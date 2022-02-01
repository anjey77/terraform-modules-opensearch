variable "name" {
  description = "Name of ES cluster. Also usesd for naming of other resources."
  type        = string
}

variable "route53_main_hosted_zone_id" {
  type = string
}

variable "custom_endpoint_enabled" {
  type    = bool
  default = true
}

variable "elasticsearch_version" {
  description = "Type ES version"
  type        = string
  default     = "OpenSearch_1.0"
}

variable "instance_type" {
  description = "Type of nodes ES cluster"
  type        = string
}

variable "instance_count" {
  description = "Nodes count"
  type        = number
}

variable "availability_zone_count" {
  description = "The number of zones in which the ES cluster will work. For 3 Availability Zones, you must choose a minimum of 3 data nodes"
  type        = number
}

variable "node_to_node_encryption" {
  description = "Required for fine-grained access"
  type        = bool
  default     = true
}

variable "encrypt_at_rest" {
  description = "Required for fine-grained access"
  type        = bool
  default     = true
}

variable "volume_size_gb" {
  description = "Disk size of one node (you can increase this value if EBS type is chosen)"
  type        = number
}

variable "timeouts_update" {
  type    = string
  default = "60m"
}

# Master user ARN
variable "set_iam_arn_as_master_user" {
  type    = bool
  default = true
}

variable "master_user_create_role" {
  description = "Create IAM role to be used as master user ARN"
  type        = bool
  default     = true
}

variable "master_user_arn" {
  description = "ARN of the master user"
  type        = string
  default     = ""
}

# If set_iam_arn_as_master_user is false

variable "master_user_name" {
  description = "Name of the master user"
  type        = string
  default     = ""
}

variable "master_user_password" {
  description = "Password of the master user"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "marketplaces" {
  type = map(any)
}

variable "ssm_opensearch_vars" {
  type        = string
  description = "SSM ParameterStore path for json with Opensearch-specific outputs"
}

variable "iam_actions" {
  type        = list(string)
  default     = ["es:*"]
  description = "List of actions to allow for the IAM roles, _e.g._ `es:ESHttpGet`, `es:ESHttpPut`, `es:ESHttpPost`"
}

# Cognito 

variable "cognito_enabled" {
  type    = bool
  default = true
}

variable "cognito_identity_pool_id" {
  type        = string
  description = "Cognito identity pool id"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "Cognito user pool id"
}

variable "cognito_identity_authenticated_arn" {
  type        = string
  description = "IAM role ARN of cognito identity authenticated"
}

variable "cognito_identity_group_role_arns" {
  type        = map(string)
  description = "IAM roles for each marketplaces attached to Cognito groups"
}

#==============================
#     CloudWatch metrics      #
#==============================

variable "alarms_enabled" {
  description = "Enable monitoring of cluster"
  type        = map(bool)
  default = {
    "cluster_status_is_red"        = true
    "cluster_status_is_yellow"     = true
    "free_storage_space_low"       = true
    "cluster_index_writes_blocked" = true
    "unreachable_nodes"            = true
    "automated_snapshot_failure"   = true
    "cpu_utilization_high"         = true
    "jvm_memory_pressure_high"     = true
    "http_requests_5xx"            = true
    "master_reachable_from_node"   = true
    "thread_pool_index_queue"      = true
    "thread_pool_search_queue"     = true
  }
}

variable "alarm_cluster_status_is_red_periods" {
  description = "The number of periods to alert that cluster status is red"
  type        = number
  default     = 1
}

variable "alarm_cluster_status_is_yellow_periods" {
  description = "The number of periods to alert that cluster status is yellow"
  type        = number
  default     = 1
}

variable "alarm_free_storage_space_low_periods" {
  description = "The number of periods to alert that cluster free storage space is low"
  type        = number
  default     = 1
}

variable "alarm_cluster_index_writes_blocked_periods" {
  description = "The number of periods to alert that cluster index writes blocked"
  type        = number
  default     = 1
}

variable "alarm_cluster_unreachable_nodes_periods" {
  description = "The number of periods to alert that cluster  unreachable nodes"
  type        = number
  default     = 1
}

variable "alarm_automated_snapshot_failure_periods" {
  description = "The number of periods to alert that cluster  automated snapshot failure"
  type        = number
  default     = 1
}

variable "alarm_cpu_utilization_high_periods" {
  description = "The number of periods to alert that cluster  cpu utilization high"
  type        = number
  default     = 3
}

variable "alarm_jvm_memory_pressure_high_periods" {
  description = "The number of periods to alert that cluster jvm memory pressure high"
  type        = number
  default     = 3
}

variable "alarm_http_requests_5xx_periods" {
  description = "The number of periods to alert that cluster HTTP requests 5xx more than 10%"
  type        = number
  default     = 2
}

variable "alarm_master_reachable_from_node_periods" {
  description = "The number of periods to alert that cluster master node stopped or is unreachable"
  type        = number
  default     = 1
}

variable "alarm_thread_pool_index_queue_periods" {
  description = "The number of periods to alert that cluster is experiencing high indexing concurrency"
  type        = number
  default     = 1
}

variable "alarm_thread_pool_search_queue_periods" {
  description = "The number of periods to alert that cluster is experiencing high search concurrency"
  type        = number
  default     = 1
}

# Opensearch logs

variable "log_publishing_options" {
  description = "Enabled Opensearch log types"
  type        = map(bool)
  default = {
    "AUDIT_LOGS"          = false
    "SEARCH_SLOW_LOGS"    = false
    "ES_APPLICATION_LOGS" = true
    "INDEX_SLOW_LOGS"     = false
  }
}

variable "retention_logs" {
  default     = 14
  type        = number
  description = "How long time retention logs from OpenSearch"
}
