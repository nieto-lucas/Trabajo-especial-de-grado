"""Carga relaciones para el análisis interprocedural (IPA)"""
import ladybug as lb

# Propiedades default para crear tablas de nodos necesarias
DEFAULT_PROP = "`id` INT64, PRIMARY KEY(`id`)"

ARGUMENT_NODE_TYPES = ["LITERAL", "IDENTIFIER", "CALL_NODE"]

IPA_NODE_TYPES = ["RETURN"] + ARGUMENT_NODE_TYPES


def load_IPA(conn: lb.Connection) -> None:
    """ Construye relaciones entre los argumentos de las llamadas a funciones
    a sus parametros y el retorno de funciones con las llamadas, para habilitar el 
    analisis intraprocedural
    """
    _load_default_schemas(conn)
    _load_ret_to_call(conn)
    _load_arg_to_param(conn)
    

def _load_default_schemas(conn: lb.Connection) -> None:
    for node_type in IPA_NODE_TYPES:
        conn.execute(f"""
            CREATE NODE TABLE IF NOT EXISTS {node_type} (
                {DEFAULT_PROP}
            )""")


def _load_ret_to_call(conn: lb.Connection) -> None:
    conn.execute("""
        CREATE REL TABLE IF NOT EXISTS RET_TO_CALL(
            FROM RETURN TO CALL_NODE
        )""")

    # Si no hay (:METHOD)-[:CONTAINS]->(:RETURN) no crea nodos
    if not _related_by(conn, 'CONTAINS', 'METHOD', 'RETURN'):
        return
    
    conn.execute("""
        MATCH (call:CALL_NODE)-[:CALL]->(callee:METHOD)-[:CONTAINS]->(ret:RETURN)
        WHERE callee.IS_EXTERNAL = false
        MERGE (ret)-[:RET_TO_CALL]->(call);
    """)


def _load_arg_to_param(conn: lb.Connection) -> None:
    conn.execute("""
        CREATE REL TABLE IF NOT EXISTS ARG_TO_PARAM (
            FROM LITERAL TO METHOD_PARAMETER_IN,
            FROM IDENTIFIER TO METHOD_PARAMETER_IN,
            FROM CALL_NODE TO METHOD_PARAMETER_IN
        )""")
    
    for node_type in ARGUMENT_NODE_TYPES:
        # Si no hay (:CALL_NODE)-[:ARGUMENT]->(:node_type) no crea nodos
        if not _related_by(conn, 'ARGUMENT', 'CALL_NODE', node_type):
            continue
        
        conn.execute(f"""
            MATCH (call:CALL_NODE)-[:CALL]->(callee:METHOD)
            WHERE callee.IS_EXTERNAL = false

            MATCH (call)-[:ARGUMENT]->(arg:{node_type})
            WHERE arg.ARGUMENT_INDEX > 0

            MATCH (callee)-[:AST]->(param:METHOD_PARAMETER_IN)
            WHERE param.`INDEX` = arg.ARGUMENT_INDEX
            MERGE (arg)-[:ARG_TO_PARAM]->(param);
        """)


def _related_by(conn: lb.Connection, rel: str, src: str, dst: str) -> bool:
    relations = conn.execute(f"CALL SHOW_CONNECTION('{rel}') RETURN *")
    while relations.has_next():
        row = relations.get_next()
        if src in row and dst in row:
            return True

    return False
