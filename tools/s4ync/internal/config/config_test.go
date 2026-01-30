package config_test

import (
	"os"
	"testing"

	"github.com/arhuman/s4ync/internal/config"
)

func TestLoadFromEnv(t *testing.T) {
	tests := []struct {
		name      string
		envVars   map[string]string
		wantErr   bool
		errMsg    string
		checkFunc func(*testing.T, *config.Config)
	}{
		{
			name: "valid configuration",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "localhost:9000",
				"MINIO_ACCESS_KEY": "minioadmin",
				"MINIO_SECRET_KEY": "minioadmin",
			},
			wantErr: false,
			checkFunc: func(t *testing.T, cfg *config.Config) {
				if cfg.MinIOEndpoint != "localhost:9000" {
					t.Errorf("expected endpoint localhost:9000, got %s", cfg.MinIOEndpoint)
				}
				if cfg.BucketName != "global-projects" {
					t.Errorf("expected default bucket global-projects, got %s", cfg.BucketName)
				}
			},
		},
		{
			name: "missing endpoint",
			envVars: map[string]string{
				"MINIO_ACCESS_KEY": "minioadmin",
				"MINIO_SECRET_KEY": "minioadmin",
			},
			wantErr: true,
			errMsg:  "MINIO_ENDPOINT not set",
		},
		{
			name: "missing access key",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "localhost:9000",
				"MINIO_SECRET_KEY": "minioadmin",
			},
			wantErr: true,
			errMsg:  "MINIO_ACCESS_KEY not set",
		},
		{
			name: "missing secret key",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "localhost:9000",
				"MINIO_ACCESS_KEY": "minioadmin",
			},
			wantErr: true,
			errMsg:  "MINIO_SECRET_KEY not set",
		},
		{
			name: "custom bucket name",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "localhost:9000",
				"MINIO_ACCESS_KEY": "minioadmin",
				"MINIO_SECRET_KEY": "minioadmin",
				"MINIO_BUCKET":     "my-bucket",
			},
			wantErr: false,
			checkFunc: func(t *testing.T, cfg *config.Config) {
				if cfg.BucketName != "my-bucket" {
					t.Errorf("expected bucket my-bucket, got %s", cfg.BucketName)
				}
			},
		},
		{
			name: "http protocol prefix",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "http://localhost:9000",
				"MINIO_ACCESS_KEY": "minioadmin",
				"MINIO_SECRET_KEY": "minioadmin",
			},
			wantErr: false,
			checkFunc: func(t *testing.T, cfg *config.Config) {
				if cfg.MinIOEndpoint != "localhost:9000" {
					t.Errorf("expected endpoint localhost:9000, got %s", cfg.MinIOEndpoint)
				}
				if cfg.MinIOSecure {
					t.Error("expected MinIOSecure to be false for http://")
				}
			},
		},
		{
			name: "https protocol prefix",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "https://localhost:9000",
				"MINIO_ACCESS_KEY": "minioadmin",
				"MINIO_SECRET_KEY": "minioadmin",
			},
			wantErr: false,
			checkFunc: func(t *testing.T, cfg *config.Config) {
				if cfg.MinIOEndpoint != "localhost:9000" {
					t.Errorf("expected endpoint localhost:9000, got %s", cfg.MinIOEndpoint)
				}
				if !cfg.MinIOSecure {
					t.Error("expected MinIOSecure to be true for https://")
				}
			},
		},
		{
			name: "no protocol defaults to https",
			envVars: map[string]string{
				"MINIO_ENDPOINT":   "localhost:9000",
				"MINIO_ACCESS_KEY": "minioadmin",
				"MINIO_SECRET_KEY": "minioadmin",
			},
			wantErr: false,
			checkFunc: func(t *testing.T, cfg *config.Config) {
				if cfg.MinIOEndpoint != "localhost:9000" {
					t.Errorf("expected endpoint localhost:9000, got %s", cfg.MinIOEndpoint)
				}
				if !cfg.MinIOSecure {
					t.Error("expected MinIOSecure to be true when no protocol specified (default to https)")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear environment
			for _, key := range []string{"MINIO_ENDPOINT", "MINIO_ACCESS_KEY", "MINIO_SECRET_KEY", "MINIO_BUCKET", "PROJECT_PATH"} {
				os.Unsetenv(key)
			}

			// Set test environment
			for k, v := range tt.envVars {
				os.Setenv(k, v)
			}

			cfg, err := config.LoadFromEnv()

			if tt.wantErr {
				if err == nil {
					t.Error("expected error, got nil")
				} else if err.Error() != tt.errMsg {
					t.Errorf("expected error %q, got %q", tt.errMsg, err.Error())
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}

			if tt.checkFunc != nil {
				tt.checkFunc(t, cfg)
			}
		})
	}
}

func TestNewConfig(t *testing.T) {
	cfg := config.NewConfig(
		"localhost:9000",
		"access",
		"secret",
		"bucket",
		"/path/to/project",
		true,
	)

	if cfg.MinIOEndpoint != "localhost:9000" {
		t.Errorf("expected endpoint localhost:9000, got %s", cfg.MinIOEndpoint)
	}
	if cfg.MinIOAccessKey != "access" {
		t.Errorf("expected access key 'access', got %s", cfg.MinIOAccessKey)
	}
	if cfg.MinIOSecretKey != "secret" {
		t.Errorf("expected secret key 'secret', got %s", cfg.MinIOSecretKey)
	}
	if cfg.BucketName != "bucket" {
		t.Errorf("expected bucket 'bucket', got %s", cfg.BucketName)
	}
	if cfg.ProjectPath != "/path/to/project" {
		t.Errorf("expected project path '/path/to/project', got %s", cfg.ProjectPath)
	}
	if !cfg.MinIOSecure {
		t.Error("expected secure to be true")
	}
}

func TestValidate(t *testing.T) {
	tests := []struct {
		name    string
		cfg     *config.Config
		wantErr bool
		errMsg  string
	}{
		{
			name: "valid config",
			cfg: config.NewConfig(
				"localhost:9000",
				"access",
				"secret",
				"bucket",
				"/path",
				false,
			),
			wantErr: false,
		},
		{
			name: "empty endpoint",
			cfg: config.NewConfig(
				"",
				"access",
				"secret",
				"bucket",
				"/path",
				false,
			),
			wantErr: true,
			errMsg:  "MINIO_ENDPOINT not set",
		},
		{
			name: "empty bucket",
			cfg: config.NewConfig(
				"localhost:9000",
				"access",
				"secret",
				"",
				"/path",
				false,
			),
			wantErr: true,
			errMsg:  "bucket name cannot be empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.Validate()

			if tt.wantErr {
				if err == nil {
					t.Error("expected error, got nil")
				} else if err.Error() != tt.errMsg {
					t.Errorf("expected error %q, got %q", tt.errMsg, err.Error())
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
			}
		})
	}
}
