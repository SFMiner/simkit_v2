class_name PredatorPreyModel
extends RefCounted
## Rabbits (prey) and foxes (predators), as ordinary differential equations integrated with RK4.
##   d(rabbits)/dt = growth * R * (1 - R / capacity) - hunting * R * F
##   d(foxes)/dt   = conversion * hunting * R * F - death * F
## Time is in "months". Numbers are animals. It is a teaching model, not a measured ecosystem.
## "Atto-fox" fix: a continuous model can leave 0.0001 foxes that later "recover". Below ONE animal a
## species is treated as extinct (set to 0), which is what a real population of animals would do.
## No nodes, no drawing, no randomness: the same parameters always give the same run.

const EXTINCT_BELOW: float = 1.0

var growth: float = 0.8
var capacity: float = 100.0
var hunting: float = 0.02
var conversion: float = 0.5
var death: float = 0.4
var rabbits: float = 0.0
var foxes: float = 0.0


## Where both species can live together unchanged: Vector2(rabbits, foxes). (0, 0) if no such point exists
## (the foxes could not live on the rabbits the land can feed).
func equilibrium() -> Vector2:
	var r_star: float = death / (conversion * hunting)
	if r_star >= capacity:
		return Vector2.ZERO
	return Vector2(r_star, (growth / hunting) * (1.0 - r_star / capacity))


## `start`: 0 = balanced (at the equilibrium), 1 = few foxes, 2 = many foxes (rabbits at the equilibrium).
func reset(start: int) -> void:
	var eq: Vector2 = equilibrium()
	if eq == Vector2.ZERO:
		rabbits = capacity * 0.5
		foxes = 10.0
		return
	rabbits = eq.x
	match start:
		1:
			foxes = maxf(eq.y * 0.2, 2.0)
		2:
			foxes = eq.y * 2.5
		_:
			foxes = eq.y


func step(dt: float) -> void:
	var k1: Vector2 = _rate(rabbits, foxes)
	var k2: Vector2 = _rate(rabbits + 0.5 * dt * k1.x, foxes + 0.5 * dt * k1.y)
	var k3: Vector2 = _rate(rabbits + 0.5 * dt * k2.x, foxes + 0.5 * dt * k2.y)
	var k4: Vector2 = _rate(rabbits + dt * k3.x, foxes + dt * k3.y)
	rabbits += dt / 6.0 * (k1.x + 2.0 * k2.x + 2.0 * k3.x + k4.x)
	foxes += dt / 6.0 * (k1.y + 2.0 * k2.y + 2.0 * k3.y + k4.y)
	rabbits = 0.0 if rabbits < EXTINCT_BELOW else rabbits
	foxes = 0.0 if foxes < EXTINCT_BELOW else foxes


func _rate(r: float, f: float) -> Vector2:
	return Vector2(growth * r * (1.0 - r / capacity) - hunting * r * f,
			conversion * hunting * r * f - death * f)
