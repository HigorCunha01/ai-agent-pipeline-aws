import boto3

sns = boto3.client('sns')
TOPIC_ARN = "arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:agent-response-notifications"


def lambda_handler(event, context):
    """
    Terceiro e ultimo passo do pipeline (chamado pelo Step Functions).

    Publica uma notificacao no SNS avisando que a resposta do agente
    esta pronta -- simula o callback que, em producao, avisaria o
    WhatsApp/Meta (ou outro canal) que ha uma resposta disponivel.
    """
    client_id = event["client_id"]
    session_id = event["session_id"]
    resposta_agente = event["resposta_agente"]

    mensagem = f"Cliente {client_id} (sessão {session_id}) recebeu a resposta: {resposta_agente}"

    sns.publish(
        TopicArn=TOPIC_ARN,
        Message=mensagem,
        Subject="Nova resposta do agente"
    )

    return {"status": "notificado"}
