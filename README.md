# Observatório: Percepção vs Realidade do Crime no Rio de Janeiro

Projeto de TCC que **compara a percepção do crime** — extraída de posts e
comentários do Instagram e classificada por um LLM (Maritaca / Sabiá-4) — com a
**realidade oficial** (dados do ISP e do Fogo Cruzado), calcula o **IDPC**
(Índice de Distorção da Percepção do Crime) e publica tudo num **painel Shiny**.

## Pipeline

```
  1_coleta            2_classificacao         3_tratamento            4_painel
 ───────────         ────────────────        ─────────────          ──────────
 Instagram     ┐                                                     App Shiny
 ISP (CISP)    ├──►  Postgres/PostGIS  ──►  LLM Sabiá-4 +     ──►   IDPC, vetores,  ──►  (Hugging Face
 Fogo Cruzado  ┘     (schema tcc.*)         LangGraph →            análises R,            Spaces)
 + shapefiles                               fatos de percepção     avaliação,
                                                                   logradouros
```

1. **`1_coleta/`** — baixa as fontes (Instagram, ISP, Fogo Cruzado) e os
   shapefiles, faz a integração espacial e carrega tudo no PostgreSQL/PostGIS.
2. **`2_classificacao/`** — classifica posts/comentários (tipo de crime, autor,
   grupo criminoso, localização) com LangGraph + Maritaca, gravando as tabelas de
   fato e exportando `.jsonl`.
3. **`3_tratamento/`** — calcula o IDPC e os vetores de percepção/realidade,
   gera os gráficos (R), avalia a qualidade do classificador e analisa logradouros.
4. **`4_painel/`** — app Shiny que lê arquivos pré-processados (`.rds`/`.gpkg`) e
   exibe os mapas Leaflet. **Não** consulta o banco em tempo de execução.

## Estrutura

```
final/
├── 1_coleta/           instagram · fogo_cruzado · isp · geografia · integracao_espacial
├── 2_classificacao/    classes · nodes · tools · main.ipynb · resultados/
├── 3_tratamento/       vetores_idpc · analise_r · avaliacao · comparacao
├── 4_painel/           global.R · ui.R · server.R · www/ · *.rds · *.gpkg · Dockerfile
├── servicos/           infra em Docker: nominatim/ · langfuse/
├── conhecimento.json   modelo lógico do banco (tabelas e relacionamentos)
├── INFO_TECNICA.md     detalhamento técnico (versões de libs, hospedagem)
└── pyproject.toml / uv.lock / .python-version
```

## Pré-requisitos

- **PostgreSQL 14+ com PostGIS** — banco `tcc` (schema `tcc.*`).
- **Nominatim local** em `http://localhost:8080` — geocodificação na classificação
  (suba via [`servicos/nominatim/`](servicos/nominatim/)).
- **uv** (Python 3.13) — `uv sync` instala as dependências de `pyproject.toml`.
- **R 4.x** — pacotes `shiny`, `shiny.router`, `shinycssloaders`, `shinyWidgets`,
  `bslib`, `plotly`, `echarts4r`, `leaflet`, `sf`, `dplyr`, `tidyr`, `stringr`,
  `RColorBrewer` (painel) e `tidyverse`, `DBI`, `RPostgres`, `dotenv`, `ggalluvial`,
  `ggspatial`, `zoo`, `lubridate`, `scales`, `ggrepel`, `broom` (análises).
- **Langfuse** local (opcional) — observabilidade do LLM
  (ver [`servicos/langfuse/`](servicos/langfuse/)).
- **Scrape bruto do Instagram** (~2,1 GB) — externo a esta pasta (ver abaixo).

## Configuração

```bash
cp .env.example .env     # preencha DB, EMAIL_API/SENHA_API, OPENAI_API_KEY, etc.
```

O scrape bruto do Instagram **não acompanha** `final/`. Aponte para ele de uma
das formas:
- defina `INSTAGRAM_SCRAPE_DIR` no `.env` com o caminho absoluto da pasta; ou
- use o symlink `1_coleta/instagram/raw` (já criado apontando para a pasta original).

## Ordem de execução

1. **Coleta** (`1_coleta/`): `instagram/` → `isp/` → `fogo_cruzado/` → `integracao_espacial/`
2. **Classificação** (`2_classificacao/`): `main.ipynb`
3. **Tratamento** (`3_tratamento/`): `vetores_idpc/` → `analise_r/` → `avaliacao/`
4. **Painel** (`4_painel/`): `regenerar_percepcao.R` (se necessário) → `shiny::runApp()`

Cada etapa tem seu próprio `README.md` com inputs, outputs e detalhes de execução.

## Banco de dados

O modelo lógico (tabelas, atributos e relacionamentos) está em
[`conhecimento.json`](conhecimento.json). Detalhes técnicos de implementação,
versões de bibliotecas e hospedagem estão em [`INFO_TECNICA.md`](INFO_TECNICA.md).

> **Nota:** os arquivos originais permanecem intactos nas pastas de nível superior
> do repositório (`carga_de_dados/`, `classificacao_maritaca/`, `OPC/`, etc.).
> `final/` é uma reorganização limpa e reproduzível desse material.
