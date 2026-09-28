import boto3
import json

sqs = boto3.client('sqs')
QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/<AWS_ACCOUNT_ID>/agent-messages-queue"


def lambda_handler(event, context):
    """
    Lambda exposta via API Gateway (POST /webhook).

    Recebe a requisicao HTTP, enfileira a mensagem no SQS e responde
    imediatamente com 200 -- desacoplando o recebimento do webhook do
    processamento real (feito de forma assincrona pelo restante do
    pipeline).
    """
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
