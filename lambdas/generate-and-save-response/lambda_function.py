import boto3
import time

dynamodb = boto3.resource('dynamodb')
tabela = dynamodb.Table("agent-sessions")


def lambda_handler(event, context):
    """
    Segundo passo do pipeline (chamado pelo Step Functions).

    - Gera a resposta do "agente" (mockada nesta fase — ver Fase 2 no README
      para a versão com Amazon Bedrock).
    - Salva o histórico atualizado da sessão no DynamoDB, com TTL de 24h
      para expiração automática do estado conversacional.
    """
    client_id = event["client_id"]
    session_id = event["session_id"]
    mensagem_usuario = event["message"]
    contexto_sessao = event.get("contexto_sessao", [])

    contexto_sessao.append({"role": "user", "text": mensagem_usuario})

    resposta_agente = (
        f"Recebi sua mensagem: '{mensagem_usuario}'. "
        "Em breve um agente de IA responderá de verdade."
    )
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
