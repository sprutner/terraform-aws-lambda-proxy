variable "name" {
  default     = "microservice_api"
  description = "This can be defined when calling module so you can avoid creating duplicates if you want to call the module multiple times"
}

# Variables
variable "region" {
  description = "Region must be specified"
}

variable "proxy_hostname" {
  description = "Hostname for Fabio"
}

variable "proxy_port" {
  description = "Port for Nomad API"
  default     = "80"
}

variable "subnet_ids" {
  type        = "list"
  description = "Subnet IDs to associate with Lambda Function"
}

variable "security_group_ids" {
  type        = "list"
  description = "Security Group IDs to associate with Lambda Function"
}

variable "quota_limit" {
  default = 20
}

variable "quota_offset" {
  default = 2
}

variable "burst_limit" {
  default = 5
}

variable "rate_limit" {
  default = 10
}
