package com.example.metrics;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class MetricsApp {
    public static void main(String[] args) {
        int vCpus = Runtime.getRuntime().availableProcessors();
        System.out.println("Starting Spring Boot with detected vCPUs: " + vCpus);
        SpringApplication.run(MetricsApp.class, args);
    }
}
