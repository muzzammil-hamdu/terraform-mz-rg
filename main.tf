
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "trm-mz"
    workspaces {
      name = "terraform-mz-rg"
    }
  }
}

# Provider auth will come from Terraform Cloud workspace variables (ARM_*)
provider "azurerm" {
  features {}
}

# ---------------- Network & VM ----------------

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = var.vm_name
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }

  # Ensure VM agent present so extension can run
  provision_vm_agent = true
}

# ---------------- Software install via Custom Script Extension ----------------

resource "azurerm_virtual_machine_extension" "install_software" {
  name                 = "install-software"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -File install_software.ps1"
    fileUris         = [] # not used when scripts are provided via protected_settings / content
  })

  protected_settings = jsonencode({
    script = <<'POWERSHELL'
# Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Retry helper
function Invoke-WithRetry {
  param([scriptblock]$Script, [int]$Retries = 5, [int]$DelaySeconds = 10)
  for ($i=1; $i -le $Retries; $i++) {
    try { & $Script; return }
    catch {
      if ($i -eq $Retries) { throw }
      Start-Sleep -Seconds $DelaySeconds
    }
  }
}

# Install Chocolatey (used for Teams/Chrome fallback)
$env:ChocolateyUseWindowsCompression = 'true'
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Java JDK (MSI direct for JDK 21 LTS)
Invoke-WithRetry { 
  Invoke-WebRequest -Uri "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.msi" -OutFile "C:\java.msi"
}
Start-Process msiexec.exe -ArgumentList '/i C:\java.msi /qn' -Wait

# Microsoft Teams (classic enterprise MSI as fallback install via Chocolatey)
try {
  choco install microsoft-teams -y --no-progress
} catch {
  Write-Host "Chocolatey Teams install failed, trying direct..."
  Invoke-WithRetry { 
    Invoke-WebRequest -Uri "https://statics.teams.cdn.office.net/production-windows-x64/1.6.00.1381/Teams_windows_x64.msi" -OutFile "C:\teams.msi"
  }
  Start-Process msiexec.exe -ArgumentList '/i C:\teams.msi /qn' -Wait
}

# Google Chrome (enterprise)
try {
  choco install googlechrome -y --no-progress
} catch {
  Write-Host "Chocolatey Chrome install failed, trying direct..."
  Invoke-WithRetry { 
    Invoke-WebRequest -Uri "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile "C:\chrome_installer.exe"
  }
  Start-Process "C:\chrome_installer.exe" -ArgumentList "/silent /install" -Wait
}

# Set JAVA_HOME for all users (best-effort path detection)
$jdk = Get-ChildItem 'C:\Program Files\Java' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'jdk*' } | Sort-Object Name -Descending | Select-Object -First 1
if ($jdk) {
  [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk.FullName, 'Machine')
  $path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  if ($path -notlike "*$($jdk.FullName)\bin*") {
    [Environment]::SetEnvironmentVariable('Path', "$path;$($jdk.FullName)\bin", 'Machine')
  }
}

Write-Host "Software install complete."
POWERSHELL
  })

  depends_on = [azurerm_windows_virtual_machine.vm]
}

output "public_ip_address" {
  description = "Public IP of the Windows VM"
  value       = azurerm_public_ip.public_ip.ip_address
}
