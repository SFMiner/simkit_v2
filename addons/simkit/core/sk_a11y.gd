class_name SkA11y
extends RefCounted
## Accessibility and comfort settings every simulation can offer: text size, high contrast, reduced motion.
## They are ordinary SkParams, so SkParamPanel shows them with no extra UI code:
##   a11y.params  ->  param_panel.bind(a11y.params)
##
## Defaults follow the browser (prefers-reduced-motion, prefers-contrast). Once the player changes a
## setting, their choice is kept (in user://, which in a browser is local to that browser) and wins.
## Settings only change presentation. They must never change simulation results: your drawing code asks
## `a11y.reduced_motion()` and `a11y.anim_time()`; your model never does.
##
##   var a11y := SkA11y.new()
##   a11y.load_saved(); a11y.read_browser()
##   a11y.bind(root_control, scaler)         # theme + text size now follow the settings

# === SIGNALS ===
signal changed

# === CONSTANTS ===
const TEXT_SCALES: Array[float] = [1.0, 1.2, 1.4]
const TEXT_NAMES: PackedStringArray = ["Normal", "Large", "Extra large"]
const ID_TEXT: String = "text_size"
const ID_CONTRAST: String = "high_contrast"
const ID_MOTION: String = "reduced_motion"

# === PUBLIC VARIABLES ===
var params: SkParams = SkParams.new()
## Which palette is used when high contrast is off: "dark" or "light".
var base_palette: String = "dark"
## Tests and previews turn this off so they never write the player's saved file.
var persist: bool = true
var save_path: String = "user://simkit_a11y.cfg"
var font_size: int = SkTheme.FONT_SIZE

# === PRIVATE VARIABLES ===
var _chosen: Dictionary = {}
var _quiet: bool = false
## [WeakRef root, WeakRef scaler or null] per bind() call.
var _bound: Array[Array] = []


# === LIFECYCLE METHODS ===
func _init() -> void:
	params.add(SkParam.choice_param(ID_TEXT, "Text size", TEXT_NAMES, 0).with_help(
			"Makes all text and controls larger."))
	params.add(SkParam.bool_param(ID_CONTRAST, "High contrast", false).with_help(
			"Black background, white text, thick outlines."))
	params.add(SkParam.bool_param(ID_MOTION, "Reduced motion", false).with_help(
			"Stops drifting, pulsing and sliding animation. Results do not change."))
	params.changed.connect(_on_param_changed)


# === PUBLIC METHODS ===
func text_scale() -> float:
	return TEXT_SCALES[params.get_int(ID_TEXT)]


func high_contrast() -> bool:
	return params.get_bool(ID_CONTRAST)


func reduced_motion() -> bool:
	return params.get_bool(ID_MOTION)


func palette_name() -> String:
	return "high_contrast" if high_contrast() else base_palette


func build_theme() -> Theme:
	return SkTheme.build(palette_name(), font_size)


## Seconds an animation should take: 0 when reduced motion is on (jump straight to the end state).
func anim_time(seconds: float) -> float:
	return 0.0 if reduced_motion() else seconds


## Browser preferences become the defaults for anything the player has not chosen. Web only.
func read_browser() -> void:
	_quiet = true
	if not _chosen.has(ID_MOTION):
		params.set_value(ID_MOTION, SkHost.prefers_reduced_motion())
	if not _chosen.has(ID_CONTRAST):
		params.set_value(ID_CONTRAST, SkHost.prefers_high_contrast())
	_quiet = false
	changed.emit()


func load_saved() -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(save_path) != OK:
		return
	_quiet = true
	for id: String in params.ids():
		if cf.has_section_key("a11y", id):
			if params.set_value(id, cf.get_value("a11y", id)):
				_chosen[id] = true
	_quiet = false
	changed.emit()


func save() -> void:
	if not persist:
		return
	var cf: ConfigFile = ConfigFile.new()
	for id: String in _chosen:
		cf.set_value("a11y", id, params.get_value(id))
	cf.save(save_path)


## Applies the settings to `root` (its theme) and `scaler` (its text size), now and after every change.
## Targets are held weakly: freeing the scene frees them, and this object no longer touches them.
func bind(root: Control, scaler: SkViewScaler = null) -> void:
	_bound.append([weakref(root), weakref(scaler) if scaler != null else null])
	_apply_bound()
	if not changed.is_connected(_apply_bound):
		changed.connect(_apply_bound)


# === PRIVATE METHODS ===
## A bound method, not a lambda: a lambda capturing this object, connected to its own signal, is a
## reference cycle that keeps it alive forever.
func _apply_bound() -> void:
	var live: Array[Array] = []
	for pair: Array in _bound:
		var root: Control = (pair[0] as WeakRef).get_ref() as Control
		if root == null:
			continue
		live.append(pair)
		root.theme = build_theme()
		var scaler: SkViewScaler = (pair[1] as WeakRef).get_ref() as SkViewScaler if pair[1] != null else null
		if scaler != null:
			scaler.text_scale = text_scale()
	_bound = live


func _on_param_changed(id: String, _value: Variant) -> void:
	if _quiet:
		return
	_chosen[id] = true
	save()
	changed.emit()
