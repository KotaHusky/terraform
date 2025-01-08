variable "subscription_id" {
  description = "The subscription ID for Azure"
  type        = string
}

variable "location" {
  description = "The location of the resources"
  type        = string
  default     = "East US"
}