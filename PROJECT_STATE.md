# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 4 — Inventory, World Loot, Consumable Action and Floor 2: **complete, awaiting human review**.
- Phase 3 — Action Slots, Action Menu and Run State: complete (commit `a7ef551`).
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There are no `PHASE_02_*.md` to `PHASE_04_*.md` files. Phases 2–4 came from the owner's
prompts. Their acceptance criteria are recorded in `ACCEPTANCE_TESTS.md`.

## Canonical design decisions (do not reintroduce the old behaviour)
Phase 3 decisions, still in force:
- **Movement is the arrow keys only.** W/A/S/D never move Carl.
- **W/A/S/D are configurable action slots.** A new game has **Fists in D** and W, A and S
  empty. The player changes what each slot holds in the in-game action menu (Space).
- **The keys themselves are fixed.** Rebinding physical keys is a separate, future
  settings concern.
- **Dungeon progression is downward only.** No level has stairs or triggers back up.
- **GAME OVER freezes the game and waits for Enter.** It never restarts on a timer. Enter
  retries the current floor from its floor-entry state.
- **Current-run state is separate from disk saves.** `GameState` holds the run in memory.
  There is still **no disk saving**; that is a future `SaveManager`'s job.

Phase 4 decisions (also written into `GAME_SPEC.md` §7, §8, §9 and §15):
- **One real inventory for the run.** Fists are innate: always there, no quantity, never
  used up. Carried items have quantities, and an item at 0 leaves the inventory.
- **Small Health Potion:** heals **30 HP**, capped at the maximum. Each use that heals
  spends exactly one; at full HP it does nothing and spends nothing. It has a 1 s cooldown,
  so one key press never drinks two.
- **Pickups are collected by walking over them.** There is no interaction key. Donut and
  enemies never collect. Floor 1's pickup grants **2** potions.
- **A slot only holds what Carl has.** One slot per item. When the last potion is used,
  its slot empties; a new potion must be assigned again.
- **Inventory survives going down a level** and is part of the floor-entry state. A retry
  takes back items picked up since entry (their pickups return) and returns items used
  since entry. Retries never duplicate items.

## Implemented
- **Title screen** (main scene). Enter starts a **new game** (`GameState.start_new_run()`:
  100 HP, no items, Fists on D), then the Surface.
- **Carl** (`scenes/actors/carl.tscn`):
  - Arrow-key movement at 180 px/s, wall collision, facing arrow, smoothed camera.
  - **Action slots:** holding W/A/S/D uses the slot's action toward his facing direction.
    An empty slot does nothing.
  - **Consumables (Phase 4):** a consumable is used only if Carl has one. A use that
    really happened spends one from his inventory.
  - **Pickups (Phase 4):** `collect_item()` adds what a pickup gives to his inventory.
  - Keys held through an unpause are ignored until released.
  - 100 HP, red hurt flash; at 0 HP he greys out and stops responding.
- **Fists:** `resources/actions/fists.tres` + `scenes/actions/fists.tscn` (a MeleeAttack:
  10 damage, reach 24 px, radius 18 px, 0.4 s cooldown, hold to repeat).
- **Small Health Potion (Phase 4):** `resources/actions/small_health_potion.tres`
  (consumable, short name "Potion") + `scenes/actions/small_health_potion.tscn`
  (a `HealAction`: 30 HP, 1 s cooldown, a brief green ring as feedback).
- **Item pickup (Phase 4):** `scenes/props/item_pickup.tscn`, a reusable Area2D. It shows a
  bobbing pink diamond and a label such as "Potion x2".
- **Donut:** unchanged. She follows Carl on the navigation mesh, has no combat, cannot be
  hurt, and never collects pickups or uses the inventory. She freezes while the game is paused.
- **Gelatinous Blob:** unchanged (30 HP, touch damage 10 every 0.8 s, chases within 220 px).
- **Surface:** stairs down to Floor 1, the HUD and the action menu.
- **Floor 1:**
  - stone room with four pillars and two Gelatinous Blobs;
  - **Phase 4:** a Small Health Potion pickup (x2) at (128, 320);
  - **Phase 4:** stairs **down to Floor 2** at the far (top-left) end, labelled
    "Down to Floor 2". It has no stairs back up.
- **Floor 2 (Phase 4, `scenes/levels/floor_02.tscn`):**
  - a 36×18-tile level: a west room where Carl and Donut arrive, a wall with a 4-tile
    doorway, and an east room with two machinery blocks and one Gelatinous Blob (a reused
    type, so Floor 2 can be lost and retried);
  - the signs "Floor 2 - Utility Level" and "Prototype: the way further down is not built
    yet.";
  - HUD and menu. It has **no stairs at all**: no way back up, and Floor 3 is not in scope.
- **Stairs** (`scenes/props/stairs.tscn`): stairs **down**. They load `destination_scene_path`
  and ignore Carl for the first 2 physics frames of a level (no transition loops).
- **HUD** (`scenes/ui/hud.tscn`):
  - top-left: "HP: x / 100";
  - below it, the slot bar with quantities, for example `W: —   A: Potion x2   S: —   D: Fists`;
  - a "Space: action menu" hint;
  - the centred GAME OVER panel.
- **Action menu** (`scenes/ui/action_menu.tscn`): lists the four slots and Carl's inventory
  with quantities (for example "Small Health Potion x2   (on A)"), with a description or
  confirmation line and a help line.
- **GameState autoload:** HP, inventory, slots and the floor-entry state (see Architecture).

Not implemented (later phases): disk saving, Floor 3, other items, other enemy types,
Donut combat/damage/stun, shops/economy, equipment stats, pause menu.

## Controls
| Action             | Key         | Effect                                                              |
|--------------------|-------------|---------------------------------------------------------------------|
| `move_up`          | Up Arrow    | Moves Carl north. In the menu: select the previous item             |
| `move_down`        | Down Arrow  | Moves Carl south. In the menu: select the next item                 |
| `move_left`        | Left Arrow  | Moves Carl west                                                     |
| `move_right`       | Right Arrow | Moves Carl east                                                     |
| `action_w`         | W           | Uses slot W (empty in a new game). In the menu: put the selection on W |
| `action_a`         | A           | Uses slot A (empty in a new game). In the menu: put the selection on A |
| `action_s`         | S           | Uses slot S (empty in a new game). In the menu: put the selection on S |
| `action_d`         | D           | Uses slot D (**Fists** in a new game). In the menu: put the selection on D |
| `inventory_toggle` | Space       | Opens / closes the action menu (not over GAME OVER)                 |
| `ui_confirm_game`  | Enter       | Title: start a new game. GAME OVER: retry the floor                 |
| `pause_back`       | Escape      | Closes the action menu. No other effect yet                         |

Holding a slot key repeats its action as fast as the action's cooldown allows (Fists every
0.4 s, a potion every 1 s while it can heal). Pickups need no key. No input actions were
added in Phases 3–4.

## Scene structure
```
project.godot                                   Settings, InputMap, physics layer names, GameState autoload
assets/tiles/placeholder_world_tiles.png        Original 4-tile placeholder atlas
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet (wall tiles collide)
resources/actions/fists.tres                    ActionDefinition: Fists (innate)
resources/actions/small_health_potion.tres      ActionDefinition: Small Health Potion (consumable)
scenes/actions/fists.tscn                       Fists' performer: a MeleeAttack
scenes/actions/small_health_potion.tscn         The potion's performer: a HealAction (30 HP)
scenes/ui/title_screen.tscn                     Main scene; Enter -> new game -> Surface
scenes/ui/hud.tscn                              HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action/inventory menu (CanvasLayer 10)
scenes/actors/carl.tscn                         Carl: Health, Hurtbox, Camera2D (performers added at run time)
scenes/actors/donut.tscn                        Donut + NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack)
scenes/props/stairs.tscn                        Reusable stairs down
scenes/props/item_pickup.tscn                   Reusable world pickup (item + quantity)
scenes/levels/surface.tscn, floor_01.tscn, floor_02.tscn   The three levels
scripts/autoload/game_state.gd                  GameState: the current run's state
scripts/actions/action_definition.gd            class ActionDefinition (Resource): one slot-able action or item
scripts/actions/action_performer.gd             class ActionPerformer (Node2D): base for what carries an action out
scripts/actions/action_slots.gd                 class ActionSlots: which action each W/A/S/D slot holds
scripts/actions/inventory.gd                    class Inventory: innate actions + carried item quantities
scripts/actions/heal_action.gd                  class HealAction (an ActionPerformer): heals the user
scripts/combat/health.gd                        class Health: hit points, take_damage(), heal(), set_health()
scripts/combat/hurtbox.gd                       class Hurtbox: where an actor can be hit
scripts/combat/melee_attack.gd                  class MeleeAttack (an ActionPerformer): cooldown-limited hit circle
scripts/levels/level.gd                         class Level: run-state wiring, GAME OVER, retry
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/props/item_pickup.gd                    Walk-over pickup: gives its item to Carl once
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
├── Pickups              (optional) item_pickup.tscn instances (item + quantity)
├── Actors               Node2D with Y-sort on
│   ├── Carl             placed at the level's entry point (also where a retry starts)
│   ├── Donut            follow_target = ../Carl
│   └── enemies          e.g. GelatinousBlob with target = ../Carl
├── HUD                  hud.tscn instance
└── ActionMenu           action_menu.tscn instance
```
**To add a floor:** duplicate `floor_02.tscn` (or `floor_01.tscn`), then:
1. Repaint Terrain and resize the NavigationPolygon outline.
2. Place Carl (the entry point) and Donut, and the enemies (set each enemy's `target` to Carl).
3. Add pickups and stairs down, if any.
4. Point the previous floor's stairs down at the new file. Never add stairs back up.

**To add an item:**
1. Write an ActionDefinition `.tres`: id, names, `consumable`, `performer_scene`.
2. Give it a performer scene: an existing ActionPerformer (MeleeAttack, HealAction) with
   new numbers, or a new ActionPerformer subclass for a new kind of behaviour.
3. Place `item_pickup.tscn` instances with `item` and `quantity` set.

Carl's script does not change.

## Architecture

### Actions and items
- **`ActionDefinition`** (Resource): `id` (stable; used to compare actions and later in
  save data), `display_name`, `short_name` (HUD/pickup label, falls back to the display
  name), `description`, optional `icon`, `assignable`, `consumable`, `performer_scene`.
- **`ActionPerformer`** (Node2D base): the root of a `performer_scene`. It has
  `perform(direction) -> bool`, which returns true only if the action really happened, and
  a `user` (Carl), which Carl sets before adding it. Each performer keeps its own state,
  such as its cooldown.
  - **`MeleeAttack`** is one: Fists. The Blob's ContactAttack calls `attack()` directly.
  - **`HealAction`** is one: the potion. It calls `heal()` on the user's `Health` child.
    It returns false (so no potion is spent) when nothing was healed or it is cooling down.
- **Carl's generic dispatch** (`_use_slot`):
  1. slot → action;
  2. a consumable with 0 left does nothing;
  3. `performer.perform(facing)`;
  4. if that returned true and the action is consumable, `inventory.remove(action, 1)`.

  There is no item-specific code in Carl.

### Inventory (`Inventory`, RefCounted)
- The single place quantities are stored. GameState owns the run's one Inventory.
- `reset(innate)`: new run.
- `add(item, n)`: pickups.
- `remove(item, n) -> bool`: fails, removing nothing, if Carl has fewer.
- `get_quantity()`, `has()` (innate, or quantity > 0), `is_innate()`.
- `get_actions()`: innate first, then carried items in the order found.
- `get_label(action, short)`: "Small Health Potion x2", "Potion x2", "Fists".
- `get_snapshot()` / `restore_snapshot()`: a copy of the carried items. Restoring
  *replaces* the carried items, so it can never add to them.
- It emits `changed` on every change. An item whose quantity reaches 0 is removed.

### Action slots (`ActionSlots`, RefCounted)
- Created with the Inventory it belongs to (`ActionSlots.new(inventory)`).
- `assign(action, slot)`:
  - accepts only assignable actions **that Carl has**;
  - an action is in at most one slot, so assigning moves it;
  - a replaced action loses its slot but stays in the inventory.
- It listens to `inventory.changed` and **empties any slot whose action Carl no longer
  has**. This single rule handles both the last potion being used and a retry taking an
  item back.
- `get_display_name(slot, short)` includes quantities (via `Inventory.get_label`).
- **Only `GameState.start_new_run()` knows the default layout** (Fists in D).

### World pickups (`item_pickup.tscn`)
- Exports `item` (an ActionDefinition) and `quantity`. Placing loot is data only.
- An Area2D with collision layer none and mask 2 `player`: only Carl's body is detected.
  Donut (layer 3) and enemies (layer 4) are never reported.
- On touch it calls `collect_item(item, quantity)` on the body (only Carl has that method),
  sets a `_collected` flag, stops monitoring and frees itself. Two bodies touching it in the
  same physics step cannot both collect.
- Nothing records collected pickups. A retry reloads the level (pickups back) and restores
  the inventory (items back to the entry amounts), so the two always agree.

### Action menu
- Space opens it only while the game is not paused (never over GAME OVER). It pauses the
  scene tree; Space or Escape closes it.
- It lists `Inventory.get_actions()` with labels and each action's slot. Up/Down select;
  W/A/S/D assign. It refreshes on inventory and slot changes, and keeps the selection in
  range when the list shrinks.
- Its rows are Labels, which never take focus, so Godot's `ui_accept` (Space/Enter) cannot
  press anything.
- **No free actions:** keys held when the game unpauses are ignored by Carl until
  released (`NOTIFICATION_UNPAUSED` in `carl.gd`).

### Run state (`GameState` autoload)
- It holds only what must survive level changes: `carl_health`, `carl_max_health`,
  `inventory`, `action_slots`, `floor_entry`. It has no gameplay rules and does no disk I/O.
- `start_new_run()` resets everything in place, so references stay valid: 100/100 HP,
  inventory = Fists only, Fists on D, no floor entry.
- **Levels connect GameState to the game** (`Level._ready()`):
  - Carl gets the HP, `inventory` and `action_slots`, and HP changes are written back;
  - the HUD gets the slots and the inventory;
  - the menu gets the inventory and the slots.

  Carl, the HUD, the menu and pickups never name `GameState` themselves. Test scripts
  compile before autoloads exist, so anything a test preloads must not name it.
- Tests reach it with `root.get_node("GameState")` (helper `game_state()`). It is the only
  autoload; ARCHITECTURE_RULES allows it.

### Floor-entry state and retry
- Every level calls `GameState.record_floor_entry(scene_file_path)` when it starts. The
  snapshot (`GameState.FloorEntry`) holds the scene path, HP, max HP and
  `inventory.get_snapshot()`.
- **GAME OVER** (`Level._on_carl_died()`) pauses the scene tree.
- Enter on the GAME OVER panel makes the level:
  1. call `GameState.restore_floor_entry()`, which restores HP and replaces the carried
     items with the entry snapshot (ActionSlots then empties any slot holding something
     Carl no longer has);
  2. unpause;
  3. reload the recorded scene, which brings back its enemies and pickups.
- The reloaded level records the same entry again, so any number of retries returns to
  the same state and never duplicates items.
- Slot preferences otherwise stay as the player last set them. A potion slot emptied
  because the last potion was used stays empty after a retry that returns the potion; the
  player assigns it again (the menu lists it).

### Earlier decisions still in force
- Compatibility renderer; 1280×720 base with `canvas_items` stretch and `expand` aspect;
  physical-keycode bindings; Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.4.0`.
- `.godot/` ignored, `.uid` files committed, LF line endings.
- Carl is a floating-mode `CharacterBody2D`; Camera2D inside Carl (zoom 1.5, smoothing);
  physics interpolation on.
- Donut uses a navigation mesh baked when the level loads.
- Combat is three reusable components:
  - `Health`: all damage through `take_damage()`, all healing through `heal()`, and
    `set_health()` for carried-over HP;
  - `Hurtbox`;
  - `MeleeAttack`.
- Gelatinous Blob: straight-line pursuit; 30 HP, speed 55, detection 220, chase 320,
  touch damage 10 every 0.8 s.

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
| —     | (none)           | Item pickups (Area2D, `monitorable` off, Phase 4) | 2 `player`: only Carl collects them |

Consequences:
- Carl and the blobs block each other.
- Donut collides only with walls, and she can neither trigger stairs nor collect pickups.
- Carl's Fists target layer 6 only; the Blob's touch targets layer 5 only.
- Navigation baking reads only layer 1.

## Earlier behaviour changed in Phase 4
1. **`GameState.available_actions` (Phase 3) was replaced by `GameState.inventory`.**
   `ActionSlots.new()` now takes the inventory, and the HUD's and menu's setup calls take it
   too. `test_action_slots.gd` was updated only where it used the old API. It now adds its
   test-only actions to an inventory first, because Phase 4 requires slots to hold only
   owned actions, and its display-name check expects " x1" after a carried item.
2. **Slots refuse actions Carl does not have**, and empty themselves when an action leaves
   the inventory (new Phase 4 rule).
3. **Floor 1 gained stairs down** (to Floor 2) and a pickup. Neither is on a path the
   earlier tests walk, and `test_floor_loop.gd`'s "nothing leads back up" check now also
   sees the new, allowed destination (`floor_02.tscn`).
4. **The menu panel is wider** (760 px) and its right column is headed "CARL'S INVENTORY",
   to fit "Small Health Potion x2   (on A)".

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process. A test fails on a non-zero exit
code or on any engine ERROR/WARNING in its output. Tests with "windowed" in their name get a
real window, which opens briefly. The full run takes about 3 minutes. Each test file can
also be run on its own; the first lines of each file give the command.

| Test file                               | Covers |
|-----------------------------------------|--------|
| `test_input_map.gd` (Phase 0)           | Every action bound to its key; no key shared between actions |
| `test_carl_movement.gd` (Phase 1, 3)    | Exact speed per arrow key, normalized diagonals, facing, tick-rate independence; W/A/S/D never move Carl, including D while it holds Fists |
| `test_surface_traversal.gd` (Phase 1)   | Title → Surface, wall collision, Donut following, stairs → Floor 1, Floor 1 walls |
| `test_combat.gd` (Phase 2, 3)           | Health; Fists on D: facing, diagonals, no self-hit, Donut unaffected, W/A/S empty, exact 24-tick cooldown; Blob pursuit, walls, contact damage, death; HUD HP; downed Carl |
| `test_action_slots.gd` (Phase 3, 4)     | New-game layout; ActionSlots rules; Carl follows reassignment D→W→A→S live; cooldown not reset by moving; a test-only second action works next to Fists; HUD slot bar |
| `test_action_menu.gd` (Phase 3)         | Space opens/pauses, Space/Escape close; nothing focused; Carl/Donut frozen while open; reassigning through the menu; no free punch/step across close; blob frozen while open; no menu over GAME OVER |
| `test_floor_loop.gd` (Phase 2, 3)       | Title → new game; reassignment; HP and slots carried to Floor 1; floor-entry recorded; no transition loop; nothing on Floor 1 leads up; real fight and defeat; GAME OVER waits; retry with entry HP; stairs ignore an arrival on top of them |
| `test_inventory.gd` (Phase 4)           | New run (0 potions, Fists innate on D); Inventory rules (quantities, labels, failing removes, snapshots replace rather than add); slots refuse unowned items, one slot per item, last potion empties its slot, snapshot restore sanitizes slots; potion through a slot: no use at full HP, 60→90 (−1), 90→100 capped (−1), HUD x2→x1→empty, empty slot safe, D still punches; one potion per short press, one per second when held; menu lists Fists only, then x2, x1, then removes the potion; pickup: exactly +2, disappears, no second collection, Donut and an enemy cannot take it, two collectors at once get 2 in total |
| `test_inventory_run.gd` (Phase 4)       | From the title: a new game clears a previous run's potions; Floor 1 entry records 0 potions; walking over the real pickup gives 2 and removes it; the menu shows x2, and Down + A assigns it; die → GAME OVER waits → retry: 0 potions, slot A emptied, pickup back; a second retry changes nothing; collect again (2, not 4); D punches, full HP uses none, 60→90 uses one; stairs → Floor 2: spawn, Donut, camera, HP 90 and potion x1 on A kept, entry records 1 potion, no exits at all on Floor 2, no loop; use the last potion (slot empties), die, retry: 90 HP and 1 potion; retry again: still 1 |
| `test_windowed_resolutions.gd` (Phase 2–4) | At 1280×720, 640×360, 1024×768, with a potion on A: visible area, HP label, slot bar (with "Potion x2"), GAME OVER panel, action menu centred and on screen, camera centred; camera follow. Prints SKIP and passes when run headless |

## Validation performed (Phase 4)
All runs used Godot 4.7.2.stable.official on this machine (Intel UHD Graphics, 60 Hz):
- **Baseline before changes:** the Phase 3 suite (HEAD `a7ef551`) passed 8 of 8.
- **Clean import:** a copy without `.godot/` was imported and opened in the headless editor
  with no errors or warnings. All 47 scripts/scenes/resources load, and all 13 scenes
  instantiate.
- **Parse checks:** all scripts are clean with the 37 default-enabled GDScript warnings
  upgraded to errors (scratch copy), both with `--check-only` and when loaded at runtime.
  The two autoload-naming scripts were loaded at runtime (see Known issues).
- **Test suite:** `run_all.gd` passed 10 of 10 on all 3 full runs. The last two ran on the final
  code with no other process running. `test_inventory_run.gd` also passed 3 of 3 separate
  runs after its navigation-route fix.
- **Mutation checks:** 16 bugs were injected into throwaway copies. Every one made a
  relevant test fail for the intended reason:
  - a pickup collected twice; a potion used at full HP; a potion lost on the stairs;
  - a retry adding to the inventory instead of restoring it; a retry keeping new items;
  - up-stairs on Floor 2 (to Floor 1) and on Floor 1 (to the Surface);
  - the last potion keeping its slot; a HUD whose quantity never updates;
  - healing above the maximum; two potions spent per use; no potion cooldown;
  - a 0-quantity item still listed; a new run keeping items; a pickup giving double;
  - a slot accepting an item Carl does not own.

  Three were first run against an early version of `test_inventory_run.gd`. It asked
  for a navigation route 3 frames after the Surface loaded, before the navigation map was
  ready on a slow first run, so they failed for an unrelated reason. The test now waits
  for a route. On rerun, all three were caught for the right reason.
- **Rendered playthrough** (real title screen, scripted key events through Godot's input
  pipeline, **real enemies** for damage and death, screenshots inspected):
  1. New game: 0 potions, `D: Fists`, and D punches. Surface → Floor 1: entry 0 potions.
  2. Walked over the pickup: potions 2, and the pickup was gone.
  3. The menu showed "Small Health Potion x2"; Down + A put it on A (`A: Potion x2`).
  4. D still punched, and A at full HP used nothing.
  5. The top blob hurt Carl to 70; D beat it (HP 60); A healed him to 90 with a green ring,
     and the HUD showed `Potion x1`.
  6. Stairs → Floor 2: HP 90, `A: Potion x1`, entry 1 potion, Donut 49 px from Carl, 0 stairs.
  7. The east-room blob attacked. Carl drank the last potion (60 → 90) and slot A emptied;
     then the blob killed him.
  8. GAME OVER was still up 3 s later. Enter restored 90 HP and 1 potion; dying and
     retrying again still gave 1 potion.
  9. The menu and HUD were also checked at 640×360 and 1024×768.
- **Normal entry point:** `godot --path .` ran the main scene with no errors or warnings.

## Known issues / limitations
- **Placeholders:**
  - the potion pickup is a pink diamond with a text label, and potion use shows a green
    ring;
  - there are no icons (`ActionDefinition.icon` is unused);
  - Floor 2 is a small two-room placeholder with one reused Gelatinous Blob and no exit.
- **Slot behaviour:**
  - a retry that returns a potion does not re-assign it if its slot was emptied when it
    ran out; the player assigns it again;
  - moving an action onto an occupied slot unassigns the action that was there (no swap).
- **Potion holding:** a held potion key drinks one potion per second while Carl is hurt.
  Each use still heals.
- **No disk saving yet.** Quitting the application ends the run.
- The action menu uses Up/Down + W/A/S/D. GAME_SPEC §8's "Equip" submenu with
  Enter/Left/Right is for a later inventory phase.
- Defeated enemies come back when a floor is retried. This is intended: the floor starts over.
- **Carried over from earlier phases:**
  - the Blob chases in a straight line and can stall behind walls (for example Floor 2's
    dividing wall);
  - there is no knockback and no invulnerability after a hit;
  - Donut ignores enemies;
  - Escape does nothing outside the menu;
  - there is no way back to the title screen;
  - camera limits are not set;
  - hand-written scenes gain `unique_id` fields the first time the editor saves them.
- Godot's `--check-only -s <script>` reports "Identifier not found: GameState" for
  `level.gd` and `title_screen.gd`, because it compiles the script before autoloads are
  registered. They compile fine in the game and the tests. By design, this is not worked
  around.

## Manual verification required
1. Open the project in Godot 4.7.2. The Output panel should show no errors.
2. Press **F5**, then **Enter**. The Surface HUD shows "HP: 100 / 100" and
   `W: —   A: —   S: —   D: Fists`. D punches; W/A/S do nothing and never move Carl.
3. Take the stairs (bottom-right) to Floor 1. A pink diamond labelled "Potion x2" sits on
   the left; the stairs "Down to Floor 2" are top-left. There are no stairs back up.
4. Open the menu (**Space**): only Fists is listed. Close it, walk over the diamond: it
   disappears. Open the menu: "Small Health Potion x2". Press **Down**, then **A**, then
   **Space**. The HUD shows `A: Potion x2 ... D: Fists`.
5. Press **A** at full HP: nothing is used. Let a blob hurt Carl, then press **A**: +30 HP
   (or up to 100) and `Potion x1`.
6. Take the stairs down. Floor 2 ("Floor 2 - Utility Level"): Donut arrives with Carl, and
   the HUD still shows `A: Potion x1`. There are no stairs on Floor 2.
7. Walk through the doorway to the east room and let the blob win. GAME OVER stays until
   **Enter**. After Enter, HP and potions are what Carl had on arriving at Floor 2.
8. Retry a few times. The potion count never grows.
9. On Floor 1, pick up the potions and then die. After the retry you have 0 potions again,
   and the pickup is back.
10. Resize the window: the HUD, the menu and GAME OVER stay readable.

## Next phase
Phase 5 is **not specified** here. Provide its prompt, with acceptance criteria, after
Phase 4 is reviewed.

Groundwork for later phases:
- **More items:** a `.tres` plus a performer scene each (see "To add an item"). Consider
  moving the cooldown counter into `ActionPerformer` once a third performer type appears.
- **Saving:** a `SaveManager` autoload can serialize `GameState` at floor transitions:
  HP, the floor path, the inventory as `{id: quantity}` (definitions looked up by id) and
  the slot ids. That needs an id → ActionDefinition lookup, which does not exist yet.
- **Floor 3 / an exit from Floor 2:** add stairs down to Floor 2, pointing at the new scene.
