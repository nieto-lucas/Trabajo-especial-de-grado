import re
from pathlib import Path

from joern_export import export_cpg
from neo4j_admin import Neo4jAdminFlags, Neo4jAdminFiles, run_import

# Expresión regular para obtener archivos de la carpeta export generada en joern-export
_FILENAME_RE = re.compile(r"^(nodes|edges)_([A-Za-z0-9_]+)_(header|data|cypher)\.csv$")

def _ensure_id_persist(header_path: Path) -> None:
    fields = header_path.read_text(encoding="utf-8").rstrip("\n").split(",")
    changed = False
    for i, field in enumerate(fields):
        # cambiamos los campos ID del archivo header por id:ID 
        # (sino no persiste id que se obtiene de joern) 
        if field == ":ID" or field.startswith(":ID("):
            fields[i] = "id" + field
            changed = True

    if changed:
        header_path.write_text(",".join(fields) + "\n", encoding="utf-8")

def _prepare_neo4jcsv_files(export_dir: Path) -> list[Neo4jAdminFiles]:
    """Prepara los archivos neo4jcsv del directorio export para poder importar sus
    datos mediante `neo4j-admin`

    Args:
        - export_dir (Path): Directorio del que obtiene archivos neo4jcsv
    
    Return:
        Lista de archivos para configurar `neo4j-admin` contiene header+data. 
        Descarta archivos *_cypher.csv (cargan una DB mediante LOAD CSV, menos optimo)
    """
    files_by_group: dict[((Neo4jAdminFlags, str), str), Path] = {}
    files_unmatch = []

    for csv_file in sorted(export_dir.glob("*.csv")):
        file_match = _FILENAME_RE.match(csv_file.name)
        if not file_match:
            files_unmatch.append(csv_file)
            continue

        kind, label, part = file_match.groups()
        if part == "cypher":
            continue

        group_key = (
            Neo4jAdminFlags.NODE if kind == "nodes" else Neo4jAdminFlags.EDGE,
            label
        )
        if group_key not in files_by_group:
            files_by_group[group_key] = {}
        files_by_group[group_key][part] = csv_file

    if files_unmatch:
        print(f"    WARNING: no se pudieron parsear: {files_unmatch}")

    files = []
    for (kind, label), files_by_part in files_by_group.items():
        if "header" not in files_by_part or "data" not in files_by_part:
            print(f"    WARNING: {kind}_{label} no tiene header+data completos")
            continue

        if kind is Neo4jAdminFlags.NODE:
            _ensure_id_persist(files_by_part["header"])

        files.append(Neo4jAdminFiles(
            kind, label,
            header=files_by_part["header"],
            data=files_by_part["data"]
        ))

    return files

def cpg_to_neo4j(
    joern_export_bin: Path, neo4j_admin_bin: Path,
    cpg_file: Path, export_dir: Path, database: str
) -> None:
    """Exporta un CPG a formato neo4jcsv, luego crea una DB Neo4j usando el bulk import de 
    `neo4j-admin` para importar el CPG

    Args:
        - joern_export_bin (Path): Path al comando `joern-export`
        - neo4j_admin_bin (Path): Path al comando `neo4j-admin`
        - cpg_file (Path): Archivo cpg.bin que importa a una DB Neo4j
        - export_dir (Path): Directorio sobre el que se exporta el CPG en formato neo4jcsv
        - database (str): Nombre de base de datos
    """
    print(f"==> Exportando CPG en {export_dir} ...")
    export_cpg(joern_export_bin, cpg_file, export_dir)
    print("     CPG exportado")

    print(f"\n==> Importando archivos neo4jscv a {database} ...")
    import_files = _prepare_neo4jcsv_files(export_dir)
    print("     WARNING: neo4j-admin database import requiere Neo4j detenido")
    run_import(neo4j_admin_bin, import_files, database)
    print("     Archivos neo4jcsv importados")
