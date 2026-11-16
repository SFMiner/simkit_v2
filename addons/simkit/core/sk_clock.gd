class_name SkClock
extends RefCounted
## Fixed-step accumulator: turns variable frame times into a whole number of equal simulation steps.
## Equal steps make a run reproducible whatever the frame rate. Used by SkSession's FIXED_STEP mode,
## and usable on its own.
##
##   var n := clock.advance(delta)      # how many steps are due this frame
##   for i in n: model.step(clock.step)

# === PUBLIC VARIABLES ===
## Length of one step, in simulation time units.
var step: float = 0.02
## Safety cap: a long frame (a stalled tab) never causes a burst of more than this many steps.
var max_steps_per_frame: int = 12
## True if the last advance() had to drop time because of the cap.
var dropped: bool = false

# === PRIVATE VARIABLES ===
var _acc: float = 0.0

const _EPSILON: float = 1e-9


# === PUBLIC METHODS ===
## Adds `delta` (already multiplied by any speed factor) and returns the number of whole steps now due.
func advance(delta: float) -> int:
	dropped = false
	if not is_finite(delta) or delta <= 0.0 or step <= 0.0:
		return 0
	_acc += delta
	var due: int = int(floor((_acc + _EPSILON) / step))
	_acc = maxf(0.0, _acc - float(due) * step)
	if due > max_steps_per_frame:
		due = max_steps_per_frame
		_acc = 0.0
		dropped = true
	return due


## Fraction (0..1) of the next step already accumulated. Views may use it to interpolate drawing;
## it must never change simulation state.
func alpha() -> float:
	return clampf(_acc / step, 0.0, 1.0) if step > 0.0 else 0.0


func reset() -> void:
	_acc = 0.0
	dropped = false
