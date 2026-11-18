class_name SkUi
extends RefCounted
## Tiny factory functions for the controls every code-built UI creates over and over
## (each existing project had its own _make_button / _label). Touch-sized and keyboard-focusable by default.

## 52 base px = 44 CSS px at SkViewScaler's smallest scale (0.85), the usual minimum touch-target size.
const TOUCH_MIN: float = 52.0


## A button. `wrap` lets long text flow onto several lines and makes the button fill its container's width.
## Put wrapping buttons in a VBoxContainer: inside an HFlowContainer a wrapping button gets no minimum width
## and collapses into a tall, empty bar.
static func button(text: String, toggle: bool = false, wrap: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
	if wrap:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## A label. `wrap` makes it flow onto several lines inside a container (it then needs a width: put it in an
## expanding container or set custom_minimum_size.x).
static func label(text: String, font_size: int = 0, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 1.0
	return l


static func heading(text: String) -> Label:
	return label(text, 20, true)


## A panel with a vertical box inside. Returns the box; the panel is `box.get_parent()`.
static func panel_box(separation: int = 8) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	panel.add_child(box)
	return box


## A scroll area that never scrolls sideways, for side panels in small frames.
static func vscroll(content: Control) -> ScrollContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc
