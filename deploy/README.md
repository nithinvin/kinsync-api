# deploy/

Version-controlled copies of the production configuration on the KinSync VM. The VM is the
runtime; **this folder is the source of truth** — any change made on the VM must be copied back
here in the same session, and vice versa.

| File | Installed on the VM as | Runbook |
|---|---|---|
| `kinsync-api.service` | `/etc/systemd/system/kinsync-api.service` | [deploy-api](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/deploy-api.md) |
| `Caddyfile` | `/etc/caddy/Caddyfile` | [caddy-and-tls](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/caddy-and-tls.md) |
| `backup.sh` | used in place at `/opt/kinsync-api/deploy/backup.sh` (cron as `kinsync`) | [postgres-backup-restore](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/postgres-backup-restore.md) |

Checked against the live VM (read-only) on 2026-10-04:
- `kinsync-api.service` — identical.
- `Caddyfile` — the VM file has Caddy's stock comment header above the same site block;
  functionally identical.
- `backup.sh` — **not installed on the VM yet** (no backup directory existed); installation
  postponed by team decision, tracked in the kinsync-docs roadmap ops backlog. It uses Postgres
  *peer* authentication, so no password is stored anywhere. Install steps:
  [postgres-backup-restore runbook](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/postgres-backup-restore.md).

Never add secrets, `.env` files or the VM's IP address here — this repo is public.
