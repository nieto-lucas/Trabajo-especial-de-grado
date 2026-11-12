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
MATCH (srcCall:CALL_NODE)-[:ARGUMENT]->(srcArg:CALL_NODE)
WHERE
  srcCall.METHOD_FULL_NAME =~ ".*malloc$" AND
  srcArg.ARGUMENT_INDEX = 1 AND
  is_arithmetic(srcArg)

// (b) Llamada a memcpy donde llegan al primer argumento flujo desde malloc
MATCH (sinkCall:CALL_NODE)-[:ARGUMENT]->(firstSinkArg {ARGUMENT_INDEX: 1})
WHERE
  sinkCall.METHOD_FULL_NAME =~ "(?i)memcpy" AND
  reachable_by(srcCall, firstSinkArg) AND
  // El tercer argumento de la llamada a memcpy debe ser distinto al de malloc
  NOT EXISTS {
    MATCH (sinkCall)-[:ARGUMENT]->(thridSinkArg {ARGUMENT_INDEX: 3}),
          (srcCall)-[:ARGUMENT]->(srcArg)
    WHERE srcArg.CODE = thridSinkArg.CODE
  }
  // El flujo de malloc que recibe memcpy debe ser desde una asignación
  AND
  EXISTS {
    MATCH (assign:CALL_NODE)-[:AST* SHORTEST]->(srcCall),
          (assign)-[:AST]->(target {ARGUMENT_INDEX: 1})
    WHERE
      assign.NAME = "<operator>.assignment" AND
      target.CODE = firstSinkArg.CODE
  }

RETURN DISTINCT sinkCall;