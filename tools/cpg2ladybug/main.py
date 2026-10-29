import argparse
from pathlib import Path

import ladybug as lb

from joern_export import export_cpg
from ladybug_loader import load_cpg
from IPA_loader import load_IPA


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cpg_file", type=Path)
    parser.add_argument("--database", type=str, default="cpg.lbdb")
    parser.add_argument("--joern-export-bin", type=Path, required=True)
    parser.add_argument("--export-dir", type=Path, default=Path(".cpg_export"))
    parser.add_argument("--database-dir", type=Path, default=Path("."))
    args = parser.parse_args()

    print(f"==> Exportando {args.cpg_file} en {args.export_dir} ...")
    export_cpg(args.joern_export_bin, args.cpg_file, args.export_dir)

    print(f"\n==> Creando {args.database} en {args.database_dir} ...")
    
    db_path = args.database_dir / Path(f"{args.database}")
    db = lb.Database(db_path)
    conn = lb.Connection(db)
    
    load_cpg(conn, args.export_dir)
    
    print(f"\n==> Creando relaciones intraprocedurales en {args.database} ...")
    
    load_IPA(conn)

    print("\nBase de datos correctamente creada")


if __name__ == "__main__":
    main()
