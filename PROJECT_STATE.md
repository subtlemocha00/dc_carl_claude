# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 1 — First Traversal Slice: **complete, awaiting human review**.
Phase 0 — Project Foundation: complete (commit `37b2c87`).

## Implemented
- Title screen (the main scene). **Enter** starts the game on the Surface.
- **Carl** (`scenes/actors/carl.tscn`): blue placeholder with a white arrow that
  shows his facing direction.
  - Moves with the arrow keys at 180 px/s. Diagonals are the same speed as
    straight movement.
  - Keeps facing his last movement direction.
  - Collides with walls and slides along them.
  - Carries a Camera2D that follows him smoothly.
- **Donut** (`scenes/actors/donut.tscn`): orange cat placeholder with ears.
  - Follows Carl automatically, using the level's navigation mesh to walk
    around walls.
  - She settles about 60 px from Carl when he stops and trails about 95 px
    behind while he walks.
  - She is a separate body in the level, not a child of Carl.
  - No combat.
- **Surface** (`scenes/levels/surface.tscn`): 48×28-tile outdoor area.
  - Concrete boundary walls, two long barrier walls that force an S-shaped
    route, several blocks and an L-shaped obstacle.
  - Stairs labelled "Dungeon entrance" in the bottom-right corner.
- **Stairs** (`scenes/props/stairs.tscn`): walking Carl onto them loads the
  level set in their `destination_scene_path`.
- **Floor 1** (`scenes/levels/floor_01.tscn`): 30×20-tile placeholder stone room
  with four pillars, Carl and Donut spawn points, and a "Floor 1 - Maintenance
  Level" sign. It has no exit yet.
- Three automated tests (see Tests).

Not implemented (later phases): combat, W/A/S/D actions, inventory, enemies,
damage/HP, pickups, HUD, saving, pause, Floors 2–3, boss.

## Controls
| Action             | Key         | Status in Phase 1                           |
|--------------------|-------------|---------------------------------------------|
| `move_up`          | Up Arrow    | Moves Carl north                            |
| `move_down`        | Down Arrow  | Moves Carl south                            |
| `move_left`        | Left Arrow  | Moves Carl west                             |
| `move_right`       | Right Arrow | Moves Carl east                             |
| `action_w`         | W           | Action slot 1: reserved, no effect yet      |
| `action_a`         | A           | Action slot 2: reserved, no effect yet      |
| `action_s`         | S           | Action slot 3: reserved, no effect yet      |
| `action_d`         | D           | Action slot 4: reserved, no effect yet      |
| `inventory_toggle` | Space       | Reserved, no effect yet                     |
| `ui_confirm_game`  | Enter       | Starts the game from the title screen       |
| `pause_back`       | Escape      | Reserved, no effect yet                     |

W/A/S/D never move Carl, and the arrow keys never trigger action slots. The
tests enforce both rules.

## Scene structure
```
project.godot                                  Settings, InputMap, physics layer names
assets/tiles/placeholder_world_tiles.png       Original 4-tile placeholder atlas (32x32 each)
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet: ground, barrier, dungeon floor, dungeon wall
scenes/ui/title_screen.tscn                    Main scene; Enter -> Surface
scenes/actors/carl.tscn                        Carl + Camera2D
scenes/actors/donut.tscn                       Donut + NavigationAgent2D
scenes/props/stairs.tscn                       Reusable level-exit trigger
scenes/levels/surface.tscn                     Surface level
scenes/levels/floor_01.tscn                    Floor 1 placeholder room
scripts/<same folder names>/*.gd               One script per scene that needs one
scripts/levels/level_navigation.gd             Bakes a level's navigation mesh on load
tests/*.gd                                     Standalone test scripts (not part of the game)
```

Every level scene uses the same layout:
```
<LevelRoot> (Node2D)
├── NavigationRegion2D   level_navigation.gd; its NavigationPolygon outline = level bounds
│   └── Terrain          TileMapLayer using the shared TileSet (wall tiles have collision)
├── Signs                world-space Labels (placeholder text)
├── Stairs               (optional) stairs.tscn instance with destination_scene_path set
└── Actors               Node2D with Y-sort on, so whoever is lower on screen draws in front
    ├── Carl             carl.tscn instance, placed at the spawn point
    └── Donut            donut.tscn instance; follow_target = ../Carl
```
**To add a floor:** duplicate `floor_01.tscn`, then:
1. Repaint Terrain in the TileMap editor.
2. Resize the NavigationPolygon outline to cover the new level.
3. Move Carl and Donut to the spawn point.
4. Point the previous level's Stairs at the new file.

## Autoloads
None yet. Nothing has to survive a level change so far. `GameState` is added
when Carl's HP or inventory must persist between floors. `SaveManager` is
deferred until saving.

## Collision layers/masks
Names are set in Project Settings > Layer Names > 2D Physics.

| Layer | Name        | Used by                                 | Mask (what it collides with/detects) |
|-------|-------------|-----------------------------------------|--------------------------------------|
| 1     | `world`     | Wall/barrier tiles (TileSet physics layer 0) | none (static)                   |
| 2     | `player`    | Carl                                    | 1 `world`                            |
| 3     | `companion` | Donut                                   | 1 `world`                            |
| —     | (none)      | Stairs (Area2D, `monitorable` off)      | 2 `player`: only Carl triggers it    |

Carl and Donut deliberately do not collide with each other, so Donut can never
body-block Carl in a corridor. Navigation baking reads only layer 1 walls
(`parsed_collision_mask = 1`).

## Architectural decisions
Phase 0 decisions (still in force):
- **Compatibility renderer.**
- **1280×720 base size, `canvas_items` stretch with `expand` aspect.** Other
  aspect ratios show more of the world instead of black bars.
- **Physical-keycode key bindings.**
- **Godot's `ui_*` actions untouched.**
- **Version** stored in Project Settings, now `0.1.0`.
- **Tests** are standalone `SceneTree` scripts.
- **Git hygiene:** `.godot/` ignored, `*.uid` sidecar files committed, LF line
  endings via `.gitattributes`.

Phase 1 decisions:
- **Title → Enter → Surface.** This resolves the Phase 0 open question. It keeps
  the Phase 0 title screen and still satisfies "starting the game reaches the
  Surface". To launch a level directly while testing, open it and press F6
  (Run Current Scene).
- **Carl is a `CharacterBody2D` in floating motion mode**, the top-down mode with
  no floor or gravity. `Input.get_vector()` reads the four `move_*` actions and
  caps diagonal length at 1. `move_and_slide()` applies the fixed physics time
  step, so speed doesn't depend on frame rate. Speed is the exported `move_speed`.
- **Camera:** a `Camera2D` inside `carl.tscn` (so every level gets it).
  - Zoom 1.5 shows about 853×480 world pixels at 16:9, roughly 26×15 tiles.
    Tune it in the Camera2D inspector.
  - Position smoothing is on.
  - No camera limits yet, so the area outside the walls shows the default
    grey background.
- **Physics interpolation is enabled** (Project Settings > Physics > Common),
  with jitter fix 0 as Godot recommends. It keeps motion smooth on monitors
  faster than 60 Hz. Camera2D is set to physics process mode, which
  interpolation requires.
- **Levels are built from `TileMapLayer`s with one shared TileSet** (32×32
  tiles). Only wall tiles have collision. Gameplay code never assumes a grid.
- **Donut navigation:** each level has a `NavigationRegion2D`. Its mesh is
  **baked when the level loads** from the Terrain's wall collisions
  (agent radius 14 px, Donut's body is 10 px). Editing walls therefore never
  leaves a stale navigation mesh, and there is no manual "Bake" step.
- **Donut follow rule:** her speed scales with straight-line distance to Carl.
  - 0 at or below `stop_distance` (60 px).
  - Full `move_speed` (200 px/s, a bit faster than Carl) at or beyond
    `full_speed_distance` (100 px).
  - Proportional in between, which gives smooth starts and stops without a
    separate acceleration setting.
  - All three values are exported for tuning.
  - Her `follow_target` is an exported node reference wired in each level, not
    a global lookup.
- **Level transitions:** the Stairs' exported `destination_scene_path` is
  loaded with `change_scene_to_file()`. The call is deferred because scenes
  cannot be swapped inside a physics callback. Each floor names the next one,
  so later floors need no code changes. When the HUD needs floor numbers and
  names, introduce a small floor-definition Resource and let Stairs reference
  it instead of a raw path.
- **Placeholder art** is original and deliberately plain: Polygon2D shapes for
  actors and stairs, and a generated 4-tile PNG for terrain. Terrain uses
  nearest-neighbour filtering (set on the Terrain node) so tiles stay crisp.

## Tests
Run from the project folder. Each exits with code 0 on pass and 1 on failure.
```
godot --headless --path . -s res://tests/test_input_map.gd
godot --headless --path . -s res://tests/test_carl_movement.gd
godot --headless --path . -s res://tests/test_surface_traversal.gd
```
- `test_input_map.gd`: every action is bound to its key, and no key is shared
  between actions.
- `test_carl_movement.gd`: Carl in an empty scene, driven by real key events
  through the InputMap. It checks:
  - exact distances for each arrow key and for a diagonal;
  - W, A, S and D, each held alone, move 0 px;
  - facing after moving;
  - the same distance at 120 physics ticks per second;
  - a custom `move_speed`.
- `test_surface_traversal.gd`: starts at the main scene, presses Enter, then:
  1. walks Carl into a wall;
  2. steers him along the navigation path to the stairs while tracking the
     Carl–Donut distance;
  3. checks that Donut settles within 50–100 px;
  4. checks that Floor 1 loads with both actors wired correctly;
  5. walks Carl into all four Floor 1 walls.

  It also fails on any engine error or warning logged during the run.

## Validation performed (Phase 1)
All runs used Godot 4.7.2.stable.official on this machine (Intel UHD Graphics,
60 Hz monitor):
- **Import:** headless import finished with no errors or warnings.
- **Editor check:** each of the 6 scenes opened in the headless editor with no
  errors or warnings, and no files were modified.
- **Parse checks:** all 8 scripts pass `--check-only`. They are also clean with
  all 37 default-enabled GDScript warnings upgraded to errors (tested in a
  scratch copy of the project).
- **Tests:** all three pass.
  - The movement test passed 10 of 10 repeated runs.
  - The traversal test gave identical numbers on 5 of 5 runs: largest
    Carl–Donut gap while walking 106.6 px, 60.0 px after stopping.
  - Carl stopped exactly at the wall faces (Surface x=500; Floor 1
    x=44/916, y=44/596).
- **Mutation checks:** I injected bugs into scratch copies of the project. The
  tests caught every one:
  - W/A/S/D moving Carl;
  - no diagonal normalization;
  - Donut not wired to Carl;
  - Donut steering straight at Carl without navigation (she ended up stuck
    about 830 px behind);
  - Stairs pointing at a missing scene.
- **Rendered playthrough:** the real main scene was played with real key
  events at 1280×720, 640×360 and 1024×768: title → Enter → Surface S-route
  with the arrow keys → stairs → Floor 1. Screenshots were inspected at each
  size. Layout was correct at all three, and the 4:3 window shows extra space
  vertically instead of distorting.
- **Camera smoothness:** measured per rendered frame during a steady walk.
  Every frame had exactly one physics tick and a 3.00 px camera step (3 runs ×
  180 frames, 0 irregular). One isolated hitch appeared once, in the very first
  window of a batch run, and did not recur.

## Known issues / limitations
- Escape, Space and W/A/S/D do nothing yet (by design for Phase 1). There is no
  way back to the title screen: close the window, or press F8 in the editor.
- Floor 1 is a single placeholder room with no exit.
- Donut judges distance in a straight line. If Carl stops just on the other side
  of a thin wall, less than 100 px away, she walks around at reduced speed. This
  can't happen on the current layouts, where walls are 2 tiles thick.
- Donut does not step aside if Carl walks onto her. They don't collide, so they
  can briefly overlap.
- Holding an arrow key through the stairs transition keeps Carl moving on
  Floor 1. This is normal for held keys.
- Releasing two diagonal keys a frame apart leaves Carl facing the direction of
  the key released last. This is normal keyboard behavior.
- No camera limits: the grey area outside the walls is visible near level edges.
- At 640×360 the world-space sign text is small but readable.
- Scene files were written by hand, so Godot adds per-node `unique_id` fields
  the first time each scene is saved in the editor. That diff is harmless.
- Carried over from Phase 0: Godot's default `ui_accept` also includes Space,
  which is the inventory key. Handle this when the inventory UI is built.

## Manual verification required
1. Open the project in Godot 4.7.2. The Output panel should show no errors.
2. Press **F5**. The title screen appears. Press **Enter**. The Surface loads
   with Carl (blue) and Donut (orange cat).
3. Walk with the **arrow keys**. Try each direction and diagonals. The white
   arrow on Carl points where he last moved.
4. Press **W, A, S, D**. Carl must not move.
5. Walk into walls and blocks. Carl stops and slides along them and cannot
   leave the area.
6. Take the long way around both barrier walls to the stairs (bottom-right).
   Donut should keep following around corners and settle near Carl when you
   stop.
7. Step onto the stairs. Floor 1 loads with Carl, Donut and the
   "Floor 1 - Maintenance Level" sign.
8. Resize the window. The view adapts without distortion.

## Next phase
Phase 2 is **not yet specified**: the repository has no `PHASE_02_*.md` file.
Provide one, with its acceptance criteria, before Phase 2 starts.
Phase 1 must be reviewed and accepted first.
