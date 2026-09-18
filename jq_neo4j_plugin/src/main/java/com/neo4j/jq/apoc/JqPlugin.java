package com.neo4j.jq.apoc;

// neo4j
import org.neo4j.procedure.*;
import org.neo4j.graphdb.Node;

// jackson
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

// jackson-jq
import net.thisptr.jackson.jq.BuiltinFunctionLoader;
import net.thisptr.jackson.jq.JsonQuery;
import net.thisptr.jackson.jq.Scope;
import net.thisptr.jackson.jq.Versions;

// Útilidades java
import java.util.*;
import java.util.stream.Stream;

/**
 * Plugin APOC - Ejecución jq inline con soporte de argumentos
 * 
 * Permite:
 * - Ejecutar consultas jq sobre propiedades JSON de nodos
 * - Pasar argumentos a las consultas jq
 * - Usar filtros complejos directamente en Cypher
 * 
 */
public class JqPlugin {
    // Mapea valores a objetos
    private static final ObjectMapper MAPPER = new ObjectMapper();
    // Necesario según la documentación de la API de jackson-jq
    private static final Scope ROOT_SCOPE;

    static {
        ROOT_SCOPE = Scope.newEmptyScope();
        BuiltinFunctionLoader.getInstance()
                             .loadFunctions(
                                Versions.JQ_1_6,
                                ROOT_SCOPE
                             );
    }

    /**
     * Ejecuta una consulta jq inline con soporte de argumentos/variables
     * 
     * @param node Nodo Neo4j que contiene la propiedad JSON
     * @param jsonPropertyName Nombre de la propiedad del nodo que contiene JSON
     * @param jqFilter Filtro jq (ej: '[.. | objects | select(._type == $type)]')
     * @param args Mapa de argumentos para la consulta
     * @return Stream con result::MAP, status::STRING, executionTimeMs::INTEGER, 
     * message::STRING, resultSize::INTEGER.
     * 
     * <pre>
     * {@code
     *      ...
     * CALL apoc.jq.execute(node, 'JSON_PROP',
     *   '[.. | objects | select(._type == $type)]',
     *   {type: typeVar}
     * ) YIELD result, executionTimeMs, resultSize 
     *      ...
     * }
     * </pre>
    */
    @Procedure(name = "apoc.jq.execute", mode = Mode.READ)
    @Description("Ejecuta una consulta jq inline con argumentos variables")
    public Stream<JqResult> execute(
            @Name("node") Node node,
            @Name("jsonPropertyName") String jsonPropertyName,
            @Name("jqFilter") String jqFilter,
            @Name(value = "args", defaultValue = "{}") Map<String, Object> args) 
    {
        long startTime = System.currentTimeMillis();
        try {
            Object jsonRaw = node.getProperty(jsonPropertyName, null);
            if (jsonRaw == null) {
                return Stream.of(new JqResult(
                    null,
                    "WARNING",
                    "No se encontró propiedad JSON: " + jsonPropertyName,
                    0,
                    0
                ));
            }
            JsonNode json = toJsonNode(jsonRaw);
            Object result = executeJqWithArgs(json, jqFilter, args);

            long executionTime = System.currentTimeMillis() - startTime;
            long resultSize = sizeOfResult(result);

            return Stream.of(new JqResult(
                result,
                "OK",
                null,
                executionTime,
                resultSize
            ));

        } catch (Exception e) {
            long executionTime = System.currentTimeMillis() - startTime;
            return Stream.of(new JqResult(
                null,
                "ERROR",
                e.getMessage(),
                executionTime,
                0
            ));
        }
    }

    /**
     * Ejecuta jq sobre JSON con argumentos variables
     * 
     * Los argumentos se pasan como variables jq:
     * - args = {var: "value"} -> accesible en jq como $var
     * - args = {idx: 2} -> accesible en jq como $idx
     */
    private Object executeJqWithArgs(JsonNode json, String jqFilter, Map<String, Object> args) 
        throws Exception 
    {
        JsonQuery query = JsonQuery.compile(jqFilter, Versions.JQ_1_6);        
        Scope scope = Scope.newChildScope(ROOT_SCOPE);
        
        if (args != null && !args.isEmpty()) {
            for (Map.Entry<String, Object> entry : args.entrySet()) {
                String varName = entry.getKey();
                Object varValue = entry.getValue();
                JsonNode varNode = MAPPER.valueToTree(varValue);
                
                // Inyecta variables en el scope
                scope.setValue(varName, varNode);
            }
        }

        List<JsonNode> results = new ArrayList<>();
        query.apply(scope, json, results::add);
        
        List<Object> output = new ArrayList<>();
        for (JsonNode resultNode : results) {
            output.add(MAPPER.treeToValue(resultNode, Object.class));
        }
        
        // Retornar como array si hay múltiples resultados, sino el primero
        if (output.isEmpty()) {
            return null;
        } else if (output.size() == 1) {
            return output.get(0);
        } else {
            return output;
        }
    }

    /**
     * Convierte un objeto a JsonNode
     */
    private JsonNode toJsonNode(Object obj) throws Exception {
        if (obj == null) {
            return MAPPER.nullNode();
        }        
        if (obj instanceof String) {
            String str = (String) obj;
            if (str.trim().startsWith("{") || str.trim().startsWith("[")) {
                return MAPPER.readTree(str);
            } else {
                return MAPPER.valueToTree(str);
            }
        } else if (obj instanceof JsonNode) {
            return (JsonNode) obj;
        } else {
            return MAPPER.valueToTree(obj);
        }
    }

    /**
     * Calcula el tamaño de un resultado para las métricas
     */
    private int sizeOfResult(Object result) {
        if (result == null) {
            return 0;
        } 
        if (result instanceof List) {
            return ((List<?>) result).size();
        } else if (result instanceof Map) {
            return ((Map<?, ?>) result).size();
        } else if (result instanceof String) {
            return ((String) result).length();
        } else if (result instanceof JsonNode) {
            JsonNode node = (JsonNode) result;
            if (node.isArray()) {
                return node.size();
            } else if (node.isObject()) {
                return node.size();
            }
        }
        
        return 1;
    }
}