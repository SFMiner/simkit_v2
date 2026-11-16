class_name SkFocusRing
extends Node
## Keyboard ownership for a game inside a web page. A canvas game that handles Tab itself must hand
## the keyboard back, or a keyboard user is trapped in it:
##   - Tab / Shift+Tab walk a list of controls you provide (rebuilt on every key press, so controls
##     that were added, removed or hidden are always in the right order);
##   - Tab past the last control, Shift+Tab before the first, and Escape with nothing to close
##     LEAVE the game: focus is released and the host page is told (SkHost.leave_game);
##   - Escape with something open closes only that thing (your `close_topmost` callable);
##   - a held key or an arrow key never throws the player out: it stops at the ends.
## Keys are read in _input(), not _unhandled_input(): the GUI consumes Tab first.
##
##   ring.provider = func() -> Array: return [play_button, reset_button, slider]
##   ring.close_topmost = func() -> bool: return panel.close_if_open()   # optional

# === SIGNALS ===
signal left_game

# === PUBLIC VARIABLES ===
## Returns the Array of Controls to walk, in order.
var provider: Callable = Callable()
## Closes the innermost open overlay and returns true, or returns false if nothing is open.
var close_topmost: Callable = Callable()
## Returns true while a modal overlay is open (then arrow keys also move focus inside the ring).
var modal_active: Callable = Callable()
var leave_count: int = 0


# === LIFECYCLE METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.is_action_pressed("ui_focus_next", true, true):
		move_focus(1, event.is_echo())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_prev", true, true):
		move_focus(-1, event.is_echo())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		escape()
		get_viewport().set_input_as_handled()
	elif modal_active.is_valid() and bool(modal_active.call()):
		if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
			move_focus(1, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
			move_focus(-1, true)
			get_viewport().set_input_as_handled()


# === PUBLIC METHODS ===
## The controls Tab can reach right now: visible, focusable, enabled.
func current_ring() -> Array[Control]:
	var ring: Array[Control] = []
	if not provider.is_valid():
		return ring
	var raw: Array = provider.call()
	for item: Variant in raw:
		if not (item is Control):
			continue
		var c: Control = item
		if not is_instance_valid(c) or c.is_queued_for_deletion() or not c.is_visible_in_tree():
			continue
		if c.focus_mode == Control.FOCUS_NONE:
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		if c is Slider and not (c as Slider).editable:
			continue
		ring.append(c)
	return ring


## Moves focus one step. With `stay_inside` it stops at the ends instead of leaving.
func move_focus(direction: int, stay_inside: bool = false) -> void:
	var ring: Array[Control] = current_ring()
	if ring.is_empty():
		if not stay_inside:
			leave_game()
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = ring.find(focused)
	var target: int = 0
	if index < 0:
		target = 0 if direction > 0 else ring.size() - 1
	else:
		target = index + direction
	if target < 0 or target >= ring.size():
		if not stay_inside:
			leave_game()
		return
	ring[target].grab_focus()


## Escape: close the innermost overlay, or leave the game when none is open.
func escape() -> void:
	if close_topmost.is_valid() and bool(close_topmost.call()):
		return
	leave_game()


func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	SkHost.leave_game()
	left_game.emit()
