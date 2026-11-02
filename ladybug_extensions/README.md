# Extensión Loern para Ladybug DB:

Este directorio posee archivos para extender Cypher en LadyBug DB, por medio de funciones escritas en C++.

## Organización de la extensión:

```
ladybug_extensions/
├── src/
│  ├── function/
│  │   └── call_nodes.cpp
│  ├── include/
│  │   ├── function/
│  │   │   └── call_nodes.hpp
│  │   └── main/
│  │       └── loern_extension.hpp
│  └── main/
│      └── loern_extension.cpp
│  
├── build/
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
| Extension: ruta/a/este/directorio/build/lib/libloern.lbug_extension has been loaded.        |

Las extensiones en LadyBug DB están ligadas al ciclo de vida de la sesión activa, fuera de ella debe volver a cargarse en cada ocasión