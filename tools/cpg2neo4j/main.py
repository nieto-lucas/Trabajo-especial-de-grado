import yaml
import argparse
from pathlib import Path

from cpg_to_neo4j import cpg_to_neo4j, CpgToNeo4jConfig

def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("cpg_file", type=Path)
    ap.add_argument("--config", type=Path, required=True)
    ap.add_argument("--database", type=Path, default="neo4j")
    ap.add_argument("-c", "--compress", action="store_true")
    args = ap.parse_args()

    with open(args.config, "r", encoding="utf-8") as config:
        entries = yaml.safe_load(config)

    import_config = CpgToNeo4jConfig.from_dict(entries["cpg2neo4j"])                                 
    print(f"==> Creando DB Neo4j: {args.database} ...\n")

    cpg_to_neo4j(
        cpg_file=args.cpg_file,
        database=args.database,
        import_config=import_config,
    )

    print("\nBase de datos correctamente creada")


if __name__ == "__main__":
    main()
