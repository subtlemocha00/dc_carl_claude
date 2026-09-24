# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 0 — Project Foundation: **complete, awaiting human review**.

## Implemented
- Godot 4.7 2D project (`project.godot`) using the Compatibility renderer.
- 1280×720 reference viewport with resizable-window stretch behavior.
- InputMap actions for every control in `GAME_SPEC.md` section 4 (see Controls).
- Placeholder title screen as the main scene. It shows the title, a
  "foundation only" note, and the game/engine version. It has no input handling.
- One sanity test that checks the InputMap bindings.

No gameplay exists yet: no Carl, Donut, movement, combat, inventory, enemies,
floors, or saving.

## Controls
All actions are configured in Project Settings > Input Map. Nothing uses them yet.

| Action             | Key         | Purpose                     |
|--------------------|-------------|-----------------------------|
| `move_up`          | Up Arrow    | Move north                  |
| `move_down`        | Down Arrow  | Move south                  |
| `move_left`        | Left Arrow  | Move west                   |
| `move_right`       | Right Arrow | Move east                   |
| `action_w`         | W           | Action slot 1               |
| `action_a`         | A           | Action slot 2               |
| `action_s`         | S           | Action slot 3               |
| `action_d`         | D           | Action slot 4               |
| `inventory_toggle` | Space       | Open/close inventory        |
| `ui_confirm_game`  | Enter       | Confirm menu/inventory item |
| `pause_back`       | Escape      | Pause/back/cancel           |

W/A/S/D are never movement. Arrows are never action slots.
`tests/test_input_map.gd` enforces both rules.

## Scene structure
```
project.godot                  Project settings and InputMap
scenes/ui/title_screen.tscn    Main (run) scene: placeholder title screen
scripts/ui/title_screen.gd     Fills in the version label
tests/test_input_map.gd        InputMap sanity check (not part of the game)
```
Title screen node tree:
`TitleScreen (Control)` > `Background (ColorRect)`, `CenterContainer` > `TextColumn (VBoxContainer)` > four `Label`s.
The script finds `VersionLabel` through its scene-unique name (`%VersionLabel`).

Folder convention: scenes go in `scenes/<area>/` and their scripts in the
matching `scripts/<area>/` (for example `ui`). Folders such as `assets/`,
`resources/`, `scenes/actors/` and `scenes/levels/` are added when their first
real content arrives. Empty folders are not created ahead of time.

## Autoloads
None yet. `GameState` will be added only when a later phase actually needs
state that outlives a scene. `SaveManager` is deferred until saving is
implemented.

## Collision layers/masks
Not yet established. Collision arrives in Phase 1 and must be documented here in a table.

## Architectural decisions
- **Renderer: Compatibility (OpenGL 3.3).** The game is 2D only. Compatibility
  runs on the widest range of Windows hardware and starts quickly. Verified
  rendering on this machine's Intel UHD Graphics.
- **Stretch: `canvas_items` mode with `expand` aspect, base 1280×720.** The window
  is resizable. A 16:9 window scales uniformly. Other aspect ratios show extra
  area rather than black bars. For example, a 1000×760 window shows 1280×972 of
  game space. UI must therefore use anchors/containers, not fixed positions.
  Texture filtering is left at the default. Revisit it if pixel-art
  placeholders look blurry.
- **Key bindings use physical keycodes on all devices.** Physical means key
  position (US QWERTY layout), which is Godot's usual choice for game controls.
  Only the keys named in the spec are bound: no numpad Enter and no gamepad
  (controller support is out of scope).
- **Godot's built-in `ui_*` actions are left at their defaults.** Control nodes
  use them for focus navigation.
- **Game version** lives in Project Settings > Application > Config > Version
  (`0.0.0`). The title screen reads it from there.
- **Tests** are small standalone `SceneTree` scripts in `tests/`, run from the
  command line. There is no test framework. Run the InputMap test from the
  project folder:
  `godot --headless --path . -s res://tests/test_input_map.gd`
  It exits 0 on pass and 1 on failure. Exclude `tests/` once export presets are
  created.
- **Git:** `.godot/` is ignored. Godot's `*.uid` sidecar files are committed
  because they keep resource references stable across moves/renames.
  `.gitattributes` forces LF line endings, because Git for Windows otherwise
  converts to CRLF and Godot writes LF.

## Known issues
- None blocking.
- The title screen responds to no keys, which is expected in Phase 0. Close
  the window to exit.
- `title_screen.tscn` was written by hand, so its nodes lack the per-node
  `unique_id` fields that Godot 4.7 adds on save. The editor adds them the
  first time the scene is saved. That produces a harmless diff.
- For the future inventory phase: Godot's default `ui_accept` action also
  includes Space, which is the `inventory_toggle` key. A focused inventory
  button could receive Space as "press". Handle this when the inventory UI is
  built.

## Validation performed (Phase 0)
All runs used Godot 4.7.2.stable.official on this machine:
- `godot --headless --path . --import`: completed, exit 0, no errors or warnings.
- `--check-only` parse of both scripts: exit 0.
  The same check on a deliberately broken script reported the parse error.
- `tests/test_input_map.gd`: PASS (11 actions).
  A deliberately broken copy (W on `move_up`, Up on `action_w`, `pause_back`
  removed) failed on all three problems.
- Headless run of the main scene for 300 frames: exit 0, no errors or warnings.
- Rendered run (Movie Maker mode, Compatibility renderer): the title screen
  draws correctly and the version label shows
  `Version 0.0.0 | Godot 4.7.2-stable (official)`.
- Window resized at runtime to 1280×720, 1600×900, 1000×760, 640×360 and
  1280×500. The layout stayed centered and undistorted.

## Manual verification required
1. Open the folder in the Godot 4.7.2 Project Manager (Import > select
   `project.godot`). Confirm the Output panel shows no errors.
2. Press F5 (Run Project). The title screen appears. Drag the window edges and
   check that the text stays centered.
3. Optionally, open Project > Project Settings > Input Map and check the 11
   actions listed above.

## Next phase
Phase 1 — First Traversal Slice (`PHASE_01_FIRST_TRAVERSAL.md`). Start it only
after Phase 0 is reviewed and accepted.
Open question for Phase 1: the spec says "Starting the game reaches the Surface
scene". Phase 1 must either make Surface the main scene or add a "press Enter
to start" step on the title screen. Record whichever choice is made.
