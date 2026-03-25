#!/usr/bin/env bash
set -euo pipefail

NAME="w_core_smoke"
PORT="${PORT:-}"
BASE="http://127.0.0.1:${PORT}"
SECRET_KEY_BASE="${SECRET_KEY_BASE:-}"

cleanup() {
  docker rm -f "${NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

pick_free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

gen_secret_key_base() {
  python3 - <<'PY'
import secrets
# token_urlsafe(64) geralmente gera bem mais que 64 bytes/chars.
print(secrets.token_urlsafe(64))
PY
}

if [[ -z "${PORT}" ]]; then
  PORT="$(pick_free_port)"
fi
BASE="http://127.0.0.1:${PORT}"

if [[ -z "${SECRET_KEY_BASE}" ]]; then
  SECRET_KEY_BASE="$(gen_secret_key_base)"
fi

echo "==> Building image"
docker build -t w_core:smoke .

echo "==> Starting container on port ${PORT}"
docker run -d --name "${NAME}" -p "${PORT}:4000" \
  -e PHX_SERVER=true \
  -e PORT=4000 \
  -e DATABASE_PATH=/data/w_core.db \
  -e SECRET_KEY_BASE="${SECRET_KEY_BASE}" \
  -e ELIXIR_ERL_OPTIONS="+fnu" \
  -v "${NAME}_data:/data" \
  w_core:smoke >/dev/null

echo "==> Waiting for HTTP to respond"
for i in $(seq 1 60); do
  if curl -fsS "${BASE}/users/log-in" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "==> Checking routes"

# 1) Login page should be 200
code="$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/users/log-in")"
test "${code}" = "200"
echo "OK /users/log-in -> 200"

# 2) Register page should be 200
code="$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/users/register")"
test "${code}" = "200"
echo "OK /users/register -> 200"

# 3) Dashboard should redirect to login when unauthenticated
location="$(curl -s -o /dev/null -D - "${BASE}/dashboard" | awk 'tolower($1)=="location:"{print $2}' | tr -d '\r')"
test "${location}" = "/users/log-in"
echo "OK /dashboard -> Location: /users/log-in (unauthenticated)"

echo "==> Smoke test passed"

