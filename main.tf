## Microservices / Proxy API Gateway
## Author: Seth Rutner


###API global configuration###

#Grabs your account number as a variable, needed for lambda permissions
data "aws_caller_identity" "current" {}

##LAMBDA CONFIG##

#Create up our Lambda function to proxy requests to our VPC
resource "aws_lambda_function" "lambda" {
  filename         = "${path.module}/${var.lambda_name}.zip"
  function_name    = "${var.lambda_name}_${var.name}"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "${var.lambda_hander}"
  runtime          = "${var.lambda_engine}"
  source_code_hash = "${base64sha256(file("${path.module}/${var.lambda_name}.zip"))}"
  timeout          = "10"
  vpc_config       = {
    subnet_ids = ["${var.subnet_ids}"]
    security_group_ids = ["${var.security_group_ids}"]
  }
  environment = "${var.lambda_env}"
}

#The role assigned to the lambda function.
#Inline policy allows lambda to assume this role.

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role_${var.name}"

  assume_role_policy = <<POLICY
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
POLICY
}

#This policy lets lambda talk to our VPC through some network interfaces
#it makes in EC2
resource "aws_iam_policy" "lambda_vpc_policy" {
    name   = "tf_lambda_vpc_policy_${var.name}"
    path   = "/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

#attach the VPC permissions to the lambda policy
resource "aws_iam_policy_attachment" "lambda_vpc" {
    name       = "tf-iam-role-attachment-lambda-vpc-policy"
    roles      = ["${aws_iam_role.lambda_role.name}"]
    policy_arn = "${aws_iam_policy.lambda_vpc_policy.arn}"
}


#Initialize the REST API
resource "aws_api_gateway_rest_api" "api_gw" {
  name          = "${var.name}_proxy_api"
  description   = "API Gateway to talk to run ${var.lambda_name}"
}

#Set up proxy resource path
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  parent_id   = "${aws_api_gateway_rest_api.api_gw.root_resource_id}"
  path_part   = "{proxy+}"
}

##########POST TO A MICROSERVICE FLOW##############

#Method to for ANY on the proxy resource
resource "aws_api_gateway_method" "proxy" {
  rest_api_id       = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id       = "${aws_api_gateway_resource.proxy.id}"
  http_method       = "ANY"
  authorization     = "NONE"
  api_key_required  = true
}

#Integration to invoke lambda proxy
resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id             = "${aws_api_gateway_resource.proxy.id}"
  http_method             = "${aws_api_gateway_method.proxy.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda.arn}/invocations"
}

#The method response after receiving the 200 passed up through lambda from the service
resource "aws_api_gateway_method_response" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id = "${aws_api_gateway_resource.proxy.id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"
  status_code = "200"
}

#Give lambda a 'trigger' permission to allow this API endpoint to invoke it
resource "aws_lambda_permission" "apigw_lambda_proxy" {
  statement_id  = "AllowExecutionFromAPIGatewayPost"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api_gw.id}/*/*/*"
}

## Deploy

# Deployment for API
resource "aws_api_gateway_deployment" "v1" {
  depends_on  = ["aws_api_gateway_method.proxy", "aws_api_gateway_integration.proxy"]
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  stage_name  = "v1"
}

## Provision

# Usage Plan
resource "aws_api_gateway_usage_plan" "usageplan" {
  name         = "${var.name}-usage-plan"
  description  = "Usage plan for service gateway"
  product_code = "${var.name}"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.api_gw.id}"
    stage  = "${aws_api_gateway_deployment.v1.stage_name}"
  }

  throttle_settings {
    burst_limit = "${var.burst_limit}"
    rate_limit  = "${var.rate_limit}"
  }
}

# Key for usage plan
resource "aws_api_gateway_api_key" "key" {
  name = "api_key"

  stage_key {
    rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
    stage_name  = "${aws_api_gateway_deployment.v1.stage_name}"
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = "${aws_api_gateway_api_key.key.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.usageplan.id}"
}
