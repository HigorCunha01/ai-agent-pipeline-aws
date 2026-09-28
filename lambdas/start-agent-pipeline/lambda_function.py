import boto3
import json

sfn = boto3.client('stepfunctions')
STATE_MACHINE_ARN = "arn:aws:states:us-east-1:<AWS_ACCOUNT_ID>:stateMachine:agent-pipeline"


def lambda_handler(event, context):
    """
    Lambda acionada pela fila SQS (agent-messages-queue).

    Para cada mensagem recebida no lote, inicia uma execucao da
    state machine 'agent-pipeline' passando o corpo da mensagem
    como input.
    """
    for registro in event["Records"]:
        corpo_mensagem = json.loads(registro["body"])

        sfn.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            input=json.dumps(corpo_mensagem)
        )

    return {"status": "execuções iniciadas"}
