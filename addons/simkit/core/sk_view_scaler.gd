class_name SkViewScaler
extends Node
## Keeps text and controls readable in any frame, from a 1180 x 500 iframe to a phone to full screen.
## Design the UI at `base_size`; this node sets the window's content_scale_size so the UI is never
## smaller than `min_css_scale` CSS pixels per base pixel (so 16 px text is never below ~13.6 CSS px).
## Below that size the layout must scroll or wrap rather than shrink further.
##
## Requires Project Settings: display/window/stretch/mode = canvas_items, aspect = expand.
##
##   var scaler := SkViewScaler.new()
##   scaler.base_size = Vector2(1280, 720)
##   add_child(scaler)
##   scaler.scale_changed.connect(func(css, view): relayout(view))

# === SIGNALS ===
## `css_scale` = CSS pixels per base pixel; `view_size` = the layout area in base pixels.
signal scale_changed(css_scale: float, view_size: Vector2)

# === PUBLIC VARIABLES ===
var base_size: Vector2 = Vector2(1280.0, 720.0)
var min_css_scale: float = 0.85
## The layout is never made narrower than this many base px (very small frames show less, not tinier text).
var min_view_width: float = 400.0
## The player's text-size setting (SkA11y.text_scale()): enlarges the whole UI.
var text_scale: float = 1.0:
	set(v):
		text_scale = clampf(v, 0.5, 3.0)
		if is_inside_tree():
			apply()
var css_scale: float = 1.0
var view_size: Vector2 = Vector2.ZERO

# === PRIVATE VARIABLES ===
var _applying: bool = false


# === LIFECYCLE METHODS ===
func _ready() -> void:
	get_tree().root.size_changed.connect(apply)
	apply()


# === PUBLIC METHODS ===
## Screen pixels per base pixel for a window of `window` physical px on a display with `dpr` physical
## px per CSS px. Pure function: tested without a window.
static func scale_for(window: Vector2, dpr: float, base: Vector2, p_text_scale: float = 1.0,
		p_min_css: float = 0.85, p_min_view_width: float = 400.0) -> float:
	var fit: float = minf(window.x / base.x, window.y / base.y)
	var s: float = maxf(fit, p_min_css * dpr) * p_text_scale
	return maxf(minf(s, window.x / p_min_view_width), 0.1)


func apply() -> void:
	if _applying:
		return
	_applying = true
	var win: Window = get_window()
	var window_size: Vector2 = Vector2(win.size)
	if window_size.x >= 1.0 and window_size.y >= 1.0:
		var dpr: float = SkHost.device_pixel_ratio()
		var s: float = scale_for(window_size, dpr, base_size, text_scale, min_css_scale, min_view_width)
		win.content_scale_size = Vector2i((window_size / s).floor())
		css_scale = s / dpr
		view_size = window_size / s
		scale_changed.emit(css_scale, view_size)
	_applying = false


## A size in CSS px (a 44 px touch target) expressed in base px at the current scale.
func css_to_base(css_px: float) -> float:
	return css_px / maxf(css_scale, 0.01)
