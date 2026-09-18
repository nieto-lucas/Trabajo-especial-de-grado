package com.neo4j.jq.apoc;

/**
 * Clase result necesaria para la implementación del plugin
 */
public class JqResult {
    public Object result;
    public String status;
    public String message;
    public long executionTimeMs;
    public long resultSize;

    public JqResult(
        Object result,
        String status,
        String message,
        long executionTimeMs,
        long resultSize
    )
    {
        this.result = result;
        this.status = status;
        this.message = message;
        this.executionTimeMs = executionTimeMs;
        this.resultSize = resultSize;
    }
}