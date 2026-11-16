#!/usr/bin/env bash
# Headless smoke test: a host bot and a client bot play a match.
# Usage: tools/run_autotest.sh [path-to-godot-console-exe]
# Env: MAX_TURNS=N makes the host leave mid-match after N turns.
# Exit 0 only if both bots PASS and no script errors were logged.
set -u
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-/c/Program Files (x86)/Godot/Godot_v4.3-stable_mono_win64_console.exe}}"
OUT="${AUTOTEST_OUT:-.godot/autotest}"
mkdir -p "$OUT"
"$GODOT" --headless --path . -- --autotest=host --max-turns=${MAX_TURNS:-30} > "$OUT/host.log" 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --path . -- --autotest=client > "$OUT/client.log" 2>&1 &
CLIENT=$!
wait $HOST; H=$?
wait $CLIENT; C=$?
NOISE='Unreferenced static|string_name.cpp|PagedAllocator|Thread object|wait_to_finish|thread.cpp|ObjectDB instances leaked|resources still in use|at exit'
FAIL=0
for role in host client; do
  echo "== $role =="
  grep -h "AUTOTEST PASS" "$OUT/$role.log" || { grep -h "AUTOTEST" "$OUT/$role.log" || echo "no result line"; FAIL=1; }
  if grep -E "SCRIPT ERROR|^ERROR" "$OUT/$role.log" | grep -Ev "$NOISE" | head -20 | grep .; then FAIL=1; fi
  # Godot 4.3 mono sometimes segfaults while shutting down after a network
  # session (BUG-004). Only a warning when the bot already reported PASS.
  if grep -q "CrashHandlerException" "$OUT/$role.log"; then echo "warning: Godot crashed on exit (BUG-004)"; fi
done
[ $FAIL -eq 0 ] && echo "SMOKE TEST PASSED" && exit 0
echo "SMOKE TEST FAILED (host=$H client=$C) — logs in $OUT/"; exit 1
