#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:18080}"
PSQL="${PSQL:-/Applications/Postgres.app/Contents/Versions/18/bin/psql}"
DATABASE="${DATABASE:-maohuoban_test}"
LEGAL_PROBE_PATH="${LEGAL_PROBE_PATH:-/api/v1/legal-documents/user_agreement}"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'E2E 前置检查失败：缺少命令 %s\n' "$command_name" >&2
    exit 1
  fi
}

require_psql() {
  if [[ "$PSQL" == */* ]]; then
    if [[ ! -x "$PSQL" ]]; then
      printf 'E2E 前置检查失败：PSQL 不可执行：%s\n' "$PSQL" >&2
      exit 1
    fi
    return
  fi

  require_command "$PSQL"
}

request() {
  local path="$1"
  local payload="$2"
  curl --silent --show-error \
    --header "content-type: application/json" \
    --request POST \
    --data "$payload" \
    "$BASE_URL$path"
}

request_get_authorized() {
  local path="$1"
  local access_token="$2"
  curl --silent --show-error \
    --header "authorization: Bearer $access_token" \
    "$BASE_URL$path"
}

request_post_authorized() {
  local path="$1"
  local access_token="$2"
  local payload="$3"
  curl --silent --show-error \
    --header "authorization: Bearer $access_token" \
    --header "content-type: application/json" \
    --request POST \
    --data "$payload" \
    "$BASE_URL$path"
}

request_patch_authorized() {
  local path="$1"
  local access_token="$2"
  local payload="$3"
  curl --silent --show-error \
    --header "authorization: Bearer $access_token" \
    --header "content-type: application/json" \
    --request PATCH \
    --data "$payload" \
    "$BASE_URL$path"
}

request_delete_authorized() {
  local path="$1"
  local access_token="$2"
  curl --silent --show-error \
    --header "authorization: Bearer $access_token" \
    --request DELETE \
    "$BASE_URL$path"
}

request_multipart_image_authorized() {
  local path="$1"
  local access_token="$2"
  local file_path="$3"
  curl --silent --show-error \
    --header "authorization: Bearer $access_token" \
    --request POST \
    --form "file=@${file_path};type=image/png" \
    --form "source_client=ios" \
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
    if (typeof current === "object") {
      process.stdout.write(JSON.stringify(current));
    } else {
      process.stdout.write(String(current));
    }
  ' "$json" "$path"
}

json_array_length() {
  local json="$1"
  local path="$2"
  node -e '
    const input = JSON.parse(process.argv[1]);
    const path = process.argv[2].split(".");
    let current = input;
    for (const key of path) current = current?.[key];
    if (!Array.isArray(current)) process.exit(2);
    process.stdout.write(String(current.length));
  ' "$json" "$path"
}

json_device_field() {
  local json="$1"
  local device_id="$2"
  local field="$3"
  node -e '
    const input = JSON.parse(process.argv[1]);
    const deviceID = process.argv[2];
    const field = process.argv[3];
    const device = input?.data?.devices?.find((item) => item.device_id === deviceID);
    if (!device || device[field] === undefined || device[field] === null) process.exit(2);
    if (typeof device[field] === "object") {
      process.stdout.write(JSON.stringify(device[field]));
    } else {
      process.stdout.write(String(device[field]));
    }
  ' "$json" "$device_id" "$field"
}

json_has() {
  local json="$1"
  local path="$2"
  node -e '
    const input = JSON.parse(process.argv[1]);
    const path = process.argv[2].split(".");
    let current = input;
    for (const key of path) {
      if (current === undefined || current === null || !(key in current)) process.exit(1);
      current = current[key];
    }
    process.exit(0);
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

expect_toast_message() {
  local json="$1"
  local actual
  actual="$(json_get "$json" "message")"
  if [[ -z "$actual" ]]; then
    printf '断言失败：响应 message 不能为空\n' >&2
    exit 1
  fi
}

expect_field_prefix() {
  local json="$1"
  local path="$2"
  local expected_prefix="$3"
  local actual
  actual="$(json_get "$json" "$path")"
  if [[ "$actual" != "$expected_prefix"* ]]; then
    printf '断言失败：%s 期望前缀 %s 实际 %s\n' "$path" "$expected_prefix" "$actual" >&2
    exit 1
  fi
}

expect_same_field() {
  local left_json="$1"
  local left_path="$2"
  local right_json="$3"
  local right_path="$4"
  local left_actual
  local right_actual
  left_actual="$(json_get "$left_json" "$left_path")"
  right_actual="$(json_get "$right_json" "$right_path")"
  if [[ "$left_actual" != "$right_actual" ]]; then
    printf '断言失败：%s 与 %s 不一致：%s != %s\n' "$left_path" "$right_path" "$left_actual" "$right_actual" >&2
    exit 1
  fi
}

expect_absent() {
  local json="$1"
  local path="$2"
  if json_has "$json" "$path"; then
    printf '断言失败：%s 不应出现在响应中\n' "$path" >&2
    exit 1
  fi
}

expect_array_length() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local actual
  actual="$(json_array_length "$json" "$path")"
  if [[ "$actual" != "$expected" ]]; then
    printf '断言失败：%s 数量期望 %s 实际 %s\n' "$path" "$expected" "$actual" >&2
    exit 1
  fi
}

expect_device_field() {
  local json="$1"
  local device_id="$2"
  local field="$3"
  local expected="$4"
  local actual
  actual="$(json_device_field "$json" "$device_id" "$field")"
  if [[ "$actual" != "$expected" ]]; then
    printf '断言失败：设备 %s 的 %s 期望 %s 实际 %s\n' "$device_id" "$field" "$expected" "$actual" >&2
    exit 1
  fi
}

expect_profile_edit_policy() {
  local json="$1"
  local policy_path="$2"
  local max_count="$3"
  local used_count="$4"
  local remaining_count="$5"
  expect_field "$json" "$policy_path.max_count" "$max_count"
  expect_field "$json" "$policy_path.used_count" "$used_count"
  expect_field "$json" "$policy_path.remaining_count" "$remaining_count"
  expect_field "$json" "$policy_path.window_days" "30"
  json_get "$json" "$policy_path.display_text" >/dev/null
}

expect_profile_media() {
  local json="$1"
  local media_path="$2"
  json_get "$json" "$media_path.asset_id" >/dev/null
  json_get "$json" "$media_path.url" >/dev/null
  expect_field "$json" "$media_path.mime_type" "image/png"
  expect_field "$json" "$media_path.width" "1"
  expect_field "$json" "$media_path.height" "1"
  json_get "$json" "$media_path.updated_at" >/dev/null
}

write_test_png() {
  local file_path="$1"
  node -e '
    const fs = require("fs");
    const content = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
      "base64"
    );
    fs.writeFileSync(process.argv[1], content);
  ' "$file_path"
}

preflight() {
  require_command node
  require_command curl
  require_psql

  if ! "$PSQL" -d "$DATABASE" -qAt -c "SELECT 1;" >/dev/null; then
    printf 'E2E 前置检查失败：无法连接测试数据库 %s\n' "$DATABASE" >&2
    exit 1
  fi

  local backend_probe
  if ! backend_probe="$(curl --silent --show-error --fail "$BASE_URL$LEGAL_PROBE_PATH")"; then
    printf 'E2E 前置检查失败：无法访问测试后端 %s，请先启动本地 E2E 后端\n' "$BASE_URL" >&2
    exit 1
  fi
  expect_field "$backend_probe" "success" "true"
  expect_field "$backend_probe" "code" "legal.document_loaded"
}

preflight

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
avatar_file="$tmp_dir/profile-avatar.png"
cover_file="$tmp_dir/profile-cover.png"
write_test_png "$avatar_file"
write_test_png "$cover_file"

"$PSQL" -d "$DATABASE" -q -c \
  "TRUNCATE TABLE auth_audit_events, device_sessions, password_credentials, user_identities, users CASCADE;"

printf -v phone_suffix "%08d" "$(( $(date +%s) % 100000000 ))"
phone="138$phone_suffix"
device_id="ios-e2e-device"
device_json="{\"device_id\":\"$device_id\",\"device_name\":\"iPhone 17 Pro\",\"platform\":\"iOS\",\"app_version\":\"1.0\"}"
second_device_id="ios-e2e-ipad"
second_device_json="{\"device_id\":\"$second_device_id\",\"device_name\":\"iPad Pro\",\"platform\":\"iPadOS\",\"app_version\":\"1.0\"}"

code_response="$(request "/api/v1/auth/phone/code" "{\"phone\":\"$phone\",\"agreement_accepted\":true,\"device\":$device_json}")"
expect_toast_message "$code_response"
expect_field "$code_response" "success" "true"
expect_field "$code_response" "message" "验证码已发送"
challenge_id="$(json_get "$code_response" "data.challenge_id")"

verify_response="$(request "/api/v1/auth/phone/verify" "{\"challenge_id\":\"$challenge_id\",\"code\":\"123456\",\"device\":$device_json}")"
expect_toast_message "$verify_response"
expect_field "$verify_response" "success" "true"
expect_field "$verify_response" "message" "登录成功"
expect_field "$verify_response" "data.user.phone" "$phone"
expect_field "$verify_response" "data.user.phone_masked" "${phone:0:3}****${phone:7:4}"
expect_field "$verify_response" "data.user.has_password" "false"
expect_field_prefix "$verify_response" "data.user.profile.display_name" "毛伙伴用户"
expect_field "$verify_response" "data.user.profile.avatar_presentation.sex" "unknown"
expect_field "$verify_response" "data.user.profile.avatar_presentation.sex_visibility" "hidden"
expect_absent "$verify_response" "data.user.badges"
expect_absent "$verify_response" "data.user.profile.join_sequence"
access_token="$(json_get "$verify_response" "data.access_token")"
refresh_token="$(json_get "$verify_response" "data.refresh_token")"

security_response="$(request_get_authorized "/api/v1/account/security" "$access_token")"
expect_toast_message "$security_response"
expect_field "$security_response" "success" "true"
expect_field "$security_response" "code" "account.security_loaded"
expect_field "$security_response" "message" "账号安全信息已加载"
expect_field "$security_response" "data.phone_masked" "${phone:0:3}****${phone:7:4}"
expect_field "$security_response" "data.has_password" "false"
expect_field "$security_response" "data.password_status_text" "未设置"

set_account_password_response="$(request_post_authorized "/api/v1/account/password" "$access_token" "{\"new_password\":\"Oldpass123\",\"confirm_password\":\"Oldpass123\"}")"
expect_toast_message "$set_account_password_response"
expect_field "$set_account_password_response" "success" "true"
expect_field "$set_account_password_response" "code" "account.password_set"
expect_field "$set_account_password_response" "message" "登录密码已设置"
expect_field "$set_account_password_response" "data.has_password" "true"
expect_field "$set_account_password_response" "data.password_status_text" "已设置"

repeat_account_password_response="$(request_post_authorized "/api/v1/account/password" "$access_token" "{\"new_password\":\"Otherpass123\",\"confirm_password\":\"Otherpass123\"}")"
expect_toast_message "$repeat_account_password_response"
expect_field "$repeat_account_password_response" "success" "false"
expect_field "$repeat_account_password_response" "code" "account.password_already_set"
expect_field "$repeat_account_password_response" "message" "登录密码已设置"

password_change_code_response="$(request_post_authorized "/api/v1/account/password/change-code" "$access_token" "{}")"
expect_toast_message "$password_change_code_response"
expect_field "$password_change_code_response" "success" "true"
expect_field "$password_change_code_response" "code" "account.password_change_code_sent"
expect_field "$password_change_code_response" "message" "验证码已发送"
password_change_challenge_id="$(json_get "$password_change_code_response" "data.challenge_id")"

wrong_current_password_response="$(request_patch_authorized "/api/v1/account/password" "$access_token" "{\"current_password\":\"Wrongpass123\",\"challenge_id\":\"$password_change_challenge_id\",\"code\":\"123456\",\"new_password\":\"Newpass123\",\"confirm_password\":\"Newpass123\"}")"
expect_toast_message "$wrong_current_password_response"
expect_field "$wrong_current_password_response" "success" "false"
expect_field "$wrong_current_password_response" "code" "account.current_password_invalid"
expect_field "$wrong_current_password_response" "message" "当前登录密码错误"

change_account_password_response="$(request_patch_authorized "/api/v1/account/password" "$access_token" "{\"current_password\":\"Oldpass123\",\"challenge_id\":\"$password_change_challenge_id\",\"code\":\"123456\",\"new_password\":\"Newpass123\",\"confirm_password\":\"Newpass123\"}")"
expect_toast_message "$change_account_password_response"
expect_field "$change_account_password_response" "success" "true"
expect_field "$change_account_password_response" "code" "account.password_changed"
expect_field "$change_account_password_response" "message" "登录密码已修改"
expect_field "$change_account_password_response" "data.has_password" "true"
expect_field "$change_account_password_response" "data.password_status_text" "已设置"

security_after_password_response="$(request_get_authorized "/api/v1/account/security" "$access_token")"
expect_toast_message "$security_after_password_response"
expect_field "$security_after_password_response" "success" "true"
expect_field "$security_after_password_response" "data.has_password" "true"
expect_field "$security_after_password_response" "data.password_status_text" "已设置"

second_login_response="$(request "/api/v1/auth/password/login" "{\"phone\":\"$phone\",\"password\":\"Newpass123\",\"device\":$second_device_json}")"
expect_toast_message "$second_login_response"
expect_field "$second_login_response" "success" "true"
expect_field "$second_login_response" "message" "登录成功"
expect_field "$second_login_response" "data.user.has_password" "true"
second_refresh_token="$(json_get "$second_login_response" "data.refresh_token")"

devices_response="$(request_get_authorized "/api/v1/account/devices" "$access_token")"
expect_toast_message "$devices_response"
expect_field "$devices_response" "success" "true"
expect_field "$devices_response" "code" "account.devices_loaded"
expect_field "$devices_response" "message" "登录设备已加载"
expect_array_length "$devices_response" "data.devices" "2"
expect_device_field "$devices_response" "$device_id" "is_current_device" "true"
expect_device_field "$devices_response" "$device_id" "last_active_text" "当前在线"
expect_device_field "$devices_response" "$second_device_id" "is_current_device" "false"
current_session_id="$(json_device_field "$devices_response" "$device_id" "session_id")"
second_session_id="$(json_device_field "$devices_response" "$second_device_id" "session_id")"

device_detail_response="$(request_get_authorized "/api/v1/account/devices/$second_session_id" "$access_token")"
expect_toast_message "$device_detail_response"
expect_field "$device_detail_response" "success" "true"
expect_field "$device_detail_response" "code" "account.device_loaded"
expect_field "$device_detail_response" "message" "登录设备详情已加载"
expect_field "$device_detail_response" "data.session_id" "$second_session_id"
expect_field "$device_detail_response" "data.device_id" "$second_device_id"
expect_field "$device_detail_response" "data.device_name" "iPad Pro"
expect_field "$device_detail_response" "data.platform" "iPadOS"
expect_field "$device_detail_response" "data.is_current_device" "false"

remove_current_device_response="$(request_delete_authorized "/api/v1/account/devices/$current_session_id" "$access_token")"
expect_toast_message "$remove_current_device_response"
expect_field "$remove_current_device_response" "success" "false"
expect_field "$remove_current_device_response" "code" "account.current_device_remove_forbidden"
expect_field "$remove_current_device_response" "message" "当前设备请通过退出登录移除"

remove_second_device_response="$(request_delete_authorized "/api/v1/account/devices/$second_session_id" "$access_token")"
expect_toast_message "$remove_second_device_response"
expect_field "$remove_second_device_response" "success" "true"
expect_field "$remove_second_device_response" "code" "account.device_revoked"
expect_field "$remove_second_device_response" "message" "登录设备已移除"

refresh_removed_device_response="$(request "/api/v1/auth/refresh" "{\"refresh_token\":\"$second_refresh_token\",\"device_id\":\"$second_device_id\"}")"
expect_toast_message "$refresh_removed_device_response"
expect_field "$refresh_removed_device_response" "success" "false"
expect_field "$refresh_removed_device_response" "code" "auth.refresh_invalid"

devices_after_remove_response="$(request_get_authorized "/api/v1/account/devices" "$access_token")"
expect_toast_message "$devices_after_remove_response"
expect_field "$devices_after_remove_response" "success" "true"
expect_array_length "$devices_after_remove_response" "data.devices" "1"
expect_device_field "$devices_after_remove_response" "$device_id" "is_current_device" "true"

profile_response="$(request_get_authorized "/api/v1/profile/me" "$access_token")"
expect_toast_message "$profile_response"
expect_field "$profile_response" "success" "true"
expect_field "$profile_response" "code" "profile.loaded"
expect_field "$profile_response" "message" "个人资料已加载"
expect_same_field "$profile_response" "data.maohuoban_id" "$verify_response" "data.user.profile.maohuoban_id"
expect_same_field "$profile_response" "data.display_name" "$verify_response" "data.user.profile.display_name"
expect_same_field "$profile_response" "data.avatar_presentation" "$verify_response" "data.user.profile.avatar_presentation"
expect_profile_edit_policy "$profile_response" "data.display_name_edit_policy" "5" "0" "5"
expect_profile_edit_policy "$profile_response" "data.bio_edit_policy" "3" "0" "3"
expect_absent "$profile_response" "data.join_sequence"
expect_absent "$profile_response" "data.badges"

avatar_upload_response="$(request_multipart_image_authorized "/api/v1/profile/me/avatar" "$access_token" "$avatar_file")"
expect_toast_message "$avatar_upload_response"
expect_field "$avatar_upload_response" "success" "true"
expect_field "$avatar_upload_response" "code" "profile.avatar_uploaded"
expect_field "$avatar_upload_response" "message" "头像已保存"
expect_profile_media "$avatar_upload_response" "data.avatar"

cover_upload_response="$(request_multipart_image_authorized "/api/v1/profile/me/cover" "$access_token" "$cover_file")"
expect_toast_message "$cover_upload_response"
expect_field "$cover_upload_response" "success" "true"
expect_field "$cover_upload_response" "code" "profile.cover_uploaded"
expect_field "$cover_upload_response" "message" "主页背景已保存"
expect_profile_media "$cover_upload_response" "data.cover"

profile_after_media_response="$(request_get_authorized "/api/v1/profile/me" "$access_token")"
expect_toast_message "$profile_after_media_response"
expect_field "$profile_after_media_response" "success" "true"
expect_same_field "$profile_after_media_response" "data.avatar" "$avatar_upload_response" "data.avatar"
expect_same_field "$profile_after_media_response" "data.cover" "$cover_upload_response" "data.cover"

profile_update_response="$(request_patch_authorized "/api/v1/profile/me" "$access_token" "{\"display_name\":\"橘子午后\",\"bio\":\"记录两只毛孩子的日常。\",\"gender\":\"female\",\"is_gender_visible\":false,\"birthday\":\"1999-12-31\"}")"
expect_toast_message "$profile_update_response"
expect_field "$profile_update_response" "success" "true"
expect_field "$profile_update_response" "code" "profile.updated"
expect_field "$profile_update_response" "message" "个人资料已更新"
expect_field "$profile_update_response" "data.display_name" "橘子午后"
expect_field "$profile_update_response" "data.bio" "记录两只毛孩子的日常。"
expect_field "$profile_update_response" "data.gender" "female"
expect_field "$profile_update_response" "data.is_gender_visible" "false"
expect_field "$profile_update_response" "data.birthday" "1999-12-31"
expect_field "$profile_update_response" "data.avatar_presentation.sex" "unknown"
expect_field "$profile_update_response" "data.avatar_presentation.sex_visibility" "hidden"
expect_profile_edit_policy "$profile_update_response" "data.display_name_edit_policy" "5" "1" "4"
expect_profile_edit_policy "$profile_update_response" "data.bio_edit_policy" "3" "1" "2"

profile_after_update_response="$(request_get_authorized "/api/v1/profile/me" "$access_token")"
expect_toast_message "$profile_after_update_response"
expect_field "$profile_after_update_response" "success" "true"
expect_same_field "$profile_after_update_response" "data.display_name" "$profile_update_response" "data.display_name"
expect_same_field "$profile_after_update_response" "data.bio" "$profile_update_response" "data.bio"
expect_same_field "$profile_after_update_response" "data.avatar_presentation" "$profile_update_response" "data.avatar_presentation"
expect_profile_edit_policy "$profile_after_update_response" "data.display_name_edit_policy" "5" "1" "4"
expect_profile_edit_policy "$profile_after_update_response" "data.bio_edit_policy" "3" "1" "2"

for display_name in "小一" "小二" "小三" "小四"; do
  name_limit_response="$(request_patch_authorized "/api/v1/profile/me" "$access_token" "{\"display_name\":\"$display_name\"}")"
  expect_toast_message "$name_limit_response"
  expect_field "$name_limit_response" "success" "true"
done

name_rejected_response="$(request_patch_authorized "/api/v1/profile/me" "$access_token" "{\"display_name\":\"小五\"}")"
expect_toast_message "$name_rejected_response"
expect_field "$name_rejected_response" "success" "false"
expect_field "$name_rejected_response" "code" "profile.display_name_edit_limit_exceeded"
expect_field "$name_rejected_response" "message" "昵称修改次数已用完，请稍后再试"

for bio_text in "简介二" "简介三"; do
  bio_limit_response="$(request_patch_authorized "/api/v1/profile/me" "$access_token" "{\"bio\":\"$bio_text\"}")"
  expect_toast_message "$bio_limit_response"
  expect_field "$bio_limit_response" "success" "true"
done

bio_rejected_response="$(request_patch_authorized "/api/v1/profile/me" "$access_token" "{\"bio\":\"简介四\"}")"
expect_toast_message "$bio_rejected_response"
expect_field "$bio_rejected_response" "success" "false"
expect_field "$bio_rejected_response" "code" "profile.bio_edit_limit_exceeded"
expect_field "$bio_rejected_response" "message" "简介修改次数已用完，请稍后再试"

refresh_response="$(request "/api/v1/auth/refresh" "{\"refresh_token\":\"$refresh_token\",\"device_id\":\"$device_id\"}")"
expect_toast_message "$refresh_response"
expect_field "$refresh_response" "success" "true"
expect_field "$refresh_response" "message" "登录状态已刷新"
expect_field "$refresh_response" "data.user.has_password" "true"
expect_same_field "$refresh_response" "data.user.profile.maohuoban_id" "$verify_response" "data.user.profile.maohuoban_id"
new_refresh_token="$(json_get "$refresh_response" "data.refresh_token")"

replay_response="$(request "/api/v1/auth/refresh" "{\"refresh_token\":\"$refresh_token\",\"device_id\":\"$device_id\"}")"
expect_toast_message "$replay_response"
expect_field "$replay_response" "success" "false"
expect_field "$replay_response" "code" "auth.refresh_reused"

recovery_code_response="$(request "/api/v1/account-recovery/code" "{\"phone\":\"$phone\",\"device\":$device_json}")"
expect_toast_message "$recovery_code_response"
expect_field "$recovery_code_response" "success" "true"
recovery_challenge_id="$(json_get "$recovery_code_response" "data.challenge_id")"

reset_response="$(request "/api/v1/account-recovery/reset-password" "{\"challenge_id\":\"$recovery_challenge_id\",\"code\":\"123456\",\"new_password\":\"Recoverpass123\"}")"
expect_toast_message "$reset_response"
expect_field "$reset_response" "success" "true"
expect_field "$reset_response" "message" "密码已重置"

password_response="$(request "/api/v1/auth/password/login" "{\"phone\":\"$phone\",\"password\":\"Recoverpass123\",\"device\":$device_json}")"
expect_toast_message "$password_response"
expect_field "$password_response" "success" "true"
expect_field "$password_response" "message" "登录成功"
expect_field "$password_response" "data.user.has_password" "true"
expect_same_field "$password_response" "data.user.profile.maohuoban_id" "$verify_response" "data.user.profile.maohuoban_id"
password_refresh_token="$(json_get "$password_response" "data.refresh_token")"

logout_response="$(request "/api/v1/auth/logout" "{\"refresh_token\":\"$password_refresh_token\",\"device_id\":\"$device_id\"}")"
expect_toast_message "$logout_response"
expect_field "$logout_response" "success" "true"
expect_field "$logout_response" "message" "已退出登录"

oauth_response="$(request "/api/v1/auth/oauth/apple" "{\"identity_token\":\"todo-token\",\"nonce\":\"todo-nonce\"}")"
expect_toast_message "$oauth_response"
expect_field "$oauth_response" "success" "false"
expect_field "$oauth_response" "code" "auth.oauth_todo"

audit_count="$("$PSQL" -d "$DATABASE" -tA -c "SELECT COUNT(*) FROM auth_audit_events;")"
if [[ "$audit_count" -lt 5 ]]; then
  printf '断言失败：auth_audit_events 数量过少：%s\n' "$audit_count" >&2
  exit 1
fi

printf 'auth e2e ok: audit_events=%s\n' "$audit_count"
