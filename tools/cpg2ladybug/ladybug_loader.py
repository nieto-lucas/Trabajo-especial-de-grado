"""Carga un CPG a partir de un directorio generado con `joern-export`"""
from pathlib import Path

import ladybug as lb

from neo4jcsv import (
    NodeCsvFile,
    EdgeCsvFile,
    Property,
    find_nodes_csv_files,
    find_edges_csv_files,
)


CSV_LOAD_CONFIG = "(HEADER=false, PARALLEL=false, DELIM=',')"

# En el esquema de Joern CALL es una label de nodos y aristas, 
# ladybug no permite esto
NODE_LABEL_RENAME = {"CALL": "CALL_NODE"}

LADYBUG_TYPES = {
    "int": "INT32",
    "long": "INT64",
    "boolean": "BOOL",
    "float": "FLOAT",
    "double": "DOUBLE",
    "string": "STRING"
}


def load_cpg(conn: lb.Connection, export_dir: Path) -> None:
    """ Carga un CPG exportado con `joern-export`

    Args:
        - conn(lb.Connection) conexión a DB ladybug
        - export_dir(Path) directorio con archivos en formato neo4jcsv
    """
    node_csv_files = find_nodes_csv_files(export_dir)
    for node_csv in node_csv_files:
        _load_nodes(conn, node_csv)

    edge_csv_files = find_edges_csv_files(export_dir)
    for edge_csv in edge_csv_files:
        _load_edges(conn, edge_csv)


def _load_nodes(conn: lb.Connection, node_csv: NodeCsvFile) -> None:
    """ Carga los nodos de un archivo csv con modificaciones para ser 
    compatible con ladybug DB
    """
    table = NODE_LABEL_RENAME.get(node_csv.label, node_csv.label)

    columns = ["`id` INT64"]
    columns += [
        f"`{prop.name}` {_ladybug_type(prop)}" for prop in node_csv.properties
    ]
    columns.append("PRIMARY KEY (`id`)")

    conn.execute(f"CREATE NODE TABLE `{table}` ({', '.join(columns)})")

    values = [f"CAST(column{node_csv.id_position} AS INT64)"]
    values += [_value(prop) for prop in node_csv.properties]
    files = ", ".join(f"'{path}'" for path in node_csv.data_paths)

    conn.execute(
        f"COPY `{table}` FROM " 
        f"(LOAD FROM [{files}] {CSV_LOAD_CONFIG} " 
        f"RETURN {', '.join(values)})"
    )


def _load_edges(conn: lb.Connection, edge_csv: EdgeCsvFile) -> None:
    """ Carga las aritas de un archivo csv con modificaciones para ser 
        compatible con ladybug DB
    """
    properties = [
        f"`{prop.name}` {_ladybug_type(prop)}" for prop in edge_csv.properties
    ]
    conn.execute(
        "CREATE NODE TABLE `_edges` "
        "(`_row` SERIAL, `_start` INT64, `_end` INT64"
        f"{''.join(', ' + prop for prop in properties)}, PRIMARY KEY (`_row`))"
    )
    
    columns = ["`_start`", "`_end`"]
    columns += [f"{prop.name}" for prop in edge_csv.properties]
    
    values = [
        f"CAST(column{edge_csv.start_id_position} AS INT64)",
        f"CAST(column{edge_csv.end_id_position} AS INT64)",
    ]
    values += [_value(prop) for prop in edge_csv.properties]
    files = ', '.join(f"'{path}'" for path in edge_csv.data_paths)

    conn.execute(
        f"COPY `_edges`({', '.join(columns)}) FROM "
        f"(LOAD FROM [{files}] {CSV_LOAD_CONFIG} "
        f"RETURN {', '.join(values)})"
    )

    pairs = conn.execute(
        "MATCH (e:`_edges`) "
        "MATCH (a) WHERE a.id = e._start "
        "MATCH (b) WHERE b.id = e._end "
        "RETURN DISTINCT label(a), label(b)"
    ).get_all()
    relation_pairs = [f"FROM `{start}` TO `{end}`" for start, end in pairs]
    conn.execute(
        f"CREATE REL TABLE `{edge_csv.type}` "
        f"({', '.join(relation_pairs + properties)})"
    )
    returned = ["x.id", "y.id"] + [f"e.`{p.name}`" for p in edge_csv.properties]

    for start, end in pairs:
        conn.execute(
            f"COPY `{edge_csv.type}` FROM (MATCH (e:`_edges`) "
            f"MATCH (x:`{start}`) WHERE x.id = e._start "
            f"MATCH (y:`{end}`) WHERE y.id = e._end "
            f"RETURN {', '.join(returned)}) (from='{start}', to='{end}')"
        )

    conn.execute("DROP TABLE `_edges`")


def _ladybug_type(prop: Property) -> str:
    scalar_type = LADYBUG_TYPES[prop.neo4jcsv_type.removesuffix("[]")]
    if prop.neo4jcsv_type.endswith("[]"):
        return f"{scalar_type}[]"
    
    return scalar_type 


def _value(prop: Property) -> str:
    """Expresión de `LOAD` que da el valor de una propiedad con su tipo"""
    column = f"column{prop.position}"
    if prop.neo4jcsv_type.endswith("[]"):
        column = f"string_split({column}, ';')"
    
    return f"CAST({column} AS {_ladybug_type(prop)})"
