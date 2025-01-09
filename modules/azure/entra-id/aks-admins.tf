variable "admin_user_object_id" {
  description = "The object ID of the Azure AD user that will be added to the admin group"
  type        = string
}

resource "azuread_group" "aks_admins" {
  display_name     = "aks-admins"
  members          = [var.admin_user_object_id]
  security_enabled = true
}

resource "azuread_group" "helm_users" {
  display_name = "Helm Users"
  members      = [var.admin_user_object_id]
  security_enabled = true
}

output "aks_admins_group_id" {
  value = azuread_group.aks_admins.object_id
}

output "helm_users_group_id" {
  value = azuread_group.helm_users.object_id
}