# Slack + Analytics MCP Setup Guide

This guide will help you connect your `analytics-mcp` server to Slack, so your team can ask analytics questions directly in Slack conversations.

## Overview

**What we're building:**
- A Slack bot that understands natural language questions about Google Analytics
- The bot uses your existing `analytics-mcp` server to fetch real data
- No n8n or other middleware needed - just Slack → slack-mcp-client → analytics-mcp

**Architecture:**
```
Slack Message → slack-mcp-client (Slack bot + MCP client) → analytics-mcp → Google Analytics API
```

**Deployment Method:**
We'll use **Docker** to deploy to Render. Think of Docker as a "shipping container" that packages:
- The Go application (`slack-mcp-client`)
- Python runtime (needed for `analytics-mcp`)
- All configuration files
- Everything needed to run, all in one package

You don't need to understand Go or Docker deeply - Render will handle running the Docker container for you!

## Prerequisites

Before starting, make sure you have:

1. ✅ **Google Analytics credentials already set up** (you've already done this for Cursor)
   - You should have a `GOOGLE_APPLICATION_CREDENTIALS` file path
   - Your Google Cloud project has the Analytics APIs enabled

2. ✅ **Slack workspace admin access** (to create a Slack app)

3. ✅ **A computer/server to run the bot** (can be your local machine, or a cloud service like Render/Railway)

4. ✅ **GitHub account** (to host your code for Render deployment)

---

## Step 1: Install slack-mcp-client (For Local Testing)

**Skip this step if you're only deploying to Render** - Docker handles everything there.

**Quick explanation:**
- **Go** = The programming language that `slack-mcp-client` is written in
- **Docker** = A way to package everything (the Go app + Python + all dependencies) into one container

**For local testing, you need to install `slack-mcp-client`.** Choose one method:

### Option A: Install via Go (If you have Go installed)

```bash
go install github.com/tuannvm/slack-mcp-client@latest
```

Verify it worked:
```bash
slack-mcp-client --version
```

### Option B: Download Pre-built Binary (Easiest - Recommended)

1. Go to: https://github.com/tuannvm/slack-mcp-client/releases
2. Download the latest release for your operating system:
   - **macOS:** `slack-mcp-client_darwin_amd64.tar.gz` (or `_arm64` for Apple Silicon)
   - **Linux:** `slack-mcp-client_linux_amd64.tar.gz`
   - **Windows:** `slack-mcp-client_windows_amd64.zip`
3. Extract the archive
4. Move the binary to a location in your PATH, or run it directly:
   ```bash
   # macOS/Linux example:
   chmod +x slack-mcp-client
   sudo mv slack-mcp-client /usr/local/bin/
   
   # Or just run it from wherever you extracted it:
   ./slack-mcp-client --version
   ```

### Option C: Use Docker Locally (If you have Docker installed)

If you have Docker, you can test locally using the same Docker setup as Render:

```bash
# Build the Docker image
docker build -t slack-analytics-bot .

# Run it (you'll need to set up environment variables)
docker run --env-file .env slack-analytics-bot
```

**Note:** For production deployment on Render, we'll use Docker (Step 6), so you don't need to install anything locally if you skip testing.

---

## Step 2: Create a Slack App

You need to create a Slack app and get tokens for the bot to work.

### 2.1 Create the App

1. Go to https://api.slack.com/apps
2. Click **"Create New App"**
3. Choose **"From scratch"**
4. Give it a name (e.g., "Analytics Bot") and select your workspace
5. Click **"Create App"**

### 2.2 Enable Socket Mode

Socket Mode allows the bot to connect to Slack securely without exposing a public URL.

1. In your app settings, go to **"Socket Mode"** (left sidebar)
2. Toggle **"Enable Socket Mode"** to ON
3. Click **"Generate Token"** under "App-Level Tokens"
4. Name it (e.g., "socket-mode-token")
5. Add the scope: `connections:write`
6. Click **"Generate"**
7. **Copy this token** - it starts with `xapp-` (this is your `SLACK_APP_TOKEN`)

### 2.3 Add Bot Token Scopes

1. Go to **"OAuth & Permissions"** (left sidebar)
2. Scroll down to **"Scopes"** → **"Bot Token Scopes"**
3. Add these scopes:
   - `app_mentions:read` - To respond when mentioned
   - `chat:write` - To send messages
   - `channels:history` - To read channel messages (if you want it to work in channels)
   - `im:history` - To read direct messages
   - `im:write` - To send direct messages

### 2.4 Install App to Workspace

1. Still in **"OAuth & Permissions"**, scroll to the top
2. Click **"Install to Workspace"**
3. Review permissions and click **"Allow"**
4. **Copy the "Bot User OAuth Token"** - it starts with `xoxb-` (this is your `SLACK_BOT_TOKEN`)

### 2.5 (Optional) Add Slash Command

If you want a slash command like `/analytics`, you can add one:

1. Go to **"Slash Commands"** (left sidebar)
2. Click **"Create New Command"**
3. Command: `/analytics`
4. Request URL: (leave blank for now - Socket Mode handles this)
5. Short description: "Ask questions about Google Analytics"
6. Click **"Save"**

---

## Step 3: Configure MCP Server Connection

Now you need to tell `slack-mcp-client` how to connect to your `analytics-mcp` server.

### 3.1 Create MCP Configuration File

Create a file called `mcp-servers.json` in your project directory (same folder as this guide).

**Quick start:** Copy `mcp-servers.example.json` and customize it.

**For Render deployment (using Docker):**
```json
{
  "mcpServers": {
    "analytics-mcp": {
      "command": "pipx",
      "args": [
        "run",
        "analytics-mcp"
      ],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/etc/secrets/credentials.json",
        "GOOGLE_PROJECT_ID": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

**Important:** 
- For Render, we'll upload your credentials file separately (see Step 6)
- Replace `YOUR_PROJECT_ID` with your Google Cloud project ID
- The path `/app/credentials.json` is where the file will be in the Docker container

**For local testing (if you want to test before deploying):**
```json
{
  "mcpServers": {
    "analytics-mcp": {
      "command": "pipx",
      "args": [
        "run",
        "analytics-mcp"
      ],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/path/to/your/credentials.json",
        "GOOGLE_PROJECT_ID": "YOUR_PROJECT_ID"
      }
    }
  }
}
```
Replace `/path/to/your/credentials.json` with your actual local path.

**Alternative if you installed analytics-mcp differently:**

If you installed `analytics-mcp` via `pip install` instead of `pipx`, you might need:

```json
{
  "mcpServers": {
    "analytics-mcp": {
      "command": "python",
      "args": [
        "-m",
        "analytics_mcp.server"
      ],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/path/to/your/credentials.json",
        "GOOGLE_PROJECT_ID": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

Or if you have a virtual environment:

```json
{
  "mcpServers": {
    "analytics-mcp": {
      "command": "/path/to/venv/bin/analytics-mcp",
      "args": [],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/path/to/your/credentials.json",
        "GOOGLE_PROJECT_ID": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

---

## Step 4: Set Up Environment Variables

You need to configure Slack tokens and LLM provider settings.

### 4.1 Choose an LLM Provider

The `slack-mcp-client` needs an LLM to interpret natural language and call MCP tools. You can use:

- **OpenAI** (GPT-4, GPT-4o) - Recommended for best results
- **Anthropic** (Claude Sonnet, Opus)
- **Ollama** (if you're running a local model)

### 4.2 Create Environment File

Create a `.env` file in the same directory where you'll run the bot:

**For OpenAI:**
```bash
# Slack Tokens
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_APP_TOKEN=xapp-your-app-token-here

# OpenAI Configuration
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_MODEL=gpt-4o

# Logging
LOG_LEVEL=info
```

**For Anthropic:**
```bash
# Slack Tokens
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_APP_TOKEN=xapp-your-app-token-here

# Anthropic Configuration
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key-here
ANTHROPIC_MODEL=claude-sonnet-4-20250514

# Logging
LOG_LEVEL=info
```

**Replace:**
- `xoxb-your-bot-token-here` with your Bot User OAuth Token from Step 2.4
- `xapp-your-app-token-here` with your App-Level Token from Step 2.2
- `sk-your-openai-api-key-here` with your OpenAI API key (or Anthropic key if using Claude)

---

## Step 5: Test Locally

Before deploying, test that everything works on your local machine.

### 5.1 Verify analytics-mcp Works

First, make sure your `analytics-mcp` server works standalone:

```bash
# Test that analytics-mcp can run
pipx run analytics-mcp
```

If it errors, check your `GOOGLE_APPLICATION_CREDENTIALS` path is correct.

### 5.2 Run slack-mcp-client

**First, make sure you installed `slack-mcp-client` in Step 1.** If you skipped Step 1, go back and install it now.

In a terminal, navigate to where your `mcp-servers.json` and `.env` files are, then run:

```bash
# Load environment variables
source .env

# Run the client
slack-mcp-client --config ./mcp-servers.json
```

**If you get "command not found":**
- Make sure you installed `slack-mcp-client` (Step 1)
- If you downloaded a binary, make sure it's in your PATH or use the full path: `./slack-mcp-client --config ./mcp-servers.json`

You should see output like:
```
INFO Starting Slack MCP Client...
INFO Connected to Slack
INFO MCP server 'analytics-mcp' initialized
```

### 5.3 Test in Slack

1. Go to your Slack workspace
2. Find the bot in your apps (it should appear in the sidebar)
3. Send it a direct message or mention it in a channel: `@Analytics Bot how many visitors did vinyl.com have last week?`
4. The bot should respond with analytics data!

---

## Step 6: Deploy to Render (Recommended)

We'll use **Docker** to deploy everything to Render. This packages the Go app, Python, and all dependencies into one container.

### 6.1 Prepare Your Files

Make sure you have these files in your project directory:

- ✅ `mcp-servers.json` (created in Step 3)
- ✅ `Dockerfile` (already created in this repo)
- ✅ `render.yaml` (already created in this repo)

**Important:** Do NOT put your Google credentials file in the project directory or commit it to GitHub. You'll upload it directly to Render as a secret file in Step 6.3. Keep your credentials file somewhere safe on your local machine (you'll need to copy its contents later).

### 6.2 Create a GitHub Repository

1. **Create a new repository on GitHub:**
   - Go to https://github.com/new
   - Name it something like `slack-analytics-bot`
   - Make it **private** (since it will contain secrets)
   - Don't initialize with README (we already have files)

2. **Push your code to GitHub:**
   ```bash
   # In your project directory
   git init
   git add .
   git commit -m "Initial commit: Slack analytics bot setup"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/slack-analytics-bot.git
   git push -u origin main
   ```

   **Important security notes:**
   - Make sure your `.env` file is in `.gitignore` (it should be by default)
   - **Never commit your Google credentials JSON file to GitHub** - you'll upload it directly to Render as a secret file
   - Never commit any files with actual API keys or tokens
   - If you accidentally committed secrets, remove them from git history immediately

### 6.3 Create Render Account and Service

1. **Sign up for Render:**
   - Go to https://render.com
   - Sign up with your GitHub account (makes connecting repos easier)

2. **Create a new Web Service:**
   - Click **"New +"** → **"Web Service"**
   - Connect your GitHub account if prompted
   - Select your `slack-analytics-bot` repository
   - Render should auto-detect the `render.yaml` file

3. **Configure the service:**
   - **Name:** `slack-analytics-bot` (or whatever you prefer)
   - **Region:** Choose closest to you
   - **Branch:** `main`
   - **Runtime:** Docker (should be auto-detected)
   - **Dockerfile Path:** `Dockerfile` (should be auto-filled)
   - **Docker Context:** `.` (should be auto-filled)

4. **Add Environment Variables:**
   Click **"Add Environment Variable"** and add each of these:

   | Key | Value | Notes |
   |-----|-------|-------|
   | `SLACK_BOT_TOKEN` | `xoxb-...` | From Step 2.4 |
   | `SLACK_APP_TOKEN` | `xapp-...` | From Step 2.2 |
   | `OPENAI_API_KEY` | `sk-...` | Your OpenAI API key |
   | `OPENAI_MODEL` | `gpt-4o` | Or `gpt-4` if you prefer |
   | `LOG_LEVEL` | `info` | |
   | `GOOGLE_PROJECT_ID` | Your project ID | Your Google Cloud project ID |

   **Important:** Don't add `GOOGLE_APPLICATION_CREDENTIALS` as an env var - we'll upload the file separately.

5. **Upload Google Credentials File:**
   - In the Render dashboard, go to your service settings
   - Scroll to **"Environment"** section
   - Click **"Secret Files"** tab
   - Click **"Add Secret File"**
   - **Filename:** `credentials.json` (just the filename, no path!)
   - **Contents:** Paste the entire contents of your Google credentials JSON file
   - Click **"Save"**
   
   **Note:** Render will make this file available at `/etc/secrets/credentials.json` in your Docker container, which matches the path in your `mcp-servers.json` file.

6. **Deploy:**
   - Click **"Create Web Service"** at the bottom
   - Render will start building your Docker container (this takes 5-10 minutes the first time)
   - Watch the logs to see the build progress

### 6.4 Verify Deployment

Once deployed, check the logs:

1. In Render dashboard, click on your service
2. Go to **"Logs"** tab
3. You should see:
   ```
   INFO Starting Slack MCP Client...
   INFO Connected to Slack
   INFO MCP server 'analytics-mcp' initialized
   ```

4. **Test in Slack:**
   - Go to your Slack workspace
   - Send the bot a DM or mention it: `@Analytics Bot how many visitors did vinyl.com have last week?`
   - It should respond!

### 6.5 Troubleshooting Render Deployment

**Build fails:**
- Check the build logs for specific errors
- Make sure `Dockerfile` and `mcp-servers.json` are in the root of your repo
- Verify your GitHub repo is connected correctly

**Service crashes:**
- Check the runtime logs (not build logs)
- Verify all environment variables are set correctly
- Make sure the credentials file was uploaded to `/app/credentials.json`

**Bot doesn't respond:**
- Check that Socket Mode is enabled in Slack
- Verify `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN` are correct
- Check Render logs for connection errors

### Option B: Deploy to Railway

Similar to Render, Railway makes deployment easy:

1. Create account at https://railway.app
2. Create new project
3. Add environment variables
4. Deploy

### Option C: Run on a VPS/Server

If you have a server (DigitalOcean, AWS EC2, etc.):

1. SSH into your server
2. Install Go and dependencies
3. Copy your `mcp-servers.json` and `.env` files
4. Run as a systemd service (I can help create the service file)

---

## Step 7: Customize Bot Behavior (Optional)

You can customize how the bot responds by:

1. **Adding a system prompt** - Tell the bot which property to use by default (e.g., "When users ask about 'vinyl.com', use property ID 346765944")

2. **Configuring response format** - Make it format numbers nicely, add emojis, etc.

3. **Adding error handling** - Customize error messages

These customizations would require modifying the `slack-mcp-client` code or using its configuration options. Let me know if you want help with this!

---

## Troubleshooting

### Bot doesn't respond
- Check that Socket Mode is enabled in Slack app settings
- Verify `SLACK_APP_TOKEN` and `SLACK_BOT_TOKEN` are correct
- Check logs for errors

### "MCP server failed to initialize"
- Verify `analytics-mcp` works standalone: `pipx run analytics-mcp`
- Check that `GOOGLE_APPLICATION_CREDENTIALS` path in `mcp-servers.json` is correct
- Ensure Google Cloud project has Analytics APIs enabled

### "Invalid credentials" errors
- Verify your Google credentials file is valid
- Check that the credentials have the `analytics.readonly` scope
- Try re-running: `gcloud auth application-default login`

### Bot responds but with errors
- Check the logs - `slack-mcp-client` should show detailed error messages
- Verify the LLM API key is valid and has credits
- Try a simpler question first: "How many visitors did vinyl.com have yesterday?"

---

## Next Steps

Once it's working:

1. **Share with your team** - They can now ask analytics questions in Slack!
2. **Add more MCP servers** - You can add other MCP servers to the same bot
3. **Customize prompts** - Train the bot on your specific use cases

---

## Need Help?

If you run into issues:

1. Check the `slack-mcp-client` logs for error messages
2. Verify each component works independently:
   - Slack app tokens
   - analytics-mcp server
   - LLM API keys
3. Ask me! I can help debug specific errors.

---

## Quick Reference

### Files You Need

**For Render deployment:**
- `mcp-servers.json` - MCP server configuration (use `/app/credentials.json` path)
- `Dockerfile` - Already created in this repo ✅
- `render.yaml` - Already created in this repo ✅
- Google credentials JSON file - Upload to Render as secret file

**For local testing:**
- `mcp-servers.json` - MCP server configuration (use your local path)
- `.env` - Environment variables (Slack tokens, LLM keys)

### Commands

**Local testing (optional):**
```bash
# Test analytics-mcp
pipx run analytics-mcp

# Run slack-mcp-client (if you have Go installed)
source .env
slack-mcp-client --config ./mcp-servers.json
```

**Render deployment:**
- Just push to GitHub and Render handles everything via Docker! 🚀

### Important Tokens & Keys

**Slack (from https://api.slack.com/apps):**
- `SLACK_BOT_TOKEN` (xoxb-...) - From OAuth & Permissions → Bot User OAuth Token
- `SLACK_APP_TOKEN` (xapp-...) - From Socket Mode → App-Level Token

**LLM Provider:**
- `OPENAI_API_KEY` (sk-...) - From https://platform.openai.com/api-keys
- OR `ANTHROPIC_API_KEY` (sk-ant-...) - From https://console.anthropic.com/

**Google:**
- `GOOGLE_APPLICATION_CREDENTIALS` - Path to credentials file (`/app/credentials.json` in Docker)
- `GOOGLE_PROJECT_ID` - Your Google Cloud project ID

### Understanding Go vs Docker

- **Go** = Programming language that `slack-mcp-client` is written in (you don't need to install it)
- **Docker** = Packaging system that bundles everything together (Render uses it automatically)
- **What happens:** Docker packages the Go app + Python + all dependencies into one container that Render runs

### Render Free Tier Notes

- Render's free tier spins down after 15 minutes of inactivity
- Your bot will take ~30 seconds to wake up when someone messages it
- For always-on service, consider Render's paid tier ($7/month) or Railway's free tier

