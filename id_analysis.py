import argparse
from neo4j import Session, Driver, GraphDatabase

# Primero se obtiene el parametro de entrada y expresión de retorno
#
# MATCH (m:METHOD)-[:AST]->(param:METHOD_PARAMETER_IN)
# MATCH (m)-[:AST*]->(:RETURN)-[:AST]->(retExpr)
#
# Primer CALL: verifica que todo camino entre el parametro y la expresión
# de retorno no haya una asignación compuesta que involucre al parametro y si se 
# llama a alguna función debe ser del conjunto de funciones identidad. Tampoco deben 
# llamarse de forma compuesta, pero si pueden ser anidadas. Por ej. f(x) + 1 NO,
# f(f(x)), f(f(f(x))), ... SI
#
# Segundo CALL: obtiene la cantidad de caminos a la expresion de retorno cuya 
# definición no esta influida por el parametro. Si la función es identidad la
# cantidad debería ser 0. (Necesario porque el primer CALL deja pasar funciones
# donde hay varios caminos y la variable que se retorna es redefinida con una expresión 
# simple. Por ej. int s(int x) { if (cond) x = 42 else x = x; return x; } en la 
# sentencia x = 42 no participa el x del parametro y por lo tanto el primer CALL no
# considera el camino donde el condicional es true)
#
# (No detecta programas donde el parametro se reasigne o retorne en composición con 
# algún operador que no lo modifique. Por ej. no detecta int w(int x) { return x + 0 })
#
_IDENTITY_QUERY = """
MATCH (m:METHOD)-[:AST]->(param:METHOD_PARAMETER_IN)
MATCH (m)-[:AST*]->(:RETURN)-[:AST]->(retExpr)

WITH m, param, retExpr, $identitySet AS identitySet
CALL (param, retExpr, identitySet) {
    MATCH path = (param)-[:REACHING_DEF*1..]->(retExpr)
    WITH identitySet, collect(path) AS paths
    WITH paths,
        ALL(p IN paths WHERE
            ALL(n IN nodes(p) WHERE
                n:METHOD_PARAMETER_IN
                OR n:IDENTIFIER
                OR (
                    n:CALL
                    AND n.NAME = "<operator>.assignment"
                    AND EXISTS {
                        (n)-[:AST]->(rightSideAssign)
                        WHERE rightSideAssign.ARGUMENT_INDEX = 2
                            AND rightSideAssign:IDENTIFIER
                    }
                )
                OR (
                    n:CALL
                    AND n.METHOD_FULL_NAME IN identitySet
                    AND COUNT { 
                        (n)-[:AST]->(functionArgument) 
                        WHERE functionArgument.ARGUMENT_INDEX = 1 
                    } = 1
                )
            )
        ) AS allClean
    RETURN size(paths) > 0 AND allClean AS cleanPath
}

CALL (param, retExpr, cleanPath) {
    MATCH (otherDef)-[:REACHING_DEF]->(retExpr)
    WHERE otherDef <> param
        AND NOT otherDef:METHOD
        AND NOT EXISTS {
            path = (param)-[:REACHING_DEF*1..]->(otherDef)
        }
    RETURN count(otherDef) AS otherDefinitions
}

WITH m, cleanPath, otherDefinitions
WHERE cleanPath AND otherDefinitions = 0

RETURN DISTINCT m.FULL_NAME AS identityMethod;
"""

def _run_identity_query(session: Session, identity_set: set[str]) -> set[str]:
    result = session.run(_IDENTITY_QUERY, identitySet=list(identity_set))
    return {record["identityMethod"] for record in result}

def compute_identity_fixpoint(driver: Driver, max_iters: int = 100) -> list[str]:
    """
    Función para reconocer funciones identidad con diferentes niveles de indirección
    Por ejemplo: una función int f(x){ return x; } es identidad y pero int g(x) { return f(x); } 
    lo es ?. En ese caso g depende de f, entonces primero hay que saber que f es identidad para 
    determinar que g lo es. Asimismo con funciones que dependan de g y así sucesivamente.

    Args:
        - driver (Driver): Driver para establecer una conexion con una instancia de Neo4j
        - max_iters (int): Cantidad máxima de iteraciones de punto fijo (modificar a conveniencia)
    
    Returns:
        Diccionario con nombre de funciones identificadas cómo identidad
    """
    indentity_set: set[str] = set()

    with driver.session() as session:
        for _ in range(max_iters):
            new_set = _run_identity_query(session, indentity_set)
            # Cuando no se incorpora una nueva función identidad termina
            if new_set == indentity_set:
                break
            indentity_set = new_set

    return sorted(list(indentity_set))

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--neo4j-uri", default="bolt://localhost:7687")
    ap.add_argument("--neo4j-user", default="neo4j")
    ap.add_argument("--neo4j-password", required=True)
    args = ap.parse_args()

    print("\n==> Corriendo analisis de función identidad ...")
    driver = GraphDatabase.driver(args.neo4j_uri, auth=(args.neo4j_user, args.neo4j_password))
    try:
        identities = compute_identity_fixpoint(driver)
    finally:
        driver.close()

    print("\n==> Funciones identidad encontradas ...")
    for identity in identities:
        print(f"    {identity}")

if __name__ == "__main__":
    main()
