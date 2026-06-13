#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
PSQL="${PSQL:-/Applications/Postgres.app/Contents/Versions/18/bin/psql}"
DATABASE="${DATABASE:-maohuoban}"

request() {
  local path="$1"
  local payload="$2"
  curl --silent --show-error \
    --header "content-type: application/json" \
    --request POST \
    --data "$payload" \
    "$BASE_URL$path"
}

json_get() {
  local json="$1"
  local path="$2"
  node -e '
    const input = JSON.parse(process.argv[1]);
    const path = process.argv[2].split(".");
    let current = input;
    for (const key of path) current = current?.[key];
    if (current === undefined || current === null) process.exit(2);
    process.stdout.write(String(current));
  ' "$json" "$path"
}

expect_field() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local actual
  actual="$(json_get "$json" "$path")"
  if [[ "$actual" != "$expected" ]]; then
    printf '断言失败：%s 期望 %s 实际 %s\n' "$path" "$expected" "$actual" >&2
    exit 1
  fi
}

"$PSQL" -d "$DATABASE" -q -c \
  "TRUNCATE TABLE auth_audit_events, device_sessions, password_credentials, user_identities, users CASCADE;"

printf -v phone_suffix "%08d" "$(( $(date +%s) % 100000000 ))"
phone="138$phone_suffix"
device_id="ios-e2e-device"
device_json="{\"device_id\":\"$device_id\",\"device_name\":\"iPhone 17 Pro\",\"platform\":\"iOS\",\"app_version\":\"1.0\"}"

code_response="$(request "/api/v1/auth/phone/code" "{\"phone\":\"$phone\",\"agreement_accepted\":true,\"device\":$device_json}")"
expect_field "$code_response" "success" "true"
expect_field "$code_response" "message" "验证码已发送"
challenge_id="$(json_get "$code_response" "data.challenge_id")"

verify_response="$(request "/api/v1/auth/phone/verify" "{\"challenge_id\":\"$challenge_id\",\"code\":\"123456\",\"device\":$device_json}")"
expect_field "$verify_response" "success" "true"
expect_field "$verify_response" "message" "登录成功"
refresh_token="$(json_get "$verify_response" "data.refresh_token")"

refresh_response="$(request "/api/v1/auth/refresh" "{\"refresh_token\":\"$refresh_token\",\"device_id\":\"$device_id\"}")"
expect_field "$refresh_response" "success" "true"
expect_field "$refresh_response" "message" "登录状态已刷新"
new_refresh_token="$(json_get "$refresh_response" "data.refresh_token")"

replay_response="$(request "/api/v1/auth/refresh" "{\"refresh_token\":\"$refresh_token\",\"device_id\":\"$device_id\"}")"
expect_field "$replay_response" "success" "false"
expect_field "$replay_response" "code" "auth.refresh_reused"

recovery_code_response="$(request "/api/v1/account-recovery/code" "{\"phone\":\"$phone\",\"device\":$device_json}")"
expect_field "$recovery_code_response" "success" "true"
recovery_challenge_id="$(json_get "$recovery_code_response" "data.challenge_id")"

reset_response="$(request "/api/v1/account-recovery/reset-password" "{\"challenge_id\":\"$recovery_challenge_id\",\"code\":\"123456\",\"new_password\":\"new-password\"}")"
expect_field "$reset_response" "success" "true"
expect_field "$reset_response" "message" "密码已重置"

password_response="$(request "/api/v1/auth/password/login" "{\"phone\":\"$phone\",\"password\":\"new-password\",\"device\":$device_json}")"
expect_field "$password_response" "success" "true"
expect_field "$password_response" "message" "登录成功"
password_refresh_token="$(json_get "$password_response" "data.refresh_token")"

logout_response="$(request "/api/v1/auth/logout" "{\"refresh_token\":\"$password_refresh_token\",\"device_id\":\"$device_id\"}")"
expect_field "$logout_response" "success" "true"
expect_field "$logout_response" "message" "已退出登录"

oauth_response="$(request "/api/v1/auth/oauth/apple" "{\"identity_token\":\"todo-token\",\"nonce\":\"todo-nonce\"}")"
expect_field "$oauth_response" "success" "false"
expect_field "$oauth_response" "code" "auth.oauth_todo"

audit_count="$("$PSQL" -d "$DATABASE" -tA -c "SELECT COUNT(*) FROM auth_audit_events;")"
if [[ "$audit_count" -lt 5 ]]; then
  printf '断言失败：auth_audit_events 数量过少：%s\n' "$audit_count" >&2
  exit 1
fi

printf 'auth e2e ok: audit_events=%s\n' "$audit_count"
