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

# === CONSTANTS ===
const MAX_EVENTS: int = 5000
const MAX_ROWS: int = 20000

# === PUBLIC VARIABLES ===
var app_name: String = "simulation"
## Array of {"n": int, "ms": int, "sim_time": float, "kind": String, "data": Dictionary}
var events: Array[Dictionary] = []
## Array of {"prompt_id": String, "prompt": String, "choice": String, "ms": int}
var responses: Array[Dictionary] = []
## name -> {"columns": PackedStringArray, "rows": Array}
var tables: Dictionary = {}
## slot -> {"meta": Dictionary, "series": Dictionary}
var kept_runs: Dictionary = {}
var session: SkSession = null
var params: SkParams = null

# === PRIVATE VARIABLES ===
var _started_ms: int = Time.get_ticks_msec()
var _counter: int = 0


# === PUBLIC METHODS ===
## Records session lifecycle and parameter changes automatically.
func attach(p_session: SkSession, p_params: SkParams = null) -> void:
	session = p_session
	params = p_params if p_params != null else p_session.params
	session.state_changed.connect(func(s: int) -> void:
		record("state", {"state": SkSession.State.keys()[s]}))
	session.reset_done.connect(func() -> void: record("reset", {"seed": session.seed_value}))
	session.finished.connect(func(reason: String) -> void: record("finished", {"reason": reason}))
	if params != null:
		params.changed.connect(func(id: String, v: Variant) -> void:
			record("param", {"id": id, "value": _plain(params.spec(id), v)}))


## Adds an event. `data` should hold only numbers, strings, bools and arrays/dictionaries of them.
func record(kind: String, data: Dictionary = {}) -> void:
	if events.size() >= MAX_EVENTS:
		return
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


func table(name: String, columns: PackedStringArray) -> void:
	tables[name] = {"columns": columns, "rows": []}


## Appends one row (same length as the table's columns). Returns false if the table is unknown, the row
## has the wrong length, or the table is full.
func add_row(name: String, row: Array) -> bool:
	if not tables.has(name):
		return false
	var t: Dictionary = tables[name]
	if row.size() != (t["columns"] as PackedStringArray).size() or (t["rows"] as Array).size() >= MAX_ROWS:
		return false
	(t["rows"] as Array).append(row.duplicate())
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
static func _plain(spec: SkParam, v: Variant) -> Variant:
	return spec.choices[int(v)] if spec != null and spec.kind == SkParam.Kind.CHOICE else v
