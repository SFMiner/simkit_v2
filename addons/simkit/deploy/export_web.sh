#!/bin/bash
# Exports a Godot project to the web and checks the result against the sims-site hosting contract.
# Usage:  bash export_web.sh <project_dir> <out_dir> [preset_name]     (GODOT=path/to/godot)
# Needs the matching Godot export templates installed, an export preset named "Web" in the project, and
# Python 3 (python3 or python) for the pck scan. Exits non-zero on any FAIL.
set -u
GODOT="${GODOT:-godot}"
PROJECT="${1:?project dir}"
OUT="${2:?output dir}"
PRESET="${3:-Web}"
fail=0
note() { echo "  $1"; }

# A portable byte search for the pck scan (binutils' strings is often missing, e.g. in Git Bash on Windows,
# and a missing tool must never read as "no leaks").
PYTHON=""
for p in python3 python; do
	if command -v "$p" > /dev/null 2>&1 && "$p" -c "import sys; assert sys.version_info >= (3,)" > /dev/null 2>&1; then
		PYTHON="$p"; break
	fi
done
[ -n "$PYTHON" ] || { echo "FAIL Python 3 is needed for the pck scan and was not found (python3 or python)"; exit 1; }

mkdir -p "$OUT" || { echo "FAIL cannot create $OUT"; exit 1; }
# Godot runs with --path, so a relative output path would be resolved inside the project: make it absolute.
OUT="$(cd "$OUT" && { pwd -W 2>/dev/null || pwd; })"

"$GODOT" --headless --path "$PROJECT" --import > /dev/null 2>&1
"$GODOT" --headless --path "$PROJECT" --export-release "$PRESET" "$OUT/index.html" 2>&1 | grep -E "ERROR|error:" && fail=1
echo "Checking $OUT"
missing=0
for f in index.html index.pck index.wasm; do
	if [ -f "$OUT/$f" ]; then note "OK   $f present at the export root"; else note "FAIL no $f at the export root"; missing=1; fi
done
if [ $missing -ne 0 ]; then
	note "STOP the export did not produce these files, so nothing else was checked"
	exit 1
fi
if ls "$OUT"/*.worker.js > /dev/null 2>&1 || grep -q 'GODOT_THREADS_ENABLED = true' "$OUT/index.html"; then
	note "FAIL threads are enabled (the host does not send cross-origin-isolation headers)"; fail=1
else
	note "OK   no threads"
fi
# The pck must not carry tests, docs, notes or private paths.
LEAKS=$("$PYTHON" - "$OUT/index.pck" <<'PY'
import re, sys
data = open(sys.argv[1], "rb").read()
word = rb"[\x21-\x7e]"
pattern = re.compile(rb"res://(?:tests|docs)/" + word + rb"*"
		+ rb"|" + word + rb"+\.md(?!" + word + rb")"
		+ rb"|/home/" + word + rb"*"
		+ rb"|[A-Za-z]:[\\/]Users[\\/]" + word + rb"*")
seen = []
for m in pattern.finditer(data):
	text = m.group().decode("ascii", "replace")
	if text not in seen:
		seen.append(text)
print("\n".join(seen[:5]))
PY
)
SCAN=$?
if [ $SCAN -ne 0 ]; then
	note "FAIL the pck scan did not run"; fail=1
elif [ -n "$LEAKS" ]; then
	note "FAIL pck contains files that should be excluded:"; echo "$LEAKS" | sed 's/^/        /'; fail=1
else
	note "OK   pck has no tests, docs or home paths"
fi
grep -q "sk-status" "$OUT/index.html" && note "OK   live regions present (custom shell)" || note "WARN default shell: screen-reader announcements go nowhere (set html/custom_html_shell)"
SIZE=$(du -sk "$OUT" | cut -f1); note "INFO total export size ${SIZE} KB"
exit $fail
