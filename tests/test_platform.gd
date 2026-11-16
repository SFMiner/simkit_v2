extends SkTest
## SkHost, SkViewScaler, SkFocusRing, SkTheme, SkA11y.


func _key(keycode: Key, shift: bool = false) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.shift_pressed = shift
	root.push_input(ev)


func run() -> void:
	test_name = "test_platform"
	# --- SkHost
	check(SkHost.safe_filename("my run/../x.json") == "my_run_.._x.json" or SkHost.safe_filename("my run/../x.json") == "my_run____x.json", "safe_filename removes slashes and spaces")
	check(not SkHost.safe_filename("../../etc/passwd").contains("/") and not SkHost.safe_filename(".hidden").begins_with("."), "safe_filename: no path separators, no leading dot")
	check(SkHost.safe_filename("") == "file", "safe_filename: empty name gets a default")
	SkHost.query_override = "?rate=2"
	check(SkHost.query_string() == "?rate=2", "query_override stands in for the page address outside the web")
	SkHost.query_override = ""
	SkHost.announce("  hello ")
	SkHost.announce("   ")
	SkHost.announce("alert!", true)
	check(SkHost.announcements.size() == 2 and SkHost.announcements[0]["text"] == "hello" and SkHost.announcements[1]["assertive"] == true, "announce trims, ignores blank, records urgency")
	for i: int in range(60):
		SkHost.announce("m%d" % i)
	check(SkHost.announcements.size() == SkHost.ANNOUNCE_HISTORY, "announce history is capped")
	var path: String = SkHost.save_text_file("simkit test.txt", "abc")
	check(path == "user://exports/simkit_test.txt" and FileAccess.get_file_as_string(path) == "abc", "save_text_file writes under user://exports with a safe name")
	check(not SkHost.is_web() and not SkHost.prefers_reduced_motion() and not SkHost.prefers_high_contrast(), "browser queries are false and harmless outside the web")

	# --- SkViewScaler.scale_for
	var base: Vector2 = Vector2(1280, 720)
	check(approx(SkViewScaler.scale_for(Vector2(1280, 720), 1.0, base), 1.0), "scale: exact fit")
	check(approx(SkViewScaler.scale_for(Vector2(2560, 1440), 2.0, base), 2.0), "scale: hi-dpi fit uses the physical size")
	var small: float = SkViewScaler.scale_for(Vector2(1180, 360), 1.0, base)
	check(approx(small, 0.85), "scale: a short frame never goes below 0.85 CSS px per base px (got %f)" % small)
	check(approx(SkViewScaler.scale_for(Vector2(1280, 720), 1.0, base, 1.4), 1.4), "scale: text size multiplies the scale")
	check(SkViewScaler.scale_for(Vector2(300, 600), 1.0, base) <= 300.0 / 400.0 + 1e-6, "scale: a very narrow frame is capped so the layout keeps its minimum width")
	check(SkViewScaler.scale_for(Vector2(0.0, 0.0), 1.0, base) >= 0.1, "scale: degenerate window gives a positive scale")
	var sc: SkViewScaler = SkViewScaler.new()
	var got: Array = []
	sc.scale_changed.connect(func(css: float, view: Vector2) -> void: got.append([css, view]))
	root.add_child(sc)
	check(not got.is_empty() and got[0][0] > 0.0 and got[0][1].x > 0.0, "scaler applies on ready and reports css scale and view size")
	var before: int = got.size()
	sc.text_scale = 1.2
	check(got.size() > before, "changing text_scale re-applies")

	# --- SkFocusRing
	var holder: Control = Control.new()
	root.add_child(holder)
	var buttons: Array[Button] = []
	for i: int in range(3):
		var b: Button = Button.new()
		b.text = "b%d" % i
		holder.add_child(b)
		buttons.append(b)
	var hidden: Button = Button.new()
	hidden.visible = false
	holder.add_child(hidden)
	var off: Button = Button.new()
	off.disabled = true
	holder.add_child(off)
	var ring: SkFocusRing = SkFocusRing.new()
	ring.provider = func() -> Array: return [buttons[0], hidden, buttons[1], off, buttons[2]]
	var overlay_open: Array = [false]
	ring.close_topmost = func() -> bool:
		if overlay_open[0]:
			overlay_open[0] = false
			return true
		return false
	root.add_child(ring)
	await frames(2)
	check(ring.current_ring() == (buttons as Array[Control]), "ring skips hidden and disabled controls")
	_key(KEY_TAB)
	await frames(1)
	check(root.gui_get_focus_owner() == buttons[0], "Tab with nothing focused goes to the first control")
	_key(KEY_TAB)
	await frames(1)
	check(root.gui_get_focus_owner() == buttons[1], "Tab moves to the next control")
	_key(KEY_TAB, true)
	await frames(1)
	check(root.gui_get_focus_owner() == buttons[0], "Shift+Tab moves back")
	var leaves: int = SkHost.leave_count
	_key(KEY_TAB, true)
	await frames(1)
	check(ring.leave_count == 1 and SkHost.leave_count == leaves + 1 and root.gui_get_focus_owner() == null, "Shift+Tab before the first control leaves the game and releases focus")
	buttons[2].grab_focus()
	_key(KEY_TAB)
	await frames(1)
	check(ring.leave_count == 2, "Tab past the last control leaves the game")
	buttons[1].grab_focus()
	overlay_open[0] = true
	_key(KEY_ESCAPE)
	await frames(1)
	check(ring.leave_count == 2 and not overlay_open[0], "Escape with an overlay open closes only the overlay")
	_key(KEY_ESCAPE)
	await frames(1)
	check(ring.leave_count == 3, "Escape with nothing open leaves the game")
	ring.move_focus(1, true)
	check(ring.leave_count == 3, "stay_inside (held key / arrow) never leaves")
	ring.provider = Callable()
	check(ring.current_ring().is_empty(), "no provider: empty ring, no crash")

	# --- SkTheme
	for name: String in ["dark", "light", "high_contrast"]:
		var th: Theme = SkTheme.build(name)
		check(th.has_stylebox("focus", "Button") and th.has_stylebox("normal", "Button") and th.has_color("text", "SkChart"), "theme '%s' has button, focus and graph styling" % name)
	var pal: Dictionary = SkTheme.palette("dark")
	var contrast: float = _contrast(pal.text, pal.panel)
	check(contrast >= 7.0, "dark palette: text on panel contrast %.1f:1 >= 7" % contrast)
	var contrast_b: float = _contrast(SkTheme.palette("light").text, SkTheme.palette("light").panel)
	check(contrast_b >= 7.0, "light palette: text on panel contrast %.1f:1 >= 7" % contrast_b)
	var hc: Dictionary = SkTheme.palette("high_contrast")
	check(_contrast(hc.text, hc.bg) >= 15.0 and _contrast(hc.focus, hc.bg) >= 10.0, "high-contrast palette: text and focus colour >= 10:1")
	for name2: String in ["dark", "light"]:
		var q: Dictionary = SkTheme.palette(name2)
		check(_contrast(q.focus, q.bg) >= 3.0, "palette '%s': focus outline vs background >= 3:1 (WCAG non-text)" % name2)
		check(_contrast(q.on_pressed, q.button_pressed) >= 4.5, "palette '%s': text on a selected (pressed) button >= 4.5:1" % name2)
	check(SkTheme.series_color(0) != SkTheme.series_color(1) and SkTheme.series_color(8) == SkTheme.series_color(0), "series colours cycle")

	# --- SkA11y
	var a: SkA11y = SkA11y.new()
	a.persist = false
	a.save_path = "user://simkit_test_a11y.cfg"
	check(approx(a.text_scale(), 1.0) and not a.high_contrast() and not a.reduced_motion(), "a11y defaults")
	check(approx(a.anim_time(0.5), 0.5), "anim_time passes through by default")
	a.params.set_value("reduced_motion", true)
	check(a.anim_time(0.5) == 0.0, "reduced motion makes animations instantaneous")
	a.params.set_value("text_size", 2)
	check(approx(a.text_scale(), 1.4), "text size 'Extra large' = 1.4")
	a.params.set_value("high_contrast", true)
	check(a.palette_name() == "high_contrast", "high contrast selects the high-contrast palette")
	var panel_root: Control = Control.new()
	root.add_child(panel_root)
	var fired: Array = [0]
	a.changed.connect(func() -> void: fired[0] += 1)
	a.bind(panel_root, sc)
	check(panel_root.theme != null and approx(sc.text_scale, 1.4), "bind applies theme and text size immediately")
	a.params.set_value("high_contrast", false)
	check(fired[0] == 1 and panel_root.theme.get_color("text", "SkChart") == SkTheme.palette("dark").text, "bind re-applies the theme after a change")
	# persistence
	var b: SkA11y = SkA11y.new()
	b.save_path = "user://simkit_test_a11y.cfg"
	b.params.set_value("text_size", 1)
	b.params.set_value("reduced_motion", true)
	var c: SkA11y = SkA11y.new()
	c.save_path = "user://simkit_test_a11y.cfg"
	c.load_saved()
	check(approx(c.text_scale(), 1.2) and c.reduced_motion() and not c.high_contrast(), "player's choices persist and reload; untouched settings stay default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://simkit_test_a11y.cfg"))
	finish(45)


## WCAG relative-luminance contrast ratio.
func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _lum(c: Color) -> float:
	var f: Callable = func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)
