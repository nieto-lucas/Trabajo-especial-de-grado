import copy
from pycparser import c_ast


def insert_before(
    ast: c_ast.FileAST, 
    node: c_ast.Node, 
    nodes: list[c_ast.Node]
) -> None:
    """
    Inserta `nodes` en el nivel superior de `ast`, justo antes de `node`
    """
    pos = ast.ext.index(node)
    ast.ext[pos:pos] = nodes


def clone_function(
    function: c_ast.FuncDef, 
    new_name: str | None = None, 
    call_map: dict[str, str] | None = None
) -> c_ast.FuncDef:
    """
    Copia `function` con otro nombre y con sus llamadas renombradas según `mapping`
    """
    clone = copy.deepcopy(function)
    if new_name is not None:
        rename_function(clone, new_name)
    
    if call_map is not None:
        rename_calls(clone.body, call_map)
    
    return clone


def rename_function(function: c_ast.FuncDef, new_name: str) -> None:
    """
    Renombra una función `function` según un nombre `new_name` 
    """
    function.decl.name = new_name

    type_decl = function.decl.type
    while not isinstance(type_decl, c_ast.TypeDecl):
        type_decl = type_decl.type

    type_decl.declname = new_name


class _CallRenamer(c_ast.NodeVisitor):
    def __init__(self, mapping: dict[str, str]) -> None:
        self._mapping = mapping
 
    def visit_FuncCall(self, node: c_ast.FuncCall) -> None:
        if isinstance(node.name, c_ast.ID) and node.name.name in self._mapping:
            node.name.name = self._mapping[node.name.name]

        self.generic_visit(node)


def rename_calls(node: c_ast.Node, mapping: dict[str, str]) -> None:
    """
    Renombra in-place cada FuncCall de `node` según `mapping` (si aplica)
    """
    _CallRenamer(mapping).visit(node)
 
  
class _ReturnSplicer(c_ast.NodeVisitor):
    def __init__(self, template: list[c_ast.Node]) -> None:
        self._template = template
 
    def visit_Compound(self, node: c_ast.Compound) -> None:
        self.generic_visit(node)

        if node.block_items is None:
            return
        
        spliced: list[c_ast.Node] = []

        for item in node.block_items:
            if isinstance(item, c_ast.Return) and item.expr is not None:
                spliced.extend(
                    copy.deepcopy(stmt) for stmt in self._template
                )
            else:
                spliced.append(item)

        node.block_items = spliced


def splice_returns(body: c_ast.Node, template: list[c_ast.Node]) -> None:
    """
    Reemplaza cada punto de retorno de `body` por una copia de `template`,
    preservando el resto de la estructura de `body` (declaraciones, ifs, etc). 
    
    Solo detecta returns que son sentencia directa de un bloque `{ ... }`, por ej. 
    un `if (x) return 1;` sin llaves no se reemplaza.
    """
    _ReturnSplicer(template).visit(body)
