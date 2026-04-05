#!/usr/bin/env bash
# Run all Manage User Data plugin tests.
# Usage: bash tests/run_all.sh
# Requires Godot 4.3+ accessible as 'godot' in PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GODOT="${GODOT_BIN:-godot}"
FAILED=0
TOTAL=0

run_test() {
    local test_file="$1"
    local test_name
    test_name="$(basename "$test_file" .gd)"
    TOTAL=$((TOTAL + 1))

    echo ""
    echo "── Running: $test_name ──"
    if "$GODOT" --headless --path "$PROJECT_DIR" --script "$test_file" 2>&1; then
        echo "✓ $test_name passed"
    else
        echo "✗ $test_name FAILED"
        FAILED=$((FAILED + 1))
    fi
}

echo "╔══════════════════════════════════════════╗"
echo "║   Manage User Data — Test Suite          ║"
echo "╚══════════════════════════════════════════╝"

run_test "tests/test_format_file_size.gd"
run_test "tests/test_file_type_label.gd"
run_test "tests/test_filter_logic.gd"
run_test "tests/test_file_operations.gd"

echo ""
echo "════════════════════════════════════════════"
echo "Results: $((TOTAL - FAILED))/$TOTAL suites passed"
if [ "$FAILED" -gt 0 ]; then
    echo "$FAILED suite(s) FAILED"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
