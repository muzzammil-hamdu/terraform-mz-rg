terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = "52883a55-f8e4-450c-a9a2-c98920f818fc"
  client_secret   = "z1v8Q~Hv7~QBbbb9Akoew9lbauFR5b74oCOmGalC"
  tenant_id       = "66573a45-6f85-4878-bebc-e0bc24647836"
  subscription_id = "5d1b700e-5c37-4a48-a430-e148b56e5404"
}

resource "azurerm_resource_group" "main" {
  name     = "my-winvm-rg"
  location = "UK South"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "winvm-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "winvm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "winvm-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"   # Fixed Public IP
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "winvm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "winvm-ip-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic" # Azure handles it
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "my-winvm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_D4ds_v5"
  admin_username        = "mujju"
  admin_password        = "Muzzammil@752"
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
}

# Install Java, Teams, Chrome via Custom Script Extension
resource "azurerm_virtual_machine_extension" "install_software" {
  name                 = "install-software"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"
    Invoke-WebRequest -Uri https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.exe -OutFile C:\\\\Temp\\\\java.exe; Start-Process C:\\\\Temp\\\\java.exe -ArgumentList '/s' -Wait;
    Invoke-WebRequest -Uri https://go.microsoft.com/fwlink/p/ -OutFile C:\\\\Temp\\\\teams.exe; Start-Process C:\\\\Temp\\\\teams.exe -ArgumentList '/silent' -Wait;
    Invoke-WebRequest -Uri https://dl.google.com/chrome/install/latest/chrome_installer.exe -OutFile C:\\\\Temp\\\\chrome.exe; Start-Process C:\\\\Temp\\\\chrome.exe -ArgumentList '/silent /install' -Wait;
  \""
}
SETTINGS
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}
