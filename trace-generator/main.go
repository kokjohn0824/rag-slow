package main

import (
	"os"
	"os/signal"
	"syscall"
	"time"
	"trace-generator/client"
	"trace-generator/config"
	"trace-generator/logger"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize logger
	log, err := logger.New(cfg.LogPath)
	if err != nil {
		panic("Failed to initialize logger: " + err.Error())
	}
	defer log.Close()

	// Create API client
	apiClient := client.NewAPIClient(cfg.TargetURL, cfg.TimeoutSeconds)

	log.Info("Trace generator started")
	log.Info("Target URL: %s", cfg.TargetURL)
	log.Info("Interval: %s", cfg.Interval)
	log.Info("Enabled APIs: %v", cfg.EnabledAPIs)
	log.Info("Timeout: %d seconds", cfg.TimeoutSeconds)

	// Setup signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Create ticker for periodic API calls
	ticker := time.NewTicker(cfg.Interval)
	defer ticker.Stop()

	// Run first cycle immediately
	callAllAPIs(apiClient, log, cfg.EnabledAPIs)

	// Main loop
	for {
		select {
		case <-ticker.C:
			callAllAPIs(apiClient, log, cfg.EnabledAPIs)
		case sig := <-sigChan:
			log.Info("Received signal: %v, shutting down...", sig)
			return
		}
	}
}

// callAllAPIs calls all enabled API endpoints
func callAllAPIs(apiClient *client.APIClient, log *logger.Logger, enabledAPIs []string) {
	log.Info("Starting API call cycle")
	cycleStart := time.Now()

	// Define all available APIs
	apis := []struct {
		name string
		call func() error
	}{
		{"order", apiClient.CreateOrder},
		{"user", apiClient.GetUserProfile},
		{"report", apiClient.GenerateReport},
		{"search", apiClient.Search},
		{"batch", apiClient.BatchProcess},
		{"simulate", apiClient.Simulate},
	}

	successCount := 0
	failCount := 0

	// Call each enabled API
	for _, api := range apis {
		if !isEnabled(api.name, enabledAPIs) {
			continue
		}

		start := time.Now()
		err := api.call()
		duration := time.Since(start)

		if err != nil {
			log.Error("API %s failed: %v (took %s)", api.name, err, duration)
			failCount++
		} else {
			log.Info("API %s succeeded (took %s)", api.name, duration)
			successCount++
		}

		// Small delay between API calls to avoid overwhelming the server
		time.Sleep(1 * time.Second)
	}

	cycleDuration := time.Since(cycleStart)
	log.Info("Cycle completed: %d succeeded, %d failed (total time: %s)", successCount, failCount, cycleDuration)
}

// isEnabled checks if an API is enabled
func isEnabled(apiName string, enabledAPIs []string) bool {
	for _, enabled := range enabledAPIs {
		if enabled == apiName {
			return true
		}
	}
	return false
}
