import sys
import subprocess
from pathlib import Path
from dataclasses import dataclass
from enum import Enum

class Neo4jAdminFlags(Enum):
    NODE = "nodes"
    EDGE = "edges"

@dataclass(frozen=True)
class Neo4jAdminFiles:
    kind: Neo4jAdminFlags
    label: str
    header: Path
    data: Path

    @property
    def admin_flag(self) -> str:
        return "--nodes" if self.kind is Neo4jAdminFlags.NODE else "--relationships"

    def build_import_arg(self) -> str:
        return f"{self.admin_flag}={self.label}={self.header},{self.data}"

def _build_import_cmd(
    neo4j_admin_bin: Path,
    import_files: list[Neo4jAdminFiles], database: str
) -> list[str]:
    # Si no hay archivos nodes* no ejecuta `neo4j-admin`
    if not any(file.kind is Neo4jAdminFlags.NODE for file in import_files):
        raise RuntimeError("No se encontró ningún grupo header+data válido")
    # Corre `neo4j-admin` pisando el contenido de la DB anterior
    cmd = [
        str(neo4j_admin_bin), "database", "import", "full", database,
        "--overwrite-destination=true",
        "--multiline-fields=true"
    ]
    cmd += [file.build_import_arg() for file in import_files]
    return cmd

def run_import(
    neo4j_admin_bin: Path, 
    import_files: list[Neo4jAdminFiles], database: str
) -> None:
    """Importa archivos csv a una DB Neo4j ejecutando un bulk import (carga optimizada) 
    mediante `neo4j-admin` (Puede requiere permisos)
    
    Args:
        - neo4j_admin_bin (Path): Path al comando `neo4j-admin`
        - import_files (list): Lista de archivos para configurar `neo4j-admin` header+data 
        - database (str): Nombre de base de datos
    """
    cmd = _build_import_cmd(neo4j_admin_bin, import_files, database)
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        print("==stdout del import==", file=sys.stderr)
        print(proc.stdout, file=sys.stderr)
        print("==stderr del import==", file=sys.stderr)
        print(proc.stderr, file=sys.stderr)
        raise RuntimeError("El import a Neo4j falló, ver sálida arriba")
