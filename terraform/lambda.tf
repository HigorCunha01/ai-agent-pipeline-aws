# ---------------------------------------------------------------------------
# Cada Lambda é empacotada automaticamente (zip) a partir do código-fonte
# em lambda_src/<nome>/ -- não é preciso subir .zip manualmente.
# ---------------------------------------------------------------------------

data "archive_file" "validate_and_fetch_context" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/validate-and-fetch-context"
  output_path = "${path.module}/.build/validate-and-fetch-context.zip"
}

resource "aws_lambda_function" "validate_and_fetch_context" {
  function_name    = "validate-and-fetch-context${var.project_suffix}"
  role             = aws_iam_role.validate_and_fetch_context.arn
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.validate_and_fetch_context.output_path
  source_code_hash = data.archive_file.validate_and_fetch_context.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.agent_sessions.name
    }
  }
}

data "archive_file" "generate_and_save_response" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/generate-and-save-response"
  output_path = "${path.module}/.build/generate-and-save-response.zip"
}

resource "aws_lambda_function" "generate_and_save_response" {
  function_name    = "generate-and-save-response${var.project_suffix}"
  role             = aws_iam_role.generate_and_save_response.arn
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.generate_and_save_response.output_path
  source_code_hash = data.archive_file.generate_and_save_response.output_base64sha256
  timeout          = 30 # chamada ao Bedrock pode levar mais que o padrão de 3s

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.agent_sessions.name
      MODEL_ID   = var.bedrock_model_id
    }
  }
}

data "archive_file" "notify_response" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/notify-response"
  output_path = "${path.module}/.build/notify-response.zip"
}

resource "aws_lambda_function" "notify_response" {
  function_name    = "notify-response${var.project_suffix}"
  role             = aws_iam_role.notify_response.arn
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.notify_response.output_path
  source_code_hash = data.archive_file.notify_response.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TOPIC_ARN = aws_sns_topic.agent_response_notifications.arn
    }
  }
}

data "archive_file" "start_agent_pipeline" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/start-agent-pipeline"
  output_path = "${path.module}/.build/start-agent-pipeline.zip"
}

resource "aws_lambda_function" "start_agent_pipeline" {
  function_name    = "start-agent-pipeline${var.project_suffix}"
  role             = aws_iam_role.start_agent_pipeline.arn
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.start_agent_pipeline.output_path
  source_code_hash = data.archive_file.start_agent_pipeline.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.agent_pipeline.arn
    }
  }
}

data "archive_file" "webhook_receiver" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/webhook-receiver"
  output_path = "${path.module}/.build/webhook-receiver.zip"
}

resource "aws_lambda_function" "webhook_receiver" {
  function_name    = "webhook-receiver${var.project_suffix}"
  role             = aws_iam_role.webhook_receiver.arn
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.webhook_receiver.output_path
  source_code_hash = data.archive_file.webhook_receiver.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      QUEUE_URL      = aws_sqs_queue.agent_messages_queue.url
      WEBHOOK_SECRET = var.webhook_secret
    }
  }
}
