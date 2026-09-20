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
// Permite hacer inlining de funciones y sus valores de retorno (llamarse una vez). //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (c:CALL)-[:CALL]->(callee:METHOD)-[:CONTAINS]->(r:RETURN)
WHERE callee.IS_EXTERNAL = false
MERGE (r)-[:RET_TO_CALL]->(c);

//////////////////////////////////////////////////////////////////////////////////////
// Comunica argumentos con parametros de funciones (llamarse una vez).              //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (c:CALL)-[:CALL]->(callee:METHOD)
WHERE callee.IS_EXTERNAL = false

MATCH (c)-[:ARGUMENT]->(arg)
WHERE arg.ARGUMENT_INDEX > 0

MATCH (callee)-[:AST]->(p:METHOD_PARAMETER_IN)
WHERE p.INDEX = arg.ARGUMENT_INDEX
MERGE (arg)-[:ARG_TO_PARAM]->(p);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene los punteros destino en los que se compia strings con strncpy dejando    //
// lugar para el caracter de términación. Emula la query CPGQL de arriba            //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene llamadas a malloc y strncpy
MATCH (sourceCall:CALL)-[:ARGUMENT]->(sourceArg)
WHERE sourceCall.METHOD_FULL_NAME =~ ".*malloc$"
    AND sourceArg.ARGUMENT_INDEX = 1

MATCH (method:METHOD)-[:CONTAINS]->(sinkCall:CALL)
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
        MATCH (sourceArg)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(dstArg)
        WHERE sourceArg.CODE = sizeArg.CODE
    }
    // NINGUNA asignación dentro de la función donde se llama a strncpy es de
    // la forma: dst[some_size] = '\0'
    AND NOT EXISTS {
        MATCH (method)-[:CONTAINS]->(methodAssignment:CALL)
        WHERE methodAssignment.NAME = "<operator>.assignment"
    
        MATCH (methodAssignment)-[:AST]->(target:CALL)
        WHERE target.ARGUMENT_INDEX = 1
            AND target.NAME = "<operator>.indirectIndexAccess"
            AND target.CODE =~ (dstArg.CODE + ".*\\[.*")
    
        MATCH (methodAssignment)-[:AST]->(source:LITERAL)
        WHERE source.ARGUMENT_INDEX = 2
            AND source.CODE =~ ".*0.*"
    }

RETURN DISTINCT dstArg;
