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
	# Space on a FOCUSED button (press + release, as a real keyboard sends them) acts exactly once
	var seen: Array[String] = []
	session.state_changed.connect(func(st: int) -> void: seen.append(SkSession.State.keys()[st]))
	bar.play_button.grab_focus()
	_key(KEY_SPACE)
	await frames(2)
	check(seen == ["RUNNING"], "Space on the focused Start button starts once (got %s)" % str(seen))
	seen.clear()
	_key(KEY_SPACE)
	await frames(2)
	check(seen == ["PAUSED"], "Space on the focused Pause button pauses once (got %s)" % str(seen))
	session.start()
	seen.clear()
	bar.reset_button.grab_focus()
	_key(KEY_SPACE)
	await frames(2)
	check(seen == ["READY"], "Space on the focused Reset button resets without also toggling play (got %s)" % str(seen))
	bar.reset_button.release_focus()
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
	# a MANUAL session can never run on its own, so the bar hides Start even if asked to show it
	var mbar2: SkTransportBar = SkTransportBar.new()
	mbar2.bind(manual)
	check(mbar2.play_button == null and mbar2.step_button != null, "MANUAL session: the bar hides Start (nothing could run) and keeps Step")
	# generations that step AND run: FIXED_STEP with a step of 1.0
	var gens: Array[int] = [0]
	var gen: SkSession = SkSession.new()
	gen.clock.step = 1.0
	gen.auto_process = false
	gen.on_step = func(_dt: float) -> void: gens[0] += 1
	root.add_child(gen)
	gen.reset()
	var gbar: SkTransportBar = SkTransportBar.new()
	gbar.step_text = "Next generation"
	gbar.bind(gen)
	gbar.step_button.pressed.emit()
	gbar.play_button.pressed.emit()
	gen.advance(3.0)
	check(gens[0] == 4 and gbar.play_button.text == "Pause", "FIXED_STEP with step 1.0: Next generation steps once, Start runs one generation per second")
	# Button wording
	var ws: SkSession = SkSession.new()
	ws.auto_process = false
	root.add_child(ws)
	var wbar: SkTransportBar = SkTransportBar.new()
	wbar.texts.start = "Run"
	wbar.texts.reset = "Start over"
	wbar.bind(ws)
	ws.reset()
	var first: String = wbar.play_button.text
	ws.start()
	var running: String = wbar.play_button.text
	wbar.texts.pause = "Hold"
	wbar.refresh()
	check(first == "Run" and wbar.reset_button.text == "Start over" and running == "Pause" and wbar.play_button.text == "Hold", "texts sets the button wording, survives resets and state changes, and refresh() applies a change")
	wbar.texts.erase("resume")
	ws.pause()
	check(wbar.play_button.text == "Resume", "a missing texts key falls back to the default wording")
	wbar.free()
	ws.queue_free()
	# Two simulations on screen: hotkeys belong to the one with focus, or the one clicked last
	var sims: Array[Control] = []
	var sessions: Array[SkSession] = []
	for k: int in range(2):
		var area: VBoxContainer = VBoxContainer.new()
		area.position = Vector2(k * 500, 0)
		area.size = Vector2(480, 300)
		root.add_child(area)
		var ss: SkSession = SkSession.new()
		ss.auto_process = false
		area.add_child(ss)
		var bb: SkTransportBar = SkTransportBar.new()
		bb.hotkey_scope = area
		bb.bind(ss)
		area.add_child(bb)
		var other: HSlider = HSlider.new()
		other.custom_minimum_size.x = 200.0
		area.add_child(other)
		sims.append(area)
		sessions.append(ss)
	await frames(1)
	root.gui_release_focus()
	_key(KEY_SPACE)
	await frames(1)
	check(sessions[0].state == SkSession.State.READY and sessions[1].state == SkSession.State.READY, "two bars, nothing focused or clicked: Space starts neither")
	(sims[1].get_child(2) as HSlider).grab_focus()
	_key(KEY_SPACE)
	await frames(1)
	check(sessions[0].state == SkSession.State.READY and sessions[1].state == SkSession.State.RUNNING, "two bars: Space starts the simulation that holds the focus")
	root.gui_release_focus()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_final_transform() * (sims[0].get_global_transform_with_canvas() * Vector2(100, 280))   # window pixels
	click.global_position = click.position
	root.push_input(click)
	var up: InputEventMouseButton = click.duplicate()
	up.pressed = false
	root.push_input(up)
	await frames(1)
	_key(KEY_SPACE)
	await frames(1)
	check(sessions[0].state == SkSession.State.RUNNING and sessions[1].state == SkSession.State.RUNNING, "two bars: with no focus, Space goes to the simulation clicked last")
	for area: Control in sims:
		area.free()
	# Speed choices the session cannot run, and the speed actually reached
	var sp: SkSession = SkSession.new()
	sp.auto_process = false
	root.add_child(sp)
	var spbar: SkTransportBar = SkTransportBar.new()
	spbar.speeds = [1.0, 8.0, 100.0]
	spbar.bind(sp)
	root.add_child(spbar)
	check(spbar.speeds == ([1.0, 8.0, 64.0] as Array[float]), "a speed choice above the session's maximum is clamped to it (%s)" % str(spbar.speeds))
	spbar.speed_button.pressed.emit()
	sp.start()
	var measured: Array[float] = []
	sp.speed_measured.connect(func(v: float) -> void: measured.append(v))
	for i: int in range(12):
		sp.advance(0.1)      # 8x of 0.1 s = 40 steps of 0.02, but the clock caps a frame at 12
	check(measured.size() == 1 and absf(measured[0] - 2.4) < 0.05 and sp.dropped_seconds > 3.0, "the session measures the speed actually reached (%s) and counts dropped time (%.2f s)" % [str(measured), sp.dropped_seconds])
	check(spbar.speed_button.text == "Speed 8x (running at 2.4x)", "the speed button says when the device cannot keep up (%s)" % spbar.speed_button.text)
	sp.pause()
	check(spbar.speed_button.text == "Speed 8x", "after a pause the speed button shows the chosen speed again")
	spbar.free()
	sp.queue_free()
	_expected += 27


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
	# Long runs: past MAX_POINTS the series is halved, not frozen
	for i: int in range(SkLineGraph.MAX_POINTS + 5):
		g.append_point("long", "Long", float(i), float(i % 7))
	var lp: PackedVector2Array = g.series_points("long")
	check(lp.size() <= SkLineGraph.MAX_POINTS and lp[0] == Vector2(0, 0) and lp[lp.size() - 1].x == float(SkLineGraph.MAX_POINTS + 4), "past MAX_POINTS a series keeps its first and newest points and goes on drawing (%d points)" % lp.size())
	await frames(1)
	var thin: PackedVector2Array = SkLineGraph._thin(PackedVector2Array(Array(range(20000)).map(func(i: int) -> Vector2: return Vector2(float(i) * 0.02, float(i % 13)))), 400.0)
	check(thin.size() <= 400 * 4 + 4 and thin[0] == Vector2(0, 0), "a 20,000-point line is drawn with at most four points per pixel column (%d)" % thin.size())
	var full: PackedVector2Array = PackedVector2Array(Array(range(5000)).map(func(i: int) -> Vector2: return Vector2(float(i) * 0.07, float((i * 37) % 101))))
	var cache: Dictionary = {}
	var grown: PackedVector2Array = PackedVector2Array()
	for n: int in [1500, 3200, 5000]:
		grown = g._line(cache, full.slice(0, n), 300.0)
	check(grown == SkLineGraph._thin(full, 300.0), "thinning a growing line step by step gives exactly the full thinning")
	g.clear()
	# X ticks thin out to fit; end labels stay inside the plot and apart
	g.auto_x = false
	g.x_range = Vector2(0.0, 10000.0)
	var font: Font = g.get_theme_default_font()
	var fs: int = maxi(g.get_theme_default_font_size() - 3, 11)
	var narrow_ticks: PackedFloat64Array = g.x_tick_values(110.0)
	var label_w: float = font.get_string_size("10000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var gap_px: float = 110.0 * (narrow_ticks[1] - narrow_ticks[0]) / 10000.0 if narrow_ticks.size() >= 2 else 999.0
	check(gap_px >= label_w * 1.5 and g.x_tick_values(600.0).size() > narrow_ticks.size(), "x tick labels thin out in a narrow plot (%d ticks at 110 px, %d at 600 px)" % [narrow_ticks.size(), g.x_tick_values(600.0).size()])
	var plot_r: Rect2 = Rect2(50, 30, 300, 150)
	var ends: Array[Dictionary] = [{"x": 300.0, "y": 184.0, "label": "A", "color": Color.WHITE}, {"x": 300.0, "y": 183.0, "label": "B", "color": Color.WHITE}]
	var placed: Array[Dictionary] = SkLineGraph.end_label_positions(ends, plot_r, font, fs)
	check(absf(float(placed[1]["y"]) - float(placed[0]["y"])) >= font.get_height(fs) - 0.01 and float(placed[1]["y"]) <= plot_r.end.y, "end labels near y = 0 stay above the x axis labels and do not overlap")
	g.x_range = Vector2(0.0, 1.0)
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
	_expected += 16


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
	check(log.table("pop", PackedStringArray(["t", "n"])) and (log.tables["pop"]["rows"] as Array).size() == 2, "table() again with the same columns keeps the rows")
	check(not log.table("pop", PackedStringArray(["t"])) and (log.tables["pop"]["columns"] as PackedStringArray).size() == 2, "table() with different columns is refused and changes nothing")
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
	check(log.events.size() == SkLog.MAX_EVENTS + 1 and log.events[-1]["kind"] == "log_full" and log.dropped_events == 10, "event log is capped; one log_full marker and a count of what was dropped")
	log.record("finished", {"reason": "done"})
	log.record_response("p2", "Again?", "no")
	check(log.count("finished") == 1 and log.count("response") == 1 and log.dropped_events == 10, "lifecycle events and answers are still kept past the cap")
	var full: Dictionary = JSON.parse_string(SkExport.to_json(log))
	check(int(full["dropped_events"]) == 10 and int(full["dropped_rows"]) == 0, "the JSON export carries dropped_events and dropped_rows")
	log.clear()
	check(log.dropped_events == 0, "clear() resets the dropped count")
	# a slider drag is one event
	for v: float in [0.2, 0.4, 0.6, 0.8]:
		params.set_value("rate", v)
	params.set_value("mode", 0)
	params.set_value("rate", 1.5)
	var pe: Array = log.events.filter(func(e: Dictionary) -> bool: return e["kind"] == "param")
	check(pe.size() == 3 and pe[0]["data"]["changes"] == 4 and is_equal_approx(float(pe[0]["data"]["value"]), 0.8) and pe[1]["data"]["id"] == "mode", "consecutive changes of one parameter merge into one event with a count (got %s)" % str(pe.map(func(e: Dictionary) -> Dictionary: return e["data"])))
	# detach, and no reference cycle
	log.detach()
	params.set_value("rate", 0.1)
	check(log.count("param") == 3 and log.session == null, "detach() stops recording")
	var leak_log: SkLog = SkLog.new()
	leak_log.attach(session)
	var leak_ref: WeakRef = weakref(leak_log)
	leak_log = null
	check(leak_ref.get_ref() == null, "an attached SkLog is freed when the game drops it (no reference cycle)")
	params.set_value("rate", 0.3)   # its connections went with it: no error
	# runs: every started run is kept; the rows of a starting picture replaced before it ran are dropped
	var rs: SkSession = SkSession.new()
	rs.auto_process = false
	root.add_child(rs)
	var rl: SkLog = SkLog.new()
	rl.attach(rs)
	rs.on_reset = func() -> void:
		rl.table("g", PackedStringArray(["run", "gen"]))
		rl.add_row("g", [rs.run_number, 0])
	rs.reset()       # run 1: starting picture
	rs.reset()       # a settings change while READY replaces it
	rs.step_once()
	rl.add_row("g", [rs.run_number, 1])
	rs.reset()       # run 2: starting picture
	check(rl.tables["g"]["rows"] == [[1, 0], [1, 1], [2, 0]], "runs are kept across resets; an unstarted starting picture is replaced, not duplicated (got %s)" % str(rl.tables["g"]["rows"]))
	check(rl.clear_table("g") and (rl.tables["g"]["rows"] as Array).is_empty() and not rl.clear_table("nope"), "clear_table empties a table on purpose")
	rs.queue_free()
	# Export edge cases
	var el: SkLog = SkLog.new()
	el.app_name = "unit"
	el.table("empty", PackedStringArray(["a", "b"]))
	check(SkExport.table_csv(el, "empty") == "a,b\r\n", "a table with no rows exports its header")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://exports/unit-nope.csv"))
	check(SkExport.table_csv(el, "nope") == "" and SkExport.save_table_csv(el, "nope") == "ERROR" and not FileAccess.file_exists("user://exports/unit-nope.csv"), "an unknown table is refused with ERROR and no file is written")
	el.add_row("empty", [NAN, INF])
	el.add_row("empty", [-INF, 2.5])
	check(SkExport.table_csv(el, "empty") == "a,b\r\n,\r\n,2.5\r\n", "NaN and infinite numbers become empty CSV cells")
	var nj: Dictionary = JSON.parse_string(SkExport.to_json(el))
	check(int(nj["non_finite"]) == 3 and nj["tables"]["empty"]["rows"][0] == [null, null] and float(nj["tables"]["empty"]["rows"][1][1]) == 2.5, "JSON writes NaN and infinity as null and counts them in non_finite")
	check(SkExport.to_csv(PackedStringArray(["x"]), [["\t=1+1"], ["\r=2"]]) == "x\r\n'\t=1+1\r\n\"'\r=2\"\r\n", "text cells starting with TAB or CR are neutralised like = + - @")
	_expected += 30


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
	(focus[2] as Button).button_pressed = true   # what a real click does before emitting pressed
	(focus[2] as Button).pressed.emit()
	check(made == [["p", 1, "no"]] and not panel.explanation_button.disabled, "prediction recorded; explanation unlocked")
	check(log.responses.size() == 1 and log.responses[0]["choice"] == "no", "response written to the log")
	var shown: Array = [0]
	panel.explanation_shown.connect(func() -> void: shown[0] += 1)
	panel.explanation_button.pressed.emit()
	panel.explanation_button.pressed.emit()
	check(shown[0] == 1 and log.count("explanation_shown") == 1, "explanation revealed once and logged once")
	(focus[2] as Button).pressed.emit()
	check((focus[1] as Button).disabled and (focus[2] as Button).button_pressed and log.responses.size() == 1 and not (focus[3] as Button).disabled, "showing the explanation locks the prediction (the chosen answer keeps its look, other answers are disabled, nothing more is logged), not the other prompts")
	(focus[focus.size() - 1] as Button).pressed.emit()
	check(log.count("vocabulary") == 1, "vocabulary lookup logged")
	panel.toggle_button.button_pressed = false
	check(panel.toggle_button.text.contains("(show)"), "lesson can be collapsed")
	var empty_panel: SkLessonPanel = SkLessonPanel.new()
	empty_panel.show_lesson(SkLesson.new())
	check(empty_panel.get_child_count() == 0 and empty_panel.focus_controls().is_empty(), "an empty lesson builds nothing")
	var open_panel: SkLessonPanel = SkLessonPanel.new()
	open_panel.lock_prediction_on_explanation = false
	open_panel.show_lesson(lesson)
	open_panel.reveal_explanation()
	check(not (open_panel.focus_controls()[1] as Button).disabled, "lock_prediction_on_explanation = false leaves the prediction open")
	open_panel.free()
	# long text wraps instead of widening the side pane
	var col: VBoxContainer = VBoxContainer.new()
	col.size = Vector2(420, 600)
	root.add_child(col)
	var long_panel: SkLessonPanel = SkLessonPanel.new()
	long_panel.show_lesson(SkLesson.from_dict({"title": "Population genetics of island lizards after a hurricane in the Caribbean",
			"prediction": {"prompt": "x", "choices": ["The population will become more varied over time because of mutation"]},
			"vocabulary": {"natural selection in a changing environment": "d"}}))
	col.add_child(long_panel)
	await frames(2)
	check(long_panel.get_combined_minimum_size().x <= 420.0 and (long_panel.focus_controls()[1] as Button).size.y > SkUi.TOUCH_MIN, "long title, choices and terms wrap within a 420 px pane (min width %.0f)" % long_panel.get_combined_minimum_size().x)
	col.queue_free()
	empty_panel.free()
	_expected += 14


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
	check(not split.is_narrow() and main_pane.get_parent() != null and side_pane.get_parent().get_parent() is ScrollContainer, "split: 1000 px wide = side by side; side pane in its own scroll")
	host.size = Vector2(400.0, 700.0)
	await frames(2)
	check(split.is_narrow() and main_pane.get_parent() == side_pane.get_parent() and main_pane.get_parent() is VBoxContainer, "split: 400 px wide = stacked in one column")
	check(main_pane.custom_minimum_size.y == split.main_min_height, "split: stacked main pane gets its minimum height")
	host.size = Vector2(1000.0, 500.0)
	await frames(2)
	check(not split.is_narrow() and main_pane.custom_minimum_size.y == 0.0 and side_pane.get_parent().get_parent() is ScrollContainer, "split: back to wide restores the side-by-side layout")
	var count: int = 0
	for n: Node in split.find_children("*", "Control", true, false):
		if n == main_pane or n == side_pane:
			count += 1
	check(count == 2, "split: each pane exists exactly once after switching")
	check(split.too_wide_panes().is_empty(), "split: no pane is wider than its room")
	var tall: Control = Control.new()
	tall.custom_minimum_size.y = 3000.0
	side_pane.add_child(tall)
	await frames(2)
	var vbar: VScrollBar = (side_pane.get_parent().get_parent() as ScrollContainer).get_v_scroll_bar()
	check(vbar.visible and side_pane.get_global_rect().end.x <= vbar.get_global_rect().position.x + 0.5, "split: the side pane's content stops left of its scrollbar (end %.0f, bar at %.0f)" % [side_pane.get_global_rect().end.x, vbar.get_global_rect().position.x])
	tall.free()
	var wide_row: Control = Control.new()
	wide_row.custom_minimum_size.x = 600.0
	side_pane.add_child(wide_row)
	await frames(1)
	var tw: Array[Array] = split.too_wide_panes()
	check(tw.size() == 1 and tw[0][0] == "side" and float(tw[0][2]) < split.side_width and float(tw[0][2]) > split.side_width - 30.0, "split: a side pane wider than its room (side_width less the scrollbar margin) is reported (%s)" % str(tw))
	_expected += 8


func _key(keycode: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	root.push_input(down)
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	root.push_input(up)
