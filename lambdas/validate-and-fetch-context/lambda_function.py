import boto3

dynamodb = boto3.resource('dynamodb')
tabela = dynamodb.Table("agent-sessions")


def lambda_handler(event, context):
    """
    Primeiro passo do pipeline (chamado pelo Step Functions).

    - Valida se a mensagem recebida tem os campos obrigatórios.
    - Busca o contexto de sessões anteriores no DynamoDB (se existir),
      para dar continuidade a uma conversa já iniciada (multi-turno).
    """
    campos_obrigatorios = ["client_id", "session_id", "message"]

    dados_recebidos = event if event else {}

    campos_com_erro = []
    for campo in campos_obrigatorios:
        if campo not in dados_recebidos or dados_recebidos[campo] in [None, ""]:
            campos_com_erro.append(campo)

    if campos_com_erro:
        raise ValueError(f"Campos ausentes ou vazios: {campos_com_erro}")

    resposta = tabela.get_item(
        Key={
            "client_id": dados_recebidos["client_id"],
            "session_id": dados_recebidos["session_id"]
        }
    )

    contexto_sessao = []
    if "Item" in resposta:
        contexto_sessao = resposta["Item"].get("context", [])

    dados_recebidos["contexto_sessao"] = contexto_sessao

    return dados_recebidos
