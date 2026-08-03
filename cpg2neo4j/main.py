import argparse
from pathlib import Path

from cpg_to_neo4j import cpg_to_neo4j

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cpg_file", type=Path)
    ap.add_argument("--joern-export-bin", type=Path, required=True)
    ap.add_argument("--neo4j-admin-bin", type=Path, required=True)
    ap.add_argument("--export-dir", type=Path, default=Path("./.export"))
    ap.add_argument("--database", default="neo4j")
    args = ap.parse_args()

    print(f"==> Creando DB Neo4j: {args.database} ...\n")

    cpg_to_neo4j(
        joern_export_bin=args.joern_export_bin,
        neo4j_admin_bin=args.neo4j_admin_bin,
        cpg_file=args.cpg_file, 
        export_dir=args.export_dir,
        database=args.database
    )

    print("\nBase de datos correctamente creada")

if __name__ == "__main__":
    main()
