// Query inspirada en get-env-to-strcpy CPGQL query https://queries.joern.io/
// CPGQL query:
// ({
//      def source = cpg.call.methodFullName("getenv")
//      def sink = cpg.call.methodFullName("strcpy").argument(2)
//      sink.reachableBy(source).l
// }).l

//////////////////////////////////////////////////////////////////////////////////////
// Permite hacer inlining de funciones y sus valores de retorno (llamarse una vez). //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (call:CALL)-[:CALL]->(callee:METHOD)-[:CONTAINS]->(ret:RETURN)
WHERE callee.IS_EXTERNAL = false
MERGE (ret)-[:RET_TO_CALL]->(call);

//////////////////////////////////////////////////////////////////////////////////////
// Comunica argumentos con parametros de funciones (llamarse una vez).              //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (call:CALL)-[:CALL]->(callee:METHOD)
WHERE callee.IS_EXTERNAL = false

MATCH (call)-[:ARGUMENT]->(arg)
WHERE arg.ARGUMENT_INDEX > 0

MATCH (callee)-[:AST]->(param:METHOD_PARAMETER_IN)
WHERE param.INDEX = arg.ARGUMENT_INDEX
MERGE (arg)-[:ARG_TO_PARAM]->(param);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene las llamadas a getenv cuyo valor alcanza al segundo argumento de una     //
// llamada a strcpy.                                                                //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (src:CALL)
WHERE src.METHOD_FULL_NAME = "getenv"

MATCH (m:METHOD)-[:CONTAINS]->(sink:CALL)-[:ARGUMENT]->(sinkArg)
WHERE
  sink.METHOD_FULL_NAME = "strcpy" AND
  sinkArg.ARGUMENT_INDEX = 2 AND
  EXISTS {
    MATCH (src)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(sinkArg)
  }

RETURN DISTINCT
  m.NAME AS vulnerableFn,
  src.CODE AS srcCode,
  src.LINE_NUMBER AS srcLine,
  sink.CODE AS sinkCode,
  sink.LINE_NUMBER AS sinkLine,
  sinkArg.CODE AS arg
ORDER BY vulnerableFn;