package logger

import (
	"errors"
	"fmt"
)

// Sentinel errors for different error categories.
var (
	// ErrConfig indicates configuration error (exit code 2).
	ErrConfig = errors.New("configuration error")
	// ErrCritical indicates critical error (exit code 3).
	ErrCritical = errors.New("critical error")
	// ErrPartial indicates partial failure (exit code 1).
	ErrPartial = errors.New("partial failure")
)

// ConfigError wraps an error as a configuration error.
type ConfigError struct {
	Err error
}

func (e *ConfigError) Error() string {
	return fmt.Sprintf("configuration error: %v", e.Err)
}

func (e *ConfigError) Unwrap() error {
	return e.Err
}

func (e *ConfigError) Is(target error) bool {
	return target == ErrConfig
}

// NewConfigError creates a new configuration error.
func NewConfigError(err error) error {
	return &ConfigError{Err: err}
}

// NewConfigErrorf creates a new configuration error with formatted message.
func NewConfigErrorf(format string, args ...any) error {
	return &ConfigError{Err: fmt.Errorf(format, args...)}
}

// CriticalError wraps an error as a critical error.
type CriticalError struct {
	Err error
}

func (e *CriticalError) Error() string {
	return fmt.Sprintf("critical error: %v", e.Err)
}

func (e *CriticalError) Unwrap() error {
	return e.Err
}

func (e *CriticalError) Is(target error) bool {
	return target == ErrCritical
}

// NewCriticalError creates a new critical error.
func NewCriticalError(err error) error {
	return &CriticalError{Err: err}
}

// NewCriticalErrorf creates a new critical error with formatted message.
func NewCriticalErrorf(format string, args ...any) error {
	return &CriticalError{Err: fmt.Errorf(format, args...)}
}

// PartialError wraps an error as a partial failure error.
type PartialError struct {
	Err         error
	Succeeded   int
	Failed      int
	FailedPaths []string
}

func (e *PartialError) Error() string {
	return fmt.Sprintf("partial failure: %d succeeded, %d failed: %v", e.Succeeded, e.Failed, e.Err)
}

func (e *PartialError) Unwrap() error {
	return e.Err
}

func (e *PartialError) Is(target error) bool {
	return target == ErrPartial
}

// NewPartialError creates a new partial failure error.
func NewPartialError(succeeded, failed int, failedPaths []string, err error) error {
	return &PartialError{
		Err:         err,
		Succeeded:   succeeded,
		Failed:      failed,
		FailedPaths: failedPaths,
	}
}

// ExitCodeFromError returns the appropriate exit code for an error.
func ExitCodeFromError(err error) int {
	if err == nil {
		return 0
	}

	if errors.Is(err, ErrConfig) {
		return 2
	}

	if errors.Is(err, ErrCritical) {
		return 3
	}

	if errors.Is(err, ErrPartial) {
		return 1
	}

	// Default to partial failure for unknown errors
	return 1
}
