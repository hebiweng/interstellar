# Multi-stage build: compile on the build host and cross-compile the static Go
# binary for the requested target. This avoids running an amd64 compiler under
# QEMU on Apple Silicon and keeps the production host out of the build path.
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /relay . \
    && mkdir -p /relay-data \
    && chown 65532:65532 /relay-data

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /relay /app/relay
# A newly created named volume inherits this directory ownership. Without it,
# SQLite cannot create relay.db when the distroless nonroot user starts.
COPY --from=build --chown=65532:65532 /relay-data /data
EXPOSE 8080
VOLUME ["/data"]
ENV RELAY_DB_PATH=/data/relay.db
USER nonroot
ENTRYPOINT ["/app/relay"]
