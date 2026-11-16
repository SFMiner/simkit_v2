extends VBoxContainer
## The smallest useful SimKit simulation: a cup of coffee cooling toward room temperature.
## Core + graph + parameter panel + transport bar. No lesson, no log, no gauge. About 40 lines of code.
## Newton's law of cooling, solved exactly each step:  T = room + (T - room) * e^(-k dt)

var params: SkParams = SkParams.new()
var session: SkSession = SkSession.new()
var graph: SkLineGraph = SkLineGraph.new()
var bar: SkTransportBar = SkTransportBar.new()
var panel: SkParamPanel = SkParamPanel.new()
var temp: float = 90.0


func setup(_a11y: SkA11y) -> void:
	pass  # the launcher calls this; a standalone game would not need it


func _ready() -> void:
	params.add(SkParam.float_param("k", "Cooling rate", 0.1, 0.02, 0.5, 0.02).with_unit("per minute"))
	params.add(SkParam.float_param("room", "Room temperature", 20.0, 0.0, 40.0, 1.0).with_unit("C"))
	session.duration = 60.0
	session.clock.step = 0.1
	session.speed = 4.0
	session.on_step = func(dt: float) -> void:
		var room: float = params.get_float("room")
		temp = room + (temp - room) * exp(-params.get_float("k") * dt)
		graph.append_point("cup", "Coffee", session.sim_time + dt, temp)
	session.on_reset = func() -> void:
		temp = 90.0
		graph.clear()
		graph.append_point("cup", "Coffee", 0.0, temp)
	add_child(session)
	graph.title = "Coffee temperature (C)"
	graph.x_label = "Minutes"
	graph.x_range = Vector2(0.0, 60.0)
	graph.y_range = Vector2(0.0, 100.0)
	graph.auto_y = false
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(graph)
	bar.bind(session)
	add_child(bar)
	panel.bind(params)
	add_child(panel)
	session.reset()


func focus_controls() -> Array[Control]:
	return bar.focus_controls() + panel.focus_controls()
