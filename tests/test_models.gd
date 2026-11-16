extends SkTest
## The two demo models, checked against known results (not just "it runs").
const PP = preload("res://demo/predator_prey/predator_prey_model.gd")
const SEL = preload("res://demo/natural_selection/selection_model.gd")


func _run_pp(m: PredatorPreyModel, months: float, dt: float) -> void:
	for i: int in range(int(round(months / dt))):
		m.step(dt)


func run() -> void:
	test_name = "test_models"
	# --- predator-prey
	var m: PredatorPreyModel = PredatorPreyModel.new()
	var eq: Vector2 = m.equilibrium()
	check(approx(eq.x, 40.0) and approx(eq.y, 24.0), "equilibrium: rabbits = death/(conv*hunt) = 40, foxes = (g/a)(1 - R*/K) = 24")
	m.reset(0)
	_run_pp(m, 150.0, 0.02)
	check(absf(m.rabbits - 40.0) < 0.05 and absf(m.foxes - 24.0) < 0.05, "starting at equilibrium stays there for 150 months (%.3f, %.3f)" % [m.rabbits, m.foxes])
	# no foxes: logistic growth to the carrying capacity
	var lone: PredatorPreyModel = PredatorPreyModel.new()
	lone.rabbits = 10.0
	lone.foxes = 0.0
	_run_pp(lone, 40.0, 0.02)
	check(absf(lone.rabbits - lone.capacity) / lone.capacity < 0.01, "no foxes: rabbits grow to the food supply (%.2f)" % lone.rabbits)
	var logistic: float = 100.0 / (1.0 + (100.0 / 10.0 - 1.0) * exp(-0.8 * 5.0))
	var l5: PredatorPreyModel = PredatorPreyModel.new()
	l5.rabbits = 10.0
	l5.foxes = 0.0
	_run_pp(l5, 5.0, 0.02)
	check(absf(l5.rabbits - logistic) < 1e-4, "no foxes: matches the exact logistic solution at t=5 (%.5f vs %.5f)" % [l5.rabbits, logistic])
	# no rabbits: exponential decay of foxes
	var starve: PredatorPreyModel = PredatorPreyModel.new()
	starve.rabbits = 0.0
	starve.foxes = 50.0
	_run_pp(starve, 3.0, 0.02)
	check(absf(starve.foxes - 50.0 * exp(-0.4 * 3.0)) < 1e-5, "no rabbits: foxes decay as e^(-death t)")
	# step-size convergence (RK4)
	var a: PredatorPreyModel = PredatorPreyModel.new()
	var b: PredatorPreyModel = PredatorPreyModel.new()
	a.reset(2)
	b.reset(2)
	_run_pp(a, 60.0, 0.02)
	_run_pp(b, 60.0, 0.01)
	check(absf(a.rabbits - b.rabbits) < 0.01 and absf(a.foxes - b.foxes) < 0.01, "halving the step changes the answer by < 0.01 animals")
	# determinism and bounds
	var c: PredatorPreyModel = PredatorPreyModel.new()
	c.reset(2)
	var d: PredatorPreyModel = PredatorPreyModel.new()
	d.reset(2)
	var bad: int = 0
	for i: int in range(6000):
		c.step(0.02)
		d.step(0.02)
		if c.rabbits < 0.0 or c.foxes < 0.0 or c.rabbits > 1.01 * c.capacity * 3.0 or is_nan(c.rabbits):
			bad += 1
	check(c.rabbits == d.rabbits and c.foxes == d.foxes, "same parameters give the identical run")
	check(bad == 0, "populations never negative, NaN or beyond sensible bounds in 120 months")
	# the "many foxes" start swings, then settles (damped, since the food supply is limited)
	var swing: PredatorPreyModel = PredatorPreyModel.new()
	swing.reset(2)
	var min_r: float = INF
	for i: int in range(3000):
		swing.step(0.02)
		min_r = minf(min_r, swing.rabbits)
	check(min_r < 30.0, "many foxes at the start drives the rabbits well below equilibrium (min %.1f)" % min_r)
	_run_pp(swing, 600.0, 0.02)
	check(absf(swing.rabbits - 40.0) < 1.0 and absf(swing.foxes - 24.0) < 1.0, "...and the system settles back to equilibrium by month 660")
	# extinction rule
	var ext: PredatorPreyModel = PredatorPreyModel.new()
	ext.rabbits = 0.0
	ext.foxes = 1.2
	_run_pp(ext, 5.0, 0.02)
	check(ext.foxes == 0.0, "foxes with no food die out completely (no 0.0001-fox recovery)")
	# foxes cannot live when the food supply is too small
	var poor: PredatorPreyModel = PredatorPreyModel.new()
	poor.hunting = 0.005
	check(poor.equilibrium() == Vector2.ZERO, "foxes too poor at hunting (death/(conv*hunt) = 160 > food supply 100): no coexistence point")
	poor.reset(0)
	_run_pp(poor, 300.0, 0.02)
	check(poor.foxes == 0.0 and absf(poor.rabbits - 100.0) < 1.0, "...so the foxes die out and the rabbits fill the food supply")

	# --- natural selection
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var s: SelectionModel = SelectionModel.new()
	s.reset(100, 10)
	check(s.dark_count() == 10 and absf(s.dark_fraction() - 0.1) < 1e-9, "reset: 10% of 100 moths are dark")
	s.bark = 0.9
	s.predation = 0.6
	check(approx(s.survival(true), 1.0 - 0.6 * 0.1) and approx(s.survival(false), 1.0 - 0.6 * 0.9), "survival = 1 - predation * |colour - bark|")
	# expected value check, large population, many repeats
	var big: SelectionModel = SelectionModel.new()
	big.bark = 0.9
	big.predation = 0.6
	big.mutation = 0.02
	var total: float = 0.0
	var reps: int = 200
	for r: int in range(reps):
		big.reset(2000, 20)
		big.next_generation(rng)
		total += big.dark_fraction()
	var expected: float = big.expected_fraction(0.2)
	check(absf(total / reps - expected) < 0.006, "mean dark fraction after one generation matches the analytic value (%.4f vs %.4f)" % [total / reps, expected])
	# direction of selection
	big.reset(1000, 10)
	for g: int in range(30):
		big.next_generation(rng)
	check(big.dark_fraction() > 0.8, "dark bark favours dark moths: 10%% -> %.0f%% in 30 generations" % (big.dark_fraction() * 100.0))
	big.bark = 0.1
	for g: int in range(60):
		big.next_generation(rng)
	check(big.dark_fraction() < 0.3, "after the bark turns light, light moths take over again (%.0f%% dark)" % (big.dark_fraction() * 100.0))
	# no selection pressure: no systematic change
	var neutral: SelectionModel = SelectionModel.new()
	neutral.bark = 0.5
	neutral.predation = 0.0
	neutral.mutation = 0.0
	var t2: float = 0.0
	for r: int in range(100):
		neutral.reset(1000, 40)
		for g: int in range(5):
			neutral.next_generation(rng)
		t2 += neutral.dark_fraction()
	check(absf(t2 / 100.0 - 0.4) < 0.02, "no predation, no mutation: the average stays at 40%% (%.3f)" % (t2 / 100.0))
	# fixation without mutation: all-light stays all-light
	neutral.mutation = 0.0
	neutral.reset(50, 0)
	for g: int in range(10):
		neutral.next_generation(rng)
	check(neutral.dark_count() == 0, "without mutation a trait that is absent cannot appear")
	# reproducibility
	var r1: RandomNumberGenerator = RandomNumberGenerator.new()
	var r2: RandomNumberGenerator = RandomNumberGenerator.new()
	r1.seed = 42
	r2.seed = 42
	var m1: SelectionModel = SelectionModel.new()
	var m2: SelectionModel = SelectionModel.new()
	m1.reset(100, 30)
	m2.reset(100, 30)
	for g: int in range(25):
		m1.next_generation(r1)
		m2.next_generation(r2)
	check(m1.moths == m2.moths, "same seed -> identical population after 25 generations")
	r2.seed = 43
	m2.reset(100, 30)
	m1.reset(100, 30)
	r1.seed = 42
	for g: int in range(25):
		m1.next_generation(r1)
		m2.next_generation(r2)
	check(m1.moths != m2.moths, "different seed -> different history")
	# extinction: everything visible, nobody survives
	var doomed: SelectionModel = SelectionModel.new()
	doomed.bark = 0.0
	doomed.predation = 0.9
	doomed.reset(20, 100)
	var died: bool = false
	for g: int in range(200):
		if not doomed.next_generation(rng):
			died = true
			break
	check(died and doomed.extinct and not doomed.next_generation(rng), "a population can die out; the model then refuses further generations")
	check(doomed.moths.size() == 20, "population size is constant (no growth beyond the starting size)")
	finish(24)
