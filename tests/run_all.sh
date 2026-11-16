#!/bin/bash
# Runs every headless SimKit test. From the project root:  GODOT=godot bash tests/run_all.sh
# A suite fails if it exits non-zero, prints "SCRIPT ERROR" / "Parse Error", or does not print PASS.
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . --import > /dev/null 2>&1   # registers the class_names first
FAILED=0
for suite in test_params test_session test_platform test_modules test_models test_demos test_isolation; do
	OUT=$(timeout 300 "$GODOT" --headless --path . --script "res://tests/$suite.gd" 2>&1)
	CODE=$?
	echo "$OUT" | grep -E "^  FAIL|: [0-9]+/[0-9]+ passed"
	if [ $CODE -ne 0 ] || echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error" || ! echo "$OUT" | grep -q -- "-> PASS"; then
		FAILED=$((FAILED + 1)); echo "FAILED: $suite"
		echo "$OUT" | grep -E "SCRIPT ERROR|Parse Error" | head -5
	fi
done
echo "Suites failed: $FAILED"
exit $FAILED
