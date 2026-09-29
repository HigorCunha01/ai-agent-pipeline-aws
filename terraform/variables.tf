variable "aws_region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project_suffix" {
  description = "Sufixo aplicado a todos os nomes de recurso, para rodar em paralelo à versão manual do projeto sem conflitar nomes."
  type        = string
  default     = "-tf"
}

variable "notification_email" {
  description = "E-mail que receberá as notificações do SNS. Passe via -var ou terraform.tfvars (não commitado)."
  type        = string
}

variable "bedrock_model_id" {
  description = "ID do modelo do Amazon Bedrock usado para gerar a resposta do agente."
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "webhook_secret" {
  description = "Segredo compartilhado exigido no header x-webhook-secret para chamar POST /webhook. Gere um valor aleatorio forte e passe via terraform.tfvars (nao commitado)."
  type        = string
  sensitive   = true
}
