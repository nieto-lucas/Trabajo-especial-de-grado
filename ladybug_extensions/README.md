# Extensión Loern para Ladybug DB:

Este directorio posee archivos para extender Cypher en LadyBug DB, por medio de funciones escritas en C++.

## Organización de la extensión:

```
ladybug_extensions/
├── src/
│  ├── function/
│  │   ├── reachable_by.cpp
│  │   └── call_nodes.cpp
│  ├── include/
│  │   ├── function/
│  │   │   ├── reachable_by.hpp
│  │   │   └── call_nodes.hpp
│  │   └── main/
│  │       └── loern_extension.hpp
│  └── main/
│      └── loern_extension.cpp
│  
└── CMakeLists.txt
```

## ¿ Cómo usar la extensión ? 

### 1) Compilar la extensión:

Desde el directorio actual ejecutar

```bash
cmake -S . build
cmake --build build
```

Esto genera un binario en el subdirectorio `./build/lib` llamado `libloern.lbug_extension`

### 2) En una base de datos ya creada ejecutar:

```cypher
LOAD EXTENSION 'ruta/a/este/directorio/build/lib/libloern.lbug_extension';
```

Esto debería generar:

| result</br>STRING                                                                           |
|---------------------------------------------------------------------------------------------|
| Extension: ruta/a/este/directorio/build/lib/loern.lbug_extension has been loaded.           |

Las extensiones en LadyBug DB están ligadas al ciclo de vida de la sesión activa, fuera de ella debe volver a cargarse en cada ocasión

## Funciones:

### is_arithmetic:

Función escalar que determina si un nodo de tipo `CALL_NODE` es una función aritmetica. Un ejemplo es de su uso es las clausulas `WHERE`

```cypher
WHERE is_arithmetic(node)
```

- node: nodo llamada a función que se evaluara para saber si la función es aritmetica. Tipo: `NODE`

Los nodos que recibe `is_arithmetic` deben ser de la tabla `CALL_NODE` sino lanza una excepción durante el bind.

### reachable_by:

Función escalar que determina si un par nodos son alcanzables por un camino de relaciones de flujo de datos salientes 
(camino de relaciones `REACHING_DEF`, `ARG_TO_PARM` o `RET_TO_CALL`)

Busca ser equivalente al metódo `reachableBy` de Joern para queries CPGQL y reemplazar la clasula cypher:

```cypher
WHERE EXISTS {
    MATCH (src)-[:REACHABLE_BY|:ARG_TO_PARAM|:RET_TO_CALL *SHORTEST]->(src)
}
```

por el siguiente uso de la función `reachable_by`:

```cypher
WHERE reachable_by(src, sink)
```

También puede recibir ids de nodos:

```cypher
WHERE reachable_by(id(src), id(sink))
```

- src: origen, desde donde parte la busqueda. Tipo: `NODE | INTERNAL_ID`
- sink: destino, frontera donde terminar la busqueda. Tipo `NODE | INTERNAL_ID`

Un alias de `reachable_by` es `reachable_by_fwd`

Si el grafo no tiene relaciones `REACHING_DEF`, `ARG_TO_PARAM` ni `RET_TO_CALL` devuelve una excepción durante el bind.

### reachable_by_bwd:

Función escalar que determina si un par de nodos son alcanzables por un camino de relaciones de flujo de datos entrantes
(camino de relaciones `REACHING_DEF`, `ARG_TO_PARM` o `RET_TO_CALL`)

Busca ser equivalente al metódo `reachableBy` de Joern para queries CPGQL y reemplazar la clasula cypher:

```cypher
WHERE EXISTS {
    MATCH (sink)<-[:REACHABLE_BY|:ARG_TO_PARAM|:RET_TO_CALL *SHORTEST]-(src)
}
```

por el siguiente uso de la función `reachable_by_bwd`:

```cypher
WHERE reachable_by_bwd(sink, src)
```

También puede recibir ids de nodos:

```cypher
WHERE reachable_by_bwd(id(sink), id(src))
```

- sink: origen, desde donde parte la busqueda. Tipo: `NODE | INTERNAL_ID`
- src: destino, frontera donde terminar la busqueda. Tipo `NODE | INTERNAL_ID`

Si el grafo no tiene relaciones `REACHING_DEF`, `ARG_TO_PARAM` ni `RET_TO_CALL` devuelve una excepción durante el bind.