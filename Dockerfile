############################################################################################################
# Build the Go binary for the Gateway
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-gateway

WORKDIR /app

COPY ./CasaOS-Gateway/go.mod ./
COPY ./CasaOS-Gateway/go.sum ./

RUN go mod download

COPY ./CasaOS-Gateway/cmd ./cmd
COPY ./CasaOS-Gateway/common ./common
COPY ./CasaOS-Gateway/pkg ./pkg
COPY ./CasaOS-Gateway/route ./route
COPY ./CasaOS-Gateway/service ./service
COPY ./CasaOS-Gateway/build ./build
COPY ./CasaOS-Gateway/main.go ./main.go

RUN go build -o casaos-gateway .

# default config
COPY ./CasaOS-Gateway/build/sysroot/etc/casaos/gateway.ini.sample /etc/casaos/gateway.ini
RUN mkdir -p /var/run/casaos/ && echo -n "{}" >> /var/run/casaos/routes.json

############################################################################################################
# Build the Go binary for the User Service
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-user-service

WORKDIR /app

COPY ./CasaOS-UserService/go.mod ./
COPY ./CasaOS-UserService/go.sum ./

RUN go mod download

COPY ./CasaOS-UserService/api ./api

# Generate Go code from OpenAPI specification
RUN mkdir -p codegen/user_service && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,server,spec -package codegen api/user-service/openapi.yaml > codegen/user_service/user_service_api.go
RUN mkdir -p codegen/message_bus && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -package message_bus https://raw.githubusercontent.com/IceWhaleTech/CasaOS-MessageBus/main/api/message_bus/openapi.yaml > codegen/message_bus/api.go


COPY ./CasaOS-UserService/build ./build
COPY ./CasaOS-UserService/cmd ./cmd
COPY ./CasaOS-UserService/common ./common
COPY ./CasaOS-UserService/model ./model
COPY ./CasaOS-UserService/pkg ./pkg
COPY ./CasaOS-UserService/route ./route
COPY ./CasaOS-UserService/service ./service
COPY ./CasaOS-UserService/main.go ./main.go

RUN go build -o casaos-user-service .

# default config
COPY ./CasaOS-UserService/build/sysroot/etc/casaos/user-service.conf.sample /etc/casaos/user-service.conf

############################################################################################################
# Build the Go binary for the MessageBus
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-message-bus

WORKDIR /app

COPY ./CasaOS-MessageBus/go.mod ./
COPY ./CasaOS-MessageBus/go.sum ./

RUN go mod download

COPY ./CasaOS-MessageBus/api ./api

# Generate Go code from OpenAPI specification
RUN mkdir -p codegen && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,server,spec -package codegen api/message_bus/openapi.yaml > codegen/message_bus_api.go

COPY ./CasaOS-MessageBus/build ./build
COPY ./CasaOS-MessageBus/cmd ./cmd
COPY ./CasaOS-MessageBus/common ./common
COPY ./CasaOS-MessageBus/config ./config
COPY ./CasaOS-MessageBus/model ./model
COPY ./CasaOS-MessageBus/repository ./repository
COPY ./CasaOS-MessageBus/route ./route
COPY ./CasaOS-MessageBus/service ./service
COPY ./CasaOS-MessageBus/main.go ./main.go

RUN go build -o casaos-message-bus .

# default config
COPY ./CasaOS-MessageBus/build/sysroot/etc/casaos/message-bus.conf.sample /etc/casaos/message-bus.conf

############################################################################################################
# Build the Go binary for the AppManagement
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-app-management

WORKDIR /app

COPY ./CasaOS-AppManagement/go.mod ./
COPY ./CasaOS-AppManagement/go.sum ./

RUN go mod download

COPY ./CasaOS-AppManagement/api ./api

# Generate Go code from OpenAPI specification
RUN mkdir -p codegen && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,server,spec -package codegen api/app_management/openapi.yaml > codegen/app_management_api.go
RUN mkdir -p codegen/message_bus && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package message_bus https://raw.githubusercontent.com/IceWhaleTech/CasaOS-MessageBus/main/api/message_bus/openapi.yaml > codegen/message_bus/api.go

    
COPY ./CasaOS-AppManagement/build ./build
COPY ./CasaOS-AppManagement/service ./service
COPY ./CasaOS-AppManagement/route ./route
COPY ./CasaOS-AppManagement/pkg ./pkg
COPY ./CasaOS-AppManagement/model ./model
COPY ./CasaOS-AppManagement/common ./common
COPY ./CasaOS-AppManagement/cmd ./cmd
COPY ./CasaOS-AppManagement/main.go ./main.go

RUN go build -o casaos-app-management .

# default config
COPY ./CasaOS-AppManagement/build/sysroot/etc/casaos/app-management.conf.sample /etc/casaos/app-management.conf
COPY ./CasaOS-AppManagement/build/sysroot/etc/casaos/env /etc/casaos/env

############################################################################################################
# Build the Go binary for the LocalStorage
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-local-storage

WORKDIR /app

COPY ./CasaOS-LocalStorage/go.mod ./
COPY ./CasaOS-LocalStorage/go.sum ./

RUN go mod download

COPY ./CasaOS-LocalStorage/api ./api

# Generate Go code from OpenAPI specification
RUN mkdir -p codegen && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,server,spec -package codegen api/local_storage/openapi.yaml > codegen/local_storage_api.go
RUN mkdir -p codegen/message_bus && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package message_bus https://raw.githubusercontent.com/IceWhaleTech/CasaOS-MessageBus/main/api/message_bus/openapi.yaml > codegen/message_bus/api.go

    
COPY ./CasaOS-LocalStorage/build ./build
COPY ./CasaOS-LocalStorage/cmd ./cmd
COPY ./CasaOS-LocalStorage/common ./common
COPY ./CasaOS-LocalStorage/drivers ./drivers
COPY ./CasaOS-LocalStorage/internal ./internal
COPY ./CasaOS-LocalStorage/model ./model
COPY ./CasaOS-LocalStorage/pkg ./pkg
COPY ./CasaOS-LocalStorage/route ./route
COPY ./CasaOS-LocalStorage/service ./service
COPY ./CasaOS-LocalStorage/main.go ./main.go
COPY ./CasaOS-LocalStorage/misc.go ./misc.go

RUN go build -o casaos-local-storage .

# default config
COPY ./CasaOS-LocalStorage/build/sysroot/etc/casaos/local-storage.conf.sample /etc/casaos/local-storage.conf

############################################################################################################
# Build the Go binary for the UI
############################################################################################################
FROM node:lts-slim AS builder-casaos-ui

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app
#same version as the one in CasaOS-UI package.json
RUN corepack enable && corepack prepare pnpm@9.0.6 --activate

COPY ./CasaOS-UI/package.json .
COPY ./CasaOS-UI/pnpm-lock.yaml .

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

COPY ./CasaOS-UI .
RUN pnpm run build

############################################################################################################
# Build the Go binary for the CasaOS Main
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-main

WORKDIR /app

COPY ./CasaOS/go.mod ./
COPY ./CasaOS/go.sum ./

RUN go mod download

COPY ./CasaOS/api ./api

# Generate Go code from OpenAPI specification
RUN mkdir -p codegen && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,server,spec -package codegen api/casaos/openapi.yaml > codegen/casaos_api.go
RUN mkdir -p codegen/message_bus && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package message_bus https://raw.githubusercontent.com/IceWhaleTech/CasaOS-MessageBus/main/api/message_bus/openapi.yaml > codegen/message_bus/api.go
    
COPY ./CasaOS/build ./build
COPY ./CasaOS/cmd ./cmd
COPY ./CasaOS/common ./common
COPY ./CasaOS/drivers ./drivers
COPY ./CasaOS/interfaces ./interfaces
COPY ./CasaOS/internal ./internal
COPY ./CasaOS/model ./model
COPY ./CasaOS/pkg ./pkg
COPY ./CasaOS/route ./route
COPY ./CasaOS/service ./service
COPY ./CasaOS/types ./types
COPY ./CasaOS/main.go ./main.go

RUN go build -o casaos-main .

# default config
COPY ./CasaOS/build/sysroot/etc/casaos/casaos.conf.sample /etc/casaos/casaos.conf

############################################################################################################
# Build the Go binary for the CasaOS Cli
############################################################################################################
FROM golang:1.21-alpine AS builder-casaos-cli

WORKDIR /app

COPY ./CasaOS-CLI/go.mod ./
COPY ./CasaOS-CLI/go.sum ./

#see main.go
RUN mkdir -p codegen/app_management && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package app_management https://raw.githubusercontent.com/IceWhaleTech/CasaOS-AppManagement/main/api/app_management/openapi.yaml > codegen/app_management/api.go
RUN mkdir -p codegen/casaos && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package casaos https://raw.githubusercontent.com/IceWhaleTech/CasaOS/main/api/casaos/openapi.yaml > codegen/casaos/api.go
RUN mkdir -p codegen/local_storage && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package local_storage https://raw.githubusercontent.com/IceWhaleTech/CasaOS-LocalStorage/main/api/local_storage/openapi.yaml > codegen/local_storage/api.go
RUN mkdir -p codegen/message_bus && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package message_bus https://raw.githubusercontent.com/IceWhaleTech/CasaOS-MessageBus/main/api/message_bus/openapi.yaml > codegen/message_bus/api.go
RUN mkdir -p codegen/user_service && \
    go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4 \
    -generate types,client -package user_service https://raw.githubusercontent.com/IceWhaleTech/CasaOS-UserService/main/api/user-service/openapi.yaml > codegen/user_service/api.go

RUN go mod download

COPY ./CasaOS-CLI/build ./build
COPY ./CasaOS-CLI/cmd ./cmd
COPY ./CasaOS-CLI/main.go ./main.go

RUN go build -o casaos-cli .

############################################################################################################
# Build the final image
############################################################################################################
FROM ubuntu:24.04

# Install required packages
RUN apt-get update && apt-get install -y wget gosu curl smartmontools parted ntfs-3g net-tools udevil samba cifs-utils mergerfs unzip openssh-server

# install docker https://docs.docker.com/engine/install/ubuntu/
RUN curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh


# Set environment variables
ENV GO_ENV=production
ENV REF_SEPARATOR=-
#ENV REF_SCHEME=https
#ENV REF_PORT=443


# Set the working directory for binaries
WORKDIR /usr/local/bin

# Copy all service binaries
COPY --from=builder-casaos-gateway /app/casaos-gateway .
COPY --from=builder-casaos-app-management /app/casaos-app-management .
COPY --from=builder-casaos-user-service /app/casaos-user-service .
COPY --from=builder-casaos-message-bus /app/casaos-message-bus .
COPY --from=builder-casaos-local-storage /app/casaos-local-storage .
COPY --from=builder-casaos-main /app/casaos-main .
COPY --from=builder-casaos-cli /app/casaos-cli .

# Copy config files
COPY ./conf/gateway/gateway.ini /etc/casaos/gateway.ini
COPY ./conf/app-management/app-management.conf /etc/casaos/app-management.conf
COPY --from=builder-casaos-app-management /etc/casaos/env /etc/casaos/env
COPY ./conf/user-service/user-service.conf /etc/casaos/user-service.conf
COPY ./conf/message-bus/message-bus.conf /etc/casaos/message-bus.conf
COPY ./conf/local-storage/local-storage.conf /etc/casaos/local-storage.conf
COPY ./conf/casaos/casaos.conf /etc/casaos/casaos.conf

# Copy UI files
COPY --from=builder-casaos-ui /app/build/sysroot/var/lib/casaos/ /var/lib/casaos/
COPY ./CasaOS-UI/register-ui-events.sh /usr/local/bin/register-ui-events.sh
RUN chmod +x /usr/local/bin/register-ui-events.sh

# Copy entrypoint
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port
EXPOSE 8080

# Define entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

