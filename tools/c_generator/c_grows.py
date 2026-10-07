import copy
from pycparser import c_ast

from c_transform import rename_calls, clone_function, insert_before, splice_returns
from c_seed import CSeed


def grow(seed: CSeed, generations: int) -> c_ast.FileAST:
    """
    Expande un archivo agregando recursivamente llamadas a funciones a todas 
    aquellas funciones terminales partiendo de una función root en la seed C.

    Args:
        - seed (CSeed) archivo base sobre el que aplicar las modificaciones
        - generations (int) número de generaciones restantes (tope a la recursión)
    
    Returns: copia del AST de archivo base expandido recursivamente 
    """
    ast_work = copy.deepcopy(seed.ast)
    
    functions_work = {
        func.decl.name: func
        for func in ast_work.ext if isinstance(func, c_ast.FuncDef)
    }
    terminals = {functions_work[t.decl.name] for t in seed.terminals}

    for _ in range(generations):
        new_terminals: set[c_ast.FuncDef] = set()    

        for terminal in terminals:
            new_terminals |= _expand(ast_work, seed, terminal)

        terminals = new_terminals

    return ast_work


def _expand(ast: c_ast.FileAST, seed: CSeed, terminal: c_ast.FuncDef) -> set[c_ast.FuncDef]:
    """
    Expande una función `terminal` sobre un `ast` y devuelve un conjunto de 
    terminales nuevas
    """
    terminal_name = terminal.decl.name

    mapping = {
        func.decl.name: f"{func.decl.name}_{terminal_name}"
        for func in seed.closure
    }

    template = copy.deepcopy(seed.root.body)
    rename_calls(template, mapping)
    splice_returns(terminal.body, template)

    clones = {
        func: clone_function(func, mapping[func.decl.name], mapping)
        for func in seed.closure
    }
    insert_before(ast, terminal, list(clones.values()))

    new_terminals = {clones[func] for func in seed.terminals}

    return new_terminals
