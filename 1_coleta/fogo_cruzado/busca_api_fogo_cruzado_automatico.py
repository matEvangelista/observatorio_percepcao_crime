# lendo libraries
import requests
import re
from datetime import date, timedelta, datetime
import pandas as pd
import json
from shapely.geometry import Point
from functools import reduce
from dotenv import load_dotenv
import os
import uuid

load_dotenv()

# parâmetros da requisição
EMAIL_API = os.getenv('EMAIL_API')
SENHA_API = os.getenv('SENHA_API')
PARAMETROS = {'email': EMAIL_API, 'password': SENHA_API}
COLUNAS_DO_BANCO = ['id_ocorrencia', 'local_ocorrencia', 'latitude_ocorrencia', 'longitude_ocorrencia',
                    'data_ocorrencia', 'hora_ocorrencia',
                    'presen_agen_segur_ocorrencia', 'qtd_morto_civil_ocorrencia', 'qtd_morto_agen_segur_ocorrencia',
                    'qtd_ferido_civil_ocorrencia',
                    'qtd_ferido_agen_segur_ocorrencia', 'estado_id', 'cidade_id', 'nome_cidade', 'cod_ibge_cidade',
                    'gentilico_cidade', 'populacao_cidade',
                    'area_cidade', 'densidade_demo_cidade', 'nome_estado', 'uf_estado', 'cod_ibge_estado',
                    'homem_qtd_mortos_oc', 'homem_qtd_feridos_oc',
                    'mulher_qtd_mortos_oc', 'mulher_qtd_feridos_oc', 'chacina_oc', 'chacina_qtd_mortos_oc',
                    'chacina_unidades_policiais_oc', 'ag_seguranca_vitima_oc',
                    'ag_seguranca_mortos_status_oc', 'ag_seguranca_feridos_status_oc', 'bala_perdida_oc',
                    'bala_perdida_qtd_mortos_oc', 'bala_perdida_qtd_feridos_oc',
                    'interior_residencia_oc', 'interior_residencia_qtd_mortos_oc', 'interior_residencia_qtd_feridos_oc',
                    'imediacao_ensino_oc', 'imediacao_ensino_qtd_mortos_oc',
                    'imediacao_ensino_qtd_feridos_oc', 'vitima_crianca_oc', 'vitima_crianca_qtd_mortos_oc',
                    'info_adicional_crianca_morta_oc', 'vitima_crianca_qtd_feridos_oc',
                    'info_adicional_crianca_ferida_oc', 'vitima_adolescente_oc', 'vitima_adolescente_qtd_mortos_oc',
                    'info_adicional_adolescente_morto_oc', 'vitima_adolescente_qtd_feridos_oc',
                    'info_adicional_adolescente_ferido_oc', 'vitima_idoso_oc', 'vitima_idoso_qtd_mortos_oc',
                    'info_adicional_idoso_morto_oc', 'vitima_idoso_qtd_feridos_oc',
                    'info_adicional_idoso_ferido_oc', 'informacao_via_oc', 'descricao_via_interrompida_oc',
                    'data_interrupcao_via_oc', 'data_liberacao_via_oc',
                    'outros_recortes', 'motivo_principal', 'motivo_complementar', 'geometry', 'timestamp_ocorrencia',
                    'dia_ocorrencia', 'mes_ocorrencia',
                    'mes_ocorrencia_numero', 'ano_ocorrencia', 'dia_semana_ocorrencia']

MESES_EM_PORTUGUES = {
    1: "Janeiro",
    2: "Fevereiro",
    3: "Março",
    4: "Abril",
    5: "Maio",
    6: "Junho",
    7: "Julho",
    8: "Agosto",
    9: "Setembro",
    10: "Outubro",
    11: "Novembro",
    12: "Dezembro"
}

DIAS_DA_SEMANA = {
    0: 'Segunda-feira',
    1: 'Terça-feira',
    2: 'Quarta-feira',
    3: 'Quinta-feira',
    4: 'Sexta-feira',
    5: 'Sábado',
    6: 'Domingo'
}

with open('dados_municipio.json', 'r+', encoding='utf-8') as f:
    DADOS_MUNICIPIOS = json.load(f)


# post para ter o token
def retorna_token() -> str:
    """Função que retorna token para ser utilizada na API.
    Deve ser gerada todas as vezes em que se deseja fazer uma consulta. Dura 2 minutos.
    Returns:
        str: Token
    """
    req = requests.post('https://api-service.fogocruzado.org.br/api/v2/auth/login', PARAMETROS)
    token = req.json()['data']['accessToken']
    return token


TOKEN = retorna_token()


# parâmetros da requisição
def parametros(n_pagina: int, intervalo: int) -> dict:
    """Função que retorna um dicionário de parâmetros para métodos get da api
    param n_pagina: número de páginas que a resposta da api tem. Valor-padrão: 1. Assume-se que esta é a quantidade de páginas
    param intervalo: número de dias anteriores à consulta atual que de deseja incluir
    returns dict: dicionário com parâmetros da requisição
    """
    id_rj = 'b112ffbe-17b3-4ad0-8f2a-2038745d1d14'
    par = {'idState': id_rj,
           'page': n_pagina, 'finaldate': date.today(),
           'initialdate': date.today() - timedelta(days=intervalo)}
    return par


# função para fazer requisição
def faz_requisicao(posicao_pagina: int = 1, interalo_dias: int = 1) -> dict:
    """Função para fazer a requisição de uma página

    Args:
        posicao_pagina (int, optional): Posição da página. Defaults to 1.
        interalo_dias (int, optional): Posição da página. Defaults to 1.

    Returns:
        dict: dados da requisicao
    """
    data = requests.get('https://api-service.fogocruzado.org.br/api/v2/occurrences',
                        headers={'Authorization': f'Bearer {TOKEN}'},
                        params=parametros(n_pagina=posicao_pagina, intervalo=interalo_dias)).json()
    return data


# função para definir tamanho da iteração
def qtd_paginas(retorno_api_pagina_1: dict) -> int:
    """Função que retorna o número de páginas que devem ser iteradas para obter todos os resultados

    Returns:
        int: número de páginas de resposta da API
    """
    qtd = retorno_api_pagina_1['pageMeta']['pageCount']
    return qtd


# fazer todas requicoes possíveis
def retorna_busca_completa(intervalo_dias: int = 1) -> list:
    # lista vazia à qual serão adicionados dados
    dados = []
    req_inicial = faz_requisicao(interalo_dias=intervalo_dias)
    n_paginas = qtd_paginas(req_inicial)
    dados += req_inicial['data']
    for i in range(2, n_paginas + 1):
        dados += faz_requisicao(i, intervalo_dias)['data']
    return dados


def gera_dicionario_molde() -> dict:
    """Função que gera o número do dicionário a partir do qual o data frame será gerado

    Returns:
        dict: dicionário aos moldes das colunas do banco
    """
    dicionario = {x: [] for x in COLUNAS_DO_BANCO}
    return dicionario


def informacoes_vitimas_idade(vitimas: list) -> dict:
    """Função para retornar dados importantes sobre vítimas separadas por idade

    Args:
        vitimas (list): lista de vitimas

    Returns:
        dict: dicionario com as chaves 'vitima_idade(_qtd_mortos/feridos)_oc'
    """

    resultado = dict()

    for faixa_etaria in ['criança', 'adolescente', 'idoso']:
        faixa_etaria_corrigido = 'crianca' if faixa_etaria == 'criança' else faixa_etaria
        masculino_feminio = "a" if faixa_etaria_corrigido == 'crianca' else "o"
        if len(vitimas) == 0:
            resultado[f'vitima_{faixa_etaria_corrigido}_oc'] = "Não"
            resultado[f'vitima_{faixa_etaria_corrigido}_qtd_mortos_oc'] = 0
            resultado[f'vitima_{faixa_etaria_corrigido}_qtd_feridos_oc'] = 0
            resultado[f'info_adicional_{faixa_etaria_corrigido}_ferid{masculino_feminio}_oc'] = pd.NA
            resultado[f'info_adicional_{faixa_etaria_corrigido}_mort{masculino_feminio}_oc'] = pd.NA
            continue

        vitimas_da_faixa_etaria = [x for x in vitimas if x['ageGroup']['name'].lower() == faixa_etaria]
        houve_vitima = "Sim" if len(vitimas_da_faixa_etaria) > 0 else "Não"
        vitimas_mortas = [vit for vit in vitimas_da_faixa_etaria if vit['situation'] == 'Dead']
        qtd_vitimas_mortas = len(vitimas_mortas)
        vitimas_feridas = [vit for vit in vitimas_da_faixa_etaria if vit['situation'] == 'Wounded']
        qtd_vitimas_feridas = len(vitimas_feridas)
        info_adicional_morto = ".".join(
            [x['circumstances'][i]['name'] for x in vitimas_mortas for i in range(len(x['circumstances']))])
        info_adicional_ferido = ".".join(
            [x['circumstances'][i]['name'] for x in vitimas_feridas for i in range(len(x['circumstances']))])

        resultado[f'info_adicional_{faixa_etaria_corrigido}_ferid{masculino_feminio}_oc'] = info_adicional_ferido
        resultado[f'info_adicional_{faixa_etaria_corrigido}_mort{masculino_feminio}_oc'] = info_adicional_morto
        resultado[f'vitima_{faixa_etaria_corrigido}_oc'] = houve_vitima,
        resultado[f'vitima_{faixa_etaria_corrigido}_qtd_mortos_oc'] = qtd_vitimas_mortas
        resultado[f'vitima_{faixa_etaria_corrigido}_qtd_feridos_oc'] = qtd_vitimas_feridas
        resultado

    return resultado


# civis e agentes
def informacoes_vitimas_cargo(vitimas: list) -> dict:
    """Funcao para retornar dados de mortes e feridos de civis e agentes

    Args:
        vitimas (dict): "Lista de vítimas"

    Returns:
        dict: Resultado de qtd_(morto/ferido)_(civil/agen_segur)
    """

    cargos_nomes = {'civil': 'Civilian', 'agen_segur': 'Agent'}

    resultado = {}

    for cargo in cargos_nomes.keys():
        if len(vitimas) == 0:
            resultado[f'qtd_morto_{cargo}_ocorrencia'] = 0
            resultado[f'qtd_ferido_{cargo}_ocorrencia'] = 0
            continue
        cargo_corrente = [x for x in vitimas if x['personType'] == cargos_nomes[cargo]]
        qtd_morto_cargo = len([x for x in cargo_corrente if x['situation'] == 'Dead'])
        qtd_ferido_cargo = len([x for x in cargo_corrente if x['situation'] == 'Wounded'])
        resultado[f'qtd_morto_{cargo}_ocorrencia'] = qtd_morto_cargo
        resultado[f'qtd_ferido_{cargo}_ocorrencia'] = qtd_ferido_cargo

    resultado['ag_seguranca_feridos_status_oc'] = '.'.join(
        [x['agentStatus']['name'] for x in vitimas if x['situation'] == 'Wounded']) if resultado[
                                                                                           'qtd_ferido_agen_segur_ocorrencia'] > 0 else pd.NA
    resultado['ag_seguranca_mortos_status_oc'] = '.'.join(
        [x['agentStatus']['name'] for x in vitimas if x['situation'] == 'Dead']) if resultado[
                                                                                        'qtd_morto_agen_segur_ocorrencia'] > 0 else pd.NA

    houve_agente_vitima = resultado['qtd_morto_agen_segur_ocorrencia'] + resultado[
        'qtd_ferido_agen_segur_ocorrencia'] > 0
    resultado['ag_seguranca_vitima_oc'] = "Sim" if houve_agente_vitima else "Não"

    return resultado


# homens e mulheres
def informacoes_vitimas_sexo(vitimas: list) -> dict:
    """_summary_

    Args:
        vitimas (list): _description_

    Returns:
        dict: _description_
    """

    resultado = dict()

    if len(vitimas) == 0:
        return {
            'homem_qtd_mortos_oc': 0,
            'homem_qtd_feridos_oc': 0,
            'mulher_qtd_mortos_oc': 0,
            'mulher_qtd_feridos_oc': 0
        }

    homens = [x for x in vitimas if x['genre']['name'].lower() in ['homem', 'masculino']]
    mulheres = [x for x in vitimas if x['genre']['name'].lower() in ['feminino', 'mulher']]

    qtd_homens_mortos = len([x for x in homens if x['situation'] == 'Dead'])
    resultado['homem_qtd_mortos_oc'] = qtd_homens_mortos

    qtd_homens_feridos = len([x for x in homens if x['situation'] == 'Wounded'])
    resultado['homem_qtd_feridos_oc'] = qtd_homens_feridos

    qtd_mulheres_mortas = len([x for x in mulheres if x['situation'] == 'Dead'])
    resultado['mulher_qtd_mortos_oc'] = qtd_mulheres_mortas

    qtd_mulheres_feridas = len([x for x in mulheres if x['situation'] == 'Wounded'])
    resultado['mulher_qtd_feridos_oc'] = qtd_mulheres_feridas

    return resultado


def informacoes_fixas() -> dict:
    """Dados fixas

    Returns:
        dict: retorna dicionario dos dados fixos
    """
    # não faço a menor ideia do porquê de isto estar aí. Não utilizamos dados de outros estados nesta tabela.
    return {
        'uf_estado': pd.NA,  # não sei porque está assim no banco. Não vou inventar moda
        'estado_id': 11,  # Está assim no banco. Não sei o que significa
        'nome_estado': 'Rio de Janeiro',  # MPRJ
        'cod_ibge_estado': 33
    }


def dados_data_hora_ocorrencia(ocorrencia: dict) -> dict:
    """Retorna todos os dados relativos a data ou hora

    Args:
        ocorrencia
    Returns:
        dict: dicionario das variáveis de data e hora
    """

    data_oc = datetime.strptime(ocorrencia['date'], "%Y-%m-%dT%H:%M:%S.%fZ")

    return {
        'data_ocorrencia': datetime.strptime(ocorrencia['date'], "%Y-%m-%dT%H:%M:%S.%fZ"),
        'hora_ocorrencia': re.search(r"\d{2}:\d{2}", ocorrencia['date']).group(),
        'timestamp_ocorrencia': pd.Timestamp(data_oc),
        'dia_ocorrencia': data_oc.day,
        'mes_ocorrencia': MESES_EM_PORTUGUES[data_oc.month],
        'ano_ocorrencia': data_oc.year,
        'dia_semana_ocorrencia': DIAS_DA_SEMANA[data_oc.weekday()],  # 0 é segunda-feira
        'mes_ocorrencia_numero': data_oc.month
    }


def dados_localizacao(ocorrencia: dict) -> dict:
    """Retorna variáveis relacionadas à localização

    Args:
        ocorrencia (dict): ocorrência

    Returns:
        dict: dict com local_ocorrencia, latitude_ocorrencia, longitude_ocorrencia e goemtry
    """
    lat = ocorrencia['latitude'].split()[0].replace(",", "")
    lon = ocorrencia['longitude']

    lat = str(lat).replace('--', '-')
    lon = str(lon).replace('--', '-')

    lat = float(lat)
    lon = float(lon)

    return {
        'local_ocorrencia': ocorrencia['address'],
        'latitude_ocorrencia': lat,
        'longitude_ocorrencia': lon,
        'geometry': Point(lon, lat)
    }


def houve_bala_perdida(ocorrencia: dict) -> bool:
    """Houve bala perdida?

    Args:
        ocorrencia (dict): ocorrência

    Returns:
        bool: houve bala perdida?
    """
    return ocorrencia['contextInfo']['mainReason']['name'].lower() == 'bala perdida'


def informacoes_vitimas_bala_perdida(vitimas: list, houve_bala_perdida: bool) -> dict:
    if houve_bala_perdida and len(vitimas) > 0:
        qtd_feridos = [x for x in vitimas if x['situation'] == 'Wounded']
        qtd_mortos = [x for x in vitimas if x['situation'] == 'Dead']
        return {'bala_perdida_qtd_feridos_oc': qtd_feridos,
                'bala_perdida_qtd_mortos_oc': qtd_mortos}
    return {'bala_perdida_qtd_feridos_oc': 0,
            'bala_perdida_qtd_mortos_oc': 0}


def houve_chacina(ocorrencia: dict) -> bool:
    """Houve chacina?

    Args:
        ocorrencia (dict): ocorrência

    Returns:
        bool: houve chacina?
    """
    return ocorrencia['contextInfo']['massacre']


def informacoes_vitimas_chacina(ocorrencia: dict) -> dict:
    """Detalhes de vítimas de chacina

    Args:
        ocorrencia (dict): ocorrência

    Returns:
        dict: chacina_qtd_mortos_oc: n
    """
    if houve_chacina(ocorrencia) and len(ocorrencia['victims']) > 0:
        return {'chacina_qtd_mortos_oc': len(ocorrencia['victims'])}
    return {'chacina_qtd_mortos_oc': 0}


def dados_externos(nome_do_municipio: str) -> dict:
    """Retorna dados externos do municipio da ocorrencia

    Args:
        nome_do_municipio (str): nome do municipio

    Returns:
        dict: dicionario com chaves nome da cidade, código do ibge, id, gentílico, populacao, area e densidade demográfica
    """
    # Normaliza o nome do município (remove espaços e deixa maiúsculo)
    nome_limpo = nome_do_municipio.strip().upper()

    # Busca o município correspondente
    resultado = [
        x for x in DADOS_MUNICIPIOS
        if x['nome_cidade'].strip().upper() == nome_limpo
    ]

    if resultado:
        dados_externos_municipio_ocorrencia = resultado[0]
    else:
        # Caso não encontre, exibe aviso e devolve dados vazios
        print(f"[AVISO] Município '{nome_do_municipio}' não encontrado em DADOS_MUNICIPIOS.")

        dados_externos_municipio_ocorrencia = {
            'nome_cidade': nome_do_municipio,
            'cod_ibge_cidade': pd.NA,
            'id': pd.NA,
            'gentilico_cidade': pd.NA,
            'populacao_cidade': pd.NA,
            'area_cidade': pd.NA,
            'densidade_demo_cidade': pd.NA
        }

    return dados_externos_municipio_ocorrencia



def dentro_da_escola(vitimas: list) -> dict:
    """Função para retornar dados de vítimas em instituições de ensino

    Args:
        vitimas (list): vitimas

    Returns:
        dict: dicionario
    """
    if len(vitimas) == 0:
        return {
            'imediacao_ensino_oc': "Não",
            'imediacao_ensino_qtd_feridos_oc': pd.NA,
            'imediacao_ensino_qtd_mortos_oc': pd.NA,
        }
    resultado = dict()

    qtd_ferido = len(
        [x for x in vitimas if x['situation'] == 'Wounded' and x['place']['name'] in ['Escola', 'Universidade']])
    qtd_morto = len(
        [x for x in vitimas if x['situation'] == 'Dead' and x['place']['name'] in ['Escola', 'Universidade']])
    houve = qtd_ferido + qtd_morto > 0
    resultado['imediacao_ensino_oc'] = "Sim" if houve else "Não"
    resultado['imediacao_ensino_qtd_feridos_oc'] = qtd_ferido
    resultado['imediacao_ensino_qtd_mortos_oc'] = qtd_morto

    return resultado


def dentro_de_casa(vitimas: list) -> dict:
    """Função para retornar dados de vítimas que foram atingidas em alguma residência

    Args:
        vitimas (dict): vitimas

    Returns:
        dict: dicionario com valores
    """
    resultado = dict()
    if len(vitimas) == 0:
        return {
            'interior_residencia_oc': "Não",
            'interior_residencia_qtd_feridos_oc': pd.NA,
            'interior_residencia_qtd_mortos_oc': pd.NA,
        }
    qtd_ferido = len([x for x in vitimas if x['situation'] == 'Wounded' and x['place']['name'] == 'Residência'])
    qtd_morto = len([x for x in vitimas if x['situation'] == 'Dead' and x['place']['name'] == 'Residência'])
    houve = qtd_ferido + qtd_morto > 0
    resultado['interior_residencia_oc'] = "Sim" if houve else "Não"
    resultado['interior_residencia_qtd_feridos_oc'] = qtd_ferido
    resultado['interior_residencia_qtd_mortos_oc'] = qtd_morto

    return resultado


def interrupcao_transportes(ocorrencia: dict) -> dict:
    """Função para retornar dados de interrupcao

    Args:
        ocorrencia (dict): ocorrencia

    Returns:
        dict: dicionário com dados
    """

    resultado = dict()
    detalhes = ocorrencia['transports']

    if len(detalhes) > 0:
        resultado['descricao_via_interrompida_oc'] = detalhes[0]['transportDescription']
        resultado['data_interrupcao_via_oc'] = detalhes[0]['dateInterruption']
        resultado['data_liberacao_via_oc'] = detalhes[0]['releaseDate']
        resultado['informacao_via_oc'] = detalhes[0]['transport']['name']
    else:
        resultado['descricao_via_interrompida_oc'] = pd.NA
        resultado['data_interrupcao_via_oc'] = pd.NA
        resultado['data_liberacao_via_oc'] = pd.NA
        resultado['informacao_via_oc'] = pd.NA

    return resultado


def recortes_adicionais(ocorrencia: dict) -> str:
    """Retorna, se houver, informações adicionais de uma ocorrencia
    Args:
        ocorrencia (dict): ocorrencia

    Returns:
        str: se houver
    """

    if len(ocorrencia['contextInfo']['clippings']) == 0:
        return pd.NA
    return ocorrencia['contextInfo']['clippings'][0]['name']


def junta_dicionarios_aux(dic_1: dict, dic_2: dict) -> dict:
    for chave in dic_1.keys():
        dic_2[chave] = dic_1[chave]
    return dic_2


def junta_dicionarios(dicionarios: list) -> dict:
    """Junta dois dicionários.
    Ex: junta_dicionarios({a: 1, b: 4}, {c: 2, d: 3}) -> {a:1,b:4,c:2,d:3}

    Args:
        dicionario (any): lsita de dicionarios

    Returns:
        dict: dicionarios dic_1 e dic_2 concatenados
    """
    return reduce(junta_dicionarios_aux, dicionarios)


def gera_lista_dicionario(intervalo_dias: int = 1) -> list:
    """Funcão para retornar uma lista de dicionários

    Args:
        intervalo_dias (int, optional): Intervalo de dias para busca. Defaults to 1:int.

    Returns:
        list: lista de ocorrências
    """
    dici_resultado = []
    ocorrencias = retorna_busca_completa(intervalo_dias)
    for ocorrencia in ocorrencias:
        nome_municipio = ocorrencia['city']['name']
        tratados = [
            {'nome_cidade': nome_municipio,
             'id_ocorrencia': ocorrencia['id'],
             'presen_agen_segur_ocorrencia': "Sim" if ocorrencia['agentPresence'] else "Não",
             'chacina_oc': "Sim" if houve_chacina(ocorrencia) else "Não",
             'bala_perdida_oc': "Sim" if houve_bala_perdida(ocorrencia) else "Não",
             'motivo_principal': ocorrencia['contextInfo']['mainReason']['name'],
             'motivo_complementar': pd.NA if 'complementaryReason' not in ocorrencia['contextInfo'].keys() else
             ocorrencia['contextInfo']['complementaryReason']['name'],
             'outros_recortes': recortes_adicionais(ocorrencia),
             'chacina_unidades_policiais_oc': ocorrencia['contextInfo']['policeUnit'] if houve_chacina(
                 ocorrencia) else pd.NA},
            dados_externos(nome_municipio),
            informacoes_vitimas_chacina(ocorrencia),
            informacoes_vitimas_bala_perdida(ocorrencia['victims'], houve_bala_perdida(ocorrencia)),
            dados_localizacao(ocorrencia),
            dados_data_hora_ocorrencia(ocorrencia),
            informacoes_fixas(),
            informacoes_vitimas_sexo(ocorrencia['victims']),
            informacoes_vitimas_cargo(ocorrencia['victims']),
            informacoes_vitimas_idade(ocorrencia['victims']),
            dentro_de_casa(ocorrencia['victims']),
            dentro_da_escola(ocorrencia['victims']),
            interrupcao_transportes(ocorrencia)
        ]

        temp = junta_dicionarios(tratados)
        dici_resultado.append(temp)

    return dici_resultado


def gera_dataframe(intervalo_dias: int = 1) -> pd.DataFrame:
    """Retorna DataFrame com dados da api

    Args:
        intervalo_dias (int, optional): intervalo de dias. Defaults to 1.

    Returns:
        pd.DataFrame: DataFrame com dados da api
    """

    final = {chave: [] for chave in COLUNAS_DO_BANCO}
    dici_resultado = gera_lista_dicionario(intervalo_dias)
    for ocorrencia in dici_resultado:
        for coluna in COLUNAS_DO_BANCO:
            final[coluna].append(ocorrencia[coluna])

    df = pd.DataFrame(final)
    df['id_ocorrencia'] = df['id_ocorrencia'].apply(lambda x: uuid.UUID(x))

    return df
