# Claude Code statusline stdin schema

This table is based on the real, redacted sample in
`harness/tasks/task_f240a435c666ac9a8b5319cbe9-t1-statusline-bridge/artifacts/statusline-sample.sanitized.json`.
Values and identifying strings are redacted only; field names and nesting are preserved.

| Purpose | Exact field | Sample value / meaning |
| --- | --- | --- |
| Session identifier | `session_id` | UUID string; bridge uses it as the filename stem |
| Transcript | `transcript_path` | Absolute `.jsonl` path |
| Session label | `session_name` | String |
| Session cost | `cost.total_cost_usd` | `789.3` USD |
| Context size | `context_window.context_window_size` | `1000000` tokens |
| Context consumed | `context_window.total_input_tokens` | `270622` tokens |
| Context percentage | `context_window.used_percentage` | `27` |
| Five-hour quota | `rate_limits.five_hour.used_percentage` | `47` |
| Five-hour reset | `rate_limits.five_hour.resets_at` | `1791778800` (Unix seconds) |
| Seven-day quota | `rate_limits.seven_day.used_percentage` | `25` |
| Seven-day reset | `rate_limits.seven_day.resets_at` | `1792296000` (Unix seconds) |
| Cache warm state | `prompt_cache.warm` | `true` |
| Cache TTL | `prompt_cache.ttl` | `"1h"` |
| Cache expiry | `prompt_cache.expires_at` | `1791778836` (Unix seconds) |
| Cache hit ratio | `prompt_cache.hit_ratio` | `0.9935554697221347` |
| Cache request/miss counts | `prompt_cache.requests`, `prompt_cache.misses` | `243`, `0` |

The sample also contains `prompt_cache.caching_observed`, `expected_rebuilds`,
`cache_write_tokens`, `miss_recache_tokens`, `last_miss_at`, `last_miss_cause`,
`miss_causes`, and `recache_tokens_if_cold`. The requested `warm`, `ttl`, and
`expires_at` fields therefore exist, and their expiry timestamp is Unix seconds.

## Bridge

`scripts/statusline-bridge.sh` reads one stdin JSON document, writes it to
`~/Library/Application Support/CacheBar/sessions/<session_id>.json` using a
same-directory temporary file and `mv`, then leaves the original bytes on stdout.
Malformed JSON, missing or unsafe session IDs, unavailable `jq`, and filesystem
errors all return status 0 after stdout has been preserved so a statusline keeps running.

Suggested owner-side change to `~/.claude/statusline-command.sh` (apply manually;
this task does not modify home-directory files): replace the temporary sample line
after `input=$(cat)` with:

```diff
-printf '%s' "$input" > "$HOME/Library/Application Support/CacheBar/statusline-sample.json"
+printf '%s' "$input" | /path/to/CacheBar/scripts/statusline-bridge.sh >/dev/null
```

Use the absolute checkout path for `/path/to/CacheBar` when installing. The bridge
is deliberately before the existing statusline rendering command and its output can
be discarded because the existing script already has the captured input.
