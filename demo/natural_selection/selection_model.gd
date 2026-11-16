class_name SelectionModel
extends RefCounted
## Natural selection in a population of moths, one generation at a time.
## Each moth is dark (1) or light (0), and the colour is inherited. Birds find a moth more easily the more
## it differs from the tree bark: visibility = |colour - bark|, survival = 1 - predation * visibility.
## Survivors then produce the next generation (each offspring copies a random survivor), and a small
## `mutation` chance flips the colour. All randomness comes from the RandomNumberGenerator you pass in
## (SkSession.rng), so the same seed reproduces the same history.
## Teaching model: haploid, one trait, constant population size, no migration.

var bark: float = 0.5
var predation: float = 0.5
var mutation: float = 0.01
var moths: PackedByteArray = PackedByteArray()
var generation: int = 0
var extinct: bool = false


func reset(count: int, dark_percent: int) -> void:
	moths = PackedByteArray()
	moths.resize(count)
	var dark_count: int = int(round(float(count) * float(dark_percent) / 100.0))
	for i: int in range(count):
		moths[i] = 1 if i < dark_count else 0
	generation = 0
	extinct = false


func dark_count() -> int:
	var n: int = 0
	for m: int in moths:
		n += m
	return n


func dark_fraction() -> float:
	return float(dark_count()) / float(moths.size()) if moths.size() > 0 else 0.0


## Chance a moth of this colour survives one generation of bird predation.
func survival(is_dark: bool) -> float:
	return 1.0 - predation * absf((1.0 if is_dark else 0.0) - bark)


## The dark fraction expected after selection and mutation, for an infinitely large population.
## Used to check the simulation: the average of many simulated generations must match it.
func expected_fraction(p: float) -> float:
	var s_d: float = survival(true)
	var s_l: float = survival(false)
	var after_selection: float = p * s_d / (p * s_d + (1.0 - p) * s_l)
	return after_selection * (1.0 - mutation) + (1.0 - after_selection) * mutation


## Advances one generation. Returns false if no moth survived (the population has died out).
func next_generation(rng: RandomNumberGenerator) -> bool:
	if extinct:
		return false
	var survivors: PackedByteArray = PackedByteArray()
	var s_d: float = survival(true)
	var s_l: float = survival(false)
	for m: int in moths:
		if rng.randf() < (s_d if m == 1 else s_l):
			survivors.append(m)
	if survivors.is_empty():
		extinct = true
		return false
	var count: int = moths.size()
	var offspring: PackedByteArray = PackedByteArray()
	offspring.resize(count)
	for i: int in range(count):
		var colour: int = survivors[rng.randi() % survivors.size()]
		if rng.randf() < mutation:
			colour = 1 - colour
		offspring[i] = colour
	moths = offspring
	generation += 1
	return true
