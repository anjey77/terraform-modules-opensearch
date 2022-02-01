
locals {
  opensearch_setup_src_dir     = "${path.module}/src"
  cognito_setup_scr_dir        = "${path.module}/src"
  opensearch_setup_src_handler = "api-handler.py"
  cognito_setup_src_handler    = "cognito-handler.py"

  opensearch_setup_envs = {
    OPENSEARCH_ENDPOINT = var.custom_endpoint_enabled ? "https://${local.custom_endpoint}" : "https://${aws_elasticsearch_domain.this.endpoint}"
    OPENSEARCH_REGION   = data.aws_region.current.name
    INDEX_ALIAS_SUFFIX  = local.opensearch_setup_index_alias_suffix_logs
    INDEX_ALIAS_MGMT    = local.opensearch_setup_index_alias_mgmt_logs
    ASSUME_ROLE_ARN     = local.master_user_arn
    COGNITO_ROLE_ARN    = var.cognito_identity_authenticated_arn
    NUMBER_OF_SHARDS    = 1
    NUMBER_OF_REPLICAS  = 1
  }

  opensearch_setup_marketplaces_envs = { for marketplace, params in var.marketplaces : marketplace =>
    merge(local.opensearch_setup_envs, {
      MARKETPLACE_NAME = marketplace
      USERS_DASHBOARD = join(",", [
        var.cognito_identity_group_role_arns[marketplace]
      ])
      USERS_AGENT = join(",", [
        "arn:aws:iam::${params.account_id}:role/${marketplace}-EC2-front", # NOTE: Hardcoded suffix. IAM Role is managed by aws_iam_instance_profile resource.
        "arn:aws:iam::${params.account_id}:role/${marketplace}-EC2-admin"  # NOTE: Hardcoded suffix. IAM Role is managed by aws_iam_instance_profile resource.
      ])
    })
  }

  cognito_setup_envs = {
    COGNITO_IDENTITY_POOL_ID           = var.cognito_identity_pool_id
    COGNITO_IDENTITY_AUTHENTICATED_ARN = var.cognito_identity_authenticated_arn
  }
}

# Install Python requirements locally in venv
resource "null_resource" "opensearch_setup_requirements" {
  triggers = {
    marketplaces_envs     = md5(jsonencode(local.opensearch_setup_marketplaces_envs))
    opensearch_setup_envs = md5(jsonencode(local.opensearch_setup_envs))
    py_script_hash        = filemd5("${local.opensearch_setup_src_dir}/${local.opensearch_setup_src_handler}")
  }

  provisioner "local-exec" {
    command     = "python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && ./${local.opensearch_setup_src_handler} control"
    environment = local.opensearch_setup_envs
    interpreter = ["bash", "-c"]
    working_dir = local.opensearch_setup_src_dir
  }

  depends_on = [aws_elasticsearch_domain.this]
}


resource "null_resource" "opensearch_setup" {
  for_each = local.opensearch_setup_marketplaces_envs

  triggers = {
    marketplace_env = jsonencode(each.value)
    py_script_hash  = filemd5("${local.opensearch_setup_src_dir}/${local.opensearch_setup_src_handler}")
  }

  provisioner "local-exec" {
    command     = "source .venv/bin/activate && ./${local.opensearch_setup_src_handler}"
    environment = each.value
    interpreter = ["bash", "-c"]
    working_dir = local.opensearch_setup_src_dir
  }

  depends_on = [null_resource.opensearch_setup_requirements]
}

# Cognito

resource "null_resource" "cognito_setup" {
  triggers = {
    cognito_setup_envs = md5(jsonencode(local.cognito_setup_envs))
    py_script_hash     = filemd5("${local.cognito_setup_scr_dir}/${local.cognito_setup_src_handler}")
  }

  provisioner "local-exec" {
    command     = "python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && ./${local.cognito_setup_src_handler}"
    environment = local.cognito_setup_envs
    interpreter = ["bash", "-c"]
    working_dir = local.cognito_setup_scr_dir
  }

  depends_on = [
    aws_elasticsearch_domain.this,
    null_resource.opensearch_setup
  ]
}
