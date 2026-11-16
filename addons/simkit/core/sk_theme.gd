class_name SkTheme
extends RefCounted
## Builds a complete Theme in code from a small palette: buttons with a visible border, a thick focus
## outline on every focusable control, readable sliders. Three palettes: "dark", "light", "high_contrast".
## The palette is also stored in the theme under the type name "SkChart" (get_theme_color("text", "SkChart")),
## so graphs and gauges match without extra setup. Custom drawing controls can read the same colours.
##
##   root_control.theme = SkTheme.build("dark")
##   var pal := SkTheme.palette("dark")      # use pal.text, pal.accent... in your own drawing code

# === CONSTANTS ===
const DARK: Dictionary = {
	"bg": Color(0.06, 0.09, 0.13), "panel": Color(0.09, 0.14, 0.20), "panel_edge": Color(0.45, 0.55, 0.66),
	"text": Color(0.95, 0.96, 0.98), "text_dim": Color(0.72, 0.78, 0.84),
	"button": Color(0.15, 0.23, 0.32), "button_hover": Color(0.21, 0.31, 0.42),
	"button_pressed": Color(0.10, 0.36, 0.55), "on_pressed": Color(1, 1, 1), "button_edge": Color(0.60, 0.72, 0.84),
	"focus": Color(1.0, 0.85, 0.29), "accent": Color(0.45, 0.80, 1.0),
	"ok": Color(0.55, 0.92, 0.60), "warn": Color(1.0, 0.78, 0.40),
	"grid": Color(1, 1, 1, 0.14), "band": Color(0.35, 0.85, 0.45, 0.20),
}
const LIGHT: Dictionary = {
	"bg": Color(0.96, 0.95, 0.97), "panel": Color(1, 1, 1), "panel_edge": Color(0.55, 0.52, 0.65),
	"text": Color(0.16, 0.14, 0.22), "text_dim": Color(0.36, 0.33, 0.45),
	"button": Color(0.92, 0.91, 0.96), "button_hover": Color(0.86, 0.84, 0.93),
	"button_pressed": Color(0.23, 0.30, 0.75), "on_pressed": Color(1, 1, 1), "button_edge": Color(0.45, 0.42, 0.58),
	"focus": Color(0.78, 0.06, 0.18), "accent": Color(0.15, 0.25, 0.70),
	"ok": Color(0.10, 0.45, 0.20), "warn": Color(0.65, 0.35, 0.0),
	"grid": Color(0, 0, 0, 0.12), "band": Color(0.2, 0.65, 0.3, 0.18),
}
const HIGH_CONTRAST: Dictionary = {
	"bg": Color(0, 0, 0), "panel": Color(0, 0, 0), "panel_edge": Color(1, 1, 1),
	"text": Color(1, 1, 1), "text_dim": Color(0.9, 0.9, 0.9),
	"button": Color(0, 0, 0), "button_hover": Color(0.2, 0.2, 0.2),
	"button_pressed": Color(0.0, 0.25, 0.65), "on_pressed": Color(1, 1, 1), "button_edge": Color(1, 1, 1),
	"focus": Color(1.0, 0.92, 0.0), "accent": Color(0.4, 0.9, 1.0),
	"ok": Color(0.5, 1.0, 0.5), "warn": Color(1.0, 0.8, 0.2),
	"grid": Color(1, 1, 1, 0.3), "band": Color(0.5, 1.0, 0.5, 0.25),
}
## Okabe-Ito colour-blind-safe series colours. Graphs also vary dash style and marker shape.
const SERIES: Array[Color] = [
	Color("#56B4E9"), Color("#E69F00"), Color("#009E73"), Color("#F0E442"),
	Color("#CC79A7"), Color("#D55E00"), Color("#0072B2"), Color("#999999"),
]
const FONT_SIZE: int = 16


# === PUBLIC METHODS ===
static func palette(name: String) -> Dictionary:
	match name:
		"light":
			return LIGHT
		"high_contrast":
			return HIGH_CONTRAST
	return DARK


static func series_color(index: int) -> Color:
	return SERIES[posmod(index, SERIES.size())]


static func build(palette_name: String = "dark", font_size: int = FONT_SIZE) -> Theme:
	var p: Dictionary = palette(palette_name)
	var hc: bool = palette_name == "high_contrast"
	var t: Theme = Theme.new()
	t.default_font_size = font_size

	t.set_stylebox("normal", "Button", _box(p.button, p.button_edge, 2))
	t.set_stylebox("hover", "Button", _box(p.button_hover, p.text, 2))
	# A pressed (selected) toggle: filled AND a thicker border, so it does not rely on colour alone.
	t.set_stylebox("pressed", "Button", _box(p.button_pressed, p.text, 4))
	t.set_stylebox("hover_pressed", "Button", _box(p.button_pressed, p.text, 4))
	t.set_stylebox("disabled", "Button", _box(p.button.lerp(p.bg, 0.5), p.button_edge.lerp(p.bg, 0.6), 2))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), p.focus, 4)
	focus.draw_center = false
	focus.set_expand_margin_all(2.0)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("focus", "CheckBox", focus)
	t.set_stylebox("focus", "HSlider", focus)
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(color_name, "Button", p.text)
		t.set_color(color_name, "CheckBox", p.text)
	# A selected (pressed) button has its own text colour: dark-on-blue would fail contrast in the light palette.
	for color_name: String in ["font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(color_name, "Button", p.on_pressed)
		t.set_color(color_name, "CheckBox", p.text)
	t.set_color("font_disabled_color", "Button", p.text_dim.lerp(p.bg, 0.45))
	t.set_color("font_disabled_color", "CheckBox", p.text_dim.lerp(p.bg, 0.45))
	t.set_color("font_color", "Label", p.text)

	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckBox", empty)
	t.set_icon("checked", "CheckBox", _check_icon(true, p))
	t.set_icon("unchecked", "CheckBox", _check_icon(false, p))
	t.set_icon("checked_disabled", "CheckBox", _check_icon(true, p))
	t.set_icon("unchecked_disabled", "CheckBox", _check_icon(false, p))
	t.set_constant("h_separation", "CheckBox", 10)

	var panel: StyleBoxFlat = _box(p.panel, p.panel_edge, 2 if not hc else 3)
	panel.set_content_margin_all(12.0)
	t.set_stylebox("panel", "PanelContainer", panel)

	var track: StyleBoxFlat = _box(p.button, p.button_edge, 1)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	t.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = _box(p.accent, p.accent, 0)
	filled.content_margin_top = 5.0
	filled.content_margin_bottom = 5.0
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", _grabber_icon(p.text, p.focus, false))
	t.set_icon("grabber_highlight", "HSlider", _grabber_icon(p.text, p.focus, true))
	t.set_icon("grabber_disabled", "HSlider", _grabber_icon(p.text_dim.lerp(p.bg, 0.5), p.focus, false))

	# Colours for drawing controls (graphs, gauges): stored under the generic theme type "SkChart".
	for color_name: String in ["text", "text_dim", "grid", "band", "ok", "warn", "accent"]:
		t.set_color(color_name, "SkChart", p[color_name])
	t.set_color("bg", "SkChart", p.panel)
	t.set_color("edge", "SkChart", p.panel_edge)
	return t


# === PRIVATE METHODS ===
static func _box(bg: Color, edge: Color, border: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


static func _check_icon(checked: bool, p: Dictionary) -> ImageTexture:
	var s: int = 26
	var img: Image = Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge_color: Color = p.text
	var fill: Color = p.accent if checked else p.bg
	for y: int in range(2, s - 2):
		for x: int in range(2, s - 2):
			var edge: bool = x < 4 or y < 4 or x >= s - 4 or y >= s - 4
			img.set_pixel(x, y, edge_color if edge else fill)
	if checked:
		var mark: Color = p.bg
		for i: int in range(5):
			for w: int in range(3):
				img.set_pixel(6 + i, 13 + i + w - 1, mark)
		for i: int in range(9):
			for w: int in range(3):
				img.set_pixel(10 + i, 17 - i + w - 1, mark)
	return ImageTexture.create_from_image(img)


static func _grabber_icon(fill: Color, ring: Color, highlight: bool) -> ImageTexture:
	var s: int = 26
	var img: Image = Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Vector2 = Vector2(s / 2.0, s / 2.0)
	for y: int in range(s):
		for x: int in range(s):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= 12.0:
				img.set_pixel(x, y, ring if (d > 9.0 or highlight) else fill)
	return ImageTexture.create_from_image(img)
