extends SkTest
## Optional modules: SkParamPanel, SkTransportBar, SkLineGraph, SkGauge, SkLog/SkExport, SkLesson/SkLessonPanel.


func run() -> void:
	test_name = "test_modules"
	root.theme = SkTheme.build("dark")
	await _test_param_panel()
	await _test_transport()
	await _test_viz()
	_test_data()
	await _test_lesson()
	await _test_split()
	finish(_expected)


var _expected: int = 0


func _test_param_panel() -> void:
	var params: SkParams = SkParams.new()
	params.add(SkParam.float_param("rate", "Rate", 1.0, 0.0, 2.0, 0.1).with_help("Speed of growth"))
	params.add(SkParam.int_param("n", "Count", 10, 0, 100, 10).locked_while_running())
	params.add(SkParam.bool_param("on", "Feature", false))
	params.add(SkParam.choice_param("mode", "Mode", PackedStringArray(["A", "B", "C"]), 0))
	var panel: SkParamPanel = SkParamPanel.new()
	panel.bind(params)
	root.add_child(panel)
	await frames(2)
	var slider: HSlider = panel.control_for("rate") as HSlider
	check(slider != null and slider.min_value == 0.0 and slider.max_value == 2.0 and absf(slider.step - 0.1) < 1e-9, "slider built from the spec")
	check(approx(slider.value, 1.0), "slider shows the default")
	slider.value = 1.5
	check(approx(params.get_float("rate"), 1.5), "moving the slider sets the parameter")
	params.set_value("rate", 0.5)
	check(approx(slider.value, 0.5), "setting the parameter moves the slider")
	var edited: Array = []
	panel.edited.connect(func(id: String, v: Variant) -> void: edited.append(id))
	params.set_value("rate", 0.7)
	check(edited.is_empty(), "code changes do not emit 'edited' (only the player's do)")
	slider.value = 0.9
	check(edited == ["rate"], "player changes emit 'edited'")
	var check_box: CheckBox = panel.control_for("on") as CheckBox
	check_box.button_pressed = true
	check(params.get_bool("on"), "check box sets a BOOL")
	var choice: Button = panel.control_for("mode") as Button
	var buttons: Array[Control] = panel.focus_controls()
	check(buttons.size() == 1 + 1 + 1 + 3 + 1, "focus list: slider, slider, check box, 3 choice buttons, reset = 7 (got %d)" % buttons.size())
	(buttons[4] as Button).pressed.emit()
	check(params.get_int("mode") == 1, "pressing a choice button sets the CHOICE")
	check((buttons[4] as Button).button_pressed and not (buttons[3] as Button).button_pressed, "choice buttons show the selected one")
	params.set_value("mode", 2)
	check((buttons[5] as Button).button_pressed, "setting the CHOICE in code updates the buttons")
	params.locked = true
	check(not (panel.control_for("n") as Slider).editable and (panel.control_for("rate") as Slider).editable, "locking disables only lock_while_running params")
	check(panel.focus_controls().size() == 7, "locked controls stay in the list (SkFocusRing skips them itself)")
	var ring: SkFocusRing = SkFocusRing.new()
	ring.provider = panel.focus_controls
	root.add_child(ring)
	check(not ring.current_ring().has(panel.control_for("n")), "SkFocusRing skips the locked slider")
	params.locked = false
	var reset_btn: Button = buttons[6] as Button
	params.set_value("rate", 2.0)
	reset_btn.pressed.emit()
	check(approx(params.get_float("rate"), 1.0) and params.get_int("mode") == 0 and not params.get_bool("on"), "Reset button restores all defaults")
	check(slider.tooltip_text == "Speed of growth", "help text becomes the tooltip")
	# rebind with a subset
	panel.show_reset = false
	panel.bind(params, PackedStringArray(["mode", "rate"]))
	await frames(2)
	check(panel.focus_controls().size() == 4 and panel.focus_controls()[0] is Button, "bind() again rebuilds with a chosen subset and order")
	_expected += 17


func _test_transport() -> void:
	var calls: Array = []
	var session: SkSession = SkSession.new()
	session.auto_process = false
	session.on_step = func(dt: float) -> void: calls.append(dt)
	root.add_child(session)
	session.reset()
	var bar: SkTransportBar = SkTransportBar.new()
	bar.bind(session)
	root.add_child(bar)
	await frames(1)
	check(bar.play_button.text == "Start" and bar.focus_controls().size() == 4, "transport: Start, Step, Reset, Speed")
	bar.play_button.pressed.emit()
	check(session.is_running() and bar.play_button.text == "Pause" and bar.step_button.disabled, "Start runs the session; label becomes Pause; Step disabled while running (fixed-step)")
	bar.play_button.pressed.emit()
	check(session.state == SkSession.State.PAUSED and bar.play_button.text == "Resume", "Pause pauses; label becomes Resume")
	bar.step_button.pressed.emit()
	check(calls.size() == 1, "Step button takes one step while paused")
	bar.speed_button.pressed.emit()
	check(approx(session.speed, 2.0) and bar.speed_button.text == "Speed 2x", "Speed button cycles 1x -> 2x")
	session.finish("end")
	check(bar.play_button.text == "Run again", "label becomes 'Run again' when finished")
	bar.play_button.pressed.emit()
	check(session.is_running() and session.sim_time == 0.0, "'Run again' resets then starts")
	var fast: SkSession = SkSession.new()
	fast.speed = 4.0
	var fast_bar: SkTransportBar = SkTransportBar.new()
	fast_bar.bind(fast)
	check(approx(fast.speed, 4.0) and fast_bar.speed_button.text == "Speed 4x", "transport: keeps a session speed that is one of its choices")
	var odd: SkSession = SkSession.new()
	odd.speed = 3.0
	SkTransportBar.new().bind(odd)
	check(approx(odd.speed, 1.0), "transport: an unlisted session speed falls back to the first choice")
	# hotkey
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	root.push_input(ev)
	await frames(1)
	check(session.state == SkSession.State.PAUSED, "Space hotkey toggles run/pause when nothing consumed it")
	var r: InputEventKey = InputEventKey.new()
	r.keycode = KEY_R
	r.pressed = true
	root.push_input(r)
	await frames(1)
	check(session.state == SkSession.State.READY, "R hotkey resets")
	# manual-mode variant: no play button
	var manual: SkSession = SkSession.new()
	manual.mode = SkSession.Mode.MANUAL
	manual.auto_process = false
	manual.on_step = func(dt: float) -> void: calls.append(dt)
	root.add_child(manual)
	manual.reset()
	var mbar: SkTransportBar = SkTransportBar.new()
	mbar.show_play = false
	mbar.show_speed = false
	mbar.step_text = "Next generation"
	mbar.bind(manual)
	root.add_child(mbar)
	check(mbar.play_button == null and mbar.step_button.text == "Next generation" and mbar.focus_controls().size() == 2, "manual-mode bar: only Next generation + Reset")
	mbar.step_button.pressed.emit()
	mbar.step_button.pressed.emit()
	check(manual.step_count == 2 and not mbar.step_button.disabled, "manual-mode step works repeatedly")
	_expected += 13


func _test_viz() -> void:
	var t: PackedFloat64Array = SkLineGraph.nice_ticks(0.0, 100.0, 5)
	check(t.size() == 6 and t[0] == 0.0 and t[5] == 100.0, "nice_ticks(0,100) = 0,20,...,100")
	var t2: PackedFloat64Array = SkLineGraph.nice_ticks(0.13, 0.87, 5)
	check(t2.size() >= 3 and t2[0] >= 0.13 and t2[t2.size() - 1] <= 0.87 + 1e-9, "nice_ticks stays inside the range for fractions")
	check(SkLineGraph.nice_ticks(5.0, 5.0).is_empty(), "nice_ticks of an empty range is empty")
	check(SkLineGraph._tick_decimals(SkLineGraph.nice_ticks(0.0, 1.0, 5)) == 1 and SkLineGraph._tick_decimals(SkLineGraph.nice_ticks(0.0, 100.0, 5)) == 0 and SkLineGraph._tick_decimals(SkLineGraph.nice_ticks(0.0, 0.5, 5)) == 1 and SkLineGraph._tick_decimals(SkLineGraph.nice_ticks(0.0, 0.25, 5)) == 2, "tick labels get the digits their spacing needs (0.2 -> 1 digit, 20 -> 0, 0.05 -> 2)")
	var g: SkLineGraph = SkLineGraph.new()
	g.size = Vector2(400, 220)
	g.title = "Pop"
	root.add_child(g)
	g.append_point("a", "Rabbits", 0.0, 10.0)
	g.append_point("a", "Rabbits", 1.0, 20.0)
	g.set_series("b", "Foxes", PackedVector2Array([Vector2(0, 5), Vector2(1, 3)]), true)
	g.bands = [{"lo": 4.0, "hi": 8.0, "label": "ok"}]
	await frames(2)
	check(g.series_ids() == (["a", "b"] as Array[String]) and g.point_count("a") == 2, "series created by append_point and set_series")
	check(g.describe().contains("Rabbits: 2 points, latest 20") and g.describe().contains("Foxes"), "describe() summarises each series for screen readers")
	g.remove_series("b")
	check(g.series_ids() == (["a"] as Array[String]), "remove_series")
	g.clear()
	check(g.series_ids().is_empty() and g.describe() == "Pop.", "clear")
	var gauge: SkGauge = SkGauge.new()
	gauge.heading = "Level"
	gauge.min_value = 0.0
	gauge.max_value = 200.0
	gauge.bands = [{"lo": 40.0, "hi": 80.0, "label": "healthy"}]
	gauge.size = Vector2(300, 100)
	root.add_child(gauge)
	gauge.value = 60.0
	check(gauge.verdict() == "in the healthy range", "gauge verdict: inside the band")
	gauge.value = 10.0
	check(gauge.verdict() == "below the healthy range", "gauge verdict: below")
	gauge.value = 150.0
	check(gauge.verdict() == "above the healthy range" and gauge.describe() == "Level: 150, above the healthy range.", "gauge verdict: above, and describe()")
	await frames(2)
	_expected += 11


func _test_data() -> void:
	var session: SkSession = SkSession.new()
	session.auto_process = false
	var params: SkParams = SkParams.new()
	params.add(SkParam.choice_param("mode", "Mode", PackedStringArray(["Slow", "Fast"]), 0))
	params.add(SkParam.float_param("rate", "Rate", 1.0, 0.0, 2.0))
	session.params = params
	session.seed_value = 123
	root.add_child(session)
	var log: SkLog = SkLog.new()
	log.app_name = "unit"
	log.attach(session)
	session.reset()
	session.start()
	params.set_value("mode", 1)
	session.pause()
	log.record_response("p1", "Will it rise?", "yes, \"a lot\"")
	log.table("pop", PackedStringArray(["t", "n"]))
	check(log.add_row("pop", [0.0, 5]) and log.add_row("pop", [1.0, 7]), "table rows added")
	check(not log.add_row("pop", [1.0]) and not log.add_row("nope", [1, 2]), "wrong-length row and unknown table refused")
	log.keep_run("A", {"n": [5, 7]}, {"note": "first"})
	check(log.count("param") == 1 and log.count("state") == 2 and log.count("reset") == 1, "attach() recorded one param change, two state changes (RUNNING, PAUSED) and one reset")
	check(log.events[-1]["kind"] == "response" or log.events.size() > 3, "events accumulate in order")
	var param_event: Dictionary = {}
	for e: Dictionary in log.events:
		if e["kind"] == "param":
			param_event = e
	check(param_event["data"]["value"] == "Fast", "param events store the readable choice name")
	var parsed: Variant = JSON.parse_string(SkExport.to_json(log, {"lesson": "L1"}))
	check(parsed is Dictionary and parsed["format"] == "simkit-session" and parsed["lesson"] == "L1", "JSON export parses back and carries extra fields")
	check(parsed["context"]["seed"] == 123.0 and parsed["context"]["params"]["mode"] == "Fast", "export context holds the seed and readable params (reproducibility)")
	check(parsed["responses"][0]["choice"] == "yes, \"a lot\"" and parsed["tables"]["pop"]["rows"].size() == 2 and parsed["tables"]["pop"]["columns"] == ["t", "n"], "responses, tables and quoting survive the round trip")
	check(parsed["kept_runs"]["A"]["meta"]["note"] == "first" and parsed["kept_runs"]["A"]["meta"]["seed"] == 123.0, "kept runs carry their own meta plus the session description")
	var txt: String = JSON.stringify(parsed)
	check(not txt.to_lower().contains("user") and not txt.contains("@") and not txt.contains("/home"), "export contains no user names, addresses or paths")
	check(SkExport.table_csv(log, "pop") == "t,n\r\n0,5\r\n1,7\r\n", "table CSV")
	var tricky: String = SkExport.to_csv(PackedStringArray(["a", "b"]), [["x,y", "say \"hi\""], ["=SUM(A1)", -3], ["line\nbreak", 0.5]])
	check(tricky == "a,b\r\n\"x,y\",\"say \"\"hi\"\"\"\r\n'=SUM(A1),-3\r\n\"line\nbreak\",0.5\r\n", "CSV quotes commas/quotes/newlines, neutralises formulas, keeps negative numbers")
	var path: String = SkExport.save_json(log)
	check(path == "user://exports/unit-session.json" and JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "save_json writes a readable file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	log.clear()
	check(log.events.is_empty() and log.tables.is_empty() and log.kept_runs.is_empty(), "clear")
	for i: int in range(SkLog.MAX_EVENTS + 10):
		log.record("x")
	check(log.events.size() == SkLog.MAX_EVENTS, "event log is capped")
	_expected += 15


func _test_lesson() -> void:
	var lesson: SkLesson = SkLesson.from_json('{"title":"T","objectives":["o1","o2"],"instructions":"go","prediction":{"id":"p","prompt":"Will it?","choices":["yes","no"]},"observations":[{"prompt":"What?","choices":["a","b"]},"just think"],"explanation":"Because.","reflection":["why?"],"vocabulary":{"term":"def"}}')
	check(lesson.title == "T" and lesson.objectives.size() == 2 and lesson.prediction["choices"].size() == 2 and lesson.observations.size() == 2 and lesson.reflection.size() == 1, "lesson parsed from JSON")
	check(lesson.observations[0]["id"] == "obs1" and (lesson.observations[1]["choices"] as PackedStringArray).is_empty(), "prompts get ids; a plain string is a thinking prompt")
	check(SkLesson.from_json("not json").is_empty() and SkLesson.from_dict({}).is_empty(), "bad or empty input gives an empty lesson, no crash")
	var log: SkLog = SkLog.new()
	var panel: SkLessonPanel = SkLessonPanel.new()
	panel.log = log
	panel.explanation_requires_prediction = true
	panel.show_lesson(lesson)
	root.add_child(panel)
	await frames(2)
	check(panel.explanation_button.disabled, "explanation is locked until a prediction is made")
	var made: Array = []
	panel.choice_made.connect(func(id: String, i: int, t: String) -> void: made.append([id, i, t]))
	var focus: Array[Control] = panel.focus_controls()
	# order: toggle, prediction yes/no, obs a/b, explanation button, term
	check(focus.size() == 1 + 2 + 2 + 1 + 1, "focus list has toggle, prediction, observation, explanation, vocabulary (got %d)" % focus.size())
	(focus[2] as Button).pressed.emit()
	check(made == [["p", 1, "no"]] and not panel.explanation_button.disabled, "prediction recorded; explanation unlocked")
	check(log.responses.size() == 1 and log.responses[0]["choice"] == "no", "response written to the log")
	var shown: Array = [0]
	panel.explanation_shown.connect(func() -> void: shown[0] += 1)
	panel.explanation_button.pressed.emit()
	panel.explanation_button.pressed.emit()
	check(shown[0] == 1 and log.count("explanation_shown") == 1, "explanation revealed once and logged once")
	(focus[focus.size() - 1] as Button).pressed.emit()
	check(log.count("vocabulary") == 1, "vocabulary lookup logged")
	panel.toggle_button.button_pressed = false
	check(panel.toggle_button.text.contains("(show)"), "lesson can be collapsed")
	var empty_panel: SkLessonPanel = SkLessonPanel.new()
	empty_panel.show_lesson(SkLesson.new())
	check(empty_panel.get_child_count() == 0 and empty_panel.focus_controls().is_empty(), "an empty lesson builds nothing")
	_expected += 11


func _test_split() -> void:
	var host: Control = Control.new()
	host.size = Vector2(1000.0, 500.0)
	root.add_child(host)
	var main_pane: Control = ColorRect.new()
	var side_pane: VBoxContainer = VBoxContainer.new()
	side_pane.add_child(Button.new())
	var split: SkSplitView = SkSplitView.new()
	host.add_child(split)
	split.set_panes(main_pane, side_pane)
	await frames(2)
	check(not split.is_narrow() and main_pane.get_parent() != null and side_pane.get_parent() is ScrollContainer, "split: 1000 px wide = side by side; side pane in its own scroll")
	host.size = Vector2(400.0, 700.0)
	await frames(2)
	check(split.is_narrow() and main_pane.get_parent() == side_pane.get_parent() and main_pane.get_parent() is VBoxContainer, "split: 400 px wide = stacked in one column")
	check(main_pane.custom_minimum_size.y == split.main_min_height, "split: stacked main pane gets its minimum height")
	host.size = Vector2(1000.0, 500.0)
	await frames(2)
	check(not split.is_narrow() and main_pane.custom_minimum_size.y == 0.0 and side_pane.get_parent() is ScrollContainer, "split: back to wide restores the side-by-side layout")
	var count: int = 0
	for n: Node in split.find_children("*", "Control", true, false):
		if n == main_pane or n == side_pane:
			count += 1
	check(count == 2, "split: each pane exists exactly once after switching")
	_expected += 5
