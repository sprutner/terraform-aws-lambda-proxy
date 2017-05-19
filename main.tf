## Microservices API Gateway
## Author: Seth Rutner


###API global configuration###

#Grabs your account number as a variable, needed for lambda permissions
data "aws_caller_identity" "current" {}

##LAMBDA CONFIG##

#Create up our Lambda function to proxy requests to our VPC
resource "aws_lambda_function" "lambda" {
  filename         = "passthrough_api.zip"
  function_name    = "passthrough_api_${var.name}"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "index.myHandler"
  runtime          = "nodejs6.10"
  source_code_hash = "${base64sha256(file("passthrough_api.zip"))}"
  vpc_config       = {
    subnet_ids = ["${var.subnet_ids}"]
    security_group_ids = ["${var.security_group_ids}"]
  }
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

#Allows lambda function to hit the API Resource
#Not sure if necessary
// resource "aws_iam_policy" "lambda_api_allow_all" {
//     name   = "lambda_api_allow_all_${var.name}"
//     path   = "/"
//     policy = <<EOF
// {
//     "Version": "2012-10-17",
//     "Statement": [
//         {
//             "Sid": "Stmt1492128981000",
//             "Effect": "Allow",
//             "Action": [
//                 "execute-api:*"
//             ],
//             "Resource": [
//                 "*"
//             ]
//         }
//     ]
// }
// EOF
// }

#Attached allow all api policy.
#not sure if needed
// resource "aws_iam_policy_attachment" "lambda_api_allow_all" {
//     name       = "tf-iam-role-attachment-lambda-api-allow-all"
//     roles      = ["${aws_iam_role.lambda_role.name}"]
//     policy_arn = "${aws_iam_policy.lambda_api_allow_all.arn}"
// }


#attach the VPC permissions to the lambda policy
resource "aws_iam_policy_attachment" "lambda_vpc" {
    name       = "tf-iam-role-attachment-lambda-vpc-policy"
    roles      = ["${aws_iam_role.lambda_role.name}"]
    policy_arn = "${aws_iam_policy.lambda_vpc_policy.arn}"
}


#Initialize the REST API
resource "aws_api_gateway_rest_api" "api_gw" {
  name          = "microservices_api"
  description   = "API Gateway to talk to microservices"
}

#Set up root v1 resource path
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  parent_id   = "${aws_api_gateway_rest_api.api_gw.root_resource_id}"
  path_part   = "v1"
}

#Set up services resource path
resource "aws_api_gateway_resource" "v1_services" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  parent_id   = "${aws_api_gateway_resource.v1.id}"
  path_part   = "services"
}


##########POST TO A MICROSERVICE FLOW##############

#Set up {service-name} POST resource path
resource "aws_api_gateway_resource" "v1_services_service-name" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  parent_id   = "${aws_api_gateway_resource.v1_services.id}"
  path_part   = "{service_name}"
}

#Method to POST to the {service_name}
resource "aws_api_gateway_method" "v1_services_service-name_POST" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id = "${aws_api_gateway_resource.v1_services_service-name.id}"
  http_method = "POST"
  authorization = "NONE"
}

#Integration to invoke lambda to pass-through data to fabio (proxy)
resource "aws_api_gateway_integration" "v1_services_service-name_POST_integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id             = "${aws_api_gateway_resource.v1_services_service-name.id}"
  http_method             = "${aws_api_gateway_method.v1_services_service-name_POST.http_method}"
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda.arn}/invocations"

  request_templates {
    "application/json" = <<EOF
#set($allParams = $input.params())
{
  "requestParams" : {
    "hostname" : "${var.fabio_hostname}",
    "port" : "${var.fabio_port}",
    "path" : "/$input.params('service-name')",
    "method" : "$context.httpMethod"
  },
  "bodyJson" : $input.json('$'),
  "params" : {
    #foreach($type in $allParams.keySet())
      #set($params = $allParams.get($type))
      "$type" : {
        #foreach($paramName in $params.keySet())
          "$paramName" : "$util.escapeJavaScript($params.get($paramName))"
          #if($foreach.hasNext),#end
        #end
      }
      #if($foreach.hasNext),#end
    #end
  },
  "stage-variables" : {
    #foreach($key in $stageVariables.keySet())
      "$key" : "$util.escapeJavaScript($stageVariables.get($key))"
      #if($foreach.hasNext),#end
    #end
  },
  "context" : {
    "account-id" : "$context.identity.accountId",
    "api-id" : "$context.apiId",
    "api-key" : "$context.identity.apiKey",
    "authorizer-principal-id" : "$context.authorizer.principalId",
    "caller" : "$context.identity.caller",
    "cognito-authentication-provider" : "$context.identity.cognitoAuthenticationProvider",
    "cognito-authentication-type" : "$context.identity.cognitoAuthenticationType",
    "cognito-identity-id" : "$context.identity.cognitoIdentityId",
    "cognito-identity-pool-id" : "$context.identity.cognitoIdentityPoolId",
    "http-method" : "$context.httpMethod",
    "stage" : "$context.stage",
    "source-ip" : "$context.identity.sourceIp",
    "user" : "$context.identity.user",
    "user-agent" : "$context.identity.userAgent",
    "user-arn" : "$context.identity.userArn",
    "request-id" : "$context.requestId",
    "resource-id" : "$context.resourceId",
    "resource-path" : "$context.resourcePath"
  }
}
EOF
  }
}

#The method response after receiving the 200 from Lambda
resource "aws_api_gateway_method_response" "v1_services_service-name_POST_method_response" {
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id = "${aws_api_gateway_resource.v1_services_service-name.id}"
  http_method = "${aws_api_gateway_method.v1_services_service-name_POST.http_method}"
  status_code = "200"
}

#The integration response from fabio
resource "aws_api_gateway_integration_response" "v1_services_service-name_POST_integration_response" {
  depends_on  = ["aws_api_gateway_integration.v1_services_service-name_POST_integration"]
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  resource_id = "${aws_api_gateway_resource.v1_services_service-name.id}"
  http_method = "${aws_api_gateway_method.v1_services_service-name_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_services_service-name_POST_method_response.status_code}"
}

#Give lambda a 'trigger' permission to allow this API endpoint to invoke it
resource "aws_lambda_permission" "apigw_lambda_post_job_docker" {
  statement_id  = "AllowExecutionFromAPIGatewayPost"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api_gw.id}/*/POST/v1/services/*/"
}
