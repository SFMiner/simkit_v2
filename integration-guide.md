# Integration guide

Target: a new Godot **4.7** project. Everything below was exercised by the
demos; the minimal example in step 5 is `demo/minimal/cooling_demo.gd`.

## 1. Add the toolkit

1. Copy `addons/simkit/` into your project's `addons/` folder. Copy only the folders you need:
   `core` always; add `ui`, `viz`, `data`, `edu` as wanted (`edu` also needs `ui`; `viz` and `data` need nothing but core).
   There is no plugin to enable.
2. Project Settings → Display → Window → Stretch: **Mode `canvas_items`, Aspect `expand`**
   (required by `SkViewScaler`). Renderer: GL Compatibility.
3. Open the project once in the editor, or run `godot --headless --path . --import`, so Godot registers the `Sk*`
   class names. **Run the import a second time if you add files while the editor is closed.**

## 2. The five-minute simulation

```gdscript
extends VBoxContainer

var params := SkParams.new()
var session := SkSession.new()
var graph := SkLineGraph.new()
var temp := 90.0

func _ready() -> void:
	params.add(SkParam.float_param("k", "Cooling rate", 0.1, 0.02, 0.5, 0.02))
	session.duration = 60.0
	session.on_step = func(dt: float) -> void:                 # your model, any shape you like
		temp = 20.0 + (temp - 20.0) * exp(-params.get_float("k") * dt)
		graph.append_point("cup", "Coffee", session.sim_time + dt, temp)
	session.on_reset = func() -> void:
		temp = 90.0
		graph.clear()
	add_child(session)
	add_child(graph)
	var bar := SkTransportBar.new(); bar.bind(session); add_child(bar)
	var panel := SkParamPanel.new(); panel.bind(params); add_child(panel)
	session.reset()                                              # READY; nothing runs until Start
```

Notes: the session never starts itself; `Reset` calls `on_reset` and returns to the same seed.

## 3. Top-level wiring (once per game)

Use `SkShell` (0.5.0): make your main scene's script extend it.

```gdscript
extends SkShell
var sim := MySim.new()

func _ready() -> void:
	title = "How does dye spread through water?"
	base_size = Vector2(1180, 560)                  # the size you design for
	super._ready()                                  # loads saved settings, builds background, top bar, scaler, Tab ring
	sim.setup(a11y)                                 # your simulation can read the settings
	set_content(sim)
	print("mygame: boot ok")                        # handy for browser checks
```

Tab walks every focusable control in the content in tree order; set `focus_provider` to a Callable returning
your own list to change that. `ring.close_topmost` still closes your overlays on Escape. Add your own controls
(a help button) to `top_bar`. Several simulations in one window: give each transport bar's `hotkey_scope` its
simulation's root, or put each simulation in its own `SkSplitView` (the default scope).

Without `SkShell`, this is the wiring it does (from `demo/demo_menu.gd`):

```gdscript
var a11y := SkA11y.new()
var scaler := SkViewScaler.new()
var ring := SkFocusRing.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	a11y.load_saved(); a11y.read_browser()          # saved choices win, else the browser's preferences
	scaler.base_size = Vector2(1280, 720)           # the size you design for
	add_child(scaler)
	a11y.bind(self, scaler)                         # theme + text size follow the settings
	ring.provider = func() -> Array: return my_controls()     # Tab order
	ring.close_topmost = func() -> bool: return close_open_panel_if_any()   # optional
	add_child(ring)
	print("mygame: boot ok")                        # handy for browser checks
```

* Show the settings with one line: `var p := SkParamPanel.new(); p.bind(a11y.params)`.
* Keep the host's Full screen button uncovered: leave `SkHost.RESERVED_CSS / scaler.css_scale` empty in the top right.
* Draw animations with `a11y.anim_time(0.4)` (0 when reduced motion is on). The model must never read `a11y`.

## 4. Pick the time model

| Your simulation | `session.mode` | Notes |
|---|---|---|
| Differential equations, feedback, physics-like | `FIXED_STEP` (default) | `session.clock.step`, `session.speed`, `duration`; use `session.rng` for any randomness |
| Per-frame motion where exact step size does not matter | `CONTINUOUS` | dt is the real frame time, capped by `max_delta` |
| Generations or turns that can also run on their own | `FIXED_STEP`, `clock.step = 1.0` | One step = one generation. `step_text = "Next generation"` for single steps (other labels: `bar.texts.start = "Run"`; keys `start`, `pause`, `resume`, `again`, `reset`); Start runs `speed` generations per second (`speeds = [1.0, 2.0, 4.0, 8.0]`). Check `MAX_GENERATIONS` with `duration`. |
| Steps only when the student acts (never runs by itself) | `MANUAL` | `session.step_once()` with `manual_dt`. The transport bar hides Start for a MANUAL session, since it could never run. |
| Your own loop | any, with `auto_process = false` | call `session.advance(delta)` yourself |

## 5. Parameters

```gdscript
params.add(SkParam.int_param("moths", "Number of moths", 100, 20, 200, 20).locked_while_running())
params.add(SkParam.choice_param("start", "Start", PackedStringArray(["Balanced", "Few foxes"]), 1).as_class_setting())
session.params = params
session.lock_params_after_start = true       # locked_while_running params refuse changes once started
```

* Read with `get_float/int/bool/get_value`; react with `params.changed(id, value)`.
* **Defaults must lie on the step grid** (`min + k*step`); `params.validate()` reports mistakes. Run it in a test.
* If a parameter determines the *starting picture*, call `session.reset_when_ready_changes()` once (after
  `session.params = params`). A change while READY then calls `session.reset()`, which reseeds the rng before
  `on_reset`, so the picture shown is exactly the one Reset replays. **Do not call `on_reset()` yourself**: it
  skips the reseed, and the shown start then differs from the one Reset produces (fixed in 0.2.0).
  Your own `params.changed` handler only needs the running case: `if session.state != SkSession.State.READY: apply()`.
* Page-address settings: mark params `.as_class_setting()` and call `params.apply_query(SkHost.query_string())`.
  Out-of-range or unknown values are ignored. `params.class_settings_markdown()` prints the README table.
* `lock` + `SkParamPanel`: a locked choice row keeps the chosen button enabled-looking and disables the others.

## 6. Optional modules

* **Graph / gauge**: `graph.append_point(id, label, x, y)`; `graph.set_series(id, label, points, true)` for a dashed kept run;
  `graph.bands = [{"lo":..,"hi":..,"label":..}]`; call `describe()` for a text summary to announce.
* **Layout**: wrap a main pane and a side pane with `SkSplitView.set_panes(main, side)`. It never scrolls sideways,
  so make long text wrap: `SkUi.label(text, 0, true)`, and `SkUi.button(text, toggle, true)` in a `VBoxContainer`
  (never in an `HFlowContainer`, where a wrapping button collapses). Rows of fixed-width controls, such as two graphs
  side by side, need to stack when narrow. In debug builds `SkSplitView` warns once when a pane is wider than its
  room, and `too_wide_panes()` lists them for a test.
* **Log and export**: `var log := SkLog.new(); log.attach(session)` records state changes and parameter changes
  automatically; `log.table("name", columns)` then `log.add_row(...)` for measurements. Tables keep every run:
  calling `table()` again with the same columns (from `on_reset`, say) keeps the rows, and different columns are
  refused with a warning. Put `session.run_number` in a `run` column to tell runs apart. Rows written for a
  starting picture that was replaced before it ran are dropped automatically; `clear_table()` empties a table;
  `SkExport.save_json(log)` / `save_table_csv(log, "name")` from a *button the student presses*.
  Consecutive changes of one parameter (a slider drag) are one `param` event with a `changes` count. Past
  `MAX_EVENTS` the log keeps only the run's lifecycle and the student's answers, after one `log_full` event; the
  JSON export reports `dropped_events` and `dropped_rows`. `log.detach()` stops recording.
  `save_table_csv` returns `"ERROR"` for a table that does not exist (nothing is written); NaN and infinite
  numbers export as empty CSV cells and JSON `null`, counted in the JSON's `non_finite`.
* **Lesson**: `SkLessonPanel.new().show_lesson(SkLesson.from_dict({...}))` or `SkLesson.from_json(text)`;
  set `panel.log = log` to record answers. Leave fields out to omit sections. Answers are multiple choice only,
  shown one per line so long answers wrap. Once the explanation is shown the prediction is final
  (`lock_prediction_on_explanation`, default true; set it false to let students revise).
* **Graph colours** follow the palette: the light palette uses darker line colours (all at least 3:1 on the graph
  background). In your own drawing, use `SkTheme.series_color(i, a11y.palette_name())`.
* **Announce** anything meaningful: `SkHost.announce("Month 12: foxes died out", true)` (assertive for failures).

## 7. Tests

Copy `tests/sk_test.gd` and write suites that `extends SkTest`; end with `finish(<exact number of checks>)`
so an aborted test fails. Run `godot --headless --path . --script tests/test_x.gd`. `tests/run_all.sh` shows
the runner (fails on non-zero exit, `SCRIPT ERROR`, `Parse Error`, or a missing `PASS`). Keep the model free of nodes
and test it directly (`tests/test_models.gd` compares against closed-form solutions).

## 8. Export for the sims site

1. Install the export templates for your exact engine version (Editor → Manage Export Templates).
2. Copy `export_presets.cfg` from this repo (preset `Web`: single-threaded, custom shell
   `res://addons/simkit/deploy/shell.html`, tests/docs/markdown/deploy files excluded). Change `export_path`.
3. `GODOT=godot bash addons/simkit/deploy/export_web.sh . exports/web` (in Git Bash on Windows; needs Python 3). It
   exports, then checks: `index.html` at the root, `.pck` and `.wasm` present (it stops there if they are not),
   threads off, no tests/docs/home paths in the `.pck`, live regions present. It exits non-zero on any FAIL.
4. Browser check: serve a folder containing `harness.html` and your export as `game/`, then
   `PORT=… node addons/simkit/deploy/web_smoke.js <shots-dir>` (needs Node and Playwright). Edit the
   `boot ok` log line and the menu clicks to match your game; **read the screenshots**.
5. Fill the "registry facts" from `params.class_settings_markdown()` plus title, description, minutes, template,
   credits. Do not publish on the site yourself unless that is your process.

Do **not** put screenshots, notes or private files in the project folder: Godot imports stray images and an
excluded file's name can still appear in the `.pck`.

## 9. Gotchas found while building SimKit

* `breakpoint` is a reserved GDScript word (a variable named that fails to parse with an unhelpful error).
* `Vector2` stores 32-bit floats; do not use it to hold model values you later compare exactly.
* GDScript has no `%g` format.
* `String.num(2.0)` is `"2.0"`; format integers yourself.
* A disabled `Button` loses its pressed look; keep the selected option of a locked group enabled.
* `a == [..] as Array[String]` parses as `(a == [..]) as Array[String]`: put the cast in parentheses.
* `JSON.parse_string` prints an engine error on bad input; use `JSON.new().parse()` for untrusted text.
* Disconnect or guard lambdas connected to signals of objects that may be freed (`is_instance_valid`).
* A test that clicks with `root.push_input` must give the position in window pixels:
  `root.get_final_transform() * (control.get_global_transform_with_canvas() * point)`.
* Saved settings in `user://` belong to one game (Godot keeps them per `config/name`, on the web too).
* Never connect a lambda that captures a RefCounted object to a signal of something that object holds: the two
  keep each other alive forever. Connect a method instead (SimKit 0.1.0 leaked a whole data log this way).
