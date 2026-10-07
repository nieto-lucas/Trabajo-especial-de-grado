from pycparser import c_ast, parse_file

from c_analysis import returns_calls, returns_value


class CSeed:
    """
    Programa C base para las expansiones recursivas de funciones terminales
    """
    def __init__(self, filepath: str, root: str) -> None:
        self.ast: c_ast.FileAST = parse_file(filepath, use_cpp=False)
        functions = {
            func.decl.name: func 
            for func in self.ast.ext if isinstance(func, c_ast.FuncDef)
        }
        self.root: c_ast.FuncDef = functions[root]

        calls = {
            name: sorted(returns_calls(func)) 
            for name, func in functions.items()
        }

        visited: set[str] = {root}
        pending = list(calls[root])
        self.closure: list[c_ast.FuncDef] = []

        while pending:
            name = pending.pop()
            if name not in visited:
                visited.add(name)
                self.closure.append(functions[name])
                pending.extend(calls[name])

        self.terminals: set[c_ast.FuncDef] = {
            func for func in self.closure
            if not calls[func.decl.name] and returns_value(func)
        }
