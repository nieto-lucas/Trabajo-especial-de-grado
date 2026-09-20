// (a) Obtiene una llamada a GetVariable de la forma: 
// gBT->GetVariable(..., ..., ..., &DataSize, ...)
MATCH (sourceCall:CALL)-[:ARGUMENT]->(srcDataSizeRef:CALL)
WHERE srcDataSizeRef.ARGUMENT_INDEX = 4
    AND sourceCall.METHOD_FULL_NAME = "<operator>.pointerCall"
    AND sourceCall.CODE =~ ".*->GetVariable.*"
    AND srcDataSizeRef.METHOD_FULL_NAME = "<operator>.addressOf"

// (b) Obtiene una siguiente llamada a GetVariable tal que el argumento DataSize 
// de la anterior alcanza la nueva sin una reasignación explicita antes
MATCH (sinkCall:CALL)-[:ARGUMENT]->(sinkDataSizeRef:CALL)
WHERE sinkDataSizeRef.ARGUMENT_INDEX = 4
    AND sinkCall.METHOD_FULL_NAME = "<operator>.pointerCall"
    AND sinkCall.CODE =~ ".*->GetVariable.*"
    AND sinkDataSizeRef.METHOD_FULL_NAME = "<operator>.addressOf"
    AND sinkCall <> sourceCall
    AND sinkCall.LINE_NUMBER > sourceCall.LINE_NUMBER
    AND sinkDataSizeRef.CODE = srcDataSizeRef.CODE

MATCH (sinkDataSizeRef)-[:AST]->(sinkDataSizeValue:IDENTIFIER)
WHERE sinkDataSizeValue.ARGUMENT_INDEX = 1
    AND NOT EXISTS {
        MATCH (reassign)-[:AST]->(target:IDENTIFIER)
        WHERE target.ARGUMENT_INDEX = 1
            AND target.CODE = sinkDataSizeValue.CODE
            AND srcDataSizeRef.LINE_NUMBER < reassign.LINE_NUMBER
            AND reassign.LINE_NUMBER < sinkDataSizeRef.LINE_NUMBER

        MATCH (target)-[:REACHING_DEF|RET_TO_CALL|ARG_TO_PARAM*]->(sinkDataSizeValue)
    }

RETURN sinkCall;
