#!/usr/bin/env bash
# Integration test: boot the image against real MariaDB + Redis, create a
# throwaway site with erpnext + hrms installed, run migrate, and check the apps.
# Usage: ci/integration-test.sh <image-ref>      (ENGINE=podman to use podman)
set -euo pipefail

IMAGE="${1:?usage: $0 <image-ref>}"
ENGINE="${ENGINE:-docker}"
RUN="erpnext-it-$$"
NET="$RUN-net"
VOL="$RUN-sites"
DB_PASS="it-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
SITE="test.localhost"

cleanup() {
  "$ENGINE" rm -f "$RUN-db" "$RUN-redis" >/dev/null 2>&1 || true
  "$ENGINE" volume rm -f "$VOL" >/dev/null 2>&1 || true
  "$ENGINE" network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$ENGINE" network create "$NET" >/dev/null
"$ENGINE" run -d --name "$RUN-db" --network "$NET" --network-alias db \
  -e MARIADB_ROOT_PASSWORD="$DB_PASS" mariadb:11.8 \
  --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci \
  --skip-character-set-client-handshake >/dev/null
"$ENGINE" run -d --name "$RUN-redis" --network "$NET" --network-alias redis \
  redis:6.2-alpine >/dev/null

echo "Waiting for MariaDB..."
for i in $(seq 1 60); do
  if "$ENGINE" exec "$RUN-db" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then
    break
  fi
  [ "$i" -eq 60 ] && { echo "MariaDB did not become ready"; "$ENGINE" logs "$RUN-db" | tail -20; exit 1; }
  sleep 2
done

# Same steps the compose configurator + create-site services perform.
"$ENGINE" run --rm --network "$NET" -v "$VOL:/home/frappe/frappe-bench/sites" \
  -e DB_PASS="$DB_PASS" -e SITE="$SITE" --entrypoint bash "$IMAGE" -c '
    set -euo pipefail
    ls -1 apps > sites/apps.txt
    bench set-config -g db_host db
    bench set-config -gp db_port 3306
    bench set-config -g redis_cache redis://redis:6379
    bench set-config -g redis_queue redis://redis:6379
    bench set-config -g redis_socketio redis://redis:6379
    bench new-site --mariadb-user-host-login-scope="%" --admin-password=admin \
      --db-root-username=root --db-root-password="$DB_PASS" \
      --install-app erpnext --install-app hrms "$SITE"
    bench --site "$SITE" migrate
    apps=$(bench --site "$SITE" list-apps)
    echo "$apps"
    for a in frappe erpnext hrms; do
      grep -q "^$a" <<<"$apps" || { echo "app not installed on site: $a"; exit 1; }
    done
    bench --site "$SITE" doctor
  '
echo "Integration test passed."
