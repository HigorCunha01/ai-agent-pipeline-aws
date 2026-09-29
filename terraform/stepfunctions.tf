resource "aws_sfn_state_machine" "agent_pipeline" {
  name     = "agent-pipeline${var.project_suffix}"
  role_arn = aws_iam_role.stepfunctions_execution.arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/step_functions/agent-pipeline.asl.json.tftpl", {
    validate_lambda_arn = aws_lambda_function.validate_and_fetch_context.arn
    generate_lambda_arn = aws_lambda_function.generate_and_save_response.arn
    notify_lambda_arn   = aws_lambda_function.notify_response.arn
  })
}
