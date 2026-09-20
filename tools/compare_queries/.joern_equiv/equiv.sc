import java.io.PrintWriter
import scala.collection.mutable.LinkedHashMap
 
@main def exec(cpgFile: String, outFile: String) = {
    importCpg(cpgFile)
 
    val results = LinkedHashMap[String, List[Long]]()
 
    results("malloc_nodes") = (cpg.method(".*malloc$").callIn).id.l
    results("memcpy_nodes") = (cpg.method("(?i)memcpy").callIn).id.l
    results("malloc_arithmetic_arg_nodes") = (cpg.method(".*malloc$").callIn.where(_.argument(1).arithmetic)).id.l
 
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
