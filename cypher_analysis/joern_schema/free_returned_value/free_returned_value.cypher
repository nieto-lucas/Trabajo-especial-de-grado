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

//////////////////////////////////////////////////////////////////////////////////////
// Obtiene valores que se retornan por medio de un parametro y se liberan en algun  //
// camino mediante un free. Emula la query CPGQL de arriba.                         //
//////////////////////////////////////////////////////////////////////////////////////

// (a) Obtiene parametros punteros y sus usos tal que en NINGUN lugar ese punteros se
// reasigna ni se se toma su dirección
MATCH (refOutParam:IDENTIFIER)-[:REF]->(outParam:METHOD_PARAMETER_IN)
WHERE
  outParam.CODE =~ ".+\\*.+" AND
  refOutParam.ARGUMENT_INDEX = 1 AND
  NOT EXISTS {
    MATCH (callRefOutParam:CALL_NODE)-[:AST]->(refOutParam)
    WHERE
      callRefOutParam.NAME IN ["<operator>.assignment", "<operator>.addressOf"]
  }

// (b) Obtiene varaibles que se asignan a desreferencias del parametro puntero
// anterior. Por ej. x tal que *p = x
MATCH (callRefOutParam:CALL_NODE)-[:AST]->(refOutParam),
      (assign:CALL_NODE)-[:AST]->(callRefOutParam),
      (assign)-[:AST]->(assignValue:IDENTIFIER)
WHERE
  callRefOutParam.NAME IN [
    "<operator>.indirectFieldAccess",
    "<operator>.indirection",
    "<operator>.indirectIndexAccess"
  ] AND
  callRefOutParam.ARGUMENT_INDEX = 1 AND
  assign.NAME = "<operator>.assignment" AND
  assignValue.ARGUMENT_INDEX = 2

// (c) Verifica si la variable a la que apunta el parametro puntero es liberada
// por medio de un free
MATCH (assignValue)-[:REF]->(refTo),
      (refAssignValue:IDENTIFIER)-[:REF]->(refTo),
      (freeCall:CALL_NODE)-[:AST]->(refAssignValue)
WHERE 
  label(refTo) IN ["METHOD_PARAMETER_IN", "LOCAL"] AND
  freeCall.NAME =~ "(.*_)?free"

WITH assignValue, freeCall
WHERE
  EXISTS {
    MATCH (assignValue)-[:DOMINATE* SHORTEST]->(freeCall)
  }

RETURN DISTINCT assignValue;