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
    MATCH (method)-[:CONTAINS]->(ret:RETURN)
    MATCH (bad)-[:REACHING_DEF|RET_TO_CALL*]->(ret)
    WHERE
      NOT (bad:IDENTIFIER OR        // renombres / usos
        bad:METHOD_PARAMETER_IN OR  // el parametro (propio o del callee)
        bad:RETURN OR               // return de un callee inlineado
        bad:METHOD OR               // ruido del nodo de entrada
        EXISTS {
          MATCH (bad)-[:CALL]->(q:METHOD)
          WHERE q.IS_EXTERNAL = false
        })                          // llamada inlineable
  }

RETURN DISTINCT method.NAME AS fn, param.NAME AS param
ORDER BY fn;