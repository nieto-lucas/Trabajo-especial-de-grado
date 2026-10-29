import ladybug as lb

from query import QueryResult
from test_cases import TestCase


def exec_cypher_query(conn: lb.Connection, test: TestCase) -> QueryResult:
    """Ejecuta la query de cypher guardada en test
    
    Args:
        conn (lb.Connection): conexión a una db LadyBugDB 
        test (TestCase): test que se quiere verificar, contiene query para Cypher

    Return:
        ids de nodos como resultados de query, listos para comparar con otros QueryResult 
    """
    result = conn.execute(test.cypher)
    if isinstance(result, list):
        raise ValueError(f"[{test.name}] la query deber ser una sola sentencia")

    positions = _node_columns(result, test.name)
    raw_ids = []
    while result.has_next():
        row = result.get_next()
        for position in positions:
            node = row[position]
            if node is None:
                continue
            
            if "id" not in node:
                raise ValueError(
                    f"[{test.name}] un nodo devuelto no tiene la propiedad 'id'"
                )
            
            raw_ids.append(node["id"])

    return QueryResult.from_raw_ids(raw_ids)


def _node_columns(result: lb.QueryResult, test_name: str) -> list[int]:
    result_types: list[str] = result.get_column_data_types()
    
    positions = [
        position
        for position, column_type in enumerate(result_types)
        if column_type == lb.Type.NODE.value
    ]

    if not positions:
        raise ValueError(
            f'[{test_name}] la query cypher no devolvio ningún nodo '
            f'debería haber un RETURN sobre uno o más varibles bindeades a nodos'
        )
    
    return positions
