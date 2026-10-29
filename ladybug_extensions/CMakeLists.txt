cmake_minimum_required(VERSION 3.20)
project(LoernArithmetic VERSION 1.0.0 LANGUAGES CXX)

# Versión de Ladybug: DEBE coincidir con tu binario lbug (lbug --version).
set(LBUG_VERSION "0.22.0" CACHE STRING "Versión de Ladybug contra la que se compila")

# Checkout de ladybug en el MISMO tag que el binario lbug que vas a usar.
set(
    LBUG_SOURCE_DIR "" 
    CACHE PATH "Checkout de LadybugDB (mismo tag que el binario lbug)"
)

if(NOT LBUG_SOURCE_DIR)
    include(FetchContent)
    FetchContent_Declare(lbug_src
        URL https://github.com/LadybugDB/ladybug/archive/refs/tags/v${LBUG_VERSION}.tar.gz
        # URL_HASH SHA256=<hash>        # recomendado para builds reproducibles
        SOURCE_SUBDIR no_cmake_aca      # descarga pero NO compila el motor
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    )
    FetchContent_MakeAvailable(lbug_src)
    set(LBUG_SOURCE_DIR "${lbug_src_SOURCE_DIR}")
endif()

if(
    NOT LBUG_SOURCE_DIR OR 
    NOT EXISTS "${LBUG_SOURCE_DIR}/src/include/extension/extension.h"
)
    message(
        FATAL_ERROR 
        "Pasá -DLBUG_SOURCE_DIR=/ruta/a/ladybug"
    )
endif()

# Genera los headers que el motor produce al configurar (system_config.h)
set(LBUG_CFG_DIR "${CMAKE_BINARY_DIR}/lbug_cfg")
if(NOT EXISTS "${LBUG_CFG_DIR}/src/include/common/system_config.h")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${LBUG_SOURCE_DIR}" -B "${LBUG_CFG_DIR}"
                -DCMAKE_BUILD_TYPE=Release
        RESULT_VARIABLE LBUG_CFG_RC
        OUTPUT_QUIET
        ERROR_VARIABLE LBUG_CFG_ERR
    )
    if(NOT LBUG_CFG_RC EQUAL 0)
        message(FATAL_ERROR "Falló el configure de Ladybug:\n${LBUG_CFG_ERR}")
    endif()
endif()

message(STATUS "Compilando contra Ladybug v${LBUG_VERSION} (${LBUG_SOURCE_DIR})")

add_library(arithmetic SHARED
    src/loern_call_node.cpp
)

target_compile_features(arithmetic PRIVATE cxx_std_20)

target_include_directories(arithmetic PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/include
    ${LBUG_SOURCE_DIR}/src/include
    ${LBUG_CFG_DIR}/src/include  
)

# Nombre final: libarithmetic.lbug_extension
set_target_properties(arithmetic PROPERTIES
    PREFIX "lib"
    SUFFIX ".lbug_extension"
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)