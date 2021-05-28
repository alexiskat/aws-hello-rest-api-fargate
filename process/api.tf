
# setup the private link to the VPC
resource "aws_api_gateway_vpc_link" "fargate_http_api_integration" {
  name        = "${module.config.entries.tags.prefix}api-to-fargate-nlb"
  target_arns = [aws_alb.fargate_nlb.arn]
  tags = merge(
    module.config.entries.tags.standard,
    {
      "Name" = "${module.config.entries.tags.prefix}api-to-fargate-nlb"
    },
  )
}

# setup the rest api
resource "aws_api_gateway_rest_api" "fargate_rest_api" {
  name = "${module.config.entries.tags.prefix}rest-api-to-nlb"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# GET /Health
resource "aws_api_gateway_resource" "rest_api_resource_health" {
  parent_id   = aws_api_gateway_rest_api.fargate_rest_api.root_resource_id
  path_part   = "health"
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
}

resource "aws_api_gateway_method" "rest_api_resource_get_health" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.rest_api_resource_health.id
  rest_api_id   = aws_api_gateway_rest_api.fargate_rest_api.id
}

resource "aws_api_gateway_integration" "rest_api_integration" {
  http_method = aws_api_gateway_method.rest_api_resource_get_health.http_method
  resource_id = aws_api_gateway_resource.rest_api_resource_health.id
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
  type        = "MOCK"
}

# GET /systeminfo
resource "aws_api_gateway_resource" "rest_api_resource_systeminfo" {
  parent_id   = aws_api_gateway_rest_api.fargate_rest_api.root_resource_id
  path_part   = "systeminfo"
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
}

resource "aws_api_gateway_method" "rest_api_resource_get_systeminfo" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.rest_api_resource_systeminfo.id
  rest_api_id   = aws_api_gateway_rest_api.fargate_rest_api.id
}

resource "aws_api_gateway_integration" "rest_api_systeminfo" {
  http_method             = aws_api_gateway_method.rest_api_resource_get_systeminfo.http_method
  resource_id             = aws_api_gateway_resource.rest_api_resource_systeminfo.id
  rest_api_id             = aws_api_gateway_rest_api.fargate_rest_api.id
  type                    = "HTTP"
  uri                     = "https://${module.config.entries.dns.api_dns}/systeminfo"
  integration_http_method = "GET"
  passthrough_behavior    = "WHEN_NO_MATCH"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.fargate_http_api_integration.id
  request_templates = {
    "application/json" = jsonencode(
      {
        "statusCode" = 200
      }
    )
  }
}

# GET /test
resource "aws_api_gateway_resource" "rest_api_resource_test" {
  parent_id   = aws_api_gateway_rest_api.fargate_rest_api.root_resource_id
  path_part   = "test"
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
}

resource "aws_api_gateway_method" "rest_api_resource_get_test" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.rest_api_resource_test.id
  rest_api_id   = aws_api_gateway_rest_api.fargate_rest_api.id
}
# GET /test IN
resource "aws_api_gateway_integration" "rest_api_test" {
  http_method = aws_api_gateway_method.rest_api_resource_get_test.http_method
  resource_id = aws_api_gateway_resource.rest_api_resource_test.id
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        "statusCode" = 200
      }
    )
  }
}

# GET /test OUT
resource "aws_api_gateway_method_response" "rest_api_test_response_200" {
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
  resource_id = aws_api_gateway_resource.rest_api_resource_test.id
  http_method = aws_api_gateway_method.rest_api_resource_get_test.http_method
  status_code = 200
}

resource "aws_api_gateway_integration_response" "rest_api_test_response" {
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
  resource_id = aws_api_gateway_resource.rest_api_resource_test.id
  http_method = aws_api_gateway_method.rest_api_resource_get_test.http_method
  status_code = aws_api_gateway_method_response.rest_api_test_response_200.status_code
  response_templates = {
    "application/json" = jsonencode(
      {
        "msg" = "Hello from weebaws!"
      }
    )
  }
}

# changes that will trigger a new deployment of the 
resource "aws_api_gateway_deployment" "rest_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id

  # https://github.com/hashicorp/terraform-provider-aws/issues/11344
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.rest_api_resource_health.id,
      aws_api_gateway_method.rest_api_resource_get_health.id,
      aws_api_gateway_resource.rest_api_resource_systeminfo.id,
      aws_api_gateway_method.rest_api_resource_get_systeminfo.id,
      aws_api_gateway_resource.rest_api_resource_test.id,
      aws_api_gateway_method.rest_api_resource_get_test.id,
      aws_api_gateway_integration.rest_api_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# define the stage dev 
resource "aws_api_gateway_stage" "rest_api_stage_dev" {
  depends_on    = [aws_cloudwatch_log_group.cw_api_fargate_nlb_dev_stage]
  deployment_id = aws_api_gateway_deployment.rest_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.fargate_rest_api.id
  stage_name    = "dev"
  tags = merge(
    module.config.entries.tags.standard,
    {
      "Name" = "${module.config.entries.tags.prefix}api-fargate-nlb-dev-stage"
    },
  )
}

# define the stage dev logging group
resource "aws_cloudwatch_log_group" "cw_api_fargate_nlb_dev_stage" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.fargate_rest_api.id}/dev"
  retention_in_days = 7
  tags = merge(
    module.config.entries.tags.standard,
    {
      "Name" = "${module.config.entries.tags.prefix}api-fargate-nlb-dev-log"
    },
  )
}

# define all the dev stage settings
resource "aws_api_gateway_method_settings" "all_dev_stage" {
  rest_api_id = aws_api_gateway_rest_api.fargate_rest_api.id
  stage_name  = aws_api_gateway_stage.rest_api_stage_dev.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}


resource "aws_api_gateway_domain_name" "rest_api_nlb_custom_domain" {
  domain_name              = module.config.entries.dns.api_dns
  security_policy          = "TLS_1_2"
  regional_certificate_arn = data.terraform_remote_state.sec_state.outputs.entries.acm_cert_arn.api
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = merge(
    module.config.entries.tags.standard,
    {
      "Name" = "${module.config.entries.tags.prefix}rest-api-to-fargate-nlb-cust-dom"
    },
  )
}

resource "aws_api_gateway_base_path_mapping" "api_rest_nlb_fargate_cd_mapping" {
  api_id      = aws_api_gateway_rest_api.fargate_rest_api.id
  stage_name  = aws_api_gateway_stage.rest_api_stage_dev.stage_name
  domain_name = aws_api_gateway_domain_name.rest_api_nlb_custom_domain.domain_name
}


# 
# # attach the HTTP API GW to the VPC link and ALB
# resource "aws_apigatewayv2_integration" "fargate_http_api_integration" {
#   api_id                 = aws_apigatewayv2_api.fargate_http_api.id
#   integration_type       = "HTTP_PROXY"
#   connection_type        = "VPC_LINK"
#   connection_id          = aws_apigatewayv2_vpc_link.fargate_http_api_integration.id
#   integration_uri        = aws_alb_listener.fargate_alb_listener_http_hello.arn
#   integration_method     = "ANY"
#   payload_format_version = "1.0"
# }
# 
# resource "aws_apigatewayv2_stage" "fargate_http_api_stage_v1" {
#   api_id      = aws_apigatewayv2_api.fargate_http_api.id
#   name        = "v1"
#   auto_deploy = true
#   default_route_settings {
#     throttling_burst_limit = 1001
#     throttling_rate_limit  = 501
#   }
#   access_log_settings {
#     destination_arn = aws_cloudwatch_log_group.fargate_api_http.arn
#     format = jsonencode(
#       {
#         path                     = "$context.path"
#         protocol                 = "$context.protocol"
#         time                     = "$context.requestTime"
#         route_key                = "$context.routeKey"
#         stage                    = "$context.stage"
#         status                   = "$context.status"
#         auth_status              = "$context.authorizer.status"
#         aws_endpoint             = "$context.awsEndpointRequestId"
#         domain_name              = "$context.domainName"
#         domain_prefix            = "$context.domainPrefix"
#         err_msg                  = "$context.error.message"
#         err_string               = "$context.error.messageString"
#         err_response             = "$context.error.responseType"
#         request_id               = "$context.extendedRequestId"
#         http_method              = "$context.httpMethod"
#         cognito_auth_provider    = "$context.identity.cognitoAuthenticationProvider"
#         cognito_auth_type        = "$context.identity.cognitoAuthenticationType"
#         cognito_identity_id      = "$context.identity.cognitoIdentityId"
#         cognito_identity_pool_id = "$context.identity.cognitoIdentityPoolId"
#         principa_ord_id          = "$context.identity.principalOrgId"
#         source_ip                = "$context.identity.sourceIp"
#         user                     = "$context.identity.user"
#         user_agent               = "$context.identity.userAgent"
#         integration_error        = "$context.integration.error"
#         integration_int_status   = "$context.integration.integrationStatus"
#         integration_status       = "$context.integration.status"
#         integration_error_msg    = "$context.integrationErrorMessage"
#       }
#     )
#   }
#   tags = merge(
#     module.config.entries.tags.standard,
#     {
#       "Name" = "${module.config.entries.tags.prefix}-stage"
#     },
#   )
# }
# 
# resource "aws_apigatewayv2_route" "fargate_http_api_proxy" {
#   api_id    = aws_apigatewayv2_api.fargate_http_api.id
#   route_key = "ANY /{proxy+}"
#   #route_key          = "$default"
#   authorization_type = "NONE"
#   target             = "integrations/${aws_apigatewayv2_integration.fargate_http_api_integration.id}"
# }
# 
# resource "aws_apigatewayv2_domain_name" "fargate_http_api_custom_domain" {
#   domain_name = module.config.entries.dns.api_dns
#   domain_name_configuration {
#     certificate_arn = data.terraform_remote_state.sec_state.outputs.entries.acm_cert_arn.api
#     endpoint_type   = "REGIONAL"
#     security_policy = "TLS_1_2"
#   }
#   tags = merge(
#     module.config.entries.tags.standard,
#     {
#       "Name" = "${module.config.entries.tags.prefix}api-custom-domain"
#     },
#   )
# }
# 
# resource "aws_apigatewayv2_api_mapping" "api_dns_mappings" {
#   api_id      = aws_apigatewayv2_api.fargate_http_api.id
#   domain_name = aws_apigatewayv2_domain_name.fargate_http_api_custom_domain.id
#   stage       = aws_apigatewayv2_stage.fargate_http_api_stage_v1.id
# }

# https://manurana.medium.com/tutorial-connecting-an-api-gateway-to-a-vpc-using-vpc-link-682a21281263
# https://docs.aws.amazon.com/apigateway/latest/developerguide/getting-started-with-private-integration.html