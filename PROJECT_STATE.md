# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 2 — First Combat Loop: **complete, awaiting human review**.
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There is no `PHASE_02_*.md` file. Phase 2 scope came from the owner's Phase 2
prompt, checked against `GAME_SPEC.md`. See "Spec discrepancies" below.

## Implemented
- **Title screen** (main scene). Enter starts the game on the Surface.
- **Carl** (`scenes/actors/carl.tscn`):
  - Arrow-key movement at 180 px/s, same speed on diagonals.
  - Remembers facing (shown by a white arrow), collides with walls, and has a
    smoothed camera.
  - **Phase 2:** 100 HP. **W punches with Fists** in his facing direction.
    He flashes red when hurt, and turns grey and stops responding at 0 HP.
- **Donut** (`scenes/actors/donut.tscn`): follows Carl around walls using the
  level's navigation mesh. No combat, and she cannot be hurt yet.
- **Gelatinous Blob** (`scenes/enemies/gelatinous_blob.tscn`, Phase 2): green
  Floor 1 enemy with a small health bar.
  - Waits until Carl is within 220 px, then oozes straight at him at 55 px/s.
  - Hurts him by touch: 10 damage at most every 0.8 s.
  - 30 HP, so 3 punches.
  - When it dies it stops acting at once, stops blocking, fades out and is
    removed.
- **Surface**: outdoor area with barrier walls and the "Dungeon entrance" stairs.
  **Phase 2:** a `FromFloor1` spawn point beside the entrance, and the HUD.
- **Floor 1**: stone room with four pillars. **Phase 2:**
  - two Gelatinous Blobs;
  - up-stairs back to the Surface;
  - signs, including "W: punch in the direction you face";
  - the HUD.
- **Stairs** (`scenes/props/stairs.tscn`): load their destination level.
  - **Phase 2:** they can name an arrival spawn point.
  - They ignore Carl if he is already standing on them when a level starts, so
    transitions never loop.
- **HUD** (`scenes/ui/hud.tscn`, Phase 2):
  - "HP: x / 100" in the top-left.
  - A centred "GAME OVER — Carl is down. Restarting the floor..." message when
    Carl dies.
- **Temporary game over** (Phase 2): 2 seconds after Carl dies, the current
  level restarts. Carl is back at his spawn with full health, and the enemies
  are restored.

Not implemented (later phases): items, inventory and equipment, A/S/D actions,
Donut combat/damage/stun, pickups, other enemy types, saving/checkpoints, pause,
Floors 2–3, boss.

## Controls
| Action             | Key         | Status in Phase 2                                  |
|--------------------|-------------|----------------------------------------------------|
| `move_up`          | Up Arrow    | Moves Carl north                                   |
| `move_down`        | Down Arrow  | Moves Carl south                                   |
| `move_left`        | Left Arrow  | Moves Carl west                                    |
| `move_right`       | Right Arrow | Moves Carl east                                    |
| `action_w`         | W           | Action slot 1 = **Fists: punch** (hold to repeat every 0.4 s) |
| `action_a`         | A           | Action slot 2: empty, no effect yet                |
| `action_s`         | S           | Action slot 3: empty, no effect yet                |
| `action_d`         | D           | Action slot 4: empty, no effect yet                |
| `inventory_toggle` | Space       | Reserved, no effect yet                            |
| `ui_confirm_game`  | Enter       | Starts the game from the title screen              |
| `pause_back`       | Escape      | Reserved, no effect yet                            |

No input actions were added in Phase 2. W/A/S/D never move Carl, and the arrow
keys never trigger action slots; the tests enforce both.

## Scene structure
```
project.godot                                   Settings, InputMap, physics layer names
assets/tiles/placeholder_world_tiles.png        Original 4-tile placeholder atlas
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet (wall tiles collide)
scenes/ui/title_screen.tscn                     Main scene; Enter -> Surface
scenes/ui/hud.tscn                              HP label + game-over message (CanvasLayer)
scenes/actors/carl.tscn                         Carl: Health, Hurtbox, Fists (MeleeAttack), Camera2D
scenes/actors/donut.tscn                        Donut + NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack)
scenes/props/stairs.tscn                        Reusable level-exit trigger
scenes/levels/surface.tscn, floor_01.tscn       The two levels
scripts/combat/health.gd                        class Health: hit points, damaged/died signals
scripts/combat/hurtbox.gd                       class Hurtbox: where an actor can be hit
scripts/combat/melee_attack.gd                  class MeleeAttack: cooldown-limited hit circle
scripts/levels/level.gd                         class Level: spawn placement, HUD wiring, restart on death
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/<actors|enemies|props|ui>/*.gd          One script per scene that needs one
tests/                                          Test scripts (not part of the game), see Tests
```

Every level scene uses this layout:
```
<LevelRoot> (Node2D, level.gd)   exports: carl, donut, hud
├── NavigationRegion2D   level_navigation.gd; NavigationPolygon outline = level bounds
│   └── Terrain          TileMapLayer with the shared TileSet
├── Signs                world-space Labels
├── Stairs / StairsUp    stairs.tscn instances (destination_scene_path, destination_spawn_point)
├── SpawnPoints          (optional) Marker2Ds that stairs from other levels can arrive at
├── Actors               Node2D with Y-sort on
│   ├── Carl             placed at the level's default spawn (also the restart point)
│   ├── Donut            follow_target = ../Carl
│   └── enemies          e.g. GelatinousBlob with target = ../Carl
└── HUD                  hud.tscn instance
```
**To add a floor:** duplicate `floor_01.tscn`, then:
1. Repaint Terrain.
2. Resize the NavigationPolygon outline.
3. Place Carl and Donut, and the enemies (set each enemy's `target` to Carl).
4. Add SpawnPoints for any stairs that arrive there.
5. Point the neighbouring levels' stairs at the new file.

## Autoloads
None. The arrival spawn point travels with the level itself: the Stairs
instantiate the destination scene, set its `arrival_spawn_point`, and hand it to
`change_scene_to_node()`. So no global state is needed yet.

`GameState` becomes necessary once something must survive a level change, such
as Carl's HP or inventory between floors, or the checkpoint state that "Restart
Floor" reloads. `SaveManager` is deferred until saving.

## Collision layers/masks
Names are set in Project Settings > Layer Names > 2D Physics.

| Layer | Name             | Used by                                    | Mask (collides with / detects)           |
|-------|------------------|--------------------------------------------|------------------------------------------|
| 1     | `world`          | Wall/barrier tiles (TileSet physics layer) | none (static)                            |
| 2     | `player`         | Carl's body                                | 1 `world`, 4 `enemy`                     |
| 3     | `companion`      | Donut's body                               | 1 `world` only                           |
| 4     | `enemy`          | Enemy bodies (Gelatinous Blob)             | 1 `world`, 2 `player`, 4 `enemy`         |
| 5     | `player_hurtbox` | Carl's Hurtbox (Area2D)                    | none; found by enemy attacks' shape query |
| 6     | `enemy_hurtbox`  | Enemy Hurtboxes (Area2D)                   | none; found by Carl's Fists' shape query  |
| —     | (none)           | Stairs (Area2D, `monitorable` off)         | 2 `player`: only Carl triggers them      |

Consequences:
- Carl and the blobs block each other.
- Donut collides only with walls, so she never blocks Carl or enemies, and
  enemies never block her.
- Attacks choose targets by hurtbox layer: Carl's Fists target layer 6 only, and
  the Blob's touch targets layer 5 only. So nobody can hit themselves, and Donut,
  who has no Hurtbox, can't be hit.
- Navigation baking reads only layer 1.

## Architectural decisions
Phase 0/1 decisions (still in force):
- Compatibility renderer.
- 1280×720 base size with `canvas_items` stretch and `expand` aspect.
- Physical-keycode bindings.
- Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.2.0`.
- `.godot/` ignored, `.uid` sidecar files committed, LF line endings.
- Title → Enter → Surface.
- Carl is a `CharacterBody2D` in floating mode; `get_vector()` caps diagonals;
  `move_and_slide()` keeps speed frame-rate independent.
- Camera2D inside Carl (zoom 1.5, smoothing, physics process).
- Physics interpolation on.
- TileMapLayer levels with one shared TileSet.
- Donut uses a navigation mesh baked when the level loads; her speed scales
  with distance (stops at 60 px, full speed at 100 px).
- Placeholder art is original and plain.

Phase 2 decisions:
- **Combat is three small reusable components**, not code inside each actor:
  - **`Health`** (Node): `max_health`, `current_health`, `take_damage()`, and
    the signals `damaged`, `health_changed` and `died` (emitted once). It
    refuses damage after death. All damage passes through `take_damage()`, so
    armor, resistances, invulnerability and healing can later be added there.
  - **`Hurtbox`** (Area2D): the area where an actor can be hit. It forwards hits
    to its `Health`.
  - **`MeleeAttack`** (Node2D): each use damages every hittable Hurtbox inside a
    circle `reach` pixels away in the attack direction. Exported values: damage,
    reach, radius, cooldown and target layers. Targets are found with an instant
    physics shape query, so there is no one-frame delay. The cooldown is counted
    in physics ticks, so it is exact. It draws a brief white circle as
    placeholder feedback and emits `performed(direction, hit_count)`.
  - Carl's Fists and the Blob's touch are both `MeleeAttack` nodes with
    different numbers.
- **Attack input = action slot W**, per GAME_SPEC §5/§7 (Carl starts with Fists
  in W). Carl's script calls `fists.attack(facing_direction)` while W is held.
  - This is the single place the future action-slot/item system replaces. An
    item Resource would supply the MeleeAttack's numbers, and slots W/A/S/D
    would map to items.
  - No item data classes were created yet: the rules say to add them when
    items arrive.
- **Fists:** 10 damage, reach 24 px, radius 18 px, cooldown 0.4 s. A blob is hit
  when its centre is within about 56 px straight ahead of Carl.
- **Gelatinous Blob** (GAME_SPEC §12, green placeholder per §17): straight-line
  pursuit, no navigation. That is enough in the open Floor 1 room, as the Phase 2
  prompt asked.
  - Numbers: 30 HP, speed 55, `detection_range` 220, `chase_range` 320 (it gives
    up beyond this), touch damage 10 every 0.8 s, `death_fade_time` 0.5 s.
  - Its `target` is an exported node reference wired in the level.
- **Carl death:** Carl only reacts visually and stops reading input. The
  **level** decides what happens next: `Level._on_carl_died()` restarts the
  level after `restart_delay` (2 s). A future game-over screen or checkpoint
  restore only changes that one function.
- **Level flow (`level.gd`):**
  - Places Carl and Donut at the arrival spawn point. `Carl.teleport_to()` also
    resets physics interpolation and camera smoothing, so the camera doesn't
    pan across the map.
  - Connects the HUD to Carl's Health.
  - Connects Carl's death to the restart.
  - It runs in the level's `_ready()`, after all its children are ready, so
    there are no ordering problems.
- **Stairs:** `destination_spawn_point` (a StringName) names a `SpawnPoints`
  Marker2D in the destination level. When it's empty, Carl keeps his position
  from the destination scene.
  - The stairs stay unarmed for the first 2 physics frames. Overlaps that exist
    at level start are ignored, so a spawn on top of stairs cannot bounce Carl
    back; he has to step off and on again.
  - Surface stairs → Floor 1, default spawn (480, 456).
  - Floor 1 up-stairs → Surface `FromFloor1` (1280, 704). Every arrival point is
    96 px from the nearest stairs.
- **HUD:** a `CanvasLayer`, so it is fixed on screen and unaffected by the
  camera. It uses anchors, so it stays inside the window at every supported
  size. Each level instances it, and the level calls `hud.show_health()`.
- **Carl's HP is not carried between levels.** Every level load, whether by
  stairs or by restart, creates a fresh Carl with 100 HP. Persisting HP needs
  `GameState`, which belongs with checkpoints and saving.

## Spec discrepancies (Phase 2 prompt vs. GAME_SPEC) and how they were resolved
1. **Attack key.** The prompt's fallback was a new `primary_attack` action on
   Left Mouse. GAME_SPEC assigns Fists to action slot **W**, and all its
   controls are keyboard. Result: W (`action_w`) attacks; no mouse input was added.
2. **Enemy identity.** The prompt suggested a generic prototype enemy.
   GAME_SPEC §12 names Floor 1's enemies. Result: **Gelatinous Blob**
   ("slow, tougher, contact/melee"). The Dungeon Rat is not implemented yet.
3. **Carl's max HP.** The prompt's example was "8 / 10"; GAME_SPEC §5 says 100.
   Result: 100.
4. **Death behaviour.** GAME_SPEC §5 says 0 HP causes "the game-over state", and
   §15 says Restart Floor reloads the state captured on entering the floor. The
   prompt asked for a temporary automatic restart at full health. Result: a
   GAME OVER message, then an automatic floor restart at full health. When
   checkpoints exist, the restart should reload the captured state instead.
5. **Donut damage.** GAME_SPEC §6 says Donut can take damage and is stunned at
   0 HP. The prompt said not to make her damageable in Phase 2 unless a spec
   assigned it to this phase, and none does. Result: Donut has no Hurtbox yet.

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process and fails a test on a
non-zero exit code or on any engine ERROR/WARNING in its output. Tests with
"windowed" in their name are started with a real window, which opens briefly.
The full run takes about 2 minutes.

| Test file                          | Covers |
|------------------------------------|--------|
| `test_input_map.gd` (Phase 0)      | Every action bound to its key; no key shared between actions |
| `test_carl_movement.gd` (Phase 1)  | Exact speed per arrow key, normalized diagonals, W/A/S/D don't move Carl, facing, tick-rate independence, `move_speed` |
| `test_surface_traversal.gd` (Phase 1) | Title → Enter → Surface, wall collision, Donut following on the navigation route, stairs → Floor 1, Floor 1 walls. Removes Floor 1's enemies before its wall checks (changed in Phase 2) |
| `test_combat.gd` (Phase 2)         | See the list below |
| `test_floor_loop.gd` (Phase 2)     | See the list below |
| `test_windowed_resolutions.gd` (Phase 2) | See the list below |

`test_combat.gd` checks:
- `Health` rules;
- W punches in the facing direction only (misses behind, hits diagonally);
- no self-damage;
- Donut doesn't block punches and can't be hit;
- A/S/D don't attack;
- punch cooldown exactly 24 ticks apart;
- Blob waits outside 220 px, chases at exactly 55 px/s, keeps chasing to
  320 px and gives up beyond;
- walls and Carl's body stop the Blob;
- touch damage exactly every 0.8 s;
- HUD updates, and Carl's hurt flash;
- the Blob dies after 3 punches, then stops acting, stops blocking, can't be
  hit or hurt Carl, and is removed;
- a downed Carl can't move or attack, and the HUD shows 0 HP and GAME OVER.

`test_floor_loop.gd` checks:
- from the title screen, Surface → Floor 1 → Surface twice, then down again;
- exact spawn positions for Carl and Donut;
- the camera starts centred on arrival (no pan);
- the HUD, and no transition loops;
- the blobs stay idle while Carl is far away;
- fighting and defeating a Blob;
- being defeated by the other Blob, a restart 2.0 s later, and full HP, blobs
  and HUD restored;
- arriving on top of stairs does not trigger them, but stepping off and on does.

`test_windowed_resolutions.gd` checks, at 1280×720, 640×360 and 1024×768:
- the visible area;
- the HP label on screen;
- the GAME OVER message on screen and centred;
- the camera centred on Carl.

It also checks that the camera follows Carl with a small lag and re-centres
when he stops. When started headless it prints SKIP and passes.

Each test file can also be run on its own. The first lines of each file give the
command.

## Validation performed (Phase 2)
All runs used Godot 4.7.2.stable.official on this machine (Intel UHD Graphics,
60 Hz monitor):
- **Import:** headless import with no errors or warnings.
- **Editor check:** all 8 scenes open in the headless editor with no errors or
  warnings.
- **Parse checks:** all 19 scripts pass `--check-only`. They are also clean with
  the 37 default-enabled GDScript warnings upgraded to errors (tested in a
  scratch copy).
- **Test suite:** `run_all.gd` was run 5 times.
  - 4 runs passed 6 of 6 test files, including the final two after clearing
    the `.godot/` cache.
  - 1 run failed only `test_windowed_resolutions.gd`, although all of its
    checks printed ok and it printed PASS (see Known issues).
  - `test_windowed_resolutions.gd` also passed 6 of 6 direct runs with exit
    code 0.
  - The Phase 1 traversal test gives the same Donut numbers as in Phase 1 (at
    most 106.6 px behind while walking, 60.0 px after stopping).
- **Mutation checks:** I injected 10 bugs into scratch copies. The tests caught
  every one:
  - Fists with no cooldown;
  - Fists ignoring facing;
  - Fists able to hit Carl's own layer;
  - Blob touch with no cooldown;
  - a dead Blob that keeps acting;
  - a downed Carl who keeps control;
  - a HUD that doesn't update;
  - stairs that don't wait before arming;
  - spawning without a camera reset (the camera ended up about 560 px off);
  - no restart after death.
- **Rendered playthrough:** the real main scene was played with real key events
  (Enter, W, arrows) at 1280×720, 640×360 and 1024×768. Sequence: title →
  Surface → Floor 1 → Blob engages → punches (flash visible, health bar drops,
  Blob flashes) → Blob fades out → second Blob hurts Carl (red flash, HUD drops)
  → GAME OVER → floor restarts at 100 HP → up-stairs → Surface beside the
  entrance. Screenshots were inspected at all three sizes.

## Known issues / limitations
- Enemies come back every time Floor 1 loads (by stairs or by restart). Nothing
  remembers defeated enemies yet.
- Carl's HP resets to 100 on every level load, so a trip up and down the stairs
  heals him fully. This ends when `GameState` or checkpoints arrive.
- The Blob chases in a straight line. If Carl hides directly behind a pillar, it
  slides along the pillar and may stall until Carl moves. This is fine for the
  open test room; a future navigation-based chase would fix it.
- A blob pressing against Carl can very slowly shove him (a few px per second)
  through Godot's normal overlap correction.
- There is no knockback and no invulnerability after a hit. Two blobs can each
  hurt Carl on their own timers.
- The game over restarts automatically. There is no game-over screen or
  "Restart Floor" choice yet.
- Placeholder feedback only: white punch circle, colour flashes, simple health
  bar. The GAME OVER text draws over the scene without a backdrop.
- Donut ignores enemies entirely (no combat, no damage) and walks through them.
- **Intermittent test-runner result:** in 1 of about 11 runs,
  `test_windowed_resolutions.gd` was reported as failed although every check
  passed and no error or warning was printed. So its process most likely
  returned a non-zero exit code while its window was closing. It could not be
  reproduced afterwards. `run_all.gd` now prints the exit code of any failing
  test, so a repeat will show the cause. If it happens, re-run that test on its
  own.
- Carried over: Escape and Space do nothing yet; there is no way back to the
  title screen (close the window). Godot's default `ui_accept` includes Space,
  which is the inventory key. Hand-written scenes gain `unique_id` fields the
  first time the editor saves them. Camera limits are not set.

## Manual verification required
1. Open the project in Godot 4.7.2. The Output panel should show no errors.
2. Press **F5**, then **Enter**. The Surface loads. "HP: 100 / 100" is at the
   top-left.
3. Check Phase 1 behaviour is unchanged:
   - Arrow keys move Carl, including diagonals.
   - W/A/S/D never move him.
   - Walls stop him.
   - Donut follows.
4. Take the stairs (bottom-right). Floor 1 loads with Carl above the up-stairs
   and two green blobs further up.
5. Walk up about three tiles. The top blob starts coming toward you.
6. Face it and **hold W**. A white circle flashes in front of Carl, and each hit
   makes the blob flash and shortens its health bar. After 3 hits it fades away.
7. Try punching with Carl facing away. Nothing is hit.
8. Walk into the other blob and stand still. Every 0.8 s Carl flashes and HP
   drops by 10.
9. At 0 HP: GAME OVER appears, Carl greys out and can't move. About 2 s later
   the floor restarts with HP 100 and both blobs back.
10. Walk down onto the up-stairs. You arrive on the Surface beside the dungeon
    entrance and stay there.
11. Go down and up again a few times. It should never bounce back and forth.
12. Resize the window. The HUD stays in the corner and readable.

## Next phase
Phase 3 is **not specified**: there is no `PHASE_03_*.md` file. Provide one,
with acceptance criteria, before starting. Phase 2 must be reviewed first.

Groundwork for later phases:
- **Items / inventory:** replace the hard-wired `fists.attack()` in `carl.gd`
  with slot → item lookups. Item Resources supply the `MeleeAttack` values.
- **New enemies** (Dungeon Rat, and so on): new scenes that reuse Health,
  Hurtbox and MeleeAttack, on layer 4 with a Hurtbox on layer 6.
- **Donut combat/damage:** give Donut a Hurtbox on a new `companion_hurtbox`
  layer, and add that layer to enemy attacks' `target_layers`.
- **Checkpoints/saving:** add `GameState`. Change `Level._on_carl_died()` and
  Carl's spawn setup to restore the state captured on entering the floor.
