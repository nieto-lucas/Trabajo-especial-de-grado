//////////////////////////////////////////////////////////////////////////////////////
// Permite hacer inlining de funciones y sus valores de retorno (llamarse una vez). //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (c:CALL)-[:CALL]->(callee:METHOD)-[:CONTAINS]->(r:RETURN)
WHERE callee.IS_EXTERNAL = false
MERGE (r)-[:RET_TO_CALL]->(c);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene funciones identidad.                                                     //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (m:METHOD)-[:AST]->(p:METHOD_PARAMETER_IN)
WHERE m.IS_EXTERNAL = false
    AND EXISTS { MATCH (m)-[:CONTAINS]->(:RETURN) }

    // (a) TODO return de m recibe flujo de p
    AND NOT EXISTS {
        MATCH (m)-[:CONTAINS]->(r:RETURN)
        WHERE NOT EXISTS { MATCH (p)-[:REACHING_DEF|RET_TO_CALL*]->(r) }
    }

    // (b) NINGUN return recibe flujo de un nodo que no preserve el valor
    AND NOT EXISTS {
        MATCH (m)-[:CONTAINS]->(r:RETURN)
        MATCH (bad)-[:REACHING_DEF|RET_TO_CALL*]->(r)
        WHERE NOT (
            bad:IDENTIFIER                              // renombres / usos
            OR bad:METHOD_PARAMETER_IN                  // el parametro (propio o del callee)
            OR bad:RETURN                               // return de un callee inlineado
            OR bad:METHOD                               // ruido del nodo de entrada
            OR EXISTS { 
                MATCH (bad)-[:CALL]->(q:METHOD)
                WHERE q.IS_EXTERNAL = false 
            }                                           // llamada inlineable
        )
    }

RETURN DISTINCT m.NAME AS fn, p.NAME AS param
ORDER BY fn;
