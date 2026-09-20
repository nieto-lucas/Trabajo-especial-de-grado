import json
import subprocess
import sys
from string import Template
from pathlib import Path

from test_cases import TestCase
from query import QueryResult

# Template del código en Scala para ejecutar queries en Joern 
_SCALA_TEMPLATE = Template(r"""import java.io.PrintWriter
import scala.collection.mutable.LinkedHashMap
 
@main def exec(cpgFile: String, outFile: String) = {
    importCpg(cpgFile)
 
    val results = LinkedHashMap[String, List[Long]]()
 
$queries_block
 
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
""")

def _escape_scala_string(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')

def generate_scala_script(tests: list[TestCase], out_json_path: Path) -> str:
    lines = []
    for test in tests:
        key = _escape_scala_string(test.name)
        # Agrega una linea para obtener una lista de los ids de nodos consultados
        lines.append(f'    results("{key}") = ({test.joern}).id.l')

    queries_block = "\n".join(lines)

    return _SCALA_TEMPLATE.substitute(queries_block=queries_block)

def exec_all_joern_queries(
    joern_bin: Path, cpg_file: Path,
    tests: list[TestCase], debug_dir: Path
) -> dict[TestCase, QueryResult]:
    """Ejecuta todas las queries Joern dentro de una lista de tests (incia una JVM
    una única vez)

    Args:
        - joern_bin (Path): Path al comando `joern`
        - cpg_file (Path): Archivo con la representación del código como CPG
        - tests (list): Lista de tests  
        - debug_dir (Path): Directorio al que enviar el script Scala generado
    
    Return:
        Diccionario entre el caso de test y el resultado (ids) de cada query Joern.
    """
    debug_dir.mkdir(parents=True, exist_ok=True)
    script_path = debug_dir / "equiv.sc"
    out_path = debug_dir / "out.json"
    script_path.write_text(generate_scala_script(tests, out_path), encoding="utf-8")
    print(f'    Script generado: {script_path}')
    # Corre joern y ejecuta las queries del código Scala generado  
    cmd = [
        joern_bin, "--script", str(script_path),
        "--param", f'cpgFile={cpg_file}',
        "--param", f'outFile={out_path}',
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0 or not out_path.exists():
        print("== stdout de joern ==", file=sys.stderr)
        print(proc.stdout, file=sys.stderr)
        print("== stderr de joern ==", file=sys.stderr)
        print(proc.stderr, file=sys.stderr)
        print(f"    (podés re-correr manualmente: {joern_bin} --script {script_path} "
              f"--param cpgFile={cpg_file} --param outFile={out_path})", file=sys.stderr)
        raise RuntimeError("la ejecución de joern falló, ver salida arriba")

    raw_data: dict[str, list[int]] = json.loads(out_path.read_text(encoding="utf-8"))
    by_name = {test.name: test for test in tests}

    missmatches = by_name.keys() - raw_data.keys()
    if missmatches:
        raise RuntimeError(f"joern no devolvió resultados para: {sorted(missmatches)}")

    return {
        by_name[name]: QueryResult.from_raw_ids(ids)
        for name, ids in raw_data.items()
        if name in by_name
    }
