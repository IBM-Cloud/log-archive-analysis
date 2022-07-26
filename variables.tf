# variables - see template.local.env for the required variables

variable "prefix" {
  description = "resources created will be named: $${prefix}vpc-pubpriv, vpc name will be $${prefix} or will be defined by vpc_name"
  default     = "log-archive"
}

variable "resource_group_name" {
  description = "Resource group that will contain all the resources created by the script."
  default     = "Default"
}

variable "region" {
  description = "region specific resources provisioned to this region"
  default     = "us-south"
}

variable "bucket_suffix" {
  description = "bucket names must be globally unique. It may be required to change this value"
  default     = "001"
}