// Query inspirada en OverflowBuffer.
// CODEQL query https://github.com/github/codeql/blob/main/cpp/ql/src/Security/CWE/CWE-119/OverflowBuffer.ql
// Aclaración: imita el resultado de la query para el caso de accesos mediante memcpy y
// strncpy en buffers de tamaño fijo.

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
// Obtiene las llamadas a memcpy o strncpy que toman como argumento de destino u    //
// origen un buffer de tamaño fijo menor al tamaño accedido                         //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtenemos los datos de incialización de un buffer estatico
MATCH (method:METHOD)-[:CONTAINS]->(assign:CALL)
WHERE assign.METHOD_FULL_NAME = "<operator>.assignment"

MATCH (assign)-[:AST]->(alloc:CALL)-[:AST]->(allocSize:LITERAL)
WHERE alloc.METHOD_FULL_NAME = "<operator>.alloc"

MATCH (assign)-[:AST]->(buf:IDENTIFIER)
WHERE buf.ARGUMENT_INDEX = 1

// (b) Obtenemos llamadas a memcpy o strncpy para las que el tamaño accedido sea mayor
// al del buffer
MATCH (sinkCall:CALL)-[:ARGUMENT]->(accessSizeArg:LITERAL)
WHERE
  sinkCall.METHOD_FULL_NAME IN ["memcpy", "strncpy"] AND
  accessSizeArg.ARGUMENT_INDEX = 3

WITH
  method,
  sinkCall,
  buf,
  toInteger(allocSize.CODE) AS declaredSize,
  toInteger(accessSizeArg.CODE) AS accessSize
WHERE accessSize > declaredSize

// (c) Nos quedamos con los buffers y llamadas tal que el primero llega alcanza al
// argumento de destino u origen del segundo
MATCH (sinkCall)-[:ARGUMENT]->(dstArg:IDENTIFIER)
WHERE
  dstArg.ARGUMENT_INDEX IN [1, 2] AND
  EXISTS {
    MATCH (buf)-[r:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(dstArg)
    WITH dstArg, r[-1].VARIABLE AS taintedVar
    WHERE dstArg.CODE = taintedVar
  }

RETURN DISTINCT
  method.NAME AS fn,
  buf.CODE AS source,
  declaredSize,
  sinkCall.CODE AS sink,
  accessSize
ORDER BY fn;