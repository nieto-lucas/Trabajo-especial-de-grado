import argparse
import sys
from pathlib import Path
import ladybug as lb

from test_cases import load_tests
from report import cmp_cypher, create_report
from joern import exec_all_joern_queries


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, 
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("tests_file", type=Path)
    parser.add_argument("--joern-bin", type=Path, required=True)
    parser.add_argument("--cpg-file", type=Path, required=True)
    parser.add_argument("--db-path", type=Path, required=True,
                        help="Base LadyBugDB con el CPG ya cargado")
    parser.add_argument("--debug-dir", type=Path, default=Path(".joern_equiv"),
                        help="Dónde guardar el .sc generado y el JSON " \
                        "de salida (default: ./.joern_equiv)")
    args = parser.parse_args()
 
    tests = load_tests(args.tests_file)
    print(f"==> {len(tests)} test(s) cargados de {args.tests_file}")

    print("\n==> Corriendo queries en Joern (una sola pasada) ...")
    joern_results = exec_all_joern_queries(
        args.joern_bin, args.cpg_file, tests, args.debug_dir
    )

    print("\n==> Corriendo queries equivalentes en Neo4j ...")
    database = lb.Database(str(args.db_path))
    conn = lb.Connection(database)
    outcomes = cmp_cypher(tests, joern_results, conn)
 
    todo_ok = create_report(outcomes)
    sys.exit(0 if todo_ok else 1)

if __name__ == "__main__":
    main()
