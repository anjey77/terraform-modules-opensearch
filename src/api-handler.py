#!/usr/bin/env python3

import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
import json
import os
import sys
from requests_aws4auth import AWS4Auth
import boto3

opensearch_endpoint = os.getenv("OPENSEARCH_ENDPOINT")
opensearch_region = os.getenv("OPENSEARCH_REGION")

role_arn = os.getenv("ASSUME_ROLE_ARN")
cognito_role_arn = os.getenv("COGNITO_ROLE_ARN")
marketplace_name = os.getenv("MARKETPLACE_NAME", "")
index_alias_suffix = os.getenv("INDEX_ALIAS_SUFFIX")
index_alias_mgmt = os.getenv("INDEX_ALIAS_MGMT")

users_agent = os.getenv("USERS_AGENT", "").split(',')
users_dashboard = os.getenv("USERS_DASHBOARD", "").split(',')

number_of_shards = os.getenv("NUMBER_OF_SHARDS")
number_of_replicas = os.getenv("NUMBER_OF_REPLICAS")


opensearch_endpoint_dashboards = f"{opensearch_endpoint}/_dashboards"

# Assume IAM Role

sts_client = boto3.client('sts')
assumed_role_object = sts_client.assume_role(
    RoleArn=role_arn,
    RoleSessionName="AssumeRoleByPythonScript"
)

credentials = assumed_role_object['Credentials']

awsauth = AWS4Auth(
    credentials['AccessKeyId'],
    credentials['SecretAccessKey'],
    opensearch_region,
    'es',
    session_token=credentials['SessionToken']
)

index_name = index_template_name = marketplace_tenant = marketplace_name
index_alias = f"{index_name}-{index_alias_suffix}"

group_name_agent = f"{marketplace_name}-group-agent"
group_name_dashboard = f"{marketplace_name}-group-dashboard"

role_name_agent = f"{marketplace_name}-role-agent"
role_name_dashboard = f"{marketplace_name}-role-dashboard"

data_index_template = {
    "index_patterns": [index_alias],
    "data_stream": {},  # make it a data stream
    "priority": 100,
    "template": {
        "settings": {
            "number_of_shards": number_of_shards,
            "number_of_replicas": number_of_replicas
        }
    }
}

data_index_template_mgmt = {
    "index_patterns": [index_alias_mgmt],
    "data_stream": {},
    "priority": 100,
    "template": {
        "settings": {
            "number_of_shards": number_of_shards,
            "number_of_replicas": number_of_replicas
        }
    }
}

data_actions_groups = {
    group_name_agent: {
        "allowed_actions": [
            "write",
            "cluster:monitor/main",
            "indices:admin/template/get",
            "indices:admin/create",
            "cluster:admin/ingest/pipeline/get",
            "cluster:admin/ingest/pipeline/put"
        ]
    },
    group_name_dashboard: {
        "allowed_actions": [
            "search",
            "cluster_all",
            "index",
            "manage",
            "read",
            "write",
            "cluster_composite_ops",
            "indices_monitor",
            "cluster:admin/opendistro/ism/*",
            "indices:monitor/settings/get",
            "indices:admin/aliases/get*"
        ]
    }
}

data_roles = {
    role_name_agent: {
        "cluster_permissions": [
            "cluster_composite_ops",
            group_name_agent
        ],
        "index_permissions": [{
            "index_patterns": [
                index_alias,         f".ds-{index_alias}-*",
                index_alias_mgmt, f".ds-{index_alias_mgmt}-*"
            ],
            "dls": "",
            "fls": [],
            "masked_fields": [],
            "allowed_actions": [group_name_agent]
        }],
        "tenant_permissions": [{
            "tenant_patterns": [marketplace_tenant],
            "allowed_actions": ["kibana_all_read"]
        }]
    },
    role_name_dashboard: {
        "cluster_permissions": [
            "cluster_composite_ops",
            group_name_dashboard
        ],
        "index_permissions": [{
            "index_patterns": [index_alias, f".ds-{index_alias}-*"],
            "dls": "",
            "fls": [],
            "masked_fields": [],
            "allowed_actions": [group_name_dashboard]
        }],
        "tenant_permissions": [{
            "tenant_patterns": [marketplace_tenant],
            "allowed_actions": ["kibana_all_write"]
        }]
    }
}

data_rolemapping = {
    role_name_agent: {
        "users": users_agent
    },
    role_name_dashboard: {
        "backend_roles": users_dashboard
    }
}


retry_strategy = Retry(total=6, backoff_factor=2, status_forcelist=[
                       500, 403], method_whitelist=["PATCH", "PUT", "POST", "GET"])


def http_with_retry():
    http = requests.Session()
    adapter = HTTPAdapter(max_retries=retry_strategy)
    http.mount("https://", adapter)
    return http


def opensearch_get(path):
    http = http_with_retry()
    return http.get(f"{opensearch_endpoint}/{path}", auth=awsauth,)


def opensearch_put(path, data):
    http = http_with_retry()
    return http.put(
        f"{opensearch_endpoint}/{path}",
        auth=awsauth,
        headers={'Content-Type': 'application/json'},
        data=json.dumps(data)
    )


def opensearch_patch(path, data):
    http = http_with_retry()
    return http.patch(
        f"{opensearch_endpoint}/{path}",
        auth=awsauth,
        headers={'Content-Type': 'application/json'},
        data=json.dumps(data)
    )


def dashboards_post(path, tenant, data):
    http = http_with_retry()
    return http.post(
        f"{opensearch_endpoint_dashboards}/{path}",
        headers={
            'osd-xsrf': 'true',
            'security_tenant': tenant,
            'Content-Type': 'application/json'
        },
        data=json.dumps(data),
        auth=awsauth
    )


def res_handler(log_text, res):
    try:
        res.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print('[ERROR]', res.text)
        raise Exception(str(e))
    print('[DEBUG]', log_text, json.dumps(res.json()))


def create_index_template(name, template):
    res = opensearch_put(f"_index_template/{name}", template)
    res_handler(f"Index template '{name}' creation:", res)


def create_marketplace_tenant(name):
    data = {"description": f"Private tenant for {name}"}
    res = opensearch_put(f"_plugins/_security/api/tenants/{name}", data)
    res_handler("Tenant creation:", res)


def create_actiongroups(groups):
    for name in groups:
        path = f"_plugins/_security/api/actiongroups/{name}"
        res = opensearch_put(path, groups[name])
        res_handler("Action group creation:", res)


def create_index_pattern(name, tenant):
    path = f"api/saved_objects/index-pattern/{name}"
    data = {
        "attributes": {
            "title": name,
            "timeFieldName": "@timestamp"
        }
    }
    res = dashboards_post(path, tenant, data)
    if res.status_code == 409:
        print("[INFO] Index pattern already exists")
    else:
        res_handler("Index pattern creation:", res)


def create_roles(roles):
    for name in roles:
        path = f"_plugins/_security/api/roles/{name}"
        res = opensearch_put(path, roles[name])
        res_handler("Role creation:", res)


def mapping_role_to_user(roles):
    for name in roles:
        path = f"_plugins/_security/api/rolesmapping/{name}"
        res = opensearch_put(path, roles[name])
        res_handler("Role mapping creation:", res)


# Map users to roles necessary for all master operations: all_access, security_manager
def update_master_users_mapping(users):
    roles = ["all_access", "security_manager"]
    patches = [{"op": "replace", "path": "/backend_roles", "value": users}]

    for role in roles:
        path = f"_plugins/_security/api/rolesmapping/{role}"
        res_handler("Role mapping patch:", opensearch_patch(path, patches))
        res_handler("Mapping:", opensearch_get(path))


if __name__ == '__main__':
    # Control actions
    if len(sys.argv) > 1 and str(sys.argv[1]) == "control":
        create_index_template('mgmt', data_index_template_mgmt)
        update_master_users_mapping([role_arn, cognito_role_arn])
        exit(0)

    # Marketplace actions
    create_index_template(index_template_name, data_index_template)
    create_marketplace_tenant(marketplace_tenant)
    create_actiongroups(data_actions_groups)
    create_index_pattern(index_alias, marketplace_tenant)

    create_roles(data_roles)
    mapping_role_to_user(data_rolemapping)
