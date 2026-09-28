# Pipeline Assíncrono de Agente de IA na AWS

Infraestrutura assíncrona e desacoplada, no estilo dos webhooks usados por
plataformas de mensageria (WhatsApp/Meta), para orquestrar o processamento
de mensagens de um agente conversacional multi-tenant com IA generativa real
(Amazon Bedrock).

Este é o **Projeto 3** do meu portfólio de Engenharia de Dados/IA na AWS,
construído para aplicar na prática as ferramentas mais pedidas em vagas de
Engenheiro(a) de IA com foco em agentes e infraestrutura AWS: Step Functions,
SQS, SNS, DynamoDB, API Gateway, Amazon Bedrock e IAM com permissões de
menor privilégio.

O projeto foi construído em duas etapas:
- **Fase 1** — toda a infraestrutura assíncrona (fila, orquestração, estado,
  notificação), 100% dentro do AWS Free Tier, com a resposta do agente
  mockada (texto fixo) para validar o fluxo antes de introduzir custo.
- **Fase 2** — a resposta mockada foi substituída por uma chamada real ao
  **Amazon Bedrock** (Converse API, modelo Amazon Nova Micro), com custo por
  token (fora do Free Tier).

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
┌───────────────────────────────────────────────────────────────────┐
│                    Step Functions: agent-pipeline                   │
│                                                                       │
│  ValidarEBuscarContexto → GerarESalvarResposta → Notificar          │
│   (Lambda)                  (Lambda)              (Lambda)          │
│        │                        │  │                    │           │
│        ▼                        │  ▼                    ▼           │
│   DynamoDB (GetItem)            │ Bedrock (Converse)  SNS (Publish) │
│   agent-sessions                │ amazon.nova-micro   agent-response│
│                                  ▼                      -notifications
│                            DynamoDB (PutItem)                       │
│                            agent-sessions                           │
└───────────────────────────────────────────────────────────────────┘
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
| Geração de resposta (IA) | Amazon Bedrock (Converse API, `amazon.nova-micro-v1:0`) | Gera a resposta do agente com base no histórico da sessão |
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
4. **Bedrock**: garanta acesso ao modelo `amazon.nova-micro-v1:0` na região
   `us-east-1` (contas novas da AWS passam por uma verificação automática
   antes de liberar chamadas ao Bedrock — normalmente resolve em até 2h).
5. **SNS**: crie o tópico `agent-response-notifications` e assine seu
   e-mail (confirme a assinatura antes de testar).
6. **Step Functions**: crie a state machine `agent-pipeline` (tipo
   Standard) usando a definição em `step-functions/agent-pipeline.asl.json`
   (ajuste os ARNs das Lambdas).
7. **SQS**: crie a fila `agent-messages-queue` (Standard) e adicione-a
   como trigger da Lambda `start-agent-pipeline`.
8. **API Gateway**: crie uma HTTP API com rota `POST /webhook` integrada
   à Lambda `webhook-receiver`, com deploy no stage `$default`.

### Mapeamento das policies IAM por Lambda

| Lambda | Policy | Motivo |
|---|---|---|
| `validate-and-fetch-context` | `dynamodb-getitem.json` | Ler contexto de sessão anterior |
| `generate-and-save-response` | `dynamodb-putitem.json` + `bedrock-invokemodel.json` | Salvar contexto atualizado e chamar o modelo de IA |
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

### 4. Verificação de conta bloqueando o Bedrock (não é bug do código)

Ao chamar `bedrock.converse(...)` pela primeira vez, a conta retornou:

```
AccessDeniedException: Your account is currently being verified.
Verification normally takes less than 2 hours...
```

Esse é um processo automático da AWS para contas que ainda não usaram
serviços de IA generativa paga (Bedrock) — não está relacionado a
permissões IAM nem ao código. **Resolução**: aguardar a verificação
(nesse caso, resolveu dentro da janela informada) e repetir a chamada.

## Fase 2 — Geração de resposta com Amazon Bedrock

A resposta mockada de `generate-and-save-response` foi substituída por uma
chamada real à **Converse API** do Amazon Bedrock, usando o modelo
`amazon.nova-micro-v1:0` (escolhido pelo custo baixo por token). O histórico
completo da sessão (`contexto_sessao`) é convertido para o formato de
mensagens exigido pela API (papéis `user`/`assistant` alternados) e enviado
a cada chamada, permitindo respostas com continuidade de contexto
multi-turno.

Próximo passo natural (fora do escopo deste repositório por enquanto): uma
base de conhecimento simples via Bedrock Knowledge Bases + Aurora
Serverless/PgVector para RAG, já que esses serviços têm custo mínimo por
hora independente de uso.
