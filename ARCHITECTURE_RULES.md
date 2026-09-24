# ARCHITECTURE & DEVELOPMENT RULES

These rules apply to every implementation.

## 1. Technology

- Godot 4.7.2 stable.
- GDScript.
- Godot Standard build; do not require the .NET build.
- Windows PC is the initial target.
- Do not upgrade the project to a Godot preview/dev version.
- Do not introduce C#, JavaScript, Python, Rust, or native extensions into the game runtime without explicit user approval.

## 2. Prefer Godot-native systems

Use Godot's built-in systems where they fit:
- scenes/nodes
- signals
- InputMap
- CharacterBody2D
- Area2D
- collision layers/masks
- Camera2D
- NavigationAgent2D/NavigationRegion2D if appropriate
- Resources for reusable data where appropriate
- Control nodes for UI

Do not build replacement engines/frameworks inside Godot.

## 3. Keep architecture understandable

The owner is new to game development.

Prefer:
- explicit names
- short scripts
- focused responsibilities
- comments for non-obvious behavior
- typed GDScript where practical
- clear directory organization

Avoid:
- premature abstraction
- dependency-injection frameworks
- service locators
- giant inheritance trees
- excessive singleton/autoload usage
- metaprogramming
- obscure cleverness

## 4. Global state

Initial allowed autoload concepts:
- `GameState`
- `SaveManager` when saving is introduced

Do not create a manager singleton for every subsystem.

Phase 0 should not add SaveManager unless it is genuinely needed in Phase 0, which it normally is not.

## 5. Scenes and reusable actors

Carl, Donut, enemies, reusable pickups, reusable UI components, and similar actors should have their own reusable scenes once those systems are introduced.

Do not duplicate the same actor logic separately in every floor.

## 6. Data-driven content

Reusable content such as item definitions, enemy stats, and floor definitions should trend toward data/resources instead of large hard-coded conditionals.

However, introduce these abstractions when the corresponding feature arrives. Do not create dozens of empty speculative resource classes in Phase 0.

## 7. Input

Use Godot InputMap action names.

Suggested names:
- `move_up`
- `move_down`
- `move_left`
- `move_right`
- `action_w`
- `action_a`
- `action_s`
- `action_d`
- `inventory_toggle`
- `ui_confirm_game`
- `pause_back`

Do not rely on raw physical key polling throughout gameplay code.

Arrow keys control movement.
W/A/S/D control action slots.

## 8. Collision organization

As collision systems are introduced, document layer/mask meanings in a short table in `PROJECT_STATE.md` or a dedicated file.

Do not use unexplained arbitrary collision layer numbers throughout scripts.

## 9. Scene references

Prefer robust scene/resource references over fragile assumptions about absolute node paths.

Avoid deeply coupled `$Parent/Parent/SomeOtherBranch/...` dependencies.

## 10. Errors and warnings

Do not hide errors with broad error suppression.

Do not claim a test passed unless it was actually run or can be directly verified.

If Godot cannot be executed from the coding environment, state that clearly and provide the exact verification that remains for the human.

## 11. Scope discipline

Implement only the active phase plus tiny prerequisite infrastructure.

Do not implement future phases merely because they seem easy.

Do not redesign requirements without asking.

If a requirement is ambiguous but a reasonable low-risk implementation is possible, choose the simplest interpretation and record the decision in `PROJECT_STATE.md`.

## 12. Git

The repository should remain commit-ready after every phase.

Before declaring a phase complete:
- inspect `git status`;
- ensure generated `.godot/` cache data is not tracked;
- remove accidental temporary files;
- summarize changed files;
- commit with a concise phase-oriented message if Git identity/config permits.

Suggested commit style:
`phase 0: initialize Godot project architecture`

If committing is impossible due to environment credentials/configuration, do not fake success; report the exact limitation.

## 13. Godot-generated files

`.godot/` must be ignored.

Do not manually edit generated cache/import internals.

Keep source assets and project files under version control.

## 14. Documentation

At the end of each phase update `PROJECT_STATE.md` with:
- completed phase
- current controls
- important scene/script structure
- architectural decisions
- known issues
- manual verification still needed
- next intended phase

Do not overwrite the product requirements in `GAME_SPEC.md` or these architecture rules unless the user explicitly asks for a requirements change.

## 15. Testing philosophy

Favor small deterministic tests and sanity checks for pure logic where useful.

Gameplay acceptance still requires actually launching/running the Godot project whenever the environment permits.

Do not build a large testing framework before there is meaningful logic to test.
