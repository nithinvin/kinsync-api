# CLAUDE.md — kinsync-api

FastAPI backend for **KinSync** (passive daily-pattern monitor for elderly people living alone;
VIT Chennai BACSE291 Innovative Design Project, AY 2026–27). Production:
`https://kinsync.ddns.net` — endpoints `/health`, `/health/db`.

## Sibling repos (cloned side by side)

| Repo | Local path | Use for |
|---|---|---|
| kinsync-docs | `../kinsync-docs` | Requirements, design, **API contract**, roadmap/status, runbooks |
| kinsync-android | `../kinsync-android` | Android client that calls this API |

Before feature work, read `../kinsync-docs/plan/roadmap.md` (current phase),
the matching `../kinsync-docs/plan/phase-N.md`, and `../kinsync-docs/design/api-contract.md`.

## Hard rules

- **Never commit or push without the user's explicit go-ahead.**
- **No `Co-Authored-By` / AI attribution trailer** in commit messages.
- **Repo is public:** never write the VM IP, SSH usernames, passwords, `.env` contents or tokens
  into any file.
- **Production VM** (Hetzner, Ubuntu 26.04): never change anything on it without asking. Read-only
  inspection only. Procedures: `../kinsync-docs/runbooks/`.
- Follow [CONSTITUTION.md](CONSTITUTION.md) and `../kinsync-docs/engineering/common-principles.md`.
  Privacy: no raw activity data may ever be stored, logged or accepted by this service.
- Endpoint changes: update `../kinsync-docs/design/api-contract.md` **first**.

## Commands

```bash
source .venv/bin/activate              # create with: python3 -m venv .venv && pip install -r requirements-dev.txt
uvicorn main:app --reload              # run locally (needs .env with DATABASE_URL)
python3 -m pytest tests/               # tests (SQLite in-memory, no Postgres needed)
python3 -m pytest tests/test_health.py::test_health_returns_ok   # single test
qa_tools/check_sanity.sh               # full quality gate — must pass before work is done
```

Gate = ruff, bandit, pylint, mypy, radon, cognitive complexity ≤ 15, tach, vulture, pytest with
branch coverage ≥ 90% on `internal/`.

## Layout

- `main.py` — `create_app()` factory + lifespan (settings → logging → DB engine on `app.state`)
- `internal/` — `config.py` (pydantic-settings), `database.py`, `health.py` (router),
  `logging_config.py`
- `tests/` — pytest, `TestClient`, `monkeypatch.setenv('DATABASE_URL', 'sqlite+aiosqlite:///:memory:')`
- `deploy/` — systemd unit, Caddyfile, backup script mirrored from the VM
- `tach.toml` — module boundaries; update when adding modules
- Details: [docs/design.md](docs/design.md), [docs/development.md](docs/development.md)

## Code style (from CONSTITUTION.md)

PEP 8, 100-char lines, single quotes, imports grouped stdlib / third-party / local, docstrings
with `Raises:` sections, specific exception classes (never bare `Exception`), `logging` not
`print`, no secrets in logs. Tests cover happy, error, edge and malformed-input paths.

## After finishing work

Update in `../kinsync-docs`: `plan/phase-N.md` (deliverable status + SHA), `specs/traceability.md`,
and `design/api-contract.md` if endpoints changed. If `deploy/` changed, note that the VM needs
the same change (and ask before applying it).
