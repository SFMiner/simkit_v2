class_name SkGauge
extends Control
## A horizontal gauge: a value on a scale, with named bands (a "normal range"), a heading and a one-line
## verdict in words. Position and text carry the reading, not colour alone: the marker is a line plus a
## triangle, bands are labelled, and the verdict says "below / in / above" the band.
##
##   gauge.heading = "Rabbits vs food supply"
##   gauge.min_value = 0; gauge.max_value = 150; gauge.unit = "%"
##   gauge.bands = [{"lo": 40.0, "hi": 80.0, "label": "healthy"}]
##   gauge.value = 62.0
## Reads colours from the theme type "SkChart" (SkTheme provides it); works without a theme too.

# === CONSTANTS ===
const FALLBACK: Dictionary = {
	"text": Color(0.92, 0.95, 0.98), "text_dim": Color(0.7, 0.76, 0.82), "bg": Color(0.09, 0.14, 0.20),
	"edge": Color(0.5, 0.6, 0.7), "band": Color(0.35, 0.85, 0.45, 0.3), "ok": Color(0.55, 0.92, 0.6),
	"warn": Color(1.0, 0.78, 0.4),
}

# === PUBLIC VARIABLES ===
var heading: String = ""
var unit: String = ""
var min_value: float = 0.0
var max_value: float = 100.0
var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()
## Each band: {"lo": float, "hi": float, "label": String}. The first band is the one the verdict refers to.
var bands: Array[Dictionary] = []
var value_format: String = "%.0f"
var tick_count: int = 5


# === LIFECYCLE METHODS ===
func _init() -> void:
	custom_minimum_size = Vector2(240.0, 96.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# === PUBLIC METHODS ===
## "in the healthy range" / "below the healthy range" / "above the healthy range", or "" without a band.
func verdict() -> String:
	if bands.is_empty():
		return ""
	var b: Dictionary = bands[0]
	var label: String = str(b.get("label", "range"))
	if value < float(b["lo"]):
		return "below the %s range" % label
	if value > float(b["hi"]):
		return "above the %s range" % label
	return "in the %s range" % label


## For screen readers and tests: "Rabbits vs food supply: 62 %, in the healthy range."
func describe() -> String:
	var text: String = "%s: %s%s" % [heading if heading != "" else "Value", value_format % value, (" " + unit) if unit != "" else ""]
	var v: String = verdict()
	return text + (", " + v + "." if v != "" else ".")


# === PRIVATE METHODS ===
func _color(name: String) -> Color:
	if has_theme_color(name, "SkChart"):
		return get_theme_color(name, "SkChart")
	return FALLBACK[name]


func _x(v: float, bar: Rect2) -> float:
	var span: float = maxf(max_value - min_value, 1e-9)
	return bar.position.x + bar.size.x * clampf((v - min_value) / span, 0.0, 1.0)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fsize: int = maxi(get_theme_default_font_size() - 2, 11)
	var text_c: Color = _color("text")
	var bar: Rect2 = Rect2(10.0, 54.0, maxf(size.x - 20.0, 20.0), 16.0)
	draw_string(font, Vector2(0.0, fsize + 1.0), "%s: %s%s" % [heading, value_format % value, (" " + unit) if unit != "" else ""],
			HORIZONTAL_ALIGNMENT_LEFT, size.x, fsize + 2, text_c)
	var v: String = verdict()
	if v != "":
		var good: bool = v.begins_with("in ")
		draw_string(font, Vector2(0.0, fsize * 2.0 + 5.0), v.substr(0, 1).to_upper() + v.substr(1),
				HORIZONTAL_ALIGNMENT_LEFT, size.x, fsize, _color("ok") if good else _color("warn"))
	draw_rect(bar, _color("bg"))
	for b: Dictionary in bands:
		var x0: float = _x(float(b["lo"]), bar)
		var x1: float = _x(float(b["hi"]), bar)
		draw_rect(Rect2(x0, bar.position.y, x1 - x0, bar.size.y), _color("band"))
		draw_string(font, Vector2(x0, bar.position.y - 4.0), str(b.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize - 1, _color("ok"))
	draw_rect(bar, _color("edge"), false, 1.0)
	for i: int in range(tick_count + 1):
		var tv: float = min_value + (max_value - min_value) * float(i) / float(tick_count)
		var x: float = _x(tv, bar)
		draw_line(Vector2(x, bar.end.y), Vector2(x, bar.end.y + 4.0), _color("text_dim"), 1.0)
		draw_string(font, Vector2(x - 20.0, bar.end.y + fsize + 5.0), value_format % tv, HORIZONTAL_ALIGNMENT_CENTER, 40.0, fsize - 1, _color("text_dim"))
	var mx: float = _x(value, bar)
	draw_line(Vector2(mx, bar.position.y - 2.0), Vector2(mx, bar.end.y + 2.0), text_c, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(mx, bar.position.y + 1.0), Vector2(mx - 7.0, bar.position.y - 10.0), Vector2(mx + 7.0, bar.position.y - 10.0)]), text_c)
