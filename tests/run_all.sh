#!/usr/bin/env bash
# Run all Manage User Data plugin checks.
# Usage: GODOT_BIN=/path/to/godot bash tests/run_all.sh
# Requires Godot 4.7 (the project target); 'godot' on PATH by default.
#
# 1. Parse-checks every addon script (a parse error disables the plugin).
# 2. Runs each test suite. Suites are SceneTree scripts that print
#    "N passed, M failed" and exit non-zero on any failure. A suite that
#    exits 0 without printing its summary (e.g. it never ran) also fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT="${GODOT_BIN:-godot}"
TIMEOUT="${TEST_TIMEOUT:-120}"
FAILED=0
TOTAL=0

echo "== Parse check (addons/manage_user_data)"
for script in "$PROJECT_DIR"/addons/manage_user_data/*.gd; do
    rel="res://${script#"$PROJECT_DIR"/}"
    if ! timeout "$TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --check-only --script "$rel" >/tmp/mud_check.txt 2>&1; then
        cat /tmp/mud_check.txt
        echo "x parse check failed: $rel"
        FAILED=$((FAILED + 1))
    else
        echo "ok $rel"
    fi
done

for test_file in "$PROJECT_DIR"/tests/test_*.gd; do
    test_name="$(basename "$test_file" .gd)"
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "-- Running: $test_name"
    out="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --script "res://tests/$test_name.gd" 2>&1)"
    code=$?
    echo "$out" | grep -E "FAIL|passed|SCRIPT ERROR|Parse Error" || true
    if [ "$code" -ne 0 ] || ! echo "$out" | grep -qE "[0-9]+ passed, 0 failed"; then
        echo "x $test_name FAILED (exit $code)"
        FAILED=$((FAILED + 1))
    else
        echo "ok $test_name"
    fi
done

echo ""
echo "Results: $TOTAL suites run, $FAILED failure(s)"
[ "$FAILED" -eq 0 ]
