.PHONY: all build run test lint clean docker-build docker-push deps

APP_NAME := makefeed-integrations-go
REGISTRY := registry.infra.makekod.ru
IMAGE := $(REGISTRY)/$(APP_NAME)
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

GOCMD := go
GOBUILD := $(GOCMD) build
GOTEST := $(GOCMD) test
GOMOD := $(GOCMD) mod
GOLINT := golangci-lint

all: lint test build

build:
	CGO_ENABLED=0 $(GOBUILD) -ldflags="-w -s -X main.Version=$(VERSION)" -o bin/$(APP_NAME) ./cmd/integrations

run:
	$(GOCMD) run ./cmd/integrations

test:
	$(GOTEST) -v -race -cover ./...

lint:
	$(GOLINT) run ./...

clean:
	rm -rf bin/

deps:
	$(GOMOD) download
	$(GOMOD) tidy

docker-build:
	docker build --platform linux/amd64 -t $(IMAGE):$(VERSION) -t $(IMAGE):dev .

docker-push:
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):dev
