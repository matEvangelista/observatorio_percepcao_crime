from busca_api_fogo_cruzado_automatico import gera_dataframe
from sqlalchemy import create_engine, text
from loguru import logger
import smtplib
import os
import pandas as pd
import geopandas as gpd
from dotenv import load_dotenv
import sys
import traceback

# Carregar variáveis de ambiente
load_dotenv()

DIAS = 400  

# Configuração do loguru
logger.remove()
logger.add(sys.stdout, level="INFO", format="{time} - {level} - {message}")

def executa_busca_final(intervalo_dias: int = 1) -> gpd.GeoDataFrame:
    """
    Realiza a busca de dados usando a API do Fogo Cruzado e salva os dados em um GeoDataFrame.

    Args:
        intervalo_dias: Número de dias para recuperar dados a partir de hoje.

    Returns:
        GeoDataFrame contendo os dados extraídos.
    """
    logger.info("Busca iniciada")
    try:
        df = gera_dataframe(intervalo_dias)
        crs = 'epsg:4326'
        geometry = gpd.GeoSeries(df['geometry'], crs=crs)
        gdf = gpd.GeoDataFrame(df, geometry=geometry, crs=crs)
        return gdf
    except Exception as e:
        logger.error(f"Erro durante a busca: {e}")
        logger.debug(traceback.format_exc())
        sys.exit(1)

def main():
    gdf = executa_busca_final(DIAS)
    gdf.to_pickle("resultado_fogo_cruzado.pkl")
