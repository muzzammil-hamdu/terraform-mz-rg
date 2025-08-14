
variable "resource_group_name" {
  type        = string
  default     = "my-winvm-rg"
  description = "Resource group name"
}

variable "location" {
  type        = string
  default     = "UK South"
  description = "Azure region"
}

variable "vm_name" {
  type        = string
  default     = "my-winvm"
  description = "Windows VM name"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D4ds_v5"
  description = "VM SKU"
}

variable "admin_username" {
  type        = string
  default     = "mujju"
  description = "Local admin username"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Local admin password (set as a sensitive variable in Terraform Cloud)"
}
