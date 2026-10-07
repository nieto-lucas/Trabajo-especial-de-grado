from pycparser import c_ast


class _ReturnValueFinder(c_ast.NodeVisitor):
    def __init__(self) -> None:
        self.returns_value = False

    def visit_Return(self, node: c_ast.Return) -> None:
        if node.expr is not None:
            self.returns_value = True


def returns_value(function: c_ast.FuncDef) -> bool:
    """
    Recorre una función `function` y determina si tiene un return no vacío
    """
    finder = _ReturnValueFinder()
    finder.visit(function)
    return finder.returns_value


class _ReturnCallExtractor(c_ast.NodeVisitor):
    def __init__(self) -> None:
        self.called: set[str] = set()

    def visit_FuncCall(self, node: c_ast.FuncCall) -> None:
        if isinstance(node.name, c_ast.ID):
            self.called.add(node.name.name)

        self.generic_visit(node)


class _ReturnExtractor(c_ast.NodeVisitor):
    def __init__(self) -> None:
        self.returns: list[c_ast.Return] = []

    def visit_Return(self, node: c_ast.Return) -> None:
        self.returns.append(node)


def returns_calls(function: c_ast.FuncDef) -> set[str]:
    """
    Recorre una función `function` y encuentra los nombres de las funciones
    llamadas directamente en una sentencia `return` (por ej. `return f();`).
    Ignora cualquier otra llamada dentro del cuerpo.
    """
    returns = _ReturnExtractor()
    returns.visit(function)

    calls = _ReturnCallExtractor()

    for node in returns.returns:
        if node.expr is not None:
            calls.visit(node.expr)

    return calls.called
