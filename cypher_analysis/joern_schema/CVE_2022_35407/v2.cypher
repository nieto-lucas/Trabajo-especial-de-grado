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

MATCH p = (srcDataSizeArg)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(sinkDataSizeArg)
WHERE none(n IN nodes(p) 
    WHERE EXISTS {
        MATCH (reassign:CALL)-[:AST]->(n:IDENTIFIER)
        WHERE reassign.METHOD_FULL_NAME = "<operator>.assignment" 
            AND n.ARGUMENT_INDEX = 1
            AND n.CODE = sinkDataSizeArg.CODE
    }
)

RETURN sinkCall;