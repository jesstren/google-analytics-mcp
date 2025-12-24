# Multi-stage build for slack-mcp-client + analytics-mcp
FROM golang:1.21-alpine AS builder

# Install slack-mcp-client
WORKDIR /build
RUN go install github.com/tuannvm/slack-mcp-client@latest

# Final stage with Python for analytics-mcp
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the Go binary from builder
COPY --from=builder /go/bin/slack-mcp-client /usr/local/bin/slack-mcp-client

# Install pipx and analytics-mcp
RUN pip install --no-cache-dir pipx && \
    pipx ensurepath && \
    pipx install analytics-mcp

# Set working directory
WORKDIR /app

# Copy configuration files
COPY mcp-servers.json /app/mcp-servers.json

# Make sure pipx binaries are in PATH
ENV PATH="/root/.local/bin:${PATH}"

# Run the slack-mcp-client
CMD ["slack-mcp-client", "--config", "/app/mcp-servers.json"]
