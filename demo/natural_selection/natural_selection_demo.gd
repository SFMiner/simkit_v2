extends SkSplitView
## Demo 2: natural selection in moths. A DISCRETE, stochastic, turn-driven model (SkSession MANUAL mode):
## time passes only when the student presses "Next generation". It deliberately uses LESS of SimKit than
## demo 1: no lesson panel, no gauge, no kept runs. That is the point: modules are optional.
## Reproducible: the seed is shown, and Reset replays the same random history.

const MAX_GENERATIONS: int = 200

var a11y: SkA11y = null
var model: SelectionModel = SelectionModel.new()
var params: SkParams = SkParams.new()
var session: SkSession = SkSession.new()
var log: SkLog = SkLog.new()
var transport: SkTransportBar = SkTransportBar.new()
var param_panel: SkParamPanel = SkParamPanel.new()
var a11y_panel: SkParamPanel = SkParamPanel.new()
var graph: SkLineGraph = SkLineGraph.new()
var field: MothField = MothField.new()
var status: Label = null
var ten_button: Button = null
var seed_button: Button = null
var json_button: Button = null
var save_note: Label = null


func setup(p_a11y: SkA11y) -> void:
	a11y = p_a11y


func _ready() -> void:
	params.add(SkParam.float_param("bark", "Tree bark darkness", 0.8, 0.0, 1.0, 0.1)
			.with_help("0 = pale birch bark, 1 = dark, sooty bark."))
	params.add(SkParam.float_param("predation", "Bird hunting strength", 0.5, 0.0, 0.9, 0.05)
			.with_help("How strongly birds pick out moths that stand out against the bark."))
	var mutation: SkParam = SkParam.float_param("mutation", "Colour mutation chance", 0.01, 0.0, 0.05, 0.005)
	mutation.decimals = 3
	params.add(mutation.with_help("Chance a baby moth is born the other colour."))
	params.add(SkParam.int_param("moths", "Number of moths", 100, 20, 200, 20).locked_while_running())
	params.add(SkParam.int_param("start_dark", "Dark moths at the start", 10, 0, 100, 10).locked_while_running()
			.with_unit("%").as_class_setting())
	params.apply_query(SkHost.query_string())
	params.changed.connect(_on_param_changed)

	session.mode = SkSession.Mode.MANUAL
	session.manual_dt = 1.0
	session.duration = float(MAX_GENERATIONS)
	session.params = params
	session.lock_params_after_start = true
	session.reset_when_ready_changes()
	session.seed_value = 2024
	session.on_step = _on_generation
	session.on_reset = _on_reset
	session.finished.connect(func(reason: String) -> void: _finished(reason))
	add_child(session)
	log.app_name = "natural-selection"
	log.attach(session)

	_build_ui()
	session.reset()


func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	out.append_array(transport.focus_controls())
	out.append_array([ten_button, seed_button])
	out.append_array(param_panel.focus_controls())
	out.append(json_button)
	out.append_array(a11y_panel.focus_controls())
	return out


# === PRIVATE ===
## Before Start the session rebuilds the starting picture itself (reset_when_ready_changes, in _ready).
## After Start a change only affects the model's rates; the populations carry on from where they are.
func _on_param_changed(_id: String, _v: Variant) -> void:
	if session.state != SkSession.State.READY:
		_apply_params()


func _apply_params() -> void:
	model.bark = params.get_float("bark")
	model.predation = params.get_float("predation")
	model.mutation = params.get_float("mutation")
	field.bark = model.bark


func _on_reset() -> void:
	_apply_params()
	model.reset(params.get_int("moths"), params.get_int("start_dark"))
	graph.clear()
	graph.append_point("dark", "Dark moths", 0.0, model.dark_fraction() * 100.0)
	log.table("generations", PackedStringArray(["run", "generation", "dark_moths", "moths"]))   # keeps earlier runs
	log.add_row("generations", [session.run_number, 0, model.dark_count(), model.moths.size()])
	field.moths = model.moths
	field.queue_redraw()
	if status != null:
		_update_status("Press Next generation to let the birds hunt.")


func _on_generation(_dt: float) -> void:
	_apply_params()
	if not model.next_generation(session.rng):
		session.finish("the moths died out")
		return
	graph.append_point("dark", "Dark moths", float(model.generation), model.dark_fraction() * 100.0)
	log.add_row("generations", [session.run_number, model.generation, model.dark_count(), model.moths.size()])
	field.moths = model.moths
	field.queue_redraw()
	_update_status("")
	if session.state != SkSession.State.RUNNING:
		SkHost.announce("Generation %d. %d of %d moths are dark." % [model.generation, model.dark_count(), model.moths.size()])


func _finished(reason: String) -> void:
	_update_status("Finished: " + reason + ".")
	SkHost.announce("Finished: " + reason, true)


func _update_status(extra: String) -> void:
	var pct: int = int(round(model.dark_fraction() * 100.0))
	status.text = ("Generation %d: %d of %d moths are dark (%d%%). Seed %d. %s" % [
			model.generation, model.dark_count(), model.moths.size(), pct, session.seed_value, extra]).strip_edges()


func _ten_more() -> void:
	for i: int in range(10):
		if session.state == SkSession.State.FINISHED:
			break
		session.step_once()


func _new_seed() -> void:
	session.reset(true)
	save_note.text = "New random history (seed %d). Reset replays it exactly." % session.seed_value


func _save() -> void:
	var result: String = SkExport.save_json(log)
	save_note.text = "Your browser is saving the file." if result == "" else ("Could not save the file." if result == "ERROR" else "Saved: " + result)
	SkHost.announce(save_note.text)


func _build_ui() -> void:
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	field.custom_minimum_size = Vector2(240.0, 230.0)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(field)
	graph.title = "Share of dark moths"
	graph.x_label = "Generation"
	graph.auto_x = true
	graph.auto_y = false
	graph.y_range = Vector2(0.0, 100.0)
	graph.y_format = "%.0f%%"
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(240.0, 200.0)
	left.add_child(graph)

	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	transport.show_play = false
	transport.show_speed = false
	transport.step_text = "Next generation"
	transport.bind(session)
	right.add_child(transport)
	var more: HFlowContainer = HFlowContainer.new()
	more.add_theme_constant_override("h_separation", 6)
	more.add_theme_constant_override("v_separation", 6)
	right.add_child(more)
	ten_button = SkUi.button("+10 generations")
	ten_button.pressed.connect(_ten_more)
	seed_button = SkUi.button("New random history")
	seed_button.pressed.connect(_new_seed)
	more.add_child(ten_button)
	more.add_child(seed_button)
	status = SkUi.label("", 0, true)
	right.add_child(status)
	param_panel.bind(params)
	right.add_child(param_panel)
	json_button = SkUi.button("Save my data (JSON)")
	json_button.pressed.connect(_save)
	right.add_child(json_button)
	save_note = SkUi.label("", 0, true)
	right.add_child(save_note)
	right.add_child(SkUi.label("Display settings", 0, true))
	a11y_panel.show_reset = false
	a11y_panel.bind(a11y.params if a11y != null else SkA11y.new().params)
	right.add_child(a11y_panel)
	set_panes(left, right)


## The moths on the bark. Dark moths are dark with a light outline, light moths are light with a dark
## outline, so each stays visible on any bark colour and no one has to tell colours apart.
class MothField extends Control:
	var moths: PackedByteArray = PackedByteArray()
	var bark: float = 0.8

	func _draw() -> void:
		var bark_color: Color = Color(0.86, 0.80, 0.68).lerp(Color(0.16, 0.13, 0.11), bark)
		draw_rect(Rect2(Vector2.ZERO, size), bark_color)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.8, 0.8), false, 1.0)
		if moths.is_empty():
			return
		var area: Rect2 = Rect2(14.0, 14.0, size.x - 28.0, size.y - 28.0)
		var cols: int = maxi(1, int(ceil(sqrt(float(moths.size()) * area.size.x / maxf(area.size.y, 1.0)))))
		var rows: int = int(ceil(float(moths.size()) / float(cols)))
		var cell: Vector2 = Vector2(area.size.x / float(cols), area.size.y / float(rows))
		var radius: float = clampf(minf(cell.x, cell.y) * 0.36, 3.0, 11.0)
		for i: int in range(moths.size()):
			var c: Vector2 = area.position + Vector2((float(i % cols) + 0.5) * cell.x, (float(i / cols) + 0.5) * cell.y)
			if moths[i] == 1:
				draw_circle(c, radius, Color(0.08, 0.07, 0.07))
				draw_arc(c, radius, 0.0, TAU, 16, Color(0.97, 0.97, 0.97), 2.0, true)
			else:
				draw_circle(c, radius, Color(0.97, 0.95, 0.9))
				draw_arc(c, radius, 0.0, TAU, 16, Color(0.08, 0.07, 0.07), 2.0, true)
