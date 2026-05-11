FROM golang:1.24-bookworm AS build

WORKDIR /src

COPY server/go.mod server/go.sum ./server/

WORKDIR /src/server
RUN go mod download

COPY server/ ./

ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /out/sprout-server ./cmd/server

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -u 10001 -r -m -d /app appuser

WORKDIR /app

COPY --from=build /out/sprout-server /app/sprout-server

RUN mkdir -p /data \
    && chown -R appuser:appuser /app /data

USER appuser

EXPOSE 8080

CMD ["/app/sprout-server"]
