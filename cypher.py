from neo4j import Session, Record
from neo4j.graph import Node

from query import QueryResult
from test_cases import TestCase

def _extract_nodes(row: Record, test_name: str) -> list[Node]:
    nodes = [value for value in row.values() if isinstance(value, Node)]

    if not nodes:
        raise ValueError(
            f'[{test_name}] la query cypher no devolvio ningún nodo '
            f'debería haber un RETURN sobre uno o más varibles bindeades a nodos'
        )
    return nodes

def exec_cypher_query(session: Session, test: TestCase) -> QueryResult:
    """Ejecuta la query de cypher guardada en test
    
    Args:
        session (Session): sesion de una conexión en Neo4j 
        test (TestCase): test que se quiere verificar, contiene query para Cypher

    Return:
        ids de nodos como resultados de query, listos para comparar con otros QueryResult 
    """
    rows = session.run(test.cypher)
    raw_ids = []
    for row in rows:
        for node in _extract_nodes(row, test.name):
            if "id" not in node:
                raise ValueError(f"[{test.name}] un nodo devuelto no tiene la propiedad 'id'")
            raw_ids.append(node["id"])

    return QueryResult.from_raw_ids(raw_ids)
