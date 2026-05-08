# App Review notes — Plat

Paste the relevant sections into App Store Connect → App Privacy → Review Information when submitting.

## What the app does

Plat shows live MTA subway and bus arrivals at the saved stops a user
chooses. It is widget-first: users add their stops once and rely on home
screen and lock screen widgets to surface the next arrival without
opening the app.

There is no account system, no server holding user data, no analytics, no
third-party SDKs.

## Why we request location ("Always")

Plat is widget-driven. The whole product is "set up your stops once, never
open the app again, just glance at the widget." That UX requires the
widget to know which 3 of your saved stops are currently closest to you.

To do that without forcing the user to open the app every time they move,
we use Apple's `CLLocationManager.startMonitoringSignificantLocationChanges`,
which only fires when the user has moved roughly half a kilometer. That
API requires the "Always" location authorization.

We never sample precise location. We never log, transmit, or store the
user's coordinates anywhere. Location is read on-device, used to compute
distance to a list of points the user explicitly added, and discarded.

If the user grants only "When In Use", Plat still works — the closest-3
ranking simply doesn't update until the user reopens the app. We do not
nag.

## What data leaves the device

Two endpoints, both run by the Metropolitan Transportation Authority:

- `api-endpoint.mta.info` — GTFS-Realtime subway feeds (no API key
  required).
- A Cloudflare Worker we operate that forwards bus arrival queries to
  `bustime.mta.info`. The Worker's purpose is to inject the MTA Bus Time
  API key server-side so it doesn't ship in the iOS binary. The Worker
  does not log queries; we have no analytics.

Outbound requests contain a stop ID and route ID. They contain no user
identifier and no location.

## Demo instructions for the reviewer

1. Open the app. Onboarding sheet appears with a "Get Started" button.
2. Tap "Get Started". The system prompts for "When In Use" location.
3. Tap "Allow While Using App".
4. Tap the **Add** tab.
5. Pick the 6 line, choose "14 St – Union Sq", choose Downtown. Tap to
   save.
6. Pick the L line, choose "Bedford Av", choose 8 Av. Tap to save.
7. Return to the Saved tab. Both stops appear with distance.
8. Long-press an empty home screen area, add the **Plat** widget
   (Closest Stop or Next Arrivals).

To test the "Always" prompt: tap **Settings** → "Location: While Using" →
"Open Settings" → set to Always. Or save a third stop.

## Bus key in app

We do **not** ship the MTA Bus Time API key in the iOS binary. The key
lives only in our Cloudflare Worker (`workers/bus-proxy/` in the repo)
and is never accessible to clients.

## Source

Source code is at https://github.com/joshcohen90/Plat (private, can grant
read access to the reviewer on request).
