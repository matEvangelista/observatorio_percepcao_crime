# Coleta do Instagram

Esta etapa baixa posts e comentários de perfis de monitoramento de crime no Rio
e carrega tudo no PostgreSQL. O download bruto é feito com o
[**instaloader**](https://instaloader.github.io/) (declarado no `pyproject.toml`).

## Fluxo

```
instaloader (scrape)  ─►  extrair_jsonxz.py  ─►  carga_instagram.ipynb  ─►  Postgres
   (.json.xz/.json)        (descompacta .xz)       (lê e insere)            tcc.*
```

## 1. Scrape com o instaloader

Rode **uma vez para cada perfil**. O comando baixa só os metadados (texto +
comentários), ignorando imagens e vídeos, e filtra por data:

```bash
instaloader --comments --no-pictures --no-videos <pagina> \
    --load-cookies Firefox \
    --post-filter="date_utc > datetime(aaaa, mm, dd)"
```

Perfis usados no projeto:

```bash
instaloader --comments --no-pictures --no-videos folhazonanorte    --load-cookies Firefox --post-filter="date_utc > datetime(2025, 1, 1)"
instaloader --comments --no-pictures --no-videos riodenojeiraoficial --load-cookies Firefox --post-filter="date_utc > datetime(2025, 1, 1)"
instaloader --comments --no-pictures --no-videos zonaoesteurgente   --load-cookies Firefox --post-filter="date_utc > datetime(2025, 1, 1)"
```

### O que cada flag faz

| Flag | Função |
|---|---|
| `--comments` | baixa também os comentários de cada post |
| `--no-pictures` `--no-videos` | ignora mídia (só texto/metadados — coleta mais leve) |
| `<pagina>` | username do perfil (vira o nome da pasta de saída) |
| `--load-cookies Firefox` | reaproveita a sessão logada do navegador (via `browser-cookie3`); requer estar logado no Instagram no Firefox |
| `--post-filter="date_utc > datetime(aaaa, mm, dd)"` | baixa só posts após a data informada — troque `aaaa, mm, dd` (ex.: `2025, 1, 1`) |

> **Login obrigatório:** o Instagram exige sessão autenticada para comentários.
> O `--load-cookies Firefox` lê os cookies do Firefox; para outro navegador,
> troque o nome (ex.: `Chrome`). Respeite os limites de taxa do Instagram para
> evitar bloqueio — colete aos poucos.

## 2. Saída esperada

O instaloader cria **uma pasta por perfil**, cada uma com arquivos por post:

```
<INSTAGRAM_SCRAPE_DIR>/
├── folhazonanorte/
│   ├── 2025-03-14_18-22-05.json.xz          # metadados do post (comprimido)
│   ├── 2025-03-14_18-22-05_comments.json    # comentários do post
│   └── ...
├── riodenojeiraoficial/
└── zonaoesteurgente/
```

Esses ~2,1 GB **não acompanham** o `final/`. Aponte a pasta-raiz do scrape via
`INSTAGRAM_SCRAPE_DIR` no `.env`, ou use o symlink `raw/` desta pasta
(ver [README da etapa](../README.md) e o `.env.example` da raiz).

## 3. Descompactar e carregar

```bash
python extrair_jsonxz.py        # descompacta os .json.xz → .json
# depois abra carga_instagram.ipynb (cwd nesta pasta) para inserir em:
#   tcc.pagina · tcc.publicacao · tcc.comentario
```

Ambos resolvem o caminho do scrape por `INSTAGRAM_SCRAPE_DIR` (com fallback para
o symlink `raw/`).
