import sys 
import shutil
import subprocess
from pathlib import Path

def export_cpg(joern_export_bin: Path, cpg_file: Path, export_dir: Path) -> None:
    """Exporta un CPG al format neo4csv usando `joern-export`

    Args:
        - joern_export_bin (Path): Path al comando `joern-export`
        - cpg_file (Path): Archivo cpg.bin que exportar
        - export_dir (Path): Directorio al que exportar archivos neo4jcsv
    """
    if export_dir.exists():
        shutil.rmtree(export_dir)
    # Corre `joern-export` con formato neo4jcsv
    cmd = [
        str(joern_export_bin), str(cpg_file),
        "--repr", "all", "--format", "neo4jcsv", "--out", str(export_dir)
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        print("== stdout de joern ==", file=sys.stderr)
        print(proc.stdout, file=sys.stderr)
        print("== stderr de joern ==", file=sys.stderr)
        print(proc.stderr, file=sys.stderr)
        raise RuntimeError("joern-export falló, ver sálida arriba")
