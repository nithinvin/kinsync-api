# KinSync Backend — Phase-1 Deployment Guide (`deployment.md`)

**Scope:** Deploying the Phase-1 backend slice — a health-check-only FastAPI service backed by
PostgreSQL — onto a self-hosted Hetzner VM running Ubuntu 26.04, fronted by Caddy for automatic
HTTPS. Companion documents: `spec.md` (requirements), `plan.md` (architecture & phased roadmap).

This guide assumes a fresh Hetzner Cloud VM (CX22-class, Ubuntu 26.04) and a domain/subdomain you
control that you can point at the VM's public IP (e.g. `api.kinsync.example.com`).

---

## 1. Provision the VM

1. Create a Hetzner Cloud server: **Ubuntu 26.04**, CX22 (or larger), in a region close to your
   users.
2. Add your SSH public key during creation (Hetzner Cloud console → SSH Keys). Do **not** enable
   password login.
3. Note the server's public IPv4/IPv6 address.
4. In your DNS provider, create an `A` (and `AAAA`, if using IPv6) record pointing your chosen
   subdomain (e.g. `api.kinsync.example.com`) at the VM's IP. Caddy needs this to issue a
   Let's Encrypt certificate later.

## 2. Initial Server Hardening

SSH in as `root` (or the sudo user created at provisioning) and run:

```bash
ssh root@<vm-ip>

# Create a non-root deploy user with sudo access
adduser kinsync
usermod -aG sudo kinsync
rsync --archive --chown=kinsync:kinsync ~/.ssh /home/kinsync

# Switch to the new user for the rest of setup
su - kinsync
```

### 2.1 SSH: key-only login

Edit `/etc/ssh/sshd_config` (`sudo nano /etc/ssh/sshd_config`) and set:

```
PasswordAuthentication no
PermitRootLogin no
```

Restart SSH:

```bash
sudo systemctl restart ssh
```

### 2.2 Firewall (`ufw`)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (ACME challenge / redirect to HTTPS)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
sudo ufw status verbose
```

### 2.3 `fail2ban`

```bash
sudo apt update
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

### 2.4 Automated security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

Confirm `/etc/apt/apt.conf.d/20auto-upgrades` has both `Update-Package-Lists` and
`Unattended-Upgrade` set to `"1"`.

## 3. Install PostgreSQL

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
```

Create the database and an application role with a strong, unique password:

```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE kinsync WITH LOGIN PASSWORD 'CHANGE_ME_STRONG_PASSWORD';
CREATE DATABASE kinsync OWNER kinsync;
SQL
```

By default PostgreSQL listens on `localhost` only (`listen_addresses = 'localhost'` in
`postgresql.conf`) — leave this as-is since the API runs on the same VM; do not expose Postgres's
port 5432 externally (it is not opened in the `ufw` rules above).

Verify connectivity:

```bash
psql "postgresql://kinsync:CHANGE_ME_STRONG_PASSWORD@localhost:5432/kinsync" -c 'SELECT 1;'
```

## 4. Install Python and the Application

```bash
sudo apt install -y python3-venv python3-pip git
sudo mkdir -p /opt/kinsync-api
sudo chown kinsync:kinsync /opt/kinsync-api

git clone <this-repo-url> /opt/kinsync-api
cd /opt/kinsync-api

python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate
```

### 4.1 Configure environment

```bash
cp .env.example .env
```

Edit `/opt/kinsync-api/.env` and set:

```
DATABASE_URL=postgresql+asyncpg://kinsync:CHANGE_ME_STRONG_PASSWORD@localhost:5432/kinsync
LOG_LEVEL=INFO
```

Restrict permissions since this file holds a credential:

```bash
chmod 600 /opt/kinsync-api/.env
```

## 5. Run the API as a systemd Service

Create `/etc/systemd/system/kinsync-api.service`:

```ini
[Unit]
Description=KinSync API (FastAPI/Uvicorn)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=kinsync
Group=kinsync
WorkingDirectory=/opt/kinsync-api
EnvironmentFile=/opt/kinsync-api/.env
ExecStart=/opt/kinsync-api/.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=5

# Basic sandboxing
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
```

Enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kinsync-api.service
sudo systemctl status kinsync-api.service
```

The app listens only on `127.0.0.1:8000` — it is not reachable from the internet directly; Caddy
(next step) is the only public entry point.

Check logs:

```bash
journalctl -u kinsync-api.service -f
```

## 6. Install Caddy (TLS reverse proxy)

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
  sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

Edit `/etc/caddy/Caddyfile`:

```
api.kinsync.example.com {
    reverse_proxy 127.0.0.1:8000
}
```

Replace `api.kinsync.example.com` with your real subdomain. Reload Caddy:

```bash
sudo systemctl reload caddy
```

Caddy automatically requests and renews a Let's Encrypt certificate for the domain the first time
it is reloaded, provided DNS already points at the VM and ports 80/443 are open.

## 7. Verify the Deployment

```bash
curl -s https://api.kinsync.example.com/health
# {"status":"ok"}

curl -s https://api.kinsync.example.com/health/db
# {"status":"ok"}
```

If `/health/db` returns a `503`, check `journalctl -u kinsync-api.service` for the logged
connectivity error and confirm the `DATABASE_URL` credential and PostgreSQL service status.

## 8. Nightly Backups (`pg_dump`)

Create `/opt/kinsync-api/backup.sh`:

```bash
#!/bin/bash
set -euo pipefail
BACKUP_DIR=/var/backups/kinsync
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump "postgresql://kinsync:CHANGE_ME_STRONG_PASSWORD@localhost:5432/kinsync" \
  | gzip > "$BACKUP_DIR/kinsync_${TIMESTAMP}.sql.gz"
find "$BACKUP_DIR" -name '*.sql.gz' -mtime +14 -delete
```

```bash
chmod 700 /opt/kinsync-api/backup.sh
sudo crontab -u kinsync -e
```

Add a nightly line (e.g. 02:15 daily):

```
15 2 * * * /opt/kinsync-api/backup.sh
```

## 9. Deploying Updates

```bash
cd /opt/kinsync-api
git pull
source .venv/bin/activate
pip install -r requirements.txt
deactivate
sudo systemctl restart kinsync-api.service
```

## 10. Definition-of-Done Checklist (Phase-1, backend half)

- [ ] VM provisioned, `ufw` (22/80/443 only), SSH key-only login, `fail2ban`, unattended-upgrades
      all active.
- [ ] PostgreSQL installed, `kinsync` database + role created, reachable only on `localhost`.
- [ ] `kinsync-api.service` running under systemd, restarts automatically on failure.
- [ ] Caddy serving `https://<domain>/health` with a valid Let's Encrypt certificate.
- [ ] `https://<domain>/health` returns `{"status": "ok"}`.
- [ ] `https://<domain>/health/db` returns `{"status": "ok"}`, confirming live PostgreSQL
      connectivity.
- [ ] Nightly `pg_dump` cron job configured and verified to produce a non-empty backup file.

## 11. Out of Scope for Phase-1 Deployment

Domain-specific business endpoints (`/pair`, `/devices/register`, `/heartbeat`, `/alerts/*`),
APScheduler dead-man's-switch job, and FCM push integration are deferred to Phase 2/3 per
`plan.md` §4.2 and are not part of this deployment.
