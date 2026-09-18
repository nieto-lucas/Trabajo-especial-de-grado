# APOC jq plugin:

Extensión del plugin APOC para Cypher que agrega un procedimiento para ejecutar consultas `jq` sobre propiedades tipo JSON en nodos. Integra las consultas `jq` a Cypher de forma eficiente y permite agregar argumentos a los filtros JSON, facilitando así el uso de estos mediante Cypher. 

```Cypher
    ...
CALL apoc.jq.execute(node, 'JSON_PROP',
    '[.. | objects | select(._type == $type)]',
    {type: typeVar}
) YIELD result, executionTimeMs, resultSize 
    ...
```

## Requisitos previos:

- Java 17+
- Maeven 3.8+
- Neo4j 4.4+
- opcional: Cypher 5x
- opcional: APOC (si se configura correctamente el procedimiento `apoc.jq.execute` puede usarse sin APOC)

## Instalación:

### 1) Compilar el proyecto:

Desde este directorio ejecutar:

```bash
mvn clean package
```

#### Salida esperada:

```
[INFO] BUILD SUCCESS
[INFO] Total time: XX.XXs
[INFO] Artifacts created in target/
```

#### Archivos generados:

- `target/apoc-jq-plugin-1.0-SNAPSHOT.jar` (sin dependencias)
- `target/apoc-jq-plugin-jar-with-dependecies.jar` (Con dependencias, usar este)

### 2) Copiar el JAR:

```bash
# Reemplazar con la ruta real segun tu instalación
export NEO4J_PLUGINS="/usr/local/neo4j/plugins"

cp target/apoc-jq-plugin-jar-with-dependencies.jar \
    $NEO4J_PLUGINS/apoc-jq-plugin.jar
```

### 3) Configurar Neo4j para cargar el procedimiento:

Editar `$NEO4J_HOME/conf/neo4j.conf`:

#### Buscar y agregar esta linea:

```
dbms.security.procedures.unrestricted=apoc.jq.execute
```

### 4) Reiniciar Neo4j:

```bash
# Parar Neo4j
neo4j stop

# Iniciar Neo4j
neo4j start

# Verificar logs
tail -f $NEO4J_HOME/logs/neo4j.log
```

#### Para verificar la instalación:

Conectarse a Neo4j y ejecutar:

```Cypher
CALL dbms.procedures()
WHERE name STARTS WITH 'apoc.jq'
RETURN name, description, signature
```

#### Salida esperada:

```
name                  description                                    signature
"apoc.jq.execute"     "Ejecuta una consulta jq inline..."           (node, jsonPropertyName, jqFilter, args) :: (result, status, executionTimeMs, resultSize, jqFilter)
```

## Procedimiento:

`apoc.jq.execute(node, jsonPropertyName, jqFilter, args)`

### Parámetros:

- `node`: Node Neo4j con propiedad tipo JSON
- `jsonPropertyName`: Nombre de propiedad que contiene el "JSON"
- `jqFilter`: Filtro jq como string
- `args` (opcional): Map de argumentos variables `{var1: value1, var2: value2}`

### Retorna:

- `result`: Resultado de la consulta `jq` 
- `status`: "OK" | "ERROR" | "WARNING"
- `executionTimeMs`: Tiempo de ejecución
- `resultSize`: Tamaño del resultado

## Sintaxis básica de jq:

### Operadores básicos:

- `.`: selecciona todo
- `..`: recursivo, pasa por todos los niveles
- `.property`: accede a propiedad
- `.[]`: itera array
- `.[index]`: indice especifico

### Filtros:

- `objects`: solo objetos (NO arrays)
- `arrays`: solo arrays
- `select(condition)`: filtra por condición
- `map(expr)`: transforma cada elemento
- `group_by(.property)`: agrupa por propiedad