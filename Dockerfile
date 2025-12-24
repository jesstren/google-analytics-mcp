# Install slack-mcp-client + analytics-mcp
FROM python:3.11-slim

# Install system dependencies including curl and tar for downloading binary
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Download and install slack-mcp-client binary
# Download a specific known-good release for Linux amd64
RUN curl -L "https://github.com/tuannvm/slack-mcp-client/releases/download/v2.8.3/slack-mcp-client_2.8.3_linux_amd64.tar.gz" -o /tmp/slack-mcp-client.tar.gz && \
    tar -xzf /tmp/slack-mcp-client.tar.gz -C /tmp && \
    find /tmp -name "slack-mcp-client" -type f -exec mv {} /usr/local/bin/slack-mcp-client \; && \
    chmod +x /usr/local/bin/slack-mcp-client && \
    rm -rf /tmp/slack-mcp-client*

# Install analytics-mcp directly with pip (simpler than pipx in Docker)
RUN pip install --no-cache-dir analytics-mcp

# Set working directory
WORKDIR /app

# Copy configuration files
COPY mcp-servers.json /app/mcp-servers.json

# Run the slack-mcp-client
# Note: --system-prompt flag not available in v2.8.3, will work without custom prompt
CMD ["slack-mcp-client", "--config", "/app/mcp-servers.json"]
