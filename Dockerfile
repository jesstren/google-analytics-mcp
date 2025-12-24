# Install slack-mcp-client + analytics-mcp
FROM python:3.11-slim

# Install system dependencies including curl and tar for downloading binary
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Download and install slack-mcp-client binary
# Get the latest release version and download the binary
RUN RELEASE_URL=$(curl -s https://api.github.com/repos/tuannvm/slack-mcp-client/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d '"' -f 4) && \
    curl -L "$RELEASE_URL" -o /tmp/slack-mcp-client.tar.gz && \
    tar -xzf /tmp/slack-mcp-client.tar.gz -C /tmp && \
    find /tmp -name "slack-mcp-client" -type f -exec mv {} /usr/local/bin/slack-mcp-client \; && \
    chmod +x /usr/local/bin/slack-mcp-client && \
    rm -rf /tmp/slack-mcp-client* && \
    which slack-mcp-client

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
