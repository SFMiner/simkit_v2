class_name SkSplitView
extends Control
## A responsive two-pane layout: a main pane (the picture, the graph) and a side pane (the controls).
##   wide   (width >= narrow_below): side by side; the side pane scrolls by itself, so the main pane keeps
##                                 the whole height.
##   narrow (width <  narrow_below): stacked, in one vertical scroll area, so nothing is cut off on a phone
##                                 or in a small iframe. The main pane gets `main_min_height`.
## Content never shrinks below readable size (see SkViewScaler); it scrolls instead.
##
##   var split := SkSplitView.new()
##   split.set_panes(main_box, side_box)          # any Controls; side_box is usually a VBoxContainer
##   add_child(split)
## `size` is measured in the layout's own (base) pixels, which SkViewScaler keeps >= 0.85 CSS px each.

# === PUBLIC VARIABLES ===
## Width (px) below which the panes stack.
var narrow_below: float = 780.0
var side_width: float = 420.0
var main_min_height: float = 440.0
var main: Control = null
var side: Control = null

# === PRIVATE VARIABLES ===
var _wide_box: HBoxContainer = HBoxContainer.new()
var _side_scroll: ScrollContainer = null
var _narrow_scroll: ScrollContainer = ScrollContainer.new()
var _narrow_box: VBoxContainer = VBoxContainer.new()
var _narrow: bool = false
var _built: bool = false


# === LIFECYCLE METHODS ===
func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wide_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wide_box.add_theme_constant_override("separation", 12)
	add_child(_wide_box)
	_narrow_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_narrow_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_narrow_scroll.follow_focus = true
	_narrow_scroll.visible = false
	add_child(_narrow_scroll)
	_narrow_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_narrow_box.add_theme_constant_override("separation", 12)
	_narrow_scroll.add_child(_narrow_box)
	_side_scroll = ScrollContainer.new()
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_scroll.follow_focus = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


# === PUBLIC METHODS ===
func set_panes(p_main: Control, p_side: Control) -> void:
	main = p_main
	side = p_side
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_built = true
	_place(size.x < narrow_below)


func is_narrow() -> bool:
	return _narrow


# === PRIVATE METHODS ===
func _relayout() -> void:
	if _built and (size.x < narrow_below) != _narrow:
		_place(size.x < narrow_below)


func _place(narrow: bool) -> void:
	_narrow = narrow
	for pane: Control in [main, side]:
		if pane.get_parent() != null:
			pane.get_parent().remove_child(pane)
	if _side_scroll.get_parent() != null:
		_side_scroll.get_parent().remove_child(_side_scroll)
	if _side_scroll.get_child_count() > 0:
		for c: Node in _side_scroll.get_children():
			_side_scroll.remove_child(c)
	_wide_box.visible = not narrow
	_narrow_scroll.visible = narrow
	if narrow:
		main.custom_minimum_size.y = main_min_height
		_narrow_box.add_child(main)
		_narrow_box.add_child(side)
	else:
		main.custom_minimum_size.y = 0.0
		_wide_box.add_child(main)
		_side_scroll.custom_minimum_size.x = side_width
		_side_scroll.add_child(side)
		_wide_box.add_child(_side_scroll)
