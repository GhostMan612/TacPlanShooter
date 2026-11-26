#!/usr/bin/env bash
set -u
log="$1"
shift
if [ ! -s "$log" ]; then
  echo "::error::$log is empty"
  exit 1
fi
bad=$(grep -vF 'ERROR: Condition "!m" is true' "$log" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|\bFAIL\b|^ERROR:|^\s*ERROR:" | grep -viE "resources still in use at exit|ObjectDB instances leaked|StringName: .* unclaimed|mesh_get_surface_count|Condition .!m. is true")
if [ -n "$bad" ]; then
  echo "::error::$log contains failures"
  echo "$bad" | head -40
  exit 1
fi
for need in "$@"; do
  if ! grep -qF -- "$need" "$log"; then
    echo "::error::$log is missing required marker: $need"
    exit 1
  fi
done
echo "gate ok: $log"

