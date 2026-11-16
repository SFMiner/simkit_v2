#!/bin/bash
# Exports a Godot project to the web and checks the result against the sims-site hosting contract.
# Usage:  bash export_web.sh <project_dir> <out_dir> [preset_name]     (GODOT=path/to/godot)
# Needs the matching Godot export templates installed, and an export preset named "Web" in the project.
set -u
GODOT="${GODOT:-godot}"
PROJECT="${1:?project dir}"
OUT="${2:?output dir}"
PRESET="${3:-Web}"
fail=0
note() { echo "  $1"; }
mkdir -p "$OUT"
"$GODOT" --headless --path "$PROJECT" --import > /dev/null 2>&1
"$GODOT" --headless --path "$PROJECT" --export-release "$PRESET" "$OUT/index.html" 2>&1 | grep -E "ERROR|error:" && fail=1
echo "Checking $OUT"
[ -f "$OUT/index.html" ] && note "OK   index.html is at the export root" || { note "FAIL no index.html at the root"; fail=1; }
[ -f "$OUT/index.pck" ] && note "OK   index.pck present" || { note "FAIL no index.pck"; fail=1; }
[ -f "$OUT/index.wasm" ] && note "OK   index.wasm present" || { note "FAIL no index.wasm"; fail=1; }
if ls "$OUT"/*.worker.js > /dev/null 2>&1 || grep -q 'GODOT_THREADS_ENABLED = true' "$OUT/index.html"; then
	note "FAIL threads are enabled (the host does not send cross-origin-isolation headers)"; fail=1
else
	note "OK   no threads"
fi
# The pck must not carry tests, docs, notes or private paths.
LEAKS=$(strings "$OUT/index.pck" 2>/dev/null | grep -E "res://(tests|docs)/|\.md$|/home/|C:\\\\Users" | head -5)
if [ -n "$LEAKS" ]; then note "FAIL pck contains files that should be excluded:"; echo "$LEAKS" | sed 's/^/        /'; fail=1; else note "OK   pck has no tests, docs or home paths"; fi
grep -q "sk-status" "$OUT/index.html" && note "OK   live regions present (custom shell)" || note "WARN default shell: screen-reader announcements go nowhere (set html/custom_html_shell)"
SIZE=$(du -sk "$OUT" | cut -f1); note "INFO total export size ${SIZE} KB"
exit $fail
