package com.example.metrics;

import io.micrometer.core.instrument.Clock;
import io.micrometer.core.instrument.binder.jvm.*;
import io.micrometer.core.instrument.binder.system.ProcessorMetrics;
import io.micrometer.prometheus.PrometheusConfig;
import io.micrometer.prometheus.PrometheusMeterRegistry;
import io.prometheus.client.CollectorRegistry;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

@WebListener
public class MetricsInitializer implements ServletContextListener {
    private static PrometheusMeterRegistry registry;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        // Initialize Prometheus registry
        registry = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT, CollectorRegistry.defaultRegistry, Clock.SYSTEM);
        
        // Register JVM metrics
        new ClassLoaderMetrics().bindTo(registry);
        new JvmMemoryMetrics().bindTo(registry);
        new JvmGcMetrics().bindTo(registry);
        new JvmThreadMetrics().bindTo(registry);
        new ProcessorMetrics().bindTo(registry);

        sce.getServletContext().setAttribute("prometheusRegistry", registry);
        System.out.println("Prometheus metrics initialized for Tomcat");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        if (registry != null) {
            registry.close();
        }
    }

    public static PrometheusMeterRegistry getRegistry() {
        return registry;
    }
}
