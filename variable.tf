variable "domain_name" {
  description = "name of ES cluster"
  type        = string
}

variable "elasticsearch_version" {
  description = "type ES version"
  type        = string
}

variable "instance_type" {
  description = "type of nodes ES cluster"
  type        = string
}

variable "instance_count" {
  description = "how many nodes startup"
  type        = number
}

variable "availability_zone_count" {
  description = "the number of zones in which the ES cluster will work"
  type        = number
}

variable "volume_size" {
  description = "disk size of one node"
  type        = number
}

variable "master_user_name" {
  description = "name the admin user"
  type        = string
}

variable "master_user_password" {
  description = "password the admin user"
  type        = string
}

variable "environment" {
  description = "current environment"
  type        = string
}

variable "sourceip" {
  description = "whitelist ip"
  type        = string
}
