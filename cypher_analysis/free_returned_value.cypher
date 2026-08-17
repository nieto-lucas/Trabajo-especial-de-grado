// Query free-returned-value CPGQL query https://queries.joern.io/
// Autor: @maltek
// CPGQL query:
// ({
//      def outParams =
//          cpg.parameter
//              .code(".+\\*.+")
//              .whereNot(
//                  _.referencingIdentifiers
//                  .argumentIndex(1)
//                  .inCall
//                  .nameExact(Operators.assignment, Operators.addressOf)
//              )
//
//      def assignedValues =
//          outParams.referencingIdentifiers
//              .argumentIndex(1)
//              .inCall
//              .nameExact(Operators.indirectFieldAccess, Operators.indirection, Operators.indirectIndexAccess)
//              .argumentIndex(1)
//              .inCall
//              .nameExact(Operators.assignment)
//              .argument(2)
//              .isIdentifier
//
//      def freeAssigned =
//          assignedValues.map(id =>
//              (
//                  id,
//                  id.refsTo
//                      .flatMap {
//                          case p: MethodParameterIn => p.referencingIdentifiers
//                          case v: Local             => v.referencingIdentifiers
//                      }
//                      .inCall
//                      .name("(.*_)?free")
//              )
//          )
//
//      freeAssigned
//          .filter { case (id, freeCall) =>
//              freeCall.dominatedBy.exists(_ == id)
//          }
//          .flatMap(_._1)
// }).l
//

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene valores que se retornan por medio de un parametro y se liberan en algun  //
// camino mediante un free. Emula la query CPGQL de arriba.                         //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene parametros punteros y sus usos tal que en NINGUN lugar ese punteros se
// reasigna ni se se toma su dirección
MATCH (refOutParam:IDENTIFIER)-[:REF]->(outParam:METHOD_PARAMETER_IN)
WHERE outParam.CODE =~ ".+\\*.+"
    AND refOutParam.ARGUMENT_INDEX = 1
    AND NOT EXISTS {
        MATCH (callRefOutParam:CALL)-[:AST]->(refOutParam)
        WHERE callRefOutParam.NAME IN [
            "<operator>.assignment",
            "<operator>.addressOf"
        ]
    }

// (b) Obtiene varaibles que se asignan a desreferencias del parametro puntero
// anterior. Por ej. x tal que *p = x
MATCH (callRefOutParam:CALL)-[:AST]->(refOutParam)
WHERE callRefOutParam.NAME IN [
        "<operator>.indirectFieldAccess",
        "<operator>.indirection",
        "<operator>.indirectIndexAccess"
    ]
    AND callRefOutParam.ARGUMENT_INDEX = 1

MATCH (assignCall:CALL)-[:AST]->(callRefOutParam)
WHERE assignCall.NAME = "<operator>.assignment"

// (c) Verifica si la variable a la que apunta el parametro puntero es liberada
// por medio de un free
MATCH (assignCall)-[:AST]->(assignValue:IDENTIFIER)
WHERE assignValue.ARGUMENT_INDEX = 2

MATCH (assignValue)-[:REF]->(refTo)
WHERE refTo:METHOD_PARAMETER_IN OR refTo:LOCAL

MATCH (refAssignValue:IDENTIFIER)-[:REF]->(refTo)
MATCH (freeCall:CALL)-[:AST]->(refAssignValue)
WHERE freeCall.NAME =~ "(.*_)?free"

WITH assignValue, freeCall
WHERE EXISTS {
    MATCH (domNode)-[:DOMINATE*]->(freeCall)
    WHERE domNode = assignValue
}

RETURN DISTINCT assignValue;
