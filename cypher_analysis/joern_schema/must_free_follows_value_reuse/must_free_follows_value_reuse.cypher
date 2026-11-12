// Query free-follows-value-reuse CPGQL Query https://queries.joern.io/
// Autor: @maltek
// CPGQL query:
// ({
//      cpg.method
//          .name("(.*_)?free")
//          .filter(_.parameter.size == 1)
//          .callIn
//          .where(_.argument(1).isIdentifier)
//          .flatMap { f =>
//              val freedIdentifierCode = f.argument(1).code
//              val postDom = f.postDominatedBy.toSetImmutable
//
//              val assignedPostDom = postDom.isIdentifier
//                  .where(_.inAssignment)
//                  .codeExact(freedIdentifierCode)
//                  .flatMap(id => Iterator.single(id) ++ id.postDominatedBy)
//
//              postDom
//                  .removedAll(assignedPostDom)
//                  .isIdentifier
//                  .codeExact(freedIdentifierCode)
//          }
// }).l

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene llamadas a free donde se liberan valores que son reusados sin            //
// reasignación en todos los caminos. Emula la query CPGQL de arriba.               //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene el ćodigo de las llamadas a funciones free
MATCH (freeCall:CALL_NODE)-[:ARGUMENT]->(freed:IDENTIFIER)
WHERE 
  freeCall.METHOD_FULL_NAME =~ "(.*_)?free" AND
  freed.ARGUMENT_INDEX = 1

MATCH (use:IDENTIFIER)-[:POST_DOMINATE* SHORTEST]->(freeCall)
WHERE 
  use.CODE = freed.CODE AND
  NOT EXISTS {
    MATCH (assign1:CALL_NODE)-[:AST]->(use)
    WHERE 
      assign1.NAME = "<operator>.assignment" AND
      use.ARGUMENT_INDEX = 1
  }
  AND
  NOT EXISTS {
    MATCH (assign2:CALL_NODE)-[:AST]->(reuse:IDENTIFIER),
          (reuse)-[:POST_DOMINATE* SHORTEST]->(freeCall),
          (use)-[:POST_DOMINATE* SHORTEST]->(reuse)
    WHERE
      assign2.NAME = "<operator>.assignment" AND
      reuse.ARGUMENT_INDEX = 1 AND
      reuse.CODE = freed.CODE
  }

RETURN DISTINCT freeCall;