// Query modelada apartir del CVE-2022-35407 https://www.binarly.io/advisories/brly-2022-020
// Aclaración: detecta buffer overflow de la forma:
//  ...
// DataSize = 17;
// gRT->GetVariable(..., ..., ..., &DataSize, ...);
// gRT->GetVariable(..., ..., ..., &DataSize, ...);
//  ...
// Basandose en la idea de que ocurre por no hay una reasignación que reestablezca DataSize
// a un valor adecuado luego del primer GetVariable.
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
// Análisis para detección de buffer overflow modelado a partir del CVE-2022-35407. //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene una llamada a GetVariable de la forma: 
// gBT->GetVariable(..., ..., ..., &DataSize, ...)
MATCH (sourceCall:CALL)-[:ARGUMENT]->(srcDataSizeRef:CALL)
WHERE srcDataSizeRef.ARGUMENT_INDEX = 4
    AND sourceCall.METHOD_FULL_NAME = "<operator>.pointerCall"
    AND sourceCall.CODE =~ ".*->GetVariable.*"
    AND srcDataSizeRef.METHOD_FULL_NAME = "<operator>.addressOf"

MATCH (srcDataSizeRef)-[:AST]->(srcDataSizeArg:IDENTIFIER)
WHERE srcDataSizeArg.ARGUMENT_INDEX = 1

// (b) Obtiene una siguiente llamada a GetVariable tal que el argumento DataSize 
// de la anterior alcanza la nueva sin una reasignación explicita antes
MATCH (sinkCall:CALL)-[:ARGUMENT]->(sinkDataSizeRef:CALL)
WHERE sinkDataSizeRef.ARGUMENT_INDEX = 4
    AND sinkCall.METHOD_FULL_NAME = "<operator>.pointerCall"
    AND sinkCall.CODE =~ ".*->GetVariable.*"
    AND sinkDataSizeRef.METHOD_FULL_NAME = "<operator>.addressOf"
    AND sinkCall <> sourceCall

MATCH (sinkDataSizeRef)-[:AST]->(sinkDataSizeArg:IDENTIFIER)
WHERE sinkDataSizeArg.ARGUMENT_INDEX = 1
    AND EXISTS {
        MATCH p = (srcDataSizeArg)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(sinkDataSizeArg)
        // En NINGUN nodo del camino entre el srcDataSizeArg y sinkDataSizeArg del 
        // ocurre una asignación a sinkDataSizeArg que no sea srcDataSizeArg
        // (Trata de preveer casos donde se reestablece el cuarto arg entre llamadas) 
        WHERE none(n IN nodes(p) 
            WHERE EXISTS {
                MATCH (n:CALL)-[:AST]->(t:IDENTIFIER)
                WHERE n.METHOD_FULL_NAME = "<operator>.assignment" 
                    AND t.ARGUMENT_INDEX = 1
                    AND t.CODE = sinkDataSizeArg.CODE
        
                MATCH (n)-[:AST]->(s)
                WHERE s.ARGUMENT_INDEX = 2 
                    AND s.CODE <> srcDataSizeArg.CODE
            }
        )
    }

RETURN sinkCall;
