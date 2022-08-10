# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "impacta-group" {
    name     = "myResourceGroup"
    location = "eastus"

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "impacta-network" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.impacta-group.name

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}

# Create subnet
resource "azurerm_subnet" "impacta-subnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.impacta-group.name
    virtual_network_name = azurerm_virtual_network.impacta-network.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "impacta-publicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.impacta-group.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "impacta-nsg" {
    name                = "myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.impacta-group.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}

# Create network interface
resource "azurerm_network_interface" "impacta-nic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.impacta-group.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.impacta-subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.impacta-publicip.id
    }

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "impacta" {
    network_interface_id      = azurerm_network_interface.impacta-nic.id
    network_security_group_id = azurerm_network_security_group.impacta-nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.impacta-group.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "impacta-storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.impacta-group.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "impacta_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.impacta_ssh.private_key_pem 
    sensitive = true
}

resource "tls_private_key" "private-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.private-key.private_key_pem
  filename        = "key.pem"
  file_permission = "0600"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "impacta-vm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.impacta-group.name
    network_interface_ids = [azurerm_network_interface.impacta-nic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myvm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username   = "adminuser"
        public_key = tls_private_key.private-key.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.impacta-storageaccount.primary_blob_endpoint
    }

    depends_on = [
        local_file.private_key
    ]

    tags = {
        environment = "Impacta - Ativiadade 01"
    }
}