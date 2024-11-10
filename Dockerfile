############################################################################################################
# Build the Go binary for the Gateway
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-gateway

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-gateway .

# default config
COPY ./CasaOS-Gateway/build/sysroot/etc/casaos/gateway.ini.sample /etc/casaos/gateway.ini
RUN mkdir -p /var/run/casaos/ && echo -n "{}" >> /var/run/casaos/routes.json

############################################################################################################
# Build the Go binary for the User Service
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-user-service

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-user-service .

# default config
COPY ./CasaOS-UserService/build/sysroot/etc/casaos/user-service.conf.sample /etc/casaos/user-service.conf

############################################################################################################
# Build the Go binary for the MessageBus
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-message-bus

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-message-bus .

# default config
COPY ./CasaOS-MessageBus/build/sysroot/etc/casaos/message-bus.conf.sample /etc/casaos/message-bus.conf

############################################################################################################
# Build the Go binary for the AppManagement
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-app-management

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-app-management .

# default config
COPY ./CasaOS-AppManagement/build/sysroot/etc/casaos/app-management.conf.sample /etc/casaos/app-management.conf
COPY ./CasaOS-AppManagement/build/sysroot/etc/casaos/env /etc/casaos/env

############################################################################################################
# Build the Go binary for the LocalStorage
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-local-storage

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-local-storage .

# default config
COPY ./CasaOS-LocalStorage/build/sysroot/etc/casaos/local-storage.conf.sample /etc/casaos/local-storage.conf

############################################################################################################
# Build the Go binary for the UI
############################################################################################################
FROM --platform=$BUILDPLATFORM node:16 AS builder-casaos-ui

ENV NODE_ENV=production

WORKDIR /app

COPY ./CasaOS-UI/package.json .
COPY ./CasaOS-UI/yarn.lock .
COPY ./CasaOS-UI/.yarnrc.yml .
COPY ./CasaOS-UI/.yarn ./.yarn
COPY ./CasaOS-UI/main/package.json ./main/package.json

RUN yarn install --network-timeout 1000000

COPY ./CasaOS-UI .

RUN yarn build

############################################################################################################
# Build the Go binary for the CasaOS Main
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-main

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-main .

# default config
COPY ./CasaOS/build/sysroot/etc/casaos/casaos.conf.sample /etc/casaos/casaos.conf

############################################################################################################
# Build the Go binary for the CasaOS Cli
############################################################################################################
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder-casaos-cli

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

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o casaos-cli .

############################################################################################################
# Build the final image
############################################################################################################

FROM debian:bookworm-slim AS casaos

ARG TARGETARCH
ARG VERSION_ARG="0.0"
ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN set -eu \
  && apt-get update -y \
  && apt-get --no-install-recommends -y install jq tini gnupg wget curl smartmontools parted ntfs-3g net-tools udevil samba cifs-utils mergerfs unzip openssh-server ca-certificates \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update -y \
  && apt-get --no-install-recommends -y install docker-ce-cli docker-compose-plugin \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && echo "$VERSION_ARG" > /run/version

# Set environment variables
ENV GO_ENV=production

ENV REF_PORT=
ENV REF_DOMAIN=
ENV REF_SEPARATOR=-
ENV REF_SCHEME=http

# Set the Current Working Directory inside the container
WORKDIR /root/

# Copy the Pre-built binary file and configuration files from the gateway
COPY --from=builder-casaos-gateway /app/casaos-gateway .
#COPY --from=builder-casaos-gateway /etc/casaos/gateway.ini /etc/casaos/gateway.ini
COPY ./conf/gateway/gateway.ini /etc/casaos/gateway.ini
COPY --from=builder-casaos-gateway /var/run/casaos/routes.json /var/run/casaos/routes.json

# Copy the Pre-built binary file and configuration files from the app-management
COPY --from=builder-casaos-app-management /app/casaos-app-management .
#COPY --from=builder-casaos-app-management /etc/casaos/app-management.conf /etc/casaos/app-management.conf
COPY ./conf/app-management/app-management.conf /etc/casaos/app-management.conf
COPY --from=builder-casaos-app-management /etc/casaos/env /etc/casaos/env

# Copy the Pre-built binary file from the user-service
COPY --from=builder-casaos-user-service /app/casaos-user-service .
#COPY --from=builder-casaos-user-service /etc/casaos/user-service.conf /etc/casaos/user-service.conf
COPY ./conf/user-service/user-service.conf /etc/casaos/user-service.conf

# Copy the Pre-built binary file and configuration files from the message-bus
COPY --from=builder-casaos-message-bus /app/casaos-message-bus .
#COPY --from=builder-casaos-message-bus /etc/casaos/message-bus.conf /etc/casaos/message-bus.conf
COPY ./conf/message-bus/message-bus.conf /etc/casaos/message-bus.conf

# Copy the Pre-built binary file and configuration files from the local-storage
COPY --from=builder-casaos-local-storage /app/casaos-local-storage .
#COPY --from=builder-casaos-local-storage /etc/casaos/local-storage.conf /etc/casaos/local-storage.conf
COPY ./conf/local-storage/local-storage.conf /etc/casaos/local-storage.conf

#COPY ui /var/lib/casaos/www and other initial files
COPY --from=builder-casaos-ui /app/build/sysroot/var/lib/casaos/ /var/lib/casaos/
COPY --chmod=755 ./CasaOS-UI/main/register-ui-events.sh ./register-ui-events.sh

# Copy CasaOS-AppStore
#COPY ./appstore-data/main/build/sysroot/var/lib/casaos/appstore/default.new /var/lib/casaos/appstore/default
COPY ./CasaOS-AppStore/Apps /var/lib/casaos/appstore/default/Apps
COPY ./CasaOS-AppStore/*.json /var/lib/casaos/appstore/default/

# Copy the Pre-built binary file and configuration files from the main
COPY --from=builder-casaos-main /app/casaos-main .
COPY --from=builder-casaos-main /app/build/sysroot/usr/share/casaos/shell/ /usr/share/casaos/shell
RUN chmod +x /usr/share/casaos/shell/*.sh

COPY ./conf/casaos/casaos.conf /etc/casaos/casaos.conf

# Copy the Pre-built binary file from the cli
COPY --from=builder-casaos-cli /app/casaos-cli .
COPY --chmod=755 ./entrypoint.sh ./entrypoint.sh

# Expose port 8080 to the outside world
EXPOSE 8080

# Command to run the executable
ENTRYPOINT ["/usr/bin/tini", "-s", "/root/entrypoint.sh"]
