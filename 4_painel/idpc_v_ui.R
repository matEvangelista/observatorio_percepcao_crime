idpc_v_ui <- tags$section(
  get_navbar(active_page = "idpc-v"),
  tags$section(
    class = "container",

    div(class = "row mt-5",
        div(class = "col-12",
            h1("IDPC-V"),
            p(class = "paragrafo-descricao mt-3",
              "O IDPC-V (Índice de Distorção da Percepção do Crime — Volume) compara o volume
               de menções a crimes no Instagram com o volume de ocorrências oficiais registradas
               pelo ISP, ambos normalizados pela população da CISP."),
            p(class = "paragrafo-descricao",
              tags$b("Fórmula: "), "IDPC-V = (P − R) / (P + R), onde P e R são as taxas por 100.000
               habitantes de menções no Instagram e ocorrências oficiais. O resultado varia de −1
               (crime invisível nas redes — subestimado) a +1 (percepção sem respaldo oficial —
               superestimado); valores próximos de 0 indicam alinhamento.")
        )
    ),

    div(class = 'plot-container mt-5',
        div(
          class = 'd-flex justify-content-between align-items-center',
          h2("IDPC-V AGREGADO POR CISP"),
          downloadButton("download_idpc_v_agregado", "EXPORTAR VISUALIZAÇÃO")
        ),
        div(class = 'row mt-3',
            p(class = 'col-12', style = 'line-height: 1.5rem',
              "Considerando todos os crimes somados, quão distorcida é a percepção em cada
               circunscrição? Valores em azul indicam superestimação; em vermelho, subestimação.")
        ),
        div(class = 'row g-3 mt-3',
            div(class = 'col-md-8',
                leafletOutput("mapa_idpc_v_agregado", height = "600px", width = "100%") %>%
                  withSpinner(color = "#FF9D00")
            ),
            div(class = 'col-md-4',
                div(class = "card h-100 border-0 bg-light",
                    div(class = "card-body",
                        h4("Detalhes da CISP", class = "card-title text-muted mb-4"),
                        uiOutput("painel_idpc_v_agregado") %>% withSpinner(color = "#FF9D00")
                    )
                )
            )
        )
    ),

    div(class = 'plot-container mt-5 mb-5',
        div(
          class = 'd-flex justify-content-between align-items-center',
          h2("IDPC-V POR CRIME E CISP"),
          downloadButton("download_idpc_v_crime", "EXPORTAR VISUALIZAÇÃO")
        ),
        div(class = 'row mt-3',
            p(class = 'col-12', style = 'line-height: 1.5rem',
              "Selecione um crime para ver onde ele é mais superestimado (azul) ou subestimado
               (vermelho). Clique em uma CISP para ver o ranking de distorções por tipo de crime
               naquela localidade.")
        ),
        div(class = 'row mt-3',
            div(class = 'col-md-4 offset-md-4',
                selectInput("idpc_v_crime", "Crime:",
                            choices  = crimes_comparacao,
                            selected = "Homicídio Doloso")
            )
        ),
        div(class = 'row g-3 mt-1',
            div(class = 'col-md-8',
                leafletOutput("mapa_idpc_v_crime", height = "600px", width = "100%") %>%
                  withSpinner(color = "#FF9D00")
            ),
            div(class = 'col-md-4',
                div(class = "card h-100 border-0 bg-light",
                    div(class = "card-body",
                        h4("Ranking por Crime", class = "card-title text-muted mb-4"),
                        uiOutput("painel_idpc_v_crime") %>% withSpinner(color = "#FF9D00")
                    )
                )
            )
        )
    )
  )
)
