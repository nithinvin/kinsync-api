# Development Guide

## 1. Prerequisites

- Python 3.11+ (ruff targets `py311`).
- PostgreSQL for running against a real DB locally (optional — unit tests use in-memory SQLite
  via `aiosqlite`).

## 2. Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt   # includes requirements.txt
pip install ruff                      # used by check_sanity.sh, not yet pinned in requirements-dev.txt
cp .env.example .env
```

### Configuration (`internal/config.py`)

Loaded from environment variables or `.env`; validated at startup (fails fast if missing).

| Variable | Required | Example |
|---|---|---|
| `DATABASE_URL` | yes | `postgresql+asyncpg://kinsync:changeme@localhost:5432/kinsync` |
| `LOG_LEVEL` | no (`INFO`) | `DEBUG` |

`.env` is gitignored. Never commit real credentials.

## 3. Run

```bash
uvicorn main:app --reload
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/health/db
```

Interactive OpenAPI docs: `http://127.0.0.1:8000/docs`. Keep them consistent with the
[API contract](https://github.com/nithinvin/kinsync-docs/blob/main/design/api-contract.md).

## 4. Tests and quality gates

```bash
python3 -m pytest tests/            # tests only
qa_tools/check_sanity.sh            # full gate (what CONSTITUTION.md §II requires)
```

`check_sanity.sh` runs, in order: ruff (format + `--fix`), bandit, pylint, mypy (main, internal,
tests) → then radon (cc, mi), cognitive complexity (max 15), cohesion (advisory), tach (module
boundaries), vulture (advisory), and pytest with branch coverage **≥ 90%** on `internal/`.
Coverage HTML: `qa_tools/coverage_html_report/index.html`.

Configs live in `qa_tools/static_analysis/` (`pylintrc`, `pylintrc_tests`, `mypy_config`,
`mypy_config_tests`, `ruff.toml`) and `qa_tools/.coveragerc`. Module boundaries: `tach.toml`.

## 5. Deploying

Not from here — follow the
[deploy-api runbook](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/deploy-api.md).
Production config files are versioned in [`../deploy/`](../deploy/).
