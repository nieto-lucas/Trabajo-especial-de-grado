import argparse
import yaml
from pathlib import Path

from lib.neo4j import Neo4jClient, Neo4jConfig
import ast_json, args_json


# Metódos de compresión de un CPG
METHODS = {"ast_json": ast_json.compress_cpg, "args_json": args_json.compress_cpg}


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--method", type=str, choices=["ast_json", "args_json"])
    args = parser.parse_args()

    raw = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    config = Neo4jConfig.from_dict(raw["neo4j"])
    compress_cpg = METHODS[args.method]

    print(f"Aplicando compresión {args.method} a: {config.database}")

    with Neo4jClient(config) as db:
        print(f"\nNúmero de nodos originales: {db.nodes_count()}")
        print(f"Número de aristas originales: {db.relations_count()}\n")

        compress_cpg(db)

        print(f"\nNúmero de nodos post-compresión: {db.nodes_count()}")
        print(f"Número de aristas post-compresión: {db.relations_count()}")


if __name__ == "__main__":
    main()
