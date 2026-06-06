FROM rocker/shiny-verse:4.3.3

# Diretório de trabalho
WORKDIR /code

# 1. Dependências de sistema (Adicionado libpq-dev e locales)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libproj-dev \
    proj-bin \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libpq-dev \
    locales \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen pt_BR.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configura variáveis de ambiente para o idioma
ENV LANG pt_BR.UTF-8
ENV LANGUAGE pt_BR:pt
ENV LC_ALL pt_BR.UTF-8

# 2. Instala pacotes CRAN (Adicionado RPostgres, DBI, dotenv, echarts4r)
RUN install2.r --error \
    shiny \
    bslib \
    dplyr \
    lubridate \
    plotly \
    ggplot2 \
    scales \
    sf \
    leaflet \
    readxl \
    shinyWidgets \
    shinycssloaders \
    reactable \
    shiny.router \
    rlang \
    remotes \
    units \
    httpuv \
    DT \
    RPostgres \
    DBI \
    dotenv \
    echarts4r

# Pacote do GitHub
RUN R -e "remotes::install_github('cpsievert/histoslider')"

# Copia os arquivos da aplicação
COPY . /code

# 3. Garantia de porta (A porta do seu Shiny no PC é 7247, ajuste se necessário)
EXPOSE 7860

# Comando para iniciar o app
CMD ["R", "--quiet", "-e", "shiny::runApp('/code', host='0.0.0.0', port=7860)"]