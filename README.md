# Pipeline Assíncrono de Agente de IA na AWS (Fase 1 — infraestrutura serverless)

Infraestrutura assíncrona e desacoplada, no estilo dos webhooks usados por
plataformas de mensageria (WhatsApp/Meta), para orquestrar o processamento
de mensagens de um agente conversacional multi-tenant. Construída inteiramente
no AWS Free Tier.

Este é o **Projeto 3** do meu portfólio de Engenharia de Dados/IA na AWS,
construído para aplicar na prática as ferramentas mais pedidas em vagas de
Engenheiro(a) de IA com foco em agentes e infraestrutura AWS: Step Functions,
SQS, SNS, DynamoDB, API Gateway e IAM com permissões de menor privilégio.

> **Sobre a resposta do "agente" nesta fase**: a geração da resposta está
> mockada (retorna um texto fixo) — o foco desta fase é a infraestrutura
> assíncrona em si (fila, orquestração, estado, notificação), que é o que
> sustenta um agente de IA real em produção. A Fase 2 (ver seção abaixo)
> substitui esse mock por uma chamada real ao Amazon Bedrock.

## Arquitetura

```
Cliente HTTP (curl / WhatsApp / etc.)
        │  POST /webhook
        ▼
┌─────────────────┐
│   API Gateway    │  (HTTP API)
└────────┬─────────┘
         ▼
┌─────────────────────┐
│ Lambda: webhook-     │  responde 200 imediatamente,
│ receiver             │  enfileira a mensagem
└────────┬─────────────┘
         ▼
┌─────────────────┐
│   SQS Queue       │  agent-messages-queue
│ agent-messages-  │  (buffer/desacoplamento)
│ queue            │
└────────┬─────────┘
         ▼  (event source mapping)
┌──────────────────────┐
│ Lambda:               │  consome a fila, inicia
│ start-agent-pipeline  │  a execução do Step Functions
└────────┬──────────────┘
         ▼
┌─────────────────────────────────────────────────────────┐
│              Step Functions: agent-pipeline               │
│                                                             │
│  ValidarEBuscarContexto → GerarESalvarResposta → Notificar │
│   (Lambda)                  (Lambda)              (Lambda) │
│        │                        │                     │    │
│        ▼                        ▼                     ▼    │
│   DynamoDB (GetItem)     DynamoDB (PutItem)      SNS (Publish)
│   agent-sessions          agent-sessions      agent-response-
│                                                  notifications
└─────────────────────────────────────────────────────────┘
                                                       │
                                                       ▼
                                              E-mail de notificação
                                          (simula callback ao canal
                                           de origem, ex: WhatsApp)
```

## Stack

| Componente | Serviço AWS | Função |
|---|---|---|
| Entrada HTTP | API Gateway (HTTP API) | Expõe `POST /webhook` publicamente |
| Recepção rápida | Lambda (`webhook-receiver`) | Responde 200 e enfileira, sem bloquear o cliente |
| Buffer/desacoplamento | SQS (`agent-messages-queue`) | Absorve picos e desacopla recepção do processamento |
| Disparo da orquestração | Lambda (`start-agent-pipeline`) | Consome SQS e inicia a state machine |
| Orquestração | Step Functions (`agent-pipeline`, Standard) | Encadeia os 3 passos do pipeline |
| Estado conversacional | DynamoDB (`agent-sessions`) | Multi-tenant (`client_id` + `session_id`), com TTL de 24h |
| Notificação | SNS (`agent-response-notifications`) | Avisa que a resposta está pronta (e-mail nesta fase) |
| Permissões | IAM (policies inline por Lambda) | Least privilege — cada função só acessa o que precisa |

## Design multi-tenant e de estado

A tabela DynamoDB usa chave composta **`client_id` (partition key) +
`session_id` (sort key)**, permitindo múltiplos clientes e múltiplas
conversas simultâneas por cliente, isoladas entre si — mapeando direto para
o requisito de "design de sistemas multi-tenant (isolamento por
client_id/company_id)" comum em vagas de agentes de IA.

Cada item também carrega um atributo `ttl` (Unix timestamp, 24h no futuro),
usado para expirar automaticamente sessões antigas — simulando "esquecer"
conversas inativas.

> **Nota**: nesta fase o atributo `ttl` é escrito pela Lambda, mas a
> configuração de TTL do DynamoDB (que faz a exclusão automática de fato)
> ainda não foi habilitada na tabela — é um ajuste pendente antes de
> considerar essa expiração como "ativa" em produção.

## Setup (reprodução manual, via console AWS)

Este projeto foi construído manualmente no console da AWS para fins de
aprendizado, não via IaC (Infrastructure as Code). Para reproduzir:

1. **DynamoDB**: crie a tabela `agent-sessions` com partition key `client_id`
   (String) e sort key `session_id` (String).
2. **Lambdas**: crie as 5 funções em `lambdas/` (runtime Python 3.13),
   colando o código de cada pasta. Ajuste os ARNs/URLs marcados como
   `<AWS_ACCOUNT_ID>` para o ID da sua conta.
3. **IAM**: para cada Lambda, adicione a policy inline correspondente em
   `iam-policies/` à sua role de execução (veja o mapeamento abaixo).
4. **SNS**: crie o tópico `agent-response-notifications` e assine seu
   e-mail (confirme a assinatura antes de testar).
5. **Step Functions**: crie a state machine `agent-pipeline` (tipo
   Standard) usando a definição em `step-functions/agent-pipeline.asl.json`
   (ajuste os ARNs das Lambdas).
6. **SQS**: crie a fila `agent-messages-queue` (Standard) e adicione-a
   como trigger da Lambda `start-agent-pipeline`.
7. **API Gateway**: crie uma HTTP API com rota `POST /webhook` integrada
   à Lambda `webhook-receiver`, com deploy no stage `$default`.

### Mapeamento das policies IAM por Lambda

| Lambda | Policy | Motivo |
|---|---|---|
| `validate-and-fetch-context` | `dynamodb-getitem.json` | Ler contexto de sessão anterior |
| `generate-and-save-response` | `dynamodb-putitem.json` | Salvar contexto atualizado |
| `notify-response` | `sns-publish.json` | Publicar notificação |
| `start-agent-pipeline` | `sqs-consume.json` + `states-startexecution.json` | Consumir a fila e iniciar a state machine |
| `webhook-receiver` | `sqs-sendmessage.json` | Enfileirar mensagem recebida |
| Role de execução do Step Functions | `stepfunctions-execution-role_lambda-invoke.json` | Invocar as 3 Lambdas do pipeline |

## Teste end-to-end

```bash
curl -X POST https://<sua-api>.execute-api.us-east-1.amazonaws.com/webhook \
  -H "Content-Type: application/json" \
  -d '{"client_id": "cliente_1", "session_id": "sessao_1", "message": "oi, preciso de ajuda"}'
```

Resposta esperada: `{"status": "mensagem recebida"}`, seguida (assíncrona)
de uma nova execução "Succeeded" em Step Functions e um e-mail via SNS.

## Troubleshooting (bugs reais encontrados e corrigidos)

### 1. ARN da role colado no lugar do ARN da state machine

A variável `STATE_MACHINE_ARN` na Lambda `start-agent-pipeline` foi
acidentalmente preenchida com o ARN da **role de execução do Step
Functions** (`arn:aws:iam::...:role/service-role/...`) em vez do ARN da
**state machine** (`arn:aws:states:...:stateMachine:agent-pipeline`).

O erro reportado pelo `start_execution` foi enganoso à primeira vista:

```
InvalidArn: Arn missing resource component:
arn:aws:iam::...:role/service-role/StepFunctions-agent-pipeline-role-...
```

O Step Functions valida o `stateMachineArn` esperando o formato
`arn:aws:states:regiao:conta:stateMachine:nome` (recurso separado por `:`).
Como o ARN de IAM usa `/` em vez de `:` para separar o recurso, a validação
falhou com essa mensagem genérica — o que mascarou a causa real (variável
com o valor errado). **Correção**: substituir o valor de `STATE_MACHINE_ARN`
pelo ARN correto da state machine.

### 2. Permissão IAM faltando para iniciar a execução

Mesmo com o ARN corrigido, a chamada `sfn.start_execution(...)` continuou
falhando:

```
AccessDeniedException: ... is not authorized to perform: states:StartExecution
on resource: arn:aws:states:...:stateMachine:agent-pipeline because no
identity-based policy allows the states:StartExecution action
```

A role de execução da Lambda `start-agent-pipeline` tinha permissão para
consumir mensagens do SQS, mas não para chamar `states:StartExecution` na
state machine. **Correção**: adicionar a policy inline
`states-startexecution.json`, escopada ao ARN exato da state machine
(princípio do menor privilégio).

### 3. Escaping de JSON quebrado no PowerShell + curl

Ao testar o webhook via `curl.exe` no PowerShell (Windows), o corpo da
requisição chegava corrompido:

```
[ERROR] JSONDecodeError: Expecting property name enclosed in double quotes
```

O PowerShell não trata `\"` dentro de aspas simples do mesmo jeito que um
shell Unix — os caracteres de escape chegavam literalmente no corpo da
requisição, invalidando o JSON. **Correção**: escrever o payload em um
arquivo (`body.json`) e usar `curl.exe -d "@body.json"`, evitando por
completo o problema de escaping de aspas do shell.

## Fase 2 (próximos passos, não incluída neste ponto do repositório)

Substituir a resposta mockada em `generate-and-save-response` por uma
chamada real à API Converse do **Amazon Bedrock**, com uma base de
conhecimento simples (RAG) — este passo tem custo (Bedrock é cobrado por
token) e por isso foi feito de forma isolada e controlada, fora do escopo
100% gratuito desta Fase 1.
