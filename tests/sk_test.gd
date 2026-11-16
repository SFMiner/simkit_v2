class_name SkTest
extends SceneTree
## Base for SimKit's headless tests. A test script extends this, overrides run(), calls check() and ends
## with finish(<exact number of checks>): a test that stops early cannot pass, because the count is compared.
## Run:  godot --headless --path . --script tests/test_xxx.gd

var passed: int = 0
var failures: int = 0
var test_name: String = "test"


func _initialize() -> void:
	# Deferred so autoload-free class_names and the scene tree are ready.
	call_deferred("_run_wrapper")


func _run_wrapper() -> void:
	await run()


## Override in the test.
func run() -> void:
	finish(0)


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		print("  FAIL: " + label)


func approx(a: float, b: float, tolerance: float = 1e-6) -> bool:
	return absf(a - b) <= tolerance


func finish(expected_total: int) -> void:
	var total: int = passed + failures
	var ok: bool = failures == 0 and total == expected_total
	print("%s: %d/%d passed (expected %d checks) -> %s" % [test_name, passed, total, expected_total,
			"PASS" if ok else "FAIL"])
	quit(0 if ok else 1)


## Waits `n` rendered/processed frames.
func frames(n: int) -> void:
	for i: int in range(n):
		await process_frame
