import java.io.PrintWriter
import scala.collection.mutable.LinkedHashMap
 
@main def exec(cpgFile: String, outFile: String) = {
    importCpg(cpgFile)
 
    val results = LinkedHashMap[String, List[Long]]()
 
    results("generic_all_nodes") = (cpg.all).id.l
    results("generic_all_literal_nodes") = (cpg.literal).id.l
    results("generic_all_block_nodes") = (cpg.block).id.l
    results("generic_all_identifier_nodes") = (cpg.identifier).id.l
    results("generic_all_method_nodes") = (cpg.method).id.l
    results("generic_all_method_return_nodes") = (cpg.methodReturn).id.l
    results("generic_all_method_paramIn_nodes") = (cpg.methodParameterIn).id.l
    results("generic_all_method_paramOut_nodes") = (cpg.methodParameterOut).id.l
    results("generic_all_method_ref_nodes") = (cpg.methodRef).id.l
    results("generic_all_control_struct_nodes") = (cpg.controlStructure).id.l
    results("generic_all_namespace_nodes") = (cpg.namespace).id.l
    results("generic_all_namespaceBlock_nodes") = (cpg.namespaceBlock).id.l
    results("generic_all_binding_nodes") = (cpg.binding).id.l
    results("generic_all_file_node") = (cpg.file).id.l
    results("generic_all_call_nodes") = (cpg.call).id.l
    results("generic_all_type_nodes") = (cpg.typ).id.l
    results("generic_all_typeDecl_nodes") = (cpg.typeDecl).id.l
    results("generic_all_local_nodes") = (cpg.local).id.l
    results("generic_all_return_nodes") = (cpg.ret).id.l
    results("generic_all_cfg_nodes") = (cpg.all.filter(n => 
  n.outE("CFG").hasNext || n.inE("CFG").hasNext
)
).id.l
    results("generic_all_ast_nodes") = (cpg.astNode).id.l
    results("generic_all_ifStatements_nodes") = (cpg.method.controlStructure.controlStructureType("IF").distinct).id.l
    results("generic_methods_with_param_count_1") = (cpg.method.filter(_.parameter.size == 1)).id.l
 
    val json = "{" + results.map { case (k, v) =>
        "\"" + k.replace("\"", "\\\"") + "\":[" + v.mkString(",") + "]"
    }.mkString(",") + "}"
 
    val pw = new PrintWriter(outFile)
    try {
        pw.write(json)
    } finally {
        pw.close()
    }
}
