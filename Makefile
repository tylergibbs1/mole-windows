# Makefile for Mole Windows

.PHONY: all build clean release

# Output directory
BIN_DIR := bin

# Binaries
ANALYZE := analyze
STATUS := status

# Source directories
ANALYZE_SRC := ./cmd/analyze
STATUS_SRC := ./cmd/status

# Build flags
LDFLAGS := -s -w

all: build

# Local build (Windows)
build:
	@echo "Building for Windows..."
	go build -ldflags="$(LDFLAGS)" -o $(BIN_DIR)/$(ANALYZE).exe $(ANALYZE_SRC)
	go build -ldflags="$(LDFLAGS)" -o $(BIN_DIR)/$(STATUS).exe $(STATUS_SRC)

# Release build for Windows amd64
release-amd64:
	@echo "Building Windows amd64 release..."
	GOOS=windows GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o $(BIN_DIR)/$(ANALYZE)-windows-amd64.exe $(ANALYZE_SRC)
	GOOS=windows GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o $(BIN_DIR)/$(STATUS)-windows-amd64.exe $(STATUS_SRC)

# Release build for Windows arm64
release-arm64:
	@echo "Building Windows arm64 release..."
	GOOS=windows GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o $(BIN_DIR)/$(ANALYZE)-windows-arm64.exe $(ANALYZE_SRC)
	GOOS=windows GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o $(BIN_DIR)/$(STATUS)-windows-arm64.exe $(STATUS_SRC)

# Test
test:
	go test ./...

clean:
	@echo "Cleaning binaries..."
	rm -f $(BIN_DIR)/*.exe
