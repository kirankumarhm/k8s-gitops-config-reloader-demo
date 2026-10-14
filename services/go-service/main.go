package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
)

type Config struct {
	Service           string `json:"service"`
	Environment       string `json:"environment"`
	Message           string `json:"message"`
	MaxItems          int    `json:"maxItems"`
	FeatureFlagActive bool   `json:"featureFlagActive"`
}

func loadConfig() Config {
	cfg := Config{
		Service:           "go-service",
		Environment:       getEnv("APP_ENVIRONMENT", "local"),
		Message:           getEnv("APP_MESSAGE", "Default local Go message"),
		MaxItems:          getEnvInt("APP_MAX_ITEMS", 50),
		FeatureFlagActive: getEnvBool("APP_FEATURE_FLAG_ACTIVE", false),
	}

	// If mounted config file exists (from ConfigMap), load from it:
	if data, err := os.ReadFile("/etc/config/config.json"); err == nil {
		var fileCfg Config
		if err := json.Unmarshal(data, &fileCfg); err == nil {
			if fileCfg.Environment != "" {
				cfg.Environment = fileCfg.Environment
			}
			if fileCfg.Message != "" {
				cfg.Message = fileCfg.Message
			}
			if fileCfg.MaxItems != 0 {
				cfg.MaxItems = fileCfg.MaxItems
			}
			cfg.FeatureFlagActive = fileCfg.FeatureFlagActive
		}
	}

	return cfg
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return fallback
}

func getEnvBool(key string, fallback bool) bool {
	if val := os.Getenv(key); val != "" {
		if b, err := strconv.ParseBool(val); err == nil {
			return b
		}
	}
	return fallback
}

func main() {
	port := getEnv("PORT", "8085")

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "UP"})
	})

	http.HandleFunc("/api/v1/config", func(w http.ResponseWriter, r *http.Request) {
		cfg := loadConfig()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(cfg)
	})

	fmt.Printf("go-service listening on port %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
