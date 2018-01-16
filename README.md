# A module that creates an API Gateway Proxy to your VPC.
Current stable version: v1.2

## Call me like this:

### NOTE: It is not secure to output the api_key to the terminal. In real deployments, omit the api_key output.

```hcl
module "lambda_proxy" {
  source             = "github.com/sprutner/terraform-aws-lambda-proxy"
  region             = "${var.region}"
  name               = "proxy"
  proxy_hostname     = "exampleproxy${var.environment}.dev"
  proxy_port         = "80"
  subnet_ids         = "${module.vpc.app_subnets}"
  security_group_ids = ["${aws_security_group.proxy_access.id}"]
  burst_limit        = 10000
  rate_limit         = 1000
}

output "invoke_url" {
  value = "${module.lambda_proxy.invoke_url}"
}

output "api_key" {
  value = "${module.lambda_proxy.api_key_value}"
}
```
