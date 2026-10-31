#!/usr/bin/env python3
"""Hanoi GTFS (hanoi_gtfs_md.zip) -> flutter/assets/stop_order.json.

Usage: python3 -I tool/gtfs_to_stop_order.py <hanoi_gtfs_md.zip> <out.json> [--updated YYYY-MM-DD]

- routes.txt route_short_name is like `n/a-39_1`: drop `n/a-`; the trailing `_1`/`_2` is the direction,
  the rest is the ref (39, 03A, BRT01). If it is empty, route_id (same form) is used.
  route_long_name is a placeholder and is not used.
- One trip per route and direction from trips.txt, preferring trip_ids containing `_MD_`.
- Stops in stop_sequence order from stop_times.txt; coordinates from stops.txt.
- stop_name is a placeholder (`STOP_01_1_S1`), so names are written empty and the app matches by coordinates.
- No times, calendars or shapes. Fails if the output exceeds 1 MB.
"""
import csv
import io
import json
import re
import sys
import zipfile
from datetime import date

MAX_BYTES = 1024 * 1024


def read(zf, name):
    with zf.open(name) as f:
        return list(csv.DictReader(io.TextIOWrapper(f, encoding='utf-8-sig')))


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    src, out = argv[1], argv[2]
    updated = None
    if '--updated' in argv:
        updated = argv[argv.index('--updated') + 1]
    with zipfile.ZipFile(src) as zf:
        if updated is None:
            # The newest file date inside the archive.
            updated = max(date(*i.date_time[:3]) for i in zf.infolist()).isoformat()
        routes = read(zf, 'routes.txt')
        trips = read(zf, 'trips.txt')
        stops = {s['stop_id']: s for s in read(zf, 'stops.txt')}
        chosen = {}  # route_id -> trip_id
        for t in trips:
            current = chosen.get(t['route_id'])
            if current is None or ('_MD_' in t['trip_id'] and '_MD_' not in current):
                chosen[t['route_id']] = t['trip_id']
        wanted = set(chosen.values())
        times = {}
        with zf.open('stop_times.txt') as f:
            for row in csv.DictReader(io.TextIOWrapper(f, encoding='utf-8-sig')):
                if row['trip_id'] in wanted:
                    times.setdefault(row['trip_id'], []).append((int(row['stop_sequence']), row['stop_id']))

    out_routes = []
    skipped = []
    for r in routes:
        short = (r.get('route_short_name') or '').strip()
        short = re.sub(r'^n/a-', '', short)
        if not short:
            # Some copies leave route_short_name empty; route_id has the same `39_1` form.
            short = r['route_id'].strip()
        m = re.fullmatch(r'(.+)_([12])', short)
        trip = chosen.get(r['route_id'])
        if not m or trip is None or trip not in times:
            skipped.append(r['route_id'])
            continue
        ref, direction = m.group(1), m.group(2)
        seq = [stops[sid] for _, sid in sorted(times[trip]) if sid in stops]
        if len(seq) < 2:
            skipped.append(r['route_id'])
            continue
        out_routes.append({
            'ref': ref,
            'direction': direction,
            'stops': [
                {'name': '', 'latitude': round(float(s['stop_lat']), 6), 'longitude': round(float(s['stop_lon']), 6)}
                for s in seq
            ],
        })

    out_routes.sort(key=lambda x: (x['ref'], x['direction']))
    for x in out_routes:
        del x['direction']
    text = json.dumps({'updated': updated, 'routes': out_routes}, ensure_ascii=False, separators=(',', ':'))
    data = text.encode('utf-8')
    if len(data) > MAX_BYTES:
        sys.exit(f'output is {len(data)} bytes (> 1 MB)')
    with open(out, 'wb') as f:
        f.write(data)
    refs = sorted({x['ref'] for x in out_routes})
    print(f'updated={updated} directions={len(out_routes)} refs={len(refs)} bytes={len(data)} skipped={len(skipped)}')
    if skipped:
        print('skipped route_ids:', ' '.join(skipped[:20]), '...' if len(skipped) > 20 else '')


if __name__ == '__main__':
    main(sys.argv)
