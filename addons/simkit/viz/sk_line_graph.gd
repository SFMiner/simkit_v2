class_name SkLineGraph
extends Control
## A small line graph of one or more series over x (usually time or generation).
## Series are told apart by more than colour: the line style (solid / dashed "kept run"), a marker shape
## on the newest point, and a direct label at the end of the line, so no legend lookup is needed.
## Optional shaded bands (a "normal range"), fixed or automatic y range, and a text description for
## screen readers.
##
##   graph.title = "Population"; graph.x_label = "Month"
##   graph.x_range = Vector2(0, 100)           # fixed; or leave auto_x = true
##   graph.set_series("rabbits", "Rabbits", points)         # PackedVector2Array
##   graph.append_point("foxes", "Foxes", month, count)     # creates the series on first use
##   graph.bands = [{"lo": 135.0, "hi": 145.0, "label": "normal"}]
## Reads colours from the theme type "SkChart" (SkTheme provides it); works without a theme too.

# === CONSTANTS ===
const MARGIN_LEFT: float = 52.0
const MIN_MARGIN_RIGHT: float = 24.0
const MARGIN_TOP: float = 28.0
const MARGIN_BOTTOM: float = 38.0
const MAX_POINTS: int = 20000
const FALLBACK: Dictionary = {
	"text": Color(0.92, 0.95, 0.98), "text_dim": Color(0.7, 0.76, 0.82), "bg": Color(0.09, 0.14, 0.20),
	"edge": Color(0.5, 0.6, 0.7), "grid": Color(1, 1, 1, 0.14), "band": Color(0.35, 0.85, 0.45, 0.2),
	"ok": Color(0.55, 0.92, 0.6),
}

# === PUBLIC VARIABLES ===
var title: String = ""
var x_label: String = ""
var y_label: String = ""
var auto_x: bool = false
var auto_y: bool = true
var x_range: Vector2 = Vector2(0.0, 1.0)
var y_range: Vector2 = Vector2(0.0, 1.0)
## Each band: {"lo": float, "hi": float, "label": String}
var bands: Array[Dictionary] = []
## printf-style formats for the axis numbers ("%.0f", "%.1f%%"). "" = choose the digits from the tick spacing.
var y_format: String = ""
var x_format: String = ""

# === PRIVATE VARIABLES ===
## Each series: {"id", "label", "points": PackedVector2Array, "dashed": bool}
var _series: Array[Dictionary] = []


# === LIFECYCLE METHODS ===
func _init() -> void:
	custom_minimum_size = Vector2(240.0, 140.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# === PUBLIC METHODS ===
func clear() -> void:
	_series.clear()
	queue_redraw()


func remove_series(id: String) -> void:
	for i: int in range(_series.size()):
		if _series[i]["id"] == id:
			_series.remove_at(i)
			break
	queue_redraw()


## Replaces (or creates) a series. `dashed` is for a kept / comparison run.
func set_series(id: String, label: String, points: PackedVector2Array, dashed: bool = false) -> void:
	var s: Dictionary = _find(id)
	if s.is_empty():
		s = {"id": id, "label": label, "points": PackedVector2Array(), "dashed": dashed}
		_series.append(s)
	s["label"] = label
	s["dashed"] = dashed
	s["points"] = points
	queue_redraw()


func append_point(id: String, label: String, x: float, y: float) -> void:
	var s: Dictionary = _find(id)
	if s.is_empty():
		set_series(id, label, PackedVector2Array())
		s = _find(id)
	var pts: PackedVector2Array = s["points"]
	if pts.size() >= MAX_POINTS:
		return
	pts.append(Vector2(x, y))
	s["points"] = pts
	queue_redraw()


func series_ids() -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in _series:
		out.append(s["id"])
	return out


## A copy of a series' points (for keeping a run to compare with the next one).
func series_points(id: String) -> PackedVector2Array:
	var s: Dictionary = _find(id)
	return PackedVector2Array() if s.is_empty() else (s["points"] as PackedVector2Array).duplicate()


func point_count(id: String) -> int:
	var s: Dictionary = _find(id)
	return 0 if s.is_empty() else (s["points"] as PackedVector2Array).size()


## A sentence per series for screen readers and tests: "Rabbits: 12 points, latest 41.5, range 12.0 to 80.2."
func describe() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if title != "":
		parts.append(title + ".")
	for s: Dictionary in _series:
		var pts: PackedVector2Array = s["points"]
		if pts.is_empty():
			parts.append("%s: no data yet." % s["label"])
			continue
		var lo: float = pts[0].y
		var hi: float = pts[0].y
		for p: Vector2 in pts:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		parts.append("%s: %d points, latest %s, from %s to %s." % [s["label"], pts.size(),
				_fmt(y_format, pts[pts.size() - 1].y, 1), _fmt(y_format, lo, 1), _fmt(y_format, hi, 1)])
	return " ".join(parts)


## "Nice" tick values between lo and hi (about `target` of them): 0, 20, 40... Static and testable.
static func nice_ticks(lo: float, hi: float, target: int = 5) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if not (hi > lo) or target < 1:
		return out
	var raw: float = (hi - lo) / float(target)
	var magnitude: float = pow(10.0, floor(log(raw) / log(10.0)))
	var residual: float = raw / magnitude
	var nice: float = 1.0
	if residual > 5.0:
		nice = 10.0
	elif residual > 2.0:
		nice = 5.0
	elif residual > 1.0:
		nice = 2.0
	var step: float = nice * magnitude
	var k: int = int(ceil(lo / step - 1e-9))
	while float(k) * step <= hi + step * 1e-9:
		# Multiply (not accumulate) and round to 12 places, so 0.1 * 3 is 0.3 and 100 stays exactly 100.
		out.append(("%.12f" % (float(k) * step)).to_float())
		k += 1
	return out


# === PRIVATE METHODS ===
static func _fmt(fmt: String, v: float, decimals: int) -> String:
	return (fmt % v) if fmt != "" else ("%.*f" % [decimals, v])


## Digits needed to show every tick exactly: 0 for 0,20,40; 1 for 0,0.5,1; 2 for 0,0.25...
static func _tick_decimals(ticks: PackedFloat64Array) -> int:
	if ticks.size() < 2:
		return 0
	var step: float = absf(ticks[1] - ticks[0])
	if step >= 1.0 - 1e-9:
		return 0
	return clampi(int(ceil(-log(step) / log(10.0) - 1e-9)), 0, 6)


func _find(id: String) -> Dictionary:
	for s: Dictionary in _series:
		if s["id"] == id:
			return s
	return {}


func _color(name: String) -> Color:
	if has_theme_color(name, "SkChart"):
		return get_theme_color(name, "SkChart")
	return FALLBACK[name]


## Room on the right for the widest end-of-line label, so no label is ever cut off.
func _margin_right() -> float:
	var font: Font = get_theme_default_font()
	var fsize: int = maxi(get_theme_default_font_size() - 3, 11)
	var widest: float = 0.0
	for s: Dictionary in _series:
		widest = maxf(widest, font.get_string_size(str(s["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x)
	return clampf(widest + 22.0, MIN_MARGIN_RIGHT, maxf(size.x * 0.4, MIN_MARGIN_RIGHT))


func _plot() -> Rect2:
	return Rect2(MARGIN_LEFT, MARGIN_TOP, maxf(10.0, size.x - MARGIN_LEFT - _margin_right()),
			maxf(10.0, size.y - MARGIN_TOP - MARGIN_BOTTOM))


func _ranges() -> Array[Vector2]:
	var xr: Vector2 = x_range
	var yr: Vector2 = y_range
	if auto_x or auto_y:
		var x_lo: float = INF
		var x_hi: float = -INF
		var y_lo: float = INF
		var y_hi: float = -INF
		for s: Dictionary in _series:
			for p: Vector2 in (s["points"] as PackedVector2Array):
				x_lo = minf(x_lo, p.x)
				x_hi = maxf(x_hi, p.x)
				y_lo = minf(y_lo, p.y)
				y_hi = maxf(y_hi, p.y)
		if x_lo <= x_hi and auto_x:
			xr = Vector2(x_lo, maxf(x_hi, x_lo + 1.0))
		if y_lo <= y_hi and auto_y:
			var pad: float = maxf((y_hi - y_lo) * 0.08, 1e-6)
			yr = Vector2(minf(y_lo, 0.0) if y_lo >= 0.0 and y_lo < (y_hi - y_lo) else y_lo - pad, y_hi + pad)
	if not (yr.y > yr.x):
		yr.y = yr.x + 1.0
	if not (xr.y > xr.x):
		xr.y = xr.x + 1.0
	return [xr, yr]


func _to_point(plot: Rect2, xr: Vector2, yr: Vector2, p: Vector2) -> Vector2:
	return Vector2(plot.position.x + plot.size.x * clampf((p.x - xr.x) / (xr.y - xr.x), 0.0, 1.0),
			plot.end.y - plot.size.y * clampf((p.y - yr.x) / (yr.y - yr.x), 0.0, 1.0))


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fsize: int = maxi(get_theme_default_font_size() - 3, 11)
	var text_c: Color = _color("text")
	var dim_c: Color = _color("text_dim")
	draw_rect(Rect2(Vector2.ZERO, size), _color("bg"))
	draw_rect(Rect2(Vector2.ZERO, size), _color("edge"), false, 1.0)
	var plot: Rect2 = _plot()
	var r: Array[Vector2] = _ranges()
	var xr: Vector2 = r[0]
	var yr: Vector2 = r[1]
	if title != "":
		draw_string(font, Vector2(8.0, 19.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fsize + 2, text_c)
	# bands
	for b: Dictionary in bands:
		var top: float = _to_point(plot, xr, yr, Vector2(xr.x, float(b["hi"]))).y
		var bottom: float = _to_point(plot, xr, yr, Vector2(xr.x, float(b["lo"]))).y
		draw_rect(Rect2(plot.position.x, top, plot.size.x, bottom - top), _color("band"))
		draw_string(font, Vector2(plot.position.x + 6.0, top + fsize + 1.0), str(b.get("label", "")),
				HORIZONTAL_ALIGNMENT_LEFT, plot.size.x - 12.0, fsize, _color("ok"))
	# grid + y ticks
	var y_ticks: PackedFloat64Array = nice_ticks(yr.x, yr.y, 4)
	var y_digits: int = _tick_decimals(y_ticks)
	for t: float in y_ticks:
		var y: float = _to_point(plot, xr, yr, Vector2(xr.x, t)).y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), _color("grid"), 1.0)
		draw_string(font, Vector2(2.0, y + 4.0), _fmt(y_format, t, y_digits), HORIZONTAL_ALIGNMENT_RIGHT, MARGIN_LEFT - 8.0, fsize, dim_c)
	var x_ticks: PackedFloat64Array = nice_ticks(xr.x, xr.y, 5)
	var x_digits: int = _tick_decimals(x_ticks)
	for t: float in x_ticks:
		var x: float = _to_point(plot, xr, yr, Vector2(t, yr.x)).x
		draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + 4.0), dim_c, 1.0)
		draw_string(font, Vector2(x - 24.0, plot.end.y + fsize + 6.0), _fmt(x_format, t, x_digits), HORIZONTAL_ALIGNMENT_CENTER, 48.0, fsize, dim_c)
	draw_rect(plot, _color("edge"), false, 1.0)
	if x_label != "":
		draw_string(font, Vector2(plot.position.x, size.y - 4.0), x_label, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, fsize, dim_c)
	if y_label != "":
		draw_string(font, Vector2(8.0, MARGIN_TOP - 6.0), y_label, HORIZONTAL_ALIGNMENT_LEFT, MARGIN_LEFT + 80.0, fsize, dim_c)
	# series
	for i: int in range(_series.size()):
		var s: Dictionary = _series[i]
		var pts: PackedVector2Array = s["points"]
		if pts.is_empty():
			continue
		var slot: String = "series_%d" % posmod(i, SkTheme.SERIES.size())
		var color: Color = get_theme_color(slot, "SkChart") if has_theme_color(slot, "SkChart") else SkTheme.series_color(i)
		var screen: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			screen.append(_to_point(plot, xr, yr, p))
		if bool(s["dashed"]):
			for k: int in range(screen.size() - 1):
				if k % 2 == 0:
					draw_line(screen[k], screen[k + 1], color, 2.0)
		elif screen.size() >= 2:
			draw_polyline(screen, color, 2.5, true)
		var end: Vector2 = screen[screen.size() - 1]
		_marker(end, i, color)
		draw_string(font, end + Vector2(10.0, 4.0), str(s["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, color)


## A different shape per series: circle, square, triangle, diamond.
func _marker(at: Vector2, index: int, color: Color) -> void:
	var rad: float = 5.0
	match index % 4:
		0:
			draw_circle(at, rad, color)
		1:
			draw_rect(Rect2(at - Vector2(rad, rad), Vector2(rad, rad) * 2.0), color)
		2:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -rad - 1), at + Vector2(rad + 1, rad), at + Vector2(-rad - 1, rad)]), color)
		3:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -rad - 1), at + Vector2(rad + 1, 0), at + Vector2(0, rad + 1), at + Vector2(-rad - 1, 0)]), color)
