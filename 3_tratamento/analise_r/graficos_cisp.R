library(dplyr)
library(sf)
library(ggplot2)
library(DBI)
library(RPostgres)
library(dotenv)
library(zoo)
library(tidyr)
library(lubridate)
library(scales)
library(ggrepel)
library(broom)
library(purrr)     # Garantia extra
library(stringr)
library(scales)
library(tidyverse)

# Carregar variáveis de ambiente do .env consolidado na raiz de final/
load_dot_env("../../.env")

# Ler variáveis de ambiente
DB_NAME <- Sys.getenv("DB_NAME")
DB_USER <- Sys.getenv("DB_USER")
DB_PW   <- Sys.getenv("DB_PW")
DB_HOST <- Sys.getenv("DB_HOST")
DB_PORT <- Sys.getenv("DB_PORT")

# Criar conexão com o PostgreSQL
con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = DB_NAME,
  user     = DB_USER,
  password = DB_PW,
  host     = DB_HOST,
  port     = DB_PORT
)

# meu estilo de gráfico uwu
tema_tcc <- theme_minimal() +
  theme(
    legend.position = "top",
    legend.text = element_text(size = 12, color = "black"),   # tamanho da legenda
    legend.title = element_text(size = 12, face = "bold"),    # título da legenda (opcional)
    plot.title = element_text(face = "bold", size = 20, color = "#222222"),
    plot.subtitle = element_text(size = 14, color = "#444444"),
    axis.text.x = element_text(angle = 45, hjust = 1, color = "black"),
    axis.text.y = element_text(color = "black"),
    axis.title = element_text(face = "bold", size = 12),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(hjust = 1, size = 12, color = "#666666", face = "italic", margin = margin(t = 10))
  )

################################################################################
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
  "Tráfico Drogas",
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

################################################################################

nomes_crimes <- c(
  "Homicídio Doloso", "Latrocínio", "Morte por Intervenção Policial", "Tentativa de Homicídio",
  "Lesão Corporal Dolosa", "Estupro", "Sequestro", "Extorsão", "Estelionato", "Tráfico Drogas",
  "Policiais Mortos em Serviço", "Lesão Corporal Seguida de Morte", "Homicídio Culposo",
  "Lesão Corporal Culposa", "Ameaça", "Roubo a Transeunte", "Roubo de Celular", "Roubo em Coletivo",
  "Roubo de Veículo", "Roubo de Carga", "Roubo a Residência", "Roubo a Banco", "Roubo de Comércio",
  "Roubo a Caixa Eletrônico", "Roubo com Condução a Saque", "Roubo após Saque", "Roubo de Bicicleta",
  "Outros Roubos", "Furto de Veículos", "Furto de Celular", "Furto a Transeunte", "Furto em Coletivo",
  "Furto de Bicicleta", "Outros Furtos", "Sequestro Relâmpago", "Posse Drogas",
  "Pessoas Desaparecidas", "Encontro Cadáver"
)

dados_crimes <- DBI::dbGetQuery(conn = con,
                                "select * from tcc.registro_cisp") %>%
  select(mes:encontro_cadaver, -roubo_rua) %>%
  group_by(mes) %>%
  summarise(across(everything(), ~ sum(.x, na.rm = TRUE)))


colnames(dados_crimes)[2:39] <- nomes_crimes

dados_posts <- DBI::dbGetQuery(conn = con,
                               "select * from tcc.crimes_nome_autor") %>%
  select(data) %>%
  mutate(
    data = as.Date(data),
    mes = floor_date(data, "month") %>% month() # Arredonda dias para o dia 1º do mês
  ) %>%
  group_by(mes) %>%
  summarise(total_posts = n())

df_oficial_longo <- dados_crimes %>%
  pivot_longer(
    cols = -mes, 
    names_to = "tipo_crime", 
    values_to = "qtd_oficial"
  ) %>%
  mutate(mes = mes)

df_posts_longo <- DBI::dbGetQuery(conn = con, "select * from tcc.crimes_nome_autor") %>%
  mutate(
    mes = floor_date(as.Date(data), "month") %>% month(),
    tipo_crime_join = str_trim(nome_crime) 
  ) %>%
  group_by(mes, tipo_crime_join) %>%
  summarise(qtd_posts = n(), .groups = "drop")


classificar_crime <- function(nome) {
  case_when(
    # Assassinatos / Crimes Letais
    str_detect(nome, regex("Homicídio|Latrocínio|Morte por|Lesão Corporal Seguida de Morte", ignore_case = TRUE)) ~ "Crimes Letais",
    
    # Roubos (Excluindo Latrocínio que já foi pego acima se estiver antes, mas por segurança definimos a ordem)
    str_detect(nome, regex("Roubo", ignore_case = TRUE)) ~ "Roubos",
    
    # Furtos
    str_detect(nome, regex("Furto", ignore_case = TRUE)) ~ "Furtos",
    
    # O Resto (Estelionato, Drogas, etc)
    TRUE ~ "Outros"
  )
}

normalizar <- function(x) {
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

df_oficial_agrupado <- df_oficial_longo %>%
  mutate(
    mes_num = mes, 
    grupo = classificar_crime(tipo_crime)
  ) %>%
  filter(grupo != "Outros") %>% # Focar só no que você pediu
  group_by(mes_num, grupo) %>%
  summarise(qtd_real = sum(qtd_oficial, na.rm = TRUE), .groups = "drop")

df_posts_agrupado <- df_posts_longo %>%
  mutate(
    grupo = classificar_crime(tipo_crime_join)
  ) %>%
  filter(grupo != "Outros") %>%
  group_by(mes, grupo) %>% # 'mes' já vem numérico do seu snippet
  summarise(qtd_posts = n(), .groups = "drop") %>%
  rename(mes_num = mes)

df_analise <- inner_join(
  df_oficial_agrupado, 
  df_posts_agrupado, 
  by = c("mes_num", "grupo")
) %>% group_by(grupo) %>% # A normalização deve ser feita DENTRO de cada grupo
  mutate(
    real_norm = normalizar(qtd_real),
    posts_norm = normalizar(qtd_posts)
  ) %>%
  ungroup()

resultado_stats <- df_analise %>%
  group_by(grupo) %>%
  nest() %>%
  mutate(
    # Correlação de Pearson
    correlacao = map_dbl(data, ~ cor(.x$qtd_real, .x$qtd_posts)),
    
    # Regressão Linear (Posts ~ Crime Real)
    modelo = map(data, ~ lm(qtd_posts ~ qtd_real, data = .x)),
    stats = map(modelo, tidy),
    qualidade = map(modelo, glance)
  ) %>%
  unnest(stats) %>%
  unnest(qualidade, names_sep = "_") %>%
  filter(term == "qtd_real") %>%
  select(grupo, correlacao, beta = estimate, p_valor = p.value, r2 = qualidade_r.squared)

ggplot(df_analise, aes(x = real_norm, y = posts_norm, color = grupo)) +
  # Pontos dispersos
  geom_point(size = 3, alpha = 0.7) +
  
  # Linha de tendência para cada grupo (Regressão Linear)
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed") +
  
  # Divide o gráfico em 3 painéis (um para cada grupo) para facilitar a leitura
  facet_wrap(~grupo, scales = "free") +
  
  labs(
    title = "Crime Real e Quantidade de Posts",
    subtitle = "Agrupamento por macro-categorias (Roubos, Furtos e Crimes Letais)",
    caption = "Fonte: dados coletados do ISP e do Instagram",
    x = "Quantidade Oficial de Crimes Normalizados",
    y = "Quantidade de Posts Normalizados",
    color = "Categoria"
  ) +
  tema_tcc

ggsave("plots/correlacao_qtd.png", width = 12, height = 8, dpi = 600)


################################################################################

# A. Dados Oficiais (Longo)
df_oficial <- df_oficial_longo %>%
  mutate(
    mes_date = mes,
    tipo_crime_norm = str_to_lower(str_trim(tipo_crime)) # Padroniza para cruzar
  ) %>%
  group_by(mes_date, tipo_crime_norm, tipo_crime) %>% # Mantém o nome original bonito
  summarise(qtd_real = sum(qtd_oficial, na.rm = TRUE), .groups = "drop")

# B. Dados de Posts (Longo)
df_posts <- df_posts_longo %>%
  mutate(
    # Converte número do mês para data (assumindo ano 2025 conforme conversamos)
    mes_date = mes,
    tipo_crime_norm = str_to_lower(str_trim(tipo_crime_join))
  ) %>%
  group_by(mes_date, tipo_crime_norm) %>%
  summarise(qtd_posts = sum(qtd_posts), .groups = "drop")

# --- 2. Cruzamento Total ---
df_completo <- inner_join(df_oficial, df_posts, by = c("mes_date", "tipo_crime_norm"))

# --- 3. Cálculo das Estatísticas por Crime ---
# 2. Cálculo com Diagnóstico
tabela_geral <- df_completo %>%
  group_by(tipo_crime) %>%
  # Filtro de segurança: remove crimes sem variação (desvio padrão zero)
  filter(sd(qtd_real) > 0 & sd(qtd_posts) > 0 & n() > 3) %>%
  nest() %>%
  mutate(
    # A. Cria o Modelo
    modelo = map(data, ~ lm(qtd_posts ~ qtd_real, data = .x)),
    
    # B. Extrai Correlação (Simples)
    Correlacao = map_dbl(data, ~ cor(.x$qtd_real, .x$qtd_posts)),
    
    # C. Extrai R² (Poder de Explicação)
    R2 = map_dbl(modelo, ~ summary(.x)$r.squared),
    
    # D. Extrai Beta (Impacto) - Extração direta do coeficiente
    Impacto_Beta = map_dbl(modelo, ~ coef(.x)["qtd_real"]),
    
    # E. Extrai P-Valor - Extração direta do sumário do modelo
    P_Valor = map_dbl(modelo, ~ {
      summ <- summary(.x)
      # Tenta pegar o p-valor da linha 'qtd_real'. Se der erro, retorna NA
      tryCatch(coef(summ)["qtd_real", 4], error = function(e) NA)
    })
  ) %>%
  
  # Remove as colunas de lista (data e modelo) para sobrar só a tabela limpa
  select(tipo_crime, Correlacao, R2, Impacto_Beta, P_Valor) %>%
  arrange(desc(R2))

dados_grafico <- tabela_geral %>%
  filter(!is.na(Correlacao)) %>%          # Remove os NAs (erros matemáticos)
  mutate(
    # Cria uma coluna para definir a cor (Positivo vs Negativo)
    Direcao = ifelse(Correlacao > 0, "Acompanha", "Não acompanha"),
    # Ordena o eixo Y do maior para o menor
    tipo_crime = fct_reorder(tipo_crime, Correlacao)
  )

# 2. Gerar o Gráfico
ggplot(dados_grafico, aes(x = Correlacao, 
                          # AQUI ESTÁ A MUDANÇA MÁGICA:
                          y = reorder(tipo_crime, Correlacao), 
                          fill = Direcao)) +
  
  # Cria as barras
  geom_col(width = 0.7, alpha = 0.9) +
  
  # Adiciona o valor numérico
  geom_text(
    aes(label = round(Correlacao, 2), hjust = ifelse(Correlacao > 0, -0.2, 1.2)),
    size = 3.5, fontface = "bold"
  ) +
  
  # Linha vertical no zero
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray30") +
  
  # Cores personalizadas
  scale_fill_manual(values = c("Acompanha" = "#2E86C1", "Não acompanha" = "#C0392B")) +
  
  # Ajustes de eixo
  scale_x_continuous(limits = c(-1.1, 1.1), breaks = seq(-1, 1, 0.5)) +
  
  labs(
    title = "Sincronia entre Realidade e Redes Sociais",
    subtitle = "Correlação entre Ocorrências Reais e Quantidade de Posts",
    x = "Correlação",
    y = "",  # Removemos o rótulo Y porque os nomes já explicam
    fill = "Comportamento",
    caption = "Fonte: ISP e dados coletados do Instagram"
  ) +
  
  tema_tcc

ggsave("plots/sincronia.png", width = 12, height = 8, dpi = 600)

################################################################################

classificar_crime <- function(nome) {
  case_when(
    str_detect(nome, regex("Homicídio|Latrocínio|Morte por|Lesão Corporal Seguida de Morte", ignore_case = TRUE)) ~ "Crimes Letais",
    str_detect(nome, regex("Roubo", ignore_case = TRUE)) ~ "Roubos",
    str_detect(nome, regex("Furto", ignore_case = TRUE)) ~ "Furtos",
    TRUE ~ "Outros"
  )
}

normalizar <- function(x) {
  return ((x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE)))
}

# --- 2. Preparação dos Dados (Agrupados) ---

# A. Dados Oficiais (ISP)
df_real_grupo <- df_oficial_longo %>%
  mutate(grupo = classificar_crime(tipo_crime)) %>%
  filter(grupo != "Outros") %>%
  mutate(mes_date = as.Date(paste0("2025-", mes, "-01"))) %>% # Garante formato data
  group_by(mes_date, grupo) %>%
  summarise(total_real = sum(qtd_oficial, na.rm = TRUE), .groups = "drop")

# B. Dados de Posts (Redes Sociais)
df_posts_grupo <- df_posts_longo %>%
  mutate(grupo = classificar_crime(tipo_crime_join)) %>%
  filter(grupo != "Outros") %>%
  # Se 'mes' no seu df_posts_longo for número (1, 2...), converte para data fictícia do ano 2025
  # Se já for data, use direto. Assumindo que é número conforme seu último snippet:
  mutate(mes_date = as.Date(paste0("2025-", mes, "-01"))) %>% 
  group_by(mes_date, grupo) %>%
  summarise(total_posts = n(), .groups = "drop")

# --- 3. Junção e Normalização ---
df_final_plot <- inner_join(df_real_grupo, df_posts_grupo, by = c("mes_date", "grupo")) %>%
  group_by(grupo) %>%
  mutate(
    # Normaliza DENTRO de cada grupo para as escalas ficarem comparáveis
    Real_Norm = normalizar(total_real),
    Posts_Norm = normalizar(total_posts)
  ) %>%
  ungroup()

# --- 4. Gerando a Série Temporal ---
ggplot(df_final_plot, aes(x = mes_date)) +
  # Adiciona as linhas
  geom_line(aes(y = Real_Norm, color = "Crimes Reais (ISP)"), size = 1.2) +
  geom_line(aes(y = Posts_Norm, color = "Menções (Posts)"), size = 1.2, linetype = "solid") +
  
  # Adiciona os pontos para marcar os meses
  geom_point(aes(y = Real_Norm, color = "Crimes Reais (ISP)"), size = 2) +
  geom_point(aes(y = Posts_Norm, color = "Menções (Posts)"), size = 2) +
  
  # Divide em 3 painéis (um para cada tipo de crime)
  facet_wrap(~grupo, nrow = 3, scales = "free_x") +
  
  # Estética
  scale_x_date(date_labels = "%b", date_breaks = "1 month") + # Mostra Jan, Fev, Mar...
  scale_color_manual(values = c("Crimes Reais (ISP)" = "#d32f2f", "Menções (Posts)" = "#1976D2")) +
  
  labs(
    title = "Histórico da Realidade vs. Percepção",
    subtitle = "Comparação da variação mensal normalizada",
    x = "Mês",
    y = "Intensidade Normalizada",
    color = "Legenda"
  ) +
  tema_tcc +
  theme(legend.position = "top")

ggsave("plots/serie_temporal_crimes.png", width = 12, height = 12, dpi = 600)

################################################################################
query_crimes_cisp <- "
WITH cte_isp AS (
    -- 1. Soma dos registros oficiais (ISP)
    SELECT 
        c.nome_dp, 
        c.geometry, 
        COALESCE(sum(homicidio), 0) as homicidio, 
        COALESCE(sum(latrocinio), 0) as latrocinio, 
        COALESCE(sum(hom_por_intervencao_policial), 0) as hom_por_intervencao_policial, 
        COALESCE(sum(tentat_hom), 0) as tentat_hom, 
        COALESCE(sum(lesao_corp_dolosa), 0) as lesao_corp_dolosa, 
        COALESCE(sum(estupro), 0) as estupro, 
        COALESCE(sum(sequestro), 0) as sequestro, 
        COALESCE(sum(extorsao), 0) as extorsao, 
        COALESCE(sum(estelionato), 0) as estelionato, 
        COALESCE(sum(trafico_drogas), 0) as trafico_drogas, 
        COALESCE(sum(policiais_mortos), 0) as policiais_mortos, 
        COALESCE(sum(lesao_corp_morte), 0) as lesao_corp_morte, 
        COALESCE(sum(hom_culposo), 0) as hom_culposo, 
        COALESCE(sum(lesao_corp_culposa), 0) as lesao_corp_culposa, 
        COALESCE(sum(ameaca), 0) as ameaca, 
        COALESCE(sum(roubo_transeunte), 0) as roubo_transeunte, 
        COALESCE(sum(roubo_celular), 0) as roubo_celular, 
        COALESCE(sum(roubo_em_coletivo), 0) as roubo_em_coletivo, 
        COALESCE(sum(roubo_veiculo), 0) as roubo_veiculo, 
        COALESCE(sum(roubo_carga), 0) as roubo_carga, 
        COALESCE(sum(roubo_rua), 0) as roubo_rua, 
        COALESCE(sum(roubo_residencia), 0) as roubo_residencia, 
        COALESCE(sum(roubo_banco), 0) as roubo_banco, 
        COALESCE(sum(roubo_comercio), 0) as roubo_comercio, 
        COALESCE(sum(roubo_cx_eletronico), 0) as roubo_cx_eletronico, 
        COALESCE(sum(roubo_conducao_saque), 0) as roubo_conducao_saque, 
        COALESCE(sum(roubo_apos_saque), 0) as roubo_apos_saque, 
        COALESCE(sum(roubo_bicicleta), 0) as roubo_bicicleta, 
        COALESCE(sum(outros_roubos), 0) as outros_roubos, 
        COALESCE(sum(furto_veiculos), 0) as furto_veiculos, 
        COALESCE(sum(furto_celular), 0) as furto_celular, 
        COALESCE(sum(furto_transeunte), 0) as furto_transeunte, 
        COALESCE(sum(furto_coletivo), 0) as furto_coletivo, 
        COALESCE(sum(furto_bicicleta), 0) as furto_bicicleta, 
        COALESCE(sum(outros_furtos), 0) as outros_furtos, 
        COALESCE(sum(sequestro_relampago), 0) as sequestro_relampago, 
        COALESCE(sum(posse_drogas), 0) as posse_drogas, 
        COALESCE(sum(pessoas_desaparecidas), 0) as pessoas_desaparecidas, 
        COALESCE(sum(encontro_cadaver), 0) as encontro_cadaver
    FROM tcc.cisp c
    LEFT JOIN tcc.registro_cisp rc ON c.id = rc.cisp_id
    WHERE c.nome_dp != 'Sem DP'
    GROUP BY 1, 2
),
cte_fc AS (
    -- 2. Contagem de Tiroteios (Fogo Cruzado)
    SELECT 
        c.nome_dp, 
        count(ot.id) as tiros
    FROM tcc.bairro b
    LEFT JOIN tcc.ocorrencia_tiroteio ot ON b.id_bairro = ot.bairro_id_bairro
    LEFT JOIN tcc.cisp c ON c.id = b.cisp_id
    WHERE c.nome_dp IS NOT NULL
    GROUP BY 1
),
cte_consolidada AS (
    -- 3. Unifica as tabelas para ter todas as colunas numa linha só
    SELECT 
        i.*,
        COALESCE(f.tiros, 0) as tiros
    FROM cte_isp i
    LEFT JOIN cte_fc f ON i.nome_dp = f.nome_dp
),
cte_unpivot AS (
    -- 4. Transforma Colunas em Linhas usando o seu Dicionário
    SELECT 
        t.nome_dp,
        t.geometry,
        v.nome_crime,
        v.total_ocorrencias
    FROM cte_consolidada t
    CROSS JOIN LATERAL (
        VALUES 
            ('Homicídio Doloso', t.homicidio),
            ('Latrocínio', t.latrocinio),
            ('Morte por Intervenção Policial', t.hom_por_intervencao_policial),
            ('Tentativa de Homicídio', t.tentat_hom),
            ('Lesão Corporal Dolosa', t.lesao_corp_dolosa),
            ('Estupro', t.estupro),
            ('Sequestro', t.sequestro),
            ('Extorsão', t.extorsao),
            ('Estelionato', t.estelionato),
            ('Tráfico Drogas', t.trafico_drogas),
            ('Policiais Mortos em Serviço', t.policiais_mortos),
            ('Lesão Corporal Seguida de Morte', t.lesao_corp_morte),
            ('Homicídio Culposo', t.hom_culposo),
            ('Lesão Corporal Culposa', t.lesao_corp_culposa),
            ('Ameaça', t.ameaca),
            ('Roubo a Transeunte', t.roubo_transeunte),
            ('Roubo de Celular', t.roubo_celular),
            ('Roubo em Coletivo', t.roubo_em_coletivo),
            ('Roubo de Veículo', t.roubo_veiculo),
            ('Roubo de Carga', t.roubo_carga),
            ('Roubo a Residência', t.roubo_residencia),
            ('Roubo a Banco', t.roubo_banco),
            ('Roubo de Comércio', t.roubo_comercio),
            ('Roubo a Caixa Eletrônico', t.roubo_cx_eletronico),
            ('Roubo com Condução a Saque', t.roubo_conducao_saque),
            ('Roubo após Saque', t.roubo_apos_saque),
            ('Roubo de Bicicleta', t.roubo_bicicleta),
            ('Outros Roubos', t.outros_roubos),
            ('Furto de Veículos', t.furto_veiculos),
            ('Furto de Celular', t.furto_celular),
            ('Furto a Transeunte', t.furto_transeunte),
            ('Furto em Coletivo', t.furto_coletivo),
            ('Furto de Bicicleta', t.furto_bicicleta),
            ('Outros Furtos', t.outros_furtos),
            ('Sequestro Relâmpago', t.sequestro_relampago),
            ('Posse Drogas', t.posse_drogas),
            ('Pessoas Desaparecidas', t.pessoas_desaparecidas),
            ('Encontro Cadáver', t.encontro_cadaver),
            ('Tiros', t.tiros)
    ) AS v(nome_crime, total_ocorrencias)
),
cte_ranking AS (
    -- 5. Cria o ranking (do maior para o menor) por DP
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY nome_dp ORDER BY total_ocorrencias DESC) as ranking
    FROM cte_unpivot
)
-- 6. Seleciona apenas o Top 1
SELECT 
    nome_dp,
    geometry,
    nome_crime as crime_principal,
    total_ocorrencias
FROM cte_ranking
WHERE ranking = 1;
"

st_real_cisp <- st_read(con, query=query_crimes_cisp, geometry_column='geometry')

ggplot(data = st_real_cisp) +
  # 2. No aes(), usamos replace_na para trocar NA pelo texto desejado
  # Se sua coluna for fator, use as.character() por segurança: 
  # aes(fill = replace_na(as.character(nome_crime), "Não há dados"))
  geom_sf(aes(fill = replace_na(crime_principal, "Não há dados")), 
          color = "white", 
          size = 0.15) +
  
  scale_fill_manual(
    values = cores,
    name = "Crime Cometido"
    # Note que removemos o argumento 'na.value' pois não haverá mais NAs reais no plot
  ) +
  
  labs(
    title = "Crime Mais Cometido por CISP",
    subtitle = "Baseado nos dados do ISP em 2025",
    caption = "Fonte: ISP"
  ) +
  tema_tcc +
  coord_sf(datum = NA)

ggsave("plots/crime_real_cisp.png", width = 12, height = 8, dpi = 600)


################################################################################

library(ggplot2)
library(dplyr)

# 1. Definir as Cores Semânticas manualmente
cores_categorias <- c(
  "Crimes Letais / Contra a Vida" = "#800000", # Vinho/Sangue (Mais grave)
  "Confronto Armado e Tráfico"    = "#4B0082", # Roxo/Índigo (Guerra/Tensão)
  "Roubos"  = "#D32F2F", # Vermelho Vivo (Alerta cotidiano)
  "Furtos"                        = "#F9A825", # Amarelo/Ouro (Patrimônio menos grave)
  "Outros Delitos"                = "#9E9E9E"  # Cinza (Neutro)
)

# 2. Query Atualizada com o Agrupamento
query_agrupada <- "
WITH Base AS (
    SELECT 
        DATE_TRUNC('month', data)::date as mes_referencia,
        CASE 
            WHEN nome_crime IN ('Homicídio Doloso', 'Latrocínio', 'Morte por Intervenção Policial', 'Lesão Corporal Seguida de Morte', 'Policiais Mortos em Serviço', 'Encontro Cadáver') THEN 'Crimes Letais / Contra a Vida'
            WHEN nome_crime IN ('Tiros', 'Tráfico Drogas', 'Posse Drogas', 'Tentativa de Homicídio') THEN 'Confronto Armado e Tráfico'
            WHEN nome_crime LIKE 'Roubo%' OR nome_crime IN ('Sequestro Relâmpago', 'Extorsão') THEN 'Roubos'
            WHEN nome_crime LIKE 'Furto%' THEN 'Furtos'
            ELSE 'Outros Delitos'
        END as crime_categoria
    FROM tcc.crimes_nome_autor
    WHERE data IS NOT NULL
)
SELECT 
    mes_referencia,
    crime_categoria,
    COUNT(*) as total_ocorrencias
FROM Base
GROUP BY 1, 2
ORDER BY 1, 2;
"

# 3. Executar e Plotar
df_agrupado <- dbGetQuery(con, query_agrupada)

# Forçar a ordem das camadas (Letais no topo ou base, conforme preferir)
df_agrupado$crime_categoria <- factor(df_agrupado$crime_categoria, 
                                      levels = c("Outros Delitos", "Furtos", "Roubos", "Confronto Armado e Tráfico", "Crimes Letais / Contra a Vida"))

ggplot(df_agrupado, aes(x = mes_referencia, y = total_ocorrencias, fill = crime_categoria)) +
  geom_area(alpha = 0.9, size = 0.2, colour = "white") +
  scale_fill_manual(values = cores_categorias, name = "Categoria de Crime") +
  scale_x_date(date_labels = "%b/%Y", date_breaks = "1 month") +
  labs(
    title = "Evolução da Criminalidade por Categoria",
    subtitle = "Agrupamento semântico dos relatos de violência",
    x = "Mês",
    y = "Quantidade de Relatos"
  ) + tema_tcc

ggsave("plots/evolucao_categorias_crime.png", width = 12, height = 7, dpi = 600)

# Salvar
ggsave("plots/evolucao_tipos_crime.png", width = 12, height = 7, dpi = 600)




