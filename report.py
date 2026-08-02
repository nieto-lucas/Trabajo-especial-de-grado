from dataclasses import dataclass
from neo4j import Driver

from cypher import exec_cypher_query
from query import QueryResult
from test_cases import TestCase

@dataclass(frozen=True)
class TestOutCome:
    test: TestCase
    joern_result: QueryResult
    cypher_result: QueryResult

    @property
    def passed(self) -> bool:
        return self.joern_result.cmp_result(self.cypher_result)

    @property
    def only_on_joern(self) -> QueryResult:
        return self.joern_result.diff_result(self.cypher_result)

    @property
    def only_on_cypher(self) -> QueryResult:
        return self.cypher_result.diff_result(self.joern_result)

def cmp_cypher(tests: list[TestCase], 
               joern_results: dict[TestCase, QueryResult], driver: Driver
) -> list[TestOutCome]:
    """Compara los resultados de una query en Joern con los resultados de la query en cypher
    para el mismo tests

    Args:
        - tests (list): Lista de test a comparar
        - joern_results (dict): Diccionario donde a cada test le corresponde un resultado a su
        consulta en Joern
        - driver (Driver): Driver para establecer una conexion con una instancia de Neo4j
    
    Return:
        Lista de resultados con en nombre del test y los ids obtenidos en Cypher y Joern
    """
    outcomes = []
    with driver.session() as session:
        for test in tests:
            joern_result = joern_results[test]
            cypher_result = exec_cypher_query(session, test)
            outcomes.append(
                TestOutCome(test, joern_result=joern_result, cypher_result=cypher_result)
            )

    return outcomes

def print_report(outcomes: list[TestOutCome]) -> bool:
    ok_tests = 0
    for outcome in outcomes:
        if outcome.passed:
            print(f'[OK] {outcome.test.name} ({len(outcome.joern_result)} nodos)')
            ok_tests += 1
            continue

        print(f'[FAIL] {outcome.test.name}')
        print(f'    joern: {len(outcome.joern_result)} nodos \n'
              f'    cypher: {len(outcome.cypher_result)} nodos')

        if outcome.only_on_cypher.ids:
            print(f'    solo en cypher: {sorted(outcome.only_on_cypher.ids)}')
        if outcome.only_on_joern.ids:
            print(f'    solo en joern: {sorted(outcome.only_on_joern.ids)}')

    print()
    print(f'==> {ok_tests}/{len(outcomes)} tests OK')

    return ok_tests == len(outcomes)
