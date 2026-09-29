resource "aws_sns_topic" "agent_response_notifications" {
  name = "agent-response-notifications${var.project_suffix}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.agent_response_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email

  # A confirmação da assinatura por e-mail é sempre manual (clique no link
  # que a AWS envia) -- o Terraform cria a assinatura, mas não consegue
  # confirmá-la por você.
}
