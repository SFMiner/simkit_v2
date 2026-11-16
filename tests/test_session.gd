extends SkTest
## SkSession + SkClock: lifecycle, no auto-play, three stepping modes, reproducible reset, param locking.

var steps_taken: Array[float] = []
var resets: int = 0
var draws: Array[float] = []


func _step(dt: float) -> void:
	steps_taken.append(dt)


func _reset() -> void:
	resets += 1
	steps_taken.clear()


func _make(mode: SkSession.Mode) -> SkSession:
	var s: SkSession = SkSession.new()
	s.mode = mode
	s.auto_process = false
	s.on_step = _step
	s.on_reset = _reset
	s.seed_value = 7
	root.add_child(s)
	s.reset()
	return s


func run() -> void:
	test_name = "test_session"
	# --- SkClock
	var c: SkClock = SkClock.new()
	c.step = 0.1
	check(c.advance(0.05) == 0 and approx(c.alpha(), 0.5), "clock: half a step due after 0.05 s; alpha 0.5")
	check(c.advance(0.05) == 1 and approx(c.alpha(), 0.0, 1e-6), "clock: accumulates to one step")
	check(c.advance(0.35) == 3, "clock: three steps in 0.35 s")
	check(c.advance(0.0) == 0 and c.advance(-1.0) == 0 and c.advance(NAN) == 0, "clock: zero, negative and NaN deltas do nothing")
	check(c.advance(100.0) == c.max_steps_per_frame and c.dropped, "clock: a stalled frame is capped and reported")
	c.reset()
	var total: int = 0
	for i: int in range(600):
		total += c.advance(1.0 / 60.0)
	check(total == 100, "clock: 600 frames at 60 fps = 10 s = exactly 100 steps (no drift) [got %d]" % total)

	# --- lifecycle, FIXED_STEP
	var s: SkSession = _make(SkSession.Mode.FIXED_STEP)
	s.clock.step = 0.05
	check(s.state == SkSession.State.READY and resets == 1, "starts READY after reset()")
	check(s.advance(1.0) == 0 and steps_taken.is_empty(), "never runs before start() (no auto-play)")
	s.start()
	check(s.is_running(), "start -> RUNNING")
	var n: int = s.advance(0.5)
	check(n == 10 and steps_taken.size() == 10 and approx(s.sim_time, 0.5), "running: 0.5 s = 10 steps of 0.05; sim_time 0.5")
	s.pause()
	check(s.advance(5.0) == 0 and steps_taken.size() == 10, "paused: model is not stepped")
	s.step_once()
	check(steps_taken.size() == 11 and s.state == SkSession.State.PAUSED, "step_once while paused takes exactly one step")
	s.speed = 2.0
	s.start()
	check(s.advance(0.25) == 10, "speed 2x doubles steps (0.25 s -> 0.5 sim s -> 10 steps)")
	s.speed = 1.0
	s.reset()
	check(s.state == SkSession.State.READY and s.sim_time == 0.0 and s.step_count == 0 and steps_taken.is_empty(), "reset returns to time zero and READY")
	check(resets == 2, "on_reset called once per reset (_make + explicit = 2)")

	# --- duration and finish
	s.duration = 1.0
	s.start()
	var finished_reason: Array = []
	s.finished.connect(func(r: String) -> void: finished_reason.append(r))
	for i: int in range(30):
		s.advance(0.1)
	check(s.state == SkSession.State.FINISHED and finished_reason == ["duration"], "reaching duration finishes the run")
	check(steps_taken.size() == 20 and approx(s.sim_time, 1.0), "stepping stops exactly at the duration (20 steps)")
	s.start()
	check(s.state == SkSession.State.FINISHED, "start() is ignored once FINISHED")
	s.step_once()
	check(steps_taken.size() == 20, "step_once() is ignored once FINISHED")
	s.reset()
	s.duration = 0.0

	# --- the model can finish the run itself
	var stopper: SkSession = _make(SkSession.Mode.FIXED_STEP)
	stopper.on_step = func(_dt: float) -> void:
		if stopper.step_count >= 4:
			stopper.finish("collapse")
	stopper.start()
	stopper.advance(10.0)
	check(stopper.step_count == 5 and stopper.finish_reason == "collapse", "finish() inside on_step stops the burst immediately")

	# --- CONTINUOUS
	var cont: SkSession = _make(SkSession.Mode.CONTINUOUS)
	cont.max_delta = 0.1
	cont.start()
	cont.advance(0.016)
	cont.advance(3.0)
	check(steps_taken.size() == 2 and approx(steps_taken[0], 0.016) and approx(steps_taken[1], 0.1), "continuous: one step per frame, dt capped at max_delta")

	# --- MANUAL (event / generation driven)
	var man: SkSession = _make(SkSession.Mode.MANUAL)
	man.start()
	check(man.advance(10.0) == 0 and steps_taken.is_empty(), "manual: time passing never steps the model")
	man.step_once()
	man.step_once()
	check(steps_taken.size() == 2 and approx(man.sim_time, 2.0) and approx(steps_taken[0], 1.0), "manual: step_once = one manual_dt (a generation)")

	# --- reproducible randomness
	var a: SkSession = _make(SkSession.Mode.MANUAL)
	var seq_a: Array[int] = []
	for i: int in range(5):
		seq_a.append(a.rng.randi())
	a.reset()
	var seq_b: Array[int] = []
	for i: int in range(5):
		seq_b.append(a.rng.randi())
	check(seq_a == seq_b, "reset() restarts the same random sequence (same seed)")
	a.reset(false, 99)
	check(a.seed_value == 99 and a.rng.randi() != seq_a[0], "explicit seed changes the sequence")
	var old_seed: int = a.seed_value
	a.reset(true)
	check(a.seed_value != old_seed and a.seed_value >= 0, "reseed picks a new seed")
	check(a.describe()["seed"] == a.seed_value and a.describe()["mode"] == "MANUAL", "describe() reports seed and mode")

	# --- param locking
	var params: SkParams = SkParams.new()
	params.add(SkParam.int_param("n", "N", 5, 0, 10).locked_while_running())
	var lk: SkSession = _make(SkSession.Mode.FIXED_STEP)
	lk.params = params
	lk.lock_params_after_start = true
	lk.start()
	check(params.locked and not params.set_value("n", 7), "params lock once the run starts")
	lk.pause()
	check(params.locked, "params stay locked while paused")
	lk.reset()
	check(not params.locked and params.set_value("n", 7), "reset unlocks params")
	lk.start()
	lk.finish("x")
	check(not params.locked, "params unlock when the run finishes")

	# --- auto_process drives the session from _process
	var auto: SkSession = SkSession.new()
	auto.on_step = _step
	steps_taken.clear()
	root.add_child(auto)
	auto.reset()
	await frames(3)
	check(steps_taken.is_empty(), "auto_process does not start a READY session")
	auto.start()
	await create_timer(0.3).timeout
	check(steps_taken.size() > 0, "auto_process steps a RUNNING session from _process")
	finish(33)
