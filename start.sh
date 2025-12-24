#!/bin/bash
# Startup script that injects prompt from file into config.json at runtime
# and initializes/ingests RAG database

set -e

# Use Python to properly escape and inject the prompt (handles JSON escaping correctly)
python3 << 'PYTHON_SCRIPT'
import json
import sys
import os

# Read the prompt file
with open('/app/analytics-assistant-prompt.txt', 'r', encoding='utf-8') as f:
    prompt = f.read()

# Read the template
with open('/app/config.json.template', 'r', encoding='utf-8') as f:
    config = json.load(f)

# Inject the prompt (json.dumps handles all escaping)
config['llm']['customPrompt'] = prompt

# Write the final config
with open('/app/config.json', 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print("Config generated successfully", file=sys.stderr)
PYTHON_SCRIPT

# Initialize RAG database if it doesn't exist
RAG_DB="/app/knowledge.json"
if [ ! -f "$RAG_DB" ]; then
    echo "Initializing RAG database..." >&2
    slack-mcp-client --config /app/config.json --rag-provider simple --rag-db "$RAG_DB" --rag-init
fi

# Ingest PDF files into RAG database
# The simple provider seems to need individual file paths, not directories
echo "Ingesting PDF files into RAG..." >&2
INGESTED=0
for pdf_file in /app/rag-docs/*.pdf; do
    if [ -f "$pdf_file" ]; then
        echo "Ingesting $pdf_file..." >&2
        if slack-mcp-client --config /app/config.json --rag-provider simple --rag-db "$RAG_DB" --rag-ingest "$pdf_file" 2>&1; then
            echo "Successfully ingested $pdf_file" >&2
            INGESTED=1
        else
            echo "Warning: Failed to ingest $pdf_file" >&2
        fi
    fi
done

if [ $INGESTED -eq 0 ]; then
    echo "Warning: No PDF files were successfully ingested. RAG search may not be available." >&2
fi

# Start slack-mcp-client
exec slack-mcp-client --config /app/config.json --rag-provider simple --rag-db "$RAG_DB" --metrics-port 0
