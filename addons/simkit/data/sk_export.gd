class_name SkExport
extends RefCounted
## Turns an SkLog into files the student or teacher can keep: one JSON file with everything, or CSV for
## the events and for any table. Saving goes through SkHost.save_text_file: a browser download on the
## web, a file in user://exports/ elsewhere. No server, no account, nothing leaves the device by itself.

const FORMAT_NAME: String = "simkit-session"
const FORMAT_VERSION: int = 1


## The whole session as JSON text. `extra` is merged into the top level (e.g. {"lesson": "predators-1"}).
static func to_json(log: SkLog, extra: Dictionary = {}) -> String:
	var tables: Dictionary = {}
	for name: String in log.tables:
		tables[name] = {"columns": Array(log.tables[name]["columns"]), "rows": log.tables[name]["rows"]}
	var out: Dictionary = {
		"format": FORMAT_NAME,
		"format_version": FORMAT_VERSION,
		"framework_version": SkHost.VERSION,
		"app": log.app_name,
		"context": log.session.describe() if log.session != null else {},
		"responses": log.responses,
		"events": log.events,
		"tables": tables,
		"kept_runs": log.kept_runs,
	}
	out.merge(extra, false)
	return JSON.stringify(out, "\t")


## Events as CSV: n, ms, sim_time, kind, data (the data as compact JSON in one quoted cell).
static func events_csv(log: SkLog) -> String:
	var rows: Array = []
	for e: Dictionary in log.events:
		rows.append([e["n"], e["ms"], e["sim_time"], e["kind"], JSON.stringify(e["data"])])
	return to_csv(PackedStringArray(["n", "ms", "sim_time", "kind", "data"]), rows)


## One table as CSV.
static func table_csv(log: SkLog, name: String) -> String:
	if not log.tables.has(name):
		return ""
	var t: Dictionary = log.tables[name]
	return to_csv(t["columns"], t["rows"])


## RFC 4180 CSV: cells containing a comma, quote or line break are quoted, quotes are doubled.
## Cells starting with = + - @ are prefixed with ' so a spreadsheet never runs them as formulas.
static func to_csv(columns: PackedStringArray, rows: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(",".join(Array(columns).map(_cell)))
	for row: Array in rows:
		lines.append(",".join(row.map(_cell)))
	return "\r\n".join(lines) + "\r\n"


## Saves JSON and returns SkHost.save_text_file's result ("" on the web, a path elsewhere, "ERROR").
static func save_json(log: SkLog, filename: String = "", extra: Dictionary = {}) -> String:
	var name: String = filename if filename != "" else "%s-session.json" % log.app_name
	return SkHost.save_text_file(name, to_json(log, extra), "application/json")


static func save_events_csv(log: SkLog, filename: String = "") -> String:
	var name: String = filename if filename != "" else "%s-events.csv" % log.app_name
	return SkHost.save_text_file(name, events_csv(log), "text/csv")


static func save_table_csv(log: SkLog, table_name: String, filename: String = "") -> String:
	var name: String = filename if filename != "" else "%s-%s.csv" % [log.app_name, table_name]
	return SkHost.save_text_file(name, table_csv(log, table_name), "text/csv")


static func _cell(v: Variant) -> String:
	var text: String = ""
	if v is float:
		text = String.num(v).trim_suffix(".0")
	else:
		text = str(v)
	if text.length() > 0 and "=+-@".contains(text[0]) and not (v is float or v is int):
		text = "'" + text
	if text.contains(",") or text.contains("\"") or text.contains("\n") or text.contains("\r"):
		text = "\"" + text.replace("\"", "\"\"") + "\""
	return text
