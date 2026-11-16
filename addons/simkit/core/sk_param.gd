class_name SkParam
extends RefCounted
## Specification of ONE adjustable simulation parameter: its id, label, type, default and limits.
## It holds no current value (SkParams does), so a spec can be shared and reused freely.
## Build one with the static helpers: SkParam.float_param("rate", "Growth rate", 0.5, 0.0, 2.0, 0.05).

# === ENUMS ===
enum Kind { FLOAT, INT, BOOL, CHOICE }

# === PUBLIC VARIABLES ===
var id: String = ""
var label: String = ""
var kind: Kind = Kind.FLOAT
var default_value: Variant = 0.0
var min_value: float = 0.0
var max_value: float = 1.0
## Snap size for FLOAT/INT values. 0 = continuous (FLOAT) / 1 (INT).
var step: float = 0.0
## CHOICE only: the option names. The stored value is the option's index.
var choices: PackedStringArray = PackedStringArray()
var unit: String = ""
## One or two sentences of contextual help (shown as a tooltip by SkParamPanel).
var help: String = ""
## If true, SkParams rejects changes while its `locked` flag is set (SkSession can set it once a run starts).
var lock_while_running: bool = false
## If true, the value may be set from the page address, e.g. ?rate=0.8 (SkParams.apply_query).
var class_setting: bool = false
## Digits shown after the decimal point. -1 = derive from `step`.
var decimals: int = -1


# === STATIC CONSTRUCTORS ===
static func float_param(p_id: String, p_label: String, p_default: float, p_min: float, p_max: float,
		p_step: float = 0.0) -> SkParam:
	var p: SkParam = SkParam.new()
	p.id = p_id
	p.label = p_label
	p.kind = Kind.FLOAT
	p.default_value = p_default
	p.min_value = p_min
	p.max_value = p_max
	p.step = p_step
	return p


static func int_param(p_id: String, p_label: String, p_default: int, p_min: int, p_max: int,
		p_step: int = 1) -> SkParam:
	var p: SkParam = SkParam.new()
	p.id = p_id
	p.label = p_label
	p.kind = Kind.INT
	p.default_value = p_default
	p.min_value = float(p_min)
	p.max_value = float(p_max)
	p.step = float(maxi(p_step, 1))
	return p


static func bool_param(p_id: String, p_label: String, p_default: bool) -> SkParam:
	var p: SkParam = SkParam.new()
	p.id = p_id
	p.label = p_label
	p.kind = Kind.BOOL
	p.default_value = p_default
	return p


static func choice_param(p_id: String, p_label: String, p_choices: PackedStringArray,
		p_default: int = 0) -> SkParam:
	var p: SkParam = SkParam.new()
	p.id = p_id
	p.label = p_label
	p.kind = Kind.CHOICE
	p.choices = p_choices
	p.default_value = p_default
	p.max_value = float(maxi(p_choices.size() - 1, 0))
	return p


# === FLUENT SETTERS (so a spec fits on one line) ===
func with_help(text: String) -> SkParam:
	help = text
	return self


func with_unit(text: String) -> SkParam:
	unit = text
	return self


func locked_while_running() -> SkParam:
	lock_while_running = true
	return self


func as_class_setting() -> SkParam:
	class_setting = true
	return self


# === PUBLIC METHODS ===
## Returns `v` made valid for this parameter (clamped, snapped, converted), or null if it cannot be used
## (wrong type, NaN/infinity, unknown choice, choice index out of range).
func coerce(v: Variant) -> Variant:
	match kind:
		Kind.FLOAT:
			if not (v is float or v is int):
				return null
			var f: float = float(v)
			if not is_finite(f):
				return null
			f = clampf(f, min_value, max_value)
			if step > 0.0:
				f = clampf(min_value + roundf((f - min_value) / step) * step, min_value, max_value)
			return f
		Kind.INT:
			if not (v is float or v is int):
				return null
			var fv: float = float(v)
			if not is_finite(fv):
				return null
			var s: float = maxf(step, 1.0)
			var snapped_value: float = min_value + roundf((clampf(fv, min_value, max_value) - min_value) / s) * s
			return int(clampf(snapped_value, min_value, max_value))
		Kind.BOOL:
			if v is bool:
				return v
			return null
		Kind.CHOICE:
			if v is int:
				var index: int = v
				return index if index >= 0 and index < choices.size() else null
			if v is String:
				var found: int = choices.find(v)
				return found if found >= 0 else null
			return null
	return null


## Parses text from a page address. Unlike coerce(), out-of-range numbers are rejected, not clamped.
## Returns null when the text is not acceptable.
func parse_text(raw: String) -> Variant:
	var text: String = raw.strip_edges()
	match kind:
		Kind.FLOAT:
			if not text.is_valid_float():
				return null
			var f: float = text.to_float()
			return f if is_finite(f) and f >= min_value and f <= max_value else null
		Kind.INT:
			if not text.is_valid_int():
				return null
			var i: int = text.to_int()
			return i if float(i) >= min_value and float(i) <= max_value else null
		Kind.BOOL:
			var lower: String = text.to_lower()
			if lower == "on" or lower == "true" or lower == "1" or lower == "yes":
				return true
			if lower == "off" or lower == "false" or lower == "0" or lower == "no":
				return false
			return null
		Kind.CHOICE:
			for i: int in range(choices.size()):
				if choices[i].to_lower() == text.to_lower():
					return i
			return null
	return null


## Human-readable value, with its unit: "0.50 per month", "On", "Large".
func format(v: Variant) -> String:
	var text: String = ""
	match kind:
		Kind.FLOAT:
			text = "%.*f" % [_digits(), float(v)]
		Kind.INT:
			text = "%d" % int(v)
		Kind.BOOL:
			text = "On" if bool(v) else "Off"
		Kind.CHOICE:
			var index: int = int(v)
			text = choices[index] if index >= 0 and index < choices.size() else "?"
	if unit != "" and kind != Kind.BOOL and kind != Kind.CHOICE:
		text += " " + unit
	return text


## Problems with the spec itself (not with a value). Empty when fine.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id.strip_edges().is_empty():
		errors.append("a parameter has no id")
	if label.strip_edges().is_empty():
		errors.append("%s: label is empty" % id)
	match kind:
		Kind.FLOAT, Kind.INT:
			if not (is_finite(min_value) and is_finite(max_value)) or min_value >= max_value:
				errors.append("%s: min must be less than max" % id)
			if step < 0.0:
				errors.append("%s: step must not be negative" % id)
		Kind.CHOICE:
			if choices.is_empty():
				errors.append("%s: no choices" % id)
	if coerce(default_value) == null:
		errors.append("%s: default value is not valid for its type" % id)
	elif kind == Kind.FLOAT or kind == Kind.INT:
		var d: float = float(default_value)
		if d < min_value or d > max_value:
			errors.append("%s: default is outside min..max" % id)
		elif absf(float(coerce(default_value)) - d) > 1e-9:
			errors.append("%s: default is not on the step grid (min + k * step)" % id)
	return errors


# === PRIVATE METHODS ===
func _digits() -> int:
	if decimals >= 0:
		return decimals
	if step <= 0.0:
		return 2
	# Fewest digits that show every multiple of `step` exactly (0.25 -> 2, 0.05 -> 2, 0.5 -> 1, 5 -> 0).
	for d: int in range(0, 7):
		var scaled: float = step * pow(10.0, float(d))
		if absf(scaled - roundf(scaled)) < 1e-6:
			return d
	return 6
