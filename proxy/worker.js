// CareThread API Proxy — Cloudflare Worker
// Sits between your iOS app and the Anthropic API so your key never leaves the server.
//
// Environment variables (set in Cloudflare dashboard):
//   ANTHROPIC_API_KEY  — your sk-ant-... key
//   APP_SECRET         — a shared secret your iOS app sends to authenticate requests

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

export default {
  async fetch(request, env) {
    // Only allow POST
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    // Authenticate the request from your app
    const appSecret = request.headers.get("X-App-Secret");
    if (!appSecret || appSecret !== env.APP_SECRET) {
      return jsonError("Unauthorized", 401);
    }

    // Validate the API key is configured
    if (!env.ANTHROPIC_API_KEY) {
      return jsonError("Server misconfigured — missing API key", 500);
    }

    try {
      // Forward the request body to Anthropic
      const body = await request.text();

      const anthropicResponse = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": ANTHROPIC_VERSION,
        },
        body: body,
      });

      // Stream the response back to the app
      const responseBody = await anthropicResponse.text();

      return new Response(responseBody, {
        status: anthropicResponse.status,
        headers: {
          "Content-Type": "application/json",
          ...corsHeaders(),
        },
      });
    } catch (err) {
      return jsonError("Proxy error: " + err.message, 502);
    }
  },
};

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Secret",
  };
}
