package com.example.metrics;

import io.micrometer.core.instrument.Clock;
import io.micrometer.core.instrument.binder.jvm.*;
import io.micrometer.core.instrument.binder.system.ProcessorMetrics;
import io.micrometer.prometheus.PrometheusConfig;
import io.micrometer.prometheus.PrometheusMeterRegistry;
import io.prometheus.client.CollectorRegistry;
import io.undertow.Undertow;
import io.undertow.server.HttpHandler;
import io.undertow.server.HttpServerExchange;
import io.undertow.util.Headers;

import java.nio.charset.StandardCharsets;

public class MetricsApp {
    private static PrometheusMeterRegistry registry;

    public static void main(String[] args) {
        // Initialize Prometheus registry
        registry = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT, CollectorRegistry.defaultRegistry, Clock.SYSTEM);
        
        // Register JVM metrics
        new ClassLoaderMetrics().bindTo(registry);
        new JvmMemoryMetrics().bindTo(registry);
        new JvmGcMetrics().bindTo(registry);
        new JvmThreadMetrics().bindTo(registry);
        new ProcessorMetrics().bindTo(registry);

        int ioThreads = Math.max(2, Runtime.getRuntime().availableProcessors());
        int workerThreads = ioThreads * 8;

        // Start HTTP server
        Undertow server = Undertow.builder()
                .addHttpListener(8080, "0.0.0.0")
                .setIoThreads(ioThreads)
                .setWorkerThreads(workerThreads)
                .setHandler(new RoutingHandler())
                .build();
        
        server.start();
        System.out.println("Undertow server started on http://0.0.0.0:8080");
        System.out.println("IO threads: " + ioThreads + ", Worker threads: " + workerThreads);
        System.out.println("Metrics available at http://0.0.0.0:8080/metrics");
        System.out.println("Health available at http://0.0.0.0:8080/health");
    }

    static class RoutingHandler implements HttpHandler {
        @Override
        public void handleRequest(HttpServerExchange exchange) {
            String path = exchange.getRelativePath();
            
            if ("/metrics".equals(path)) {
                exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/plain; version=0.0.4");
                exchange.getResponseSender().send(registry.scrape(), StandardCharsets.UTF_8);
            } else if ("/health".equals(path)) {
                exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "application/json");
                exchange.getResponseSender().send("{\"status\":\"UP\",\"runtime\":\"undertow\"}", StandardCharsets.UTF_8);
            } else {
                exchange.setStatusCode(404);
                exchange.getResponseSender().send("Not Found");
            }
        }
    }
}
