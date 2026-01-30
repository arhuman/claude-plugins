// Package config handles configuration loading and validation for s4ync.
package config

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// Config holds the configuration for s4ync.
type Config struct {
	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOSecure    bool
	BucketName     string
	ProjectPath    string
}

// LoadFromEnv loads configuration from environment variables.
func LoadFromEnv() (*Config, error) {
	rawEndpoint := os.Getenv("MINIO_ENDPOINT")
	endpoint, secure := parseEndpoint(rawEndpoint)

	cfg := &Config{
		MinIOEndpoint:  endpoint,
		MinIOAccessKey: os.Getenv("MINIO_ACCESS_KEY"),
		MinIOSecretKey: os.Getenv("MINIO_SECRET_KEY"),
		MinIOSecure:    secure,
		BucketName:     getEnvOrDefault("MINIO_BUCKET", "global-projects"),
		ProjectPath:    getEnvOrDefault("PROJECT_PATH", ".claude/global-project"),
	}

	return cfg, cfg.Validate()
}

// NewConfig creates a Config with explicit values, useful for testing.
func NewConfig(endpoint, accessKey, secretKey, bucket, projectPath string, secure bool) *Config {
	return &Config{
		MinIOEndpoint:  endpoint,
		MinIOAccessKey: accessKey,
		MinIOSecretKey: secretKey,
		MinIOSecure:    secure,
		BucketName:     bucket,
		ProjectPath:    projectPath,
	}
}

// Validate checks that all required configuration values are present and valid.
func (c *Config) Validate() error {
	if c.MinIOEndpoint == "" {
		return errors.New("MINIO_ENDPOINT not set")
	}
	if c.MinIOAccessKey == "" {
		return errors.New("MINIO_ACCESS_KEY not set")
	}
	if c.MinIOSecretKey == "" {
		return errors.New("MINIO_SECRET_KEY not set")
	}
	if c.BucketName == "" {
		return errors.New("bucket name cannot be empty")
	}
	return nil
}

// ValidateProjectPath checks that the project path exists.
func (c *Config) ValidateProjectPath() error {
	absPath, err := c.AbsProjectPath()
	if err != nil {
		return err
	}

	info, err := os.Stat(absPath)
	if os.IsNotExist(err) {
		return errors.New("project path does not exist: " + absPath)
	}
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return errors.New("project path is not a directory: " + absPath)
	}
	return nil
}

// AbsProjectPath returns the absolute path to the project directory.
func (c *Config) AbsProjectPath() (string, error) {
	if filepath.IsAbs(c.ProjectPath) {
		return c.ProjectPath, nil
	}
	return filepath.Abs(c.ProjectPath)
}

func getEnvOrDefault(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	return val == "true" || val == "1" || val == "yes"
}

// parseEndpoint extracts the protocol from the endpoint and returns the endpoint without protocol
// and whether it should use secure (HTTPS) connection.
// Examples:
//   - "http://example.com:9000" -> ("example.com:9000", false)
//   - "https://example.com:9000" -> ("example.com:9000", true)
//   - "example.com:9000" -> ("example.com:9000", true) // defaults to HTTPS
func parseEndpoint(endpoint string) (string, bool) {
	if strings.HasPrefix(endpoint, "https://") {
		return strings.TrimPrefix(endpoint, "https://"), true
	}
	if strings.HasPrefix(endpoint, "http://") {
		return strings.TrimPrefix(endpoint, "http://"), false
	}
	// Default to HTTPS if no protocol specified
	return endpoint, true
}
