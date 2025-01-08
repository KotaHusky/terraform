variable "admin_user_object_id" {
  description = "The object ID of the Azure AD user that will be added to the admin group"
  type        = string
}

resource "azuread_group" "aks_admins" {
  display_name     = "aks-admins"
  members          = [var.admin_user_object_id]
  security_enabled = true
}

output "aks_admins_group_id" {
  value = azuread_group.aks_admins.id
}