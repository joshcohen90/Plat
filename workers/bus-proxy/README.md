# Plat bus proxy

Cloudflare Worker that proxies bustime.mta.info SIRI requests, injecting our
MTA Bus Time API key from a server-side secret. Keeps the key out of the
shipped iOS binary.

## Why

Anyone can extract a hardcoded API key from an iOS app's IPA. If a few people
do that, your MTA quota gets eaten and the real users hit rate limits. The
fix: never put the key on devices. The app calls this Worker; the Worker
injects the key.

Side benefit: edge caching collapses duplicate requests (e.g. five people
standing at the same bus stop) into a single upstream call.

## Deploy

One-time setup:

```bash
cd workers/bus-proxy
npm i -g wrangler
wrangler login          # opens browser, sign in to Cloudflare
wrangler secret put MTA_KEY
# paste your bustime.mta.info key when prompted
wrangler deploy
```

After `wrangler deploy` succeeds, you'll get a URL like:
`https://plat-bus-proxy.<account>.workers.dev`

Copy it into `Plat/AppConfig.swift` as `busProxyURL`, then `xcodegen
generate` and rebuild the iOS app.

## Smoke test

```bash
curl 'https://plat-bus-proxy.<account>.workers.dev/api/siri/stop-monitoring.json?MonitoringRef=400069&LineRef=MTA%20NYCT_M15&DirectionRef=0'
```

Should return JSON with `Siri.ServiceDelivery.StopMonitoringDelivery`. The
response will have an `X-Cache: MISS` header on the first call and `HIT` on
repeats within 25 seconds.

## Updating

Edit `src/index.js` and run `wrangler deploy` again. The iOS app does not
need to be re-released for proxy changes.

## Rotation

If your MTA key ever needs to be rotated:
```bash
wrangler secret put MTA_KEY
wrangler deploy
```
The iOS app keeps working — the URL doesn't change.

## Cost

Free tier: 100k requests/day. A single iOS user opens the widget ≤a few
times per hour and saves ≤10 bus stops, so realistic cap is ~thousands of
users before hitting the limit.
