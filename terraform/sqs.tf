resource "aws_sqs_queue" "agent_messages_queue" {
  name = "agent-messages-queue${var.project_suffix}"
}

resource "aws_lambda_event_source_mapping" "sqs_to_start_agent_pipeline" {
  event_source_arn = aws_sqs_queue.agent_messages_queue.arn
  function_name    = aws_lambda_function.start_agent_pipeline.arn
  batch_size       = 1
}
