from langchain_core.tools import tool
from sqlalchemy import create_engine
from dotenv import load_dotenv
import pandas as pd
import requests
import os

load_dotenv()
DB_NAME=os.getenv('DB_NAME')
DB_USER=os.getenv('DB_USER')
DB_PW=os.getenv('DB_PW')
DB_HOST=os.getenv('DB_HOST')
DB_PORT=os.getenv('DB_PORT')

ENGINE = create_engine(f"postgresql://{DB_USER}:{DB_PW}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

@tool("busca_bairro_por_nome_tool")
def busca_bairro_por_nome_tool(nome_bairro: str) -> list:
    """
    Busca bairros com nomes semelhantes no banco de dados e retorna uma lista de dicionários:
    [{"id_bairro": 1, "nome_bairro": "Ipanema", "zona": "Zona Sul"}]
    """
    query = """
    SELECT id_bairro, nome_bairro, zona
    FROM bairro
    WHERE unaccent(nome_bairro::text) ILIKE unaccent(%(nome)s)
    """
    params = {"nome": f"%{nome_bairro}%"}
    resultados = pd.read_sql(query, ENGINE, params=params).to_dict('records')
    return resultados

@tool("busca_bairro_poi_no_rio_tool")
def buscar_poi_no_rio_tool(poi: str):
    """
    Busca um ponto de interesse (ex: bairro, praça, hospital etc.)
    garantindo que o resultado seja na cidade do Rio de Janeiro.
    """
    base_url = "http://localhost:8080/search"

    params = {
        "format": "json",
        "polygon_geojson": 0,
        "addressdetails": 1,
        "dedupe": 0,
        "limit": 30,
        "q": f"{poi}, Rio de Janeiro"
    }

    # --- 1. Requisição ---
    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        resultados_brutos = response.json()
    except requests.exceptions.RequestException as e:
        print(f"Erro na API: {e}")
        return []

    # --- 2. Filtragem ---
    resultados_finais = []

    municipio_alvo = "Rio de Janeiro"

    for item in resultados_brutos:
        endereco = item.get("address", {})

        # OSM pode variar o campo da cidade
        cidade_api = (
            endereco.get("city")
            or endereco.get("town")
            or endereco.get("municipality")
            or ""
        )

        cidade_api_norm = cidade_api

        if cidade_api_norm == municipio_alvo:
            resultados_finais.append(item)
    
    resultados_finais = [res['address'] for res in resultados_finais]

    return resultados_finais

tools_geo = [busca_bairro_por_nome_tool, buscar_poi_no_rio_tool]