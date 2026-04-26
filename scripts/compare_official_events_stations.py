#!/usr/bin/env python3
"""
Download official GMDB events/stations via API and compare with local SQLite.

Credentials are read from stdin or prompted interactively; they are never
written to disk. Outputs are CSV/Markdown comparison artifacts only.
"""

from __future__ import annotations

import csv
import getpass
import base64
import json
import os
import sqlite3
import sys
import time
from pathlib import Path
from typing import Any
from urllib import error, parse, request


ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "output" / "sqlite" / "nga_west3_20250919.sqlite"
OUT = ROOT / "output" / "official_api_compare"
BASE_URL = "https://www.gmdatabase.org"
LOGIN_URL = f"{BASE_URL}/users/login"
HEADERS = {"User-Agent": "NGA-West3-local-compare", "Accept": "application/json"}
ENV_FILE = ROOT / ".env"


def read_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            env[key] = value
    return env


def read_credentials() -> tuple[str, str]:
    env = read_env_file(ENV_FILE)
    username = os.environ.get("GMDB_USERNAME") or env.get("GMDB_USERNAME")
    password = os.environ.get("GMDB_PASSWORD") or env.get("GMDB_PASSWORD")
    if username and password:
        return username, password

    if not sys.stdin.isatty():
        lines = [line.rstrip("\n") for line in sys.stdin.readlines()]
        if len(lines) >= 2 and lines[0] and lines[1]:
            return lines[0], lines[1]
    username = input("GMDB username: ")
    password = getpass.getpass("GMDB password: ")
    return username, password


def login(username: str, password: str) -> str:
    auth = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
    headers = dict(HEADERS)
    headers["Authorization"] = f"Basic {auth}"
    payload = http_json(LOGIN_URL, headers=headers)
    token = payload.get("token")
    if not token:
        raise RuntimeError(f"Login succeeded but token missing. Payload keys: {list(payload)}")
    return token


def http_json(url: str, headers: dict[str, str]) -> Any:
    req = request.Request(url, headers=headers, method="GET")
    try:
        with request.urlopen(req, timeout=120) as response:
            text = response.read().decode("utf-8")
            return json.loads(text)
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} for {url}: {body[:500]}") from exc


def normalize_payload(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("data", "results", "records", "items"):
            if isinstance(payload.get(key), list):
                return payload[key]
    raise RuntimeError(f"Unexpected API JSON shape: {type(payload).__name__}: {repr(payload)[:500]}")


def fetch_endpoint(endpoint: str, token: str, limit: int = 1000, pause: float = 0.05) -> list[dict[str, Any]]:
    headers = dict(HEADERS)
    headers["Authorization"] = f"Bearer {token}"
    page = 1
    rows: list[dict[str, Any]] = []
    sort_fields = {
        "events": "event_id",
        "stations": "station_id",
        "motions": "motion_id",
        "eventTypes": "event_type_id",
        "networks": "network_id",
    }
    while True:
        url = f"{BASE_URL}/{endpoint}"
        params = {"limit": limit, "page": page, "sort": sort_fields.get(endpoint, "id")}
        payload = http_json(url + "?" + parse.urlencode(params), headers=headers)
        batch = normalize_payload(payload)
        if not batch:
            break
        rows.extend(batch)
        print(f"{endpoint}: page={page} rows={len(rows)}", flush=True)
        if len(batch) < limit:
            break
        page += 1
        time.sleep(pause)
    return rows


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    keys: list[str] = []
    seen = set()
    for row in rows:
        for key in row.keys():
            if key not in seen:
                seen.add(key)
                keys.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=keys, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def local_ids(table: str, id_col: str) -> set[int]:
    conn = sqlite3.connect(DB)
    try:
        return {int(row[0]) for row in conn.execute(f"SELECT {id_col} FROM {table}")}
    finally:
        conn.close()


def local_rows(table: str, id_col: str) -> dict[int, dict[str, Any]]:
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    try:
        return {int(row[id_col]): dict(row) for row in conn.execute(f"SELECT * FROM {table}")}
    finally:
        conn.close()


def write_id_diff(name: str, official_rows: list[dict[str, Any]], local_table: str, id_col: str) -> dict[str, Any]:
    official_map = {int(row[id_col]): row for row in official_rows if row.get(id_col) not in (None, "")}
    local_map = local_rows(local_table, id_col)
    official_ids = set(official_map)
    local_id_set = set(local_map)
    only_official = sorted(official_ids - local_id_set)
    only_local = sorted(local_id_set - official_ids)
    common = sorted(official_ids & local_id_set)

    write_csv(OUT / f"{name}_only_official.csv", [official_map[i] for i in only_official])
    write_csv(OUT / f"{name}_only_local.csv", [local_map[i] for i in only_local])

    return {
        "name": name,
        "official_count": len(official_ids),
        "local_count": len(local_id_set),
        "common_count": len(common),
        "only_official_count": len(only_official),
        "only_local_count": len(only_local),
        "only_official_first20": only_official[:20],
        "only_local_first20": only_local[:20],
    }


def summarize_events(official_rows: list[dict[str, Any]]) -> dict[str, Any]:
    local = local_rows("events", "event_id")
    official_by_id = {int(r["event_id"]): r for r in official_rows if r.get("event_id") not in (None, "")}
    only_official = sorted(set(official_by_id) - set(local))
    countries: dict[str, int] = {}
    event_types: dict[str, int] = {}
    for i in only_official:
        row = official_by_id[i]
        countries[str(row.get("event_country") or "")] = countries.get(str(row.get("event_country") or ""), 0) + 1
        event_types[str(row.get("event_type_id") or "")] = event_types.get(str(row.get("event_type_id") or ""), 0) + 1
    return {
        "only_official_by_country": sorted(countries.items(), key=lambda kv: (-kv[1], kv[0])),
        "only_official_by_event_type_id": sorted(event_types.items(), key=lambda kv: (-kv[1], kv[0])),
    }


def summarize_stations(official_rows: list[dict[str, Any]]) -> dict[str, Any]:
    local = local_rows("stations", "station_id")
    official_by_id = {int(r["station_id"]): r for r in official_rows if r.get("station_id") not in (None, "")}
    only_official = sorted(set(official_by_id) - set(local))
    networks: dict[str, int] = {}
    has_site = 0
    for i in only_official:
        row = official_by_id[i]
        networks[str(row.get("network_id") or "")] = networks.get(str(row.get("network_id") or ""), 0) + 1
        if row.get("site_id") not in (None, ""):
            has_site += 1
    return {
        "only_official_by_network_id": sorted(networks.items(), key=lambda kv: (-kv[1], kv[0]))[:30],
        "only_official_with_site_id": has_site,
    }


def summarize_motions(
    official_motions: list[dict[str, Any]],
    official_events: list[dict[str, Any]],
    official_stations: list[dict[str, Any]],
    official_event_types: list[dict[str, Any]],
    official_networks: list[dict[str, Any]],
) -> dict[str, Any]:
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    try:
        local_motion_ids = {int(row[0]) for row in conn.execute("SELECT motion_id FROM motions")}
        local_event_ids = {int(row[0]) for row in conn.execute("SELECT event_id FROM events")}
        local_station_ids = {int(row[0]) for row in conn.execute("SELECT station_id FROM stations")}
        local_motion_map = {
            int(row["motion_id"]): dict(row)
            for row in conn.execute("SELECT motion_id, event_id, station_id FROM motions")
        }
    finally:
        conn.close()

    official_event_map = {
        int(row["event_id"]): row
        for row in official_events
        if row.get("event_id") not in (None, "")
    }
    official_station_map = {
        int(row["station_id"]): row
        for row in official_stations
        if row.get("station_id") not in (None, "")
    }
    event_type_map = {
        str(row.get("event_type_id")): row.get("event_type") or str(row.get("event_type_id"))
        for row in official_event_types
    }
    network_map = {
        str(row.get("network_id")): " / ".join(
            part
            for part in [row.get("network_code"), row.get("network_name")]
            if part
        )
        for row in official_networks
    }

    official_motion_map = {
        int(row["motion_id"]): row
        for row in official_motions
        if row.get("motion_id") not in (None, "")
    }
    only_official_ids = sorted(set(official_motion_map) - local_motion_ids)
    only_local_ids = sorted(local_motion_ids - set(official_motion_map))

    by_event_status: dict[str, int] = {}
    by_station_status: dict[str, int] = {}
    by_event_type: dict[str, int] = {}
    by_event_country: dict[str, int] = {}
    by_station_network: dict[str, int] = {}
    by_event_id: dict[str, int] = {}
    by_station_id: dict[str, int] = {}

    for motion_id in only_official_ids:
        motion = official_motion_map[motion_id]
        event_id = int(motion["event_id"]) if str(motion.get("event_id") or "").lstrip("-").isdigit() else None
        station_id = int(motion["station_id"]) if str(motion.get("station_id") or "").lstrip("-").isdigit() else None
        event_status = "event_in_local" if event_id in local_event_ids else "event_official_only"
        station_status = "station_in_local" if station_id in local_station_ids else "station_official_only"
        by_event_status[event_status] = by_event_status.get(event_status, 0) + 1
        by_station_status[station_status] = by_station_status.get(station_status, 0) + 1

        event = official_event_map.get(event_id or -1, {})
        event_type_id = str(event.get("event_type_id") or "")
        event_type = event_type_map.get(event_type_id, event_type_id or "(blank)")
        by_event_type[event_type] = by_event_type.get(event_type, 0) + 1
        country = str(event.get("event_country") or "(blank)")
        by_event_country[country] = by_event_country.get(country, 0) + 1
        event_label = f"{event_id}: {event.get('event_name') or ''}".strip()
        by_event_id[event_label] = by_event_id.get(event_label, 0) + 1

        station = official_station_map.get(station_id or -1, {})
        network_id = str(station.get("network_id") or "")
        network = network_map.get(network_id, network_id or "(blank)")
        by_station_network[network] = by_station_network.get(network, 0) + 1
        station_label = f"{station_id}: {station.get('station_code') or station.get('station_name') or ''}".strip()
        by_station_id[station_label] = by_station_id.get(station_label, 0) + 1

    local_only_by_event: dict[str, int] = {}
    local_only_by_station: dict[str, int] = {}
    for motion_id in only_local_ids:
        motion = local_motion_map[motion_id]
        event_label = str(motion.get("event_id"))
        station_label = str(motion.get("station_id"))
        local_only_by_event[event_label] = local_only_by_event.get(event_label, 0) + 1
        local_only_by_station[station_label] = local_only_by_station.get(station_label, 0) + 1

    def sorted_items(d: dict[str, int]) -> list[tuple[str, int]]:
        return sorted(d.items(), key=lambda kv: (-kv[1], kv[0]))

    return {
        "only_official_by_event_status": sorted_items(by_event_status),
        "only_official_by_station_status": sorted_items(by_station_status),
        "only_official_by_event_type": sorted_items(by_event_type),
        "only_official_by_event_country": sorted_items(by_event_country),
        "only_official_by_station_network": sorted_items(by_station_network),
        "only_official_top_events": sorted_items(by_event_id)[:50],
        "only_official_top_stations": sorted_items(by_station_id)[:50],
        "only_local_by_event_id": sorted_items(local_only_by_event)[:50],
        "only_local_by_station_id": sorted_items(local_only_by_station)[:50],
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    username, password = read_credentials()
    print("Authenticating...", flush=True)
    token = login(username, password)
    print("Downloading events...", flush=True)
    events = fetch_endpoint("events", token)
    print("Downloading stations...", flush=True)
    stations = fetch_endpoint("stations", token)
    print("Downloading motions...", flush=True)
    motions = fetch_endpoint("motions", token)
    print("Downloading event types and networks...", flush=True)
    event_types = fetch_endpoint("eventTypes", token)
    networks = fetch_endpoint("networks", token)

    write_csv(OUT / "official_events.csv", events)
    write_csv(OUT / "official_stations.csv", stations)
    write_csv(OUT / "official_motions.csv", motions)
    write_csv(OUT / "official_event_types.csv", event_types)
    write_csv(OUT / "official_networks.csv", networks)

    event_diff = write_id_diff("events", events, "events", "event_id")
    station_diff = write_id_diff("stations", stations, "stations", "station_id")
    motion_diff = write_id_diff("motions", motions, "motions", "motion_id")
    event_summary = summarize_events(events)
    station_summary = summarize_stations(stations)
    motion_summary = summarize_motions(motions, events, stations, event_types, networks)

    summary = {
        "events": event_diff,
        "stations": station_diff,
        "motions": motion_diff,
        "event_summary": event_summary,
        "station_summary": station_summary,
        "motion_summary": motion_summary,
    }
    (OUT / "comparison_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    md = [
        "# Official GMDB Events/Stations Difference Summary",
        "",
        "## Counts",
        "",
        "| Dataset | Official API unique IDs | Local SQLite unique IDs | Common | Official only | Local only |",
        "|---|---:|---:|---:|---:|---:|",
        f"| events | {event_diff['official_count']} | {event_diff['local_count']} | {event_diff['common_count']} | {event_diff['only_official_count']} | {event_diff['only_local_count']} |",
        f"| stations | {station_diff['official_count']} | {station_diff['local_count']} | {station_diff['common_count']} | {station_diff['only_official_count']} | {station_diff['only_local_count']} |",
        f"| motions | {motion_diff['official_count']} | {motion_diff['local_count']} | {motion_diff['common_count']} | {motion_diff['only_official_count']} | {motion_diff['only_local_count']} |",
        "",
        "## First 20 Official-Only IDs",
        "",
        f"- events: {event_diff['only_official_first20']}",
        f"- stations: {station_diff['only_official_first20']}",
        f"- motions: {motion_diff['only_official_first20']}",
        "",
        "## First 20 Local-Only IDs",
        "",
        f"- events: {event_diff['only_local_first20']}",
        f"- stations: {station_diff['only_local_first20']}",
        f"- motions: {motion_diff['only_local_first20']}",
        "",
        "## Official-Only Events by Country",
        "",
    ]
    md.extend([f"- {country or '(blank)'}: {count}" for country, count in event_summary["only_official_by_country"][:30]])
    md.extend(["", "## Official-Only Events by event_type_id", ""])
    md.extend([f"- {etype or '(blank)'}: {count}" for etype, count in event_summary["only_official_by_event_type_id"]])
    md.extend(["", "## Official-Only Stations by network_id", ""])
    md.extend([f"- {network or '(blank)'}: {count}" for network, count in station_summary["only_official_by_network_id"]])
    md.extend(["", "## Official-Only Motions by Event Status", ""])
    md.extend([f"- {status}: {count}" for status, count in motion_summary["only_official_by_event_status"]])
    md.extend(["", "## Official-Only Motions by Station Status", ""])
    md.extend([f"- {status}: {count}" for status, count in motion_summary["only_official_by_station_status"]])
    md.extend(["", "## Official-Only Motions by Event Type", ""])
    md.extend([f"- {label}: {count}" for label, count in motion_summary["only_official_by_event_type"]])
    md.extend(["", "## Official-Only Motions by Event Country", ""])
    md.extend([f"- {label}: {count}" for label, count in motion_summary["only_official_by_event_country"][:30]])
    md.extend(["", "## Official-Only Motions by Station Network", ""])
    md.extend([f"- {label}: {count}" for label, count in motion_summary["only_official_by_station_network"][:30]])
    md.extend(["", "## Output Files", ""])
    md.extend(
        [
            "- `official_events.csv`",
            "- `official_stations.csv`",
            "- `official_motions.csv`",
            "- `events_only_official.csv`",
            "- `events_only_local.csv`",
            "- `stations_only_official.csv`",
            "- `stations_only_local.csv`",
            "- `motions_only_official.csv`",
            "- `motions_only_local.csv`",
            "- `comparison_summary.json`",
        ]
    )
    (OUT / "events_stations_diff_summary.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
