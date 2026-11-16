class_name SkParams
extends RefCounted
## The current values of a set of SkParam specs, with validation, defaults and reset.
## The simulation reads values with get_value(); the UI (or the page address) writes them with set_value().
## Nothing here knows about nodes, drawing or time.
##
##   var params := SkParams.new()
##   params.add(SkParam.float_param("rate", "Growth rate", 0.5, 0.0, 2.0, 0.05))
##   params.changed.connect(func(id, value): print(id, " -> ", value))
##   params.set_value("rate", 1.2)

# === SIGNALS ===
## Emitted only when a value actually changes.
signal changed(id: String, value: Variant)
signal locked_changed(is_locked: bool)

# === CONSTANTS ===
const MAX_QUERY_LENGTH: int = 512

# === PUBLIC VARIABLES ===
## While true, params whose spec says lock_while_running reject changes. SkSession drives this.
var locked: bool = false:
	set(v):
		if v != locked:
			locked = v
			locked_changed.emit(v)

# === PRIVATE VARIABLES ===
var _specs: Dictionary = {}
var _order: Array[String] = []
var _values: Dictionary = {}


# === PUBLIC METHODS ===
## Registers a spec. Returns it. A duplicate id replaces nothing and is refused (returns null).
func add(spec: SkParam) -> SkParam:
	if spec == null or _specs.has(spec.id):
		push_warning("SkParams.add: missing spec or duplicate id '%s'" % (spec.id if spec != null else ""))
		return null
	_specs[spec.id] = spec
	_order.append(spec.id)
	var start: Variant = spec.coerce(spec.default_value)
	_values[spec.id] = start if start != null else spec.default_value
	return spec


func has(id: String) -> bool:
	return _specs.has(id)


## Ids in the order they were added.
func ids() -> Array[String]:
	return _order.duplicate()


func spec(id: String) -> SkParam:
	return _specs.get(id) as SkParam


func get_value(id: String) -> Variant:
	if not _values.has(id):
		push_error("SkParams.get_value: unknown parameter '%s'" % id)
		return null
	return _values[id]


func get_float(id: String) -> float:
	return float(get_value(id))


func get_int(id: String) -> int:
	return int(get_value(id))


func get_bool(id: String) -> bool:
	return bool(get_value(id))


## Value as text: the option name for a CHOICE, "On"/"Off" for a BOOL...
func get_text(id: String) -> String:
	return spec(id).format(get_value(id))


## Sets a value. Numbers are clamped and snapped; anything unusable is refused.
## Returns false (and changes nothing) for an unknown id, an unusable value, or a locked param.
## Returns true when the value was accepted, even if it equals the old one.
func set_value(id: String, value: Variant) -> bool:
	return _assign(id, value, false)


func reset(id: String) -> void:
	if _specs.has(id):
		_assign(id, spec(id).default_value, true)


## Returns every value to its default (ignores the lock: a reset starts fresh).
func reset_all() -> void:
	for id: String in _order:
		_assign(id, spec(id).default_value, true)


func is_default(id: String) -> bool:
	return _values.get(id) == spec(id).coerce(spec(id).default_value)


## id -> raw value (a CHOICE is its index). Round-trips through from_dict().
func to_dict() -> Dictionary:
	return _values.duplicate(true)


## id -> readable value (a CHOICE is its option name). For exports and reports.
func to_labeled_dict() -> Dictionary:
	var out: Dictionary = {}
	for id: String in _order:
		var s: SkParam = spec(id)
		out[id] = s.choices[int(_values[id])] if s.kind == SkParam.Kind.CHOICE else _values[id]
	return out


## Applies saved values (ignores the lock). Returns messages for ids that are unknown or whose value was refused.
func from_dict(data: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for key: Variant in data:
		var id: String = str(key)
		if not _specs.has(id):
			problems.append("unknown parameter '%s'" % id)
		elif not _assign(id, data[key], true):
			problems.append("value for '%s' not usable" % id)
	return problems


## Reads a page address such as "?rate=0.8&mode=fast" and applies only the params marked class_setting.
## Unknown keys, unusable and out-of-range values are ignored, so the address can never break the sim.
## The text is only compared and parsed as numbers; it is never used as a path or run as code.
## Returns the values it applied: id -> value.
func apply_query(search: String) -> Dictionary:
	var applied: Dictionary = {}
	var text: String = search.strip_edges()
	if text.begins_with("?"):
		text = text.substr(1)
	if text.length() > MAX_QUERY_LENGTH:
		return applied
	for pair: String in text.split("&", false):
		var parts: PackedStringArray = pair.split("=", true, 1)
		if parts.size() != 2:
			continue
		var id: String = parts[0].uri_decode()
		if not _specs.has(id) or not spec(id).class_setting:
			continue
		var parsed: Variant = spec(id).parse_text(parts[1].uri_decode())
		if parsed != null and _assign(id, parsed, true):
			applied[id] = _values[id]
	return applied


## Markdown table of the class settings, for the "Registry facts" section of a README.
func class_settings_markdown() -> String:
	var lines: PackedStringArray = PackedStringArray(["| Key | Type | Values | Default | Effect |", "|---|---|---|---|---|"])
	for id: String in _order:
		var s: SkParam = spec(id)
		if not s.class_setting:
			continue
		var type_name: String = "number"
		var values: String = "%s to %s" % [s.format(s.min_value), s.format(s.max_value)]
		match s.kind:
			SkParam.Kind.INT:
				type_name = "whole number"
			SkParam.Kind.BOOL:
				type_name = "on/off"
				values = "`on`, `off`"
			SkParam.Kind.CHOICE:
				type_name = "choice"
				values = ", ".join(Array(s.choices).map(func(c: String) -> String: return "`%s`" % c))
		lines.append("| `%s` | %s | %s | %s | %s |" % [id, type_name, values, s.format(s.default_value), s.help])
	return "\n".join(lines)


## Problems with the specs themselves. Empty when everything is consistent.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for id: String in _order:
		errors.append_array(spec(id).validate())
	return errors


# === PRIVATE METHODS ===
func _assign(id: String, value: Variant, force: bool) -> bool:
	var s: SkParam = _specs.get(id) as SkParam
	if s == null:
		return false
	if locked and s.lock_while_running and not force:
		return false
	var clean: Variant = s.coerce(value)
	if clean == null:
		return false
	if _values[id] != clean:
		_values[id] = clean
		changed.emit(id, clean)
	return true
