terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.100"
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

provider "azurerm" {
  features {}
client_id ="52883a55-f8e4-450c-a9a2-c98920f818fc"
client_secret ="z1v8Q~Hv7~QBbbb9Akoew9lbauFR5b74oCOmGalC"
tenant_id ="66573a45-6f85-4878-bebc-e0bc24647836"
subscription_id ="5d1b700e-5c37-4a48-a430-e148b56e5404"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "terrarg6"
  location = "uk south"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-win"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-win"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "pip" {
  name                = "winvm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "winvm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-WinRM"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Subnet + NSG Association
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# NIC
resource "azurerm_network_interface" "nic" {
  name                = "winvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Windows VM
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "winhamd"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D4s_v3"
  admin_username      = "mujju"
  admin_password      = "Muzzammil@752"
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

# Enable WinRM for Ansible
resource "azurerm_virtual_machine_extension" "winrm" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"winrm quickconfig -q; winrm set winrm/config/winrs @{MaxMemoryPerShellMB='512'}; winrm set winrm/config @{MaxTimeoutms='1800000'}; winrm set winrm/config/service @{AllowUnencrypted='true'}; winrm set winrm/config/service/auth @{Basic='true'}; netsh advfirewall firewall add rule name='WinRM HTTP' dir=in action=allow protocol=TCP localport=5985\""
  })
}

# Output Public IP
output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}
