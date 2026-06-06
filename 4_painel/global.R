library(shiny)
library(shiny.router)
library(shinycssloaders)
library(shinyWidgets)
library(plotly)
library(echarts4r)
library(bslib)
#library(dotenv)
#library(RPostgres)
#library(DBI)
library(sf)
library(tidyr)
library(dplyr)
library(leaflet)
library(stringr)
#load_dot_env()

if (Sys.info()[['sysname']] == "Windows") {
  Sys.setlocale("LC_TIME", "Portuguese_Brazil.1252")
} else {
  # Para Linux/Mac (comum em servidores como shinyapps.io)
  Sys.setlocale("LC_TIME", "pt_BR.UTF-8") 
}

# # Ler variáveis de ambiente
# DB_NAME <- Sys.getenv("DB_NAME")
# DB_USER <- Sys.getenv("DB_USER")
# DB_PW   <- Sys.getenv("DB_PW")
# DB_HOST <- Sys.getenv("DB_HOST")
# DB_PORT <- Sys.getenv("DB_PORT")
# 
# # Criar conexão com o PostgreSQL
# con <- dbConnect(
#   RPostgres::Postgres(),
#   dbname   = DB_NAME,
#   user     = DB_USER,
#   password = DB_PW,
#   host     = DB_HOST,
#   port     = DB_PORT
# )

#st_write(gdf_principal, "gdf_principal.gpkg", delete_layer = TRUE)


# query_crimes_cisp <- "
# WITH cte_isp AS (
#   -- 1. Agrega registros ISP por c.id (inteiro) em vez de c.geometry (caro)
#   SELECT
#     c.id,
#     c.nome_dp,
#     COALESCE(SUM(rc.homicidio), 0)                    AS homicidio,
#     COALESCE(SUM(rc.latrocinio), 0)                   AS latrocinio,
#     COALESCE(SUM(rc.hom_por_intervencao_policial), 0) AS hom_por_intervencao_policial,
#     COALESCE(SUM(rc.tentat_hom), 0)                   AS tentat_hom,
#     COALESCE(SUM(rc.lesao_corp_dolosa), 0)            AS lesao_corp_dolosa,
#     COALESCE(SUM(rc.estupro), 0)                      AS estupro,
#     COALESCE(SUM(rc.sequestro), 0)                    AS sequestro,
#     COALESCE(SUM(rc.extorsao), 0)                     AS extorsao,
#     COALESCE(SUM(rc.estelionato), 0)                  AS estelionato,
#     COALESCE(SUM(rc.trafico_drogas), 0)               AS trafico_drogas,
#     COALESCE(SUM(rc.policiais_mortos), 0)             AS policiais_mortos,
#     COALESCE(SUM(rc.lesao_corp_morte), 0)             AS lesao_corp_morte,
#     COALESCE(SUM(rc.hom_culposo), 0)                  AS hom_culposo,
#     COALESCE(SUM(rc.lesao_corp_culposa), 0)           AS lesao_corp_culposa,
#     COALESCE(SUM(rc.ameaca), 0)                       AS ameaca,
#     COALESCE(SUM(rc.roubo_transeunte), 0)             AS roubo_transeunte,
#     COALESCE(SUM(rc.roubo_celular), 0)                AS roubo_celular,
#     COALESCE(SUM(rc.roubo_em_coletivo), 0)            AS roubo_em_coletivo,
#     COALESCE(SUM(rc.roubo_veiculo), 0)                AS roubo_veiculo,
#     COALESCE(SUM(rc.roubo_carga), 0)                  AS roubo_carga,
#     COALESCE(SUM(rc.roubo_rua), 0)                    AS roubo_rua,
#     COALESCE(SUM(rc.roubo_residencia), 0)             AS roubo_residencia,
#     COALESCE(SUM(rc.roubo_banco), 0)                  AS roubo_banco,
#     COALESCE(SUM(rc.roubo_comercio), 0)               AS roubo_comercio,
#     COALESCE(SUM(rc.roubo_cx_eletronico), 0)          AS roubo_cx_eletronico,
#     COALESCE(SUM(rc.roubo_conducao_saque), 0)         AS roubo_conducao_saque,
#     COALESCE(SUM(rc.roubo_apos_saque), 0)             AS roubo_apos_saque,
#     COALESCE(SUM(rc.roubo_bicicleta), 0)              AS roubo_bicicleta,
#     COALESCE(SUM(rc.outros_roubos), 0)                AS outros_roubos,
#     COALESCE(SUM(rc.furto_veiculos), 0)               AS furto_veiculos,
#     COALESCE(SUM(rc.furto_celular), 0)                AS furto_celular,
#     COALESCE(SUM(rc.furto_transeunte), 0)             AS furto_transeunte,
#     COALESCE(SUM(rc.furto_coletivo), 0)               AS furto_coletivo,
#     COALESCE(SUM(rc.furto_bicicleta), 0)              AS furto_bicicleta,
#     COALESCE(SUM(rc.outros_furtos), 0)                AS outros_furtos,
#     COALESCE(SUM(rc.sequestro_relampago), 0)          AS sequestro_relampago,
#     COALESCE(SUM(rc.posse_drogas), 0)                 AS posse_drogas,
#     COALESCE(SUM(rc.pessoas_desaparecidas), 0)        AS pessoas_desaparecidas,
#     COALESCE(SUM(rc.encontro_cadaver), 0)             AS encontro_cadaver
#   FROM tcc.cisp c
#   LEFT JOIN tcc.registro_cisp rc ON rc.cisp_id = c.id
#   WHERE c.nome_dp != 'Sem DP'
#   GROUP BY c.id, c.nome_dp
# ),
# cte_fc AS (
#   -- 2. Tiroteios por CISP — agrupa direto por cisp_id (inteiro), sem JOIN a cisp
#   SELECT
#     b.cisp_id,
#     COUNT(ot.id) AS tiros
#   FROM tcc.bairro b
#   LEFT JOIN tcc.ocorrencia_tiroteio ot ON ot.bairro_id_bairro = b.id_bairro
#   WHERE b.cisp_id IS NOT NULL
#   GROUP BY b.cisp_id
# ),
# cte_pop AS (
#   -- 3. População por CISP — pré-agrupada por cisp_id (inteiro), sem JOIN a cisp
#   SELECT
#     cisp_id,
#     COALESCE(SUM(total_domicilios_2022), 0) AS populacao
#   FROM tcc.bairro
#   WHERE cisp_id IS NOT NULL
#   GROUP BY cisp_id
# ),
# cte_consolidada AS (
#   -- 4. Une tudo; geometria entra aqui via JOIN simples por chave inteira
#   SELECT
#     i.nome_dp,
#     c.geometry,
#     COALESCE(p.populacao, 0) AS populacao,
#     COALESCE(f.tiros, 0)     AS tiros,
#     i.homicidio, i.latrocinio, i.hom_por_intervencao_policial, i.tentat_hom,
#     i.lesao_corp_dolosa, i.estupro, i.sequestro, i.extorsao, i.estelionato,
#     i.trafico_drogas, i.policiais_mortos, i.lesao_corp_morte, i.hom_culposo,
#     i.lesao_corp_culposa, i.ameaca, i.roubo_transeunte, i.roubo_celular,
#     i.roubo_em_coletivo, i.roubo_veiculo, i.roubo_carga, i.roubo_rua,
#     i.roubo_residencia, i.roubo_banco, i.roubo_comercio, i.roubo_cx_eletronico,
#     i.roubo_conducao_saque, i.roubo_apos_saque, i.roubo_bicicleta, i.outros_roubos,
#     i.furto_veiculos, i.furto_celular, i.furto_transeunte, i.furto_coletivo,
#     i.furto_bicicleta, i.outros_furtos, i.sequestro_relampago, i.posse_drogas,
#     i.pessoas_desaparecidas, i.encontro_cadaver
#   FROM      cte_isp i
#   JOIN      tcc.cisp c ON c.id = i.id
#   LEFT JOIN cte_fc   f ON f.cisp_id = i.id
#   LEFT JOIN cte_pop  p ON p.cisp_id = i.id
# )
# -- 5. Unpivot final (sem ORDER BY — R reordena conforme necessário)
# SELECT
#   t.nome_dp,
#   t.geometry,
#   t.populacao,
#   v.nome_crime,
#   COALESCE(v.total_ocorrencias, 0) AS total_ocorrencias
# FROM cte_consolidada t
# CROSS JOIN LATERAL (
#   VALUES
#     ('Homicídio Doloso',                 t.homicidio),
#     ('Latrocínio',                        t.latrocinio),
#     ('Morte por Intervenção Policial',    t.hom_por_intervencao_policial),
#     ('Tentativa de Homicídio',           t.tentat_hom),
#     ('Lesão Corporal Dolosa',            t.lesao_corp_dolosa),
#     ('Estupro',                           t.estupro),
#     ('Sequestro',                         t.sequestro),
#     ('Extorsão',                          t.extorsao),
#     ('Estelionato',                       t.estelionato),
#     ('Tráfico Drogas',                    t.trafico_drogas),
#     ('Policiais Mortos em Serviço',       t.policiais_mortos),
#     ('Lesão Corporal Seguida de Morte',  t.lesao_corp_morte),
#     ('Homicídio Culposo',                t.hom_culposo),
#     ('Lesão Corporal Culposa',           t.lesao_corp_culposa),
#     ('Ameaça',                            t.ameaca),
#     ('Roubo a Transeunte',               t.roubo_transeunte),
#     ('Roubo de Celular',                 t.roubo_celular),
#     ('Roubo em Coletivo',                t.roubo_em_coletivo),
#     ('Roubo de Veículo',                 t.roubo_veiculo),
#     ('Roubo de Carga',                   t.roubo_carga),
#     ('Roubo a Residência',               t.roubo_residencia),
#     ('Roubo a Banco',                    t.roubo_banco),
#     ('Roubo de Comércio',                t.roubo_comercio),
#     ('Roubo a Caixa Eletrônico',         t.roubo_cx_eletronico),
#     ('Roubo com Condução a Saque',       t.roubo_conducao_saque),
#     ('Roubo após Saque',                 t.roubo_apos_saque),
#     ('Roubo de Bicicleta',               t.roubo_bicicleta),
#     ('Outros Roubos',                     t.outros_roubos),
#     ('Furto de Veículos',                t.furto_veiculos),
#     ('Furto de Celular',                 t.furto_celular),
#     ('Furto a Transeunte',               t.furto_transeunte),
#     ('Furto em Coletivo',                t.furto_coletivo),
#     ('Furto de Bicicleta',               t.furto_bicicleta),
#     ('Outros Furtos',                     t.outros_furtos),
#     ('Sequestro Relâmpago',              t.sequestro_relampago),
#     ('Posse Drogas',                      t.posse_drogas),
#     ('Pessoas Desaparecidas',            t.pessoas_desaparecidas),
#     ('Encontro Cadáver',                 t.encontro_cadaver),
#     ('Tiros',                             t.tiros)
# ) AS v(nome_crime, total_ocorrencias);
# "
# 
# st_real_cisp <- st_read(con, query = query_crimes_cisp, geometry_column = "geometry")
# st_real_cisp %>% st_write("st_real_cisp.gpkg", delete_layer = TRUE)
st_real_cisp  <- st_read("st_real_cisp.gpkg")
df_real_cisp  <- st_real_cisp %>% st_drop_geometry()
rm(st_real_cisp)

# meu estilo de gráfico uwu
tema_tcc <- theme_minimal() +
  theme(
    legend.position = "top",
    plot.title = element_text(face = "bold", size = 16, color = "#222222"),
    plot.subtitle = element_text(size = 12, color = "#444444"),
    axis.text.x = element_text(angle = 45, hjust = 1, color = "black"),
    axis.text.y = element_text(color = "black"),
    axis.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(hjust = 1, size = 9, color = "#666666", face = "italic", margin = margin(t = 10))
  )

# --- FUNÇÕES UTILITÁRIAS ---

# Limpa geometrias SF de problemas comuns ao importar do PostGIS/arquivos
limpar_sf <- function(gdf) {
  gdf %>%
    st_as_sf() %>%
    st_transform(4326) %>%
    st_zm(drop = TRUE, what = "ZM") %>%
    st_make_valid() %>%
    st_cast("MULTIPOLYGON") %>%
    filter(!st_is_empty(.))
}

# Retorna o valor mais frequente de valor_col por area_col, filtrado por filtro
top_por_area <- function(df, area_col, valor_col, filtro) {
  df %>%
    filter(!is.na(.data[[area_col]]), .data[[valor_col]] %in% filtro) %>%
    count(.data[[area_col]], .data[[valor_col]]) %>%
    group_by(.data[[area_col]]) %>%
    slice_max(n, n = 1, with_ties = FALSE) %>%
    ungroup()
}

# df_principal <- dbGetQuery(con,
#   "SELECT nome_crime, nome_autor, nome_bairro, nome_dp, nome_grupo, data
#    FROM tcc.crimes_nome_autor")

#df_principal %>% saveRDS("df_principal.rds")

df_principal <- readRDS("df_principal.rds")

# gdf_principal <- sf::st_read(con, query="
#   SELECT logradouro, nome_bairro, nome_autor, nome_crime, qtd_mencoes, geom
#   FROM tcc.linhas_logradouros")
# gdf_principal %>% st_write("gdf_principal.gpkg", delete_layer = TRUE)

gdf_principal <- st_read("gdf_principal.gpkg", quiet = TRUE)

# gdf_cisp <- st_read(con, query="
#   SELECT
#     c.nome_dp,
#     c.geometry AS geom,
#     COALESCE(pop.populacao, 0) AS populacao
#   FROM tcc.cisp c
#   LEFT JOIN (
#     SELECT cisp_id, SUM(total_domicilios_2022) AS populacao
#     FROM tcc.bairro
#     WHERE cisp_id IS NOT NULL
#     GROUP BY cisp_id
#   ) pop ON pop.cisp_id = c.id
#   WHERE c.nome_dp != 'Sem DP'",
#   geometry_column = "geom")
# gdf_cisp %>% saveRDS("gdf_cisp.rds")
gdf_cisp    <- readRDS("gdf_cisp.rds")
gdf_cisp    <- limpar_sf(gdf_cisp)

# gdf_bairros <- st_read(con, query="
#   SELECT nome_bairro, zona, total_domicilios_2022 AS populacao, geometry AS geom
#   FROM tcc.bairro
#   WHERE nome_bairro IS NOT NULL",
#   geometry_column = "geom")
# gdf_bairros %>% saveRDS("gdf_bairros.rds")
gdf_bairros <- readRDS("gdf_bairros.rds")
gdf_bairros <- limpar_sf(gdf_bairros)

# df_percepcao <- dbGetQuery(con,
#   "SELECT nome_dp,
#           vetor_perc_normalizado,
#           vetor_real_normalizado,
#           indice_desalinhamento,
#           crime_superestimado, delta_super_pp,
#           crime_subestimado,   delta_sub_pp
#    FROM tcc.resultados_vetores")
# df_percepcao %>% saveRDS("gdf_percepcao.rds")
# (geometria vem de gdf_cisp no lado R — sem necessidade de JOIN no banco)
df_percepcao <- readRDS("gdf_percepcao.rds")

# Ranking de IDPC entre CISPs (para badge "Nª mais distorcida")
df_percepcao <- df_percepcao %>%
  mutate(rank_idpc = rank(-indice_desalinhamento, ties.method = "min"))

# Distância de cosseno entre dois vetores (P percebido, R real)
calc_idpc <- function(p, r) {
  if (length(p) == 0 || length(r) == 0) return(NA_real_)
  if (sum(p) == 0 || sum(r) == 0)       return(0)
  num <- sum(p * r)
  den <- sqrt(sum(p^2)) * sqrt(sum(r^2))
  if (den == 0) return(0)
  1 - num / den
}

# qtd_dados <- dbGetQuery(con,
#   "SELECT COUNT(*) AS total
#    FROM (
#      SELECT id_publicacao FROM tcc.publicacao
#      UNION ALL
#      SELECT id_comentario FROM tcc.comentario
#    ) t")$total[1]
# qtd_dados %>% saveRDS("qtd_dados.rds")
qtd_dados <- 650799L
# (UNION ALL em vez de UNION: publicações e comentários são entidades distintas,
#  não faz sentido deduplicar IDs entre tabelas diferentes)
qtd_com_bairros <- nrow(df_principal)
autor_mais_citado <- df_principal %>% group_by(nome_autor) %>% summarise(qtd = n()) %>%
  arrange(desc(qtd)) %>% head(1) %>% pull(nome_autor)
crime_mais_comentado <- df_principal %>% group_by(nome_crime) %>% summarise(qtd = n()) %>%
  arrange(desc(qtd)) %>% head(1) %>% pull(nome_crime)

get_navbar <- function(active_page = "") {
  
  # Função auxiliar interna para verificar se é a página ativa
  # Se o nome bater, retorna a classe com 'active', senão, retorna normal
  get_active_class <- function(page_name) {
    if (active_page == page_name) {
      return("nav-link active")
    } else {
      return("nav-link")
    }
  }
  # # Ler variáveis de ambiente
  # DB_NAME <- Sys.getenv("DB_NAME")
  # DB_USER <- Sys.getenv("DB_USER")
  # DB_PW   <- Sys.getenv("DB_PW")
  # DB_HOST <- Sys.getenv("DB_HOST")
  # DB_PORT <- Sys.getenv("DB_PORT")
  # 
  # # Criar conexão com o PostgreSQL
  # con <- dbConnect(
  #   RPostgres::Postgres(),
  #   dbname   = DB_NAME,
  #   user     = DB_USER,
  #   password = DB_PW,
  #   host     = DB_HOST,
  #   port     = DB_PORT
  # )
  tags$nav(
    class = "navbar navbar-expand-lg p-3",
    
    div(class = "container",
        
        # --- BRAND (Logo) ---
        tags$a(class = "navbar-brand", 
               img(src='logo_nav.png', height='55rem'),
               href = route_link("/")), # Link para a Home
        
        # --- TOGGLER (Mobile) ---
        tags$button(
          class = "navbar-toggler",
          type = "button",
          `data-bs-toggle` = "collapse",
          `data-bs-target` = "#navbarSupportedContent",
          `aria-controls` = "navbarSupportedContent",
          `aria-expanded` = "false",
          `aria-label` = "Toggle navigation",
          tags$span(class = "navbar-toggler-icon")
        ),
        
        # --- CONTEÚDO DO MENU ---
        div(
          class = "collapse navbar-collapse",
          id = "navbarSupportedContent",
          
          tags$ul(
            class = "navbar-nav mb-2 mb-lg-0 w-100",
            
            # --- LINK METODOLOGIA ---
            tags$li(class = "nav-item ms-auto ms-lg-auto mt-4 mt-lg-0",
                    tags$a(
                      # AQUI A MÁGICA ACONTECE:
                      class = get_active_class("metodologia"), 
                      `aria-current`="page",
                      href = route_link("metodologia"), 
                      "METODOLOGIA"
                    )
            ),
            
            # --- LINK RESULTADOS ---
            tags$li(class = "nav-item ms-auto ms-lg-4 mt-3 mt-lg-0",
                    tags$a(
                      # AQUI TAMBÉM:
                      class = get_active_class("resultados"),
                      href = route_link("resultados"),
                      "RESULTADOS"
                    )
            ),

            # --- LINK ACESSAR TESE (Estático) ---
            tags$li(class = "nav-item ms-auto ms-lg-auto mt-3 mt-lg-0",
                    tags$a(class = "nav-link", href="#", "ACESSAR TESE")
            ),
            
            # --- LINK ACESSAR SABIÁ (Externo) ---
            tags$li(class = "nav-item ms-auto ms-lg-4 mt-3 mt-lg-0",
                    tags$a(class = "nav-link", 
                           href="https://www.maritaca.ai/",
                           "ACESSAR SABIÁ", target="_blank")
            )
          )
        )
    )
  )
}

library(RColorBrewer)
# Lista de crimes (valores legíveis)
crimes <- c(
  "Homicídio Doloso",
  "Latrocínio",
  "Morte por Intervenção Policial",
  "Tentativa de Homicídio",
  "Lesão Corporal Dolosa",
  "Estupro",
  "Sequestro",
  "Extorsão",
  "Estelionato",
  "Tráfico de Drogas",
  "Policiais Mortos em Serviço",
  "Lesão Corporal Seguida de Morte",
  "Homicídio Culposo",
  "Lesão Corporal Culposa",
  "Ameaça",
  "Roubo a Transeunte",
  "Roubo de Celular",
  "Roubo em Coletivo",
  "Roubo de Veículo",
  "Roubo de Carga",
  "Roubo a Residência",
  "Roubo a Banco",
  "Roubo de Comércio",
  "Roubo a Caixa Eletrônico",
  "Roubo com Condução a Saque",
  "Roubo após Saque",
  "Roubo de Bicicleta",
  "Outros Roubos",
  "Furto de Veículos",
  "Furto de Celular",
  "Furto a Transeunte",
  "Furto em Coletivo",
  "Furto de Bicicleta",
  "Outros Furtos",
  "Sequestro Relâmpago",
  "Posse Drogas",
  "Pessoas Desaparecidas",
  "Encontro Cadáver",
  "Tiros"
)
# Criar cores usando RColorBrewer, 9 cores fortes e o resto interpolado
cores_base <- brewer.pal(9, "Set1")
cores <- colorRampPalette(cores_base)(length(crimes))

# Lista nomeada de cores
names(cores) <- crimes

# Criar cores usando RColorBrewer, 9 cores fortes e o resto interpolado
cores_base <- brewer.pal(9, "Set1")
cores <- colorRampPalette(cores_base)(length(crimes))

# Lista nomeada de cores
names(cores) <- crimes

perfis <- c(
  "Policial", "Miliciano", "Traficante", "Assaltante", "Furtador",
  "Homicida", "Agressor", "Estuprador", "Sequestrador", "Extorsionário",
  "Estelionatário", "Usuário de Drogas", "Autor Culposo", "Político",
  "Autor Não Identificado", "Outros", "Sem Crime"
)

# Cores ajustadas:
cores_perfis <- c(
  "#1f78b4", # Policial - azul forte
  "#6baed6", # Miliciano - azul claro (próximo da polícia)
  "#e31a1c", # Traficante - vermelho
  "#ff7f00", # Assaltante - laranja
  "#fdbf6f", # Furtador - laranja claro
  "#b15928", # Homicida - marrom escuro
  "#6a3d9a", # Agressor - roxo
  "#d73027", # Estuprador - vermelho intenso
  "#984ea3", # Sequestrador - roxo escuro
  "#a50f15", # Extorsionário - vermelho escuro
  "#377eb8", # Estelionatário - azul médio
  "#a6cee3", # Usuário de Drogas - azul claro
  "#ffff33", # Autor Culposo - amarelo
  "#ff69b4", # Político - rosa
  "#b2df8a", # Autor Não Identificado - verde claro
  "#999999", # Outros - cinza
  "#cccccc"  # Sem Crime - cinza claro
)

# Criando lista nomeada
names(cores_perfis) <- perfis

# --- PRÉ-AGREGAÇÕES ---
# Calculadas uma vez no startup. Painéis filtram estas tabelas (~3k linhas)
# em vez de df_principal (~650k linhas) a cada clique no mapa.
contagem_crimes_bairro <- df_principal %>%
  filter(!is.na(nome_bairro), nome_crime %in% crimes) %>%
  count(nome_bairro, nome_crime)

contagem_autores_bairro <- df_principal %>%
  filter(!is.na(nome_bairro), nome_autor %in% perfis) %>%
  count(nome_bairro, nome_autor)

contagem_crimes_cisp <- df_principal %>%
  filter(!is.na(nome_dp), nome_crime %in% crimes) %>%
  count(nome_dp, nome_crime)

contagem_autores_cisp <- df_principal %>%
  filter(!is.na(nome_dp), nome_autor %in% perfis) %>%
  count(nome_dp, nome_autor)

# Lookup de população O(1): evita st_drop_geometry + filter a cada clique
pop_por_bairro <- setNames(gdf_bairros$populacao, gdf_bairros$nome_bairro)
pop_por_cisp   <- setNames(gdf_cisp$populacao,   gdf_cisp$nome_dp)

source("capa_ui.R")
source("metodologia.R")