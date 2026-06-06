# Serviços de infraestrutura

Serviços de apoio (em Docker) que o pipeline espera encontrar rodando. Cada um
tem sua própria pasta e `docker-compose`, para subir de forma independente.

| Serviço | Pasta | Usado por | Porta(s) |
|---|---|---|---|
| **Nominatim** (geocodificação OSM) | [`nominatim/`](nominatim/) | `2_classificacao/tools` (geocodifica bairros/logradouros) | `8080` (API), `8081` (UI), `5555` (Postgres interno) |
| **Langfuse** (observabilidade de LLM) | [`langfuse/`](langfuse/) | `2_classificacao` (tracing das chamadas ao LLM) | `3000` (UI), `9090` (MinIO) + internos |

## Pré-requisitos

- Docker + Docker Compose.

## Como subir

```bash
# Nominatim (geocodificação) — necessário para a etapa 2
cd nominatim && docker compose up -d

# Langfuse (observabilidade) — opcional
cd ../langfuse && docker compose up -d
```

> Os endereços desses serviços são referenciados no `.env` da raiz de `final/`
> (`LANGFUSE_BASE_URL`) e no código da classificação (Nominatim em
> `http://localhost:8080`).
