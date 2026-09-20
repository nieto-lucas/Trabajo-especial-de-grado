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

CALL
  apoc.jq.execute(
    call,
    "AST_JSON",
    '[.AST[] | select(.ARGUMENT_INDEX > 0)]'
  )
  YIELD result
  WHERE result <> []

UNWIND result AS arg
MATCH (callee)-[:AST]->(param:METHOD_PARAMETER_IN)
WHERE param.INDEX = arg.ARGUMENT_INDEX
MERGE (call)-[:ARG_TO_PARAM]->(param);

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene las llamadas a getenv cuyo valor alcanza al segundo argumento de una     //
// llamada a strcpy.                                                                //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (src:CALL {METHOD_FULL_NAME: "getenv"})
MATCH (sink:CALL {METHOD_FULL_NAME: "strcpy"})

CALL apoc.jq.execute(
    sink,
    "AST_JSON",
    '[.AST[] | select(.ARGUMENT_INDEX == 2) | {CODE}]'
) 
YIELD result
WHERE result <> []

MATCH (m:METHOD)-[:CONTAINS]->(sink)
WHERE EXISTS {
    MATCH (src)-[r:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(sink)
    WHERE last(r).VARIABLE = result[0].CODE
  }

RETURN DISTINCT
  m.NAME AS vulnerableFn,
  src.CODE AS srcCode,
  src.LINE_NUMBER AS srcLine,
  sink.CODE AS sinkCode,
  sink.LINE_NUMBER AS sinkLine,
  result[0].CODE AS arg
ORDER BY vulnerableFn;