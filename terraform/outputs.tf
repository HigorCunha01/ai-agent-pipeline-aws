output "webhook_url" {
  description = "URL pública do endpoint do webhook. Use com POST e um corpo JSON."
  value       = "${aws_apigatewayv2_api.agent_webhook_api.api_endpoint}/webhook"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.agent_sessions.name
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.agent_pipeline.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.agent_response_notifications.arn
}
