#!/usr/bin/env bats
# Tests for check-status.sh - OTP status checking

setup() {
  export TEST_DIR="$(mktemp -d)"
  export OPENCLAW_WORKSPACE="$TEST_DIR"
  export STATE_FILE="$TEST_DIR/memory/otp-state.json"

  CHECK_STATUS_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/check-status.sh"

  mkdir -p "$TEST_DIR/memory"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Helper: Create valid state file
create_state() {
  local user_id="$1"
  local verified_at="$2"
  local expires_at="$3"

  cat > "$STATE_FILE" <<EOF
{
  "verifications": {
    "$user_id": {
      "verifiedAt": $verified_at,
      "expiresAt": $expires_at
    }
  }
}
EOF
}

# ============================================================================
# Input Validation
# ============================================================================

@test "check-status.sh: rejects user_id with command substitution" {
  # RED: Should reject malicious user IDs
  create_state "user1" "1000000000000" "2000000000000"

  run bash "$CHECK_STATUS_SCRIPT" '$(touch /tmp/pwned3)'

  [ "$status" -ne 0 ]
  [ ! -f "/tmp/pwned3" ]
}

@test "check-status.sh: rejects user_id with shell metacharacters" {
  # RED: Should reject dangerous user IDs
  create_state "user1" "1000000000000" "2000000000000"

  run bash "$CHECK_STATUS_SCRIPT" 'user; rm -rf /'

  [ "$status" -eq 2 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "check-status.sh: accepts valid user_id formats" {
  # RED: Should accept standard user ID formats
  NOW_MS=$(date +%s)000
  FUTURE_MS=$((NOW_MS + 3600000))

  for user_id in "user@example.com" "user.name@domain.co.uk" "user_123"; do
    create_state "$user_id" "$NOW_MS" "$FUTURE_MS"
    run bash "$CHECK_STATUS_SCRIPT" "$user_id"
    [ "$status" -eq 0 ]
  done
}

# ============================================================================
# State File Validation
# ============================================================================

@test "check-status.sh: recovers from corrupted state file" {
  # RED: Should handle invalid JSON gracefully
  echo "not valid json" > "$STATE_FILE"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Never verified" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "check-status.sh: handles state file with wrong structure" {
  # RED: Should handle unexpected schema
  echo '{"wrong": "structure"}' > "$STATE_FILE"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Never verified" ]]
}

@test "check-status.sh: handles missing verification entry" {
  # RED: Should handle user not in state file
  create_state "user2" "1000000000000" "2000000000000"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Never verified" ]]
}

# ============================================================================
# macOS/BSD Portability
# ============================================================================

@test "check-status.sh: works with BSD date format" {
  # RED: Should use portable date commands
  skip "Requires BSD date testing"
}

# ============================================================================
# Existing Functionality
# ============================================================================

@test "check-status.sh: reports valid verification" {
  # Baseline: Should show valid verification with time remaining
  NOW_MS=$(date +%s)000
  FUTURE_MS=$((NOW_MS + 86400000))  # 24 hours

  create_state "user1" "$NOW_MS" "$FUTURE_MS"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅" ]]
  [[ "$output" =~ "Valid" ]]
}

@test "check-status.sh: reports expired verification" {
  # Baseline: Should show expired verification
  NOW_MS=$(date +%s)000
  PAST_MS=$((NOW_MS - 86400000))  # 24 hours ago
  EXPIRED_MS=$((PAST_MS - 1000))

  create_state "user1" "$EXPIRED_MS" "$PAST_MS"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 1 ]
  [[ "$output" =~ "❌" ]]
  [[ "$output" =~ "Expired" ]]
}

@test "check-status.sh: reports never verified" {
  # Baseline: Should handle missing state file
  rm -f "$STATE_FILE"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Never verified" ]]
}

@test "check-status.sh: shows remaining time correctly" {
  # Baseline: Should calculate and display remaining hours
  NOW_MS=$(date +%s)000
  FUTURE_MS=$((NOW_MS + 7200000))  # 2 hours

  create_state "user1" "$NOW_MS" "$FUTURE_MS"

  run bash "$CHECK_STATUS_SCRIPT" "user1"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "2" ]]
  [[ "$output" =~ "hours" ]]
}

@test "check-status.sh: defaults to 'default' user" {
  # Baseline: Should use "default" if no user specified
  NOW_MS=$(date +%s)000
  FUTURE_MS=$((NOW_MS + 3600000))

  create_state "default" "$NOW_MS" "$FUTURE_MS"

  run bash "$CHECK_STATUS_SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Valid" ]]
}
