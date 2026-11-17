Assignment: Independent Stress Test — Godot Educational Simulation Kit
======================================================================

Objective
---------

Conduct an adversarial engineering evaluation of the newly developed reusable Godot educational simulation kit.

The kit was created by analyzing five existing educational game and simulation repositories. Its developer estimates that it could eliminate approximately 800 lines of repeated code per new simulation.

Your task is to test that claim, identify architectural weaknesses, and determine whether the kit is genuinely useful across different kinds of educational simulations.

**Do not assume that the framework is well designed simply because its demonstration works.**

The evaluation must involve actual implementation, execution, and testing.

Target Godot version: **4.7**.
Phase 1: Architectural Inspection
---------------------------------

Examine the complete simulation kit, its documentation, demonstration project, and relevant source repositories.

Identify:

* Core components and their responsibilities.

* Optional modules and dependencies.

* Required initialization and configuration.

* Assumptions about simulation structure.

* UI and state-management patterns.

* Accessibility and data-export support.

* Web-export requirements.

* Any dependencies on specific project settings or autoloads.

Evaluate whether the framework imposes unnecessary constraints.

Look for excessive coupling, hidden dependencies, global state, redundant abstractions, and assumptions that might work for one simulation but fail for another.
Phase 2: Build Two Independent Test Simulations
-----------------------------------------------

Create two small but complete simulations using the kit.

Both must use the existing public interfaces and documented integration procedures.

Do not modify the framework to make the tests pass.

### Test A: Continuous Particle Simulation

Build a simple 2D diffusion simulation.

Requirements:

* Particles move continuously within a bounded environment.

* Two adjustable parameters affect observable behavior.

* Users can pause, resume, and reset.

* Changes in parameters produce visible consequences.

* A simple graph or numerical indicator displays a meaningful measurement.

* The simulation includes a short prediction or observation interaction.

This tests continuous updates, parameter binding, visual rendering, and UI responsiveness.

The model need not reproduce molecular physics quantitatively, but its qualitative behavior must be scientifically coherent.

### Test B: Discrete Population Simulation

Build a simplified population model with discrete generations.

Requirements:

* A population contains at least two heritable variants.

* Users can adjust environmental conditions.

* Each generation updates population composition according to explicit rules.

* The interface displays changes over multiple generations.

* Users can advance one generation at a time or run automatically.

* Users can reset the model and reproduce an initial configuration.

* A short explanatory interaction helps users interpret the results.

This tests whether the framework supports discrete-step models rather than assuming every simulation runs continuously.

The model should not imply that organisms mutate in response to need or that individual organisms evolve during their lifetimes.
Phase 3: Adversarial Tests
--------------------------

Test the following conditions where applicable:

### Lifecycle and state

* Repeated start, pause, resume, and reset operations.

* Reset while the simulation is running.

* Parameter changes during execution.

* Invalid or extreme parameter values.

* Multiple simultaneous instances.

* Deterministic behavior when a fixed random seed is supplied.

* State consistency after scene reloads.

### UI and accessibility

* Different viewport sizes.

* Keyboard navigation.

* Scaled text.

* High-contrast presentation.

* Reduced-motion settings.

* Long labels and unexpected input values.

* Usability without relying exclusively on color.

### Data and export

* Local data recording.

* Export with no recorded data.

* Export after repeated resets.

* Correct handling of special characters.

* Browser-compatible file export.

* Absence of unnecessary personal information.

### Integration

* Importing the kit into a clean Godot 4.7 project.

* Using only the core components.

* Using optional modules independently.

* Removing optional modules without breaking the simulation.

* Avoiding conflicts with existing project settings.

### Performance

* Increasing particle or population counts.

* Monitoring frame rate and memory behavior.

* Identifying avoidable allocations or expensive update loops.

Use reasonable stress levels for browser-based classroom simulations rather than artificial extremes with no practical relevance.
Phase 4: Measure Development Efficiency
---------------------------------------

Evaluate the claim that the kit saves approximately 800 lines of code per project.

Measure:

1. Lines of simulation-specific code.

2. Lines of configuration and integration code.

3. Lines of reused framework code.

4. Additional code required to work around framework limitations.

5. Time or implementation steps required to integrate the kit.

6. Components that were genuinely useful.

7. Components that added complexity without clear benefit.

Do not equate fewer lines of code with better software automatically.

Where practical, estimate the effort of implementing equivalent functionality without the kit, using the five reference repositories as evidence.

Clearly distinguish measured results from estimates.
Phase 5: Identify Architectural Problems
----------------------------------------

Classify findings as:

* **Critical:** Prevents correct or reliable use.

* **Major:** Substantially reduces usefulness or flexibility.

* **Moderate:** Creates unnecessary work or maintenance burden.

* **Minor:** Cosmetic, documentation, or low-impact issues.

For each finding, include:

* Exact source location.

* Steps to reproduce.

* Expected behavior.

* Actual behavior.

* Likely cause.

* Recommended correction.

* Whether the issue is in the kit, its documentation, or the test implementation.

Do not modify the original kit.
Phase 6: Validation
-------------------

Run both test simulations in Godot 4.7.

Verify that:

* Projects load without parser errors.

* Controls function correctly.

* Simulation state behaves as expected.

* Resets restore the intended initial conditions.

* Data export works where supported.

* No critical errors appear during normal operation.

Attempt browser export and execution if the required tools are available.

Do not claim successful browser compatibility merely because the project exports without an error.

If graphical execution or browser testing is unavailable, document the limitation and perform the strongest available alternative tests.
Deliverables
------------

### `simulation-kit-audit.md`

Architectural review, strengths, weaknesses, and recommendations.

### `stress-test-results.md`

Test cases, procedures, results, failures, and reproduction instructions.

### `development-efficiency.md`

Assessment of the claimed code savings, with measurements and estimates clearly distinguished.

### `framework-improvements.md`

Prioritized recommendations with implementation-ready acceptance criteria.

### `test-projects/`

Two complete Godot 4.7 test projects, including all required source files and assets.

### `README.md`

Instructions for running the tests and interpreting the results.
Constraints
-----------

* Treat the original simulation kit as read-only.

* Do not modify the five reference repositories.

* Do not redesign the framework before testing it.

* Do not silently work around framework limitations without documenting them.

* Do not add unrelated features.

* Do not introduce unnecessary dependencies.

* Do not substitute static analysis for execution when execution is possible.

* Do not manufacture performance or efficiency measurements.

* Do not claim a test passed unless it was actually executed successfully.

Autonomy
--------

Proceed independently through inspection, implementation, testing, analysis, and documentation.

Do not stop after producing a test plan.

Make reasonable decisions without requesting approval for routine matters.

If a test reveals a major framework limitation, document it and continue with other tests rather than abandoning the assignment.

Do not modify the original framework or its repositories.
Final Report
------------

Provide:

1. Overall assessment of the simulation kit.

2. Which components proved most useful.

3. Which components created unnecessary complexity.

4. Test results for both simulations.

5. Measured or estimated development savings.

6. Critical and major issues.

7. Recommended corrections.

8. Whether the framework is ready for use in future educational simulations.

**Success criterion:** Determine, through actual development and testing, whether the kit makes it faster and easier to build substantially different Godot educational simulations without compromising reliability, flexibility, or scientific correctness.
