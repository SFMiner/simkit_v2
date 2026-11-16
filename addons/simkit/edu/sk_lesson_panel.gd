class_name SkLessonPanel
extends VBoxContainer
## Shows an SkLesson beside a simulation: learning objectives, instructions, an optional prediction,
## observation prompts, a hidden-until-asked explanation, reflection prompts, and tap-for-definition
## vocabulary. Sections the lesson leaves empty are not built, so a small sim shows only what it has.
## Everything is a Label or a Button (no free-text entry), keyboard-focusable and touch-sized.
##
##   var panel := SkLessonPanel.new()
##   panel.log = log                     # optional: answers are recorded in the SkLog
##   panel.show_lesson(lesson)
##   side.add_child(panel)

# === SIGNALS ===
signal choice_made(prompt_id: String, choice_index: int, choice_text: String)
signal explanation_shown

# === PUBLIC VARIABLES ===
## Optional. Any object with record_response(prompt_id, prompt, choice) and record(kind, data) - normally an
## SkLog. Untyped on purpose, so this module works without the data module.
var log: Object = null
## Investigate-then-explain: the explanation button stays disabled until a prediction is made (if there is one).
var explanation_requires_prediction: bool = false
var lesson: SkLesson = null
var toggle_button: Button = null
var explanation_button: Button = null

# === PRIVATE VARIABLES ===
var _body: VBoxContainer = null
var _controls: Array[Control] = []
var _explanation_label: Label = null
var _definition_label: Label = null
var _prediction_made: bool = false


# === PUBLIC METHODS ===
func show_lesson(p_lesson: SkLesson) -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_controls.clear()
	_prediction_made = false
	lesson = p_lesson
	if lesson == null or lesson.is_empty():
		return
	add_theme_constant_override("separation", 8)
	toggle_button = SkUi.button("Lesson: %s (hide)" % lesson.title if lesson.title != "" else "Lesson (hide)", true)
	toggle_button.button_pressed = true
	toggle_button.toggled.connect(_on_toggle)
	add_child(toggle_button)
	_controls.append(toggle_button)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)

	if not lesson.objectives.is_empty():
		_body.add_child(SkUi.label("Learning objectives", 0, true))
		for o: String in lesson.objectives:
			_body.add_child(SkUi.label("- " + o, 0, true))
	if lesson.instructions != "":
		_body.add_child(SkUi.label("How to use it", 0, true))
		_body.add_child(SkUi.label(lesson.instructions, 0, true))
	if not lesson.prediction.is_empty():
		_add_prompt(lesson.prediction, "Predict", true)
	for p: Dictionary in lesson.observations:
		_add_prompt(p, "Observe", false)
	if lesson.explanation != "":
		explanation_button = SkUi.button("Show explanation")
		explanation_button.pressed.connect(_on_show_explanation)
		explanation_button.disabled = explanation_requires_prediction and not lesson.prediction.is_empty()
		_body.add_child(explanation_button)
		_controls.append(explanation_button)
		_explanation_label = SkUi.label(lesson.explanation, 0, true)
		_explanation_label.visible = false
		_body.add_child(_explanation_label)
	for p: Dictionary in lesson.reflection:
		_add_prompt(p, "Reflect", false)
	if not lesson.vocabulary.is_empty():
		_body.add_child(SkUi.label("Words to know (select one)", 0, true))
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_body.add_child(flow)
		for term: String in lesson.vocabulary:
			var b: Button = SkUi.button(term)
			b.pressed.connect(_on_term.bind(term))
			flow.add_child(b)
			_controls.append(b)
		_definition_label = SkUi.label("", 0, true)
		_body.add_child(_definition_label)


func focus_controls() -> Array[Control]:
	return _controls.duplicate()


## Shows the explanation now (also what its button does).
func reveal_explanation() -> void:
	_on_show_explanation()


# === PRIVATE METHODS ===
func _add_prompt(p: Dictionary, kind_label: String, is_prediction: bool) -> void:
	_body.add_child(SkUi.label("%s: %s" % [kind_label, p["prompt"]], 0, true))
	var choices: PackedStringArray = p["choices"]
	if choices.is_empty():
		return
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_body.add_child(flow)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in range(choices.size()):
		var b: Button = SkUi.button(choices[i], true)
		b.button_group = group
		b.pressed.connect(_on_choice.bind(p, i, is_prediction))
		flow.add_child(b)
		_controls.append(b)


func _on_choice(p: Dictionary, index: int, is_prediction: bool) -> void:
	var text: String = (p["choices"] as PackedStringArray)[index]
	if log != null and log.has_method("record_response"):
		log.record_response(str(p["id"]), str(p["prompt"]), text)
	if is_prediction:
		_prediction_made = true
		if explanation_button != null:
			explanation_button.disabled = false
	SkHost.announce("Chosen: " + text)
	choice_made.emit(str(p["id"]), index, text)


func _on_show_explanation() -> void:
	if _explanation_label == null or _explanation_label.visible:
		return
	_explanation_label.visible = true
	if explanation_button != null:
		explanation_button.disabled = true
		explanation_button.text = "Explanation shown"
	if log != null and log.has_method("record"):
		log.record("explanation_shown")
	SkHost.announce(lesson.explanation)
	explanation_shown.emit()


func _on_term(term: String) -> void:
	var definition: String = str(lesson.vocabulary[term])
	_definition_label.text = "%s: %s" % [term, definition]
	SkHost.announce(_definition_label.text)
	if log != null and log.has_method("record"):
		log.record("vocabulary", {"term": term})


func _on_toggle(pressed: bool) -> void:
	_body.visible = pressed
	toggle_button.text = toggle_button.text.replace("(show)", "(hide)") if pressed else toggle_button.text.replace("(hide)", "(show)")
