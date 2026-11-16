extends Control
## Launcher for the two demos. It is also the reference for how a SimKit game is wired at the top level:
## accessibility settings -> theme + text size, view scaler, keyboard ring, query settings, host messages.
## Open one directly with ?demo=predator_prey or ?demo=natural_selection (desktop: -- --demo=natural_selection).

const PredatorPreyDemo = preload("res://demo/predator_prey/predator_prey_demo.gd")
const NaturalSelectionDemo = preload("res://demo/natural_selection/natural_selection_demo.gd")
const CoolingDemo = preload("res://demo/minimal/cooling_demo.gd")
const DEMO_IDS: PackedStringArray = ["menu", "predator_prey", "natural_selection", "cooling"]
const TITLES: Dictionary = {
	"predator_prey": "Rabbits and foxes",
	"natural_selection": "Moths and birds",
	"cooling": "Cooling coffee (minimal)",
}
const BLURBS: Dictionary = {
	"predator_prey": "Continuous model, fixed time step. Uses every SimKit module, including the lesson panel and data export.",
	"natural_selection": "Discrete, random, one generation per press. Uses far fewer modules: no lesson panel, no gauge.",
	"cooling": "About 40 lines: core + graph + parameter panel + transport bar. Shows the minimum needed for a working simulation.",
}

var a11y: SkA11y = SkA11y.new()
var scaler: SkViewScaler = SkViewScaler.new()
var ring: SkFocusRing = SkFocusRing.new()
var settings: SkParams = SkParams.new()
var current: Control = null
var current_id: String = "menu"

var _background: ColorRect = null
var _top_bar: HBoxContainer = null
var _title: Label = null
var _menu_button: Button = null
var _corner_spacer: Control = null
var _content: MarginContainer = null
var _menu_page: VBoxContainer = null
var _menu_scroll: ScrollContainer = null
var _menu_buttons: Array[Control] = []
var _a11y_panel: SkParamPanel = SkParamPanel.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--demo=") and SkHost.query_override == "":
			SkHost.query_override = "?demo=" + arg.substr(7)
	a11y.load_saved()
	a11y.read_browser()
	scaler.base_size = Vector2(1280.0, 720.0)
	add_child(scaler)
	a11y.bind(self, scaler)
	a11y.changed.connect(_on_a11y_changed)
	settings.add(SkParam.choice_param("demo", "Demo", DEMO_IDS, 0).as_class_setting())
	settings.apply_query(SkHost.query_string())

	_build_ui()
	scaler.scale_changed.connect(_on_scale_changed)
	_on_scale_changed(scaler.css_scale, scaler.view_size)
	_on_a11y_changed()
	ring.provider = _ring
	ring.close_topmost = _close_demo
	add_child(ring)
	open_demo(DEMO_IDS[settings.get_int("demo")])
	print("simkit: boot ok")


## The controls Tab walks right now.
func _ring() -> Array:
	var out: Array = []
	if current != null:
		out.append(_menu_button)
		out.append_array(current.call("focus_controls"))
	else:
		out.append_array(_menu_buttons)
		out.append_array(_a11y_panel.focus_controls())
	return out


func open_demo(id: String) -> void:
	if current != null:
		current.queue_free()
		_content.remove_child(current)
		current = null
	current_id = id
	_menu_scroll.visible = id == "menu"
	_menu_button.visible = id != "menu"
	_title.text = "SimKit demos" if id == "menu" else str(TITLES[id])
	if id == "predator_prey":
		current = PredatorPreyDemo.new()
	elif id == "natural_selection":
		current = NaturalSelectionDemo.new()
	elif id == "cooling":
		current = CoolingDemo.new()
	if current != null:
		current.call("setup", a11y)
		_content.add_child(current)
		SkHost.announce("Opened " + str(TITLES[id]))
	else:
		SkHost.announce("Demo menu")
	get_viewport().gui_release_focus()


## Escape closes the open demo (back to the menu); with the menu showing it leaves the game.
func _close_demo() -> bool:
	if current == null:
		return false
	open_demo("menu")
	return true


func _on_scale_changed(css: float, view: Vector2) -> void:
	# A narrow frame has no room for a title beside the button and the reserved corner.
	_title.visible = view.x >= 640.0
	# Keep the host page's Full screen button (top-right 200 x 64 CSS px) uncovered.
	var reserved: Vector2 = SkHost.RESERVED_CSS / maxf(css, 0.01)
	_corner_spacer.custom_minimum_size.x = reserved.x
	_top_bar.custom_minimum_size.y = reserved.y


func _on_a11y_changed() -> void:
	_background.color = SkTheme.palette(a11y.palette_name())["bg"]
	RenderingServer.set_default_clear_color(_background.color)


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 0)
	add_child(root_box)
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 12)
	root_box.add_child(_top_bar)
	var pad: Control = Control.new()
	pad.custom_minimum_size.x = 8.0
	_top_bar.add_child(pad)
	_menu_button = SkUi.button("Back to menu")
	_menu_button.pressed.connect(open_demo.bind("menu"))
	_top_bar.add_child(_menu_button)
	_title = SkUi.label("SimKit demos", 22, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_bar.add_child(_title)
	_corner_spacer = Control.new()
	_top_bar.add_child(_corner_spacer)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, 10)
	root_box.add_child(_content)

	_menu_page = VBoxContainer.new()
	_menu_page.add_theme_constant_override("separation", 10)
	_menu_page.custom_minimum_size.x = 420.0
	_menu_scroll = SkUi.vscroll(_menu_page)
	_menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_menu_scroll)
	_menu_page.add_child(SkUi.label("Two small simulations built with SimKit. Choose one.", 0, true))
	for id: String in TITLES:
		var b: Button = SkUi.button(str(TITLES[id]))
		b.pressed.connect(open_demo.bind(id))
		_menu_page.add_child(b)
		_menu_buttons.append(b)
		_menu_page.add_child(SkUi.label(str(BLURBS[id]), 0, true))
	_menu_page.add_child(SkUi.label("Display settings", 0, true))
	_a11y_panel.show_reset = false
	_a11y_panel.bind(a11y.params)
	_menu_page.add_child(_a11y_panel)
