class_name SkLesson
extends RefCounted
## The teaching text that wraps a simulation, as plain data. Every part is optional: leave a field empty
## and SkLessonPanel simply does not show that section. A lesson can be written in code or loaded from JSON
## (so a teacher-editable file can replace it without touching scripts).
##
##   var lesson := SkLesson.from_dict({
##       "title": "Rabbits and foxes",
##       "objectives": ["Explain why predator and prey numbers rise and fall together."],
##       "instructions": "Press Start. Change the food supply while it runs.",
##       "prediction": {"id": "p1", "prompt": "If food supply doubles, rabbits will...",
##                      "choices": ["stay the same", "rise a little", "rise a lot"]},
##       "observations": [{"id": "o1", "prompt": "What happened to the foxes?", "choices": ["rose", "fell"]}],
##       "explanation": "More food lets rabbits breed faster, which feeds more foxes...",
##       "reflection": ["Where might this model be wrong?"],
##       "vocabulary": {"predator": "An animal that hunts and eats other animals."}
##   })
## A prompt WITHOUT "choices" is just displayed text (a thinking prompt). Free-text answers are not supported
## on purpose: they cannot be checked, and they invite personal information.

var title: String = ""
var objectives: PackedStringArray = PackedStringArray()
var instructions: String = ""
## {"id": String, "prompt": String, "choices": PackedStringArray} or {}
var prediction: Dictionary = {}
## Each: {"id", "prompt", "choices"} (choices may be empty)
var observations: Array[Dictionary] = []
## Shown only after the student asks for it, so it does not spoil an investigation.
var explanation: String = ""
var reflection: Array[Dictionary] = []
## term -> definition
var vocabulary: Dictionary = {}


static func from_dict(d: Dictionary) -> SkLesson:
	var l: SkLesson = SkLesson.new()
	l.title = str(d.get("title", ""))
	l.objectives = _strings(d.get("objectives", []))
	l.instructions = str(d.get("instructions", ""))
	l.prediction = _prompt(d.get("prediction", {}), "prediction")
	l.observations = _prompts(d.get("observations", []), "obs")
	l.explanation = str(d.get("explanation", ""))
	l.reflection = _prompts(d.get("reflection", []), "ref")
	var vocab: Variant = d.get("vocabulary", {})
	if vocab is Dictionary:
		for term: Variant in vocab:
			l.vocabulary[str(term)] = str(vocab[term])
	return l


## Parses JSON text. Returns an empty lesson (and a warning) if the text is not a JSON object.
static func from_json(text: String) -> SkLesson:
	var json: JSON = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return from_dict(json.data)
	push_warning("SkLesson.from_json: not a JSON object")
	return SkLesson.new()


func is_empty() -> bool:
	return title == "" and objectives.is_empty() and instructions == "" and prediction.is_empty() \
			and observations.is_empty() and explanation == "" and reflection.is_empty() and vocabulary.is_empty()


# === PRIVATE METHODS ===
static func _strings(v: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if v is Array:
		for item: Variant in v:
			out.append(str(item))
	return out


static func _prompt(v: Variant, fallback_id: String) -> Dictionary:
	if v is String:
		return {"id": fallback_id, "prompt": v, "choices": PackedStringArray()}
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		return {}
	var d: Dictionary = v
	return {"id": str(d.get("id", fallback_id)), "prompt": str(d.get("prompt", "")),
			"choices": _strings(d.get("choices", []))}


static func _prompts(v: Variant, prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		var i: int = 0
		for item: Variant in v:
			var p: Dictionary = _prompt(item, "%s%d" % [prefix, i + 1])
			if not p.is_empty():
				out.append(p)
			i += 1
	return out
