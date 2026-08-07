// Query para emular get-env-to-strcpy CODEQL query https://queries.joern.io/
// Autor: @ursachec
// ({
//      def source = cpg.call.methodFullName("getenv")
//      def sink = cpg.method.fullName("strcpy").parameter.index(2)
//      sink.reachableBy(source).l
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
WHERE callee.is_EXTERNAL = false

MATCH (c)-[:AST]->(arg)
WHERE arg.ARGUMENT_INDEX > 0

MATCH (callee)-[:AST]->(p:METHOD_PARAMETER_IN)
WHERE p.INDEX = arg.ARGUMENT_INDEX
MERGE (arg)-[:ARG_TO_PARAM]->(p);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene las llamadas a getenv cuyo valor alcanza al segundo argumento de una     // 
// llamada a strcpy.                                                                //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (sourceCall: CALL)
WHERE sourceCall.METHOD_FULL_NAME = "getenv"

MATCH (sinkCall: CALL)-[:AST]->(sinkArg)
WHERE sinkCall.METHOD_FULL_NAME = "strcpy"
    AND sinkArg.ARGUMENT_INDEX = 2
    AND EXISTS {
        MATCH (sourceCall)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(sinkArg)
    }
RETURN DISTINCT sourceCall;
