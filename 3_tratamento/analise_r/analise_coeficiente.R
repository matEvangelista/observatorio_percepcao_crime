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
    plot.title = element_text(face = "bold", size = 16, color = "#222222"),
    plot.subtitle = element_text(size = 12, color = "#444444"),
    axis.text.x = element_text(angle = 45, hjust = 1, color = "black"),
    axis.text.y = element_text(color = "black"),
    axis.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(hjust = 1, size = 9, color = "#666666", face = "italic", margin = margin(t = 10))
  )

query_vetores <- "
with cte_cisp as (select 'Rio de Janeiro' as nome_dp, st_union(b.geometry) as geometry
from tcc.bairro b
union all
select c.nome_dp, c.geometry
from tcc.cisp c
where c.nome_dp != 'Não identificado')
select c.nome_dp, rv.indice_desalinhamento, rv.crime_superestimado, 
  rv.delta_super_pp, rv.crime_subestimado, rv.delta_sub_pp, c.geometry
from tcc.resultados_vetores rv
left join cte_cisp c
	on rv.nome_dp = c.nome_dp;
"

sf_vetores <- st_read(con,
                      query=query_vetores,
                      geometry_column='geometry')


sf_vetores %>%
  filter(nome_dp != 'Rio de Janeiro') %>%
  ggplot() +
  geom_sf(aes(fill = indice_desalinhamento),
          color = "black", size = 0.2) +
  scale_fill_distiller(
    palette = "YlOrRd",
    direction = 1,
    name = "IDPC",
    limits = c(0, 1)
  ) +
  labs(
    title = "Onde a Percepção Falha?",
    subtitle = "Índice de Distorção da Percepção do Crime por CISP",
    caption = "Fonte: dados do ISP e do Instagram."
  ) +
  tema_tcc +
  coord_sf(
    expand = FALSE,        # remove espaço extra ao redor do mapa
    datum = NA             # REMOVE os rótulos de longitude/latitude
  ) +
  theme(
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank()
  )

ggsave("plots/idpc_cisp.png", width = 12, height = 8, dpi = 600)

################################################################################
sf_vetores$crime_superestimado <- as.factor(sf_vetores$crime_superestimado)

sf_vetores %>% filter(nome_dp != 'Rio de Janeiro') %>% ggplot() +
  # 1. Geometria do Mapa
  geom_sf(aes(fill = crime_superestimado), 
          color = "white",   # Borda branca fica mais elegante em mapas categóricos
          lwd = 0.1) +       # Linha fina
  
  # 2. Aplicação das Cores Semânticas
  scale_fill_manual(
    values = cores, 
    na.value = "grey90",     # Cor para CISPs sem dados
    name = "Crime superestimado"
  ) +
  
  # 3. Textos e Títulos
  labs(
    title = "Qual crime domina o imaginário local?",
    subtitle = "Crime com maior distorção positiva (Percepção > Realidade) por CISP",
    caption = "Fonte: dados coletados do ISP e Instagram."
  ) +
  
  # 4. Tema
  tema_tcc +
  coord_sf(
    expand = FALSE,        # remove espaço extra ao redor do mapa
    datum = NA             # REMOVE os rótulos de longitude/latitude
  )+
  # 5. Ajustes de Mapa
  theme(
    axis.text = element_blank(),      # Remove lat/long
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    legend.position = "right"         # Legenda à direita funciona melhor para muitas categorias
  ) + tema_tcc

ggsave("plots/maior_distorcao.png", width = 12, height = 8, dpi = 600)


################################################################################
sf_vetores %>% filter(nome_dp != 'Rio de Janeiro') %>% ggplot() +
  # 1. Geometria do Mapa
  geom_sf(aes(fill = crime_subestimado), 
          color = "white",   # Borda branca fica mais elegante em mapas categóricos
          lwd = 0.1) +       # Linha fina
  
  # 2. Aplicação das Cores Semânticas
  scale_fill_manual(
    values = cores, 
    na.value = "grey90",     # Cor para CISPs sem dados
    name = "Crime subestimado"
  ) +
  
  # 3. Textos e Títulos
  labs(
    title = "Quais Crimes são Subestimados?",
    subtitle = "Crime com maior distorção negativa (Percepção < Realidade) por CISP",
    caption = "Fonte: dados coletados do ISP e Instagram."
  ) +
  
  # 4. Tema
  tema_tcc +
  coord_sf(
    expand = FALSE,        # remove espaço extra ao redor do mapa
    datum = NA             # REMOVE os rótulos de longitude/latitude
  )+
  # 5. Ajustes de Mapa
  theme(
    axis.text = element_blank(),      # Remove lat/long
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    legend.position = "right"         # Legenda à direita funciona melhor para muitas categorias
  ) + tema_tcc

ggsave("plots/subestimados.png", width = 12, height = 8, dpi = 600)


################################################################################

query_mr <- "
WITH 
-- ========================================================================
-- BLOCO 1: REALIDADE (Volume de Crimes por CISP em 2025)
-- ========================================================================
crimes_2025 AS (
    SELECT 
        c.nome_dp,
        -- Soma horizontal de todos os crimes monitorados no TCC
        COALESCE(SUM(
            COALESCE(rc.homicidio, 0) + 
            COALESCE(rc.latrocinio, 0) + 
            COALESCE(rc.hom_por_intervencao_policial, 0) + 
            COALESCE(rc.tentat_hom, 0) + 
            COALESCE(rc.lesao_corp_dolosa, 0) + 
            COALESCE(rc.estupro, 0) + 
            COALESCE(rc.total_roubos, 0) + 
            COALESCE(rc.total_furtos, 0) + 
            COALESCE(rc.sequestro, 0) + 
            COALESCE(rc.extorsao, 0) + 
            COALESCE(rc.estelionato, 0) + 
            COALESCE(rc.trafico_drogas, 0) + 
            COALESCE(rc.policiais_mortos, 0)
        ), 0) as total_crimes_Ci
    FROM tcc.cisp c
    LEFT JOIN tcc.registro_cisp rc ON c.id = rc.cisp_id
    WHERE rc.ano = 2025 
    GROUP BY c.nome_dp
),

-- ========================================================================
-- BLOCO 2: PERCEPÇÃO & TEMPO (Burstiness e Volume de Menções)
-- ========================================================================
calendario AS (SELECT generate_series('2025-01-01'::date, '2025-12-31'::date, '1 day'::interval)::date as data),

todas_cisps AS (SELECT id, nome_dp FROM cisp),

grid_completo AS (SELECT c.nome_dp, k.data FROM todas_cisps c CROSS JOIN calendario k),

mencoes_brutas AS (
    -- Publicações
    SELECT c.nome_dp, DATE(p.data_publicacao) as data, COUNT(*) as qtd
    FROM publicacao p
    JOIN tcc.fato_publicacao_percepcao fpp ON p.id_publicacao = fpp.publicacao_id_publicacao
    JOIN tcc.bairro b ON fpp.bairro_id_bairro = b.id_bairro
    JOIN tcc.cisp c ON b.cisp_id = c.id
    WHERE EXTRACT(YEAR FROM p.data_publicacao) = 2025 AND fpp.crime_id_crime < 14
    GROUP BY 1, 2
    UNION ALL
    -- Comentários
    SELECT c.nome_dp, DATE(com.data_comentario) as data, COUNT(*) as qtd
    FROM tcc.comentario com
    JOIN tcc.fato_comentario_percepcao fcp ON fcp.comentario_id_comentario = com.id_comentario
    JOIN tcc.bairro b ON fcp.bairro_id_bairro = b.id_bairro
    JOIN tcc.cisp c ON b.cisp_id = c.id
    WHERE EXTRACT(YEAR FROM com.data_comentario) = 2025 AND fcp.crime_id_crime < 14
    GROUP BY 1, 2
),

stats_percepcao AS (
    SELECT 
        g.nome_dp,
        SUM(COALESCE(m.qtd, 0)) as total_mencoes_Pi, 
        AVG(COALESCE(m.qtd, 0)) as mi,
        STDDEV(COALESCE(m.qtd, 0)) as sigma
    FROM grid_completo g
    LEFT JOIN mencoes_brutas m ON g.nome_dp = m.nome_dp AND g.data = m.data
    GROUP BY g.nome_dp
),

-- ========================================================================
-- BLOCO 3: TOTAIS GLOBAIS (Para os Shares)
-- ========================================================================
totais_globais AS (
    SELECT 
        (SELECT SUM(total_crimes_Ci) FROM crimes_2025) as C_total,
        (SELECT SUM(total_mencoes_Pi) FROM stats_percepcao) as P_total
),

-- ========================================================================
-- BLOCO 4: CONSOLIDAÇÃO FINAL (O Cálculo do MR e COLUNA N)
-- ========================================================================
tabela_final AS (
    SELECT
        p.nome_dp,
        
        -- Variáveis Brutas
        p.total_mencoes_Pi as P_i,
        COALESCE(c.total_crimes_Ci, 0) as C_i,
        
        -- Cálculo do Burstiness (B)
        CASE 
            WHEN (p.sigma + p.mi) = 0 THEN 0 
            ELSE (p.sigma - p.mi) / (p.sigma + p.mi) 
        END as burstiness_B,
        
        -- Shares 
        (p.total_mencoes_Pi::numeric / tg.P_total) as share_voice,
        (COALESCE(c.total_crimes_Ci, 0)::numeric / tg.C_total) as share_crime
        
    FROM stats_percepcao p
    LEFT JOIN crimes_2025 c ON p.nome_dp = c.nome_dp
    CROSS JOIN totais_globais tg
)

SELECT 
    tf.nome_dp,
    P_i as volume_mencoes,
    C_i as volume_crimes,
    
    -- Coluna N solicitada (Total de Ocorrências Reais)
    C_i as n, 
    
    ROUND(burstiness_B::numeric, 4) as burstiness,
    
    -- Disparidade de Atenção (IIS)
    ROUND(CASE 
        WHEN share_crime = 0 THEN 0 
        ELSE share_voice / share_crime 
    END, 4) as IIS,
    
    -- Métrica de Reação (MR) = IIS * (1 + B)
    ROUND((CASE 
        WHEN share_crime = 0 THEN 0 
        ELSE (share_voice / share_crime) 
    END * (1 + 
        CASE 
            WHEN P_i = 0 THEN 0 
            ELSE burstiness_B 
        END
    )), 4) as MR,
    
    c.geometry
FROM tabela_final tf
LEFT JOIN tcc.cisp c ON c.nome_dp = tf.nome_dp
WHERE tf.nome_dp NOT IN ('Não identificado')
ORDER BY MR DESC;
"

df_final <- st_read(
  con,
  query = query_mr,
  geometry_column = 'geometry'
)

df_rankings <- df_final %>%
  select(nome_dp, volume_crimes, volume_mencoes) %>%
  mutate(
    # A função rank com o sinal de menos (-) cria um ranking descendente
    # 1 = Quem tem mais crime/menção
    rank_crime = rank(-volume_crimes),
    rank_mencao = rank(-volume_mencoes),
    
    # Calcula a diferença (Gap) para pintar a linha depois se quiser
    gap = rank_mencao - rank_crime 
  ) %>%
  # Reordena o fator 'nome_dp' para que o gráfico siga a ordem da realidade (Crime)
  # Isso faz com que o bairro mais violento (Rank 1) apareça no topo do gráfico
  mutate(nome_dp = reorder(nome_dp, -rank_crime))

ggplot(df_rankings) +
  
  # 1. A linha cinza (o "cabo" do haltere) - essa não precisa de legenda
  geom_segment(aes(x = rank_crime, xend = rank_mencao, y = nome_dp, yend = nome_dp), 
               color = "grey60", size = 0.8) +
  
  # 2. Ponto da Realidade (Azul)
  # MUDANÇA: Colocamos color DENTRO do aes() com o nome que queremos na legenda
  geom_point(aes(x = rank_crime, y = nome_dp, color = "Realidade (ISP)"), 
             size = 3) +
  
  # 3. Ponto da Percepção (Vermelho)
  # MUDANÇA: Idem aqui
  geom_point(aes(x = rank_mencao, y = nome_dp, color = "Percepção (Redes)"), 
             size = 3) +
  
  # 4. Configurar as Cores Manualmente (Onde a mágica acontece)
  # Aqui ligamos o nome que criamos acima à cor que você quer
  scale_color_manual(
    name = NULL, # Deixe NULL para não ter título na legenda (fica mais limpo)
    values = c(
      "Realidade (ISP)" = "blue",   # Ou use "#4682b4" (Azul Aço) para ficar mais elegante
      "Percepção (Redes)" = "red"   # Ou use "#b22222" (Vermelho Sangue)
    ),
    # Isso força a bolinha da legenda a ser maiorzinha para facilitar a leitura
    guide = guide_legend(override.aes = list(size = 4)) 
  ) +
  
  tema_tcc +
  
  labs(
    title = "Deslocamento de Prioridade: O que a Polícia vê vs. O que a Rede vê",
    subtitle = "Comparativo de Ranking entre ocorrências oficiais e volume de menções",
    x = "Posição no Ranking (1 = Mais Crítico)", 
    y = NULL,
    caption = "Fonte: Elaboração própria (2025)."
  )


ggplot(df_final) +
  
  # 1. A Geometria (Polígonos)
  geom_sf(aes(fill = mr), 
          color = "grey80",  # Borda cinza clara (não briga com o vermelho)
          size = 0.1) +      # Linha fina para elegância
  
  # 2. A Escala de Cores (Gradiente de Vermelhos)
  scale_fill_gradient(
    low = "#fff5f0",   # Quase branco (MR baixo = Frio/Invisível)
    high = "#a50f15",  # Vermelho Sangue Escuro (MR alto = Pânico)
    na.value = "grey95", # Cor para áreas sem dados (se houver)
    name = "Índice MR\n(Reação Social)"
  ) +
  
  # 3. Textos e Legendas
  labs(
    title = "Geografia do Clamor Público: Onde a Sociedade Reage?",
    subtitle = "Distribuição espacial da Métrica de Reação (MR) no Rio de Janeiro",
    caption = "Fonte: Elaboração própria. Dados: ISP e Redes Sociais (2025).\nNota: Áreas mais escuras indicam maior desproporção entre falação e crime real."
  ) +
  coord_sf(
    expand = FALSE,        # remove espaço extra ao redor do mapa
    datum = NA             # REMOVE os rótulos de longitude/latitude
  )+
  # 4. Tema
  tema_tcc





################################################################################
library(ggplot2)
library(grid) # Para setas personalizadas

# 1. Dados Simulados (Valores Brutos)
# Realidade: Predomínio do Crime 1 (ex: 90 ocorrências de c1, 10 de c2)
# Percepção: Predomínio do Crime 2 (ex: 20 menções de c1, 80 de c2)
c1_real <- 90; c2_real <- 10
c1_perc <- 20; c2_perc <- 80

# 2. Normalização (Cálculo da norma L2)
# Transformamos em vetores unitários para comparar apenas a DIREÇÃO
norm_real <- sqrt(c1_real^2 + c2_real^2)
norm_perc <- sqrt(c1_perc^2 + c2_perc^2)

df_vetores <- data.frame(
  Tipo = c("Realidade", "Percepção"),
  # Coordenadas Normalizadas (x e y variam entre 0 e 1)
  c1_norm = c(c1_real / norm_real, c1_perc / norm_perc),
  c2_norm = c(c2_real / norm_real, c2_perc / norm_perc)
)

# 3. Gerando o Gráfico
ggplot(data = df_vetores) +
  
  # A. Círculo Unitário (Referência visual de magnitude = 1)
  annotate("path",
           x = cos(seq(0, pi/2, length.out = 100)),
           y = sin(seq(0, pi/2, length.out = 100)),
           color = "grey80", linetype = "dashed") +
  
  # B. Desenhar os Vetores (Setas da origem até o ponto)
  geom_segment(aes(x = 0, y = 0, xend = c1_norm, yend = c2_norm, color = Tipo),
               arrow = arrow(length = unit(0.3, "cm"), type = "closed"), 
               size = 1.2) +
  
  # C. Adicionar os Valores (Rótulos nas pontas)
  geom_text(aes(x = c1_norm, y = c2_norm, 
                label = paste0("(", round(c1_norm, 2), ", ", round(c2_norm, 2), ")"),
                color = Tipo),
            vjust = -1, fontface = "bold") +
  
  # D. Estilização
  scale_color_manual(values = c("Realidade" = "#1976D2", "Percepção" = "#D32F2F")) +
  
  # Importante: coord_fixed garante que 1 unidade em X seja igual a 1 em Y (não distorce o ângulo)
  coord_fixed(xlim = c(-0.1, 1.2), ylim = c(-0.1, 1.2)) +
  
  labs(
    title = "Exemplo de Comparação Vetorial",
    subtitle = "Vetores normalizados para dois crimes distintos",
    x = "Crime 1 Normalizado",
    y = "Crime 2 Normalizado"
  ) +
  tema_tcc

ggsave("vetor_exemplo.png", width = 12, height = 8, dpi = 600)
  
################################################################################
query_qtd_mencoes <- "
with cte as (select c.nome_dp, fpp.id_fato
from tcc.fato_publicacao_percepcao fpp
join tcc.bairro b
	on b.id_bairro = fpp.bairro_id_bairro
join tcc.cisp c
	on b.cisp_id = c.id
where (fpp.crime_id_crime < 14 or fpp.crime_id_crime = 16)
and c.cisp != 99
union all
select c.nome_dp, fcp.id_fato
from tcc.fato_comentario_percepcao fcp
join tcc.bairro b
	on b.id_bairro = fcp.bairro_id_bairro
join tcc.cisp c
	on b.cisp_id = c.id
where (fcp.crime_id_crime < 14 or fcp.crime_id_crime = 16)
and c.cisp != 99)
select nome_dp, count(id_fato)
from cte
group by 1;
"

df_mencoes_cisp <- DBI::dbGetQuery(con, query_qtd_mencoes)

df_indice_qtd <- sf_vetores %>% left_join(df_mencoes_cisp, by='nome_dp') %>%
  filter(nome_dp != 'Rio de Janeiro')

ggplot(df_indice_qtd, aes(x = count, y = indice_desalinhamento)) +
  # Adiciona os pontos
  geom_point(alpha = 1, color = "#2c3e50") +
  
  # Limites do eixo Y (já que o IDPC vai de 0 a 1)
  coord_cartesian(ylim = c(0, 1)) +
  
  labs(
    title = "Influência do Volume de Menções no IDPC",
    subtitle = "IDPC por quantidade de menções na CISP",
    x = "Volume de Ocorrências",
    y = "IDPC"
  ) +
  tema_tcc

ggsave("plots/dispersao.png", width = 12, height = 8, dpi = 600)

# Opção 1: Correlação de Pearson (Testa relação linear)
# Ideal se os dados fossem "bem comportados", mas vale rodar para comparar.
teste_pearson <- cor.test(df_indice_qtd$count, df_indice_qtd$indice_desalinhamento, method = "pearson")

# Imprimir os resultados
print(teste_pearson)







