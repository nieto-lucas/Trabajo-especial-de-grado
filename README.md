# Equivalencia entre Joern CPGQL y Cypher queries:

Este repositorio contiene código y herrmientas para realizar comparaciones entre queries de Joern y Cypher

## Pre requisitos:

1. Usar Python 3.12.3 o más nuevo, luego crear y activar un entorno virtual:

    ```python3 -m venv .env```

    ```source .env/bin/activate```

2. Instalar las dependencias desde `requirements.txt`:

    ```pip install -r requirements.txt```

## compare-queries:

1. Ir al directorio `compare_queries/`

2. Crear un archivo `tests/queries.yml` basado en el archivo `tests/basic_queries.yml`

3. Usar cpg2neo4j para pasar de CPG a una DB Neo4j 

4. Conectarse a Neo4j usando `neo4j console`

5. Correr `python main.py tests/queries.yml` con las opciones `--neo4j-user`, `--neo4j-password`, `--joern-bin`, etc. (para más información usar `--help`).

## cpg2neo4j:

1. Ir al directorio `cpg2neo4j/`

2. Crear un archivo `cpg.bin` usando `joern-parse`

3. Correr `python main.py cpg.bin` con las opciones `--neo4j-admin-bin`, `--joern-export-bin`, `--export-dir`, `--database` (para más información usar `--help`).

## Dependencias:

- neo4j==6.2.0
- PyYAML==6.0.3
- pytz==2026.3.post1

## TO DO:

- [] Implementar análisis para CVE-2022-36372
- [] Agregar un README por cada carpeta de analisis con un resumen del mismo.
- [] Implementar un programa en Rust para correr todos los análisis o uno solo.
- [] Ver si puedo obtener ejemplos reales de funciones para los CVE de UEFI usando efiSeek y Ghidra. 
- [] Setear la configuración para tests también desde un archivo .yml
- [] Obtener los resultados completos de queries para así permitir consultas con avg, count, etc, e inclusive poder comparar aristas (ahí parece haber discrepancias entre Joern y Cypher)
