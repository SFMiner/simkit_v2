class_name SkTransportBar
extends HFlowContainer
## Start / Pause / Step / Reset / Speed buttons bound to an SkSession, with the usual hotkeys
## (Space = start/pause, R = reset, N or Right arrow = step). Buttons wrap on narrow frames.
##
##   var bar := SkTransportBar.new()
##   bar.speeds = [1.0, 2.0, 4.0]
##   bar.bind(session)
##   # Generations that can also run on their own: session FIXED_STEP with clock.step = 1.0 (one
##   # generation per step; speed = generations per second); bar.step_text = "Next generation".
##   # MANUAL-mode sessions cannot run on their own, so the bar never shows Start/Pause for them.
##
## Hotkeys fire only when no focused control has used the key. When a button has keyboard focus, Space
## belongs to that button: a focused button does not consume the key press (it acts on release), so the
## Space hotkey stands aside instead of toggling a second time.
##
## Button wording: set `texts` (and `step_text`) before bind(), or call refresh() after changing them:
##   bar.texts.start = "Run"            # keys: start, pause, resume, again, reset, speed, speed_slow
##
## Several simulations on one screen: each bar's hotkeys act only for its own simulation, the one that holds
## keyboard focus or was clicked last (`hotkey_scope`, by default the nearest SkSplitView above the bar, else
## its parent). With one bar on screen its hotkeys always work.
##
## When the device cannot keep up, the speed button says so: "Speed 8x (running at 5x)".

# === CONSTANTS ===
const _DEFAULT_TEXTS: Dictionary = {"start": "Start", "pause": "Pause", "resume": "Resume", "again": "Run again",
		"reset": "Reset", "speed": "Speed %sx", "speed_slow": "Speed %sx (running at %sx)"}
## The speed button reports the speed actually reached when it is this far below the chosen one.
const SLOW_RATIO: float = 0.9

# === STATIC VARIABLES ===
static var _bars: Array[SkTransportBar] = []
static var _clicked: WeakRef = null

# === PUBLIC VARIABLES ===
var session: SkSession = null
var show_play: bool = true
var show_step: bool = true
var show_reset: bool = true
var show_speed: bool = true
var step_text: String = "Step"
## Button labels by state. Change any of them to match your lesson's wording or language.
var texts: Dictionary = _DEFAULT_TEXTS.duplicate()
var speeds: Array[float] = [1.0, 2.0, 4.0]
var hotkeys: bool = true
## The part of the screen that belongs to this bar's simulation (see the header). null = automatic.
var hotkey_scope: Control = null
## What Reset does. Default: session.reset(). Override to also clear your graphs, log, etc.
var on_reset_pressed: Callable = Callable()
var play_button: Button = null
var step_button: Button = null
var reset_button: Button = null
var speed_button: Button = null

# === PRIVATE VARIABLES ===
var _speed_index: int = 0
var _measured_speed: float = -1.0


# === PUBLIC METHODS ===
func bind(p_session: SkSession) -> void:
	session = p_session
	if show_play and session.mode == SkSession.Mode.MANUAL:
		# MANUAL sessions never advance by themselves: a Start button would say "Pause" while nothing happens.
		push_warning("SkTransportBar: MANUAL-mode sessions cannot run on their own, so the Start button is hidden. For Step + Run, use FIXED_STEP with clock.step = 1.0.")
		show_play = false
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	if show_play:
		play_button = SkUi.button(_text("start"))
		play_button.pressed.connect(_on_play)
		add_child(play_button)
	if show_step:
		step_button = SkUi.button(step_text)
		step_button.pressed.connect(_on_step)
		add_child(step_button)
	if show_reset:
		reset_button = SkUi.button(_text("reset"))
		reset_button.pressed.connect(_on_reset)
		add_child(reset_button)
	# A choice the session cannot run at would be displayed but never happen.
	var clamped: Array[float] = []
	for s: float in speeds:
		var c: float = clampf(s, SkSession.SPEED_MIN, SkSession.SPEED_MAX)
		if not is_equal_approx(c, s):
			push_warning("SkTransportBar: speed %s is outside what SkSession allows (%s to %s); using %s" % [
					String.num(s), String.num(SkSession.SPEED_MIN), String.num(SkSession.SPEED_MAX), String.num(c)])
		if not clamped.has(c):
			clamped.append(c)
	speeds = clamped if not clamped.is_empty() else [1.0]
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
	if not session.state_changed.is_connected(_on_state_changed):
		session.state_changed.connect(_on_state_changed)
	if not session.reset_done.is_connected(refresh):
		session.reset_done.connect(refresh)
	if not session.speed_measured.is_connected(_on_speed_measured):
		session.speed_measured.connect(_on_speed_measured)
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
				play_button.text = _text("pause")
			SkSession.State.PAUSED:
				play_button.text = _text("resume")
			SkSession.State.FINISHED:
				play_button.text = _text("again")
			_:
				play_button.text = _text("start")
	if reset_button != null:
		reset_button.text = _text("reset")
	if speed_button != null:
		if session.state != SkSession.State.RUNNING:
			_measured_speed = -1.0
		speed_button.text = _speed_text()
	if step_button != null:
		step_button.text = step_text
		step_button.disabled = session.state == SkSession.State.FINISHED \
				or (session.state == SkSession.State.RUNNING and session.mode != SkSession.Mode.MANUAL)


## True if this bar's hotkeys should act now: it is the only bar on screen, or its simulation holds the
## keyboard focus, or (nothing holding focus) its simulation was clicked last.
func owns_hotkeys() -> bool:
	var live: Array[SkTransportBar] = []
	for b: SkTransportBar in _bars:
		if is_instance_valid(b) and b.is_visible_in_tree() and b.hotkeys and b.session != null:
			live.append(b)
	if live.size() <= 1:
		return true
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null:
		for b: SkTransportBar in live:
			if b._scope() == focus or b._scope().is_ancestor_of(focus):
				return b == self
	var clicked: SkTransportBar = _clicked.get_ref() as SkTransportBar if _clicked != null else null
	return clicked == self


# === LIFECYCLE METHODS ===
func _enter_tree() -> void:
	if not _bars.has(self):
		_bars.append(self)


func _exit_tree() -> void:
	_bars.erase(self)


## Remembers which simulation was clicked last. Never consumes the click.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var scope: Control = _scope()
		var local: InputEventMouseButton = scope.make_input_local(event) as InputEventMouseButton
		if scope.is_visible_in_tree() and Rect2(Vector2.ZERO, scope.size).has_point(local.position):
			_clicked = weakref(self)


func _unhandled_input(event: InputEvent) -> void:
	if not hotkeys or session == null or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	if not owns_hotkeys():
		return
	match key.keycode:
		KEY_SPACE:
			# A focused button presses itself on Space (on release); toggling here too would act twice.
			if get_viewport().gui_get_focus_owner() is BaseButton:
				return
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
func _text(key: String) -> String:
	return str(texts.get(key, _DEFAULT_TEXTS[key]))


func _scope() -> Control:
	if hotkey_scope != null and is_instance_valid(hotkey_scope):
		return hotkey_scope
	var n: Node = get_parent()
	while n != null:
		if n is SkSplitView:
			return n
		n = n.get_parent()
	return get_parent() as Control if get_parent() is Control else self


func _on_speed_measured(effective: float) -> void:
	_measured_speed = effective
	if speed_button != null:
		speed_button.text = _speed_text()


## A method, not a lambda, so freeing the bar disconnects it from the session.
func _on_state_changed(_s: int) -> void:
	refresh()


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
	_measured_speed = -1.0
	speed_button.text = _speed_text()
	SkHost.announce(_speed_text())


func _speed_text() -> String:
	var s: float = speeds[_speed_index]
	if _measured_speed >= 0.0 and session != null and session.state == SkSession.State.RUNNING \
			and _measured_speed < s * SLOW_RATIO:
		return _text("speed_slow") % [_num(s), _num(snappedf(_measured_speed, 0.1))]
	return _text("speed") % _num(s)


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else String.num(v)
