# deploy/

Version-controlled copies of the production configuration on the KinSync VM. The VM is the
runtime; **this folder is the source of truth** — any change made on the VM must be copied back
here in the same session, and vice versa.

| File | Installed on the VM as | Runbook |
|---|---|---|
| `kinsync-api.service` | `/etc/systemd/system/kinsync-api.service` | [deploy-api](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/deploy-api.md) |
| `Caddyfile` | `/etc/caddy/Caddyfile` | [caddy-and-tls](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/caddy-and-tls.md) |
| `backup.sh` | used in place at `/opt/kinsync-api/deploy/backup.sh` (cron as `kinsync`) | [postgres-backup-restore](https://github.com/nithinvin/kinsync-docs/blob/main/runbooks/postgres-backup-restore.md) |

> **Not yet reconciled with the live VM** (created 2026-10-04 from the Phase-1 deployment guide).
> Before relying on these, diff them against the VM read-only, e.g.
> `diff <(ssh <admin-user>@kinsync.ddns.net cat /etc/caddy/Caddyfile) deploy/Caddyfile`.
> The guide's original backup script lived at `/opt/kinsync-api/backup.sh` with the password
> inline; `deploy/backup.sh` uses `~/.pgpass` instead — switching the VM over is a change that
> needs the team's go-ahead.

Never add secrets, `.env` files or the VM's IP address here — this repo is public.
