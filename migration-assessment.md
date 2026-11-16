# Migration assessment

No migration was performed; the five repos were not modified. Effort figures are **my estimates** for a
developer who knows the repo, in focused hours including re-testing. They have not been measured. Where a
repo's real behaviour is unknown to me (not run, GDD not read) I say so. Version note: `cell-designer` is on
4.7; the other four are tagged 4.5, so adopting SimKit means moving them to 4.7 first (or using SimKit
on 4.5, which passes its tests but is not the target). That version bump is **not** included below, and
for web projects it also forces a template decision (a 4.7 lean template does not exist yet).

## Summary

| Project | Worth migrating? | Estimate | Main benefit | Main risk |
|---|---|---|---|---|
| `water-balance` | **Partly, yes** | 6–10 h | Fix static focus paths and uncapped steps; gain text-size / reduced motion / announcer / query settings; drop custom graph and gauge | model and controller are good already: do **not** rewrite them |
| `cell-designer` | **Selectively** | 3–5 h | None of the infrastructure is missing; benefit is mainly that SimKit's pieces would be *this project's pieces, maintained once* | it is the donor; replacing working, hosting-verified code risks regressions for little gain |
| `osmosis-simulation` | **Yes, most gain per hour** | 8–14 h | Layout containers (responsive), keyboard ring and exit, theme, text size, a11y, tests, export hygiene | UI rewrite; two modes; the model itself stays |
| `dogestive-sim` | **Yes, but partial** | 5–8 h | Keyboard exit, a11y, query settings, theme, scaler; deletes its copy of the helpers | god-script `main.gd` makes a surgical swap awkward |
| `circulation-sim` | **No, as a separate migration**: fold into doge's engine first | 2–4 h to merge, then as doge | Eliminates a near-duplicate project | it works; two siblings of one codebase should not each be migrated |

## Per project

### water-balance (6–10 h)
Already has: model/controller/view split, `Resource` parameters with `validate()`, deep-copied kept runs,
tests. Use SimKit for: `SkViewScaler` and `SkFocusRing` (replacing `KeyboardNav`; fixes the "break if a control is
moved" fragility), `SkTheme`/`SkA11y` (text size, high contrast, reduced
motion), `SkHost` (announcer, `leave_game`), `SkLineGraph` + `SkGauge` (replace `RaceGraph`, `SodiumGauge`; their
dashed kept-run and band behaviour was the template, so nearly 1:1), `SkSession` in FIXED_STEP with a frame cap.
**Leave alone:** `WaterBalanceModel`, `ModelParameters`, the controller's snapshot interpolation and A/B ledger
(unique), the body diagram. Also replace the absolute Windows template path in `export_presets.cfg`.
Mapping caveat: `ModelParameters` is a `Resource` with arrays of rates; the UI toggles are index choices, so
they map to `SkParam.choice_param` but the model should keep its own `Resource`. Expect to keep both.
Watch: its 62 UI checks assert on specific controls and the `EXPECTED_STOPS` tab count; they will need updating.

### cell-designer (3–5 h, optional)
It is where `SkFocusRing`, `SkA11y`, `SkHost` and `SkTheme` came from, and its keyboard and settings tests
pass today. The sensible move is not a rewrite but to swap `KeyboardExit`→`SkFocusRing`, `Announcer`→`SkHost.announce`,
`GameSettings`→`SkA11y` + `SkParams` (class settings table comes free), `UiTheme`→`SkTheme`, `view_scale`→`SkViewScaler`,
and re-run its 216 checks, balance report and browser script. Skip if its schedule is tight; it loses nothing
by waiting. **Do not** replace its model, organelle layout, tutorials or overlay stack.

### osmosis-simulation (8–14 h)
Largest improvement. Current state: absolute-position layout, no keyboard handling, no theme, no safe
area, `assert`-based test, export preset that ships everything. Plan: keep `OsmosisSimulation`,
`CellProfile`, `CellView`, `ParticleField`, `RedBloodCells`; rebuild `main.gd` as containers
(`SkSplitView`: canvas and controls), replace the slider with `SkParamPanel` (note: the slider is an
integer −5…+5 → `SkParam.int_param`), add `SkTransportBar` (Pause/Reset), `SkFocusRing`, `SkA11y`, `SkLineGraph`
or `SkGauge` instead of the two `ProgressBar`s, convert the test to `SkTest` with an exact count, set
`exclude_filter`, remove or exclude the unused MP3. The two modes could be a `SkParams` choice. Risk: its
physics-step model uses `_physics_process`; moving it to `SkSession` FIXED_STEP changes timing slightly
(reset the expectation in tests, do not assume equality). Confirm the 4.5 vs 4.7 question first.

### dogestive-sim (5–8 h)
Replace the duplicated helpers in `engine/main.gd` (`_box`, `_make_button`, `_make_label`, theme, fullscreen,
actions) with `SkUi`, `SkTheme`, `SkHost.toggle_fullscreen`; add `SkFocusRing` (arrow/Tab/Enter on cards and
boxes would be in the ring), `SkA11y`, `SkViewScaler` instead of `aspect=keep`, `SkHost.announce` for quiz feedback.
Leave `SimSystem`, `SimToken`, `MapView`, `BoxTarget`, quiz logic as they are. A real gain would be tests
(the quiz rules are intricate, e.g. helper-organ ordering); SimKit supplies the harness only.
The state machine inside `main.gd` is the thing that actually needs refactoring and SimKit does not help with it.

### circulation-sim (2–4 h to merge into doge, not a standalone migration)
It is the same engine as doge before the refactor. Port `CirculationData` to a `SimSystem` subclass
(the data is already shaped for it), delete `main.gd`, `station_card.gd`, `map_drop_area.gd`. Then it inherits
whatever doge gets. A separate SimKit migration of its 685-line `main.gd` would be wasted effort.

## Where migration is **not** worthwhile

* Any model code in any repo.
* Scientific visualisations and art code (cell views, body diagram, particle fields, maps).
* Tutorial/overlay machinery in cell-designer.
* The tour/quiz drag-and-drop mechanics: not in SimKit by design; consolidate circulation into doge instead.

## Suggested order

1. Decide the engine version for all web games (4.7 or stay 4.5), and whether to build a 4.7 lean web template.
2. Use SimKit unchanged in the **next new simulation** (zero migration cost, real feedback).
3. osmosis → water-balance → dogestive(+circulation merge) → cell-designer last or never.

## Honest caveat

These estimates assume the SimKit pieces behave in your projects as they do in the demos. Parts of the
touch, screen-reader and Chromebook behaviour are unverified for SimKit itself, exactly as they are for cell-designer.
