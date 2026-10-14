from lib.neo4j import Neo4jClient

# Tamaño de batches de queries a procesar
BATCH_SIZE = 200

# Propiedades que conservar en el AST de la sentencia
KEEP_PROPS = ["_type", "CODE", "NAME", "TYPE_FULL_NAME", "ARGUMENT_INDEX", "ORDER"]

# Relaciones que entran o salen del los nodos AST de la sentencia y deben
# preservarse y redirigirse entre ellas
EXTERNAL_RELS = ["CFG", "REACHING_DEF", "CDG", "DOMINATE"]


def compress_cpg(db: Neo4jClient) -> None:
    """
    Post-procesa un CPG con el esquema de Joern para obtener un grafo similar
    al de QVoG, es decir, se comprime la representación original colocando en cada
    nodo CALL su argumentos como un string JSON en la popiedad `ARGS_JSON`,
    reconectando las aristas entrantes y salientes de CALL.

    Args:
        db (Neo4jClient): instancia de una DB Neo4j lista para ser usada

    ## Note
    La función se compone de una serie de pasos atómicos que procesan por batches
    el CPG para obtener el mejor rendimiento posible en proyectos grandes. Sin embargo,
    esto permite que cualquier etapa de compresión pueda fallar y dejar la DB
    en un estado incosistente, en dicho caso se debe volver a cargar el CPG en Neo4j.
    """
    print("Comprimiendo el CPG ...\n")

    try:
        print("Agregando ARGS_JSON a llamadas ...")
        _add_arg_list_calls(db)

        print(
            "Redirigiendo arista salientes en nodos LITERAL \
              o IDENTIFIER afectados ..."
        )
        _redirect_in_rels(db)

        print(
            "Redirigiendo aristas entrantes en nodos LITERAL \
              o IDENTIFIER afectados ..."
        )
        _redirect_out_rels(db)

        print("Eliminando nodos LITERAL o IDENTIFIER internos del ARGS_JSON ...")
        _delete_internals(db)

    except Exception as e:
        print(f"\nERROR durante compresión: {e}")
        print("\nLa base de datos quedo en un estado incosistente")


def _add_arg_list_calls(db: Neo4jClient) -> None:
    # Query para setear una lista de argumentos de llamada a función
    query_set_call_ast = """
        CALL () {
            MATCH (call:CALL)-[:ARGUMENT]->(arg)

            WITH call, arg
            ORDER BY arg.ARGUMENT_INDEX
            
            WITH 
                call,
                collect(
                    apoc.map.fromPairs([
                        key IN $keep_props
                        WHERE arg[key] IS NOT NULL
                        | [key, arg[key]]
                    ])
                ) AS args

            SET call.ARGS_JSON = apoc.convert.toJson(args)

        } IN TRANSACTIONS OF $batch_size ROWS
    """
    db.run(query_set_call_ast, keep_props=KEEP_PROPS, batch_size=BATCH_SIZE)


def _redirect_in_rels(db: Neo4jClient) -> None:
    # Query para redirigir las aristas entrantes al AST de la llamada a función
    query_set_rels_in = """
        CALL () {
            MATCH (call:CALL)-[:ARGUMENT]->(internal)
            WHERE internal:IDENTIFIER OR internal:LITERAL
            
            MATCH (external)-[r]->(internal)
            WHERE type(r) IN $rel_types AND
                call <> external AND
                NOT EXISTS {
                    MATCH (call)-[:ARGUMENT]->(external)
                }

            WITH call, external, type(r) AS relType, properties(r) AS props
            CALL apoc.merge.relationship(
                external, relType, props, props, call, {}
            )
            YIELD rel

            FINISH
        } IN TRANSACTIONS OF $batch_size ROWS
    """
    db.run(query_set_rels_in, rel_types=EXTERNAL_RELS, batch_size=BATCH_SIZE)


def _redirect_out_rels(db: Neo4jClient) -> None:
    # Query para redirigir las aristas salientes del AST de la llamada a función
    query_set_rels_out = """
        CALL () {
            MATCH (call:CALL)-[:ARGUMENT]->(internal)
            WHERE internal:IDENTIFIER OR internal:LITERAL

            MATCH (internal)-[r]->(external)
            WHERE type(r) IN $rel_types AND
                call <> external AND
                NOT EXISTS {
                    MATCH (call)-[:ARGUMENT]->(external)
                }
        
            WITH call, external, type(r) AS relType, properties(r) AS props
            CALL apoc.merge.relationship(
                call, relType, props, props, external, {}
            )
            YIELD rel

            FINISH
        } IN TRANSACTIONS OF $batch_size ROWS
    """
    db.run(query_set_rels_out, rel_types=EXTERNAL_RELS, batch_size=BATCH_SIZE)


def _delete_internals(db: Neo4jClient) -> None:
    # Query para eliminar los nodos del AST de la llamada a función
    query_delete_internals = """
        CALL () {
            MATCH (call:CALL)-[:ARGUMENT]->(n)
            WHERE n:IDENTIFIER OR n:LITERAL  
            DETACH DELETE n
        } IN TRANSACTIONS OF $batch_size ROWS
    """
    db.run(query_delete_internals, batch_size=BATCH_SIZE)
