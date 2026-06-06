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
# Tente uma dessas opções dependendo do seu sistema operacional:

Sys.setlocale("LC_TIME", "pt_BR.UTF-8")

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

df_evolucao_faccoes <- dbGetQuery(con, "
WITH cte_timeline AS (
    -- 1. Dados das Publicações (Data da Postagem)
    SELECT 
        DATE_TRUNC('month', p.data_publicacao)::date as mes_referencia,
        g.nome_grupo
    FROM tcc.fato_publicacao_percepcao fpp
    JOIN tcc.publicacao p ON fpp.publicacao_id_publicacao = p.id_publicacao
    JOIN tcc.grupo_criminoso g ON fpp.grupo_id = g.id_grupo
    WHERE g.nome_grupo IN ('Comando Vermelho', 'Milícia', 'Terceiro Comando Puro', 'Amigo dos Amigos')

    UNION ALL

    -- 2. Dados dos Comentários (Data do Comentário - Repercussão)
    SELECT 
        DATE_TRUNC('month', c.data_comentario)::date as mes_referencia,
        g.nome_grupo
    FROM tcc.fato_comentario_percepcao fcp
    JOIN tcc.comentario c ON fcp.comentario_id_comentario = c.id_comentario
    JOIN tcc.grupo_criminoso g ON fcp.grupo_id = g.id_grupo
    WHERE g.nome_grupo IN ('Comando Vermelho', 'Milícia', 'Terceiro Comando Puro', 'Amigo dos Amigos')
)
-- 3. Agrupamento Final
SELECT 
    mes_referencia,
    nome_grupo,
    COUNT(*) as total_mencoes
FROM cte_timeline
GROUP BY 1, 2
ORDER BY 1, 2;
")


# 1. Definir Cores Oficiais (Mantendo consistência com seus mapas)
cores_faccoes <- c(
  "Comando Vermelho"      = "#D32F2F",  # Vermelho
  "Milícia"               = "#1976D2",  # Azul
  "Terceiro Comando Puro" = "#2E7D32",  # Verde
  "Amigo dos Amigos"      = "#F9A825"   # Amarelo/Ouro
)

# 2. Gerar o Gráfico
plot_evolucao <- ggplot(df_evolucao_faccoes, aes(x = mes_referencia, y = total_mencoes, fill = nome_grupo)) +
  
  # Geometria de Área (alpha ajuda a ver sobreposições se quiser, mas stacked é sólido)
  geom_area(position = "stack", alpha = 0.9, colour = "white", size = 0.2) +
  
  # Cores Manuais
  scale_fill_manual(values = cores_faccoes, name = "Grupo Criminoso") +
  
  # Escalas
  scale_x_date(date_labels = "%b/%Y", date_breaks = "1 month") + # Ex: Jan/2024
  scale_y_continuous(expand = c(0, 0)) + # Remove espaço vazio na base
  
  # Textos
  labs(
    title = "Dinâmica de Poder: Evolução das Menções ao Crime Organizado",
    subtitle = "Soma de citações em publicações e comentários",
    x = "Mês de Referência",
    y = "Volume de Menções",
    caption = "Fonte: dados coletados do Instagram"
  ) +
  
  # Tema
  theme_minimal() +
  tema_tcc

# 3. Exibir e Salvar
print(plot_evolucao)
ggsave("plots/evolucao_faccoes_timeline.png", width = 12, height = 7, dpi = 600)





