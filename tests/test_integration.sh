#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:${APP_PORT:-8000}}"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local tmp
  tmp="$(mktemp)"

  if [ -n "$body" ]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" \
      -H 'Content-Type: application/json' \
      --data "$body" \
      "$BASE_URL$path")"
  else
    code="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$BASE_URL$path")"
  fi

  response="$(cat "$tmp")"
  rm -f "$tmp"
}

assert_code() {
  local expected="$1"
  local label="$2"
  [ "$code" = "$expected" ] || fail "$label expected HTTP $expected, got $code: $response"
}

assert_json_key() {
  local key="$1"
  local label="$2"
  printf '%s' "$response" | python3 -c "import json,sys; data=json.load(sys.stdin); assert '$key' in data" \
    || fail "$label missing JSON key '$key': $response"
}

assert_json_array() {
  local label="$1"
  printf '%s' "$response" | python3 -c "import json,sys; assert isinstance(json.load(sys.stdin), list)" \
    || fail "$label expected JSON array: $response"
}

unique_name="api-$(date +%s)"

request GET /health
assert_code 200 "GET /health"
assert_json_key status "GET /health"
assert_json_key checks "GET /health"
pass "GET /health returns status and checks"

request POST /services "{\"name\":\"$unique_name\",\"url\":\"https://example.com\"}"
assert_code 200 "POST /services"
assert_json_key id "POST /services"
assert_json_key name "POST /services"
pass "POST /services creates a service"

request POST /services "{\"name\":\"$unique_name\",\"url\":\"https://example.com\"}"
assert_code 409 "POST /services duplicate"
assert_json_key detail "POST /services duplicate"
pass "POST /services duplicate returns 409"

request GET /services
assert_code 200 "GET /services"
assert_json_array "GET /services"
pass "GET /services returns an array"

request POST /incidents "{\"service_name\":\"$unique_name\",\"title\":\"Synthetic incident\",\"description\":\"CI test\",\"severity\":\"minor\"}"
assert_code 200 "POST /incidents"
assert_json_key id "POST /incidents"
assert_json_key status "POST /incidents"
pass "POST /incidents creates an incident"

request GET /incidents
assert_code 200 "GET /incidents"
assert_json_array "GET /incidents"
pass "GET /incidents returns an array"
