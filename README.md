# SimKit

A small toolkit for building classroom science simulations in Godot **4.7** (also passes its tests on 4.5).
It removes the parts every simulation re-implements: parameters and limits, start/pause/reset, a reproducible
clock, a theme, accessibility settings, keyboard handling for web iframes, graphs, optional lessons and data
export, and the web export. It does **not** include any scientific model, and it never asks you to inherit from anything.

Status: version 0.3.0. 294 automated checks pass on Godot 4.7.2 (0.2.0 also passed on 4.5; 0.3.0 was not rerun there). The demos' web export was checked in
real Chromium for 0.1.0; for 0.2.0 and 0.3.0, two simulations built on the kit passed a 45-check run in Chrome. See "Verified / not verified" below, and "Changes" at the end.

## Quick start

```bash
# 1. Copy the folders you need (core is always needed)
cp -r simkit/addons/simkit  my_project/addons/
# 2. Project Settings: Display > Window > Stretch: Mode canvas_items, Aspect expand
# 3. Register class names once
godot --headless --path my_project --import
```

```gdscript
extends VBoxContainer     # a complete simulation: 2 parameters, graph, Start/Pause/Step/Reset/Speed

var params := SkParams.new()
var session := SkSession.new()
var graph := SkLineGraph.new()
var temp := 90.0

func _ready() -> void:
	params.add(SkParam.float_param("k", "Cooling rate", 0.1, 0.02, 0.5, 0.02))
	params.add(SkParam.float_param("room", "Room temperature", 20.0, 0.0, 40.0, 1.0))
	session.on_step = func(dt: float) -> void:
		var room := params.get_float("room")
		temp = room + (temp - room) * exp(-params.get_float("k") * dt)
		graph.append_point("cup", "Coffee", session.sim_time + dt, temp)
	session.on_reset = func() -> void:
		temp = 90.0
		graph.clear()
	add_child(session); add_child(graph)
	var bar := SkTransportBar.new(); bar.bind(session); add_child(bar)
	var panel := SkParamPanel.new(); panel.bind(params); add_child(panel)
	session.reset()
```

Run the demos: open this folder in Godot 4.7 and press F5 (launcher with three simulations), or
`godot --path . -- --demo=natural_selection`. In a browser: `?demo=predator_prey&capacity=200`.

## What is in it

| Folder | Components | Depends on |
|---|---|---|
| `core/` | `SkParam`/`SkParams` (parameters, validation, page-address settings), `SkSession` (lifecycle, reproducible seed, 3 time models), `SkClock`, `SkHost` (all browser access), `SkFocusRing` (Tab ring, leave game), `SkViewScaler`, `SkTheme` (dark/light/high contrast), `SkA11y` | nothing |
| `ui/` | `SkParamPanel`, `SkTransportBar`, `SkSplitView`, `SkUi` | core |
| `viz/` | `SkLineGraph`, `SkGauge` | core |
| `data/` | `SkLog`, `SkExport` (JSON/CSV, local only) | core |
| `edu/` | `SkLesson`, `SkLessonPanel` (prediction, observation, explanation, vocabulary) | core + ui |
| `deploy/` | HTML shell with live regions, `export_web.sh`, iframe harness, Playwright smoke test | |

Demos (`demo/`): *Rabbits and foxes* (continuous, fixed-step, every module), *Moths and birds* (discrete,
random, turn-driven, no lesson or gauge) and *Cooling coffee* (38 lines of code).

## Tests

```bash
GODOT=godot bash tests/run_all.sh                       # 7 suites, 294 checks
bash addons/simkit/deploy/export_web.sh . exports/web   # export + contract checks (needs 4.7 export templates)
```

## Verified / not verified

Verified: all headless suites on 4.7.stable and 4.5.stable; each module combination in a clean project; the
models against closed-form solutions; a web export (4.7, no threads, 39 MB) in Chromium through an iframe harness
(boot, no console errors, no auto-play, keyboard exit, class settings, pause freezes the frame, 4 frame sizes).

Not verified: a real device (touch, Chromebook, phone), a physical keyboard, any screen reader, grayscale or
colour-blind viewing, the real sims site, a lean web template, a 4.5 web export, Godot 4.6.

## Documents

`repository-analysis.md` · `framework-architecture.md` · `integration-guide.md` · `migration-assessment.md`

Licence: not set (yours to choose). Third-party code: none. Engine: Godot (MIT).

## Changes

**0.3.0** (2026-11-17): fixes for the six moderate findings of the independent audit.
- **No more leaks**: `SkLog`, `SkA11y` and the transport bar connect methods, not lambdas, so a reloaded scene
  frees its log, parameters and settings. `SkA11y.bind` holds its targets weakly. New `SkLog.detach()`.
- **The event log never loses data silently**: a slider drag is one event with a `changes` count; past the cap the
  run's lifecycle and the student's answers are still kept, and `dropped_events` / `dropped_rows` are in the export.
- **A prediction is final once the explanation is shown** (`SkLessonPanel.lock_prediction_on_explanation`, on by
  default).
- **Graph lines are visible in the light palette**: darker colour-blind-safe line colours there, carried in the
  theme so graphs pick them up; every colour is at least 3:1 on the graph background in all three palettes.
- **Long text wraps**: `SkUi.button(..., wrap)`; lesson answers are one per line and wrap; the lesson title is a
  wrapping label above a short "Lesson (hide)" toggle. `SkSplitView` warns in debug builds when a pane is wider
  than its room.
- **`export_web.sh` can be trusted**: relative output paths work, a failed export stops before any OK line, and the
  `.pck` scan uses Python instead of `strings` (which was missing in Git Bash and made the scan pass silently).

**0.2.0** (2026-11-17): fixes for the four blocking findings of the independent audit.
- **Space on a focused transport button acts once.** The Space hotkey now stands aside when a button has keyboard
  focus; before, Start on a focused button started and immediately paused the run.
- **Generations that step and run**: the guide now recommends `FIXED_STEP` with `clock.step = 1.0`. The transport
  bar hides Start for a `MANUAL` session, which could never run on its own.
- **Reproducible starting pictures**: `SkSession.reset_when_ready_changes()` replaces the guide's old advice to
  call `on_reset()` on a READY settings change, which skipped the reseed.
- **Logs keep every run**: `SkLog.table()` called again with the same columns keeps the rows (different columns are
  refused), `clear_table()` empties one, `SkSession.run_number` numbers the runs, and rows of a starting picture
  that never ran are dropped. Both demos now write a `run` column.
