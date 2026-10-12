#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
bridge="$repo_root/scripts/statusline-bridge.sh"
fixture="$repo_root/scripts/fixtures/statusline-sample.json"
test_home=$(mktemp -d "${TMPDIR:-/tmp}/cachebar-bridge-test.XXXXXX")
trap 'rm -rf "$test_home"' EXIT

expected=$(cat "$fixture")
actual=$(HOME="$test_home" bash "$bridge" <"$fixture")
test "$actual" = "$expected"
test -f "$test_home/Library/Application Support/CacheBar/sessions/00000000-0000-0000-0000-000000000000.json"
cmp "$fixture" "$test_home/Library/Application Support/CacheBar/sessions/00000000-0000-0000-0000-000000000000.json"
echo "valid JSON: stdout and atomic session file match fixture"

bad='{"session_id":"bad/name"'
set +e
bad_output=$(printf '%s' "$bad" | HOME="$test_home" bash "$bridge")
bad_status=$?
set -e
test "$bad_status" -eq 0
test "$bad_output" = "$bad"
test ! -e "$test_home/Library/Application Support/CacheBar/sessions/bad/name.json"
echo "invalid JSON: status 0 and stdout preserved"
