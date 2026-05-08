/**
 * Plat bus proxy.
 *
 * Forwards SIRI requests to bustime.mta.info, injecting our MTA Bus Time API
 * key from `env.MTA_KEY` (set via `wrangler secret put MTA_KEY`). The key
 * never ships in the iOS app.
 *
 * Why this exists: anyone can extract a hard-coded API key from a shipped
 * iOS binary. With this proxy, the iOS app calls this Worker URL with no
 * key; the Worker injects the key server-side. If the proxy URL is abused,
 * we can rate-limit or rotate the key here without shipping a new app.
 *
 * Routing:
 *   /api/siri/stop-monitoring.json?MonitoringRef=…&LineRef=…&DirectionRef=…
 *     → https://bustime.mta.info/api/siri/stop-monitoring.json?<same>&key=$MTA_KEY
 *
 * Cache: SIRI publishes new vehicle positions every ~30s. We instruct
 * Cloudflare's edge cache to hold each unique (stop, route, direction)
 * response for 25s; this collapses duplicate requests across many users
 * standing at the same bus stop into a single upstream fetch.
 */

const ALLOWED_PATH_PREFIXES = ["/api/siri/"];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    if (!ALLOWED_PATH_PREFIXES.some(p => url.pathname.startsWith(p))) {
      return new Response("Not found", { status: 404, headers: CORS_HEADERS });
    }

    if (!env.MTA_KEY) {
      return new Response("Server misconfigured: MTA_KEY not set", {
        status: 500, headers: CORS_HEADERS,
      });
    }

    const upstream = new URL(`https://bustime.mta.info${url.pathname}${url.search}`);
    upstream.searchParams.set("key", env.MTA_KEY);
    // Strip any client-supplied key so we always use ours.
    if (url.searchParams.has("key")) upstream.searchParams.set("key", env.MTA_KEY);

    // Build a cache key that does NOT include our secret key. Otherwise the
    // edge cache would key on the secret and we'd never get hits.
    const cacheKey = new Request(
      url.toString(),                    // request URL without env.MTA_KEY
      { method: "GET" }
    );
    const cache = caches.default;

    let response = await cache.match(cacheKey);
    if (!response) {
      response = await fetch(upstream.toString(), {
        headers: { "Accept": "application/json" },
      });
      // Don't cache errors.
      if (response.ok) {
        const cached = new Response(response.body, response);
        cached.headers.set("Cache-Control", "public, max-age=25");
        cached.headers.set("X-Cache", "MISS");
        ctx.waitUntil(cache.put(cacheKey, cached.clone()));
        response = cached;
      }
    } else {
      response = new Response(response.body, response);
      response.headers.set("X-Cache", "HIT");
    }

    // Add CORS for safety, even though our iOS app doesn't need it.
    for (const [k, v] of Object.entries(CORS_HEADERS)) {
      response.headers.set(k, v);
    }
    return response;
  },
};
