// Query strncpy-no-null-term CPGQL query https://queries.joern.io/
// Autor: @fabsx00
// CPGQL query:
// ({
//      val allocations = cpg.method(".*malloc$").callIn.argument(1).l
//      cpg
//          .method("(?i)strncpy")
//          .callIn
//          .map { c =>
//              (c.method, c.argument(1), c.argument(3))
//          }
//          .filter { case (method, dst, size) =>
//              dst.reachableBy(allocations).codeExact(size.code).nonEmpty &&
//              method.assignment
//                  .where(_.target.arrayAccess.code(s"${dst.code}.*\\[.*"))
//                  .source
//                  .isLiteral
//                  .code(".*0.*")
//                  .isEmpty
//          }
//          .map(_._2)
// }).l
// 

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene los punteros destino en los que se compia strings con strncpy dejando    //
// lugar para el caracter de términación. Emula la query CPGQL de arriba            //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene llamadas a malloc y strncpy
MATCH (srcCall:CALL_NODE)-[:ARGUMENT]->(srcArg)
WHERE srcCall.METHOD_FULL_NAME =~ ".*malloc$"
    AND srcArg.ARGUMENT_INDEX = 1

MATCH (method:METHOD)-[:CONTAINS]->(sinkCall:CALL_NODE)
WHERE sinkCall.METHOD_FULL_NAME =~ "(?i)strncpy"

// (b) Otenemos method, dst, size
MATCH (sinkCall)-[:ARGUMENT]->(dstArg)
WHERE dstArg.ARGUMENT_INDEX = 1

MATCH (sinkCall)-[:ARGUMENT]->(sizeArg)
WHERE sizeArg.ARGUMENT_INDEX = 3

WITH method, dstArg, sizeArg

// (c) El tamaño reservado al string que se copia es el mismo que lo copiado y no 
// se agregan caracteres de términcación en la copia
WHERE EXISTS {
    MATCH (srcArg)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM* SHORTEST]->(dstArg)
    WHERE srcArg.CODE = sizeArg.CODE
}
// NINGUNA asignación dentro de la función donde se llama a strncpy es de
// la forma: dst[some_size] = '\0'
AND NOT EXISTS {
    MATCH (method)-[:CONTAINS]->(assign:CALL_NODE),
          (assign)-[:AST]->(target:CALL_NODE),
          (assign)-[:AST]->(src:LITERAL)
    WHERE
        assign.NAME = "<operator>.assignment"
        AND target.ARGUMENT_INDEX = 1
        AND target.NAME = "<operator>.indirectIndexAccess"
        AND target.CODE =~ (dstArg.CODE + ".*\\[.*")
        AND src.ARGUMENT_INDEX = 2
        AND src.CODE =~ ".*0.*"
}

RETURN DISTINCT dstArg;
