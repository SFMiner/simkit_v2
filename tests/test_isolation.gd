extends SkTest
## Proves the modules are optional: each combination is copied into a brand-new project (no other SimKit
## folders, none of this repo's scripts) and must import and load without errors. A negative control
## (lesson panel without the ui module it needs) must FAIL, which shows the harness can see a missing dependency.

const ADDON: String = "res://addons/simkit"
const OPTIONAL: PackedStringArray = ["ui", "viz", "data", "edu"]


func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(f)
	return out


func _copy_module(module: String, project_dir: String) -> int:
	var target: String = project_dir + "/addons/simkit/" + module
	DirAccess.make_dir_recursive_absolute(target)
	var n: int = 0
	for f: String in _scripts_in(ADDON + "/" + module):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(ADDON + "/" + module + "/" + f), target + "/" + f)
		n += 1
	return n


## Returns {"ok": bool, "output": String, "loaded": int, "scripts": int}
func _try(label: String, modules: PackedStringArray) -> Dictionary:
	var dir: String = OS.get_user_data_dir() + "/iso_" + label
	OS.execute("rm", ["-rf", dir])
	DirAccess.make_dir_recursive_absolute(dir)
	var count: int = 0
	for m: String in modules:
		count += _copy_module(m, dir)
	var pf: FileAccess = FileAccess.open(dir + "/project.godot", FileAccess.WRITE)
	pf.store_string("config_version=5\n[application]\nconfig/name=\"iso\"\nconfig/features=PackedStringArray(\"4.7\", \"GL Compatibility\")\n")
	pf.close()
	var chk: FileAccess = FileAccess.open(dir + "/check.gd", FileAccess.WRITE)
	chk.store_string("""extends SceneTree
func _initialize() -> void:
	var n: int = 0
	var failed: int = 0
	for m: String in DirAccess.get_directories_at("res://addons/simkit"):
		for f: String in DirAccess.get_files_at("res://addons/simkit/" + m):
			if f.ends_with(".gd"):
				if load("res://addons/simkit/%s/%s" % [m, f]) == null:
					failed += 1
				n += 1
	print("LOADED ", n, " FAILED ", failed)
	quit(1 if failed > 0 else 0)
""")
	chk.close()
	var exe: String = OS.get_executable_path()
	var out: Array = []
	OS.execute(exe, ["--headless", "--path", dir, "--import"], out, true)
	var text: String = "\n".join(out)
	var out2: Array = []
	var code: int = OS.execute(exe, ["--headless", "--path", dir, "--script", "res://check.gd"], out2, true)
	text += "\n" + "\n".join(out2)
	var bad: bool = text.contains("SCRIPT ERROR") or text.contains("Parse Error") or text.contains("Could not find type") or text.contains("not declared")
	var loaded: bool = text.contains("LOADED %d FAILED 0" % count)
	return {"ok": code == 0 and not bad and loaded, "output": text, "scripts": count}


func run() -> void:
	test_name = "test_isolation"
	# Core purity: no core file may name an optional module's classes.
	var optional_classes: Array[String] = ["SkParamPanel", "SkTransportBar", "SkUi", "SkLineGraph", "SkGauge", "SkLog", "SkExport", "SkLesson", "SkLessonPanel"]
	var leaks: Array[String] = []
	for f: String in _scripts_in(ADDON + "/core"):
		var text: String = FileAccess.get_file_as_string(ADDON + "/core/" + f)
		for c: String in optional_classes:
			# Comments may mention optional classes by name; code may not. Strip comment text first.
			for line: String in text.split("\n"):
				var code_part: String = line.split("#")[0]
				if code_part.contains(c):
					leaks.append("%s uses %s" % [f, c])
	check(leaks.is_empty(), "core never mentions an optional module's classes in code %s" % str(leaks))
	check(_scripts_in(ADDON + "/core").size() >= 9, "core has its modules")

	var r: Dictionary = await _try("core", PackedStringArray(["core"]))
	check(r["ok"], "core alone imports and loads (%d scripts)\n%s" % [r["scripts"], str(r["output"]).left(600) if not r["ok"] else ""])
	for m: String in ["ui", "viz", "data"]:
		var rr: Dictionary = await _try("core_" + m, PackedStringArray(["core", m]))
		check(rr["ok"], "core + %s imports and loads (%d scripts)\n%s" % [m, rr["scripts"], str(rr["output"]).left(600) if not rr["ok"] else ""])
	var edu: Dictionary = await _try("core_ui_edu", PackedStringArray(["core", "ui", "edu"]))
	check(edu["ok"], "core + ui + edu (no data, no viz) imports and loads (%d scripts)\n%s" % [edu["scripts"], str(edu["output"]).left(600) if not edu["ok"] else ""])
	var all: Dictionary = await _try("everything", PackedStringArray(["core", "ui", "viz", "data", "edu"]))
	check(all["ok"], "all modules together import and load (%d scripts)" % all["scripts"])
	var control: Dictionary = await _try("negative", PackedStringArray(["core", "edu"]))
	check(not control["ok"], "negative control: edu without ui is detected as broken (it needs SkUi)")
	var no_core: Dictionary = await _try("nocore", PackedStringArray(["viz"]))
	check(not no_core["ok"], "negative control: a module without core is detected as broken")
	finish(10)
