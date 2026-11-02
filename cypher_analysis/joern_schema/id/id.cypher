//////////////////////////////////////////////////////////////////////////////////////
// Obtiene funciones identidad.                                                     //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (method:METHOD)-[:AST]->(param:METHOD_PARAMETER_IN)
WHERE
  method.IS_EXTERNAL = false AND
  EXISTS {
    MATCH (method)-[:CONTAINS]->(:RETURN)
  }
  // (a) TODO return de method recibe flujo de param
  AND
  NOT EXISTS {
    MATCH (method)-[:CONTAINS]->(ret:RETURN)
    WHERE
      NOT EXISTS {
        MATCH (param)-[:REACHING_DEF|RET_TO_CALL* SHORTEST]->(ret)
      }
  }
  // (b) NINGUN return recibe flujo de un nodo que no preserve el valor
  AND
  NOT EXISTS {
    MATCH (method)-[:CONTAINS]->(ret:RETURN),
          (bad)-[:REACHING_DEF|RET_TO_CALL* SHORTEST]->(ret)
    WHERE
      NOT label(bad) IN [
        "IDENTIFIER",           // renombres / usos
        "METHOD_PARAMETER_IN",  // el parametro (propio o del callee)
        "RETURN",               // return de un callee inlineado
        "METHOD"                // ruido del nodo de entrada
      ] OR                      // llamada inlineable
        EXISTS {
          MATCH (bad)-[:CALL]->(q:METHOD)
          WHERE q.IS_EXTERNAL = false
        }
  }

RETURN DISTINCT method.NAME AS fn, param.NAME AS param
ORDER BY fn;