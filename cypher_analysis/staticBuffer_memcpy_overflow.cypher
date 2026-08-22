// Query inspirada en OverflowBuffer. 
// CODEQL query https://github.com/github/codeql/blob/main/cpp/ql/src/Security/CWE/CWE-119/OverflowBuffer.ql
// Aclaración: imita el resultado de la query para el caso de accesos mediante memcpy y 
// strncpy en buffers de tamaño fijo. 

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
// Obtiene las llamadas a memcpy o strncpy que toman como argumento de destino un   //
// buffer de tamaño fijo menor al tamaño accedido                                   //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene los buffers de tamaño fijo
MATCH (buffer:IDENTIFIER)
WHERE buffer.CODE =~ ".*\\[\\d+\\]"

WITH buffer,
    split(buffer.CODE, '[')[1] AS afterBracket
WITH buffer, afterBracket,
    split(afterBracket, ']')[0] AS sizeStr
WITH buffer, sizeStr,
    toInteger(sizeStr) AS declaredSize
WITH buffer, declaredSize

// (b) Obtiene llamadas de la forma memcpy(dst, src, n), donde n es un entero y 
// dst es un buffer de tamaño fijo
MATCH (sinkCall:CALL)-[:AST]->(accessSizeArg:LITERAL)
WHERE sinkCall.METHOD_FULL_NAME IN ["memcpy", "strncpy"]
    AND accessSizeArg.ARGUMENT_INDEX = 3

MATCH (sinkCall)-[:AST]->(dstArg:IDENTIFIER)
WHERE dstArg.ARGUMENT_INDEX = 1
    AND EXISTS {
        MATCH (buffer)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(dstArg)
    }

// (c) Se queda solo con las llamadas para las que el buffer de destino tiene un 
// tamaño menor al accedido 
WITH sinkCall, declaredSize, 
    toInteger(accessSizeArg.CODE) AS accessSize
WHERE accessSize > declaredSize

RETURN sinkCall.CODE AS sink, declaredSize, accessSize;
