#!/bin/bash

# Preserve the statusline stream even when CacheBar cannot consume it.
set +e
input_file=$(mktemp "${TMPDIR:-/tmp}/cachebar-statusline.XXXXXX") || exit 0
trap 'rm -f "$input_file" "$output_file"' EXIT
cat >"$input_file" || exit 0
cat "$input_file"

output_file=
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi
session_id=$(jq -er '.session_id | strings' <"$input_file" 2>/dev/null) || exit 0
case "$session_id" in
  ''|*[!A-Za-z0-9._-]*) exit 0 ;;
esac

sessions_dir="${HOME:-}/Library/Application Support/CacheBar/sessions"
mkdir -p "$sessions_dir" 2>/dev/null || exit 0
output_file=$(mktemp "$sessions_dir/.${session_id}.XXXXXX") || exit 0
if ! cp "$input_file" "$output_file" 2>/dev/null; then
  exit 0
fi
mv -f "$output_file" "$sessions_dir/$session_id.json" 2>/dev/null || exit 0
