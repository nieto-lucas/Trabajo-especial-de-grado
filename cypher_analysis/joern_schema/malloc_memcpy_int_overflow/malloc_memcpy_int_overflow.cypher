// Query malloc-memcpy-int-overflow CPGQL query https://queries.joern.io/
// Autor: @fabsx00
// CPGQL query:
// ({
//      val src =
//      cpg.method(".*malloc$").callIn.where(_.argument(1).arithmetic).l
//
//      cpg.method("(?i)memcpy").callIn.l.filter { memcpyCall =>
//      memcpyCall
//          .argument(1)
//          .reachableBy(src)
//          .where(_.inAssignment.target.codeExact(memcpyCall.argument(1).code))
//          .whereNot(_.argument(1).codeExact(memcpyCall.argument(3).code))
//          .hasNext
//      }
// }).l

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene las llamadas a memcpy que le llega flujo desde una llamada a malloc      //
// Emula la query CPGQL de arriba.                                                  //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Llamadas a malloc que en su argumento tienen operaciones aritmeticas
MATCH (sourceCall:CALL_NODE)-[:ARGUMENT]->(sourceArg:CALL_NODE)
WHERE
  sourceCall.METHOD_FULL_NAME =~ ".*malloc$" AND
  sourceArg.ARGUMENT_INDEX = 1 AND
  sourceArg.NAME IN [
    "<operator>.addition",
    "<operator>.subtraction",
    "<operator>.multiplication",
    "<operator>.division"
  ]

// (b) Llamada a memcpy donde llegan al primer argumento flujo desde malloc
MATCH (sinkCall:CALL_NODE)-[:ARGUMENT]->(firstSinkArg)
WHERE
  sinkCall.METHOD_FULL_NAME =~ "(?i)memcpy" AND
  firstSinkArg.ARGUMENT_INDEX = 1 AND
  EXISTS {
    MATCH (sourceCall)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(firstSinkArg)
  }
  // El tercer argumento de la llamada a memcpy debe ser distinto al de malloc
  AND
  NOT EXISTS {
    MATCH (sinkCall)-[:ARGUMENT]->(thridSinkArg),
          (sourceCall)-[:ARGUMENT]->(sourceArg)
    WHERE 
      thridSinkArg.ARGUMENT_INDEX = 3 AND
      sourceArg.ARGUMENT_INDEX = 1 AND 
      sourceArg.CODE = thridSinkArg.CODE
  }
  // El flujo de malloc que recibe memcpy debe ser desde una asignación
  AND
  EXISTS {
    MATCH (assignmentCall)-[:AST*]->(sourceCall),
          (assignmentCall)-[:AST]->(target)
    WHERE 
      assignmentCall.NAME = "<operator>.assignment" AND
      target.ARGUMENT_INDEX = 1 AND 
      target.CODE = firstSinkArg.CODE
  }

RETURN DISTINCT sinkCall;