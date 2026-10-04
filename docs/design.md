# kinsync-api — Backend Design Notes

System-level architecture, data model and API contract are in
[kinsync-docs/design](https://github.com/nithinvin/kinsync-docs/tree/main/design). This file only
covers how *this* codebase is organised.

## Module layout (Phase-1)

```
main.py                  App factory (create_app) + lifespan: settings, logging, DB engine
internal/
├── config.py            Settings (pydantic-settings) — env/.env, validated at startup
├── logging_config.py    Root logger setup from LOG_LEVEL
├── database.py          Async SQLAlchemy engine factory, check_connection(), DatabaseConnectionError
└── health.py            Router: GET /health, GET /health/db
tests/                   pytest; SQLite in-memory via aiosqlite, FastAPI TestClient
qa_tools/                check_sanity.sh + static-analysis configs
deploy/                  systemd unit, Caddyfile, backup script (copies of what runs on the VM)
```

Module dependencies are enforced by `tach` (`tach.toml`): `main` → `internal`; `internal` depends
on nothing local; `tests` → both.

## Key design decisions

- **App factory + lifespan.** `create_app()` builds the app; the DB engine is created in the
  lifespan handler and stored on `app.state.db_engine`, disposed on shutdown. Tests build their
  own app with a different `DATABASE_URL`.
- **Fail fast on config.** `DATABASE_URL` has no default; a misconfigured deploy fails at startup,
  not at request time.
- **Loopback Postgres without client TLS.** For `postgresql` URLs the engine sets `ssl=disable`.
  Postgres is only reached over loopback, and asyncpg's default `prefer` mode probes
  `~/.postgresql/postgresql.crt`, which raises `PermissionError` under systemd's
  `ProtectHome=true` (fix `e5f0ca1`).
- **`/health/db` hides causes from clients.** Returns `503 {"detail": "Database unreachable"}`;
  the underlying error is logged server-side only.

## Coming in Phase-3

SQLAlchemy models + Alembic migrations, auth dependency (device bearer tokens), pairing and
heartbeat routers — see
[roadmap](https://github.com/nithinvin/kinsync-docs/blob/main/plan/roadmap.md). Add new routers
under `internal/` and update this layout and `tach.toml` together.
