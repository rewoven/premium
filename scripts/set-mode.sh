#!/usr/bin/env bash
# Toggle the entire Rewoven stack between FREE mode and PREMIUM mode.
#
#   ./scripts/set-mode.sh free      # make everything free for everyone
#   ./scripts/set-mode.sh premium   # turn the paywall back on
#
# What it does:
#   1. SSH to the VPS
#   2. Edit REQUIRE_PREMIUM in /opt/rewoven_premium/.env.prod,
#      /opt/rewoven_curriculum/.env.prod, /opt/rewoven_quiz/.env.prod
#   3. Restart all three services
#   4. Update the static rewovenapp.com site (REWOVEN_FREE_MODE flag)
#      and push to GitHub Pages

set -euo pipefail
VPS=root@185.197.250.205
MODE="${1:-}"

if [[ "$MODE" != "free" && "$MODE" != "premium" ]]; then
  echo "Usage: $0 free|premium" >&2
  exit 1
fi

if [[ "$MODE" == "premium" ]]; then
  REQUIRE=true
  JS_FREE=false
  echo "🔒 Switching to PREMIUM mode — paywall ON"
else
  REQUIRE=false
  JS_FREE=true
  echo "🌱 Switching to FREE mode — paywall OFF"
fi

# --- Phoenix services on the VPS ---
ssh "$VPS" bash <<EOF
set -e
for app in rewoven_premium rewoven_curriculum rewoven_quiz; do
  envfile="/opt/\$app/.env.prod"
  if [[ -f "\$envfile" ]]; then
    if grep -q '^REQUIRE_PREMIUM=' "\$envfile"; then
      sed -i 's|^REQUIRE_PREMIUM=.*|REQUIRE_PREMIUM=$REQUIRE|' "\$envfile"
    else
      echo 'REQUIRE_PREMIUM=$REQUIRE' >> "\$envfile"
    fi
    echo "  updated \$envfile"
  fi
done

systemctl restart rewoven-premium rewoven-curriculum rewoven-quiz
sleep 2
for svc in rewoven-premium rewoven-curriculum rewoven-quiz; do
  echo "  \$svc: \$(systemctl is-active \$svc)"
done
EOF

# --- Static site (rewovenapp.com) on GitHub Pages ---
SITE_DIR="$(dirname "$0")/../../rewoven-site"
if [[ -d "$SITE_DIR/.git" ]]; then
  echo "→ Updating static site flag (REWOVEN_FREE_MODE = $JS_FREE)"
  cd "$SITE_DIR"
  for f in index.html game/index.html; do
    sed -i.bak -E "s|window\.REWOVEN_FREE_MODE = (true\|false);|window.REWOVEN_FREE_MODE = $JS_FREE;|g" "$f"
    rm -f "$f.bak"
  done
  if ! git diff --quiet; then
    git add index.html game/index.html
    git -c user.name="ArhanCodes" -c user.email="arhanh1234@gmail.com" \
        commit -m "Set rewovenapp.com to $MODE mode (REWOVEN_FREE_MODE=$JS_FREE)"
    git push
    echo "  ✓ pushed to rewoven/site (GitHub Pages will rebuild in ~30s)"
  else
    echo "  (no static-site changes needed)"
  fi
fi

echo "✓ Done — Rewoven stack is now in $MODE mode."
