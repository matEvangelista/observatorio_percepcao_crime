import lzma
import json
import os


def extrair_jsonxz(pasta):
    """
    Extrai todos os arquivos .json.xz de uma pasta,
    salvando cada um como .json com o mesmo nome original.
    """
    for arquivo in os.listdir(pasta):
        caminho = os.path.join(pasta, arquivo)

        # Ignora diretórios
        if not os.path.isfile(caminho):
            continue

        if arquivo.endswith(".json.xz"):
            base_nome = os.path.splitext(os.path.splitext(arquivo)[0])[
                0
            ]  # remove .json.xz
            destino = os.path.join(pasta, f"{base_nome}.json")

            try:
                with lzma.open(caminho, "rt", encoding="utf-8") as f_in, open(
                    destino, "w", encoding="utf-8"
                ) as f_out:
                    dados = json.load(f_in)
                    json.dump(dados, f_out, ensure_ascii=False, indent=2)

            except Exception as e:
                print(f"Erro ao processar {arquivo}: {e}")
    print(f"Pasta {pasta} processada")


def main():
    # O scrape bruto do Instagram (~2,1 GB) NÃO acompanha final/.
    # Aponte para ele via a variável de ambiente INSTAGRAM_SCRAPE_DIR
    # (ver .env.example) ou crie o symlink ./raw -> pasta do scrape.
    scrape_dir = os.environ.get(
        "INSTAGRAM_SCRAPE_DIR",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw"),
    )

    pastas_scrape = [
        os.path.join(scrape_dir, pasta) for pasta in os.listdir(scrape_dir)
    ]

    for pasta in pastas_scrape:
        extrair_jsonxz(pasta)


if __name__ == "__main__":
    main()