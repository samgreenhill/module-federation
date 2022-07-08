output "remote-api" {
  value = aws_api_gateway_stage.dev.invoke_url
}

resource "aws_iam_role" "api" {
  name = "apigateway_sqs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "api_policy" {
  name = "api-sqs-cloudwatch-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        "Resource": "*"
      }   
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "api_exec_role" {
  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.api_policy.arn
}

resource "aws_api_gateway_rest_api" "apiGateway" {
  name        = "remote-api-gateway"
  description = "Dummy API for the remote application"
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.apiGateway.id
  parent_id   = aws_api_gateway_rest_api.apiGateway.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_request_validator" "validator_query" {
  name                        = "queryValidator"
  rest_api_id                 = aws_api_gateway_rest_api.apiGateway.id
  validate_request_body       = false
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "method_api" {
  rest_api_id      = aws_api_gateway_rest_api.apiGateway.id
  resource_id      = aws_api_gateway_resource.api.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false

  request_parameters = {
    "method.request.path.proxy" = false
  }

  request_validator_id = aws_api_gateway_request_validator.validator_query.id
}

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = aws_api_gateway_rest_api.apiGateway.id
  resource_id             = aws_api_gateway_resource.api.id
  http_method             = aws_api_gateway_method.method_api.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_api.invoke_arn
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.apiGateway.id

  # Redeploy when there are new updates
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.api,
      aws_api_gateway_resource.api.id,
      aws_api_gateway_method.method_api.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.apiGateway.id
  stage_name    = local.stage_name
}

resource "aws_api_gateway_usage_plan" "dev" {
  name = "dev-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.apiGateway.id
    stage  = aws_api_gateway_stage.dev.stage_name
  }

  quota_settings {
    limit  = 100
    offset = 2
    period = "WEEK"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

/*resource "aws_api_gateway_api_key" "devkey" {
  name = "dev_key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.devkey.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.dev.id
}*/

data "archive_file" "lambda_with_dependencies_api" {
  source_dir  = "../remote-api/dist"
  output_path = "../remote-api/dist/${local.app_name}-${local.lambda_api_name}.zip"
  excludes    = ["${local.app_name}-${local.lambda_api_name}.zip"]
  type        = "zip"
}

resource "aws_lambda_function" "lambda_api" {
  function_name = "${local.app_name}-${local.lambda_api_name}"
  handler       = "main.handler"
  role          = aws_iam_role.lambda_api_role.arn
  runtime       = "nodejs14.x"

  filename         = data.archive_file.lambda_with_dependencies_api.output_path
  source_code_hash = data.archive_file.lambda_with_dependencies_api.output_base64sha256

  timeout     = 30
  memory_size = 128
}

resource "aws_iam_policy" "lambda_api_policy" {
  name        = "lambda_policy_api"
  description = "IAM policy for lambda Being invoked by API gateway"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect": "Allow"
      }
    ]
  }
EOF
}

resource "aws_iam_role" "lambda_api_role" {
  name               = "${local.app_name}-api-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_api_role_policy" {
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = aws_iam_policy.lambda_api_policy.arn
}

resource "aws_lambda_permission" "allows_apigateway_to_trigger_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.apiGateway.execution_arn}/*/*/*"
}