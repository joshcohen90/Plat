# Plat Privacy Policy

_Last updated: May 8, 2026_

Plat is an iOS app for showing the next train and bus arrivals at the
saved transit stops you choose. This document explains what data the app
uses, how it's used, and what is **not** collected.

## Plain-English summary

- We use your iPhone's location to show which of your saved stops are
  closest to you. That's it.
- We do not have a server. We do not have an account system.
- We do not collect, transmit, sell, or share your data.
- We do not use any analytics or tracking SDKs.
- The list of stops you save is stored locally on your device.

## Location

Plat requests location access ("When In Use" first, then optionally
"Always") to:

- Identify the **3 closest** of your saved transit stops.
- Update that ranking as you move between neighborhoods so the widget
  reflects your current area.

We use **significant location changes** (Apple's low-power location API)
in the background. Your precise location is read on-device only. It is
never stored, transmitted, or shared with us or any third party.

If you decline location access, the app still works — it simply uses the
order in which you saved your stops instead of distance.

## Data stored on your device

- Your list of saved transit stops (line, station, direction, location).
- Your manual stop groupings ("combine these into one location").
- A cached snapshot of upcoming arrivals so the widget renders quickly.

These are stored in the app's private storage and shared with the
Plat widget via an Apple App Group. Nothing leaves your device.

## Network requests

Plat makes HTTPS requests to:

- **api-endpoint.mta.info** — the Metropolitan Transportation Authority's
  GTFS-Realtime feeds for subway arrival times.
- **bustime.mta.info** — MTA Bus Time SIRI feeds for bus arrival times.

These requests include the saved stop ID and route you're checking
arrivals for, plus an API key for the Bus Time service. They do not
include your location, identity, or any data that could be used to
identify you. The requests are made directly from your device to MTA;
nothing is proxied through us.

## Children

Plat does not knowingly collect data from children, because it does
not collect data from anyone.

## Third-party services

The only third party the app contacts is the Metropolitan Transportation
Authority (MTA), to fetch transit data. MTA's terms are published at
https://api.mta.info/.

## Changes

If this policy changes, the new version will be posted at the same URL.
The "Last updated" date at the top will reflect the change.

## Contact

For privacy questions or any other contact, open an issue at https://github.com/joshcohen90/Plat/issues.

(Replace this placeholder with your real support address before publishing.)
