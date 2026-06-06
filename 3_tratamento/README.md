# 3 · Tratamento e Análise

Calcula os índices que comparam percepção × realidade, gera os gráficos do TCC,
avalia a qualidade do classificador e analisa a violência em nível de logradouro.

## Subpastas

| Pasta | O que faz | Saída |
|---|---|---|
| `vetores_idpc/` | `manipulacao_dados.ipynb`: monta vetores de percepção e realidade por CISP, calcula o **IDPC** (distância cosseno) e geometrias de logradouros | `tcc.resultados_vetores`, `tcc.linhas_logradouros` |
| `analise_r/` | 5 scripts R: mapas, séries temporais, correlações, índices espaciais (IDPC, MR) | PNGs em `analise_r/plots/` |
| `avaliacao/` | `main.ipynb`: matriz de confusão e acurácia do classificador (autor, crime, grupo, bairro) | `cm_*.png` |
| `comparacao/` | `main.ipynb`: demonstração de NER com BERT (experimento à parte, não entra no pipeline) | — |

## Inputs

- Banco PostgreSQL via `.env` (Python e R).
- `avaliacao/main.ipynb` lê `avaliar.csv` (dataset anotado manualmente, na própria pasta).

## Outputs

- Tabelas `tcc.resultados_vetores` e `tcc.linhas_logradouros` (consumidas pelo painel).
- Figuras em `analise_r/plots/` e `analise_r/` (preservadas do TCC) e `avaliacao/cm_*.png`.

## Como rodar

1. **`vetores_idpc/manipulacao_dados.ipynb` primeiro** — ele popula
   `tcc.resultados_vetores`, que alimenta os scripts R e o painel.
2. **`analise_r/`** — rode os scripts com o diretório de trabalho em `analise_r/`
   (eles carregam o `.env` em `../../.env` e gravam em `plots/`).
   > Comece por `graficos_cisp.R`: ele cria o objeto de conexão `con` que
   > `graficos_percepcao.R` e `historico_milicia.R` reaproveitam na mesma sessão R.
3. **`avaliacao/main.ipynb`** — gera as matrizes de confusão.
