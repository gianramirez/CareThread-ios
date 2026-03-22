# CareThread API Proxy — Deployment Guide

This Cloudflare Worker sits between CareThread and the Anthropic API so your API key never ships in the app.

## How It Works

```
User's iPhone → Your Cloudflare Worker → Anthropic API
                (adds your API key)
```

Users never see or need an API key. Your key lives only on Cloudflare.

## Setup (10 minutes)

### 1. Create a Cloudflare account
Go to https://dash.cloudflare.com/sign-up (free tier is fine).

### 2. Install Wrangler CLI
```bash
npm install -g wrangler
wrangler login
```

### 3. Deploy the worker
From this `proxy/` folder:
```bash
cd proxy
wrangler deploy
```
It will print your worker URL, something like:
`https://carethread-proxy.YOUR_SUBDOMAIN.workers.dev`

### 4. Set your secrets
```bash
wrangler secret put ANTHROPIC_API_KEY
# Paste your sk-ant-... key when prompted

wrangler secret put APP_SECRET
# Create any random string (e.g. generate one with: openssl rand -hex 32)
# This prevents random people from using your proxy
```

### 5. Update the iOS app
In `ClaudeAPIService.swift`, update `AppConfig`:
```swift
static let apiBaseURL = "https://carethread-proxy.YOUR_SUBDOMAIN.workers.dev"
static let appSecret = "same-random-string-from-step-4"
```

Then clear the `Secrets.swift` API key (no longer needed):
```swift
static let anthropicAPIKey = ""
```

### 6. Test
Build and run. Log a day — it should work exactly the same, but now through your proxy.

## Cost

- **Cloudflare Workers**: Free for 100,000 requests/day
- **Anthropic API**: ~$0.003-0.015 per request depending on prompt length
- A typical user generates ~10-20 API calls per week (daily parses + reports)

## Security Notes

- The `APP_SECRET` header prevents unauthorized access to your proxy
- For stronger auth, you could add Firebase Auth or Sign in with Apple and validate tokens in the worker
- Never commit your API key or app secret to git
