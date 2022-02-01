locals {
  dimensions = {
    DomainName = var.name
    ClientId   = data.aws_caller_identity.current.account_id
  }
  free_storage_space_low_threshold = var.volume_size_gb * 0.25 * 1024 # The minimum amount of available storage space in MB; recommended setting it to 25% of the storage space
}

resource "aws_cloudwatch_metric_alarm" "cluster_status_is_red" {
  count = var.alarms_enabled.cluster_status_is_red ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Status-Is-Red", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_cluster_status_is_red_periods
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Average elasticsearch cluster status is in red over last 1 minute(s)"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "cluster_status_is_yellow" {
  count = var.alarms_enabled.cluster_status_is_yellow ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Status-Is-Yellow", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_cluster_status_is_yellow_periods
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = "60" #var.monitor_cluster_status_is_yellow_period
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Average elasticsearch cluster status is in yellow over last 1m minute(s)"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space_low" {
  count = var.alarms_enabled.free_storage_space_low ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Free-Storage-Space-Low", title(var.name))
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_free_storage_space_low_periods
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = "60" #var.monitor_free_storage_space_low_period
  statistic           = "Minimum"
  threshold           = local.free_storage_space_low_threshold
  alarm_description   = "Average elasticsearch free storage space over last 1 minute(s) is low"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "cluster_index_writes_blocked" {
  count = var.alarms_enabled.cluster_index_writes_blocked ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Index-Writes-Blocked", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_cluster_index_writes_blocked_periods
  metric_name         = "ClusterIndexWritesBlocked"
  namespace           = "AWS/ES"
  period              = "300" #var.monitor_cluster_index_writes_blocked_period # 300s => 5m
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Elasticsearch index writes being blocker over last 5 minute(s)"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "unreachable_nodes" {
  count = var.alarms_enabled.unreachable_nodes ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Available-Nodes", title(var.name))
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_cluster_unreachable_nodes_periods
  metric_name         = "Nodes"
  namespace           = "AWS/ES"
  period              = "86400" # 86400s => 24h
  statistic           = "Minimum"
  threshold           = var.instance_count
  alarm_description   = "Elasticsearch nodes minimum < ${var.instance_count} for 1 day"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "automated_snapshot_failure" {
  count = var.alarms_enabled.automated_snapshot_failure ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Automated-Snapshot-Failed", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_automated_snapshot_failure_periods
  metric_name         = "AutomatedSnapshotFailure"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Elasticsearch automated snapshot failed for last 1 minute(s)"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_high" {
  count = var.alarms_enabled.cpu_utilization_high ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-CPU-Utilization-High", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_cpu_utilization_high_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = "900" # 900s => 15m
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Average elasticsearch cluster CPU utilization over last 45 minutes high"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "jvm_memory_pressure_high" {
  count = var.alarms_enabled.jvm_memory_pressure_high ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-JVM-Memory-Pressure", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_jvm_memory_pressure_high_periods
  metric_name         = "JVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = "300" # 300s => 5m
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Elasticsearch JVM memory pressure is too high over last 15 minutes"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "http_requests_5xx" {
  count = var.alarms_enabled.http_requests_5xx ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-HTTP-Requests-5xx", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_http_requests_5xx_periods
  threshold           = "10"
  alarm_description   = "Elasticsearch HTTP Requests 5xx for last 10 minutes"
  treat_missing_data  = "ignore"

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "5xx"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "OpenSearchRequests"
      namespace   = "AWS/ES"
      period      = "300" # 300s => 5m
      stat        = "Sum"

      dimensions = local.dimensions
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "5xx"
      namespace   = "AWS/ES"
      period      = "300" # 300s => 5m
      stat        = "Sum"

      dimensions = local.dimensions
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "master_reachable_from_node" {
  count = var.alarms_enabled.master_reachable_from_node ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Master-Reachable-From-Node", title(var.name))
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_master_reachable_from_node_periods
  metric_name         = "MasterReachableFromNode"
  namespace           = "AWS/ES"
  period              = "86400" # 86400s => 24h
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Elasticsearch master node stopped or is unreachable minimum < 1 for 1 day"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "thread_pool_index_queue" {
  count = var.alarms_enabled.thread_pool_index_queue ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Thread_Pool_Index_Queue", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_thread_pool_index_queue_periods
  metric_name         = "ThreadpoolIndexQueue" # metric is not exist
  namespace           = "AWS/ES"
  period              = "60" # 1 min
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "Elasticsearch cluster is experiencing high indexing concurrency for 1 min"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}

resource "aws_cloudwatch_metric_alarm" "thread_pool_search_queue" {
  count = var.alarms_enabled.thread_pool_search_queue ? 1 : 0

  alarm_name          = format("ElasticSearch-Cluster-%s-Thread-Pool-Search-Queue", title(var.name))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_thread_pool_search_queue_periods
  metric_name         = "ThreadpoolSearchQueue"
  namespace           = "AWS/ES"
  period              = "60" # 1 min
  statistic           = "Average"
  threshold           = "500"
  alarm_description   = "Elasticsearch cluster is experiencing high search concurrency for 1 min"
  treat_missing_data  = "ignore"
  tags                = var.tags

  dimensions = local.dimensions
}
