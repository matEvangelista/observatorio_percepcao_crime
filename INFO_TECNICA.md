# Informações Técnicas de Implementação

Levantamento baseado **apenas** no que está no repositório local. Onde não há informação no código, isso é marcado explicitamente.

## 1. Linguagens

- **Python 3.13** — declarado em `.python-version` (`3.13`) e em `pyproject.toml` (`requires-python = ">=3.13"`).
- **R** — usado no painel Shiny (`OPC/OPC (copy)/`). **Não há lockfile (`renv.lock`/`DESCRIPTION`) no repositório**, então a versão exata do R não está fixada.

## 2. Bibliotecas e versões

Versões exatas vêm do `uv.lock`; declarações mínimas vêm do `pyproject.toml`.

### Python — pipeline de coleta e classificação

| Categoria | Biblioteca | Versão (uv.lock) |
|---|---|---|
| Orquestração LLM | `langgraph` | **1.0.7** |
| LangChain base | `langchain` | 1.2.7 |
| Conexão com Maritaca (via API OpenAI-compatível) | `langchain-openai` | 1.1.7 |
| Outros provedores LLM | `langchain-google-genai` 4.2.0, `langchain-ollama` 1.0.1 | — |
| Observabilidade de LLM | `langfuse` | 3.12.1 |
| Coleta do Instagram | **`instaloader`** | **4.15** |
| Cookies de sessão | `browser-cookie3` | 0.20.1 |
| PostgreSQL (driver moderno) | **`psycopg`** | **3.3.2** (com `psycopg-binary`) |
| PostgreSQL (driver legado, usado por SQLAlchemy/GeoAlchemy) | `psycopg2-binary` | 2.9.11 |
| ORM | `sqlalchemy` | 2.0.46 |
| Camada espacial sobre SQLAlchemy | `geoalchemy2` | 0.18.1 |
| Geoespacial | **`geopandas` 1.1.2**, **`shapely` 2.1.2**, `folium` 0.20.0, `contextily` 1.7.0 | — |
| Dados | `pandas` 3.0.0, `openpyxl` 3.1.5 | — |
| ML/embeddings | `scikit-learn` 1.8.0, `torch` 2.10.0, `transformers` 5.2.0 | — |
| Utilitários | `python-dotenv` 1.2.1, `loguru` 0.7.3, `requests` 2.32.5, `matplotlib` 3.10.7, `seaborn` 0.13.2 | — |

**Modelo LLM** (`classificacao_maritaca/nodes/nodes.py`):
`ChatOpenAI(model="sabia-4", base_url="https://chat.maritaca.ai/api")` e `model="sabiazinho-4"` — a Maritaca expõe API compatível com OpenAI, daí o uso de `langchain-openai`.

### R — painel Shiny

Bibliotecas declaradas em `OPC/OPC (copy)/global.R`:

`shiny`, `shiny.router`, `shinycssloaders`, `shinyWidgets`, `plotly`, `echarts4r`, `bslib`, `sf`, `tidyr`, `dplyr`, `leaflet`, `stringr`, `RColorBrewer`.

As bibliotecas `RPostgres`, `DBI` e `dotenv` aparecem comentadas — só são ativadas para regenerar os arquivos `.rds`/`.gpkg` (ver `regenerar_percepcao.R`). **Versões não constam.**

## 3. Onde o pipeline roda

Tudo em **máquina local**, sem indícios de orquestrador, container ou nuvem nesta cópia do repositório:

- **Coleta do Fogo Cruzado:** script Python `carga_de_dados/main_api_fogo_cruzado_automatico.py` lê `.env` local (`EMAIL_API`, `SENHA_API`) e grava no Postgres.
- **Coleta do Instagram:** os arquivos brutos ficam em `Instagram Web Scrape/{folhazonanorte,riodenojeiraoficial,zonaoesteurgente}/` com formatos `.json`, `.json.xz` e `.txt` (padrão do `instaloader`). O notebook `carga_de_dados/carga_instagram.ipynb` lê esses arquivos e carrega no banco.
- **Classificação:** notebook `classificacao_maritaca/main.ipynb` constrói um `StateGraph` do LangGraph com `Sabiá-4`/`Sabiazinho-4` via Maritaca, com tracing via Langfuse.
- **Cálculo dos vetores e do IDPC:** `manipulacao_dados.ipynb` (raiz) — gera e popula `tcc.resultados_vetores`.

O **pipeline** (etapas 1–3) roda localmente, sem orquestrador, container, GitHub Actions, cron ou agendador. O único container é o do **painel** (`4_painel/Dockerfile`), usado para empacotar e implantar o app Shiny no Hugging Face Spaces.

## 4. Hospedagem do painel

A URL `https://mateus-evangelista-observatorio-percepcao-crime.hf.space` confirma **Hugging Face Spaces** (domínio `*.hf.space` é exclusivo de Spaces). O `Dockerfile` da implantação está em `4_painel/Dockerfile`: parte de `rocker/shiny-verse:4.3.3`, instala as libs de sistema geoespaciais (GDAL/GEOS/PROJ) e `libpq-dev`, configura o locale `pt_BR.UTF-8`, instala os pacotes R (CRAN + `histoslider` via GitHub), copia o app e sobe o Shiny na porta `7860` (padrão de Spaces).

Detalhe importante: o painel **não consulta o Postgres em runtime**. Em `global.R` todos os `dbConnect`/`dbGetQuery` estão comentados; o app só lê arquivos pré-processados (`df_principal.rds`, `gdf_cisp.rds`, `gdf_bairros.rds`, `gdf_percepcao.rds`, `st_real_cisp.gpkg`, `gdf_principal.gpkg`), que são versionados junto com o app no Space.

## 5. Hospedagem do PostgreSQL

O `.env` do projeto raiz e o `.env` em `OPC (copy)/.env` apontam para `DB_HOST=localhost`, `DB_PORT=5432`, `DB_NAME=tcc`, `DB_USER=postgres`. O notebook `manipulacao_dados.ipynb` também usa essas variáveis. **O banco é local** (na máquina de desenvolvimento). Não há código apontando para um Postgres em nuvem (Supabase, RDS, Neon, etc).

## 6. Arquivos de configuração de ambiente

| Arquivo | Existe? | Conteúdo |
|---|---|---|
| `pyproject.toml` | sim (raiz) | Dependências Python com `>=` |
| `uv.lock` | sim (raiz) | Versões exatas (gerenciador: **uv**) |
| `.python-version` | sim (raiz) | `3.13` |
| `requirements.txt` | **não** | — |
| `renv.lock` / `DESCRIPTION` | **não** | — |
| `Dockerfile` | sim (`4_painel/`) | imagem do painel: `rocker/shiny-verse` + libs geo + pacotes R, porta 7860 |
| `.env` | sim, **não versionável** | credenciais DB e APIs |
