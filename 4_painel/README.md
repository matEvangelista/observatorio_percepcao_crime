# 4 · Painel (Observatório da Percepção do Crime)

App **Shiny** que apresenta o cruzamento percepção × realidade do crime no Rio,
com mapas **Leaflet** por bairro e por CISP, séries temporais e o IDPC.

## Como funciona

O painel **não consulta o PostgreSQL em tempo de execução** — ele lê arquivos
pré-processados versionados junto com o app:

| Arquivo | Conteúdo |
|---|---|
| `df_principal.rds` | Eventos de crime percebidos (Instagram, classificados) |
| `gdf_principal.{rds,gpkg}` | Logradouros com geometria e menções |
| `gdf_cisp.rds` | Geometrias das CISPs (+ população) |
| `gdf_bairros.rds` | Geometrias dos bairros (+ zona, população) |
| `gdf_percepcao.rds` | Vetores normalizados e IDPC por CISP |
| `st_real_cisp.{rds,gpkg}` | Crimes reais (ISP + Fogo Cruzado) por CISP |
| `qtd_dados.rds` | Total de posts/comentários processados |

Código organizado em: `global.R` (carrega dados e libs), `ui.R` + `capa_ui.R` +
`metodologia.R` + `idpc_v_ui.R` (interface), `server.R` (lógica reativa). Assets
(imagens, fontes, CSS) em `www/`.

## Como rodar

```r
# com o diretório de trabalho em 4_painel/
shiny::runApp()
```

## Regenerar dados

Quando novos resultados forem calculados na etapa 3, atualize o IDPC do painel:

```bash
Rscript regenerar_percepcao.R   # lê tcc.resultados_vetores via ../.env e regrava gdf_percepcao.rds
```

## Deploy

Publicado no **Hugging Face Spaces**
(`https://mateus-evangelista-observatorio-percepcao-crime.hf.space`).

O [`Dockerfile`](Dockerfile) empacota o painel: parte de `rocker/shiny-verse:4.3.3`,
instala as bibliotecas de sistema geoespaciais (GDAL/GEOS/PROJ) e `libpq-dev`,
configura o locale `pt_BR.UTF-8`, instala os pacotes R e sobe o app na porta `7860`.

```bash
# build e execução local da imagem
docker build -t opc-painel .
docker run --rm -p 7860:7860 opc-painel
# abra http://localhost:7860
```

> Esta é a versão consolidada do app (originalmente `OPC/OPC (copy)/`). A versão
> antiga `OPC/OPC/` foi descartada por ser menos completa e sem as otimizações de
> performance (pré-agregações na inicialização, reativos reutilizáveis).
