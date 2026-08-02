from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable

@dataclass(frozen=True)
class QueryResult:
    ids: frozenset[Decimal]

    @staticmethod
    def from_raw_ids(raw_ids: Iterable) -> "QueryResult":
        return QueryResult(frozenset(Decimal(x) for x in raw_ids))

    def cmp_result(self, other_result: "QueryResult") -> bool:
        return self.ids == other_result.ids

    def diff_result(self, other_result: "QueryResult") -> "QueryResult":
        return QueryResult(self.ids - other_result.ids)

    def __len__(self) -> int:
        return len(self.ids)
