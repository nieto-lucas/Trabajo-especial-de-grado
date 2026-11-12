// Query inspirada en get-env-to-strcpy CPGQL query https://queries.joern.io/
// CPGQL query:
// ({
//      def source = cpg.call.methodFullName("getenv")
//      def sink = cpg.call.methodFullName("strcpy").argument(2)
//      sink.reachableBy(source).l
// }).l

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene las llamadas a getenv cuyo valor alcanza al segundo argumento de una     //
// llamada a strcpy.                                                                //
//////////////////////////////////////////////////////////////////////////////////////
MATCH (src:CALL_NODE)
WHERE src.METHOD_FULL_NAME = "getenv"

MATCH (sink:CALL_NODE)-[:ARGUMENT]->(sinkArg {ARGUMENT_INDEX: 2})
WHERE
  sink.METHOD_FULL_NAME = "strcpy" AND
  reachable_by(src, sink)

MATCH (m:METHOD)-[:CONTAINS]->(sink)

RETURN
  m.NAME AS vulnerableFn,
  src.CODE AS srcCode,
  src.LINE_NUMBER AS srcLine,
  sink.CODE AS sinkCode,
  sink.LINE_NUMBER AS sinkLine,
  sinkArg.CODE AS arg
ORDER BY vulnerableFn;