variable "name" {
  default     = "microservice_api"
  description = "This can be defined when calling module so you can avoid creating duplicates if you want to call the module multiple times"
}

# Variables
variable "region" {
  description = "Region must be specified"
}

variable "subnet_ids" {
  type        = "list"
  description = "Subnet IDs to associate with Lambda Function"
}

variable "security_group_ids" {
  type        = "list"
  description = "Security Group IDs to associate with Lambda Function"
}

variable "burst_limit" {
  default = 5
}

variable "rate_limit" {
  default = 10
}

variable "lambda_name" {
  description = "lambda name to load"
  default = "proxy.zip"
}

variable "lambda_handler" {
  description = "lambda handler function name"
  default = "index.myHandler"
}

variable "lambda_engine" {
  description = "engine to run the lambda code"
  default = "nodejs6.10"
}

variable "lambda_env" {
  description = "A mapping of environment variables to pass for lambda"
  default     = {
    variables = {
      PROXY_HOST = "test"
      PROXY_PORT = "80"
    }
  }
}