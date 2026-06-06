# Langfuse (observabilidade de LLM)

Stack self-hosted do Langfuse para rastrear as chamadas ao LLM na etapa
**2_classificacao**. O notebook usa o `LangfuseCallbackHandler`, que lê do
`.env` da raiz de `final/`:

```
LANGFUSE_SECRET_KEY=
LANGFUSE_PUBLIC_KEY=
LANGFUSE_BASE_URL=http://localhost:3000
```

O Langfuse é **opcional** — a classificação roda sem ele; apenas não haverá tracing.

## Segredos

Os defaults deste `docker-compose.yml` já foram **rotacionados para valores
aleatórios e descartáveis**, exclusivos deste stack local — nenhuma senha
pessoal ou reaproveitada permanece no arquivo, e não há e-mail pessoal. Como
todos os serviços ficam em `localhost` (só `langfuse-web:3000` e `minio:9090`
expostos), esses defaults são adequados para uso local.

Se quiser usar segredos próprios (ou rodar fora de `localhost`), o compose usa a
sintaxe `${VAR:-default}`: crie um `.env` **nesta pasta** (o `docker compose` o
carrega automaticamente) e sobrescreva o que quiser. Há um modelo em
[`.env.example`](.env.example):

```bash
cp .env.example .env   # preencha com segredos NOVOS; este .env é git-ignored
```

> Recomendado: gerar segredos fortes, p.ex. `openssl rand -hex 32` para
> `ENCRYPTION_KEY`/`NEXTAUTH_SECRET` e `openssl rand -hex 16` para `SALT`.

## Serviços e portas

| Serviço | Porta no host | Observação |
|---|---|---|
| `langfuse-web` | `3000` | UI/API → este é o `LANGFUSE_BASE_URL` |
| `langfuse-worker` | `127.0.0.1:3030` | processamento assíncrono |
| `postgres` (do Langfuse) | `127.0.0.1:9999→5432` | **separado** do Postgres do projeto (5432) |
| `clickhouse` | `127.0.0.1:8123`, `9000` | armazenamento analítico |
| `minio` | `9090→9000` (API), `127.0.0.1:9091→9001` (console) | object storage |
| `redis` | `127.0.0.1:6379` | fila/cache |

Não há conflito de portas com o resto do projeto (Postgres do TCC em 5432,
Nominatim em 8080/8081/5555, painel em 7860).

## Como subir

```bash
docker compose up -d
# primeira subida baixa várias imagens e roda migrações — aguarde ~1-2 min
```

## Conectar o pipeline

1. Acesse `http://localhost:3000` e crie a conta/projeto (ou preencha
   `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`/`..._SECRET_KEY` no `.env` para já iniciar
   com as chaves definidas).
2. Copie as chaves do projeto (public/secret) para o `.env` da **raiz de final/**
   (`LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`) e mantenha
   `LANGFUSE_BASE_URL=http://localhost:3000`.
