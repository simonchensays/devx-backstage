################################################################################
# Cognito User Pool
################################################################################

resource "aws_cognito_user_pool" "main" {
  name = local.name_prefix

  auto_verified_attributes = ["email"]
  mfa_configuration        = "OFF"

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  tags = { Name = local.name_prefix }
}

################################################################################
# Cognito User Pool Domain (hosted UI)
################################################################################

resource "aws_cognito_user_pool_domain" "main" {
  domain       = local.name_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

################################################################################
# Cognito User Pool Client (for ALB integration)
################################################################################

resource "aws_cognito_user_pool_client" "alb" {
  name         = "${local.name_prefix}-alb"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]

  callback_urls = local.use_https ? [
    "https://${aws_lb.main.dns_name}/oauth2/idpresponse"
    ] : [
    "http://${aws_lb.main.dns_name}/oauth2/idpresponse"
  ]
}
