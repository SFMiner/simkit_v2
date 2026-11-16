# SimKit architecture

SimKit is a **toolkit of small, independent GDScript pieces**, not an engine. A project copies
`addons/simkit/` (or only some of its folders) and uses whichever classes it needs. Nothing is an AutoLoad,
nothing needs a plugin to be enabled, and no class has to be inherited from.

## Versions and constraints

* **Target: Godot 4.7** (the demo project is tagged 4.7, GL Compatibility).
* **Also verified on Godot 4.5.stable**: all 266 headless checks pass (the other four repos are tagged 4.5).
  Not verified on 4.6. Nothing in SimKit uses a 4.6+ API as far as I know, but that is not a test.
* **Web export verified on 4.7 only** (standard `web_nothreads_release` template, 39 MB total export). A web
  export needs a template built for the same engine version. The lean 2D template found in your project
  presets is a 4.5 build, so a 4.5 project can use it but a 4.7 project cannot until a 4.7 lean template is
  built. I did not test a lean template at all.
* Typed GDScript, tabs, UI built in code, no scenes required (the demo has one 8-line scene).
* All class names are prefixed `Sk` to avoid colliding with your own (`Announcer`, `UiTheme`, `KeyboardNav` ... exist in
  your repos).
* Only basic controls are used (`Button`, `CheckBox`, `HSlider`, `Label`, containers, `ScrollContainer`).

## Layout and dependencies

```
addons/simkit/
  core/    9 files   no dependency on anything outside core
  ui/      4 files   needs core
  viz/     2 files   needs core (SkTheme only)
  data/    2 files   needs core
  edu/     2 files   needs core + ui (lesson buttons); data is optional and duck-typed
  deploy/            HTML shell, export script, iframe harness, browser smoke test (not GDScript)
```

Verified, not just intended: `tests/test_isolation.gd` builds a brand-new project for **core**, **core+ui**,
**core+viz**, **core+data**, **core+ui+edu** and **everything**, and requires each to import and load without
errors. Two negative controls (edu without ui; viz without core) must fail, proving the check can see a missing
dependency. A second check scans `core/` and fails if its code names any optional class.

### Core (A): what nearly every simulation needs

| Class | Job | Replaces (seen in) |
|---|---|---|
| `SkParam`, `SkParams` | Parameter specs (float/int/bool/choice, limits, step, default, help), current values, clamp/refuse, reset, lock, change signal, dictionary round-trip, **page-address settings**, validation, README table | `ModelParameters.validate()`, `CellProfile`, `GameSettings.parse_query` |
| `SkSession` | Lifecycle READY→RUNNING↔PAUSED→FINISHED, reset with reproducible seed, three stepping modes, duration, optional parameter lock | controllers in cell-designer and water-balance; play/pause state in circulation/doge/osmosis |
| `SkClock` | Fixed-step accumulator with a frame cap and an interpolation `alpha()` | two hand-written loops |
| `SkHost` | The *only* file touching `JavaScriptBridge`: page address, DPR, browser preferences, `sims:leave-game`, live-region announcements, file download / save, fullscreen, safe file names | `KeyboardExit`/`KeyboardNav`/`Announcer`/`GameSettings` fragments; fullscreen in circulation/doge |
| `SkFocusRing` | Tab ring rebuilt each key press, boundary leave, Escape closes-then-leaves | `KeyboardExit`, `KeyboardNav` |
| `SkViewScaler` | DPI-aware content scale with a 0.85 CSS-px floor, text-size multiplier | `view_scale`, `_apply_scale` |
| `SkTheme` | Code-built theme from three palettes (dark, light, high contrast), focus outlines, check/slider icons, colour-blind-safe series colours | `UiTheme`, two `_build_theme` copies |
| `SkA11y` | Text size, high contrast, reduced motion as ordinary `SkParams`; browser defaults; persistence; `bind(root, scaler)` | `GameSettings` |

Dependencies inside core: `SkParams`→`SkParam`; `SkSession`→`SkClock`, `SkParams` (optional), `SkHost` (version);
`SkViewScaler`, `SkFocusRing`→`SkHost`; `SkA11y`→`SkParams`, `SkTheme`, `SkHost`, `SkViewScaler`.
`SkParam`, `SkParams`, `SkClock`, `SkHost`, `SkTheme` can each be used alone.

Core is **854 lines of code**. That is not tiny, but the five repos contain ~520 lines doing the
overlapping parts of it, once, in one project. See "Honest size accounting" below.

### Optional modules (B)

| Module | Classes | Notes |
|---|---|---|
| `ui` | `SkUi` (button/label factories, 52 px touch size), `SkParamPanel` (controls generated from `SkParams`, two-way sync, lock-aware, announces changes), `SkTransportBar` (Start/Pause/Step/Reset/Speed + Space/R/N hotkeys), `SkSplitView` (side-by-side when wide, stacked in a scroll area when narrow) | choice params are toggle-button rows, not `OptionButton` |
| `viz` | `SkLineGraph` (series, dashed kept runs, bands, end labels, marker shapes, auto ranges, text `describe()`), `SkGauge` (labelled bands, words-first verdict) | generalised from `RaceGraph`, `SodiumGauge`; colours from the theme type `SkChart` |
| `data` | `SkLog` (events, multiple-choice responses, tables, kept runs; auto-attach to a session), `SkExport` (JSON, CSV with spreadsheet-formula neutralising, save via `SkHost`) | no names, ids, dates or free text; memory only until the *student* presses Save |
| `edu` | `SkLesson` (plain data / JSON: objectives, instructions, prediction, observations, hidden explanation, reflection, vocabulary), `SkLessonPanel` | every section optional; **no free-text answers by design** |
| `deploy` | `shell.html`, `export_web.sh`, `harness.html`, `web_smoke.js` | see below |

### Simulation-specific (C): never in the kit

Models and their ledgers, scientific visualisations (cells, body diagrams, particle fields, maps), level/story
logic, quiz drag-and-drop on maps, tutorial choreography. The two demos show the pattern: a pure `RefCounted`
model plus a UI script that wires it to SimKit pieces.

## Key design decisions

1. **Composition, not inheritance.** `SkSession` calls two `Callable`s you give it. No base class, no required
   method names. A model can be a `RefCounted`, a `Node`, or a lambda.
2. **Three time models behind one lifecycle.** `FIXED_STEP` (continuous models, equal steps),
   `CONTINUOUS` (per-frame dt, capped) and `MANUAL` (turns, generations, events: time moves only on
   `step_once()`). The two demos use FIXED_STEP and MANUAL with the same transport bar and log.
3. **No auto-play.** A session never leaves READY by itself. Pause freezes the model. Tested.
4. **Reproducibility is a first-class field.** `SkSession.rng` is seeded; `reset()` replays the same random
   history; `describe()` returns framework version, mode, seed, sim time, steps and readable parameter values and
   goes into every export. The predator–prey test shows the demo's state after N steps equals a standalone model
   stepped N times, and a reset replays it bit-for-bit.
5. **Parameters are data.** A spec says what a control should be; `SkParamPanel` builds it; `apply_query`
   whitelists page-address settings; `class_settings_markdown()` writes the "registry facts" table. A spec can be
   checked (`validate()`) without any UI. Out-of-range input is clamped by code but **rejected** by the page address
   (matching cell-designer's rule).
6. **Locking is a flag, not a mode.** `lock_while_running` on a param plus `lock_params_after_start` on a session
   gives the "conditions lock after starting" rule from water-balance. A locked CHOICE keeps its selected option
   visible (found in review: a disabled button loses its selected look).
7. **Accessibility is settings that change presentation only.** `SkA11y` exposes `reduced_motion()` and
   `anim_time()` for drawing code; the model never sees them.
8. **Browser access is concentrated.** Everything that calls `JavaScriptBridge` is in `SkHost`; outside the web
   it is inert or writes to `user://`, so tests run headless.
9. **Privacy and the lean template shaped the data module.** Responses are *choices*, not typed text.
   `LineEdit`/`TextEdit` are avoided (possible lean-template exclusion, and personal-data risk).
10. **Responsive means scroll or stack, never shrink.** `SkViewScaler` floors scale at 0.85 CSS px per base px;
    `SkSplitView` stacks panes when narrower than 780 base px. This was added after the real-Chromium 380 px
    frame showed the side panel cut off.
11. **Touch size is a derived constant.** `SkUi.TOUCH_MIN = 52` base px = 44 CSS px at the 0.85 floor.

## Deployment contract implemented

From cell-designer's GDD §8 / HOSTING_VERIFICATION and water-balance's README (second-hand: the site's own
SPEC was not in the repos):

* root `index.html`, no threads, no server features;
* `sims:leave-game` to a same-origin parent (Tab past the end, Shift+Tab before the start, Escape with nothing open);
* class settings from the page address, whitelisted;
* top-right 200×64 CSS px left free (demo launcher does this; `SkHost.RESERVED_CSS`);
* no auto-play, 1180×500 iframe usable (also exercised at 1180×360, 590×250, 380×640);
* export hygiene: `exclude_filter` for tests/docs, and `export_web.sh` scans the `.pck` for them.

Not implemented because it is site-side and not visible from the repos: registry import, hidden/published states.

## Honest size accounting

| | lines of code (non-blank, non-comment) |
|---|---|
| `core` | 854 |
| `ui` + `viz` + `data` + `edu` | 386 + 292 + 127 + 174 |
| demos (3 UIs, 2 models, launcher) | ~863 raw lines |
| tests (7 suites, 266 checks) | 1,278 raw lines |

A minimal simulation (`demo/minimal/cooling_demo.gd`: graph, two parameters, Start/Pause/Reset/Speed, reset
reproducibility) is **38 lines of code**. The two larger demos are 218 and 289 raw lines including
their lesson text and cosmetic drawing.

## Tests

| Suite | Checks | What |
|---|---|---|
| `test_params` | 33 | clamp/snap/refuse, signals, lock, dictionary round trip, page address, validation |
| `test_session` | 33 | clock exactness (600 frames = exactly 100 steps), lifecycle, three modes, duration, reproducible seed, locking |
| `test_platform` | 45 | host helpers, scaler maths, focus ring with real key events, WCAG contrast of the palettes, a11y persistence |
| `test_modules` | 72 | panels, transport, graph, gauge, log/export round trips, CSV quoting, lesson, split view |
| `test_models` | 24 | scientific correctness (see below) |
| `test_demos` | 49 | demos end to end, determinism, locking, export, Escape semantics, touch sizes, page address |
| `test_isolation` | 10 | module combinations in clean projects; negative controls |

Scientific checks on the demo models: logistic growth equals the exact solution to 1e-4; fox decay equals
`e^(-mt)`; the coexistence equilibrium stays put for 150 months; halving the RK4 step changes the answer by
less than 0.01 animal; selection-after-one-generation equals the analytic value within sampling error;
no-selection control shows no drift; same seed → identical history.

Browser checks (`deploy/web_smoke.js`, real Chromium via Playwright, iframe harness): boots without console errors,
static for 3 s without input, Tab+Enter opens a demo and the live region receives the announcement, Escape closes
the demo without leaving, Escape on the menu sends exactly one `sims:leave-game` and focus lands on the host
page, class settings from the address apply, Space starts and pauses (pixel-identical frames while paused), four
frame sizes boot without errors. Software rendering only; screenshots read by me.

## Not done / known limits

* No density setting; no screen-reader verification; no hand testing on touch devices, a Chromebook or a
  physical keyboard; high-contrast and colour-blind palettes unverified by eye or tool beyond computed contrast.
* Selected toggles differ by fill and a thicker border, not tested in grayscale.
* `SkLineGraph` draws by redrawing everything on each point; fine to 20,000 points per series, not benchmarked.
* The lean web template and a 4.5 web export were not tested.
