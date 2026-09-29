# Versão Terraform (Infraestrutura como Código)

Esta pasta recria **exatamente a mesma arquitetura** descrita no README
principal do repositório — API Gateway → SQS → Step Functions → DynamoDB +
Bedrock → SNS — só que provisionada via código (Terraform) em vez de
clique-a-clique no console AWS.

Os recursos são criados com sufixo `-tf` (ex: `agent-sessions-tf`), para
rodar em paralelo à versão manual sem conflito de nomes.

## Por que isso importa

A versão manual (documentada no README principal) tem uma limitação
conhecida: o atributo `ttl` era gravado pela Lambda, mas a exclusão
automática nunca foi habilitada de fato na tabela DynamoDB — teria que ser
feito manualmente no console, e não foi. Nesta versão Terraform, isso é
corrigido: o bloco `ttl` da tabela é declarado como código
(`dynamodb.tf`), então toda vez que a infraestrutura é recriada, a TTL
já vem habilitada — sem depender de um passo manual esquecível.

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- AWS CLI configurado (`aws configure`) com credenciais que tenham
  permissão para criar os recursos (IAM, Lambda, DynamoDB, SQS, SNS,
  Step Functions, API Gateway).
- Acesso ao modelo `amazon.nova-micro-v1:0` liberado no Bedrock, na
  região `us-east-1` (ver Troubleshooting #4 no README principal).

## Como usar

```bash
cd terraform

# 1. Configure seu e-mail de notificação e o segredo do webhook
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars: seu e-mail real + um valor forte para webhook_secret
# (gere um, por ex: openssl rand -hex 20)

# 2. Inicialize (baixa os providers AWS e archive)
terraform init

# 3. Revise o plano -- mostra tudo que será criado, sem aplicar nada ainda
terraform plan

# 4. Aplique
terraform apply
```

Depois do `apply`:

1. **Confirme a assinatura do SNS** — chega um e-mail da AWS com um link
   de confirmação; sem clicar nele, as notificações não chegam.
2. O output `webhook_url` mostra a URL pública do endpoint. A rota exige o
   segredo configurado em `webhook_secret` no header `x-webhook-secret` —
   sem ele, a Lambda responde `401` antes de enfileirar qualquer coisa (ver
   [Segurança do webhook](../README.md#segurança-do-webhook) no README
   principal). Teste com:

```bash
curl -X POST <webhook_url> \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: <seu-segredo>" \
  -d '{"client_id": "cliente_1", "session_id": "sessao_1", "message": "oi"}'
```

3. Confira no console (ou via CLI) que uma nova execução apareceu na state
   machine `agent-pipeline-tf` e que o e-mail de notificação chegou.

## Destruindo o ambiente

Como o objetivo deste ambiente paralelo é demonstrar a competência em IaC
(não manter dois pipelines rodando ao mesmo tempo), depois de validar que
tudo funciona é recomendado destruir para não gerar custo com o Bedrock
por chamadas futuras esquecidas:

```bash
terraform destroy
```

## Diferenças em relação à versão manual

| Aspecto | Versão manual (console) | Versão Terraform |
|---|---|---|
| Configuração de recursos | Cliques no console AWS | Código declarativo (`.tf`) |
| ARNs/nomes de recurso | Colados manualmente no código de cada Lambda | Injetados automaticamente via variáveis de ambiente (`os.environ`) |
| TTL do DynamoDB | Atributo gravado, mas exclusão automática nunca habilitada | Habilitada por código (`ttl { enabled = true }`) |
| Permissão do API Gateway para invocar a Lambda | Criada implicitamente pelo console | Declarada explicitamente (`aws_lambda_permission`) |
| Reprodutibilidade | Manual, sujeita a esquecimento de passos | `terraform apply` recria tudo de forma idêntica |
| Autenticação do webhook | Rota pública sem autenticação | Segredo compartilhado (`x-webhook-secret`), validado na Lambda antes de enfileirar |
