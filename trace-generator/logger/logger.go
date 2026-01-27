package logger

import (
	"fmt"
	"io"
	"log"
	"os"
)

// Logger handles logging to both file and stdout
type Logger struct {
	file   *os.File
	logger *log.Logger
}

// New creates a new logger that writes to both file and stdout
func New(logPath string) (*Logger, error) {
	// Create log directory if it doesn't exist
	// Extract directory path
	dir := logPath[:len(logPath)-len(extractFilename(logPath))]
	if dir != "" && dir != "/" {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return nil, fmt.Errorf("failed to create log directory: %w", err)
		}
	}

	// Open log file (append mode)
	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}

	// Write to both file and stdout
	multiWriter := io.MultiWriter(f, os.Stdout)
	logger := log.New(multiWriter, "", log.LstdFlags)

	return &Logger{
		file:   f,
		logger: logger,
	}, nil
}

// Info logs an info message
func (l *Logger) Info(format string, v ...interface{}) {
	l.logger.Printf("[INFO] "+format, v...)
}

// Error logs an error message
func (l *Logger) Error(format string, v ...interface{}) {
	l.logger.Printf("[ERROR] "+format, v...)
}

// Warn logs a warning message
func (l *Logger) Warn(format string, v ...interface{}) {
	l.logger.Printf("[WARN] "+format, v...)
}

// Close closes the log file
func (l *Logger) Close() error {
	if l.file != nil {
		return l.file.Close()
	}
	return nil
}

// extractFilename extracts filename from a path
func extractFilename(path string) string {
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '/' {
			return path[i+1:]
		}
	}
	return path
}
