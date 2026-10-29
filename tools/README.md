# Herramientas para Loern:

Este directorio posee scripts para poder realizar cargar en un base de datos Neo4j el esquema de CPG generado por Joern, comprimirlo y realizar comparaciones entre las consultas Joern y Cypher de un CPG.

## Requerimientos previos:

- Python >= 3.12
- Joern >= 4 (requerido para `compare_queries`)
- recomendado: Java >= 21 (usado en los comandos `joern`, `joern-parse` y `joern-export`)
- opcional: C++ >= 20 (se necesita si se quiere cargar la extensión de LadyBug DB)

## Configuración:

### 1) Crear un entorno virtual:

Desde este directorio ejecutar

```bash
python -m venv .env
source .env/bin/activate
```

### 2) Instalar dependencias desde `pyproject.toml`:

En el mismo directorio y en el entorno virtual ejecutar:

```bash
pip install -e .
```
> Las dependencias del proyecto pueden verificarse en `pyproject.toml`

## Origanización de las herramientas:

```
tools/
├── compare_queries/
│   ├── programs/
│   ├── reports/
│   ├── src/
│   │   ├── cypher.py
│   │   ├── joern.py
│   │   ├── main.py
│   │   ├── query.py
│   │   ├── report.py
│   │   └── test_cases.py
│   └── tests/
|
├── cpg2ladybug/
│   ├── IPA_loader.py
│   ├── ladybug_loader.py
│   ├── joern_export.py
│   ├── main.py
│   └── neo4jcsv.py
|
└── pyproject.toml
```

## `tools/cpg2ladybug`:

Script que recibe un archivo `cpg.bin` extraido con `joern-parse` y lo transforma en una base de datos LadyBugDB.
### 1) Crear un archivo `cpg.bin` usando `joern-parse`:

```bash
joern-pase foo.c -o cpg.bin
```

### 2) Correr el programa:

```bash
python main.py cpg.bin --joern-export-bin ruta/a/joern-export-bin
```
