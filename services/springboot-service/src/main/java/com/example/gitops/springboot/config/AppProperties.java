package com.example.gitops.springboot.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(
    String environment,
    String message,
    int maxOrderQuantity,
    boolean featureFlagActive
) {}
