class_name SkParamPanel
extends VBoxContainer
## Builds a labelled control for every parameter in an SkParams, and keeps them in step in both directions:
## the player moves a slider -> params.set_value(); code (or reset) changes a value -> the slider follows.
##   FLOAT / INT  -> a slider with a value read-out
##   BOOL         -> a check box
##   CHOICE       -> a row of toggle buttons (not an OptionButton: it works in the lean 2D web template)
## Params flagged lock_while_running are disabled while params.locked is true.
## Only basic controls are used, all keyboard-focusable and at least 44 px high.
##
##   var panel := SkParamPanel.new()
##   panel.bind(params)                        # or panel.bind(params, PackedStringArray(["rate", "mode"]))
##   side.add_child(panel)
##   ring.provider = func(): return panel.focus_controls() + [...]

# === SIGNALS ===
## The player (not code) changed a parameter.
signal edited(id: String, value: Variant)

# === PUBLIC VARIABLES ===
var params: SkParams = null
## Show a "Reset" button at the bottom that restores every bound parameter's default.
var show_reset: bool = true
var reset_text: String = "Reset settings"
## Say each change to screen readers (SkHost.announce).
var announce_changes: bool = true

# === PRIVATE VARIABLES ===
var _rows: Dictionary = {}
var _bound_ids: PackedStringArray = PackedStringArray()
var _reset_button: Button = null
var _dragging: bool = false


# === PUBLIC METHODS ===
## Builds the controls. `ids` selects and orders a subset; empty = every param. Safe to call again to rebuild.
func bind(p_params: SkParams, ids: PackedStringArray = PackedStringArray()) -> void:
	_unbind()
	params = p_params
	_bound_ids = ids if not ids.is_empty() else PackedStringArray(params.ids())
	add_theme_constant_override("separation", 10)
	for id: String in _bound_ids:
		if params.has(id):
			_build_row(params.spec(id))
	if show_reset:
		_reset_button = SkUi.button(reset_text)
		_reset_button.pressed.connect(_on_reset_pressed)
		add_child(_reset_button)
	params.changed.connect(_on_params_changed)
	params.locked_changed.connect(_on_locked_changed)
	_on_locked_changed(params.locked)


## Every focusable control, top to bottom, for SkFocusRing.
func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	for id: String in _bound_ids:
		if _rows.has(id):
			for c: Control in _rows[id]["controls"]:
				out.append(c)
	if _reset_button != null:
		out.append(_reset_button)
	return out


func control_for(id: String) -> Control:
	return (_rows[id]["controls"][0] as Control) if _rows.has(id) else null


# === PRIVATE METHODS ===
func _unbind() -> void:
	if params != null:
		if params.changed.is_connected(_on_params_changed):
			params.changed.disconnect(_on_params_changed)
		if params.locked_changed.is_connected(_on_locked_changed):
			params.locked_changed.disconnect(_on_locked_changed)
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_rows.clear()
	_reset_button = null


func _build_row(spec: SkParam) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.tooltip_text = spec.help
	add_child(box)
	var row: Dictionary = {"spec": spec, "controls": [] as Array[Control]}
	match spec.kind:
		SkParam.Kind.FLOAT, SkParam.Kind.INT:
			var head: Label = SkUi.label(spec.label, 0, true)
			box.add_child(head)
			var line: HBoxContainer = HBoxContainer.new()
			line.add_theme_constant_override("separation", 10)
			box.add_child(line)
			var slider: HSlider = HSlider.new()
			slider.min_value = spec.min_value
			slider.max_value = spec.max_value
			slider.step = spec.step if spec.step > 0.0 else (spec.max_value - spec.min_value) / 200.0
			slider.focus_mode = Control.FOCUS_ALL
			slider.custom_minimum_size = Vector2(120.0, SkUi.TOUCH_MIN)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.tooltip_text = spec.help
			slider.value = float(params.get_value(spec.id))
			slider.value_changed.connect(_on_slider_changed.bind(spec.id))
			slider.drag_started.connect(func() -> void: _dragging = true)
			slider.drag_ended.connect(_on_drag_ended.bind(spec.id))
			line.add_child(slider)
			var readout: Label = SkUi.label("", 0)
			readout.custom_minimum_size.x = 150.0
			readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(readout)
			row["slider"] = slider
			row["readout"] = readout
			(row["controls"] as Array[Control]).append(slider)
		SkParam.Kind.BOOL:
			var check: CheckBox = CheckBox.new()
			check.text = spec.label
			check.focus_mode = Control.FOCUS_ALL
			check.custom_minimum_size = Vector2(0.0, SkUi.TOUCH_MIN)
			check.tooltip_text = spec.help
			check.toggled.connect(_on_check_toggled.bind(spec.id))
			box.add_child(check)
			row["check"] = check
			(row["controls"] as Array[Control]).append(check)
		SkParam.Kind.CHOICE:
			box.add_child(SkUi.label(spec.label, 0, true))
			var flow: HFlowContainer = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			box.add_child(flow)
			var group: ButtonGroup = ButtonGroup.new()
			var buttons: Array[Button] = []
			for i: int in range(spec.choices.size()):
				var b: Button = SkUi.button(spec.choices[i], true)
				b.button_group = group
				b.tooltip_text = spec.help
				b.pressed.connect(_on_choice_pressed.bind(spec.id, i))
				flow.add_child(b)
				buttons.append(b)
				(row["controls"] as Array[Control]).append(b)
			row["buttons"] = buttons
	_rows[spec.id] = row
	_sync_row(spec.id)


## Writes the current value into the row's controls without triggering their signals.
func _sync_row(id: String) -> void:
	var row: Dictionary = _rows[id]
	var spec: SkParam = row["spec"]
	var value: Variant = params.get_value(id)
	match spec.kind:
		SkParam.Kind.FLOAT, SkParam.Kind.INT:
			(row["slider"] as HSlider).set_value_no_signal(float(value))
			(row["readout"] as Label).text = spec.format(value)
		SkParam.Kind.BOOL:
			(row["check"] as CheckBox).set_pressed_no_signal(bool(value))
		SkParam.Kind.CHOICE:
			var buttons: Array[Button] = row["buttons"]
			for i: int in range(buttons.size()):
				buttons[i].set_pressed_no_signal(i == int(value))


func _on_params_changed(id: String, _value: Variant) -> void:
	if _rows.has(id):
		_sync_row(id)
		if params.locked:
			_on_locked_changed(true)


func _on_locked_changed(is_locked: bool) -> void:
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var spec: SkParam = row["spec"]
		var disable: bool = is_locked and spec.lock_while_running
		for c: Control in row["controls"]:
			if c is BaseButton:
				# A disabled button loses its "selected" look, so the chosen option of a locked CHOICE stays
				# enabled (pressing it changes nothing: the params refuse the change) and the rest are disabled.
				var keep_visible: bool = spec.kind == SkParam.Kind.CHOICE and (c as BaseButton).button_pressed
				(c as BaseButton).disabled = disable and not keep_visible
			elif c is Slider:
				(c as Slider).editable = not disable


func _on_slider_changed(value: float, id: String) -> void:
	if params.set_value(id, value):
		edited.emit(id, params.get_value(id))
		if not _dragging:
			_say(id)
	_sync_row(id)


func _on_drag_ended(_value_changed: bool, id: String) -> void:
	_dragging = false
	_say(id)


func _on_check_toggled(pressed: bool, id: String) -> void:
	if params.set_value(id, pressed):
		edited.emit(id, params.get_value(id))
		_say(id)
	_sync_row(id)


func _on_choice_pressed(id: String, index: int) -> void:
	if params.set_value(id, index):
		edited.emit(id, params.get_value(id))
		_say(id)
	_sync_row(id)


func _on_reset_pressed() -> void:
	for id: String in _bound_ids:
		if params.has(id):
			params.reset(id)
	SkHost.announce("Settings reset")


func _say(id: String) -> void:
	if announce_changes:
		SkHost.announce("%s: %s" % [params.spec(id).label, params.get_text(id)])
