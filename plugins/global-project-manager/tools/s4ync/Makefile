.PHONY: build test clean install lint fmt

# Build variables
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS := -X 'github.com/arhuman/s4ync/cmd.Version=$(VERSION)' \
           -X 'github.com/arhuman/s4ync/cmd.GitCommit=$(GIT_COMMIT)' \
           -X 'github.com/arhuman/s4ync/cmd.BuildDate=$(BUILD_DATE)'

# Default target
all: build

# Build the binary
build:
	go build -ldflags "$(LDFLAGS)" -o s4ync .

# Run tests
test:
	go test ./... -v

# Run tests with coverage
test-coverage:
	go test ./... -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	rm -f s4ync coverage.out coverage.html

# Install to GOPATH/bin
install:
	go install -ldflags "$(LDFLAGS)" .

# Run linter
lint:
	golangci-lint run ./...

# Format code
fmt:
	go fmt ./...

# Run go mod tidy
tidy:
	go mod tidy

# Show help
help:
	@echo "Available targets:"
	@echo "  build         - Build the s4ync binary"
	@echo "  test          - Run tests"
	@echo "  test-coverage - Run tests with coverage report"
	@echo "  clean         - Remove build artifacts"
	@echo "  install       - Install to GOPATH/bin"
	@echo "  lint          - Run golangci-lint"
	@echo "  fmt           - Format code"
	@echo "  tidy          - Run go mod tidy"
