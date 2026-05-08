#!/usr/bin/env bash
# Downloads MTA bus static GTFS for all 5 boroughs + MTA Bus Company,
# derives a slim bus_stops.json. One row per (route, direction, stop).
#
# Output: Plat/Resources/bus_stops.json
# Schema: [{ code, name, lat, lon, line (route_id), directionID (0|1), headsign }]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
OUT="$ROOT/Plat/Resources/bus_stops.json"

# Borough zips. As of 2024–2025, paths under web.mta.info/developers/data/.
URLS=(
  "http://web.mta.info/developers/data/nyct/bus/google_transit_bronx.zip"
  "http://web.mta.info/developers/data/nyct/bus/google_transit_brooklyn.zip"
  "http://web.mta.info/developers/data/nyct/bus/google_transit_manhattan.zip"
  "http://web.mta.info/developers/data/nyct/bus/google_transit_queens.zip"
  "http://web.mta.info/developers/data/nyct/bus/google_transit_staten_island.zip"
  "http://web.mta.info/developers/data/busco/google_transit.zip"
)

i=0
for url in "${URLS[@]}"; do
  i=$((i+1))
  d="$TMP/feed$i"
  mkdir -p "$d"
  echo "→ [$i/${#URLS[@]}] $url"
  curl -fsSL "$url" -o "$d/g.zip"
  ( cd "$d" && unzip -qq g.zip )
done

python3 - "$TMP" "$OUT" <<'PY'
import csv, json, os, sys, collections

tmp = sys.argv[1]
out_path = sys.argv[2]

def read(path):
    with open(path, newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

# Aggregate across feeds. Keys: (route_id, direction_id) -> headsign
# stops: stop_id -> (name, lat, lon)
# served: (route_id, direction_id) -> set(stop_id)
stops = {}
served = collections.defaultdict(set)
headsigns = {}

for feed_dir in sorted(d for d in os.listdir(tmp) if d.startswith("feed")):
    base = os.path.join(tmp, feed_dir)
    files = {n: os.path.join(base, n) for n in ("stops.txt","trips.txt","stop_times.txt","routes.txt") if os.path.exists(os.path.join(base, n))}
    if not files.get("stops.txt") or not files.get("trips.txt") or not files.get("stop_times.txt"):
        continue

    for s in read(files["stops.txt"]):
        sid = s["stop_id"]
        if sid not in stops:
            stops[sid] = (s["stop_name"], float(s["stop_lat"]), float(s["stop_lon"]))

    trip_route = {}
    trip_dir = {}
    trip_head = {}
    for t in read(files["trips.txt"]):
        trip_route[t["trip_id"]] = t["route_id"]
        trip_dir[t["trip_id"]] = int(t.get("direction_id") or "0")
        trip_head[t["trip_id"]] = t.get("trip_headsign","")

    # Pick the most common headsign per (route,direction)
    head_counts = collections.Counter()
    for tid, route in trip_route.items():
        d = trip_dir.get(tid, 0)
        h = trip_head.get(tid, "")
        if h:
            head_counts[(route, d, h)] += 1

    pair_best = {}
    for (route, d, h), c in head_counts.most_common():
        if (route, d) not in pair_best:
            pair_best[(route, d)] = h
    for k, v in pair_best.items():
        headsigns.setdefault(k, v)

    for st in read(files["stop_times.txt"]):
        tid = st["trip_id"]
        route = trip_route.get(tid)
        if route is None: continue
        d = trip_dir.get(tid, 0)
        served[(route, d)].add(st["stop_id"])

records = []
for (route, d), stop_ids in served.items():
    head = headsigns.get((route, d), "")
    for sid in stop_ids:
        if sid not in stops: continue
        name, lat, lon = stops[sid]
        records.append({
            "code": sid,
            "name": name,
            "lat": lat,
            "lon": lon,
            "line": route,
            "directionID": d,
            "headsign": head,
        })

# Stable order: by route, direction, then stop name
records.sort(key=lambda r: (r["line"], r["directionID"], r["name"]))

os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w") as f:
    json.dump(records, f, separators=(',',':'))
print(f"wrote {len(records)} (route,direction,stop) rows from {len(stops)} unique stops")
PY

echo "→ wrote $OUT"
echo "Add it to the Plat target's Copy Bundle Resources phase."
