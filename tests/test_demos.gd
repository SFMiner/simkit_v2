extends SkTest
## The two demos, end to end: wiring, determinism, locking, export, keyboard, query settings.

var _expected: int = 0


func _menu(query: String = "") -> Node:
	SkHost.query_override = query
	var scene: Node = load("res://demo/main.tscn").instantiate()
	root.add_child(scene)
	await frames(2)
	return scene


func _drive(session: SkSession, seconds: float) -> void:
	session.auto_process = false
	var t: float = 0.0
	while t < seconds:
		session.advance(1.0 / 60.0)
		t += 1.0 / 60.0


func _min_touch(controls: Array[Control]) -> float:
	var smallest: float = INF
	for c: Control in controls:
		if c is BaseButton or c is Slider:
			smallest = minf(smallest, c.get_combined_minimum_size().y)
	return smallest


func run() -> void:
	test_name = "test_demos"
	await _test_menu()
	await _test_predator_prey()
	await _test_selection()
	await _test_cooling()
	await _test_query()
	finish(_expected)


func _test_menu() -> void:
	var scene: Node = await _menu()
	check(scene.current == null and scene.current_id == "menu", "menu: boots to the menu, nothing running")
	var ring: Array = scene._ring()
	check(ring.size() == 2 + 3 + 1 + 0 or ring.size() >= 5, "menu: Tab ring holds the two demo buttons and the display settings (%d)" % ring.size())
	scene.a11y.persist = false
	scene.a11y.params.set_value("high_contrast", true)
	check(scene.theme.get_color("text", "SkChart") == SkTheme.palette("high_contrast").text, "menu: High contrast setting changes the whole theme")
	scene.a11y.params.set_value("high_contrast", false)
	scene.a11y.params.set_value("text_size", 2)
	check(approx(scene.scaler.text_scale, 1.4), "menu: Extra large text setting reaches the view scaler")
	scene.a11y.params.set_value("text_size", 0)
	scene.queue_free()
	await frames(2)
	_expected += 4


func _test_predator_prey() -> void:
	var scene: Node = await _menu("?demo=predator_prey")
	scene.a11y.persist = false
	var d: Node = scene.current
	check(d != null and scene.current_id == "predator_prey", "pp: ?demo=predator_prey opens the demo")
	var s: SkSession = d.session
	d.session.auto_process = false
	check(s.state == SkSession.State.READY and s.step_count == 0, "pp: READY at the start, nothing has moved")
	_drive(s, 5.0)
	check(s.step_count == 0 and d.graph.point_count("rabbits") == 1, "pp: time passing before Start changes nothing (no auto-play)")
	check(d.params.get_int("start") == 1, "pp: default start is 'Few foxes'")
	# Start through the real button
	d.transport.play_button.pressed.emit()
	check(s.is_running() and d.params.locked, "pp: Start runs the sim and locks the start condition")
	check(not d.params.set_value("start", 2), "pp: the locked start condition refuses changes")
	var start_ctrl: Array[Button] = d.param_panel._rows["start"]["buttons"]
	check(start_ctrl[0].disabled and not start_ctrl[1].disabled and start_ctrl[1].button_pressed, "pp: locked choice: others disabled, the selected one stays visible/enabled")
	_drive(s, 20.0)
	check(absf(s.sim_time - 40.0) < 0.05, "pp: 20 s at speed 2x = 40 months of model time (got %.2f)" % s.sim_time)
	check(d.graph.point_count("rabbits") == int(s.sim_time / 0.5) + 1 and d.log.tables["populations"]["rows"].size() == d.graph.point_count("rabbits"), "pp: graph points and logged table rows are in step (one sample per 0.5 month)")
	# adjust a parameter live
	var cap_before: float = d.model.capacity
	d.params.set_value("capacity", 300.0)
	check(d.model.capacity == 300.0 and cap_before == 100.0, "pp: changing food supply while running reaches the model")
	check(d.log.count("param") >= 1, "pp: the parameter change was logged")
	d.transport.play_button.pressed.emit()
	var frozen: int = s.step_count
	_drive(s, 3.0)
	check(s.state == SkSession.State.PAUSED and s.step_count == frozen, "pp: Pause freezes the model")
	# keep run, prediction, export
	d.keep_button.pressed.emit()
	check(d.graph.series_ids().has("rabbits_kept") and d.log.kept_runs.has("A"), "pp: 'Keep this run' draws dashed series and records it")
	var focus: Array[Control] = d.lesson_panel.focus_controls()
	(focus[1] as Button).pressed.emit()
	check(d.log.responses.size() == 1 and d.log.responses[0]["prompt_id"] == "predict_food", "pp: prediction answer lands in the log")
	d.json_button.pressed.emit()
	var path: String = "user://exports/predator-prey-session.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and parsed["context"]["params"]["start"] == "Few foxes" and parsed["tables"]["populations"]["rows"].size() > 40, "pp: exported JSON has context (params by name), responses and the population table")
	check(parsed["context"]["seed"] != null and parsed["format"] == "simkit-session", "pp: export is self-describing")
	d.csv_button.pressed.emit()
	var csv: String = FileAccess.get_file_as_string("user://exports/predator-prey-populations.csv")
	check(csv.begins_with("month,rabbits,foxes\r\n") and csv.count("\r\n") > 40, "pp: CSV export of the table")
	# Reset reproduces the run
	d.transport.reset_button.pressed.emit()
	check(s.state == SkSession.State.READY and not d.params.locked and d.graph.point_count("rabbits") == 1 and s.sim_time == 0.0, "pp: Reset returns to READY, unlocks, clears the live series")
	check(d.graph.series_ids().has("rabbits_kept"), "pp: ...but the kept run stays for comparison")
	d.params.set_value("capacity", 100.0)
	d.transport.play_button.pressed.emit()
	_drive(s, 20.0)
	var run_one_r: float = d.model.rabbits
	var run_one_f: float = d.model.foxes
	var steps_one: int = s.step_count
	var reference: PredatorPreyModel = PredatorPreyModel.new()
	reference.reset(1)
	for i: int in range(steps_one):
		reference.step(0.02)
	check(reference.rabbits == run_one_r and reference.foxes == run_one_f, "pp: the demo's state after %d steps equals a standalone model stepped %d times (no hidden state)" % [steps_one, steps_one])
	d.transport.reset_button.pressed.emit()
	d.transport.play_button.pressed.emit()
	_drive(s, 20.0)
	check(s.step_count == steps_one and d.model.rabbits == run_one_r and d.model.foxes == run_one_f, "pp: Reset then the same run again gives the identical result")
	d.transport.reset_button.pressed.emit()
	# touch targets and keyboard ring
	var ctrls: Array[Control] = d.focus_controls()
	check(_min_touch(ctrls) >= 52.0, "pp: every button and slider is at least 52 base px (44 CSS px at min scale) tall (%.0f)" % _min_touch(ctrls))
	check(ctrls.size() >= 14, "pp: focus list covers transport, settings, actions, lesson, display (%d controls)" % ctrls.size())
	# reduced motion reaches the drawing
	scene.a11y.params.set_value("reduced_motion", true)
	await frames(2)
	check(d.field.calm, "pp: Reduced motion calms the animal field")
	# Escape: closes the demo first, leaves only from the menu
	var leaves: int = scene.ring.leave_count
	scene.ring.escape()
	check(scene.current == null and scene.ring.leave_count == leaves, "pp: Escape returns to the menu without leaving the game")
	scene.ring.escape()
	check(scene.ring.leave_count == leaves + 1, "pp: Escape on the menu leaves the game (sims:leave-game)")
	for f: String in ["predator-prey-session.json", "predator-prey-populations.csv"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://exports/" + f))
	scene.queue_free()
	await frames(2)
	_expected += 26


func _test_selection() -> void:
	var scene: Node = await _menu("?demo=natural_selection")
	scene.a11y.persist = false
	var d: Node = scene.current
	var s: SkSession = d.session
	check(s.mode == SkSession.Mode.MANUAL and d.transport.play_button == null, "ns: MANUAL mode, no play button")
	d.transport.step_button.pressed.emit()
	check(s.step_count == 1 and d.model.generation == 1 and d.params.locked, "ns: Next generation advances exactly one generation and locks the setup")
	d.ten_button.pressed.emit()
	check(d.model.generation == 11 and d.graph.point_count("dark") == 12, "ns: +10 generations adds ten points")
	var after_a: PackedByteArray = d.model.moths.duplicate()
	var seed_a: int = s.seed_value
	d.transport.reset_button.pressed.emit()
	check(d.model.generation == 0 and d.graph.point_count("dark") == 1 and not d.params.locked, "ns: Reset returns to generation 0 and unlocks")
	d.transport.step_button.pressed.emit()
	d.ten_button.pressed.emit()
	check(d.model.moths == after_a and s.seed_value == seed_a, "ns: Reset replays the identical history (same seed)")
	d.seed_button.pressed.emit()
	check(s.seed_value != seed_a and d.model.generation == 0, "ns: 'New random history' picks a new seed")
	d.transport.step_button.pressed.emit()
	d.ten_button.pressed.emit()
	check(d.model.moths != after_a, "ns: ...and gives a different history")
	# run to the end
	for i: int in range(30):
		d.ten_button.pressed.emit()
	check(s.state == SkSession.State.FINISHED and s.sim_time >= 200.0 - 1e-6 and d.transport.step_button.disabled, "ns: the run finishes at the generation limit and Step is disabled")
	# extinction
	d.transport.reset_button.pressed.emit()
	d.params.set_value("bark", 0.0)
	d.params.set_value("predation", 0.9)
	d.params.set_value("mutation", 0.0)
	d.params.set_value("moths", 20)
	d.params.set_value("start_dark", 100)
	d.transport.reset_button.pressed.emit()
	for i: int in range(40):
		d.ten_button.pressed.emit()
	check(s.state == SkSession.State.FINISHED and s.finish_reason == "the moths died out", "ns: a doomed population ends the run with its reason (%s)" % s.finish_reason)
	d.json_button.pressed.emit()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://exports/natural-selection-session.json"))
	check(parsed is Dictionary and parsed["context"]["mode"] == "MANUAL" and parsed["tables"]["generations"]["columns"] == ["generation", "dark_moths", "moths"], "ns: export works with only core + data modules in use")
	check(_min_touch(d.focus_controls()) >= 52.0, "ns: touch targets >= 52 base px")
	# the demo does not use the lesson panel or gauge at all
	check(d.get_node_or_null("SkLessonPanel") == null and not ("lesson_panel" in d) and not ("gauge" in d), "ns: this demo uses no lesson panel and no gauge (optional modules omitted)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://exports/natural-selection-session.json"))
	scene.queue_free()
	await frames(2)
	_expected += 12


func _test_cooling() -> void:
	var scene: Node = await _menu("?demo=cooling")
	scene.a11y.persist = false
	var d: Node = scene.current
	var s: SkSession = d.session
	d.params.set_value("k", 0.2)
	d.params.set_value("room", 25.0)
	d.bar.play_button.pressed.emit()
	_drive(s, 5.0)
	var t: float = s.sim_time
	var exact: float = 25.0 + (90.0 - 25.0) * exp(-0.2 * t)
	check(t > 15.0 and absf(d.temp - exact) < 1e-6, "cooling: matches the exact solution T = room + (T0 - room) e^(-k t) at t = %.1f min (%.6f vs %.6f)" % [t, d.temp, exact])
	_drive(s, 30.0)
	check(s.state == SkSession.State.FINISHED and absf(s.sim_time - 60.0) < 0.11, "cooling: stops at its 60-minute duration")
	var lines: int = 0
	for line: String in FileAccess.get_file_as_string("res://demo/minimal/cooling_demo.gd").split("\n"):
		var code: String = line.strip_edges()
		if code != "" and not code.begins_with("#") and not code.begins_with("##"):
			lines += 1
	check(lines <= 50, "cooling: a complete simulation in %d lines of code (limit 50)" % lines)
	scene.queue_free()
	await frames(2)
	_expected += 3


func _test_query() -> void:
	var scene: Node = await _menu("?demo=predator_prey&capacity=200&start=Many%20foxes&growth=9&bogus=1")
	scene.a11y.persist = false
	var d: Node = scene.current
	check(d.params.get_float("capacity") == 200.0 and d.params.get_int("start") == 2, "query: capacity and start are set from the page address")
	check(d.params.get_float("growth") == 0.8, "query: growth is not a class setting, and 9 is out of range: ignored")
	check(d.model.capacity == 200.0, "query: the model starts with the class settings applied")
	scene.queue_free()
	await frames(2)
	var scene2: Node = await _menu("?demo=nonsense")
	check(scene2.current == null, "query: an unknown demo name falls back to the menu")
	scene2.queue_free()
	SkHost.query_override = ""
	await frames(2)
	_expected += 4
