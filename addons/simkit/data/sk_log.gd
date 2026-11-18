class_name SkLog
extends RefCounted
## An in-memory record of what happened in one sitting: lifecycle events, parameter changes, the
## student's multiple-choice answers, tables of measurements, and kept runs for comparison.
## Nothing is stored or sent anywhere. The only way data leaves is SkExport.save_*, which the player triggers.
##
## Privacy by design: it records no names, no ids, no dates, no free text. Times are milliseconds since the
## log was created and simulation time. Responses are choices from lists YOU wrote.
##
##   var log := SkLog.new()
##   log.attach(session)                      # records start / pause / reset / finish + param changes
##   log.record("note", {"what": "opened help"})
##   log.add_row("populations", [t, rabbits, foxes])      # after log.table("populations", ["t", "rabbits", "foxes"])
##
## Tables keep every run. Calling table() again with the same columns (e.g. from on_reset) keeps the rows;
## add session.run_number as a column to tell runs apart. When attached, rows written for a starting
## picture that was replaced before it ever ran (a settings change or new seed while READY) are dropped,
## so the export holds each real run once. clear_table() empties a table on purpose.
##
## Limits: consecutive changes of one parameter are merged into one "param" event (with a "changes" count).
## Past MAX_EVENTS only the run's lifecycle and the student's answers are kept; anything else is counted in
## dropped_events, after one "log_full" event. Rows past MAX_ROWS are counted in dropped_rows. Nothing is
## lost without a count, and the JSON export carries both counts. detach() stops recording.

# === CONSTANTS ===
const MAX_EVENTS: int = 5000
const MAX_ROWS: int = 20000
## Event kinds still recorded after MAX_EVENTS is reached: the run's lifecycle and the student's answers.
const KEPT_KINDS: PackedStringArray = ["state", "reset", "finished", "response", "explanation_shown"]
const KEPT_RESERVE: int = 1000

# === PUBLIC VARIABLES ===
var app_name: String = "simulation"
## Array of {"n": int, "ms": int, "sim_time": float, "kind": String, "data": Dictionary}
var events: Array[Dictionary] = []
## Array of {"prompt_id": String, "prompt": String, "choice": String, "ms": int}
var responses: Array[Dictionary] = []
## name -> {"columns": PackedStringArray, "rows": Array, "runs": PackedInt32Array (session.run_number per row)}
var tables: Dictionary = {}
## slot -> {"meta": Dictionary, "series": Dictionary}
var kept_runs: Dictionary = {}
var session: SkSession = null
var params: SkParams = null
## Events not recorded because the log was full (see record()). SkExport.to_json includes it.
var dropped_events: int = 0
## Rows refused because their table held MAX_ROWS rows. SkExport.to_json includes it.
var dropped_rows: int = 0

# === PRIVATE VARIABLES ===
var _started_ms: int = Time.get_ticks_msec()
var _counter: int = 0


# === PUBLIC METHODS ===
## Records session lifecycle and parameter changes automatically.
func attach(p_session: SkSession, p_params: SkParams = null) -> void:
	detach()
	session = p_session
	params = p_params if p_params != null else p_session.params
	# Bound methods, not lambdas: a lambda that captures this log, connected to a signal of an object the
	# log holds, is a reference cycle and neither is ever freed.
	session.state_changed.connect(_on_state_changed)
	session.reset_done.connect(_on_reset_done)
	session.finished.connect(_on_finished)
	session.resetting.connect(_on_resetting)
	if params != null:
		params.changed.connect(_on_param_changed)


## Stops recording the session and parameters (attach() again to resume). Safe to call when not attached.
func detach() -> void:
	if session != null:
		for pair: Array in [[session.state_changed, _on_state_changed], [session.reset_done, _on_reset_done],
				[session.finished, _on_finished], [session.resetting, _on_resetting]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	if params != null and params.changed.is_connected(_on_param_changed):
		params.changed.disconnect(_on_param_changed)
	session = null
	params = null


## Adds an event. `data` should hold only numbers, strings, bools and arrays/dictionaries of them.
## Past MAX_EVENTS, only the kinds in KEPT_KINDS are still recorded (up to MAX_EVENTS + KEPT_RESERVE);
## the rest are counted in dropped_events, and one "log_full" event marks where dropping began.
func record(kind: String, data: Dictionary = {}) -> void:
	if events.size() >= MAX_EVENTS:
		if not KEPT_KINDS.has(kind) or events.size() >= MAX_EVENTS + KEPT_RESERVE:
			if dropped_events == 0:
				_append("log_full", {"max_events": MAX_EVENTS})
			dropped_events += 1
			return
	_append(kind, data)


func _append(kind: String, data: Dictionary) -> void:
	events.append({
		"n": _counter,
		"ms": Time.get_ticks_msec() - _started_ms,
		"sim_time": session.sim_time if session != null else 0.0,
		"kind": kind,
		"data": data.duplicate(true),
	})
	_counter += 1


## Stores a multiple-choice answer (a prediction, an observation, a reflection).
func record_response(prompt_id: String, prompt: String, choice: String) -> void:
	responses.append({"prompt_id": prompt_id, "prompt": prompt, "choice": choice,
			"ms": Time.get_ticks_msec() - _started_ms})
	record("response", {"prompt_id": prompt_id, "choice": choice})


## Creates a table. Called again with the same columns it keeps the existing rows (returns true); with
## different columns it warns and changes nothing (returns false). Use clear_table() to empty one.
func table(name: String, columns: PackedStringArray) -> bool:
	if tables.has(name):
		if (tables[name]["columns"] as PackedStringArray) == columns:
			return true
		push_warning("SkLog.table('%s'): already exists with columns %s; refusing to replace it with %s. Use clear_table() or a new name." % [
				name, str(tables[name]["columns"]), str(columns)])
		return false
	tables[name] = {"columns": columns, "rows": [], "runs": PackedInt32Array()}
	return true


## Removes every row of a table, keeping its columns. Returns false if the table is unknown.
func clear_table(name: String) -> bool:
	if not tables.has(name):
		return false
	(tables[name]["rows"] as Array).clear()
	tables[name]["runs"] = PackedInt32Array()
	return true


## Appends one row (same length as the table's columns). Returns false if the table is unknown, the row
## has the wrong length, or the table is full.
func add_row(name: String, row: Array) -> bool:
	if not tables.has(name):
		return false
	var t: Dictionary = tables[name]
	if row.size() != (t["columns"] as PackedStringArray).size():
		return false
	if (t["rows"] as Array).size() >= MAX_ROWS:
		dropped_rows += 1
		return false
	(t["rows"] as Array).append(row.duplicate())
	var runs: PackedInt32Array = t.get("runs", PackedInt32Array())
	runs.append(session.run_number if session != null else 0)
	t["runs"] = runs
	return true


## Keeps a deep copy of a finished run under `slot` ("A", "B") so a later run can be compared with it.
func keep_run(slot: String, series: Dictionary, meta: Dictionary = {}) -> void:
	var full_meta: Dictionary = meta.duplicate(true)
	if session != null:
		full_meta.merge(session.describe(), false)
	kept_runs[slot] = {"meta": full_meta, "series": series.duplicate(true)}


func kept_run(slot: String) -> Dictionary:
	return (kept_runs[slot] as Dictionary).duplicate(true) if kept_runs.has(slot) else {}


func clear() -> void:
	events.clear()
	responses.clear()
	tables.clear()
	kept_runs.clear()
	dropped_events = 0
	dropped_rows = 0
	_counter = 0
	_started_ms = Time.get_ticks_msec()


## Count of events of one kind.
func count(kind: String) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if e["kind"] == kind:
			n += 1
	return n


# === PRIVATE METHODS ===
func _on_state_changed(s: int) -> void:
	record("state", {"state": SkSession.State.keys()[s]})


func _on_reset_done() -> void:
	record("reset", {"seed": session.seed_value if session != null else 0})


func _on_finished(reason: String) -> void:
	record("finished", {"reason": reason})


## A run of changes to one parameter with nothing else in between (a slider drag, repeated clicks) is one
## event: its value is the latest, "changes" counts them. This keeps a long drag from filling the log.
func _on_param_changed(id: String, v: Variant) -> void:
	var value: Variant = _plain(params.spec(id) if params != null else null, v)
	if not events.is_empty() and dropped_events == 0:
		var last: Dictionary = events[events.size() - 1]
		if last["kind"] == "param" and last["data"].get("id", "") == id:
			last["data"]["value"] = value
			last["data"]["changes"] = int(last["data"].get("changes", 1)) + 1
			last["ms"] = Time.get_ticks_msec() - _started_ms
			return
	record("param", {"id": id, "value": value, "changes": 1})


## The run being replaced never started: its rows only described a starting picture that is now gone.
func _on_resetting(run_started: bool) -> void:
	if run_started or session == null or session.run_number <= 0:
		return
	var current: int = session.run_number
	for name: String in tables:
		var t: Dictionary = tables[name]
		var runs: PackedInt32Array = t.get("runs", PackedInt32Array())
		var rows: Array = t["rows"]
		if runs.size() != rows.size():
			continue   # rows were added around add_row(); leave the table alone
		var kept_rows: Array = []
		var kept_runs: PackedInt32Array = PackedInt32Array()
		for i: int in range(rows.size()):
			if runs[i] != current:
				kept_rows.append(rows[i])
				kept_runs.append(runs[i])
		t["rows"] = kept_rows
		t["runs"] = kept_runs


static func _plain(spec: SkParam, v: Variant) -> Variant:
	return spec.choices[int(v)] if spec != null and spec.kind == SkParam.Kind.CHOICE else v
