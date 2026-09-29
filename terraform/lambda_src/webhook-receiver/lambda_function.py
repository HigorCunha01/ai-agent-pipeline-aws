import os
import json
import hmac
import boto3

sqs = boto3.client('sqs')
QUEUE_URL = os.environ["QUEUE_URL"]
WEBHOOK_SECRET = os.environ["WEBHOOK_SECRET"]


def lambda_handler(event, context):
    """
    Lambda exposta via API Gateway (POST /webhook).

    Recebe a requisicao HTTP, valida um segredo compartilhado enviado no
    header (protege a rota publica contra chamadas nao autorizadas),
    enfileira a mensagem no SQS e responde imediatamente com 200.
    """
    headers_recebidos = {
        chave.lower(): valor for chave, valor in (event.get("headers") or {}).items()
    }
    segredo_recebido = headers_recebidos.get("x-webhook-secret", "")

    if not hmac.compare_digest(segredo_recebido, WEBHOOK_SECRET):
        return {
            "statusCode": 401,
            "body": json.dumps({"status": "nao autorizado"})
        }

    corpo = event.get("body", {})
    if isinstance(corpo, str):
        dados_recebidos = json.loads(corpo)
    else:
        dados_recebidos = corpo if corpo else {}

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(dados_recebidos)
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"status": "mensagem recebida"})
    }
