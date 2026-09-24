# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 3 — Action Slots, Action Menu and Run State: **complete, awaiting human review**.
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There is no `PHASE_02_*.md` or `PHASE_03_*.md` file. Phases 2 and 3 came from the owner's
prompts. Phase 3's acceptance criteria are recorded in `ACCEPTANCE_TESTS.md`.

## Canonical design decisions (Phase 3 — do not reintroduce the old behaviour)
These override anything earlier phases said or built. `GAME_SPEC.md` was updated to match.
- **Movement is the arrow keys only.** W/A/S/D never move Carl.
- **W/A/S/D are configurable action slots.** A new game has **Fists in D** and W, A and S
  empty. The player changes what each slot holds in the in-game action menu (Space).
- **The keys themselves are fixed.** Rebinding physical keys is a separate, future
  settings concern.
- **Dungeon progression is downward only.** No level has stairs or triggers back up. The
  Phase 2 up-stairs and the Surface's `FromFloor1` arrival point were removed.
- **GAME OVER freezes the game and waits for Enter.** It never restarts on a timer. Enter
  retries the current floor from its floor-entry state.
- **Current-run state is separate from disk saves.** `GameState` holds the run in memory;
  saving to disk is a future `SaveManager`'s job.

## Implemented
- **Title screen** (main scene). Enter starts a **new game**: `GameState.start_new_run()`,
  then the Surface.
- **Carl** (`scenes/actors/carl.tscn`):
  - Arrow-key movement at 180 px/s, same speed on diagonals, wall collision, facing arrow,
    smoothed camera.
  - **Action slots (Phase 3).** Holding W, A, S or D uses whatever action that slot holds,
    in his facing direction. An empty slot does nothing.
  - Keys still held when the game unpauses (for example keys used in the menu) are ignored
    until released, so a menu key press never also acts in the game.
  - 100 HP, red hurt flash; at 0 HP he greys out and stops responding.
- **Fists** (Phase 3 form): an action defined by `resources/actions/fists.tres`, carried out
  by `scenes/actions/fists.tscn`. Same numbers as Phase 2 (10 damage, reach 24 px,
  radius 18 px, 0.4 s cooldown, hold to repeat).
- **Donut**: unchanged. She follows Carl on the navigation mesh, has no combat, cannot be
  hurt, never blocks Carl and has no part in the action slots. She freezes while the game
  is paused.
- **Gelatinous Blob**: unchanged from Phase 2 (30 HP, touch damage 10 every 0.8 s, chases
  within 220 px). Blobs freeze while the game is paused.
- **Surface**: outdoor area with the "Dungeon entrance" stairs down to Floor 1, the HUD and
  the action menu.
- **Floor 1**: stone room with four pillars, two Gelatinous Blobs, a sign, the HUD and the
  action menu. **No stairs**: the way back up was removed, and Floor 2 is a later phase.
- **Stairs** (`scenes/props/stairs.tscn`): stairs **down**. They load
  `destination_scene_path`, and Carl appears wherever that level places him. They ignore
  Carl for the first 2 physics frames of a level, so a spawn on top of stairs cannot skip a
  level.
- **HUD** (`scenes/ui/hud.tscn`):
  - top-left: "HP: x / 100";
  - below it, the slot bar, for example `W: —   A: —   S: —   D: Fists`, updated the moment
    an assignment changes;
  - a small "Space: action menu" hint;
  - the centred GAME OVER panel: "Carl is down. Press Enter to retry this floor."
- **Action menu** (`scenes/ui/action_menu.tscn`, Phase 3): opened and closed with Space.
  It shows the four slots, Carl's actions with the selection highlighted, the selected
  action's description or the last change, and a help line.
- **GameState autoload** (Phase 3): the current run's state (see Architecture).

Not implemented (later phases): items other than Fists, pickups, inventory quantities,
Donut combat/damage/stun, other enemy types, disk saving, pause menu, Floors 2–3, boss.

## Controls
| Action             | Key         | Effect                                                              |
|--------------------|-------------|---------------------------------------------------------------------|
| `move_up`          | Up Arrow    | Moves Carl north. In the menu: select the previous action           |
| `move_down`        | Down Arrow  | Moves Carl south. In the menu: select the next action               |
| `move_left`        | Left Arrow  | Moves Carl west                                                     |
| `move_right`       | Right Arrow | Moves Carl east                                                     |
| `action_w`         | W           | Uses slot W (empty in a new game). In the menu: put the selection on W |
| `action_a`         | A           | Uses slot A (empty in a new game). In the menu: put the selection on A |
| `action_s`         | S           | Uses slot S (empty in a new game). In the menu: put the selection on S |
| `action_d`         | D           | Uses slot D (**Fists** in a new game). In the menu: put the selection on D |
| `inventory_toggle` | Space       | Opens / closes the action menu (not over GAME OVER)                 |
| `ui_confirm_game`  | Enter       | Title: start a new game. GAME OVER: retry the floor                 |
| `pause_back`       | Escape      | Closes the action menu. No other effect yet                         |

Holding a slot key repeats its action as fast as the action's cooldown allows (Fists: every
0.4 s). No input actions were added in Phase 3. The tests check that W/A/S/D never move Carl
and that the arrow keys never trigger action slots.

## Scene structure
```
project.godot                                   Settings, InputMap, physics layer names, GameState autoload
assets/tiles/placeholder_world_tiles.png        Original 4-tile placeholder atlas
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet (wall tiles collide)
resources/actions/fists.tres                    ActionDefinition: Fists
scenes/actions/fists.tscn                       Fists' performer: a MeleeAttack with Fists' numbers
scenes/ui/title_screen.tscn                     Main scene; Enter -> new game -> Surface
scenes/ui/hud.tscn                              HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action menu (CanvasLayer 10)
scenes/actors/carl.tscn                         Carl: Health, Hurtbox, Camera2D (action performers added at run time)
scenes/actors/donut.tscn                        Donut + NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack)
scenes/props/stairs.tscn                        Reusable stairs down
scenes/levels/surface.tscn, floor_01.tscn       The two levels
scripts/autoload/game_state.gd                  GameState: the current run's state
scripts/actions/action_definition.gd            class ActionDefinition (Resource): one slot-able action
scripts/actions/action_performer.gd             class ActionPerformer (Node2D): base for what carries an action out
scripts/actions/action_slots.gd                 class ActionSlots: which action each W/A/S/D slot holds
scripts/combat/health.gd                        class Health: hit points, damaged/died signals
scripts/combat/hurtbox.gd                       class Hurtbox: where an actor can be hit
scripts/combat/melee_attack.gd                  class MeleeAttack (an ActionPerformer): cooldown-limited hit circle
scripts/levels/level.gd                         class Level: run-state wiring, GAME OVER, retry
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/<actors|enemies|props|ui>/*.gd          One script per scene that needs one
tests/                                          Test scripts (not part of the game), see Tests
```

Every level scene uses this layout:
```
<LevelRoot> (Node2D, level.gd)   exports: carl, hud, action_menu
├── NavigationRegion2D   level_navigation.gd; NavigationPolygon outline = level bounds
│   └── Terrain          TileMapLayer with the shared TileSet
├── Signs                world-space Labels
├── Stairs               (optional) stairs.tscn leading DOWN to the next level
├── Actors               Node2D with Y-sort on
│   ├── Carl             placed at the level's entry point (also where a retry starts)
│   ├── Donut            follow_target = ../Carl
│   └── enemies          e.g. GelatinousBlob with target = ../Carl
├── HUD                  hud.tscn instance
└── ActionMenu           action_menu.tscn instance
```
**To add a floor:** duplicate `floor_01.tscn`, then:
1. Repaint Terrain and resize the NavigationPolygon outline.
2. Place Carl (the entry point) and Donut, and the enemies (set each enemy's `target` to Carl).
3. Add stairs down to the next floor, if there is one.
4. Point the previous floor's stairs down at the new file. Never add stairs back up.

## Architecture

### Action slots
- **`ActionDefinition`** (Resource, one `.tres` per action in `resources/actions/`): `id`
  (stable, used to compare actions and later in save data), `display_name`, `description`,
  optional `icon`, `assignable`, and `performer_scene`.
- **`ActionPerformer`** (Node2D base class): the root of a `performer_scene`. Carl calls
  `perform(direction) -> bool` on it. Each performer keeps its own state, such as its cooldown.
- **`MeleeAttack` is an `ActionPerformer`.** Fists is simply a MeleeAttack scene with
  Fists' numbers. The Blob's ContactAttack is also a MeleeAttack, which it calls through
  `attack()` directly.
- **`ActionSlots`** (RefCounted): the single authority on which action is in which slot.
  - Slots are named after their InputMap actions (`action_w`, `action_a`, `action_s`, `action_d`).
  - `assign(action, slot)` puts an action in a slot and empties its old slot, since an
    action is in one slot at a time. It refuses actions whose `assignable` is false. An
    action that was already in the target slot loses its slot but stays available.
  - It emits `changed` after every real change.
- **Only `GameState.start_new_run()` knows the default layout** (Fists in D).
- **Carl** reads `action_slots` every physics tick. For each slot key held, he calls
  `perform(facing_direction)` on the performer of the action in that slot. He has no
  item-specific code. He creates a performer (as his child) the moment an action first
  enters one of his slots, and keeps it when the action moves. So moving Fists never resets
  its cooldown, and the first punch has the same exact 24-tick rhythm as later ones.
- **Adding a weapon or item** means adding a `.tres` (ActionDefinition) and a performer
  scene. A melee weapon is another MeleeAttack scene. A new kind (projectile, consumable)
  is a new ActionPerformer subclass. Carl's script does not change.

### Action menu
- Space opens it only while the game is not paused, so never over GAME OVER. Opening
  pauses the scene tree; closing (Space or Escape) unpauses it.
- The menu is a CanvasLayer with `process_mode` Always. It handles keys in
  `_unhandled_input` and marks every key event handled while open.
- Up/Down change the selection (holding repeats). W/A/S/D call
  `ActionSlots.assign(selected, slot)`.
- Its rows are plain Labels, which cannot take focus. Godot's built-in `ui_accept`
  (which includes Space and Enter) therefore cannot press anything. The tests check that
  nothing has focus.
- **No free actions.** When the game unpauses, Carl records which movement and slot keys
  are still held and ignores each until it is released
  (`NOTIFICATION_UNPAUSED` in `carl.gd`). A key used in the menu therefore never
  also moves Carl or triggers an action. Carl reads the arrow keys through the same filter,
  which is why `carl.gd` builds its movement vector itself instead of calling `Input.get_vector()`.

### Run state (`GameState` autoload, `scripts/autoload/game_state.gd`)
- It holds only what must survive level changes: `carl_health`, `carl_max_health`,
  `available_actions` (Carl's actions, in menu order), `action_slots`, and `floor_entry`.
- It contains no gameplay rules and does no disk I/O.
- `start_new_run()` resets everything (100/100 HP, `[Fists]`, Fists in D, no floor entry).
  It resets the array and the ActionSlots in place, so references to them stay valid.
- **Levels connect GameState to the game** (`Level._ready()`):
  - Carl's Health is set from GameState, and every HP change is written back through
    `store_carl_health()`;
  - Carl, the HUD and the menu get GameState's ActionSlots, and the menu gets
    `available_actions`.
  - Carl, the HUD and the menu never name `GameState` themselves. Test scripts compile
    before autoloads exist, so anything a test preloads must not name it. It also keeps
    those scenes usable on their own.
- Tests reach it with `root.get_node("GameState")` (helper `game_state()` in
  `tests/support/game_test.gd`).
- ARCHITECTURE_RULES allows `GameState` as an autoload. It is the only autoload.

### Floor-entry state and retry
- Every level calls `GameState.record_floor_entry(scene_file_path)` when it starts, after
  applying the run's HP to Carl. The snapshot (`GameState.FloorEntry`) holds the scene
  path, `carl_health` and `carl_max_health`.
- **GAME OVER** (`Level._on_carl_died()`) pauses the scene tree. Carl, Donut and the
  enemies stop; tweens and cooldowns stop with them.
- The HUD has `process_mode` Always. While its GAME OVER panel is visible, Enter emits
  `retry_requested`. The level then:
  1. calls `GameState.restore_floor_entry()`: HP goes back to the entry value, and the
     action slots stay as the player last set them;
  2. unpauses the game;
  3. loads the recorded scene again, which also resets its enemies.
- The reloaded level records the entry again with identical values, so retrying any
  number of times always returns to the same state.
- When pickups arrive, Carl's inventory must join `FloorEntry`, so a retry also undoes
  pickups (GAME_SPEC §15). A future SaveManager can serialize `GameState` plus
  `FloorEntry` without touching combat, the menu or level flow.

### Earlier decisions still in force
- Compatibility renderer; 1280×720 base with `canvas_items` stretch and `expand` aspect;
  physical-keycode bindings; Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.3.0`.
- `.godot/` ignored, `.uid` files committed, LF line endings.
- Carl is a floating-mode `CharacterBody2D`; `move_and_slide()` keeps speed frame-rate
  independent; Camera2D inside Carl (zoom 1.5, smoothing, physics process); physics
  interpolation on.
- Donut uses a navigation mesh baked when the level loads (stops at 60 px, full speed at
  100 px).
- Combat is three reusable components: `Health` (all damage through `take_damage()`,
  plus `set_health()` for carried-over HP), `Hurtbox`, and `MeleeAttack` (instant shape
  query, cooldown counted in physics ticks).
- Gelatinous Blob: straight-line pursuit; 30 HP, speed 55, detection 220, chase 320, touch
  damage 10 every 0.8 s.

## Collision layers/masks
Names are set in Project Settings > Layer Names > 2D Physics. Unchanged in Phase 3.

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
- Donut collides only with walls: she never blocks Carl or enemies, and they never block her.
- Carl's Fists target layer 6 only; the Blob's touch targets layer 5 only. Nobody hits
  themselves, and Donut, who has no Hurtbox, can't be hit.
- Navigation baking reads only layer 1.

## Phase 2 behaviour corrected in Phase 3
1. **Fists moved from W to D.** Phase 2 hard-wired `if W held: fists.attack()` in
   `carl.gd`. That line and Carl's `Fists` child node are gone; Fists now goes through the
   slot system.
2. **Up-stairs removed.** Floor 1's `StairsUp` and its sign, the Surface's
   `SpawnPoints/FromFloor1`, and the arrival-spawn-point code (`Stairs.destination_spawn_point`,
   `Level.arrival_spawn_point`, `Level.donut_spawn_offset`) existed only for the trip back
   up. They were removed, not hidden.
3. **No automatic restart.** Phase 2 restarted the level 2 s after Carl died, at full HP.
   Now GAME OVER stays until Enter, and the retry restores the floor-entry HP.
4. **HP carries between levels.** Phase 2 gave Carl 100 HP on every level load.
5. **Tests changed only where Phase 3 supersedes them.**
   - `test_combat.gd` uses D instead of W.
   - `test_floor_loop.gd` no longer climbs the up-stairs or waits for the automatic
     restart; it tests the retry instead. Its stairs-arrival check now uses the Surface's
     stairs down.
   - Separately, `test_surface_traversal.gd` and `test_floor_loop.gd` now wait for the
     title scene before pressing Enter. The old fixed 5-frame wait could lose the key on a
     busy machine.

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process. A test fails on a non-zero exit
code or on any engine ERROR/WARNING in its output. Tests with "windowed" in their name get a
real window, which opens briefly. The full run takes about 2.5 minutes. Each test file can
also be run on its own; the first lines of each file give the command.

| Test file                               | Covers |
|-----------------------------------------|--------|
| `test_input_map.gd` (Phase 0)           | Every action bound to its key; no key shared between actions |
| `test_carl_movement.gd` (Phase 1, 3)    | Exact speed per arrow key, normalized diagonals, facing, tick-rate independence, `move_speed`; W/A/S/D never move Carl, including D while it holds Fists |
| `test_surface_traversal.gd` (Phase 1)   | Title → Enter → Surface (waits until the title scene is current before pressing Enter), wall collision, Donut following on the navigation route, stairs → Floor 1, Floor 1 walls |
| `test_combat.gd` (Phase 2, 3)           | Health; Fists on D: facing direction, diagonals, no self-hit, Donut unaffected, W/A/S empty, exact 24-tick cooldown; Blob pursuit, walls, contact damage every 0.8 s, death; HUD HP; downed Carl |
| `test_action_slots.gd` (Phase 3)        | New-game layout; ActionSlots rules (one slot per action, id identity, non-assignable refused, `changed` only on real changes); Carl follows reassignment D→W→A→S live, old slots go quiet, facing respected, cooldown not reset by moving; a test-only second action works next to Fists with no Carl change; HUD slot bar updates |
| `test_action_menu.gd` (Phase 3)         | Space opens/pauses, Space/Escape close; rows and selection; nothing focused; Carl can't move/turn/attack and Donut stops while open; reassigning W/S/D through the menu updates GameState, menu and HUD, and the new slot punches in the game; no free punch/step from held keys across close, no stuck key across open; an adjacent blob can't hurt Carl or move while the menu is open, and hurts again after; menu can't open over GAME OVER |
| `test_floor_loop.gd` (Phase 2, 3)       | Title → new game resets the run; menu reassignment on the Surface; HP and slots carried to Floor 1; floor-entry recorded; no transition loop; nothing on Floor 1 leads up; W beats a blob; GAME OVER pauses and is still there 4 s later; Enter retries with entry HP (70, not 100), blobs restored, current slot layout kept; game works after retry; stairs ignore an arrival on top of them |
| `test_windowed_resolutions.gd` (Phase 2, 3) | At 1280×720, 640×360, 1024×768: visible area, HP label, slot bar (no overlap), GAME OVER panel centred (no overlap with slot bar), action menu centred and on screen, camera centred; camera follow lag and re-centre. Prints SKIP and passes when run headless |

## Validation performed (Phase 3)
All runs used Godot 4.7.2.stable.official on this machine (Intel UHD Graphics, 60 Hz):
- **Baseline before changes:** the Phase 2 suite passed 6 of 6.
- **Clean import:** a copy without `.godot/` was imported and opened in the headless editor
  with no errors or warnings. All 38 scripts/scenes/resources load, and all 10 scenes
  instantiate.
- **Parse checks:**
  - every script passes `--check-only`, except the two that name the autoload (see Known
    issues); those, and everything else, compile when loaded at runtime;
  - all scripts are also clean with the 37 default-enabled GDScript warnings upgraded to
    errors (tested in a scratch copy, where a planted unused variable was correctly
    rejected).
- **Test suite:** `run_all.gd` passed 8 of 8 on every run: 4 full runs. The first ran before the two
  test-robustness edits below; the other three ran on the final code, with no other
  process running.
- **Mutation checks:** 19 bugs were injected into throwaway copies. Every one made a
  relevant test fail for the intended reason:
  - Fists on W by default; D hard-wired to punch; an action in two slots; the menu not
    pausing; no held-key guard; the menu opening over GAME OVER; an automatic restart
    after 2 s; GAME OVER not freezing; a retry healing to full; up-stairs re-added (off the
    walked path, and at the Phase 2 spot); HP not carried between levels; a static HUD slot
    bar; a retry resetting the slots; no floor-entry record; a new performer on every
    reassignment (cooldown reset); the title not starting a new run; an empty slot
    punching; S moving Carl.
  - Two mutations first failed for an unrelated reason: a startup race in two end-to-end
    tests, which pressed Enter after a fixed 5 frames and so could press it before the
    title scene existed on a busy machine. Those tests now wait for the title scene. On
    rerun, both mutations were caught for the right reason.
- **Rendered playthrough** (real main scene, scripted key events through Godot's input
  pipeline, screenshots inspected):
  - title → Surface (HUD `D: Fists`) → D punches, W/A/S do nothing;
  - Space → menu → W → HUD `W: Fists` → W punches, D doesn't;
  - stairs → Floor 1 with the layout kept;
  - menu opened while a blob chased: no damage, no movement for 2 s;
  - a blob beaten with W; defeat → GAME OVER still up 4 s later → Enter → Floor 1 retried
    at entry HP, and Carl moves again.
  - HUD, menu and GAME OVER were also checked at 640×360 and 1024×768.
- **Normal entry point with real Windows keyboard input** (`godot --path .` on a scratch
  copy with a logging-only autoload; OS key events via `keybd_event`, including real key
  repeat):
  - D held: 5 punches exactly 24 ticks apart; W/A/S held: nothing, no movement;
  - W pressed in the menu and held through closing it, with 32 repeat events: **no** punch;
    a fresh W tap then punched once;
  - D after the move: nothing; Escape closed the menu;
  - Down held through closing the menu, with 17 repeat events: Carl did not move;
  - no errors or warnings in the output.

## Known issues / limitations
- Fists is the only action, so the menu lists one action. The architecture is ready for
  more; none were invented (GAME_SPEC §9 items belong to later phases).
- `ActionDefinition.icon` exists, but the placeholder UI shows names only; no icons are
  drawn yet.
- Moving an action onto an occupied slot unassigns the action that was there (no swap).
  It stays in Carl's action list and can be assigned again.
- Carl ignores a key that was held through an unpause until it is released. A key held
  when the menu closes therefore needs a fresh press. This is intended.
- The floor-entry state covers HP only, which is everything that changes during a floor
  today. The inventory must join it when pickups exist.
- The action menu uses Up/Down + W/A/S/D. GAME_SPEC §8's "Equip" submenu with
  Enter/Left/Right is for a later inventory phase.
- Defeated enemies come back when a floor is retried. This is intended: the floor starts over.
- Carried over from Phase 2:
  - The Blob chases in a straight line and can stall behind a pillar.
  - A blob pressing on Carl can shove him very slowly.
  - There is no knockback and no invulnerability after a hit.
  - Donut ignores enemies.
  - Feedback is placeholder only.
  - Escape does nothing outside the menu, and there is no way back to the title screen
    (close the window).
  - Camera limits are not set.
  - Hand-written scenes gain `unique_id` fields the first time the editor saves them.
- Godot's check `--check-only -s <script>` reports "Identifier not found: GameState" for
  `level.gd` and `title_screen.gd`. This is a limitation of that check mode: it compiles
  the script before autoloads are registered. Those scripts compile fine in the game and
  the tests (see Validation).

## Manual verification required
1. Open the project in Godot 4.7.2. The Output panel should show no errors.
2. Press **F5**, then **Enter**. On the Surface, the top-left shows "HP: 100 / 100" and
   `W: —   A: —   S: —   D: Fists`.
3. Arrow keys move Carl. W/A/S/D never move him. **D** punches (white circle in the facing
   direction); **W, A, S** do nothing.
4. Press **Space**: the game pauses and the menu shows D = Fists. Press **W**: the menu and
   the HUD show Fists on W. Press **Space** to close.
5. **W** now punches; **D** does nothing. Reopen the menu and try other slots; Escape also
   closes it.
6. Take the stairs (bottom-right). On Floor 1 the HUD still shows your layout. There are no
   stairs back up.
7. Walk up until a blob approaches, then press **Space**: the blob and Donut freeze and
   Carl takes no damage. Close the menu and punch the blob with your slot key.
8. Let the other blob defeat Carl. GAME OVER stays on screen, and nothing moves. Wait more
   than 2 seconds: it does not restart. Space does not open the menu.
9. Press **Enter**: Floor 1 restarts with the HP Carl had when he entered it, both blobs
   back, and your current slot layout.
10. Resize the window. The HUD, the menu and GAME OVER stay readable and on screen.

## Next phase
Phase 4 is **not specified** here. Provide its prompt or `PHASE_04_*.md`, with acceptance
criteria, after Phase 3 is reviewed.

Groundwork for later phases:
- **Items/pickups:** new ActionDefinition `.tres` files plus performer scenes. Add picked-up
  actions to `GameState.available_actions`, and add the inventory to `FloorEntry`.
- **Consumables with quantities:** add a quantity to the run state (not to the shared
  Resource), and have the performer report use.
- **Saving:** a `SaveManager` autoload serializes `GameState` (HP, action ids, slot ids,
  floor path) at floor transitions.
- **New floors:** duplicate `floor_01.tscn`; stairs only ever lead down.
