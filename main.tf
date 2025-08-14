terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "trm-mz"

    workspaces {
      name = "terraform-mz-rg"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "my-winvm-rg"
  location = "East US"
}

# Virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "winvm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "winvm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP (Static, Standard SKU)
resource "azurerm_public_ip" "public_ip" {
  name                = "winvm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "winvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "winvm-ip-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Windows VM
resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "my-winvm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "azureuser"
  admin_password        = "P@ssw0rd12345!"
  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Install Java, Teams, and Chrome
resource "azurerm_virtual_machine_extension" "install_software" {
  name                 = "install-software"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"New-Item -ItemType Directory -Path C:\\Temp -Force; Invoke-WebRequest -Uri https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.exe -OutFile C:\\Temp\\java.exe; Start-Process C:\\Temp\\java.exe -ArgumentList '/s' -Wait; Invoke-WebRequest -Uri https://go.microsoft.com/fwlink/p/?linkid=2139997 -OutFile C:\\Temp\\teams.exe; Start-Process C:\\Temp\\teams.exe -ArgumentList '/silent' -Wait; Invoke-WebRequest -Uri https://dl.google.com/chrome/install/latest/chrome_installer.exe -OutFile C:\\Temp\\chrome.exe; Start-Process C:\\Temp\\chrome.exe -ArgumentList '/silent /install' -Wait\""
  })
}
