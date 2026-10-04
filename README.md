# kinsync-api

FastAPI backend for **KinSync** — a passive daily-pattern monitor for elderly people living
alone. It stores pairings and derived heartbeats and acts as the dead-man's switch that alerts
caregivers when an elder's phone goes quiet. Raw activity data never reaches this service.

Live at **`https://kinsync.ddns.net`** (Hetzner VM, Caddy → Uvicorn → PostgreSQL).

## Project docs

Requirements, design, roadmap and runbooks live in
**[nithinvin/kinsync-docs](https://github.com/nithinvin/kinsync-docs)**:
[specs](https://github.com/nithinvin/kinsync-docs/tree/main/specs) ·
[design](https://github.com/nithinvin/kinsync-docs/tree/main/design) ·
[API contract](https://github.com/nithinvin/kinsync-docs/blob/main/design/api-contract.md) ·
[roadmap & status](https://github.com/nithinvin/kinsync-docs/blob/main/plan/roadmap.md) ·
[runbooks](https://github.com/nithinvin/kinsync-docs/tree/main/runbooks).
The Android client is [nithinvin/kinsync-android](https://github.com/nithinvin/kinsync-android).

This repo's own docs:
- [`docs/development.md`](docs/development.md) — local setup, running, tests, QA gates
- [`docs/design.md`](docs/design.md) — module layout and backend-internal design notes
- [`deploy/`](deploy/) — version-controlled systemd unit, Caddyfile, backup script
- [`CONSTITUTION.md`](CONSTITUTION.md) — coding/quality/security standards for this repo

## Current status: Phase-1 done (Review II)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness → `{"status": "ok"}` |
| GET | `/health/db` | PostgreSQL connectivity → `{"status": "ok"}` or `503` |

Next: Phase-2 is Android-only (on-device data collection); backend pairing, auth and heartbeat come in Phase-3 — see the
[roadmap](https://github.com/nithinvin/kinsync-docs/blob/main/plan/roadmap.md).

## Quick start

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env            # set DATABASE_URL
uvicorn main:app --reload       # http://127.0.0.1:8000/docs
qa_tools/check_sanity.sh        # lint, types, complexity, tests + coverage
```

## Tech stack

Python 3.11+, FastAPI, Uvicorn, SQLAlchemy 2 (async) + asyncpg, pydantic-settings, PostgreSQL.

## License

Apache-2.0 — see [LICENSE](LICENSE).
