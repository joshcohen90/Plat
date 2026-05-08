#!/usr/bin/env bash
# Downloads MTA static GTFS for the subway and derives a slim stops.json
# tailored for NextStop. Output: NextStop/Resources/stops.json
#
# stops.json schema: [{ "id": parent_stop_id, "name", "lines": [route_id...], "lat", "lon" }]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
OUT="$ROOT/NextStop/Resources/stops.json"

echo "→ tmp: $TMP"
cd "$TMP"

GTFS_URL="http://web.mta.info/developers/data/nyct/subway/google_transit.zip"
echo "→ downloading $GTFS_URL"
curl -fsSL "$GTFS_URL" -o gtfs.zip
unzip -qq gtfs.zip

# Required files: stops.txt, trips.txt, stop_times.txt, routes.txt
# stops.txt has parent stations (location_type=1) and platform stops (parent_station populated).
# We want one row per parent station with its serving lines.

python3 - <<'PY'
import csv, json, os, collections

def read(name):
    with open(name, newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

stops = read('stops.txt')
trips = read('trips.txt')
stop_times = read('stop_times.txt')

# Build platform_id -> parent_id
parent_of = {}
parents = {}
for s in stops:
    if s['location_type'] == '1':           # station
        parents[s['stop_id']] = s
    else:
        parent_of[s['stop_id']] = s.get('parent_station') or s['stop_id']

# trip_id -> route_id
route_of_trip = {t['trip_id']: t['route_id'] for t in trips}

# parent_id -> set(route_id)
routes_by_parent = collections.defaultdict(set)
for st in stop_times:
    plat = st['stop_id']
    parent = parent_of.get(plat, plat)
    rid = route_of_trip.get(st['trip_id'])
    if rid:
        routes_by_parent[parent].add(rid)

out = []
for pid, p in parents.items():
    lines = sorted(routes_by_parent.get(pid, []))
    if not lines:
        continue
    out.append({
        "id": pid,
        "name": p['stop_name'],
        "lines": lines,
        "lat": float(p['stop_lat']),
        "lon": float(p['stop_lon']),
    })

out.sort(key=lambda s: s['name'])
with open('out.json','w') as f:
    json.dump(out, f, separators=(',',':'))
print(f"wrote {len(out)} stations")
PY

mkdir -p "$(dirname "$OUT")"
mv out.json "$OUT"
echo "→ wrote $OUT"
echo "Add it to the NextStop target's Copy Bundle Resources phase if not already."
