// Query que emula strncpy-no-null-term CPGQL query https://queries.joern.io/
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

MATCH (c)-[:AST]->(arg)
WHERE arg.ARGUMENT_INDEX > 0

MATCH (callee)-[:AST]->(p:METHOD_PARAMETER_IN)
WHERE p.INDEX = arg.ARGUMENT_INDEX
MERGE (arg)-[:ARG_TO_PARAM]->(p);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene los punteros destino en los que se compia strings con strncpy dejando    //
// lugar para el caracter de términación. Emula la CPGQL de arriba                  //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Llamadas a malloc y strncpy
MATCH (sourceCall:CALL)
WHERE sourceCall.METHOD_FULL_NAME =~ ".*malloc$"

MATCH (sourceCall)-[:AST]->(sourceArg)
WHERE sourceArg.ARGUMENT_INDEX = 1

MATCH (sinkCall:CALL)
WHERE sinkCall.METHOD_FULL_NAME =~ "(?i)strncpy"

// (b) Otenemos method, dst, size
MATCH (method:METHOD)-[:CONTAINS]->(sinkCall)

MATCH (sinkCall)-[:AST]->(firstSinkArg)
WHERE firstSinkArg.ARGUMENT_INDEX = 1

MATCH (sinkCall)-[:AST]->(thridSinkArg)
WHERE thridSinkArg.ARGUMENT_INDEX = 3

WITH sourceArg, method, firstSinkArg AS dst, thridSinkArg AS size

// (c) El tamaño reservado al string que se copia es el mismo que lo copiado y no 
// se agregan caracteres de términcación en la copia
WHERE EXISTS {
        MATCH (sourceArg)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(dst)
        WHERE sourceArg.CODE = size.CODE
    }
    // NINGUNA asignación dentro de la función donde se llama a strncpy es de
    // la forma: dst[some_size] = '\0'  
    AND NOT EXISTS {
        MATCH (method)-[:CONTAINS]->(methodAssignment)
        WHERE methodAssignment.NAME = "<operator>.assignment"
        
        MATCH (methodAssignment)-[:AST]->(target)
        WHERE target.ARGUMENT_INDEX = 1
            AND target.NAME = "<operator>.indirectIndexAccess"
            AND target.CODE =~ (dst.CODE + ".*\\[.*")
    
        MATCH (methodAssignment)-[:AST]->(source:LITERAL)
        WHERE source.ARGUMENT_INDEX = 2
            AND source.CODE =~ ".*0.*"
    }

RETURN DISTINCT dst;
