// Query que emula malloc-memcpy-int-overflow CODEQL query https://queries.joern.io/
// Autor: @fabsx00
// CODEQL query:
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
// Obtiene las llamadas a memcpy que le llega flujo desde una llamada a malloc cuyo //
// Emula la query CODEQL de arriba.                                                 //              
//////////////////////////////////////////////////////////////////////////////////////

// (a) Llamadas a malloc que en su argumento tienen operaciones aritmeticas 
MATCH (sourceCall: CALL)
WHERE sourceCall.METHOD_FULL_NAME =~ ".*malloc$"
    AND EXISTS {
        MATCH (sourceCall)-[:AST]->(sourceArg)
            WHERE sourceArg.ARGUMENT_INDEX = 1
                AND sourceArg.NAME IN [
                    "<operator>.addition",
                    "<operator>.subtraction",
                    "<operator>.multiplication",
                    "<operator>.division"
                ]
    }

// (b) Llamada a memcpy donde llegan al primer argumento flujo desde malloc
MATCH (sinkCall: CALL)-[:AST]->(firstSinkArg)
WHERE sinkCall.METHOD_FULL_NAME =~ "(?i)memcpy"
    AND firstSinkArg.ARGUMENT_INDEX = 1
    AND EXISTS {
        MATCH (sourceCall)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(firstSinkArg)
    }
    // El tercer argumento de la llamada a memcpy debe ser distinto al de malloc
    AND NOT EXISTS {
        MATCH (sinkCall)-[:AST]->(thridSinkArg)
        WHERE thridSinkArg.ARGUMENT_INDEX = 3
        
        MATCH (sourceCall)-[:AST]->(sourceArg)
        WHERE sourceArg.ARGUMENT_INDEX = 1
            AND sourceArg.CODE = thridSinkArg.CODE
    }
    // El flujo de malloc que recibe memcpy debe ser desde una asignación  
    AND EXISTS {
        MATCH (assignmentCall)-[:AST*]->(sourceCall)
        WHERE assignmentCall.NAME = "<operator>.assignment"
        
        MATCH (assignmentCall)-[:AST]->(target)
        WHERE target.ARGUMENT_INDEX = 1
            AND target.CODE = firstSinkArg.CODE
    }

RETURN DISTINCT sinkCall;
