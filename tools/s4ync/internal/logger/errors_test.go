package logger_test

import (
	"errors"
	"testing"

	"github.com/arhuman/s4ync/internal/logger"
)

func TestConfigError(t *testing.T) {
	err := logger.NewConfigError(errors.New("missing endpoint"))

	if !errors.Is(err, logger.ErrConfig) {
		t.Error("ConfigError should match ErrConfig")
	}

	if logger.ExitCodeFromError(err) != 2 {
		t.Errorf("expected exit code 2, got %d", logger.ExitCodeFromError(err))
	}
}

func TestCriticalError(t *testing.T) {
	err := logger.NewCriticalError(errors.New("cannot read project.md"))

	if !errors.Is(err, logger.ErrCritical) {
		t.Error("CriticalError should match ErrCritical")
	}

	if logger.ExitCodeFromError(err) != 3 {
		t.Errorf("expected exit code 3, got %d", logger.ExitCodeFromError(err))
	}
}

func TestPartialError(t *testing.T) {
	err := logger.NewPartialError(5, 2, []string{"a.md", "b.md"}, errors.New("upload failed"))

	if !errors.Is(err, logger.ErrPartial) {
		t.Error("PartialError should match ErrPartial")
	}

	if logger.ExitCodeFromError(err) != 1 {
		t.Errorf("expected exit code 1, got %d", logger.ExitCodeFromError(err))
	}

	var pe *logger.PartialError
	if !errors.As(err, &pe) {
		t.Fatal("failed to extract PartialError")
	}

	if pe.Succeeded != 5 {
		t.Errorf("expected 5 succeeded, got %d", pe.Succeeded)
	}
	if pe.Failed != 2 {
		t.Errorf("expected 2 failed, got %d", pe.Failed)
	}
	if len(pe.FailedPaths) != 2 {
		t.Errorf("expected 2 failed paths, got %d", len(pe.FailedPaths))
	}
}

func TestExitCodeFromError_Nil(t *testing.T) {
	if logger.ExitCodeFromError(nil) != 0 {
		t.Error("nil error should return exit code 0")
	}
}

func TestExitCodeFromError_Unknown(t *testing.T) {
	err := errors.New("unknown error")

	if logger.ExitCodeFromError(err) != 1 {
		t.Error("unknown error should default to exit code 1")
	}
}

func TestConfigErrorf(t *testing.T) {
	err := logger.NewConfigErrorf("invalid %s: %s", "endpoint", "localhost")

	if !errors.Is(err, logger.ErrConfig) {
		t.Error("ConfigErrorf should create ConfigError")
	}

	expected := "configuration error: invalid endpoint: localhost"
	if err.Error() != expected {
		t.Errorf("expected %q, got %q", expected, err.Error())
	}
}

func TestCriticalErrorf(t *testing.T) {
	err := logger.NewCriticalErrorf("file not found: %s", "project.md")

	if !errors.Is(err, logger.ErrCritical) {
		t.Error("CriticalErrorf should create CriticalError")
	}

	expected := "critical error: file not found: project.md"
	if err.Error() != expected {
		t.Errorf("expected %q, got %q", expected, err.Error())
	}
}

func TestErrorUnwrap(t *testing.T) {
	innerErr := errors.New("inner error")

	configErr := logger.NewConfigError(innerErr)
	if !errors.Is(configErr, innerErr) {
		t.Error("ConfigError should unwrap to inner error")
	}

	criticalErr := logger.NewCriticalError(innerErr)
	if !errors.Is(criticalErr, innerErr) {
		t.Error("CriticalError should unwrap to inner error")
	}

	partialErr := logger.NewPartialError(0, 1, nil, innerErr)
	if !errors.Is(partialErr, innerErr) {
		t.Error("PartialError should unwrap to inner error")
	}
}
