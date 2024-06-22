.DEFAULT_GOAL := build

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

## help: print this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'
.PHONY:help

confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]
.PHONY:confirm

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## run: Runs the server
run:
	@go run ./cmd/server
.PHONY:run

## start: starts a local development environment
start:
	@start
.PHONY:start

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## test: run all tests
.PHONY: test
test: test
	@echo 'Removing test cache...'
	go clean -testcache
	@echo 'Running tests...'
	go test -race -vet=off -timeout 30s ./...


## audit: tidy and vendor dependencies and format, vet and test all code
audit: vendor
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...
.PHONY:audit

## vendor: tidy and vendor dependencies
vendor:
	@echo 'Tidying and verifying module dependencies...'
	go mod tidy
	go mod verify
	@echo 'Vendoring dependencies...'
	go mod vendor
.PHONY:vendor


# ==================================================================================== #
# BUILD
# ==================================================================================== #
#
# Determine all Go files the project depends on, excluding standard library
SERVER_FILES = $(shell go list -f '{{if not .Standard}}{{$$dir := .Dir}}{{range .GoFiles}}{{printf "%s/%s\n" $$dir .}}{{end}}{{end}}' -deps ./cmd/server)
CLIENT_FILES = $(shell go list -f '{{if not .Standard}}{{$$dir := .Dir}}{{range .GoFiles}}{{printf "%s/%s\n" $$dir .}}{{end}}{{end}}' -deps ./cmd/client)

## build cmd/server
bin/pulse-server: $(SERVER_FILES)
	@echo 'Compiling server...'
	go build -ldflags="-X main.serverName=${SERVER_NAME} -X main.port=${PORT} -X main.uri=${URI} -X main.db=${DB}" -o=./bin/pulse-server ./cmd/server

## build cmd/client
bin/pulse-client: $(CLIENT_FILES)
	@echo 'Compiling client...'
	go build -ldflags="-X main.serverName=${SERVER_NAME} -X main.port=${PORT} -X main.hostname=${HOSTNAME}" -o=./bin/pulse-client ./cmd/client

## build: builds the server and client applications
build: audit bin/pulse-server bin/pulse-client
.PHONY:build
