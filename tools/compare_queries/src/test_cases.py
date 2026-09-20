from dataclasses import dataclass
from pathlib import Path
import yaml

@dataclass(frozen=True)
class TestCase:
    name: str
    joern: str
    cypher: str

    @staticmethod
    def from_yaml_entry(entry: dict) -> "TestCase":
        return TestCase(**entry)

def load_tests(path: Path) -> list[TestCase]:
    with open(path, encoding="utf-8") as file:
        entries = yaml.safe_load(file)

    tests = [TestCase.from_yaml_entry(entry) for entry in entries]
    names = [test.name for test in tests]
    duplicates = {name for name in names if names.count(name) > 1}
    if duplicates:
        raise ValueError(f'Nombre de tests duplicados: {sorted(duplicates)}')

    return tests