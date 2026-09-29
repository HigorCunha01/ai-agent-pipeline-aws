import os
import time
import boto3

dynamodb = boto3.resource('dynamodb')
tabela = dynamodb.Table(os.environ["TABLE_NAME"])

bedrock = boto3.client("bedrock-runtime")
MODEL_ID = os.environ["MODEL_ID"]


def lambda_handler(event, context):
    """
    Segundo passo do pipeline (chamado pelo Step Functions).

    Gera a resposta do agente chamando o Amazon Bedrock (Converse API)
    com o historico completo da sessao, e salva o contexto atualizado
    no DynamoDB, com TTL de 24h para expiracao automatica.
    """
    client_id = event["client_id"]
    session_id = event["session_id"]
    mensagem_usuario = event["message"]
    contexto_sessao = event.get("contexto_sessao", [])

    contexto_sessao.append({"role": "user", "text": mensagem_usuario})

    mensagens = []
    for turno in contexto_sessao:
        papel = "user" if turno["role"] == "user" else "assistant"
        mensagens.append({
            "role": papel,
            "content": [{"text": turno["text"]}]
        })

    resposta_bedrock = bedrock.converse(
        modelId=MODEL_ID,
        messages=mensagens,
        inferenceConfig={"maxTokens": 512, "temperature": 0.5}
    )

    resposta_agente = resposta_bedrock["output"]["message"]["content"][0]["text"]

    contexto_sessao.append({"role": "agent", "text": resposta_agente})

    ttl_expiracao = int(time.time()) + (24 * 60 * 60)

    tabela.put_item(Item={
        "client_id": client_id,
        "session_id": session_id,
        "contexto": contexto_sessao,
        "ttl": ttl_expiracao
    })

    return {
        "client_id": client_id,
        "session_id": session_id,
        "resposta_agente": resposta_agente
    }
