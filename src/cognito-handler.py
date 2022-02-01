#!/usr/bin/env python3

import boto3
import os

identity_pool_id = os.getenv("COGNITO_IDENTITY_POOL_ID")
identity_authenticated_arn = os.getenv("COGNITO_IDENTITY_AUTHENTICATED_ARN")

client = boto3.client('cognito-identity')


def get_cognito_identity_providers():
    res = client.describe_identity_pool(IdentityPoolId=identity_pool_id)
    return res['CognitoIdentityProviders']


def set_identity_pool_roles(provider_name, client_id):
    print(f"[INFO] Set up auth provider {provider_name}:{client_id}")

    client.set_identity_pool_roles(
        IdentityPoolId=identity_pool_id,
        Roles={
            'authenticated': identity_authenticated_arn
        },
        RoleMappings={
            f'{provider_name}:{client_id}': {
                'Type': 'Token',
                'AmbiguousRoleResolution': 'AuthenticatedRole',
            }
        }
    )


for idp in get_cognito_identity_providers():
    set_identity_pool_roles(idp['ProviderName'], idp['ClientId'])
