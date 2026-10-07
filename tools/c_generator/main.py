import argparse
import sys

from pycparser import c_generator

from c_grows import grow
from c_seed import CSeed


def main() -> None:
    parser = argparse.ArgumentParser(description="Crece un seed C por generaciones")
    parser.add_argument("seed", help="archivo .c base")
    parser.add_argument("-n", "--generations", type=int, default=1)
    parser.add_argument("-r", "--root", required=True,
                        help="función root (si el seed tiene varias)")
    parser.add_argument("-o", "--output", help="archivo de salida (default stdout)")
    parser.add_argument("-i", "--include", action="append", default=None,
                        help="header a incluir arriba (repetible)")
    
    args = parser.parse_args()

    headers = args.include or ["stdlib.h", "string.h"]
    ast = grow(CSeed(args.seed, args.root), args.generations)
    code = "".join(f"#include <{h}>\n" for h in headers) + "\n"
    code += c_generator.CGenerator().visit(ast)

    out = open(args.output, "w") if args.output else sys.stdout
    with out:
        out.write(code)


if __name__ == "__main__":
    main()
