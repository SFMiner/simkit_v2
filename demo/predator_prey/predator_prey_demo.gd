extends SkSplitView
## Demo 1: rabbits and foxes. A CONTINUOUS model stepped at a fixed 0.02 month (SkSession FIXED_STEP).
## Uses every SimKit module: params + panel, session + transport, line graph, gauge, kept run,
## lesson panel (predict -> observe -> explain), log + JSON/CSV export, accessibility settings.
## The model (predator_prey_model.gd) knows nothing about any of this.

const MONTHS: float = 120.0
const SAMPLE_EVERY: float = 0.5
const START_NAMES: PackedStringArray = ["Balanced", "Few foxes", "Many foxes"]
const LESSON: Dictionary = {
	"title": "Rabbits and foxes",
	"objectives": [
		"Explain why predator and prey populations rise and fall in a repeating pattern.",
		"Predict how a change in the food supply changes both populations.",
	],
	"instructions": "Press Start. Watch both lines. While it runs, change the food supply or the foxes' hunting success and watch what happens next.",
	"prediction": {"id": "predict_food", "prompt": "If the food supply is doubled, the rabbit population will end up",
		"choices": ["lower", "about the same", "higher"]},
	"observations": [
		{"id": "observe_lag", "prompt": "Which population peaks first after a fox boom?", "choices": ["rabbits", "foxes", "both together"]},
		"Look at the gauge: when do rabbits get close to the food supply?",
	],
	"explanation": "Rabbits increase when foxes are few. More rabbits give foxes more food, so foxes increase a little later. More foxes eat more rabbits, so rabbits fall, then the foxes go hungry and fall too. In this model the balance point for rabbits depends on how well foxes hunt, not on the food supply, so a bigger food supply mostly feeds more foxes.",
	"reflection": ["Real rabbits and foxes have other food, disease and weather. What would change if the model included them?"],
	"vocabulary": {"predator": "An animal that hunts and eats other animals.", "prey": "An animal that is hunted and eaten.", "carrying capacity": "The most animals an environment can feed for a long time."},
}

var a11y: SkA11y = null
var model: PredatorPreyModel = PredatorPreyModel.new()
var params: SkParams = SkParams.new()
var session: SkSession = SkSession.new()
var log: SkLog = SkLog.new()
var transport: SkTransportBar = SkTransportBar.new()
var param_panel: SkParamPanel = SkParamPanel.new()
var a11y_panel: SkParamPanel = SkParamPanel.new()
var lesson_panel: SkLessonPanel = SkLessonPanel.new()
var graph: SkLineGraph = SkLineGraph.new()
var gauge: SkGauge = SkGauge.new()
var field: PopulationField = PopulationField.new()
var status: Label = null
var keep_button: Button = null
var json_button: Button = null
var csv_button: Button = null
var save_note: Label = null

var _next_sample: float = 0.0
var _announced_extinct: Dictionary = {}


func setup(p_a11y: SkA11y) -> void:
	a11y = p_a11y


func _ready() -> void:
	_define_params()
	params.apply_query(SkHost.query_string())
	params.changed.connect(_on_param_changed)

	session.mode = SkSession.Mode.FIXED_STEP
	session.clock.step = 0.02
	session.duration = MONTHS
	session.params = params
	session.lock_params_after_start = true
	session.reset_when_ready_changes()
	session.on_step = _on_step
	session.on_reset = _on_reset
	session.finished.connect(func(reason: String) -> void: _say_summary("Finished: " + reason))
	session.state_changed.connect(_on_state)
	add_child(session)
	log.app_name = "predator-prey"
	log.attach(session)

	_build_ui()
	session.reset()


func _process(_delta: float) -> void:
	field.calm = a11y != null and a11y.reduced_motion()
	if session.is_running() and not field.calm:
		field.queue_redraw()


## Controls in Tab order (SkFocusRing).
func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	out.append_array(transport.focus_controls())
	out.append_array(param_panel.focus_controls())
	out.append_array([keep_button, json_button, csv_button])
	out.append_array(lesson_panel.focus_controls())
	out.append_array(a11y_panel.focus_controls())
	return out


# === PRIVATE ===
## Before Start the session rebuilds the starting picture itself (reset_when_ready_changes, in _ready).
## After Start a change only affects the model's rates; the populations carry on from where they are.
func _on_param_changed(_id: String, _v: Variant) -> void:
	if session.state != SkSession.State.READY:
		_apply_params()


func _define_params() -> void:
	params.add(SkParam.float_param("growth", "Rabbit birth rate", 0.8, 0.2, 1.5, 0.05).with_unit("per month")
			.with_help("How fast rabbits breed when there is plenty of food."))
	params.add(SkParam.float_param("capacity", "Food supply (most rabbits the land can feed)", 100.0, 60.0, 400.0, 10.0)
			.with_help("A bigger food supply lets more rabbits live without foxes.").as_class_setting())
	var hunting: SkParam = SkParam.float_param("hunting", "Fox hunting success", 0.02, 0.005, 0.04, 0.005)
	hunting.decimals = 3
	params.add(hunting.with_help("How many rabbits a fox catches. Very low success and the foxes starve."))
	params.add(SkParam.choice_param("start", "Starting foxes", START_NAMES, 1).locked_while_running()
			.with_help("Chosen before you press Start. 'Balanced' begins exactly at the balance point, so nothing changes until you change a setting.").as_class_setting())


func _apply_params() -> void:
	model.growth = params.get_float("growth")
	model.capacity = params.get_float("capacity")
	model.hunting = params.get_float("hunting")
	_refresh_gauge()


func _on_reset() -> void:
	_apply_params()
	model.reset(params.get_int("start"))
	graph.remove_series("rabbits")
	graph.remove_series("foxes")
	log.table("populations", PackedStringArray(["run", "month", "rabbits", "foxes"]))   # keeps earlier runs
	_next_sample = 0.0
	_announced_extinct.clear()
	_sample(0.0)
	_next_sample = SAMPLE_EVERY
	if status != null:
		status.text = "Press Start. Everything is paused until you do."


func _on_step(dt: float) -> void:
	model.step(dt)
	var t: float = session.sim_time + dt
	while t + 1e-9 >= _next_sample:
		_sample(_next_sample)
		_next_sample += SAMPLE_EVERY


func _sample(t: float) -> void:
	graph.append_point("rabbits", "Rabbits", t, model.rabbits)
	graph.append_point("foxes", "Foxes", t, model.foxes)
	log.add_row("populations", [session.run_number, snappedf(t, 0.01), snappedf(model.rabbits, 0.01), snappedf(model.foxes, 0.01)])
	field.rabbits = model.rabbits
	field.foxes = model.foxes
	field.queue_redraw()
	_refresh_gauge()
	if status != null:
		status.text = "Month %d: about %d rabbits and %d foxes." % [int(t), int(round(model.rabbits)), int(round(model.foxes))]
	if model.foxes == 0.0 and not _announced_extinct.has("foxes") and t > 0.0:
		_announced_extinct["foxes"] = true
		SkHost.announce("The foxes have died out.", true)
		status.text += " The foxes have died out."
	if model.rabbits == 0.0 and not _announced_extinct.has("rabbits") and t > 0.0:
		_announced_extinct["rabbits"] = true
		SkHost.announce("The rabbits have died out.", true)
		status.text += " The rabbits have died out."


func _refresh_gauge() -> void:
	gauge.value = model.rabbits / model.capacity * 100.0


func _on_state(s: int) -> void:
	if s == SkSession.State.PAUSED:
		_say_summary("Paused")


func _say_summary(prefix: String) -> void:
	SkHost.announce("%s. %s" % [prefix, graph.describe()])


func _keep_run() -> void:
	var series: Dictionary = {}
	for id: String in ["rabbits", "foxes"]:
		var pts: PackedVector2Array = graph.series_points(id)
		if pts.is_empty():
			continue
		graph.set_series(id + "_kept", ("Rabbits" if id == "rabbits" else "Foxes") + " (kept)", pts, true)
		series[id] = Array(pts).map(func(p: Vector2) -> Array: return [p.x, p.y])
	log.keep_run("A", series, {"note": "kept for comparison"})
	SkHost.announce("This run is kept as dashed lines. Start another run to compare.")
	save_note.text = "Kept. The dashed lines show the earlier run."


func _save(kind: String) -> void:
	var result: String = SkExport.save_json(log) if kind == "json" else SkExport.save_table_csv(log, "populations")
	if result == "ERROR":
		save_note.text = "Could not save the file."
	elif result == "":
		save_note.text = "Your browser is saving the file."
	else:
		save_note.text = "Saved: " + result
	SkHost.announce(save_note.text)


func _build_ui() -> void:
	# main pane: the field, the graph, the gauge
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	field.custom_minimum_size = Vector2(240.0, 170.0)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(field)
	graph.title = "Populations over time"
	graph.x_label = "Month"
	graph.x_range = Vector2(0.0, MONTHS)
	graph.auto_y = true
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(240.0, 220.0)
	left.add_child(graph)
	gauge.heading = "Rabbits compared with the food supply"
	gauge.unit = "%"
	gauge.min_value = 0.0
	gauge.max_value = 150.0
	gauge.bands = [{"lo": 10.0, "hi": 90.0, "label": "comfortable"}]
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(gauge)

	# side pane: the controls (SkSplitView scrolls it, or stacks it under the main pane in a narrow frame)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	transport.speeds = [2.0, 4.0, 8.0]
	transport.bind(session)
	right.add_child(transport)
	status = SkUi.label("", 0, true)
	right.add_child(status)
	param_panel.bind(params)
	right.add_child(param_panel)
	var actions: HFlowContainer = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	right.add_child(actions)
	keep_button = SkUi.button("Keep this run")
	keep_button.pressed.connect(_keep_run)
	json_button = SkUi.button("Save my data (JSON)")
	json_button.pressed.connect(_save.bind("json"))
	csv_button = SkUi.button("Save table (CSV)")
	csv_button.pressed.connect(_save.bind("csv"))
	for b: Button in [keep_button, json_button, csv_button]:
		actions.add_child(b)
	save_note = SkUi.label("", 0, true)
	right.add_child(save_note)
	lesson_panel.log = log
	lesson_panel.explanation_requires_prediction = true
	lesson_panel.show_lesson(SkLesson.from_dict(LESSON))
	right.add_child(lesson_panel)
	right.add_child(SkUi.label("Display settings", 0, true))
	a11y_panel.show_reset = false
	a11y_panel.bind(a11y.params if a11y != null else SkA11y.new().params)
	right.add_child(a11y_panel)
	set_panes(left, right)


## Cosmetic picture of the two populations: a dot per ~4 rabbits, a triangle per ~2 foxes.
## It reads the model's numbers and never changes them. Shapes (not only colours) tell the species apart.
class PopulationField extends Control:
	var rabbits: float = 0.0
	var foxes: float = 0.0
	var calm: bool = false

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var fsize: int = maxi(get_theme_default_font_size() - 3, 11)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.14, 0.27, 0.16))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.8, 0.7), false, 1.0)
		var area: Rect2 = Rect2(10.0, 10.0, size.x - 20.0, size.y - 38.0)
		var t: float = 0.0 if calm else Time.get_ticks_msec() / 1000.0
		for i: int in range(mini(int(ceil(rabbits / 4.0)), 80)):
			var p: Vector2 = _spot(i, 0.0, area) + Vector2(0.0, sin(t * 3.0 + float(i)) * 2.5)
			draw_circle(p, 6.0, Color(0.96, 0.94, 0.9))
			draw_arc(p, 6.0, 0.0, TAU, 16, Color(0.1, 0.1, 0.1), 1.5, true)
		for i: int in range(mini(int(ceil(foxes / 2.0)), 50)):
			var p2: Vector2 = _spot(i, 37.0, area) + Vector2(sin(t * 2.0 + float(i)) * 2.5, 0.0)
			var tri: PackedVector2Array = PackedVector2Array([p2 + Vector2(0, -9), p2 + Vector2(8, 6), p2 + Vector2(-8, 6)])
			draw_colored_polygon(tri, Color(0.93, 0.5, 0.12))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.1, 0.1, 0.1), 1.5, true)
		draw_string(font, Vector2(10.0, size.y - 10.0), "Circle = about 4 rabbits.  Triangle = about 2 foxes.  (%d rabbits, %d foxes)" % [int(round(rabbits)), int(round(foxes))],
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, fsize, Color(0.92, 0.95, 0.98))

	## A fixed pseudo-random spot for animal number `i` (stable as the population changes).
	func _spot(i: int, salt: float, area: Rect2) -> Vector2:
		var fx: float = fposmod(sin(float(i) * 12.9898 + salt) * 43758.5453, 1.0)
		var fy: float = fposmod(sin(float(i) * 78.233 + salt * 1.7) * 24634.6345, 1.0)
		return area.position + Vector2(fx * area.size.x, fy * area.size.y)
