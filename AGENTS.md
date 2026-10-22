# CLAUDE.md

This file provides guidance to AI agents when working with code in this repository.

## What this is

A self-hosted stack that collects energy metrics from Tasmota smart plugs and
visualizes them. It is deployed via Docker Compose, not published as a package.
The only application code is a single Python bridge script (`dbexporter.py`);
everything else is configuration.

## Architecture

Data flows in one direction through four containers wired together in
`docker-compose.yaml` on a single bridge network:

```
Tasmota plugs → Mosquitto (MQTT) → dbexporter.py → InfluxDB → Grafana
```

- **Mosquitto** (`mosquitto/`) receives MQTT publishes from the plugs. Auth is
  required (`allow_anonymous false`); the password file is injected as a Docker
  secret at `/run/secrets/mqtt_passwd_file`, not baked into the image. The plugs
  publish on `tele/<location>/SENSOR`.
- **`dbexporter.py`** subscribes to `tele/+/SENSOR`, parses the JSON `ENERGY`
  object, and writes each whitelisted field (`MQTT_FIELDS`) to InfluxDB. The
  topic's second segment becomes the InfluxDB `location` tag; each energy field
  becomes its own measurement with a single `value` field. Messages whose
  measurement segment is `status` are ignored. All config comes from environment
  variables — the script raises on startup if any are missing.
- **InfluxDB 2.x** stores the points (bucket = `INFLUXDB_DATABASE`, Flux query
  language, 365d retention).
- **Grafana** renders `grafana/dashboard.json`. The dashboard is written to
  auto-detect new plugs by their `location` tag, so adding a plug requires no
  dashboard edits. Panels carry a `price_per_kWh` variable to localize cost.

Key consequence of this design: the MQTT topic name a plug publishes under (set
in the plug's own MQTT config, "Topic" field) is the identity that propagates
all the way to the dashboard. There is no device registry.

## Commands

Quality gate (required after any code change, per global rules):

```bash
prek run --files dbexporter.py    # runs ruff, mypy, black, bandit, etc.
```

`pre-commit run --all-files` is the equivalent if `prek` is unavailable. The CI
(`.github/workflows/cicd.yaml`) runs the same pre-commit hooks plus a Docker
build on every push and PR.

Run the stack (requires the env vars from the README to be exported, plus a
populated `mosquitto/passwd_file`):

```bash
docker compose up -d
docker compose logs -f dbexporter
```

Build just the bridge image:

```bash
docker build -t btschwertfeger/mqtt-bridge:latest .
```

## Conventions

- Python is managed with `uv`; never call `python`/`pip` directly. Runtime deps
  are only `paho-mqtt` and `influxdb-client` (installed directly in the
  `Dockerfile`, also listed in `requirements.txt`).
- Ruff is configured with a broad rule set and `--preview`; mypy runs in
  `strict` mode. Every source file carries a `Copyright (C) <year> Benjamin
Thomas Schwertfeger` header, which ruff's copyright check enforces.
- There is no test suite. "Verifying" a change to `dbexporter.py` means running
  the stack and confirming points land in InfluxDB / show up in Grafana.

## Gotchas

- `[tool.mypy] files = ["krakengridbot/*.py"]` in `pyproject.toml` is a stale
  copy-paste and does not match this repo. mypy is invoked via pre-commit with
  `.` as an explicit target, so the misconfigured `files` glob is bypassed —
  leave the pre-commit invocation intact if touching lint config.
- The InfluxDB admin token must be created in the InfluxDB UI after first boot,
  then fed back in via `INFLUXDB_TOKEN` (see README steps 5–6). It is not
  auto-generated into the environment.
- `tools/backup.sh` hardcodes `BASE_DIR=/home/ubuntu/...` and volume names
  prefixed `tasmota-plug-monitoring_` — it is meant to run on the deployment
  host via cron, not locally.
