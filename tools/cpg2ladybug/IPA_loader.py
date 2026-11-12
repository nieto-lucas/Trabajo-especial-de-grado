"""Carga relaciones para el análisis interprocedural (IPA)"""
import ladybug as lb

# Propiedades default para crear tablas de nodos necesarias
DEFAULT_PROP = "`id` INT64, PRIMARY KEY(`id`)"

ARGUMENT_NODE_TYPES = ["LITERAL", "IDENTIFIER", "CALL_NODE"]


def load_IPA(conn: lb.Connection) -> None:
    """ Construye relaciones entre los argumentos de las llamadas a funciones
    a sus parametros y el retorno de funciones con las llamadas, para habilitar el 
    analisis intraprocedural
    """
    _load_default_schemas(conn)
    _load_ret_to_call(conn)
    _load_arg_to_param(conn)


def _load_default_schemas(conn: lb.Connection) -> None:
    _create_node_table(conn, "RETURN")
    for node_type in ARGUMENT_NODE_TYPES:
        props = ["ARGUMENT_INDEX INT32"]
        if node_type == "CALL_NODE":
            props.append("IS_EXTERNAL BOOL")

        _create_node_table(conn, node_type, props)


def _create_node_table(conn, name: str, props: list[str] = []) -> None:
    cols = ", ".join(["`id` INT64", *props, "PRIMARY KEY(`id`)"])
    conn.execute(f"CREATE NODE TABLE IF NOT EXISTS {name} ({cols})")


def _load_ret_to_call(conn: lb.Connection) -> None:
    conn.execute("""
        CREATE REL TABLE IF NOT EXISTS RET_TO_CALL(
            FROM RETURN TO CALL_NODE
        )""")

    match = """
        MATCH (call:CALL_NODE)-[:CALL]->(callee:METHOD)-[:CONTAINS]->(ret:RETURN)
        WHERE callee.IS_EXTERNAL = false
    """
    # Si no hay match en la query de arriba, no crea nodos
    if _has_matches(conn, match):
        conn.execute(match + "MERGE (ret)-[:RET_TO_CALL]->(call);")


def _load_arg_to_param(conn: lb.Connection) -> None:
    conn.execute("""
        CREATE REL TABLE IF NOT EXISTS ARG_TO_PARAM (
            FROM LITERAL TO METHOD_PARAMETER_IN,
            FROM IDENTIFIER TO METHOD_PARAMETER_IN,
            FROM CALL_NODE TO METHOD_PARAMETER_IN
        )""")
    
    for node_type in ARGUMENT_NODE_TYPES:
        match = f"""
            MATCH (call:CALL_NODE)-[:CALL]->(callee:METHOD)
            WHERE callee.IS_EXTERNAL = false

            MATCH (call)-[:ARGUMENT]->(arg:{node_type})
            WHERE arg.ARGUMENT_INDEX > 0

            MATCH (callee)-[:AST]->(param:METHOD_PARAMETER_IN)
            WHERE param.`INDEX` = arg.ARGUMENT_INDEX
        """
        # Si no hay match en la query de arriba, no crea nodos
        if _has_matches(conn, match):
            conn.execute(match + "MERGE (arg)-[:ARG_TO_PARAM]->(param);")


def _has_matches(conn: lb.Connection, subquery: str) -> bool:
    result = conn.execute(f"{subquery} RETURN count(*) AS matches")
    return result.get_next()[0] > 0
