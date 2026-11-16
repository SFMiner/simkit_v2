# Repository analysis

Five Godot projects were inspected on 2026-11-15, read-only. This document says what was found, how
confident each finding is, and which findings drove the design of SimKit.

## Method and limits

I read, in full, the code that is *infrastructure* (theme builders, keyboard handling, settings, scaling,
controllers, test harnesses, export presets, HTML shell, hosting notes) in every project. I read the
simulation-specific internals (models, particle fields, art code) only far enough to learn how state is
represented and how it reaches the screen. I did not run any of the five projects, and I did not open the
GDD / design documents beyond the hosting section of Cell Designer's. Statements about behaviour that
come from READMEs (for example "216 checks pass", "published on 2026-10-14") are the authors' claims; I did
not re-verify them. Where something is my inference it says so.

| Repo | GDScript lines* | Godot feature tag | Scenes | Tests |
|---|---|---|---|---|
| `cell-designer` | 5,014 (3,700 game, 1,300 tests) | **4.7** | 1 (`Main.tscn`, one node) | 5 headless suites, 216 checks (claimed), balance report, Playwright browser checks |
| `water-balance` (`water_balance/`) | 2,443 | 4.5 | 1 (+ an unexported prototype `preview.tscn`) | 4 headless suites, 93+31+62 checks (claimed) |
| `dogestive-sim` | 2,055 | 4.5 | 1 | none |
| `circulation-sim` | 1,210 | 4.5 | 1 | none |
| `osmosis-simulation` | 610 | 4.5 in `project.godot` (README says 4.7) | 1 | 1 script using `assert` |

\* `wc -l` of `*.gd`, comments and blanks included.

Common to all five: GL Compatibility renderer, `canvas_items` stretch, no addons or third-party code, UI
built in code (all but a handful of controls), `class_name` used freely, no threads in the web export
(`variant/thread_support=false` in every preset), no audio in play (osmosis ships an MP3 that no script
loads, see below).

## 1. Per-repository findings

### 1.1 cell-designer: "Power & Growth" (Godot 4.7.2, grade 7, three levels)

*Mechanics and state.* A fixed-tick resource model (`simulation_model.gd`, 545 lines, a `RefCounted`
with no nodes) holds ATP, glucose, oxygen, amino acids, protein and starch pools plus an organelle list.
Per-level numbers live in `level_configs.gd`. The single player action (click a ready organelle to make it
divide) is a transaction with explicit refusal reasons ("Need 5 ATP"). Randomness is seeded and used only
for cosmetic particles. `game_controller.gd` (705 lines) owns the fixed-tick loop (`TICK = 0.05`, at most
12 steps per frame), converts model events into tutorial call-outs and result cards.

*Reusable infrastructure present.* The most complete set of the five:
`UiTheme` (theme built in code, 4 px focus outline), `GameSettings` (text size ×3, reduced motion with the
browser's `prefers-reduced-motion` as default, saved to `user://settings.cfg`, **whitelisted page-address
parser** for `?level=` and `?particles=`), `Announcer` (screen-reader live-region messages through
`JavaScriptBridge`), `KeyboardExit` (Tab ring rebuilt on every key press, Escape closes the innermost overlay
else leaves, `postMessage({type:'sims:leave-game'})`), `OverlayPanel` (modal cards), `view_scale()` (DPI-aware
UI scale with a 0.85 CSS-px floor), top-right 200×64 CSS-px safe area, a custom HTML shell (`web/shell.html`)
with live regions and a readable load-failure message, and a test base class that **compares the number of
checks run against the expected number** so an aborted test cannot pass quietly.

*Hosting.* The only repository with a written hosting contract: `sims.mr-miner.com`, root `index.html`,
no threads, iframe 1180×500, no auto-play, keyboard exit, class settings in the query string, "registry
facts" (title, description, minutes, settings, credits). `docs/HOSTING_VERIFICATION.md` states for every
claim *how* it was checked (headless Godot, headless Chrome, visible Chrome, by hand: "nothing was checked
by hand").

*Concerns.* (a) Standard 4.7.2 web template, 39.5 MB `.wasm`, because the lean 2D templates in the author's
folder are built for 4.5 and "a template must match the engine exactly". (b) The README lists unchecked
items honestly (screen reader, phone, Chromebook, touch). (c) Organelle art contrast is below 3:1 against
the cytoplasm (stated in the README). (d) The report and a few comments in the code use author-specific
Windows paths (docs only).

### 1.2 water-balance: "The Runner's Water Balance" (Godot 4.5)

*Mechanics and state.* The cleanest model/controller/view split of the five. `WaterBalanceModel` is a
`RefCounted` with a private state `Dictionary`, parameters in a `ModelParameters` **`Resource` with a
`validate()` method**, conservation ledgers, and defensive copies returned to callers. A
`WaterBalanceController` steps the model on a fixed 0.02 grid, records samples, **interpolates a "visual
snapshot" between steps without touching model state**, and stores deep-copied A/B "kept runs" in memory only.
Views (`MainView`, `BodyView`, `RaceGraph`, `SodiumGauge`) only read snapshots.

*Reusable infrastructure present.* `RaceGraph` (line graph with a dashed kept-run line, a shaded
band, direct end-of-line label: not colour alone) and `SodiumGauge` (value on a scale with a labelled
normal band and a words-first verdict) are good, general ideas buried in a project-specific shape.
Toggle buttons instead of `OptionButton` (so the lean 2D web template works), `KeyboardNav`
(Tab ring + `sims:leave-game`), `_apply_scale()` (same idea as cell-designer's `view_scale()`), a headless test
runner shell script that fails on `SCRIPT ERROR`.

*Concerns.* (a) `KeyboardNav` sets `focus_next` / `focus_previous` NodePaths once, and its own
comment warns they "break if a control is moved afterwards"; cell-designer's rebuilt-each-keypress ring has no
such problem. (b) The controller's `advance()` has **no cap on steps per frame** (cell-designer caps at 12),
so a stalled frame at 4× speed runs many steps at once; this is an inference from reading the loop, not
something I observed. (c) `export_presets.cfg` contains an **absolute Windows path** to the custom template
(`C:/Users/…`), so the preset only works on one machine. (d) `views/` and `preview.tscn` are an older prototype
kept in the tree and excluded from export by filter, which is fragile. (e) UI scale uses
`DisplayServer.screen_get_scale()`; cell-designer asks the browser for `devicePixelRatio`. I did not check
whether they agree on the web.

### 1.3 dogestive-sim and circulation-sim (Godot 4.5)

*Same family, partly merged.* Both are "a token travels station to station along a traced path" tours
with Explore mode and a drag-and-drop Quiz mode. `circulation-sim` is a single 685-line `main.gd` plus
`CirculationData`. `dogestive-sim` is the same program refactored: `scripts/engine/` (`SimSystem` data contract,
`SimToken`, `MapView`, `StationCard`, `MapDropArea`, `BoxTarget`, a 1,129-line `main.gd`) is system-agnostic and
`scripts/systems/` holds the digestive data and the carrot. The doge CLAUDE.md says so ("Sister project:
circulation-sim, same UI patterns").

*State.* Plain member variables on the root control (`current_station`, `quiz_mode`, `mistakes`,
`_moving_segment`, `_t`, ...), movement by distance along a polyline per frame (not fixed-step), all text and
geometry in data scripts.

*Measured duplication* (function-by-function comparison of `circulation-sim/scripts/main.gd` and
`dogestive-sim/scripts/engine/main.gd`): `_box`, `_make_button`, `_make_label`, `is_fullscreen`,
`toggle_fullscreen`, `_add_key_action` are **byte-identical**; `_build_theme`, `_make_check_icon` and
`_register_actions` differ only in palette/keys. `station_card.gd` and `map_drop_area.gd` differ by 76 and 24
diff lines respectively.

*Concerns.* No tests at all. No `sims:leave-game` handling, no page-address settings, no announcer, no saved
settings (none found; the hosting contract may not have been applied to these two). Keyboard navigation is
Godot's default focus traversal plus a few hotkeys; in an iframe, **I would expect Tab to be trapped in the
canvas** (inference from how cell-designer had to solve it; not tested). The doge `main.gd` is a 1,129-line
god-script mixing layout, quiz state machines and input.

### 1.4 osmosis-simulation (Godot 4.5 tag, README says 4.7)

*Mechanics and state.* The smallest and most "classic" Godot structure: an `OsmosisSimulation` **node**
stepped in `_physics_process`, parameters in a `CellProfile` **`Resource`** (`@export` fields, saved as
`animal_cell.tres`), results published through a `state_updated` signal to the views. `main.gd` (208
lines) builds the whole UI with **hard-coded pixel positions** for a 1280×800 canvas. A second mode (red
blood cells, `red_blood_cells.gd`) has per-cell state and irreversible rupture.

*Good ideas to preserve.* The `Resource` profile with `@export` numbers (editable in the Godot inspector
and swappable per organism); a single authoritative simulation node publishing one signal; "the slider is an
outside setting compared with the *starting* cell, the status text compares with the *current* cell"
(a design note that prevents a common misconception); the displayed radius exaggeration documented as a
display choice that must not change the science (water-balance's CLAUDE.md says the same).

*Concerns.* (a) Absolute positions: no layout containers for the main layout, so no responsive behaviour, no
scroll. (b) No keyboard focus management, no theme, no safe area, no leave message. (c) `exclude_filter=""`
plus `all_resources` means the unused 3 MB-class MP3 and anything else in the folder ships in the `.pck`
(not measured; read from the preset). (d) The test uses `assert`, which does nothing in an export build
and does not count checks. (e) Version tag and README disagree (4.5 vs 4.7). (f) Frame-rate-dependent
only through `_physics_process`'s fixed 60 Hz default; `delta` is clamped at 0.05.

## 2. Comparative analysis

Legend: ● present and fairly complete, ◐ partial, ○ not found.

| Capability | cell-designer | water-balance | dogestive | circulation | osmosis |
|---|---|---|---|---|---|
| **Model separate from nodes** (testable headless) | ● RefCounted | ● RefCounted | ◐ data contract, logic in UI script | ◐ data script, logic in UI script | ◐ Node, but logic small |
| **Time stepping** | fixed 0.05, cap 12/frame | fixed 0.02, no cap, interpolated view | per-frame distance | per-frame distance | `_physics_process`, clamp 0.05 |
| **Start / pause / reset** | ● start required, pause freezes all | ● ready/running/paused/finished + restart | ● play/step/reset | ● play/step/reset | ◐ pause, reset |
| **No auto-play before input** | ● tested | ◐ | ○ | ○ | ○ |
| **Parameter controls** | none (clicks) | toggle rows (no sliders) | speed slider | speed slider | one slider, buttons |
| **Parameter validation** | ◐ per-level config | ● `validate()` | ○ | ○ | ○ |
| **Parameters as data** | dictionary configs | `Resource` | static scripts | static script | `Resource` |
| **Reproducible runs (seed / identical result)** | ● seed | ● deterministic | n/a | n/a | ◐ |
| **Reusable theme** | ● code theme | ◐ per-control overrides | ● code theme (copy) | ● code theme | ○ |
| **Focus visibility** | ● 4 px | ● 3 px | ● | ● | ○ |
| **Keyboard: Tab ring + exit to host** | ● | ◐ static NodePaths | ○ | ○ | ○ |
| **Text size / reduced motion / contrast** | ● size + motion | ○ (85 % floor only) | ○ | ○ | ○ |
| **Screen-reader announcements** | ● live regions | ○ | ○ | ○ | ○ |
| **Responsive scaling** | ● `view_scale` | ◐ `_apply_scale` | ○ (`keep`) | ○ (`keep`) | ○ |
| **Query-string settings** | ● whitelisted | ○ | ○ | ○ | ○ |
| **Saved settings (`user://`)** | ● | ○ (by decision) | ○ | ○ | ○ |
| **Student responses / assessment** | ○ | ◐ A/B kept runs, prediction string | ◐ quiz counts | ◐ quiz counts | ○ |
| **Data export** | ○ | ○ (by decision) | ○ | ○ | ○ |
| **Graph / gauge** | ○ (bars in HUD) | ● graph + gauge | ○ | ○ | ◐ two bars |
| **Custom HTML shell** | ● | ○ | ○ | ○ | ○ |
| **Export preset portable** | ● | ✗ absolute path | ● | ● | ● (but no excludes) |
| **Automated tests** | ● 216 | ● ~186 | ○ | ○ | ◐ 1 script |
| **Documented hosting checks** | ● | ◐ | ○ | ○ | ○ |

Reading the table: **accessibility, keyboard exit, query settings, announcer and the custom shell exist
exactly once**, in the newest project, and have to be re-done by hand in every other one. Meanwhile the
**theme/button/label helpers exist three times**, the **UI scale function twice**, the **keyboard exit
twice (differently)**, the **fixed-step accumulator twice (differently)**, and the **test harness three
different ways**.

## 3. Shared patterns that are worth preserving

1. **Model with no nodes, view that only reads.** (cell-designer, water-balance.) It is what made 216 / 186
   headless checks possible. SimKit does not force this but its demos follow it and its docs say why.
2. **Visual state is never allowed to change scientific state** (exaggerated radius, interpolated snapshots,
   cosmetic particle layers with their own RNG). Stated as a rule in three CLAUDE.md files.
3. **Parameters as data with validation.** (`ModelParameters.validate()`, `CellProfile`.)
4. **Fixed step with a frame cap.** Equal steps make runs reproducible; the cap protects against stalled tabs.
5. **Nothing runs until the student presses Start; Pause freezes everything.** (cell-designer, tested.)
6. **Information by position and shape, not only colour.** (gauge triangle + line, dashed kept run,
   shape-coded molecules, "CRISIS" word plus hatching.)
7. **Privacy by decision.** water-balance: "no browser persistence, analytics, accounts or student health
   records; session A/B records are deep-copied and memory-only". SimKit's data module follows this.
8. **Honest verification records** (what was checked, how, and what was *not*).
9. **Whitelisted class settings.** Unknown or out-of-range values are ignored; text is never used as a path.

## 4. What is too simulation-specific to abstract

* Every model: resource pools and ledgers, osmosis flow, ADH feedback, station paths and the traced SVG
  geometry. SimKit deliberately gives these nothing but a place to be stepped from.
* Organelle slot layout, fission animation, molecule particle layers, particle fields, body diagrams,
  placeholder art code. These are the "scientific visualizations" the brief asks not to standardise.
* Quiz drag-and-drop on a map (`StationCard`, `MapDropArea`, `BoxTarget`): shared by two projects, but both
  are already the same codebase (doge's `engine/` is circulation's code refactored). The economical answer
  is to fold circulation into doge's engine, not to build a framework module for it
  (see `migration-assessment.md`).
* Tutorial call-out choreography (`tutorials.gd`) and the modal overlay stack: tied to one game's story beats.

## 5. Technical concerns to carry into any new project

1. **Web template version.** A Godot web export needs a template built from exactly the same engine
   version. The author's lean 2D template is 4.5; cell-designer therefore shipped with the 39.5 MB
   standard 4.7.2 template. Targeting 4.7 costs about 17 MB of download per game unless a 4.7 lean template is
   built. (I reproduced the standard 4.7 export: 39.0 MB total, see `framework-architecture.md`.)
2. **Lean-template restrictions.** water-balance reports that a single `OptionButton` was enough to make the
   project fail the 2D-template check; SimKit therefore avoids `OptionButton`, `LineEdit`, `TextEdit`,
   `RichTextLabel`, `ItemList`, `Tree` and `SpinBox`. *I could not run the checker (it lives outside the five
   repos), so the exact list of forbidden classes is unverified.*
3. **Keyboard in an iframe.** The canvas owns Tab; without an explicit leave mechanism keyboard users are
   trapped. Only two projects solve it, in two different ways.
4. **Export hygiene.** One preset ships everything (`exclude_filter=""`), one has an absolute path, and
   cell-designer needed a manual byte scan of the `.pck` to prove no notes or tests were inside.
5. **Test rigor varies.** Only one project verifies that a test ran *all* its checks.
6. **Unverified accessibility.** Even the best-documented project says screen reader, phone, Chromebook,
   touch and physical keyboard are "not yet checked". A framework can supply the mechanisms; it cannot
   substitute for those checks.
