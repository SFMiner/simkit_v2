extends SceneTree
## Developer tool (needs a real renderer; NOT headless): plays a demo for a while and saves a PNG.
##   xvfb-run -a godot --path . --resolution 1180x500 --script tests/shot.gd -- demo=predator_prey out=/tmp/a.png steps=400
## Save screenshots OUTSIDE the project folder: Godot would import stray images.

func _initialize() -> void:
	call_deferred("_go")


func _arg(name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _go() -> void:
	SkHost.query_override = "?demo=" + _arg("demo", "predator_prey") + _arg("extra", "")
	var scene: Node = load("res://demo/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var d: Node = scene.current
	if d != null:
		var session: SkSession = d.session
		if _arg("run", "1") == "1":
			if session.mode == SkSession.Mode.MANUAL:
				session.step_once()
				for i: int in range(int(_arg("steps", "30"))):
					session.step_once()
			else:
				session.start()
				session.auto_process = false
				for i: int in range(int(_arg("steps", "400"))):
					session.advance(0.05)
					if i % 20 == 0:
						await process_frame
	for i: int in range(6):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(_arg("out", "/tmp/shot.png"))
	print("saved ", _arg("out", "/tmp/shot.png"), " ", img.get_size())
	quit()
