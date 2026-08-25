// Query free-field-no-reassign CPGQL query https://queries.joern.io/
// Autor: @fabsx00
// CPGQL query:
// ({
//      val freeOfStructField = cpg
//          .method("free")
//          .callIn
//          .where(
//              _.argument(1)
//              .isCallTo("<operator>.*[fF]ieldAccess.*")
//              .filter(x => x.method.parameter.name.toSet.contains(x.argument(1).code))
//          )
//          .whereNot(_.argument(1).isCall.argument(1).filter { struct =>
//              struct.method.ast.isCall
//              .name(".*free$", "memset", "bzero")
//              .argument(1)
//              .codeExact(struct.code)
//              .nonEmpty
//      }).l
//
//      freeOfStructField.argument(1).filter { arg =>
//          arg.method.methodReturn.reachableBy(arg).nonEmpty
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

MATCH (c)-[:ARGUMENT]->(arg)
WHERE arg.ARGUMENT_INDEX > 0

MATCH (callee)-[:AST]->(p:METHOD_PARAMETER_IN)
WHERE p.INDEX = arg.ARGUMENT_INDEX
MERGE (arg)-[:ARG_TO_PARAM]->(p);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene el campo de un puntero a un struct que es liberado con un free, pero no  //
// se reasigna el todos los caminos de la función donde es llamada. Emula la query  //
// CPGQL de arriba.                                                                 // 
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene llamadas a free en funciones que liberan campos de structs no el 
// struct entero
MATCH (freeOfStructField:CALL)-[:ARGUMENT]->(fieldAccess:CALL)
WHERE freeOfStructField.METHOD_FULL_NAME = "free"
    AND fieldAccess.ARGUMENT_INDEX = 1
    AND fieldAccess.NAME =~ "<operator>.*[fF]ieldAccess.*"

MATCH (fieldAccess)-[:AST]->(struct)
    WHERE struct.ARGUMENT_INDEX = 1
        // La llamada a free de la forma free(p->a_field) debe tener el struct p como
        // parametro de la función que contiene la llamada
        AND EXISTS {
            MATCH (method:METHOD)-[:CONTAINS]->(sourceArg)

            MATCH (method)-[:AST]->(param:METHOD_PARAMETER_IN)
            WHERE param.NAME = struct.CODE
        }
        // En la función que llama a free(p->a_field) no ocurre NINGUNA llamada a una 
        // función que libere o setee en 0 todos los campos de un struct p. Por ej. 
        // no ocurre free(p)), memset(p, ...) y/o bzero(p, ...)
        AND NOT EXISTS {
            MATCH (method:METHOD)-[:CONTAINS]->(struct)

            MATCH (method)-[:AST*]->(call:CALL)
            WHERE call.NAME IN [".*free$", "memset", "bzero"]

            MATCH (call)-[:ARGUMENT]->(firstArg)
            WHERE firstArg.ARGUMENT_INDEX = 1
                AND firstArg.CODE = struct.CODE
        }

// (b) Obtiene el campo del struct liberado si hay un camino donde no se redefine  
WITH fieldAccess
WHERE EXISTS {
    MATCH (method:METHOD)-[:CONTAINS]->(fieldAccess)

    MATCH (method)-[:AST]->(methodReturn:METHOD_RETURN)
    WHERE EXISTS {
        MATCH (fieldAccess)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(methodReturn)
    }
}

RETURN DISTINCT fieldAccess;
