resource "aws_dynamodb_table" "agent_sessions" {
  name         = "agent-sessions${var.project_suffix}"
  billing_mode = "PAY_PER_REQUEST" # sem custo fixo -- cobra só pelo uso, dentro do Free Tier em volumes baixos

  hash_key  = "client_id"
  range_key = "session_id"

  attribute {
    name = "client_id"
    type = "S"
  }

  attribute {
    name = "session_id"
    type = "S"
  }

  # Diferente da versão manual (onde o atributo "ttl" era gravado pela
  # Lambda mas a expiração automática nunca foi de fato habilitada na
  # tabela), aqui a TTL é habilitada via código -- o Terraform corrige
  # essa lacuna documentada no README da Fase 1.
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
