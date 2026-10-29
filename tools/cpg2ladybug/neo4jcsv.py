import csv
from pathlib import Path
from typing import Iterator
from dataclasses import dataclass


NODE_FIELDS = {":ID", ":LABEL"}

EDGE_FIELDS = {":START_ID", ":END_ID", ":TYPE"}


@dataclass(frozen=True)
class Property:
    name: str
    neo4jcsv_type: str
    position: int


@dataclass(frozen=True)
class CsvFile:
    properties: list[Property]
    data_paths: list[Path]


@dataclass(frozen=True)
class NodeCsvFile(CsvFile):
    label: str
    id_position: int


@dataclass(frozen=True)
class EdgeCsvFile(CsvFile):
    type: str
    start_id_position: int
    end_id_position: int


def find_nodes_csv_files(export_dir: Path) -> list[NodeCsvFile]:
    header_paths = sorted(export_dir.glob(f"nodes_*_header.csv"))
    
    if not header_paths:
        raise FileNotFoundError(
            f"No hay archivos 'nodes_*_header.csv' en {export_dir}"
        )

    nodes_csv: NodeCsvFile = []

    for header_path in header_paths:
        columns = next(_read_csv(header_path))
        name = header_path.name[len("nodes_"):-len("_header.csv")]
        node_csv = NodeCsvFile(
            properties=_properties(
                columns,
                NODE_FIELDS,
            ),
            data_paths=sorted(export_dir.glob(f"nodes_{name}_data.csv")),
            label=name,
            id_position=columns.index(":ID")
        )
        nodes_csv.append(node_csv)

    return nodes_csv


def find_edges_csv_files(export_dir: Path) -> list[EdgeCsvFile]:
    header_paths = sorted(export_dir.glob(f"edges_*_header.csv"))
    
    if not header_paths:
        raise FileNotFoundError(
            f"No hay archivos 'edges_*_header.csv' en {export_dir}"
        )

    edges_csv: EdgeCsvFile = []

    for header_path in header_paths:
        columns = next(_read_csv(header_path))
        name = header_path.name[len("edges_"):-len("_header.csv")]
        edge_csv = EdgeCsvFile(
            properties=_properties(
                columns,
                EDGE_FIELDS,
            ),
            data_paths=sorted(export_dir.glob(f"edges_{name}_data.csv")),
            type=name,
            start_id_position=columns.index(":START_ID"),
            end_id_position=columns.index(":END_ID")
        )
        edges_csv.append(edge_csv)

    return edges_csv


def _properties(columns: list[str], fields: set[str]) -> list[Property]:
    properties: list[Property] = []
    for position, column in enumerate(columns):
        if column not in fields:
            name, _, neo4jcsv_type = column.partition(":")
            properties.append(
                Property(name, neo4jcsv_type or "string", position)
            )

    return properties


def _read_csv(path: Path) -> Iterator[list[str]]:
    with open(path, newline="", encoding="utf-8") as file:
        yield from csv.reader(file)
