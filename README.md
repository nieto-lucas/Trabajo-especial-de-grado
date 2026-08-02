# Equivalencia entre Joern CODEQL y Cypher queries:

Este repositorio contiene código para realizar comparaciones entre queries de Joern y Cypher

## Uso:

1. Usar Python 3.12.3 o más nuevo, luego crear y activar un entorno virtual:

    ```python3 -m venv .env```

    ```source .env/bin/activate```

2. Instalar las dependencias desde `requirements.txt`:

    ```pip install -r requirements.txt```

3. Crear un archivo `tests/queries.yml` basado en el archivo `tests/basic_queries.yml`

4. Levantar una conexión a Neo4J usando `neo4j console`

5. Correr `joern-parse <filepath> --output <cpg-bin>`

6. Correr `joern-export <cpg-bin> -repr all --format csvneo4j --out <export_dir>` para obtener la representación CPG del código sobre la que testear

7. Importar los archivos archivos `*<export_dir>/*_data.csv` y iniciar la base de datos con `cypher-shell -u <user> -p <password> <query>`

8. Correr `main.py` con las opciones `--neo4j-user`, `--neo4j-password`, `--joern-bin`, etc. (para más información usar `--help`).

## Dependencias:

- neo4j==6.2.0
- PyYAML==6.0.3
- pytz==2026.3.post1

## TO DO:

- [] Setear la configuración para tests también desde un archivo .yml
- [] Automatizar los puntos 5 y 6
- [] Automatizar punto 7
- [] Obtener los resultados completos de queries para así permitir consultas con avg, count, etc, e inclusive poder comparar aristas (ahí parece haber discrepancias entre Joern y Cypher)
