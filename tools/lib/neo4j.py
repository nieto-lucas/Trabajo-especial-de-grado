from dataclasses import dataclass
from neo4j import GraphDatabase, Session, Record, Result, ResultSummary

@dataclass(frozen=True)
class Neo4jConfig:
    uri: str
    database: str
    user: str
    password: str

    @staticmethod
    def from_dict(entry: dict) -> "Neo4jConfig":
        return Neo4jConfig(**entry)

class Neo4jClient:
    """
    Clase para interactuar con una BD Neo4j
    """
    def __init__(self, conf: Neo4jConfig) -> None:
        self._database = conf.database
        self._driver = GraphDatabase.driver(conf.uri, auth=(conf.user, conf.password))

    def __enter__(self) -> "Neo4jClient":
        return self

    def __exit__(self, *_) -> None:
        self.close()

    def close(self) -> None:
        self._driver.close()
        self._database = None

    def _session(self) -> Session:
        return self._driver.session(database=self._database)

    def run(self, query: str, **params) -> Result:
        """
        Obtiene un resumen del resultado de ejecutar una query
        """
        with self._session() as session:
            return session.run(query, **params)
        
    def read(self, query: str, **params) -> list[Record]:
        """
        Obtiene el resultado de una query como lista
        """
        with self._session() as session:
            return session.execute_read(lambda tx: list(tx.run(query, **params)))

    def write(self, query: str, **params) -> ResultSummary:
        """
        Obtiene un resumen de una query que escribe o modifica la DB
        """
        with self._session() as session:
            return session.execute_write(lambda tx: tx.run(query, **params).consume())
