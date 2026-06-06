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
library(RColorBrewer)
library(ggalluvial)
library(ggspatial)
library(stringr)

Sys.setlocale("LC_TIME", "pt_BR.UTF-8")

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


st_logradouros <- read_sf(con, query="select cna.*, ll.geom
from tcc.crimes_nome_autor cna
join tcc.linhas_logradouros ll
	on cna.logradouro = ll.logradouro and cna.nome_bairro = ll.nome_bairro;",
                          geometry_column = 'geom')

# 1. Aplicar a Classificação (Exatamente como você pediu)
dados_classificados <- st_logradouros %>%
  st_centroid() %>% # Garante que temos pontos
  mutate(
    categoria_macro = case_when(
      # GRUPO 1: CRIMES LETAIS / CONTRA A VIDA
      nome_crime %in% c('Homicídio Doloso', 'Latrocínio', 'Morte por Intervenção Policial', 
                        'Lesão Corporal Seguida de Morte', 'Policiais Mortos em Serviço', 
                        'Encontro Cadáver', 'Tentativa de Homicídio') ~ '1. Crimes Letais / Contra a Vida',
      
      # GRUPO 2: CONFRONTO E TRÁFICO
      nome_crime %in% c('Tiros', 'Tráfico Drogas', 'Posse Drogas') ~ '2. Confronto Armado e Tráfico',
      
      # GRUPO 3: ROUBOS (PATRIMONIAIS) - Usamos str_detect para simular o LIKE 'Roubo%'
      str_detect(nome_crime, "Roubo") | nome_crime %in% c('Sequestro Relâmpago', 'Extorsão') ~ '3. Roubos',
      
      # GRUPO 4: FURTOS - Usamos str_detect para simular o LIKE 'Furto%'
      str_detect(nome_crime, "Furto") ~ '4. Furtos',
      
      # GRUPO 5: RESTO
      TRUE ~ '5. Outros Delitos'
    )
  ) %>%
  # Extrair coordenadas para o mapa de calor
  mutate(
    X = st_coordinates(.)[,1],
    Y = st_coordinates(.)[,2]
  ) %>%
  # Filtro Opcional: Remover 'Outros Delitos' para focar no que importa
  filter(categoria_macro != '5. Outros Delitos')

# 2. Gerar o Gráfico
ggplot(dados_classificados) +
  # Mapa Base (Cartolight para contraste limpo)
  annotation_map_tile(type = "osm", zoom = 12, alpha = 0.9) +
  
  # Mapa de Calor (Densidade)
  stat_density_2d(
    aes(x = X, y = Y, fill = after_stat(level)), 
    geom = "polygon", 
    alpha = 0.6,
    bins = 10
  ) +
  
  # Cores: 'turbo' é excelente para destacar hotspots, 'magma' é mais sóbrio
  scale_fill_viridis_c(option = "turbo", name = "Densidade") +
  
  # Cria um mapa separado para cada categoria
  facet_wrap(~categoria_macro, nrow = 2) + 
  
  labs(
    title = "Territorialidade da Violência no Rio de Janeiro",
    subtitle = "Manchas de calor baseadas na natureza da ocorrência (Agrupamento Macro)",
    caption = "Fonte: OpenStreetMap e dados coletados do Instagram"
  ) +
  theme_void() +
  tema_tcc +
  theme(
    axis.title   = element_blank(),
    axis.text    = element_blank(),
    axis.ticks   = element_blank(),
    panel.grid   = element_blank(),
    panel.border = element_blank()
  ) +
  guides(fill = guide_colorbar(title.position = "top", title.hjust = 0.5, label = FALSE, ticks = FALSE)) +
  coord_sf(datum = NA)




# Instale se não tiver
# install.packages("ggspatial")
# install.packages("rosm")

library(ggplot2)
library(sf)
library(ggspatial) # O pacote mágico para OSM
library(dplyr)

# 1. Preparar os Pontos (Centroides)
# Transformamos as linhas das ruas em pontos centrais para o mapa de calor ficar correto
st_pontos_crime <- st_logradouros %>% 
  st_centroid() %>% 
  mutate(
    X = st_coordinates(.)[,1],
    Y = st_coordinates(.)[,2]
  )

# 2. Gerar o Mapa
ggplot(st_pontos_crime) +
  
  # --- CAMADA 1: O MAPA BASE (OSM) ---
  # type = "osm": O mapa colorido clássico (ruas, parques, nomes)
  # zoom: Controle o detalhe (10 a 14 costuma ser bom para cidade/bairro)
  annotation_map_tile(type = "osm", zoom = 12, alpha = 0.7) +
  
  # --- CAMADA 2: MAPA DE CALOR ---
  stat_density_2d(
    aes(x = X, y = Y, fill = after_stat(level)), 
    geom = "polygon", 
    alpha = 0.6, # Transparência para ver o nome da rua embaixo
    bins = 10
  ) +
  
  # Cores da mancha (Magma é ótimo para contraste, mas pode testar outras)
  scale_fill_viridis_c(option = "magma", name = "Intensidade") +
  
  # Divisão por Grupo (Crime Real vs Posts ou Facções)
  facet_wrap(~nome_grupo) +
  
  # Títulos
  labs(
    title = "Percepção de Ação do Crime Organizado",
    subtitle = "Concentração espacial de traficantes e milicianos",
    x = "", 
    y = "",
    caption = "Fonte: OpenStreetMap e dados coletados do Instagram"
  ) +
  
  # Remove eixos desnecessários, mas mantém a caixa do mapa
  tema_tcc + coord_sf(datum = NA) + theme(legend.position = "none")

