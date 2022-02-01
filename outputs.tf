output "opensearch_domain_name" {
  value = aws_elasticsearch_domain.this.domain_name
}

output "opensearch_domain_arn" {
  value = aws_elasticsearch_domain.this.arn
}

output "opensearch_default_endpoint" {
  value = aws_elasticsearch_domain.this.endpoint
}

output "opensearch_default_dashboard_endpoint" {
  value = aws_elasticsearch_domain.this.kibana_endpoint
}

output "opensearch_custom_endpoint" {
  value = var.custom_endpoint_enabled ? "https://${local.custom_endpoint}" : null
}

output "opensearch_dashboard_custom_endpoint" {
  value = var.custom_endpoint_enabled ? "https://${local.custom_endpoint}/_dashboards" : null
}

output "opensearch_setup_requirements_envs" {
  value = local.opensearch_setup_envs
}
