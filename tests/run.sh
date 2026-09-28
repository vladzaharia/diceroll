#!/bin/sh
# Runs the headless test suite and fails on any script/runtime error, which
# Godot reports to the log without aborting the test method.
cd "$(dirname "$0")/.." || exit 1
out=$(godot --headless --path . -s tests/run_tests.gd -- "$@" 2>&1)
code=$?
echo "$out" | grep -E "FAIL|passed|SCRIPT ERROR|ERROR:" 
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
	echo "Script errors detected -> failing"
	exit 1
fi
exit $code
