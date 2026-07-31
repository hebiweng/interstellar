# Multi-stage build: compile in golang, run on distroless (static binary, no cgo).
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /relay .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /relay /app/relay
EXPOSE 8080
VOLUME ["/data"]
ENV RELAY_DB_PATH=/data/relay.db
USER nonroot
ENTRYPOINT ["/app/relay"]
