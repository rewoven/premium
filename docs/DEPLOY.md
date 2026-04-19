# Deploying premium.rewovenapp.com to a VPS

This guide assumes a fresh **Ubuntu 22.04 / 24.04** VPS (DigitalOcean,
Hetzner, Linode, OVH, etc.). It walks through installing Elixir, building
a release, putting it behind Caddy with auto-TLS, and running it as a
systemd service.

Total time: ~30 minutes once you have the env vars ready.

---

## 0. Before you start

You need:

- A VPS with **root or sudo access**, at least **1GB RAM**
- Domain `premium.rewovenapp.com` with **DNS A record pointing at the VPS IP**
  *(set this in your registrar — Cloudflare, GoDaddy, Squarespace, etc.)*
- The env vars listed in `README.md` (Supabase + Lemon Squeezy)

---

## 1. SSH in and install dependencies

```bash
ssh root@your.vps.ip

# Update system
apt update && apt upgrade -y

# Build tools + Erlang/Elixir
apt install -y build-essential git curl autoconf m4 libncurses5-dev \
  libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev \
  libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc \
  fop libxml2-utils libncurses-dev openjdk-17-jdk inotify-tools

# Elixir via asdf (manages versions cleanly)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
source ~/.bashrc
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.1
asdf install elixir 1.17.3-otp-27
asdf global erlang 27.1
asdf global elixir 1.17.3-otp-27
mix local.hex --force
mix local.rebar --force
```

Verify: `elixir --version` should print 1.17.3.

---

## 2. Create a deploy user and clone the repo

```bash
adduser --disabled-password --gecos "" deploy
usermod -aG sudo deploy
su - deploy

# As deploy user:
mkdir -p ~/apps
cd ~/apps
git clone https://github.com/<your-username>/rewoven_premium.git premium
cd premium
```

(Or `scp` the project tarball if you haven't pushed it to GitHub yet —
see "Alternative: deploy without GitHub" at the bottom.)

---

## 3. Set environment variables

Create `~/apps/premium/.env.prod` (note: this stays on the server,
**never** commit it):

```bash
nano ~/apps/premium/.env.prod
```

Paste:

```
PHX_SERVER=true
PHX_HOST=premium.rewovenapp.com
PORT=4000
SECRET_KEY_BASE=GENERATE_BELOW

SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_KEY=eyJ...

LEMONSQUEEZY_API_KEY=ls_...
LEMONSQUEEZY_STORE_ID=12345
LEMONSQUEEZY_VARIANT_ID=67890
LEMONSQUEEZY_WEBHOOK_SECRET=...

PREMIUM_BASE_URL=https://premium.rewovenapp.com
```

Generate `SECRET_KEY_BASE`:

```bash
cd ~/apps/premium
mix deps.get --only prod
mix phx.gen.secret
```

Paste the output into the `SECRET_KEY_BASE=` line in `.env.prod`.

Lock it down so only your user can read it:

```bash
chmod 600 ~/apps/premium/.env.prod
```

---

## 4. Build the production release

```bash
cd ~/apps/premium
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release
```

The release lands at `_build/prod/rel/rewoven_premium/`.

Test it once before installing the service:

```bash
set -a && source .env.prod && set +a
_build/prod/rel/rewoven_premium/bin/rewoven_premium start
# Open http://your.vps.ip:4000 in another terminal: curl
# Ctrl-C to stop, then `kill %1` if it lingers.
```

---

## 5. Install the systemd service

Switch back to root:

```bash
exit  # back to root from deploy user
```

Create `/etc/systemd/system/rewoven-premium.service`:

```ini
[Unit]
Description=Rewoven Premium (Phoenix)
After=network.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/apps/premium
EnvironmentFile=/home/deploy/apps/premium/.env.prod
ExecStart=/home/deploy/apps/premium/_build/prod/rel/rewoven_premium/bin/rewoven_premium start
ExecStop=/home/deploy/apps/premium/_build/prod/rel/rewoven_premium/bin/rewoven_premium stop
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

Enable + start it:

```bash
systemctl daemon-reload
systemctl enable rewoven-premium
systemctl start rewoven-premium
systemctl status rewoven-premium  # should say "active (running)"
journalctl -u rewoven-premium -f  # tail the logs
```

---

## 6. Install Caddy (HTTPS reverse proxy)

Caddy auto-provisions Let's Encrypt certificates — zero config.

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | tee /etc/apt/trusted.gpg.d/caddy-stable.asc
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install -y caddy
```

Edit `/etc/caddy/Caddyfile`:

```
premium.rewovenapp.com {
    reverse_proxy 127.0.0.1:4000

    # Let's Encrypt automatically issues + renews the cert.
    # Uncomment for HSTS:
    # header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}
```

Restart Caddy:

```bash
systemctl reload caddy
systemctl status caddy
```

If DNS is propagated, Caddy fetches a TLS cert in ~30 seconds.
**Test it:** `curl -I https://premium.rewovenapp.com`. You should get a
`200 OK` with a valid TLS cert.

---

## 7. Point the Lemon Squeezy webhook at production

In Lemon Squeezy → **Settings → Webhooks**, edit the endpoint URL to:

```
https://premium.rewovenapp.com/webhooks/lemonsqueezy
```

Save. Click **Send test event** — should return `200 OK`. Check
`journalctl -u rewoven-premium -f` to see it land.

---

## 8. End-to-end test

1. Open `https://premium.rewovenapp.com` in a browser.
2. Sign in with Google (uses your Supabase auth).
3. Click "Subscribe — $4.99/mo".
4. On Lemon Squeezy's checkout, use a real card (or test mode if your
   account is still in test mode).
5. After payment → redirected to `/success`.
6. In Supabase SQL editor: `select id, email, is_premium from profiles where id = '<your-user-id>';` — should show `is_premium = true` within ~5 seconds.
7. Open `https://quiz.rewovenapp.com/host` — paywall should be gone.

---

## Updating the app later

```bash
ssh deploy@your.vps.ip
cd ~/apps/premium
git pull
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release --overwrite
sudo systemctl restart rewoven-premium
```

Total downtime: ~3 seconds.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `502 Bad Gateway` from Caddy | App isn't running. `systemctl status rewoven-premium`, then `journalctl -u rewoven-premium -n 50`. |
| Webhook returns 400 | Webhook secret in `.env.prod` doesn't match what's set in Lemon Squeezy. |
| Sign-in works but `is_premium` never flips | Check the webhook is firing (Lemon Squeezy → Webhooks → Logs) and that `SUPABASE_SERVICE_KEY` is the **service_role** key, not the anon key. |
| Cert error | Make sure the DNS A record is set and propagated (`dig premium.rewovenapp.com`). Caddy will retry every few minutes. |

---

## Alternative: deploy without GitHub

If the repo isn't pushed yet, copy it from your laptop:

```bash
# On your laptop:
cd /Users/arhanharchandani/Downloads
tar -czf premium.tar.gz --exclude='_build' --exclude='deps' --exclude='.git' rewoven_premium/
scp premium.tar.gz deploy@your.vps.ip:~/apps/

# On the VPS as deploy user:
cd ~/apps
tar -xzf premium.tar.gz
mv rewoven_premium premium
```

Then jump to step 3.
