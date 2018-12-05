#Test
# Azure VNet in a Box Template

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
#variable "resource_group_name" {}
#variable "region" {default = "Central US"}
#variable "EnvironmentTag" {}
#variable "network_name" {}
#variable "storage_account_name" {}
#variable "container_name" {}

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}


terraform {
  backend "azurerm" {
    storage_account_name = "fgterratest"
    container_name       = "testing"
    key                  = "terraform.tfstate"
    access_key           = "KerLsV335vcJ0zMcls9j+eKKSA/TPRnlZukEwJckVSISLvpKLMlcT/oowifoM/E6H5EKfK0Vx6qy/Br0UgPfLg=="
  }
}

# Create a resource group

/* module "m-vnet"
{
  source   = "./modules"
  name     = "${var.resource_group_name}"
  location = "${var.region}"
  resource_group_name = "${var.resource_group_name}"
  network_name = "${var.network_name}"
}
*/
