import argparse
import yaml
from pathlib import Path
from lib.neo4j import Neo4jClient, Neo4jConfig
from compress import compress_cpg

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", type=Path, required=True)
    args = ap.parse_args()

    raw = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    config = Neo4jConfig.from_dict(raw["neo4j"])

    with Neo4jClient(config) as db:
        compress_cpg(db)

if __name__ == "__main__":
    main()