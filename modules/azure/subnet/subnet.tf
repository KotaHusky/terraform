variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "virtual_network_name" {
  description = "The name of the virtual network"
  type        = string
}

variable "subnets" {
  description = "A list of subnets to create within the virtual network"
  type = list(object({
    name           = string
    address_prefix = string
  }))
}

variable "name" {
  description = "The name of the subnet"
  type        = string
}

resource "azurerm_subnet" "subnet" {
  for_each = { for subnet in var.subnets : subnet.name => subnet }

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [each.value.address_prefix]

  lifecycle {
    ignore_changes = [
      address_prefixes,
    ]
  }
}

output "subnet_ids" {
  value = { for k, v in azurerm_subnet.subnet : k => v.id }
}

output "subnet_name_to_id" {
  value = { for subnet in azurerm_subnet.subnet : subnet.name => subnet.id }
}