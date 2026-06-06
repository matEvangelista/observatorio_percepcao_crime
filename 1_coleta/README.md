# 1 · Coleta

Baixa as fontes de dados, faz a integração espacial e carrega tudo no
PostgreSQL/PostGIS (schema `tcc`).

## Subpastas

| Pasta | O que faz | Saída no banco |
|---|---|---|
| `instagram/` | Descompacta os `.json.xz` do scrape e carrega posts/comentários | `tcc.pagina`, `tcc.publicacao`, `tcc.comentario` |
| `isp/` | Baixa o CSV mensal do ISP e tabelas de referência | `tcc.crime`, `tcc.autor_crime`, `tcc.registro_cisp` |
| `fogo_cruzado/` | Cliente da API Fogo Cruzado → gera `resultado_fogo_cruzado.pkl` | (cache em disco) |
| `geografia/` | Shapefiles de bairros, CISP e limites de bairro (insumo) | — |
| `integracao_espacial/` | Overlay shapefiles × ocorrências → carga geográfica | `tcc.cisp`, `tcc.bairro`, `tcc.ocorrencia_tiroteio` |

## Inputs

- **Scrape do Instagram** via `INSTAGRAM_SCRAPE_DIR` (ou symlink `instagram/raw`).
  Os ~2,1 GB de JSON bruto **não** acompanham `final/`.
- **Credenciais** `EMAIL_API` / `SENHA_API` (Fogo Cruzado) e `DB_*` no `.env`.
- **CSV do ISP** — baixado pelo próprio `isp/carga_cisp.ipynb`.
- **Shapefiles** — em `geografia/` (`bairros`, `CISP`, `Limite_de_Bairros`).

## Outputs

- Tabelas do schema `tcc` no PostgreSQL/PostGIS.
- `fogo_cruzado/resultado_fogo_cruzado.pkl` (cache do GeoDataFrame).

## Como rodar

Execute cada subpasta **com o diretório de trabalho na própria subpasta**
(os caminhos relativos assumem isso). Ordem sugerida:

1. `instagram/` — scrape com instaloader, depois `extrair_jsonxz.py` (descompacta) e
   `carga_instagram.ipynb` (carga). **Detalhes do scrape em [`instagram/README.md`](instagram/README.md).**
2. `isp/` — `carga_cisp.ipynb`.
3. `fogo_cruzado/` — `main_api_fogo_cruzado_automatico.py` (gera o `.pkl`).
4. `integracao_espacial/` — `carga_fogo_cruzado_cisp_bairro.ipynb`
   (lê `../geografia/*.shp` e `../fogo_cruzado/resultado_fogo_cruzado.pkl`).
