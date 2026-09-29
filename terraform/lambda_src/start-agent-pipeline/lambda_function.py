import os
import json
import boto3

sfn = boto3.client('stepfunctions')
STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]


def lambda_handler(event, context):
    """
    Lambda acionada pela fila SQS.

    Para cada mensagem recebida no lote, inicia uma execucao da
    state machine do pipeline passando o corpo da mensagem como input.
    """
    for registro in event["Records"]:
        corpo_mensagem = json.loads(registro["body"])

        sfn.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            input=json.dumps(corpo_mensagem)
        )

    return {"status": "execuções iniciadas"}
