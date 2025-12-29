# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies to increase build time
RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum* ./

# Download dependencies (this takes time)
RUN go mod download
RUN go mod verify

# Copy source code
COPY *.go ./

# Build the application with additional flags for optimization
# CGO_ENABLED=1 for sqlite support
# Disable optimizations and inlining to increase build time
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo \
    -gcflags="all=-N -l" \
    -ldflags="-w -s" \
    -o hello-world .

# Run additional compilation steps to increase CPU time
RUN go build -race -o hello-world-race .
RUN go vet ./...
RUN go build -gcflags="-m -m" . 2>&1 | head -n 100

# Final stage - smaller image
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/hello-world .

# Expose port for the web server
EXPOSE 8080

# Run the binary
CMD ["./hello-world"]