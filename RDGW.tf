
variable "prefix" {
  default = "FG"
}

variable "instance_size" {
  default = "Standard_B1s"
}

variable "instance_count" {
  default = "2"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-RG"
  location = "West US 2"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_lb" "main" {
  name                = "RDGW_LoadBalancer"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.main.id}"
  }
}

resource "azurerm_lb_probe" "main" {
  resource_group_name = "${azurerm_resource_group.main.name}"
  loadbalancer_id     = "${azurerm_lb.main.id}"
  name                = "rdgw-running-probe"
  port                = 3389
  protocol            = "Tcp"
}

resource "azurerm_lb_rule" "main" {
  resource_group_name            = "${azurerm_resource_group.main.name}"
  loadbalancer_id                = "${azurerm_lb.main.id}"
  name                           = "LB-RDGW-Rule"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.main.id}"
  probe_id                       = "${azurerm_lb_probe.main.id}"
}

resource "azurerm_availability_set" "main" {
  name                = "RDGW-AvailabilitySet"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  managed             = true
  platform_fault_domain_count = 2

  tags {
    environment = "testing"
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  resource_group_name = "${azurerm_resource_group.main.name}"
  loadbalancer_id     = "${azurerm_lb.main.id}"
  name                = "rdgwpool"
}

resource "azurerm_subnet" "rdgw" {
  name                 = "rdgw"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_security_group" "rdgw_nsg" {
  name                 = "RDGW_NSG"
  location             = "${azurerm_resource_group.main.location}"
  resource_group_name  = "${azurerm_resource_group.main.name}"

  security_rule {
    name                       = "Public"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

}

resource "azurerm_public_ip" "main" {
  name                         = "FG-Public-IP"
  location                     = "${azurerm_resource_group.main.location}"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  public_ip_address_allocation = "dynamic"

  tags {
    environment = "Production"
  }
}
resource "azurerm_network_interface" "main" {
  count = "${var.instance_count}"
  name                = "${var.prefix}-nic-${format("rdgw-%02d", count.index + 1)}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "ipconfig${format("-rdgw-%02d", count.index + 1)}"
    subnet_id                     = "${azurerm_subnet.rdgw.id}"
    private_ip_address_allocation = "dynamic"
    #public_ip_address_id          = "${azurerm_public_ip.main.id}"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = "${azurerm_subnet.rdgw.id}"
  network_security_group_id = "${azurerm_network_security_group.rdgw_nsg.id}"
}

resource "azurerm_virtual_machine" "main" {
  count = "${var.instance_count}"
  name                  = "${format("rdgw-%02d", count.index + 1)}"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${element(azurerm_network_interface.main.*.id, count.index)}"]
  vm_size               = "${var.instance_size}"
  availability_set_id   = "${azurerm_availability_set.main.id}"
  # comment this line to not delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true
  # Uncomment this line to not delete the data disks automatically when deleting the VM
   delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "OS-${format("rdgw-%02d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "rdgw"
    admin_password = "Password1234!"
  }
  os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent = true
  }
  tags {
    environment = "testing"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count = "${var.instance_count}"
  network_interface_id    = "${element(azurerm_network_interface.main.*.id, count.index)}"
  ip_configuration_name   = "ipconfig${format("-rdgw-%02d", count.index + 1)}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.main.id}"
}

/*
data "azurerm_public_ip" "test" {
  name                = "${azurerm_public_ip.test.name}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

output "public_ip_address" {
  value = "${data.azurerm_public_ip.test.ip_address}"
}
*/
