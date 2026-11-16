class_name SkTransportBar
extends HFlowContainer
## Start / Pause / Step / Reset / Speed buttons bound to an SkSession, with the usual hotkeys
## (Space = start/pause, R = reset, N or Right arrow = step). Buttons wrap on narrow frames.
##
##   var bar := SkTransportBar.new()
##   bar.speeds = [1.0, 2.0, 4.0]
##   bar.bind(session)
##   # Discrete / event-driven sims: bar.show_play = false; bar.step_text = "Next generation"
##
## Hotkeys fire only when no focused control has used the key (a focused button takes Space itself).

# === PUBLIC VARIABLES ===
var session: SkSession = null
var show_play: bool = true
var show_step: bool = true
var show_reset: bool = true
var show_speed: bool = true
var step_text: String = "Step"
var speeds: Array[float] = [1.0, 2.0, 4.0]
var hotkeys: bool = true
## What Reset does. Default: session.reset(). Override to also clear your graphs, log, etc.
var on_reset_pressed: Callable = Callable()
var play_button: Button = null
var step_button: Button = null
var reset_button: Button = null
var speed_button: Button = null

# === PRIVATE VARIABLES ===
var _speed_index: int = 0


# === PUBLIC METHODS ===
func bind(p_session: SkSession) -> void:
	session = p_session
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	if show_play:
		play_button = SkUi.button("Start")
		play_button.pressed.connect(_on_play)
		add_child(play_button)
	if show_step:
		step_button = SkUi.button(step_text)
		step_button.pressed.connect(_on_step)
		add_child(step_button)
	if show_reset:
		reset_button = SkUi.button("Reset")
		reset_button.pressed.connect(_on_reset)
		add_child(reset_button)
	if show_speed and speeds.size() > 1:
		speed_button = SkUi.button(_speed_text())
		speed_button.pressed.connect(_on_speed)
		add_child(speed_button)
	# Keep the session's speed if it is one of the choices; otherwise start at the first choice.
	_speed_index = 0
	for i: int in range(speeds.size()):
		if is_equal_approx(speeds[i], session.speed):
			_speed_index = i
	session.speed = speeds[_speed_index]
	if speed_button != null:
		speed_button.text = _speed_text()
	session.state_changed.connect(func(_s: int) -> void: refresh())
	session.reset_done.connect(refresh)
	refresh()


func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	for b: Button in [play_button, step_button, reset_button, speed_button]:
		if b != null:
			out.append(b)
	return out


func refresh() -> void:
	if session == null:
		return
	if play_button != null:
		match session.state:
			SkSession.State.RUNNING:
				play_button.text = "Pause"
			SkSession.State.PAUSED:
				play_button.text = "Resume"
			SkSession.State.FINISHED:
				play_button.text = "Run again"
			_:
				play_button.text = "Start"
	if step_button != null:
		step_button.disabled = session.state == SkSession.State.FINISHED \
				or (session.state == SkSession.State.RUNNING and session.mode != SkSession.Mode.MANUAL)


# === LIFECYCLE METHODS ===
func _unhandled_input(event: InputEvent) -> void:
	if not hotkeys or session == null or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			if show_play:
				_on_play()
				get_viewport().set_input_as_handled()
		KEY_R:
			if show_reset:
				_on_reset()
				get_viewport().set_input_as_handled()
		KEY_N, KEY_RIGHT:
			if show_step and step_button != null and not step_button.disabled:
				_on_step()
				get_viewport().set_input_as_handled()


# === PRIVATE METHODS ===
func _on_play() -> void:
	match session.state:
		SkSession.State.RUNNING:
			session.pause()
			SkHost.announce("Paused")
		SkSession.State.FINISHED:
			_on_reset()
			session.start()
			SkHost.announce("Started again")
		_:
			session.start()
			SkHost.announce("Running")


func _on_step() -> void:
	session.step_once()


func _on_reset() -> void:
	if on_reset_pressed.is_valid():
		on_reset_pressed.call()
	else:
		session.reset()
	SkHost.announce("Reset")


func _on_speed() -> void:
	_speed_index = (_speed_index + 1) % speeds.size()
	session.speed = speeds[_speed_index]
	speed_button.text = _speed_text()
	SkHost.announce("Speed " + _speed_text())


func _speed_text() -> String:
	var s: float = speeds[_speed_index]
	return "Speed %sx" % (str(int(s)) if s == floorf(s) else String.num(s))
