# ---------------------------------------------------------------------------
# Trust policy comum: permite que o serviço Lambda assuma a role.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "states_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# validate-and-fetch-context: GetItem no DynamoDB
# ---------------------------------------------------------------------------
resource "aws_iam_role" "validate_and_fetch_context" {
  name               = "validate-and-fetch-context${var.project_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "validate_and_fetch_context_basic" {
  role       = aws_iam_role.validate_and_fetch_context.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "validate_and_fetch_context_dynamodb" {
  name = "dynamodb-getitem"
  role = aws_iam_role.validate_and_fetch_context.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "dynamodb:GetItem"
      Resource = aws_dynamodb_table.agent_sessions.arn
    }]
  })
}

# ---------------------------------------------------------------------------
# generate-and-save-response: PutItem no DynamoDB + InvokeModel no Bedrock
# ---------------------------------------------------------------------------
resource "aws_iam_role" "generate_and_save_response" {
  name               = "generate-and-save-response${var.project_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "generate_and_save_response_basic" {
  role       = aws_iam_role.generate_and_save_response.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "generate_and_save_response_dynamodb" {
  name = "dynamodb-putitem"
  role = aws_iam_role.generate_and_save_response.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "dynamodb:PutItem"
      Resource = aws_dynamodb_table.agent_sessions.arn
    }]
  })
}

resource "aws_iam_role_policy" "generate_and_save_response_bedrock" {
  name = "bedrock-invokemodel"
  role = aws_iam_role.generate_and_save_response.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "bedrock:InvokeModel"
      Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
    }]
  })
}

# ---------------------------------------------------------------------------
# notify-response: Publish no SNS
# ---------------------------------------------------------------------------
resource "aws_iam_role" "notify_response" {
  name               = "notify-response${var.project_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "notify_response_basic" {
  role       = aws_iam_role.notify_response.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "notify_response_sns" {
  name = "sns-publish"
  role = aws_iam_role.notify_response.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.agent_response_notifications.arn
    }]
  })
}

# ---------------------------------------------------------------------------
# start-agent-pipeline: consumir SQS + iniciar execução do Step Functions
# ---------------------------------------------------------------------------
resource "aws_iam_role" "start_agent_pipeline" {
  name               = "start-agent-pipeline${var.project_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "start_agent_pipeline_basic" {
  role       = aws_iam_role.start_agent_pipeline.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "start_agent_pipeline_sqs" {
  name = "sqs-consume"
  role = aws_iam_role.start_agent_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.agent_messages_queue.arn
    }]
  })
}

resource "aws_iam_role_policy" "start_agent_pipeline_states" {
  name = "states-startexecution"
  role = aws_iam_role.start_agent_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.agent_pipeline.arn
    }]
  })
}

# ---------------------------------------------------------------------------
# webhook-receiver: SendMessage no SQS
# ---------------------------------------------------------------------------
resource "aws_iam_role" "webhook_receiver" {
  name               = "webhook-receiver${var.project_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "webhook_receiver_basic" {
  role       = aws_iam_role.webhook_receiver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "webhook_receiver_sqs" {
  name = "sqs-sendmessage"
  role = aws_iam_role.webhook_receiver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.agent_messages_queue.arn
    }]
  })
}

# ---------------------------------------------------------------------------
# Role de execução do Step Functions: invocar as 3 Lambdas do pipeline
# ---------------------------------------------------------------------------
resource "aws_iam_role" "stepfunctions_execution" {
  name               = "stepfunctions-agent-pipeline${var.project_suffix}-role"
  assume_role_policy = data.aws_iam_policy_document.states_assume_role.json
}

resource "aws_iam_role_policy" "stepfunctions_lambda_invoke" {
  name = "lambda-invoke"
  role = aws_iam_role.stepfunctions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "lambda:InvokeFunction"
      Resource = [
        aws_lambda_function.validate_and_fetch_context.arn,
        aws_lambda_function.generate_and_save_response.arn,
        aws_lambda_function.notify_response.arn,
      ]
    }]
  })
}
