# Herramientas para Loern:

Este directorio posee scripts para poder realizar cargar en un base de datos Neo4j el esquema de CPG generado por Joern, comprimirlo y realizar comparaciones entre las consultas Joern y Cypher de un CPG.

## Requerimientos previos:

- Python 3.12+
- neo4j-admin 2026+.
- Joern 4+ (requerido para `compare_queries`)
- recomendado: Java 21+ (usado en los comandos `joern`, `joern-parse` y `joern-export`)
- opcional: `jq_neo4j_plugin` descargado y configurado (si se quieren realizar comparaciones con el esquema comprimido)

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

### 3) Crear un archivo `config.yaml`:

Antes de usar las herramientas se debe crear un archivo de configuración `.yaml` de la forma:

```yaml
neo4j:
    database: database
    uri: uri
    user: user
    password: password

cpg2neo4j:
    neo4j_admin_bin: path/to/neo4j-admin
    joern_export_bin: path/to/joern-export
    export_dir: dir/to/export/cpg
```

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
├── compress/
│   ├── compress.py
│   └── main.py
|
├── cpg2neo4j/
│   ├── cpg_to_neo4j.py
│   ├── joern_export.py
│   ├── main.py
│   └── neo4j_admin.py
|
├── lib/
│   ├── __init__.py
│   └── neo4j.py
|
└── pyproject.toml
```

## `tools/cpg2neo4j`:

Script que recibe un archivo `cpg.bin` extraido con `joern-parse` y lo transforma en una base de datos Neo4j. Para hacer la carga de archivos `.csv` a Neo4j más eficiente se usa `neo4j-admin`, comando offline que requiere Neo4j detenido y escribe directamente en `$NEO4J_HOME/database`, lo cuál requiere permisos.

### 1) Crear un archivo `cpg.bin` usando `joern-parse`:

```bash
joern-pase foo.c -o cpg.bin
```

### 2) Detener Neo4j:

```bash
neo4j stop
```

### 3) Correr el programa con los permisos necesarios:

```bash
python main.py cpg.bin --config config.yaml
```

## `tools/compress`:

Script para comprimir el CPG en Neo4j eliminando el AST de las llamadas a funciones y reemplazandolos por una propiedad JSON en formato string para el nodo de la llamada a la función (`AST_JSON`).

### 1) Usar `tools/cpg2neo4j` para pasar de CPG a Neo4j:

### 2) Iniciar Neo4j:

```bash
neo4j start
```

### 3) Correr el programa:

```bash
python main.py --config config.yaml
```

## TO DO:

- [] Automatizar la obtención de metricas a partir de la ejecución de consultas Cypher.
- [] Meter como opción `compress` dentro de `cpg2neo4j`.
- [] Automatizar la parte de levantar la DB con `neo4j start` y `neo4j stop`.
- [] Mejorar el script para comparar queries.
    - [] Usar el cliente de Joern en lugar de ejecutar `joern` (menos pesado, más fácil).
    - [] Permitir comparaciones entre queries Cypher escritas en el  esquema original y el nuevo esquema comprimido.