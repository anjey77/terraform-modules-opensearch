terraform {
  required_version = ">= 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 3.56.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "= 3.1.0"
    }
  }
}

locals {
  zone_awareness_enabled = var.availability_zone_count > 1
  master_user_arn        = var.master_user_create_role ? aws_iam_role.master_user_role[0].arn : var.master_user_arn
  # master_user_arn = aws_iam_role.cognito_identity_authenticated.arn
  custom_endpoint = "${var.name}-search.${data.aws_route53_zone.main[0].name}"

  opensearch_setup_index_alias_suffix_logs = "logs"
  opensearch_setup_index_alias_mgmt_logs   = "mgmt-agent-logs"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# (optional) Create IAM Role

data "aws_iam_policy_document" "master_user_assume_role_policy" {
  count = var.master_user_create_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "master_user_role" {
  count = var.master_user_create_role ? 1 : 0

  name               = "OpenSearch-MasterUser-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.master_user_assume_role_policy[0].json
  tags               = var.tags
}



# Custom Domain name (Route53 and ACM)

data "aws_route53_zone" "main" {
  count = var.custom_endpoint_enabled ? 1 : 0

  zone_id = var.route53_main_hosted_zone_id
}

resource "aws_route53_record" "this" {
  count = var.custom_endpoint_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = local.custom_endpoint
  type    = "CNAME"
  ttl     = "60"
  records = [aws_elasticsearch_domain.this.endpoint]
}

module "acm" {
  count = var.custom_endpoint_enabled ? 1 : 0

  source                     = "../acm"
  name                       = local.custom_endpoint
  domain_name                = local.custom_endpoint
  wildcard_certificate       = false
  validation_route53_zone_id = data.aws_route53_zone.main[0].zone_id
  wait_for_validation        = true
  tags                       = var.tags
}

# Allow Cognito actions for Opensearch

data "aws_iam_policy_document" "es_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "cognito_access_for_opensearh" {
  name               = "CognitoAccessForAmazonOpenSearch-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.es_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cognito_access_for_opensearh" {
  role       = aws_iam_role.cognito_access_for_opensearh.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonOpenSearchServiceCognitoAccess"
}


# CloudWatch Logs

resource "aws_cloudwatch_log_group" "es_logs" {
  for_each = { for log_type, enabled in var.log_publishing_options : log_type => enabled if enabled }

  name              = "/aws/OpenSearchService/domains/${var.name}/${each.key}"
  retention_in_days = var.retention_logs
}

resource "aws_cloudwatch_log_resource_policy" "audit_logs" {
  policy_name = "application-logs"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}

# Opensearch Cluster

resource "aws_elasticsearch_domain" "this" {
  domain_name           = var.name
  elasticsearch_version = var.elasticsearch_version

  cluster_config {
    instance_type            = var.instance_type
    dedicated_master_enabled = false
    instance_count           = var.instance_count

    zone_awareness_enabled = local.zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = local.zone_awareness_enabled ? [true] : []

      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }

  node_to_node_encryption {
    enabled = var.node_to_node_encryption
  }

  encrypt_at_rest {
    enabled = var.encrypt_at_rest
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size_gb
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = !var.set_iam_arn_as_master_user

    master_user_options {
      master_user_arn = var.set_iam_arn_as_master_user ? local.master_user_arn : null

      master_user_name     = var.set_iam_arn_as_master_user ? null : var.master_user_name
      master_user_password = var.set_iam_arn_as_master_user ? null : var.master_user_password
    }
  }

  domain_endpoint_options {
    enforce_https       = true # Default
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"

    custom_endpoint_enabled         = var.custom_endpoint_enabled
    custom_endpoint_certificate_arn = var.custom_endpoint_enabled ? module.acm[0].ssl_certificate_arn : null
    custom_endpoint                 = var.custom_endpoint_enabled ? local.custom_endpoint : null
  }

  cognito_options {
    enabled          = var.cognito_enabled
    identity_pool_id = var.cognito_identity_pool_id
    role_arn         = aws_iam_role.cognito_access_for_opensearh.arn
    user_pool_id     = var.cognito_user_pool_id
  }

  timeouts {
    update = var.timeouts_update
  }

  dynamic "log_publishing_options" {
    for_each = var.log_publishing_options

    content {
      enabled                  = log_publishing_options.value
      cloudwatch_log_group_arn = log_publishing_options.value ? aws_cloudwatch_log_group.es_logs[log_publishing_options.key].arn : ""
      log_type                 = log_publishing_options.key
    }
  }


  tags = merge({ Name = var.name }, var.tags)

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "es" {
  statement {
    actions   = distinct(compact(var.iam_actions))
    resources = ["${aws_elasticsearch_domain.this.arn}/*"]
    principals {
      type = "AWS"
      identifiers = sort(concat(
        [for marketplace, params in var.marketplaces : "arn:aws:iam::${params.account_id}:root"],
        [
          local.master_user_arn,
          var.cognito_identity_authenticated_arn,
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        ]
      ))
    }
  }

  statement {
    actions   = ["es:ESHttp*"]
    resources = ["${aws_elasticsearch_domain.this.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [for _, role_arn in var.cognito_identity_group_role_arns : role_arn]
    }
  }
}

resource "aws_elasticsearch_domain_policy" "this" {
  domain_name     = aws_elasticsearch_domain.this.domain_name
  access_policies = data.aws_iam_policy_document.es.json
}

# SSM

resource "aws_ssm_parameter" "opensearch_vars" {
  name = var.ssm_opensearch_vars
  type = "String"
  value = jsonencode({
    opensearch_endpoint                = var.custom_endpoint_enabled ? "https://${local.custom_endpoint}" : "https://${aws_elasticsearch_domain.this.endpoint}"
    opensearch_region                  = data.aws_region.current.name
    opensearch_index_alias_suffix_logs = local.opensearch_setup_index_alias_suffix_logs
    opensearch_index_alias_mgmt_logs   = local.opensearch_setup_index_alias_mgmt_logs
  })
}
