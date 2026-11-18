extends SkTest
## SkParam / SkParams: validation, clamping, reset, locking, change signals, page-address settings.


func run() -> void:
	test_name = "test_params"
	var p: SkParams = SkParams.new()
	p.add(SkParam.float_param("rate", "Rate", 0.5, 0.0, 2.0, 0.25).as_class_setting().with_help("Growth."))
	p.add(SkParam.int_param("n", "Count", 10, 0, 50, 5).locked_while_running())
	p.add(SkParam.bool_param("fast", "Fast", false).as_class_setting())
	p.add(SkParam.choice_param("mode", "Mode", PackedStringArray(["Slow", "Normal", "Fast"]), 1).as_class_setting())

	check(p.validate().is_empty(), "valid specs report no problems")
	check(p.ids() == (["rate", "n", "fast", "mode"] as Array[String]), "ids keep insertion order")
	check(p.add(SkParam.bool_param("fast", "Dup", true)) == null, "duplicate id refused")
	check(approx(p.get_float("rate"), 0.5) and p.get_int("n") == 10 and not p.get_bool("fast") and p.get_int("mode") == 1, "defaults")

	# Clamping and snapping
	check(p.set_value("rate", 9.0) and approx(p.get_float("rate"), 2.0), "float clamps to max")
	check(p.set_value("rate", 0.6) and approx(p.get_float("rate"), 0.5), "float snaps to step (0.6 -> 0.5)")
	check(p.set_value("n", 23) and p.get_int("n") == 25, "int snaps to step from min (23 -> 25 with min 1? 1+5k)")
	# Refusals
	check(not p.set_value("rate", "abc"), "string refused for float")
	check(not p.set_value("rate", NAN) and not p.set_value("rate", INF), "NaN and infinity refused")
	check(not p.set_value("fast", 1), "int refused for bool")
	check(not p.set_value("mode", 7) and not p.set_value("mode", "Nope"), "bad choice refused")
	check(p.set_value("mode", "Fast") and p.get_int("mode") == 2, "choice accepted by name")
	check(not p.set_value("ghost", 1), "unknown id refused")
	check(approx(p.get_float("rate"), 0.5), "refused values changed nothing")

	# Signals fire only on real change
	var log: Array = []
	p.changed.connect(func(id: String, v: Variant) -> void: log.append([id, v]))
	p.set_value("rate", 0.5)
	check(log.is_empty(), "no signal when value is unchanged")
	p.set_value("rate", 1.0)
	check(log.size() == 1 and log[0][0] == "rate", "signal on change")

	# Reset
	p.reset_all()
	check(approx(p.get_float("rate"), 0.5) and p.get_int("n") == 10 and p.get_int("mode") == 1, "reset_all restores defaults")
	check(p.is_default("rate"), "is_default after reset")

	# Locking
	p.locked = true
	check(not p.set_value("n", 20), "locked param refuses change")
	check(p.set_value("rate", 1.5), "unlocked-flag param still changes while locked")
	p.reset_all()
	check(p.get_int("n") == 10, "reset_all ignores the lock")
	p.locked = false

	# Dictionary round trip
	p.set_value("rate", 1.25)
	p.set_value("mode", 0)
	var saved: Dictionary = p.to_dict()
	p.reset_all()
	check(p.from_dict(saved).is_empty() and approx(p.get_float("rate"), 1.25) and p.get_int("mode") == 0, "to_dict/from_dict round trip")
	check(p.from_dict({"ghost": 1, "rate": "bad"}).size() == 2, "from_dict reports unknown and unusable entries")
	check(p.to_labeled_dict()["mode"] == "Slow", "labeled dict shows the option name")

	# Page address
	p.reset_all()
	var applied: Dictionary = p.apply_query("?rate=1.5&fast=on&mode=FAST&n=40&evil=1")
	check(approx(p.get_float("rate"), 1.5) and p.get_bool("fast") and p.get_int("mode") == 2, "query applies class settings (case-insensitive choice)")
	check(not applied.has("n"), "query ignores params not marked class_setting")
	p.reset_all()
	p.apply_query("?rate=99&fast=maybe&mode=7&rate")
	check(approx(p.get_float("rate"), 0.5) and not p.get_bool("fast") and p.get_int("mode") == 1, "query ignores out-of-range, bad and unknown values")
	p.apply_query("?rate=" + "9".repeat(600))
	check(approx(p.get_float("rate"), 0.5), "over-long query ignored")
	p.apply_query("?mode=%46ast")
	check(p.get_int("mode") == 2, "query values are URL-decoded")

	# Spec validation
	var bad: SkParams = SkParams.new()
	var kept: SkParam = bad.add(SkParam.float_param("x", "X", 5.0, 0.0, 1.0))
	var refused: SkParam = bad.add(SkParam.float_param("y", "Y", 0.5, 2.0, 1.0))
	check(kept != null and refused == null and not bad.has("y") and bad.validate().size() == 1, "add() refuses min >= max (a value could never be stored right) and keeps, with a warning, a default outside the range")
	var off_grid: SkParams = SkParams.new()
	off_grid.add(SkParam.int_param("g", "G", 3, 0, 20, 5))
	check(off_grid.validate().size() == 1, "validate catches a default that is off the step grid")

	# Formatting and docs
	check(p.spec("rate").format(1.25) == "1.25" and p.spec("mode").format(2) == "Fast" and p.spec("fast").format(true) == "On", "format")
	var md: String = p.class_settings_markdown()
	check(md.contains("`rate`") and md.contains("`mode`") and not md.contains("`n`"), "class settings table lists only class settings")
	finish(33)
