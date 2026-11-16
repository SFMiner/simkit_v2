class_name SkSession
extends Node
## Lifecycle of one simulation run: READY -> RUNNING <-> PAUSED -> FINISHED, and reset.
## It does not know your model. You give it two callables and it calls them:
##
##   session.on_step = model.step      # func(dt: float) -> void   (called once per step)
##   session.on_reset = model.reset    # func() -> void            (return to the starting state)
##
## Three ways to advance time, chosen with `mode`:
##   FIXED_STEP  - equal steps of `clock.step`, as many as the frame needs (continuous models).
##   CONTINUOUS  - one step per frame with the real (capped) frame time.
##   MANUAL      - the model steps only when you call step_once() (turn / generation / event driven).
## You may also drive it yourself: set auto_process = false and call advance(delta) from your own loop.
##
## Guarantees: nothing starts running until start() is called; the model is never stepped while
## paused or finished; reset() reproduces the same run (same seed, default state, time zero).

# === SIGNALS ===
signal state_changed(new_state: int)
## Emitted after every step (or burst of steps) with the number of steps just taken.
signal advanced(steps: int)
signal reset_done
signal finished(reason: String)

# === ENUMS ===
enum State { READY, RUNNING, PAUSED, FINISHED }
enum Mode { FIXED_STEP, CONTINUOUS, MANUAL }

# === PUBLIC VARIABLES ===
var mode: Mode = Mode.FIXED_STEP
var state: State = State.READY
var clock: SkClock = SkClock.new()
## Optional. If set, params flagged lock_while_running are locked while RUNNING or PAUSED (if lock_params_after_start).
var params: SkParams = null
var lock_params_after_start: bool = false
## Called with the step length in simulation time units.
var on_step: Callable = Callable()
## Called by reset() before the state becomes READY.
var on_reset: Callable = Callable()
## When true (default) the session advances itself from _process(). Set false to call advance() yourself.
var auto_process: bool = true
var pause_on_focus_out: bool = true
## Real seconds are multiplied by this before stepping (the "speed" button).
var speed: float = 1.0:
	set(v):
		speed = clampf(v, 0.05, 64.0)
## Simulation time at which the run finishes by itself. 0 = never.
var duration: float = 0.0
## CONTINUOUS mode: largest dt passed to on_step, so a stalled frame cannot blow up a model.
var max_delta: float = 0.1
## MANUAL mode: the dt passed to on_step by step_once() (typically 1.0 = one generation or turn).
var manual_dt: float = 1.0
var sim_time: float = 0.0
var step_count: int = 0
## Reproducible randomness for the model: use session.rng, not randf(). -1 = pick a seed at the first reset.
var seed_value: int = -1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var finish_reason: String = ""


# === LIFECYCLE METHODS ===
func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_out:
		pause()


# === PUBLIC METHODS ===
func has_started() -> bool:
	return state != State.READY


func is_running() -> bool:
	return state == State.RUNNING


## READY or PAUSED -> RUNNING. Ignored once FINISHED (call reset() first).
func start() -> void:
	if state == State.READY or state == State.PAUSED:
		_set_state(State.RUNNING)


func pause() -> void:
	if state == State.RUNNING:
		_set_state(State.PAUSED)


func toggle() -> void:
	if state == State.RUNNING:
		pause()
	else:
		start()


## Ends the run (a win, a failure, the end of the experiment). `reason` is free text for logs and the UI.
func finish(reason: String = "done") -> void:
	if state == State.FINISHED:
		return
	finish_reason = reason
	_set_state(State.FINISHED)
	finished.emit(reason)


## Back to the starting state. Keeps the seed unless `reseed` is true (a "new random run").
## An explicit `new_seed` >= 0 always wins.
func reset(reseed: bool = false, new_seed: int = -1) -> void:
	if new_seed >= 0:
		seed_value = new_seed
	elif reseed or seed_value < 0:
		seed_value = int(randi() & 0x7fffffff)
	rng.seed = seed_value
	sim_time = 0.0
	step_count = 0
	finish_reason = ""
	clock.reset()
	if params != null:
		params.locked = false
	if on_reset.is_valid():
		on_reset.call()
	_set_state(State.READY)
	reset_done.emit()


## One step now, whatever the mode. Allowed in READY and PAUSED (the run then counts as started and
## is PAUSED), and in RUNNING for MANUAL mode. FIXED_STEP uses clock.step, MANUAL uses manual_dt,
## CONTINUOUS uses clock.step too (a deterministic "frame").
func step_once() -> void:
	if state == State.FINISHED:
		return
	if state == State.RUNNING and mode != Mode.MANUAL:
		return
	if state == State.READY:
		_set_state(State.PAUSED)
	_do_step(manual_dt if mode == Mode.MANUAL else clock.step)
	advanced.emit(1)


## Advances by `real_delta` seconds if RUNNING. Called from _process() unless auto_process is false.
## Returns the number of steps taken.
func advance(real_delta: float) -> int:
	if state != State.RUNNING or not is_finite(real_delta) or real_delta <= 0.0:
		return 0
	var scaled: float = real_delta * speed
	var taken: int = 0
	match mode:
		Mode.FIXED_STEP:
			var due: int = clock.advance(scaled)
			for i: int in range(due):
				_do_step(clock.step)
				taken += 1
				if state != State.RUNNING:
					break
		Mode.CONTINUOUS:
			_do_step(minf(scaled, max_delta))
			taken = 1
		Mode.MANUAL:
			pass
	if taken > 0:
		advanced.emit(taken)
	return taken


## Everything needed to reproduce this run: put it in an export or a bug report.
func describe() -> Dictionary:
	return {
		"framework_version": SkHost.VERSION,
		"mode": Mode.keys()[mode],
		"state": State.keys()[state],
		"seed": seed_value,
		"sim_time": sim_time,
		"steps": step_count,
		"step_length": manual_dt if mode == Mode.MANUAL else clock.step,
		"params": params.to_labeled_dict() if params != null else {},
		"finish_reason": finish_reason,
	}


# === PRIVATE METHODS ===
func _do_step(dt: float) -> void:
	if on_step.is_valid():
		on_step.call(dt)
	sim_time += dt
	step_count += 1
	if duration > 0.0 and state != State.FINISHED and sim_time + 1e-9 >= duration:
		finish("duration")


func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	if params != null:
		params.locked = lock_params_after_start and (s == State.RUNNING or s == State.PAUSED)
	state_changed.emit(int(s))
