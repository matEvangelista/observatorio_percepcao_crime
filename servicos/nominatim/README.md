# Nominatim (geocodificação OpenStreetMap)

Servidor Nominatim usado pela etapa **2_classificacao** para normalizar
endereços (bairros e logradouros) dos textos do Instagram. O agente geográfico
em `2_classificacao/tools/tools.py` consulta a API em `http://localhost:8080`.

## Serviços (`docker-compose.yaml`)

| Serviço | Imagem | Portas | Função |
|---|---|---|---|
| `nominatim` | `mediagis/nominatim:5.1` | `8080` (API), `5555→5432` (Postgres interno) | Geocodificação |
| `nominatim-ui` | `nginx:alpine` | `8081→80` | Interface web de busca |

A base carregada é o extrato do **Rio de Janeiro** (`PBF_URL` aponta para o
`rio-de-janeiro.osm.pbf` do OpenStreetMap France). O Postgres interno é exposto
em `5555` para **não conflitar** com o Postgres do projeto (`5432`).

## Como subir

```bash
docker compose up -d
```

> **Primeira execução é demorada:** o container baixa o `.pbf` do Rio e importa
> os dados (alguns minutos a depender da máquina/disco). Acompanhe com
> `docker compose logs -f nominatim` até o serviço ficar pronto.

Teste a API:

```bash
curl "http://localhost:8080/search?q=Avenida+Pasteur,+Urca&format=json"
```

## Sobre o `nominatim-ui`

O serviço `nominatim-ui` monta dois caminhos locais que **não acompanham** este
repositório:

- `./nominatim-ui/dist` — build estático da interface;
- `./nominatim-ui/nginx.conf` — configuração do nginx.

Se você não tem esses arquivos, suba **apenas a API** (que é o que o pipeline
precisa):

```bash
docker compose up -d nominatim
```
