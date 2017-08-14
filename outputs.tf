output "invoke_url" {
  value = "${aws_api_gateway_deployment.v1.invoke_url}"
}

output "api_key_name" {
  value = "${aws_api_gateway_api_key.key.name}"
}

output "api_key_value" {
  value = "${aws_api_gateway_api_key.key.value}"
}
