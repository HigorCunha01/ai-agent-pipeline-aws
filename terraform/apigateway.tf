resource "aws_apigatewayv2_api" "agent_webhook_api" {
  name          = "agent-webhook-api${var.project_suffix}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "webhook_receiver" {
  api_id                 = aws_apigatewayv2_api.agent_webhook_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webhook_receiver.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_webhook" {
  api_id    = aws_apigatewayv2_api.agent_webhook_api.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook_receiver.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.agent_webhook_api.id
  name        = "$default"
  auto_deploy = true
}

# Autoriza o API Gateway a invocar a Lambda -- sem isso, a rota responde
# 403 mesmo com a integração configurada corretamente.
resource "aws_lambda_permission" "apigateway_invoke_webhook_receiver" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_receiver.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.agent_webhook_api.execution_arn}/*/*"
}
