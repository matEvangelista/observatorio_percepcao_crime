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
library(ggalluvial)

################################################################################
# Lista dos perfis
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

################################################################################
# 
# # 1. Montando o Dataframe com a Hierarquia Lógica: Total -> Crime -> ISP -> Final
# dados_sankey <- data.frame(
#   pagina = rep(c("ZONA OESTE URGENTE", "Folha Zona Norte RJ", "Rio de Nojeira Oficial"), each = 3),
#   etapa = rep(c("1. Total Coletado","2. Crimes do ISP\nou\nRegistros do Fogo Cruzado", "3. Crimes do ISP\nou\nRegistros do Fogo Cruzado\ncom bairros"), 3),
#   valor = c(
#     1113, 253, 244,    # ZO
#     742, 268, 259,     # FZN
#     3167, 951, 941    # RN
#   )
# )
# 
# # Ordenando as etapas logicamente
# dados_sankey$etapa <- factor(dados_sankey$etapa, levels = c(
#   "1. Total Coletado", "2. Crimes do ISP\nou\nRegistros do Fogo Cruzado", "3. Crimes do ISP\nou\nRegistros do Fogo Cruzado\ncom bairros"
# ))
# 
# # === CÓDIGO CORRIGIDO ===
# ggplot(dados_sankey, aes(x = etapa, y = valor, alluvium = pagina, stratum = pagina)) + # Adicionado stratum = pagina
#   
#   # 1. O Fluxo (Alluvium)
#   geom_alluvium(aes(fill = pagina), 
#                 alpha = 0.7, 
#                 width = 1/3,
#                 curve_type = "sigmoid") +
#   
#   # 2. Os Blocos (Stratum)
#   geom_stratum(aes(fill = pagina), width = 1/3, color = "white") +
#   
#   # 3. Os Textos (Rótulos)
#   # stat = "stratum" calcula a posição correta no meio do bloco
#   geom_text(stat = "stratum", aes(label = valor), size = 3, fontface = "bold", color = "white") +
#   #scale_y_continuous(trans = "log10") +
#   # 4. Estética
#   scale_fill_manual(values = c("#4682b4", "#b22222", "#228b22")) +
#   
#   labs(title = "Funil para as Publicações",
#        subtitle = "Fluxo de publicações por etapa de filtragem e página em escala logarítmica",
#        y = "Número de Publicações (Log10)",
#        x = NULL,
#        fill = "Página") +
#   
#   tema_tcc +
#   theme(axis.text.y = element_blank(),)
# ggsave("filtro_publicacao.png", width = 12, height = 8, dpi = 600)
# 
# ################################################################################
# 
# # 1. Dados (Mesmo dataframe anterior)
# dados_sankey_comentarios <- data.frame(
#   pagina = rep(c("ZONA OESTE URGENTE", "Folha Zona Norte RJ", "Rio de Nojeira Oficial"), each = 3),
#   etapa = rep(c("1. Total Coletado", "2. Crimes do ISP\nou\nRegistros do Fogo Cruzado", "3. Crimes do ISP\nou\nRegistros do Fogo Cruzado\ncom bairros"), 3),
#   valor = c(
#     51627, 168, 168,     # ZO
#     220698, 1531, 1529,    # FZN
#     374221, 3216, 3213    # RN
#   )
# )
# 
# # Ordem dos fatores
# dados_sankey_comentarios$etapa <- factor(dados_sankey_comentarios$etapa, levels = c(
#   "1. Total Coletado", "2. Crimes do ISP\nou\nRegistros do Fogo Cruzado", "3. Crimes do ISP\nou\nRegistros do Fogo Cruzado\ncom bairros"
# ))
# 
# # 2. Gráfico com Escala Log
# ggplot(dados_sankey_comentarios, aes(x = etapa, y = valor, alluvium = pagina, stratum = pagina)) +
#   
#   # Fluxo
#   geom_alluvium(aes(fill = pagina), 
#                 alpha = 0.7, 
#                 width = 1/3,
#                 curve_type = "sigmoid") +
#   
#   # Blocos
#   geom_stratum(aes(fill = pagina), width = 1/3, color = "white") +
#   geom_text(stat = "stratum", aes(label = scales::comma(valor, accuracy = 1)), 
#             size = 2.5, fontface = "bold", color = "white") +
#   scale_y_continuous(trans = "log10") +
#   scale_fill_manual(values = c("#4682b4", "#b22222", "#228b22")) +
#   labs(title = "Funil para os Comentários",
#        subtitle = "Fluxo de comentários por etapa de filtragem e página em escala logarítmica",
#        y = "Número de Comentários (Log10)",
#        x = NULL,
#        fill = "Página") +
#   tema_tcc +
#   theme(
#     axis.text.y = element_blank(),
#     panel.grid.major.y = element_line(color = "grey90") # Grades ajudam a ler log
#   )
# ggsave("filtro_comentarios.png", width = 12, height = 8, dpi = 600)
# ################################################################################

query_serie_crimes <- "
with cte as (select mes, sum(rc.registro_ocorrencias) as qtd_ocorrencias
from tcc.registro_cisp rc
group by 1),
cte2 as (select extract(month from data) as mes, count(id) as qtd_mencoes
from tcc.crimes_nome_autor cna
group by 1)
select c.mes, c.qtd_ocorrencias, c2.qtd_mencoes
from cte c
left join cte2 c2
	on c.mes = c2.mes
order by 1;
"

################################################################################
query_eventos_bairro <- "
WITH cte_dados AS (
    SELECT fcp.id_fato, fcp.bairro_id_bairro
    FROM tcc.fato_comentario_percepcao fcp
    WHERE (fcp.crime_id_crime <= 41) 
      AND fcp.bairro_id_bairro != 0
    UNION ALL
    SELECT fpp.id_fato, fpp.bairro_id_bairro
    FROM tcc.fato_publicacao_percepcao fpp 
    WHERE (fpp.crime_id_crime <= 41) 
      AND fpp.bairro_id_bairro != 0
)
SELECT 
    b.nome_bairro, 
    b.geometry, 
    COUNT(cd.id_fato) AS qtd_eventos
FROM tcc.bairro b              -- 1. Começamos pela tabela DIMENSÃO (Todos os bairros)
LEFT JOIN cte_dados cd         -- 2. Usamos LEFT JOIN (Traz tudo da esquerda, mesmo sem match na direita)
    ON b.id_bairro = cd.bairro_id_bairro
WHERE b.id_bairro != 0         -- 3. Filtramos para não trazer o bairro 'Não Identificado' (ID 0) na listagem final
GROUP BY 1, 2;
"

st_eventos_bairro <- st_read(con, query=query_eventos_bairro, geometry_column='geometry')
ggplot(data = st_eventos_bairro) +
  # color="white" e size=0.1 criam bordas finas para separar os bairros
  geom_sf(aes(fill = qtd_eventos), color = "white", size = 0.2) +
  
  # Cria o gradiente: Claro (pouco crime) -> Escuro (muito crime)
  scale_fill_gradient(
    low = "grey",   # Rosa bem claro/Bege
    high = "#a50f15",  # Vermelho Sangue Escuro
    name = "Eventos de crime",
  ) +
  
  labs(
    title = "Crimes Mencionados por Bairro",
    subtitle = "Total de eventos de crime registrados nos posts",
    caption = "Fonte: dados coletados do Instagram"
  ) +
  
  theme_void() + tema_tcc + coord_sf(datum = NA)

ggsave("plots/qtd_crimes_bairro.png", width = 12, height = 8, dpi = 600)
########################### crime mais percebido por bairro#####################
query_crime_percebido_bairro <- "
WITH uniao_fatos AS (
    SELECT crime_id_crime, bairro_id_bairro FROM tcc.fato_comentario_percepcao
    UNION ALL
    SELECT crime_id_crime, bairro_id_bairro FROM tcc.fato_publicacao_percepcao
),
contagem_por_bairro AS (
    SELECT 
        f.bairro_id_bairro,
        c.nome_crime,
        COUNT(*) as total_mencoes
    FROM uniao_fatos f
    JOIN tcc.crime c ON f.crime_id_crime = c.id_crime
    -- Filtra apenas crimes válidos para o ranking
    WHERE f.bairro_id_bairro != 0
    GROUP BY f.bairro_id_bairro, c.nome_crime
),
ranking_crimes AS (
    SELECT 
        bairro_id_bairro,
        nome_crime,
        total_mencoes,
        -- Rankeia: O crime com mais menções ganha posicao 1
        ROW_NUMBER() OVER(PARTITION BY bairro_id_bairro ORDER BY total_mencoes DESC) as posicao
    FROM contagem_por_bairro
)
SELECT 
    b.nome_bairro, 
    COALESCE(r.nome_crime, 'Não há dados') as nome_crime,
    -- Se for NULL, mostra 0
    COALESCE(r.total_mencoes, 0) as total_mencoes,
    b.geometry
FROM tcc.bairro b
LEFT JOIN ranking_crimes r 
    ON b.id_bairro = r.bairro_id_bairro AND r.posicao = 1
WHERE b.id_bairro != 0
ORDER BY r.total_mencoes DESC NULLS LAST;
"

st_crime_percebido_bairro <- st_read(
  con, query=query_crime_percebido_bairro, geometry_column='geometry'
)

ggplot(data = st_crime_percebido_bairro) +
  geom_sf(
    aes(
      fill  = replace_na(nome_crime, "Não há dados"),
      color = replace_na(nome_crime, "Não há dados")
    ),
    size = 0.2
  ) +
  
  scale_fill_manual(
    values = c(
      cores,                 # cores dos crimes
      "Não há dados" = "white"
    ),
    name = "Crime Percebido"
  ) +
  
  scale_color_manual(
    values = c(
      setNames(rep("white", length(cores)), names(cores)), # contorno normal
      "Não há dados" = "#999999"                            # contorno cinza
    ),
    guide = "none"  # remove legenda duplicada de cor
  ) +
  
  labs(
    title = "Crime Mais Associado a cada Bairro",
    subtitle = "Baseado na frequência de relatos de crime",
    caption = "Fonte: dados coletados no Instagram"
  ) +
  tema_tcc +
  coord_sf(datum = NA)

ggsave("plots/bairro_crime.png", width = 12, height = 8, dpi = 600)

################################################################################

query_autor_bairro <- "
WITH uniao_dados AS (
    -- 1. Pega os dados dos Comentários
    SELECT bairro_id_bairro, autor_crime_id_autor
    FROM tcc.fato_comentario_percepcao
    WHERE (crime_id_crime <= 41) -- Filtro de crimes violentos/tiros

    UNION ALL

    -- 2. Pega os dados das Publicações (O que faltava)
    SELECT bairro_id_bairro, autor_crime_id_autor
    FROM tcc.fato_publicacao_percepcao
    WHERE (crime_id_crime < 42)
),
ContagemAutores AS (
    SELECT 
        b.nome_bairro,
        ac.nome_autor, 
        b.geometry,
        -- Conta quantas vezes esse autor apareceu na união dos dois
        COUNT(u.autor_crime_id_autor) as total_ocorrencias,
        ROW_NUMBER() OVER (
            PARTITION BY b.nome_bairro 
            ORDER BY COUNT(u.autor_crime_id_autor) DESC
        ) as ranking
    FROM tcc.bairro b
    -- 3. Faz o LEFT JOIN com a tabela UNIFICADA
    LEFT JOIN uniao_dados u 
        ON b.id_bairro = u.bairro_id_bairro
    LEFT JOIN tcc.autor_crime ac 
        ON ac.id_autor = u.autor_crime_id_autor
    WHERE b.id_bairro != 0
    -- AND (ac.id_autor != 16 OR ac.id_autor IS NULL) 
    GROUP BY b.nome_bairro, ac.nome_autor, b.geometry
)
SELECT 
    nome_bairro, 
    COALESCE(nome_autor, 'Não há dados') as nome_autor, 
    geometry,
    total_ocorrencias -- Útil para colocar no tooltip do mapa
FROM ContagemAutores
WHERE ranking = 1;
"

st_autor_bairro <- st_read(con, query = query_autor_bairro, geometry_column='geometry')


ggplot(data = st_autor_bairro) +
  geom_sf(
    aes(
      fill  = replace_na(nome_autor, "Não há dados"),
      color = replace_na(nome_autor, "Não há dados")
    ),
    linewidth = 0.3
  ) +
  
  scale_fill_manual(
    values = c(
      cores_perfis,
      "Não há dados" = "white"
    ),
    name = "Autor Predominante",
    drop = TRUE
  ) +
  
  scale_color_manual(
    values = c(
      setNames(rep("white", length(cores_perfis)), names(cores_perfis)),
      "Não há dados" = "#999999"
    ),
    guide = "none"
  ) +
  
  labs(
    title = "Autor de Crime Mais Citado por Bairro",
    subtitle = "Baseado na frequência de relatos de crime",
    caption = "Fonte: Dados coletados do Instagram"
  ) +
  
  tema_tcc +
  coord_sf(datum = NA)

ggsave("plots/autor_bairro.png", width = 12, height = 8, dpi = 600)
################################################################################
query_crime_percebido_isp <- "
WITH uniao_fatos AS (
    SELECT crime_id_crime, bairro_id_bairro FROM tcc.fato_comentario_percepcao
    UNION ALL
    SELECT crime_id_crime, bairro_id_bairro FROM tcc.fato_publicacao_percepcao
),
contagem_por_cisp AS (
    SELECT 
        cp.id,
        c.nome_crime,
        COUNT(*) as total_mencoes
    FROM uniao_fatos f
    JOIN tcc.crime c ON f.crime_id_crime = c.id_crime
    JOIN tcc.bairro b ON f.bairro_id_bairro = b.id_bairro
    JOIN tcc.cisp cp ON b.cisp_id = cp.id
    WHERE f.bairro_id_bairro != 0 
      AND c.nome_crime NOT IN ('Sem Crime') -- Filtro importante
    GROUP BY cp.id, c.nome_crime
),
ranking_crimes AS (
    SELECT 
        id,
        nome_crime,
        total_mencoes,
        -- Critério de desempate: Ordem alfabética se houver empate nas menções
        ROW_NUMBER() OVER(PARTITION BY id ORDER BY total_mencoes DESC, nome_crime ASC) as posicao
    FROM contagem_por_cisp
)
SELECT 
    cp.nome_dp,
    COALESCE(r.nome_crime, 'Sem menções') as nome_crime, -- Trata nulos visualmente
    COALESCE(r.total_mencoes, 0) as total_mencoes,
    cp.geometry
FROM tcc.cisp cp
LEFT JOIN ranking_crimes r 
    ON cp.id = r.id AND r.posicao = 1
WHERE cp.nome_dp != 'Sem DP'
ORDER BY total_mencoes DESC;
"

st_crime_percebido_cisp <- st_read(
  con,
  query = query_crime_percebido_isp,
  geometry_column = 'geometry'
)



# crime e autor
query_relacao_autor_crime <- "
with cte as (SELECT 
    ac.nome_autor, 
    c.nome_crime
FROM tcc.fato_comentario_percepcao fcp -- Começa pelo FATO (ocorrência real)
INNER JOIN tcc.crime c 
    ON c.id_crime = fcp.crime_id_crime
LEFT JOIN tcc.autor_crime ac 
    ON ac.id_autor = fcp.autor_crime_id_autor
WHERE c.nome_crime not in ('Sem Crime')
  and ac.nome_autor != 'Sem Crime'
UNION ALL
SELECT 
    ac.nome_autor, 
    c.nome_crime
FROM tcc.fato_publicacao_percepcao fpp -- Começa pelo FATO
INNER JOIN tcc.crime c 
    ON c.id_crime = fpp.crime_id_crime
LEFT JOIN tcc.autor_crime ac 
    ON ac.id_autor = fpp.autor_crime_id_autor
WHERE c.nome_crime not in ('Sem Crime')
and ac.nome_autor != 'Sem Crime'
)
select nome_autor, nome_crime, count(*) as qtd
from cte c
group by 1, 2;
"
df_crime_autor <- DBI::dbGetQuery(con, query_relacao_autor_crime)

ggplot(df_crime_autor, aes(x = nome_autor, y = nome_crime, fill = qtd)) +
  
  # 1. Desenha os quadrados do mapa de calor
  # color = "white" cria uma borda branca para separar os blocos visualmente
  geom_tile(color = "white") +
  
  # 2. Adiciona os números dentro dos quadrados (opcional, mas útil)
  geom_text(aes(label = qtd), color = "black", size = 3) +
  
  # 3. Define as cores (Gradiente)
  # Usamos scale_fill_gradient para ir de uma cor clara (pouco) para escura (muito)
  scale_fill_gradient(low = "#e0f7fa", high = "#006064", name = "Número de associações") +
  # OU, para uma escala de vermelhos:
  # scale_fill_gradient(low = "#fee0d2", high = "#de2d26") +
  
  # 4. Ajustes visuais
  labs(
    title = "Relação de Crimes e seus Autores",
    subtitle = "Baseada na associação entre crime e autor identificada pelo modelo Sabiá 4",
    x = "Autor",
    y = "Crime",
    caption = 'Fonte: dados extraídos do Instagram'
  ) +
  theme_minimal() + # Tema limpo
  # 5. Rotacionar nomes no eixo X para não encavalar
  tema_tcc

ggsave("plots/heatmap.png", width = 12, height = 8, dpi = 600)
###############################################################################
st_trafico_milicia <- st_read(con,
                              query="
WITH cte_uniao_fatos AS (
    -- 1. Unir as tabelas de fatos (Traficante e Miliciano)
    SELECT fcp.bairro_id_bairro, ac.nome_autor
    FROM tcc.fato_comentario_percepcao fcp
    JOIN tcc.autor_crime ac ON ac.id_autor = fcp.autor_crime_id_autor
    WHERE fcp.bairro_id_bairro != 0 
      AND fcp.autor_crime_id_autor IN (2,3) 
      AND fcp.nome_grupo not in ('Tráfico não identificado')
    
    UNION ALL
    
    SELECT fpp.bairro_id_bairro, ac.nome_autor
    FROM tcc.fato_publicacao_percepcao fpp
    JOIN tcc.autor_crime ac ON ac.id_autor = fpp.autor_crime_id_autor
    WHERE fpp.bairro_id_bairro != 0 
      AND fpp.autor_crime_id_autor IN (2,3) 
      AND fpp.nome_grupo not in ('Tráfico não identificado')
),
ContagemPorBairro AS (
    -- 2. Pivô: Contar quantos de cada lado existem por bairro
    SELECT 
        bairro_id_bairro,
        SUM(CASE WHEN nome_autor = 'Traficante' THEN 1 ELSE 0 END) as qtd_trafico,
        SUM(CASE WHEN nome_autor = 'Miliciano' THEN 1 ELSE 0 END) as qtd_milicia
    FROM cte_uniao_fatos
    GROUP BY bairro_id_bairro
)
-- 3. Classificação Final
SELECT 
    b.nome_bairro,
    CASE 
        -- Se Trafico for maior que Milicia
        WHEN COALESCE(c.qtd_trafico, 0) > COALESCE(c.qtd_milicia, 0) THEN 'Traficante'
        
        -- Se Milicia for maior que Trafico
        WHEN COALESCE(c.qtd_milicia, 0) > COALESCE(c.qtd_trafico, 0) THEN 'Miliciano'
        
        -- Se forem IGUAIS e maiores que zero (Empate)
        WHEN COALESCE(c.qtd_trafico, 0) = COALESCE(c.qtd_milicia, 0) AND COALESCE(c.qtd_trafico, 0) > 0 THEN 'Disputa/Indefinido'
        
        -- Se não tiver nada
        ELSE 'Sem menção'
    END as nome_autor,
    
    -- Pega a maior quantidade para usar na escala (opcional)
    GREATEST(COALESCE(c.qtd_trafico, 0), COALESCE(c.qtd_milicia, 0)) as qtd_mencoes,
    
    b.geometry
FROM tcc.bairro b
LEFT JOIN ContagemPorBairro c ON b.id_bairro = c.bairro_id_bairro
WHERE b.id_bairro != 0;", geometry_column='geometry')


# 1. Definir as Cores do Confronto (Vermelho vs Azul)
cores_confronto <- c(
  # Caso os dados estejam como "Traficante" e "Miliciano"
  "Sem menção" = 'gray90',
  "Traficante" = "#D32F2F",  # Vermelho Vivo
  "Miliciano"  = "#1976D2"  # Azul Royal
)

# 1. Definir as Cores do Confronto (Vermelho vs Azul vs Roxo)
cores_confronto <- c(
  "Sem menção"         = "gray90",
  "Traficante"         = "#D32F2F",  # Vermelho Vivo
  "Miliciano"          = "#1976D2",  # Azul Royal
  "Disputa/Indefinido" = "#7B1FA2"   # Roxo (Indica mistura/conflito)
)

# 2. Gerar o Mapa
ggplot(data = st_trafico_milicia) +
  # Desenha os bairros
  geom_sf(aes(fill = nome_autor), color = "white", size = 0.2) +
  
  # Aplica as cores manuais
  scale_fill_manual(
    values = cores_confronto,
    name = "Predominância",
    na.value = "gray90"
  ) +
  
  # Títulos e Legendas
  labs(
    title = "Disputa Territorial: Tráfico vs. Milícia",
    subtitle = "Mapa dos tipo de crime organizado mais associado a cada bairro",
    caption = "Fonte: dados extraídos do Instagram"
  ) +
  
  coord_sf(datum = NA) +
  theme_minimal() +
  tema_tcc

ggsave("plots/trafico_milicia.png", width = 12, height = 8, dpi = 600)
################################################################################
# 1. Leitura e Processamento dos Dados (SQL)
st_faccoes <- st_read(con, query="
WITH cte_uniao_fatos AS (
    -- Unir Publicações e Comentários, filtrando apenas as facções
    SELECT fcp.bairro_id_bairro, fcp.nome_grupo
    FROM tcc.fato_comentario_percepcao fcp
    WHERE fcp.bairro_id_bairro != 0 
      AND fcp.nome_grupo IN ('Comando Vermelho', 'Terceiro Comando Puro', 'Amigos dos Amigos')
    
    UNION ALL
    
    SELECT fpp.bairro_id_bairro, fpp.nome_grupo
    FROM tcc.fato_publicacao_percepcao fpp
    WHERE fpp.bairro_id_bairro != 0 
      AND fpp.nome_grupo IN ('Comando Vermelho', 'Terceiro Comando Puro', 'Amigos dos Amigos')
),
ContagemPorBairro AS (
    -- Pivô: Contar menções de cada facção por bairro
    SELECT 
        bairro_id_bairro,
        SUM(CASE WHEN nome_grupo = 'Comando Vermelho' THEN 1 ELSE 0 END) as qtd_cv,
        SUM(CASE WHEN nome_grupo = 'Terceiro Comando Puro' THEN 1 ELSE 0 END) as qtd_tcp,
        SUM(CASE WHEN nome_grupo = 'Amigo dos Amigos' THEN 1 ELSE 0 END) as qtd_ada
    FROM cte_uniao_fatos
    GROUP BY bairro_id_bairro
)
-- Classificação Final (Quem ganha?)
SELECT 
    b.nome_bairro,
    CASE 
        -- CV ganha de todos
        WHEN COALESCE(c.qtd_cv, 0) > COALESCE(c.qtd_tcp, 0) 
             AND COALESCE(c.qtd_cv, 0) > COALESCE(c.qtd_ada, 0) THEN 'Comando Vermelho'
        
        -- TCP ganha de todos
        WHEN COALESCE(c.qtd_tcp, 0) > COALESCE(c.qtd_cv, 0) 
             AND COALESCE(c.qtd_tcp, 0) > COALESCE(c.qtd_ada, 0) THEN 'Terceiro Comando Puro'
        
        -- ADA ganha de todos
        WHEN COALESCE(c.qtd_ada, 0) > COALESCE(c.qtd_cv, 0) 
             AND COALESCE(c.qtd_ada, 0) > COALESCE(c.qtd_tcp, 0) THEN 'Amigos dos Amigos'
        
        -- Se não tem ninguém (tudo zero ou null)
        WHEN COALESCE(c.qtd_cv, 0) + COALESCE(c.qtd_tcp, 0) + COALESCE(c.qtd_ada, 0) = 0 THEN 'Sem menção'
        
        -- Se sobrou, é empate/disputa entre os líderes
        ELSE 'Indefinido'
    END as faccao_dominante,
    
    b.geometry
FROM tcc.bairro b
LEFT JOIN ContagemPorBairro c ON b.id_bairro = c.bairro_id_bairro
WHERE b.id_bairro != 0;", geometry_column='geometry')


# 2. Definir as Cores das Facções
# Sugestão: Vermelho (CV), Verde (TCP), Laranja/Ouro (ADA), Roxo (Disputa)
cores_faccoes <- c(
  "Sem menção"            = "gray90",
  "Comando Vermelho"      = "#D32F2F",  # Vermelho clássico
  "Terceiro Comando Puro" = "#2E7D32",  # Verde (para diferenciar da Milícia azul e CV vermelho)
  "Amigos dos Amigos"      = "#F9A825",  # Amarelo/Ouro
  "Indefinido"    = "#7B1FA2"   # Roxo
)

# 3. Gerar o Mapa
ggplot(data = st_faccoes) +
  # Camada dos Bairros
  geom_sf(aes(fill = faccao_dominante), color = "white", size = 0.2) +
  
  # Cores manuais
  scale_fill_manual(
    values = cores_faccoes,
    name = "Facção Predominante",
    na.value = "gray90"
  ) +
  
  # Títulos
  labs(
    title = "Geografia das Facções: CV e TCP",
    subtitle = "Classificação baseada na maioria simples de menções por bairro",
    caption = "Fonte: dados extraídos do Instagram"
  ) +
  
  coord_sf(datum = NA) +
  theme_minimal() +
  tema_tcc # Seu tema personalizado

# Salvar
ggsave("plots/distribuicao_faccoes.png", width = 12, height = 8, dpi = 600)

################################################################################

st_percepcao_cisp <- st_read(con,
                             query = "
    WITH uniao_fatos AS (
        SELECT crime_id_crime, bairro_id_bairro FROM tcc.fato_comentario_percepcao
        UNION ALL
        SELECT crime_id_crime, bairro_id_bairro FROM tcc.fato_publicacao_percepcao
    ),
    ContagemPorCisp AS (
        SELECT 
            c.id as cisp_id,
            c2.nome_crime,
            COUNT(*) as qtd_ocorrencias
        FROM uniao_fatos uf
        JOIN tcc.bairro b 
            ON b.id_bairro = uf.bairro_id_bairro
        JOIN tcc.cisp c 
            ON c.id = b.cisp_id
        JOIN tcc.crime c2 
            ON c2.id_crime = uf.crime_id_crime
        WHERE uf.bairro_id_bairro != 0 
          AND (c2.id_crime < 14 OR c2.id_crime = 16)
        GROUP BY c.id, c2.nome_crime
    ),
    RankingCrimes AS (
        SELECT 
            cisp_id,
            nome_crime,
            qtd_ocorrencias,
            ROW_NUMBER() OVER(
                PARTITION BY cisp_id 
                ORDER BY qtd_ocorrencias DESC
            ) as posicao
        FROM ContagemPorCisp
    )
    SELECT 
        c.nome_dp,
        -- Tratamento para o Dashboard não quebrar com NA
        COALESCE(rc.nome_crime, 'Sem Registros') as nome_crime, 
        COALESCE(rc.qtd_ocorrencias, 0) as qtd_ocorrencias,
        c.geometry
    FROM tcc.cisp c  -- ADICIONEI O 'tcc.' AQUI
    LEFT JOIN RankingCrimes rc 
        ON c.id = rc.cisp_id 
        AND rc.posicao = 1
    WHERE c.nome_dp != 'Não identificado';",
                             geometry_column = 'geometry'
)


ggplot(data = st_percepcao_cisp) +
  # 2. No aes(), usamos replace_na para trocar NA pelo texto desejado
  # Se sua coluna for fator, use as.character() por segurança: 
  # aes(fill = replace_na(as.character(nome_crime), "Não há dados"))
  geom_sf(aes(fill = replace_na(nome_crime, "Não há dados")), 
          color = "white", 
          size = 0.15) +
  
  scale_fill_manual(
    values = cores,
    name = "Crime Percebido"
    # Note que removemos o argumento 'na.value' pois não haverá mais NAs reais no plot
  ) +
  
  labs(
    title = "Crime Mais Associado a cada CISP",
    subtitle = "Baseado na frequência de relatos de crime",
    caption = "Fonte: dados coletados no Instagram"
  ) +
  tema_tcc +
  coord_sf(datum = NA)

ggsave("plots/percepcao_cisp.png", width = 12, height = 8, dpi = 600)
################################################################################
st_autor_cisp <- st_read(
  con,
  query="
  WITH uniao_fatos AS (
    -- 1. Unimos as tabelas de fatos trazendo Autor, Bairro e Crime
    SELECT autor_crime_id_autor, bairro_id_bairro, crime_id_crime 
    FROM tcc.fato_comentario_percepcao
    UNION ALL
    SELECT autor_crime_id_autor, bairro_id_bairro, crime_id_crime 
    FROM tcc.fato_publicacao_percepcao
),
ContagemPorCisp AS (
    -- 2. Fazemos o JOIN para chegar na CISP e contamos os Autores
    SELECT 
        c.id as cisp_id,
        ac.nome_autor,
        COUNT(*) as qtd_ocorrencias
    FROM uniao_fatos uf
    JOIN tcc.bairro b 
        ON b.id_bairro = uf.bairro_id_bairro
    JOIN tcc.cisp c 
        ON c.id = b.cisp_id -- Conexão Bairro -> CISP
    JOIN tcc.autor_crime ac 
        ON ac.id_autor = uf.autor_crime_id_autor
    WHERE uf.bairro_id_bairro != 0 
      -- Mantendo o filtro dos crimes relevantes do seu trabalho
      AND (uf.crime_id_crime < 14 OR uf.crime_id_crime = 16)
      -- Opcional: Se quiser ignorar quando não sabem quem foi, descomente a linha abaixo:
      -- AND ac.nome_autor != 'Autor Não Identificado'
    GROUP BY c.id, ac.nome_autor
),
RankingAutores AS (
    -- 3. Criamos o Ranking (1º lugar = mais citado)
    SELECT 
        cisp_id,
        nome_autor,
        qtd_ocorrencias,
        ROW_NUMBER() OVER(
            PARTITION BY cisp_id 
            ORDER BY qtd_ocorrencias DESC
        ) as posicao
    FROM ContagemPorCisp
)
-- 4. Seleção Final com a Geometria da CISP
SELECT 
    c.nome_dp,
    COALESCE(ra.nome_autor, 'Sem Dados') as nome_autor, 
    c.geometry
FROM tcc.cisp c
LEFT JOIN RankingAutores ra 
    ON c.id = ra.cisp_id 
    AND ra.posicao = 1
where c.nome_dp != 'Não Identificado'; -- Pega apenas o autor vencedor",
geometry_column = 'geometry'
)


ggplot(data = st_autor_cisp) +
  geom_sf(aes(fill = nome_autor), color = "white", size = 0.15) +
  
  scale_fill_manual(
    values = cores_perfis,
    name = "Autor Predominante",
    # O drop = FALSE garante que todas as cores da legenda apareçam 
    # (ou remova se quiser apenas os que existem no mapa)
    drop = TRUE 
  ) +
  
  labs(
    title = "Autor de Crime Mais Citado por CISP",
    subtitle = "Baseado na frequência de relatos de crime",
    caption = "Fonte: Dados coletados do Instagram"
  ) +
  
  tema_tcc +         # Seu tema personalizado
  coord_sf(datum = NA) # Remove as coordenadas (lat/long)

ggsave("plots/autor_crime_cisp.png", width = 12, height = 8, dpi = 600)









