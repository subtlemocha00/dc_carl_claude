# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 5 — Persistent Save/Load and Continue: **complete, awaiting human review**.
- Phase 4 — Inventory, World Loot, Consumable Action and Floor 2: complete (commit `4ea1123`).
- Phase 3 — Action Slots, Action Menu and Run State: complete (commit `a7ef551`).
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There are no `PHASE_02_*.md` to `PHASE_05_*.md` files. Phases 2–5 came from the owner's
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
- **Current-run state is separate from disk saves.** `GameState` holds the run in memory;
  `SaveManager` (Phase 5) is the only code that reads or writes the save file.

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

Phase 5 decisions (also written into `GAME_SPEC.md` §4 and §15):
- **One persistent save slot**, holding one **floor-entry checkpoint**, the same one a
  GAME OVER retry uses. It is saved when a new game starts (Surface) and on entering each
  floor, and nowhere else: not damage, pickups, potions, slot changes or death.
- **Continue resumes at the start of the saved floor** with the checkpoint HP, inventory
  and slots. Nothing mid-floor is saved.
- **New Game asks first** (No selected) whenever a save file exists.
- **Invalid saves are never loaded:** Continue becomes unavailable with a message, and New
  Game still works. Invalid slot assignments in an otherwise valid save are emptied.
- **Retry gives back emptied checkpoint slots:** if the last potion ran out mid-floor, a
  retry returns the potion *and* its checkpoint slot. This fixes the Phase 4 known issue.
- No mid-floor saving, multiple save slots or cloud saves.

## Implemented
- **Title screen** (main scene, Phase 5 menu):
  - **Continue** (available only when the save loads) resumes the saved floor checkpoint;
    a line shows where, for example "Saved at the start of Floor 2 - HP 90 / 100".
  - **New Game** starts a clean run on the Surface (100 HP, no items, Fists on D). If a
    save file exists, it first asks "Start a new game? Existing progress will be
    replaced." with No selected.
  - An unloadable save shows "Save data could not be loaded." and leaves Continue
    unavailable.
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
- **SaveManager autoload (Phase 5):** the persistent checkpoint in `user://savegame.json`
  (see Architecture).

Not implemented (later phases): multiple save slots, mid-floor or cloud saving, Floor 3,
other items, other enemy types, Donut combat/damage/stun, shops/economy, equipment stats,
pause menu.

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
| `ui_confirm_game`  | Enter       | Title: confirm Continue / New Game / Yes / No. GAME OVER: retry the floor |
| `pause_back`       | Escape      | Closes the action menu; on the title confirmation, means No. No other effect yet |

Title screen: **Up/Down** choose Continue or New Game, **Enter** confirms. In the New Game
confirmation, Up/Down (or Left/Right) choose No or Yes, Enter confirms, and **Escape** means No.

Holding a slot key repeats its action as fast as the action's cooldown allows (Fists every
0.4 s, a potion every 1 s while it can heal). Pickups need no key. No input actions were
added in Phases 3–4.

## Scene structure
```
project.godot                                   Settings, InputMap, physics layer names, GameState + SaveManager autoloads
assets/tiles/placeholder_world_tiles.png        Original 4-tile placeholder atlas
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet (wall tiles collide)
resources/actions/fists.tres                    ActionDefinition: Fists (innate)
resources/actions/small_health_potion.tres      ActionDefinition: Small Health Potion (consumable)
scenes/actions/fists.tscn                       Fists' performer: a MeleeAttack
scenes/actions/small_health_potion.tscn         The potion's performer: a HealAction (30 HP)
scenes/ui/title_screen.tscn                     Main scene: Continue / New Game menu, overwrite confirmation
scenes/ui/hud.tscn                              HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action/inventory menu (CanvasLayer 10)
scenes/actors/carl.tscn                         Carl: Health, Hurtbox, Camera2D (performers added at run time)
scenes/actors/donut.tscn                        Donut + NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack)
scenes/props/stairs.tscn                        Reusable stairs down
scenes/props/item_pickup.tscn                   Reusable world pickup (item + quantity)
scenes/levels/surface.tscn, floor_01.tscn, floor_02.tscn   The three levels
scripts/autoload/game_state.gd                  GameState: the current run's state
scripts/autoload/save_manager.gd                SaveManager: the one save file (encode, validate, safe write, load, delete)
scripts/state/floor_entry.gd                    class FloorEntry: a floor checkpoint (HP, inventory snapshot, slot layout)
scripts/actions/action_registry.gd              class ActionRegistry: action id -> ActionDefinition (for loading saves)
scripts/levels/floor_registry.gd                class FloorRegistry: floor id -> scene and name (the only floors a save can open)
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
  `inventory`, `action_slots`, `floor_entry` (a `FloorEntry`). It has no gameplay rules and
  does **no disk I/O**.
- `INNATE_ACTIONS` (`[Fists]`) is the one list of innate actions.
- `start_new_run()` resets everything in place, so references stay valid: 100/100 HP,
  inventory = Fists only, Fists on D, no floor entry.
- `continue_from(checkpoint)` (Continue) starts a run with exactly the checkpoint's HP,
  inventory and slot layout.
- **Levels connect GameState to the game** (`Level._ready()`):
  - Carl gets the HP, `inventory` and `action_slots`, and HP changes are written back;
  - the HUD gets the slots and the inventory;
  - the menu gets the inventory and the slots.

  Carl, the HUD, the menu and pickups never name `GameState` themselves. Test scripts
  compile before autoloads exist, so anything a test preloads must not name it.
- Tests reach it with `root.get_node("GameState")` (helper `game_state()`).
- ARCHITECTURE_RULES allows exactly two autoloads, `GameState` and `SaveManager`, and those
  are the only two.

### Floor-entry state and retry
- Every level calls `GameState.record_floor_entry(scene_file_path)` when it starts, then
  `SaveManager.save_checkpoint(GameState.floor_entry)`. This single place in `Level._ready()`
  is where every checkpoint is written, for all current and future floors.
- The checkpoint (`FloorEntry`, `scripts/state/floor_entry.gd`) holds the scene path, HP,
  max HP, `inventory.get_snapshot()` and `action_slots.get_layout()`.
- **GAME OVER** (`Level._on_carl_died()`) pauses the scene tree. **Death never writes the
  save.**
- Enter on the GAME OVER panel makes the level:
  1. call `GameState.restore_floor_entry()`:
     - HP goes back;
     - the carried items are replaced by the entry snapshot, and ActionSlots empties any
       slot holding something Carl no longer has;
     - then `ActionSlots.fill_empty_slots(entry layout)` puts each checkpoint assignment
       back where its slot is empty and the action is in no other slot;
  2. unpause;
  3. reload the recorded scene, which brings back its enemies and pickups.
- The reloaded level records and saves the same entry again, so any number of retries
  returns to the same state, never duplicates items, and never changes the save's content.
- Slot rule on retry:
  - the player's latest layout is kept (Phase 3 rule);
  - an empty slot whose checkpoint action is back gets that action again. So "A = potion
    x1 at entry → drink it (A empties during play) → die → retry" gives back the potion
    **and** A = potion. This fixes the Phase 4 known issue.

### Persistent save (`SaveManager` autoload, `scripts/autoload/save_manager.gd`)
- **Location:** `user://savegame.json` (`DEFAULT_SAVE_PATH`), in Godot's per-user app data,
  never in the project folder. On Windows that is
  `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json`.
  `save_path` can be changed; tests always change it.
- **Format:** JSON, `save_version: 1` (`SAVE_VERSION`), stable ids only:
  ```
  {"save_version": 1, "floor_id": "floor_02", "carl": {"health": 90, "max_health": 100},
   "inventory": {"small_health_potion": 1},
   "action_slots": {"action_w": null, "action_a": "small_health_potion", "action_s": null, "action_d": "fists"}}
  ```
- **Persisted:** floor id, Carl's HP and max HP, carried item quantities, and the four slot
  assignments, all at floor entry.
- **Not persisted (on purpose):**
  - Carl's and Donut's positions;
  - enemies and their HP;
  - collected pickups;
  - cooldowns, animation and navigation;
  - the live menu state;
  - anything after floor entry.
- **API:**
  - `save_checkpoint(entry) -> bool`;
  - `load_checkpoint() -> FloorEntry` (null, with the reason in `last_error`);
  - `has_save_file()`;
  - `delete_save()`, safe when there is no file;
  - `encode(entry)` / `decode(data)`.
- **Safe writes:**
  1. The text is written to `savegame.json.tmp`, read back and compared.
  2. It is renamed over `savegame.json`. (Checked on this machine: renaming replaces an
     existing file.)
  3. A failure logs an error and leaves the old save as it was.

  If the game stopped between the write and the rename, the finished `.tmp` is loaded (and
  validated) instead.
- **Validation (untrusted input).** `decode()` rejects the whole save, without logging an
  engine error, if:
  - the file is not valid JSON, or its root is not a JSON object;
  - `save_version` is not 1 (`decode()` is where a later version would migrate old files);
  - `floor_id` is not in `FloorRegistry`. No path is ever read from the file;
  - HP is not a whole number with 1 ≤ health ≤ max_health ≤ 1000;
  - `inventory` is not an object, an id is not in `ActionRegistry` or is innate (Fists),
    or a quantity is not a whole number from 0 to 999;
  - `action_slots` is not exactly the four slot names, each with an id or null.

  It **sanitizes** slots instead of rejecting the save: an unknown action id, an action
  Carl would not have (for example a potion with quantity 0), or an action named twice
  leaves that slot empty. The game's own `ActionSlots.fill_empty_slots()` rules decide this.
- **Registries:** `FloorRegistry` (surface, floor_01, floor_02) and `ActionRegistry` (fists,
  small_health_potion) are the whitelists that turn saved ids back into scenes and
  resources. A new floor or item needs one line in each list.
- **Title flow:**
  - Continue calls `load_checkpoint()` again, then `GameState.continue_from()`, then loads
    the saved floor. That floor's `_ready()` records and saves the identical checkpoint.
  - New Game calls `GameState.start_new_run()` and loads the Surface. The Surface's
    checkpoint then replaces the old save through the safe write. The old save is not
    deleted first.
- **Test isolation:**
  - `tests/support/game_test.gd` points `save_path` at `user://test_saves/<test>.json`
    before anything runs, and deletes that file at the start and the end.
  - `test_surface_traversal.gd` does the same.
  - Tests never touch `savegame.json`. After the full suite, the real user folder still
    has no save file.

### Earlier decisions still in force
- Compatibility renderer; 1280×720 base with `canvas_items` stretch and `expand` aspect;
  physical-keycode bindings; Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.5.0`.
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

## Earlier behaviour changed in Phase 5
1. **Title screen.** Phase 4's title started a new game on any Enter. It is now a
   Continue / New Game menu. With no save file, New Game is selected and needs no
   confirmation, so a single Enter still starts a new game exactly as before. The older
   end-to-end tests therefore needed no changes.
2. **Retry restores emptied checkpoint slots** (the Phase 4 known issue). `test_inventory_run.gd`
   asserted the old behaviour (the restored potion showed "(no slot)"). That one
   expectation now says "(on A)", with a HUD check added.
3. **`GameState.FloorEntry` moved to its own class** (`FloorEntry`, `scripts/state/floor_entry.gd`)
   so SaveManager can use it. Its fields are unchanged, plus the new `action_slots`.
4. **Every level save writes a checkpoint.** Tests are therefore isolated to their own save
   files (`game_test.gd`, `test_surface_traversal.gd`).

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process. A test fails on a non-zero exit
code or on any engine ERROR/WARNING in its output. Tests with "windowed" in their name get a
real window, which opens briefly. The full run takes about 3.5 minutes. Each test file can
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
| `test_inventory_run.gd` (Phase 4, 5)    | From the title: a new game clears a previous run's potions; Floor 1 entry records 0 potions; walking over the real pickup gives 2 and removes it; the menu shows x2, and Down + A assigns it; die → GAME OVER waits → retry: 0 potions, slot A emptied, pickup back; a second retry changes nothing; collect again (2, not 4); D punches, full HP uses none, 60→90 uses one; stairs → Floor 2: spawn, Donut, camera, HP 90 and potion x1 on A kept, entry records 1 potion, no exits at all on Floor 2, no loop; use the last potion (slot empties), die, retry: 90 HP, 1 potion and **A = potion again** (Phase 5); retry again: still 1 |
| `test_save_manager.gd` (Phase 5)        | Registries map ids both ways; a Floor 2 checkpoint is written as JSON (save_version 1, floor id, HP, `{"small_health_potion": 1}`, four slots, no paths or objects), with no `.tmp` left, and loads back identical; a new save replaces the old one; 29 kinds of bad data rejected with a reason and the file left untouched (malformed/empty JSON, wrong root, versions 2/0/"1"/missing, missing fields, unknown floor or a scene path, HP string/0/over max/fractional, max 0, inventory not an object, negative/fractional/string quantity, unknown or innate item, slots missing/extra/list/number); slots sanitized (unknown action, potion with 0 left, one action in two slots); 90.0 accepted; delete with and without a file; an interrupted save's finished `.tmp` loads, a broken `.tmp` beside a good save is ignored |
| `test_save_game.gd` (Phase 5)           | Real title + levels: no save → Continue unavailable, New Game without confirmation, clean run, Surface checkpoint; damage doesn't save; Floor 1 checkpoint carries 80 HP; pickups, menu changes, damage and potions don't change it; title → Continue → Floor 1 entry values (80 HP, 0 potions, pickup and blobs back, Donut); Floor 2 checkpoint 60 HP + potion on A; last potion empties A; 3 deaths: GAME OVER waits, save unchanged, each retry gives 60 HP, 1 potion and A = potion; title → Continue straight to Floor 2 with the same state, blob and Donut; quit at GAME OVER then Continue restores the valid checkpoint; New Game over a save asks (No selected), No and Escape keep the save, Yes writes a clean Surface checkpoint; corrupt and version-99 saves: Continue unavailable, message, New Game asks and replaces them |
| `test_windowed_resolutions.gd` (Phase 2–5) | At 1280×720, 640×360, 1024×768, with a potion on A: visible area, HP label, slot bar (with "Potion x2"), GAME OVER panel, action menu centred and on screen, camera centred; camera follow. **Title screen:** menu rows, save line and version on screen with a save and with a broken save; the New Game confirmation centred and on screen; Escape closes it. Prints SKIP and passes when run headless |

Every test uses its own save file under `user://test_saves/` (see Persistent save).

## Validation performed (Phase 5)
All runs used Godot 4.7.2.stable.official on this machine (Intel UHD Graphics, 60 Hz):
- **Baseline before changes:** the Phase 4 suite (HEAD `4ea1123`) passed 10 of 10.
- **Clean import:** a copy without `.godot/` was imported and opened in the headless editor
  with no errors or warnings. All 53 scripts/scenes/resources load, and all 13 scenes
  instantiate.
- **Parse checks:** all scripts are clean with the 37 default-enabled GDScript warnings
  upgraded to errors (scratch copy), both with `--check-only` and when loaded at runtime.
  This pass found two mixed `String`/`null` ternaries, which were fixed.
- **Test suite:** `run_all.gd` passed 12 of 12 on all 3 full runs. The last two ran on the final
  code with no other process running.
- **The player's save was never touched:** after full test runs, the real user folder had
  no `savegame.json`, and `test_saves/` was empty.
- **Mutation checks:** 12 bugs were injected into throwaway copies. Every one made a
  relevant test fail for the intended reason:
  - saving HP after damage;
  - Continue adding to the inventory (duplicates);
  - an unknown floor accepted;
  - a negative quantity accepted;
  - any save version accepted;
  - death overwriting the save;
  - retry not restoring the checkpoint slot;
  - New Game without confirmation;
  - Continue offered for a corrupt save;
  - a write without the final rename;
  - Continue always opening the Surface;
  - loaded slots not sanitized.

  Two test weaknesses found this way were fixed:
  - a Surface check read the save *after* the damage it was meant to watch;
  - two checks called into the title screen after it had been freed.
- **Real process restart** (a scratch copy with its own user-data folder, so no real save
  was involved; a logging-only observer autoload added):
  1. *Process 1* (`godot --path … -s` driver, windowed): title (no save: Continue
     unavailable) → New Game (Surface checkpoint written) → Floor 1 (checkpoint 100 HP) →
     2 potions → a real Gelatinous Blob hurt Carl to 60, and D beat it → Space, Down, A,
     Space → A healed to 90 (x1) → Floor 2. The checkpoint on disk was `floor_02`, 90/100,
     `small_health_potion: 1`, `action_a: small_health_potion`, `action_d: fists`. The
     process then quit normally (exit code 0).
  2. *Process 2* (a fresh `godot --path …`, the normal entry point, no script; real Windows
     key events via `keybd_event`):
     - the title showed Continue selected and "Saved at the start of Floor 2 - HP 90 / 100";
     - Enter loaded **Floor 2 directly**: HP 90/100, potion x1, HUD `A: Potion x1 … D: Fists`,
       Carl at the spawn point, Donut 49 px away, the blob present;
     - holding Right moved Carl (160 → 343), and D punched;
     - no errors.
- **Corrupt save, by hand** (same isolated copy): the save was replaced with truncated
  JSON, then the game was launched normally.
  - The title appeared with Continue unavailable and "Save data could not be loaded.".
  - Real keys Enter → Down → Enter answered the confirmation with Yes.
  - The game started on the Surface, and the save was then a valid Surface checkpoint.
    No crash, no errors.
- **Visual check** (screenshots inspected) of the title at 1280×720, 640×360 and 1024×768:
  no save, a valid save, a corrupt save, and the New Game confirmation in both wordings.
  The first confirmation let the menu show through. It now has an opaque panel over a
  dimmed screen.

## Known issues / limitations
- **Save system scope (by design):**
  - one slot only;
  - saves happen only on entering a floor or starting a new game, so quitting mid-floor
    loses that floor's progress;
  - no cloud saves;
  - no save-management UI beyond New Game's confirmation.
- **Save format:**
  - version 1 only;
  - no migration code yet (`decode()` is where it would go);
  - adding an item or floor also needs a line in `ActionRegistry` / `FloorRegistry`.
- **Save write:** on Windows, Godot's rename replaces the old file; the old save is kept
  until the new file is complete. A crash in the instant between the rename's removal
  and its move leaves the finished `.tmp`, which is loaded.
- **Retry slot rule:** a slot the player changed mid-floor keeps the player's latest choice;
  only *empty* slots get their checkpoint action back. Continue restores the checkpoint
  layout exactly.
- **Placeholders:**
  - the potion pickup is a pink diamond with a text label, and potion use shows a green
    ring;
  - the title menu is plain text;
  - there are no icons (`ActionDefinition.icon` is unused);
  - Floor 2 is a small two-room placeholder with one reused Gelatinous Blob and no exit.
- **Slot behaviour:** moving an action onto an occupied slot unassigns the action that was
  there (no swap).
- **Potion holding:** a held potion key drinks one potion per second while Carl is hurt.
  Each use still heals.
- The action menu uses Up/Down + W/A/S/D. GAME_SPEC §8's "Equip" submenu with
  Enter/Left/Right is for a later inventory phase.
- Defeated enemies come back when a floor is retried or continued. This is intended: the
  floor starts over.
- **Carried over from earlier phases:**
  - the Blob chases in a straight line and can stall behind walls (for example Floor 2's
    dividing wall);
  - there is no knockback and no invulnerability after a hit;
  - Donut ignores enemies;
  - Escape does nothing outside the menus;
  - there is no way back to the title screen during play (close the window, then Continue);
  - camera limits are not set;
  - hand-written scenes gain `unique_id` fields the first time the editor saves them.
- Godot's `--check-only -s <script>` reports "Identifier not found" for the scripts that
  name an autoload (`level.gd`, `title_screen.gd`, `save_manager.gd`), because it compiles
  the script before autoloads are registered. They compile fine in the game, the tests and
  the runtime load check. By design, this is not worked around.

## Manual verification required
Your own save is `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json`.
It does not exist until you play.
1. Open the project in Godot 4.7.2. The Output panel should show no errors.
2. Press **F5**. With no save, the title shows "Continue" greyed out, "> New Game" and
   "No saved game yet.". Press **Enter**: the Surface starts, and the save file now exists.
3. Play to Floor 1 as before:
   - pick up the potions ("Potion x2");
   - put them on A (Space, Down, A, Space);
   - let a blob hurt Carl, then drink one;
   - take the stairs to Floor 2.
4. Close the game window. Press **F5** again. The title shows "> Continue" and
   "Saved at the start of Floor 2 - HP … / 100". Press **Enter**: Floor 2, with the same
   HP, potion count, `A: Potion` and `D: Fists`, and Donut next to Carl.
5. On Floor 2, drink the last potion (A empties), then let the blob win. GAME OVER waits.
   Press **Enter**: the potion is back, **and on A**.
6. Close the window at GAME OVER. **F5** → Continue gives the Floor 2 checkpoint again, not 0 HP.
7. On the title, go **Down** to New Game and press **Enter**. "Start a new game? Existing
   progress will be replaced." appears with **No** selected; Enter or Escape keeps your save.
   Down + Enter (Yes) starts over on the Surface.
8. Optional: back up and then edit `savegame.json` into invalid JSON. The title then says
   "Save data could not be loaded.", Continue is unavailable, and New Game still works.
9. Resize the window on the title screen. The menu and the confirmation stay readable.

## Next phase
Phase 6 is **not specified** here. Provide its prompt, with acceptance criteria, after
Phase 5 is reviewed.

Groundwork for later phases:
- **More items or floors:** add them to `ActionRegistry` / `FloorRegistry` so saves can name
  them. A new floor gets its checkpoint automatically from `Level._ready()`.
- **Save format changes:** bump `SaveManager.SAVE_VERSION`, and migrate older data in
  `decode()` before `_decode_current_version()` reads it.
- **Floor 3 / an exit from Floor 2:** add stairs down to Floor 2, pointing at the new scene,
  and register the floor.
