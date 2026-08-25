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
//

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene llamadas a free donde se liberan valores que son reusados sin            //
// reasignación en todos los caminos. Emula la query CPGQL de arriba.               //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene el ćodigo de las llamadas a funciones free
MATCH (sourceCall:CALL)-[:ARGUMENT]->(freedIdentifier:IDENTIFIER)
WHERE sourceCall.METHOD_FULL_NAME =~ "(.*_)?free"
    AND freedIdentifier.ARGUMENT_INDEX = 1
WITH sourceCall, freedIdentifier.CODE AS freedIdentifierCode

// (b) Obtiene los nodos que post-dominan free (usan el valor liberado)
MATCH (postDomNode)-[:POST_DOMINATE*]->(sourceCall)
WITH sourceCall, freedIdentifierCode, collect(DISTINCT postDomNode) AS postDom

// (c) Obtiene las variables liberadas que aparecen como reasignaciones en arbol 
// de post-dominancia
WITH sourceCall, freedIdentifierCode, postDom,
    COLLECT {
        UNWIND postDom AS pdNode
        MATCH (assignCall:CALL)-[:AST]->(pdNode:IDENTIFIER)
        WHERE assignCall.NAME = "<operator>.assignment"
            AND pdNode.ARGUMENT_INDEX = 1 
            AND pdNode.CODE = freedIdentifierCode
        RETURN DISTINCT pdNode
    } AS reassignedIds

WITH sourceCall, freedIdentifierCode, postDom, reassignedIds,
    reassignedIds + COLLECT {
        UNWIND reassignedIds AS rId
        MATCH (rPdNode)-[:POST_DOMINATE*]->(rId)
        RETURN DISTINCT rPdNode
    } AS assignedPosDom

// (d) Se queda solo con las llamadas a free con valores que no se reasignan
UNWIND postDom AS candidate
WITH sourceCall, freedIdentifierCode, assignedPosDom, candidate
WHERE "IDENTIFIER" IN labels(candidate)
    AND candidate.CODE = freedIdentifierCode
    AND NOT candidate IN assignedPosDom

RETURN DISTINCT sourceCall;
