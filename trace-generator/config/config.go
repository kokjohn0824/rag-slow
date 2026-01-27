package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds the configuration for the trace generator
type Config struct {
	TargetURL      string        // API base URL
	Interval       time.Duration // Call interval
	LogPath        string        // Log file path
	EnabledAPIs    []string      // Enabled APIs
	TimeoutSeconds int           // HTTP timeout in seconds
}

// Load loads configuration from environment variables
func Load() *Config {
	cfg := &Config{
		TargetURL:      getEnv("TARGET_URL", "http://trace-demo-app:8080"),
		Interval:       getDurationEnv("INTERVAL_SECONDS", 30) * time.Second,
		LogPath:        getEnv("LOG_PATH", "/logs/trace-generator.log"),
		EnabledAPIs:    getListEnv("ENABLED_APIS", []string{"order", "user", "report", "search", "batch", "simulate"}),
		TimeoutSeconds: getIntEnv("TIMEOUT_SECONDS", 30),
	}
	return cfg
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// getIntEnv gets an integer environment variable or returns a default value
func getIntEnv(key string, defaultValue int) int {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	intValue, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return intValue
}

// getDurationEnv gets a duration environment variable or returns a default value
func getDurationEnv(key string, defaultValue int) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return time.Duration(defaultValue)
	}
	intValue, err := strconv.Atoi(value)
	if err != nil {
		return time.Duration(defaultValue)
	}
	return time.Duration(intValue)
}

// getListEnv gets a comma-separated list environment variable or returns a default value
func getListEnv(key string, defaultValue []string) []string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	// Split by comma and trim spaces
	items := strings.Split(value, ",")
	result := make([]string, 0, len(items))
	for _, item := range items {
		trimmed := strings.TrimSpace(item)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	if len(result) == 0 {
		return defaultValue
	}
	return result
}
