import argparse
import sys
from pathlib import Path
from neo4j import GraphDatabase

from test_cases import load_tests
from report import cmp_cypher, print_report
from joern import exec_all_joern_queries

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tests_file", type=Path)
    ap.add_argument("--joern-bin", type=Path, required=True)
    ap.add_argument("--cpg-file", type=Path, required=True)
    ap.add_argument("--neo4j-uri", default="bolt://localhost:7687")
    ap.add_argument("--neo4j-user", default="neo4j")
    ap.add_argument("--neo4j-password", required=True)
    ap.add_argument("--debug-dir", type=Path, default=Path(".joern_equiv"),
                     help="Dónde guardar el .sc generado y el JSON de salida (default: ./.joern_equiv)")
    args = ap.parse_args()
 
    tests = load_tests(args.tests_file)
    print(f"==> {len(tests)} test(s) cargados de {args.tests_file}")

    print()
    print("==> Corriendo queries en Joern (una sola pasada) ...")
    joern_results = exec_all_joern_queries(args.joern_bin, args.cpg_file, tests, args.debug_dir)

    print()
    print("==> Corriendo queries equivalentes en Neo4j ...")
    driver = GraphDatabase.driver(args.neo4j_uri, auth=(args.neo4j_user, args.neo4j_password))
    try:
        outcomes = cmp_cypher(tests, joern_results, driver)
    finally:
        driver.close()
 
    todo_ok = print_report(outcomes)
    sys.exit(0 if todo_ok else 1)

if __name__ == "__main__":
    main()
