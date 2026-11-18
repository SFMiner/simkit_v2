class_name SkShell
extends Control
## The top-level wiring every SimKit game needs, in one node: background in the palette's colour, a top
## bar with the title and the host's reserved corner (its Full screen button stays uncovered), the
## accessibility settings (theme, text size, high contrast, reduced motion), the view scaler and the
## keyboard ring. Put your simulation in it as the content:
##
##   extends SkShell
##   var sim := MySim.new()
##   func _ready() -> void:
##   	title = "How does dye spread through water?"
##   	super._ready()                  # loads the player's settings, builds the frame
##   	sim.setup(a11y)                 # your simulation reads the settings while building
##   	set_content(sim)
##   	print("mygame: boot ok")
##
## Tab order: by default every focusable control inside the content, in tree order (what a reader sees,
## top to bottom, main pane then side pane). Set `focus_provider` to a Callable returning an Array of
## Controls to choose the order yourself. Settings saved by the player are loaded unless `load_settings`
## is false (tests set values directly and keep the player's file untouched with a11y.persist = false).

# === PUBLIC VARIABLES ===
var title: String = "":
	set(v):
		title = v
		if _title_label != null:
			_title_label.text = v
			_title_label.visible = v != ""
## The size the layout is designed for (SkViewScaler.base_size).
var base_size: Vector2 = Vector2(1180.0, 560.0)
## Point size of the title.
var title_size: int = 22
var load_settings: bool = true
## Optional: returns the Controls Tab walks, in order. Default: the content's focusable controls.
var focus_provider: Callable = Callable()
var a11y: SkA11y = SkA11y.new()
var scaler: SkViewScaler = SkViewScaler.new()
var ring: SkFocusRing = SkFocusRing.new()
var content: Control = null
## Holds the title; add your own controls (a help button) to it if you like, before the reserved corner.
var top_bar: HBoxContainer = HBoxContainer.new()

# === PRIVATE VARIABLES ===
var _background: ColorRect = ColorRect.new()
var _corner: Control = Control.new()
var _content_box: MarginContainer = MarginContainer.new()
var _title_label: Label = null
var _built: bool = false


# === LIFECYCLE METHODS ===
func _ready() -> void:
	_build()


# === PUBLIC METHODS ===
## Puts `p_content` under the top bar, filling the rest of the screen. Replaces any earlier content.
func set_content(p_content: Control) -> void:
	if content != null and content.get_parent() == _content_box:
		_content_box.remove_child(content)
	content = p_content
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_child(content)


## The controls Tab walks: `focus_provider` if set, else every focusable control in the content, in order.
func focus_controls() -> Array:
	if focus_provider.is_valid():
		return focus_provider.call()
	var out: Array[Control] = []
	if content != null:
		_collect_focusable(content, out)
	return out


## Every Control under `node`, in tree order, that takes keyboard focus. Containers that only scroll are skipped.
static func focusable_descendants(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusable(node, out)
	return out


# === PRIVATE METHODS ===
static func _collect_focusable(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var c: Control = child
			if c.focus_mode == Control.FOCUS_ALL and not (c is ScrollContainer) and not (c is ScrollBar):
				out.append(c)
		_collect_focusable(child, out)


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if load_settings:
		a11y.load_saved()
		a11y.read_browser()
	scaler.base_size = base_size
	add_child(scaler)
	a11y.bind(self, scaler)
	a11y.changed.connect(_on_a11y_changed)

	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	move_child(_background, 0)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_box)
	top_bar.add_theme_constant_override("separation", 12)
	root_box.add_child(top_bar)
	_title_label = SkUi.label(title, title_size, true)
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_label.visible = title != ""
	top_bar.add_child(_title_label)
	top_bar.move_child(_title_label, 0)
	top_bar.add_child(_corner)
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "bottom"]:
		_content_box.add_theme_constant_override("margin_" + side, 10)
	root_box.add_child(_content_box)

	scaler.scale_changed.connect(_on_scale_changed)
	_on_scale_changed(scaler.css_scale, scaler.view_size)
	_on_a11y_changed()
	ring.provider = focus_controls
	add_child(ring)


## Keeps the host page's Full screen button (top-right RESERVED_CSS) uncovered at any scale.
func _on_scale_changed(css: float, _view: Vector2) -> void:
	var reserved: Vector2 = SkHost.RESERVED_CSS / maxf(css, 0.01)
	_corner.custom_minimum_size.x = reserved.x
	top_bar.custom_minimum_size.y = reserved.y


func _on_a11y_changed() -> void:
	_background.color = SkTheme.palette(a11y.palette_name())["bg"]
	RenderingServer.set_default_clear_color(_background.color)
