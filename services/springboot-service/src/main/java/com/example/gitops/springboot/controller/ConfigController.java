package com.example.gitops.springboot.controller;

import com.example.gitops.springboot.config.AppProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/config")
public class ConfigController {

    private final AppProperties properties;

    public ConfigController(AppProperties properties) {
        this.properties = properties;
    }

    @GetMapping
    public Map<String, Object> getConfig() {
        return Map.of(
            "service", "springboot-service",
            "environment", properties.environment(),
            "message", properties.message(),
            "maxOrderQuantity", properties.maxOrderQuantity(),
            "featureFlagActive", properties.featureFlagActive()
        );
    }
}
