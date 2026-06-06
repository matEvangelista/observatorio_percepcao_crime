# 2 · Classificação

Classifica os textos do Instagram (posts e comentários) com um grafo
**LangGraph** sobre o LLM **Maritaca (Sabiá-4 / Sabiazinho-4)**, extraindo para
cada evento: tipo de crime, autor, grupo criminoso e localização (bairro/logradouro,
geocodificada via Nominatim local).

## Estrutura

| Item | Papel |
|---|---|
| `classes/classes.py` | Modelos Pydantic, enums (`TipoAutorEnum`, `TipoCrimeEnum`) e `GraphState` |
| `nodes/nodes.py` | Nós do grafo: triagem, classificação, validação de regras, agente geográfico |
| `tools/tools.py` | Ferramentas de geocodificação (busca de bairro no banco + Nominatim) |
| `main.ipynb` | Monta e executa o grafo; orquestra posts e comentários |
| `resultados/` | Saídas `.jsonl` (brutas e versões `_LIMPO`) |

## Inputs

- Tabelas `tcc.publicacao` e `tcc.comentario` (geradas na etapa 1).
- `OPENAI_API_KEY` (Maritaca, API compatível com OpenAI), `GOOGLE_API_KEY`
  (Gemini, backup) e `LANGFUSE_*` (opcional) no `.env`.
- **Nominatim** local em `http://localhost:8080`.

## Outputs

- Tabelas `tcc.fato_publicacao_percepcao` e `tcc.fato_comentario_percepcao`.
- `resultados/resultados_processamento_{posts,comentarios}_tcc.jsonl`
  (com checkpoint incremental — reexecutar retoma de onde parou).

## Como rodar

Abra `main.ipynb` **com o diretório de trabalho em `2_classificacao/`** — os
imports `from classes ...`, `from nodes ...`, `from tools ...` dependem disso, e
os `.jsonl` são gravados em `resultados/`.
