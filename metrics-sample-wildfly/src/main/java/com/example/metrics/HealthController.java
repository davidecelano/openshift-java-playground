package com.example.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@RequestScoped
@Path("/health")
public class HealthController {
    
    @Inject
    private MeterRegistry meterRegistry;
    
    private Counter requestCounter;
    private Timer responseTimer;
    
    @PostConstruct
    public void setupMeters() {
        requestCounter = meterRegistry.counter("app_requests_total", "endpoint", "health");
        responseTimer = meterRegistry.timer("app_response_time_seconds", "endpoint", "health");
    }
    
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response health() {
        return responseTimer.record(() -> {
            requestCounter.increment();
            return Response.ok()
                .entity("{\"status\":\"UP\",\"runtime\":\"wildfly\"}")
                .build();
        });
    }
}
