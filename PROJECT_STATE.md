# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 6 — Reusable Weapon, Projectile Combat, Save Migration and Floor 3: **complete,
awaiting human review**.
- Phase 5 — Persistent Save/Load and Continue: complete (commit `fd1d5e7`).
- Phase 4 — Inventory, World Loot, Consumable Action and Floor 2: complete (commit `4ea1123`).
- Phase 3 — Action Slots, Action Menu and Run State: complete (commit `a7ef551`).
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There are no `PHASE_02_*.md` to `PHASE_06_*.md` files. Phases 2–6 came from the owner's
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
  used up. Consumables have quantities, and one at 0 leaves the inventory.
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
  retry returns the potion *and* its checkpoint slot.
- No mid-floor saving, multiple save slots or cloud saves.

Phase 6 decisions (also written into `GAME_SPEC.md` §8, §9 and §15):
- **Three kinds of things Carl can have**, told apart by data, never by item id:
  - *innate actions* (Fists): in `GameState.INNATE_ACTIONS`; always there, no quantity;
  - *reusable items* (Slingshot): `ActionDefinition.consumable = false`; found once, then
    owned, with no quantity, never used up; finding one again changes nothing;
  - *consumables* (Small Health Potion): `consumable = true`; counted, spent one per use.
- **The Slingshot** (id `slingshot`) is the one reusable ranged weapon. No ammunition. It
  fires one stone the way Carl faces: **10 damage**, **0.6 s cooldown**, **480 px/s**, gone
  after **320 px** (10 tiles, 40 ticks), on a wall, or on the first enemy it hits.
- **Stones never hurt Carl or Donut** and never collect pickups or trigger stairs.
- **Floor 2 has the one Slingshot pickup** and **stairs down to Floor 3**. Floor 3 is a
  combat-test floor with no exit. Progression: Surface → Floor 1 → Floor 2 → Floor 3.
- **Reusable items follow the checkpoint rules.** A Slingshot found on Floor 2 is not in the
  Floor 2 checkpoint: a retry, or quitting and continuing, takes it back (pickup back, slot
  empty). Entering Floor 3 with it checkpoints it, with its slot.
- **Save format version 2** stores owned reusable items as `owned_items`, a list of ids.
  **Version 1 saves are migrated** when loaded (in memory only); the file becomes version 2
  at the next checkpoint save, which Continue triggers at once by opening the floor.

## Implemented
- **Title screen** (main scene):
  - **Continue** (available only when the save loads) resumes the saved floor checkpoint;
    a line shows where, for example "Saved at the start of Floor 3 - HP 80 / 100".
  - **New Game** starts a clean run on the Surface (100 HP, no items, no Slingshot, Fists on
    D). If a save file exists, it first asks "Start a new game? Existing progress will be
    replaced." with No selected.
  - An unloadable save shows "Save data could not be loaded." and leaves Continue
    unavailable.
- **Carl** (`scenes/actors/carl.tscn`): **unchanged in Phase 6.**
  - Arrow-key movement at 180 px/s, wall collision, facing arrow, smoothed camera.
  - **Action slots:** holding W/A/S/D uses the slot's action toward his facing direction.
    An empty slot does nothing.
  - A consumable is used only if Carl has one, and a use that really happened spends one.
    Reusable items and Fists are never spent.
  - **Pickups:** `collect_item()` adds what a pickup gives to his inventory.
  - Keys held through an unpause are ignored until released.
  - 100 HP, red hurt flash; at 0 HP he greys out and stops responding.
- **Fists:** `resources/actions/fists.tres` + `scenes/actions/fists.tscn` (a MeleeAttack:
  10 damage, reach 24 px, radius 18 px, 0.4 s cooldown, hold to repeat).
- **Small Health Potion:** `resources/actions/small_health_potion.tres` (consumable, short
  name "Potion") + `scenes/actions/small_health_potion.tscn` (a `HealAction`: 30 HP, 1 s
  cooldown, a brief green ring).
- **Slingshot (Phase 6):** `resources/actions/slingshot.tres` (reusable: `consumable` false,
  with a placeholder icon `assets/items/slingshot.png`) + `scenes/actions/slingshot.tscn` (a
  `ProjectileLauncher`, 0.6 s cooldown) firing `scenes/projectiles/slingshot_stone.tscn` (a
  `Projectile`: 10 damage, 480 px/s, 320 px, targets `enemy_hurtbox`, stopped by `world`). The
  stone is a pale disc with a dark outline and a short trail, drawn above the actors.
- **Item pickup:** `scenes/props/item_pickup.tscn`, a reusable Area2D. It bobs gently and
  shows its item's icon (the Slingshot) or, without an icon, a pink diamond (the potion),
  and a label from `ActionDefinition.get_label()`: "Potion x2", "Slingshot".
- **Donut:** unchanged. She follows Carl on the navigation mesh, has no combat, cannot be
  hurt, and never collects pickups or uses the inventory. She freezes while the game is paused.
- **Gelatinous Blob:** unchanged (30 HP, touch damage 10 every 0.8 s, chases within 220 px).
  Fists and stones damage it through the same `Hurtbox` → `Health`.
- **Surface:** stairs down to Floor 1, the HUD and the action menu.
- **Floor 1:** stone room with four pillars, two Gelatinous Blobs, a Small Health Potion
  pickup (x2) at (128, 320), and stairs down to Floor 2. No stairs back up.
- **Floor 2** (`scenes/levels/floor_02.tscn`, 36×18 tiles):
  - a west room where Carl and Donut arrive, a wall with a 4-tile doorway, and an east room
    with two machinery blocks and one Gelatinous Blob;
  - **Phase 6:** the **Slingshot pickup** at (352, 448) in the west room;
  - **Phase 6:** **stairs down to Floor 3** at (1056, 96), the east room's far corner,
    labelled "Down to Floor 3". The sign under "Floor 2 - Utility Level" now says where the
    stairs are (it used to say the way down was not built). No stairs back up.
- **Floor 3 (Phase 6,** `scenes/levels/floor_03.tscn`**, 32×20 tiles, 1024×640 px):**
  - Carl arrives at (160, 320), Donut at (104, 332);
  - a 2×6-tile wall 6 tiles east of the spawn point: a stone fired right from the spawn
    point stops on it (x = 352), and the Gelatinous Blob at (736, 320) behind it is safe;
  - two 2×2 blocks further east, and a second Gelatinous Blob at (864, 160);
  - the signs "Floor 3 - Processing Level" and "Prototype: the way further down is not
    built yet.", HUD and menu. **No exits**: no way up, and Floor 4 is out of scope.
- **Stairs** (`scenes/props/stairs.tscn`): stairs **down**. They load `destination_scene_path`
  and ignore Carl for the first 2 physics frames of a level (no transition loops).
- **HUD** (`scenes/ui/hud.tscn`): "HP: x / 100"; the slot bar, for example
  `W: Slingshot   A: Potion x1   S: —   D: Fists` (no quantity for the Slingshot); a "Space:
  action menu" hint; the centred GAME OVER panel. Unchanged in Phase 6.
- **Action menu** (`scenes/ui/action_menu.tscn`): lists the four slots and Carl's inventory,
  for example "Fists (on D)", "Small Health Potion x1 (on A)", "Slingshot (on W)", with a
  description or confirmation line. Unchanged in Phase 6.
- **GameState autoload:** HP, inventory, slots and the floor-entry state (see Architecture).
- **SaveManager autoload:** the persistent checkpoint in `user://savegame.json`, format
  version 2, with the version 1 migration (see Architecture).

Not implemented (later phases): ammunition, other weapons, equipment stats, Floor 4, other
enemy types, enemy ranged attacks, bosses, Donut combat/damage/stun, shops/economy, multiple
save slots, mid-floor or cloud saving, pause menu.

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

Whatever slot holds the Slingshot fires it. Holding a slot key repeats its action as fast as
the action's cooldown allows: Fists every 0.4 s, the Slingshot every 0.6 s, a potion every
1 s while it can heal. Pickups need no key. No input actions were added in Phases 3–6.

## Scene structure
```
project.godot                                   Settings, InputMap, physics layer names, GameState + SaveManager autoloads
assets/tiles/placeholder_world_tiles.png        Original 4-tile placeholder atlas
assets/items/slingshot.png                      Original 32×32 placeholder Slingshot icon (Phase 6)
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet (wall tiles collide)
resources/actions/fists.tres                    ActionDefinition: Fists (innate)
resources/actions/small_health_potion.tres      ActionDefinition: Small Health Potion (consumable)
resources/actions/slingshot.tres                ActionDefinition: Slingshot (reusable, with icon; Phase 6)
scenes/actions/fists.tscn                       Fists' performer: a MeleeAttack
scenes/actions/small_health_potion.tscn         The potion's performer: a HealAction (30 HP)
scenes/actions/slingshot.tscn                   The Slingshot's performer: a ProjectileLauncher (Phase 6)
scenes/projectiles/slingshot_stone.tscn         The Slingshot's Projectile (Phase 6)
scenes/ui/title_screen.tscn                     Main scene: Continue / New Game menu, overwrite confirmation
scenes/ui/hud.tscn                              HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action/inventory menu (CanvasLayer 10)
scenes/actors/carl.tscn                         Carl: Health, Hurtbox, Camera2D (performers added at run time)
scenes/actors/donut.tscn                        Donut + NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack)
scenes/props/stairs.tscn                        Reusable stairs down
scenes/props/item_pickup.tscn                   Reusable world pickup (item + quantity; icon or default gem)
scenes/levels/surface.tscn, floor_01.tscn, floor_02.tscn, floor_03.tscn   The four levels
scripts/autoload/game_state.gd                  GameState: the current run's state
scripts/autoload/save_manager.gd                SaveManager: the one save file (encode, validate, migrate, safe write, load, delete)
scripts/state/floor_entry.gd                    class FloorEntry: a floor checkpoint (HP, inventory snapshot, slot layout)
scripts/actions/action_registry.gd              class ActionRegistry: action id -> ActionDefinition (for loading saves)
scripts/levels/floor_registry.gd                class FloorRegistry: floor id -> scene and name (the only floors a save can open)
scripts/actions/action_definition.gd            class ActionDefinition (Resource): one slot-able action or item
scripts/actions/action_performer.gd             class ActionPerformer (Node2D): base for what carries an action out
scripts/actions/action_slots.gd                 class ActionSlots: which action each W/A/S/D slot holds
scripts/actions/inventory.gd                    class Inventory: innate actions, owned reusable items, consumable quantities
scripts/actions/heal_action.gd                  class HealAction (an ActionPerformer): heals the user
scripts/combat/health.gd                        class Health: hit points, take_damage(), heal(), set_health()
scripts/combat/hurtbox.gd                       class Hurtbox: where an actor can be hit
scripts/combat/melee_attack.gd                  class MeleeAttack (an ActionPerformer): cooldown-limited hit circle
scripts/combat/projectile_launcher.gd           class ProjectileLauncher (an ActionPerformer): fires a Projectile (Phase 6)
scripts/combat/projectile.gd                    class Projectile: flies, stops at walls, hits one target (Phase 6)
scripts/levels/level.gd                         class Level: run-state wiring, GAME OVER, retry
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/props/item_pickup.gd                    Walk-over pickup: gives its item to Carl once
scripts/<actors|enemies|props|ui>/*.gd          One script per scene that needs one
tests/                                          Test scripts (not part of the game), see Tests
tests/fixtures/                                 Two real save_version 1 files written by the Phase 5 game (for migration tests)
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
│   ├── enemies          e.g. GelatinousBlob with target = ../Carl
│   └── (stones)         Projectiles are added here while they fly
├── HUD                  hud.tscn instance
└── ActionMenu           action_menu.tscn instance
```
**To add a floor:** duplicate `floor_03.tscn` (or another floor), then:
1. Repaint Terrain and resize the NavigationPolygon outline.
2. Place Carl (the entry point) and Donut, and the enemies (set each enemy's `target` to Carl).
3. Add pickups and stairs down, if any.
4. Point the previous floor's stairs down at the new file. Never add stairs back up.
5. Add one line to `FloorRegistry`, so the floor can be saved and continued.

**To add an item:**
1. Write an ActionDefinition `.tres`: id, names, `consumable` (true = counted and used up,
   false = reusable: found once, never used up), `performer_scene`, optional `icon`.
2. Give it a performer scene: an existing ActionPerformer (MeleeAttack, HealAction,
   ProjectileLauncher) with new numbers, or a new ActionPerformer subclass for a new kind of
   behaviour.
3. Add one line to `ActionRegistry`, so saves can name it.
4. Place `item_pickup.tscn` instances with `item` and `quantity` set.

Carl's script does not change (it did not change in Phase 6).

## Architecture

### Actions and items
- **`ActionDefinition`** (Resource): `id` (stable; used to compare actions and in save
  data), `display_name`, `short_name` (HUD/pickup label, falls back to the display name),
  `description`, optional `icon` (shown by pickups), `assignable`, `consumable`,
  `performer_scene`.
  - `get_label(quantity, short)`: "Small Health Potion x2" for a consumable, just the name for
    anything reusable. The HUD, the menu (through `Inventory.get_label()`) and pickups all use
    it, so the rule "only consumables show a quantity" lives in one place.
- **Three kinds, from data** (Phase 6):

  | Kind | Example | Defined by | Quantity | Used up | Saved as |
  |------|---------|------------|----------|---------|----------|
  | innate action | Fists | `GameState.INNATE_ACTIONS` | none | never | not saved (every run has it) |
  | reusable item | Slingshot | `consumable = false`, not innate | none | never | `owned_items: ["slingshot"]` |
  | consumable | Small Health Potion | `consumable = true` | 0–999 | one per use | `inventory: {"small_health_potion": 1}` |

  No script checks item ids to tell them apart.
- **`ActionPerformer`** (Node2D base): the root of a `performer_scene`. It has
  `perform(direction) -> bool`, which returns true only if the action really happened, and
  a `user` (Carl), which Carl sets before adding it. Each performer keeps its own state,
  such as its cooldown.
  - **`MeleeAttack`**: Fists. The Blob's ContactAttack calls `attack()` directly.
  - **`HealAction`**: the potion. It returns false (so no potion is spent) when nothing was
    healed or it is cooling down.
  - **`ProjectileLauncher`** (Phase 6): the Slingshot. `perform()` creates its
    `projectile_scene`, adds it to the user's parent (the level's Actors node, so the stone
    flies on independently of Carl), calls `launch(user position, direction)`, starts its
    cooldown and emits `fired(projectile)`. It returns false while cooling down.
- **Carl's generic dispatch** (`_use_slot`), unchanged:
  1. slot → action;
  2. a consumable with 0 left does nothing;
  3. `performer.perform(facing)`;
  4. if that returned true and the action is consumable, `inventory.remove(action, 1)`.

  So: `W → Slingshot definition → ProjectileLauncher.perform() → Projectile`. Carl knows
  nothing about projectiles.

### Projectiles (`Projectile`, `scripts/combat/projectile.gd`, Phase 6)
- A plain Node2D (not a physics body) with `damage`, `speed`, `max_distance`,
  `target_layers` (whom it may hurt) and `blocking_layers` (what stops it), and the
  `direction` set by `launch()`. Emits `stopped(collider)` once (null when it ran out of range).
- Each physics tick it casts a ray over the stretch it is about to fly
  (`speed × delta`, 8 px at 60 ticks/s) against `target_layers | blocking_layers`, with
  areas included, and stops at the **first** thing on it:
  - a body (a wall tile or any solid on `world`): it moves to the hit point and is removed;
  - a `Hurtbox` that `can_be_hit()` on a target layer: `take_hit(damage)` once, then removed;
  - any other area (for example a dying blob's Hurtbox) is excluded and the ray is cast again.
- Because the whole stretch is checked before moving, it cannot skip through a wall, hit
  something behind a wall, or hit two targets. The ray reports shapes it *starts inside*
  (`hit_from_inside`), so an enemy that steps onto a stone between two ticks is still hit.
  (Without that, about 1 stone in 10 flew through a blob chasing Carl; found during the real
  playthrough, see Validation.)
- After `max_distance` it stops by itself. It pauses with the game (menu, GAME OVER) like
  every gameplay node, and disappears when the level is reloaded or left.
- **Faction:** the Slingshot's stone targets `enemy_hurtbox` only. Carl's Hurtbox is on
  `player_hurtbox`; Donut has no Hurtbox and her body's `companion` layer is not in the mask;
  pickups and stairs detect only the `player` body, which a projectile is not.
- **Numbers:** 480 px/s (fast, but still easy to follow at 8 px per tick) and 320 px range
  (10 tiles: well inside the 853×480 px the camera shows at zoom 1.5, and longer than a blob's
  220 px detection range, so a careful player can hit a blob before it notices him).

### Inventory (`Inventory`, RefCounted)
- The single place items are stored. GameState owns the run's one Inventory.
  - `_innate`: innate actions;
  - `_items`: carried items (reusable and consumable) by id, in the order found;
  - `_quantities`: consumables only. A reusable item is never in here.
- `reset(innate)`: new run.
- `add(item, n)`: a consumable gains `n`; a reusable item becomes owned (`n` only needs to
  be positive; owning it again changes nothing and emits nothing).
- `remove(item, n) -> bool`: consumables only; fails, removing nothing, if Carl has fewer.
  Reusable items have no quantity, so they can never be removed this way.
- `get_quantity()` (0 for innate and reusable), `has()` (innate, owned, or quantity > 0),
  `is_innate()`.
- `get_actions()`: innate first, then carried items in the order found.
- `get_label(action, short)`: `action.get_label(get_quantity(action), short)`.
- `get_snapshot()` / `restore_snapshot()`: a copy of the carried items (`items` and
  `quantities`), so it includes owned reusable items. Restoring *replaces* the carried items,
  so it can never add to them.
- It emits `changed` on every change. A consumable whose quantity reaches 0 is removed.

### Action slots (`ActionSlots`, RefCounted) — unchanged in Phase 6
- Created with the Inventory it belongs to (`ActionSlots.new(inventory)`).
- `assign(action, slot)`: accepts only assignable actions **that Carl has** (so the Slingshot
  only once owned); an action is in at most one slot, so assigning moves it; a replaced
  action loses its slot but stays in the inventory (no swapping).
- It listens to `inventory.changed` and **empties any slot whose action Carl no longer
  has**. This single rule handles the last potion being used and a retry taking back a potion
  or the Slingshot.
- `get_display_name(slot, short)` includes quantities only for consumables.
- **Only `GameState.start_new_run()` knows the default layout** (Fists in D).

### World pickups (`item_pickup.tscn`)
- Exports `item` (an ActionDefinition) and `quantity`. Placing loot is data only. The
  Slingshot pickup is the same scene with `item = slingshot.tres` (quantity 1).
- An Area2D with collision layer none and mask 2 `player`: only Carl's body is detected.
  Donut (layer 3), enemies (layer 4) and projectiles (no body) are never reported.
- Shows `item.icon` when the item has one (the Slingshot), otherwise the pink gem, and the
  label `item.get_label(quantity, true)`.
- On touch it calls `collect_item(item, quantity)` on the body (only Carl has that method),
  sets a `_collected` flag, stops monitoring and frees itself. Two bodies touching it in the
  same physics step cannot both collect.
- Nothing records collected pickups. A retry reloads the level (pickups back) and restores
  the inventory (items back to the entry state), so the two always agree.

### Action menu — unchanged in Phase 6
- Space opens it only while the game is not paused (never over GAME OVER). It pauses the
  scene tree; Space or Escape closes it. Paused stones stay where they are and fly on after.
- It lists `Inventory.get_actions()` with labels and each action's slot. Up/Down select;
  W/A/S/D assign. It refreshes on inventory and slot changes.
- Its rows are Labels, which never take focus, so Godot's `ui_accept` (Space/Enter) cannot
  press anything.
- **No free actions:** keys held when the game unpauses are ignored by Carl until
  released (`NOTIFICATION_UNPAUSED` in `carl.gd`). This covers the Slingshot too.

### Run state (`GameState` autoload)
- It holds only what must survive level changes: `carl_health`, `carl_max_health`,
  `inventory`, `action_slots`, `floor_entry` (a `FloorEntry`). It has no gameplay rules and
  does **no disk I/O**.
- `INNATE_ACTIONS` (`[Fists]`) is the one list of innate actions.
- `start_new_run()` resets everything in place, so references stay valid: 100/100 HP,
  inventory = Fists only (no potions, no Slingshot), Fists on D, no floor entry.
- `continue_from(checkpoint)` (Continue) starts a run with exactly the checkpoint's HP,
  inventory (including owned reusable items) and slot layout.
- **Levels connect GameState to the game** (`Level._ready()`): Carl gets the HP, `inventory`
  and `action_slots`; the HUD and the menu get the slots and the inventory. Carl, the HUD,
  the menu, pickups and projectiles never name `GameState` themselves. Test scripts compile
  before autoloads exist, so anything a test preloads must not name it.
- ARCHITECTURE_RULES allows exactly two autoloads, `GameState` and `SaveManager`, and those
  are the only two.

### Floor-entry state and retry
- Every level calls `GameState.record_floor_entry(scene_file_path)` when it starts, then
  `SaveManager.save_checkpoint(GameState.floor_entry)`. This single place in `Level._ready()`
  writes every checkpoint, for all current and future floors (Floor 3 needed no code).
- The checkpoint (`FloorEntry`) holds the scene path, HP, max HP,
  `inventory.get_snapshot()` (consumables and owned reusable items) and
  `action_slots.get_layout()`.
- **GAME OVER** (`Level._on_carl_died()`) pauses the scene tree. **Death never writes the
  save.**
- Enter on the GAME OVER panel makes the level:
  1. call `GameState.restore_floor_entry()`: HP goes back; the carried items are replaced by
     the entry snapshot, and ActionSlots empties any slot holding something Carl no longer
     has; then `fill_empty_slots(entry layout)` puts each checkpoint assignment back where
     its slot is empty and the action is in no other slot;
  2. unpause;
  3. reload the recorded scene, which brings back its enemies and pickups.
- **Slingshot examples:**
  - Floor 2 (entered without it): collect it, put it on W, die → the snapshot has no
    Slingshot, so it is taken back, W empties, and the reloaded Floor 2 has its pickup again.
    Any number of retries gives the same result, never two Slingshots.
  - Floor 3 (entered with it on W): die → the snapshot has it, so it stays owned, and W =
    Slingshot is kept (or refilled if W was emptied).

### Persistent save (`SaveManager` autoload, `scripts/autoload/save_manager.gd`)
- **Location:** `user://savegame.json` (`DEFAULT_SAVE_PATH`), in Godot's per-user app data,
  never in the project folder. On Windows that is
  `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json`.
  `save_path` can be changed; tests always change it.
- **Format version 2** (`SAVE_VERSION`, Phase 6), stable ids only:
  ```
  {"save_version": 2, "floor_id": "floor_03", "carl": {"health": 80, "max_health": 100},
   "inventory": {"small_health_potion": 1},
   "owned_items": ["slingshot"],
   "action_slots": {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": null, "action_d": "fists"}}
  ```
  - `inventory`: the quantity of each consumable (same meaning as in version 1);
  - `owned_items`: the ids of the reusable items Carl owns (Phase 6);
  - innate actions are never saved.
- **Version 1 → 2 migration** (`decode()` → `_migrate_version_1()`):
  1. `save_version` 1 is recognized; the data is copied (the caller's data is never changed);
  2. the copy gets `save_version: 2` and `owned_items: []`. The Slingshot did not exist in
     version 1, so a migrated save never owns it; anything a version 1 file has under
     `owned_items` is ignored;
  3. the copy is validated by the full version 2 rules, which are version 1's rules plus
     the owned items. A v1 slot naming the Slingshot is therefore emptied, and a v1
     inventory with a Slingshot quantity is rejected;
  4. loading never writes. The file on disk stays version 1 until the next checkpoint save,
     which Continue triggers at once (opening the floor records and saves its entry). If the
     player picks New Game instead, the new game's Surface checkpoint replaces it. This is
     the safest choice: nothing is written unless the game would write anyway, and a failed
     migration leaves the file untouched.
  - Any other version (0, 3, 999, ...) is rejected: "save_version N is not supported".
  - Adding version 3 later means bumping `SAVE_VERSION`, adding `_migrate_version_2()`, and
    chaining it in `decode()`.
- **Persisted:** floor id, Carl's HP and max HP, consumable quantities, owned reusable items
  and the four slot assignments, all at floor entry.
- **Not persisted (on purpose):** positions; enemies and their HP; collected pickups;
  projectiles; cooldowns, animation and navigation; the live menu state; anything after
  floor entry.
- **API:** `save_checkpoint(entry) -> bool`; `load_checkpoint() -> FloorEntry` (null, with
  the reason in `last_error`); `has_save_file()`; `delete_save()`; `encode(entry)` /
  `decode(data)`.
- **Safe writes:** the text is written to `savegame.json.tmp`, read back and compared, then
  renamed over `savegame.json`. A failure logs an error and leaves the old save as it was.
  A finished `.tmp` left by an interrupted save is loaded (and validated) instead.
- **Validation (untrusted input).** `decode()` rejects the whole save, without logging an
  engine error, if:
  - the file is not valid JSON, or its root is not a JSON object;
  - `save_version` is not a whole number, or is not 1 (migrated) or 2;
  - `floor_id` is not in `FloorRegistry`. No path is ever read from the file;
  - HP is not a whole number with 1 ≤ health ≤ max_health ≤ 1000;
  - `inventory` is not an object; an id is not in `ActionRegistry`, is innate (Fists) or is
    a reusable item (the Slingshot has no quantity); or a quantity is not a whole number
    from 0 to 999;
  - `owned_items` (version 2) is not a list; or an entry is not a string, not in
    `ActionRegistry`, innate, consumable, or listed twice;
  - `action_slots` is not exactly the four slot names, each with an id or null.

  It **sanitizes** slots instead of rejecting the save: an unknown action id, an action
  Carl would not have (a potion with quantity 0, a Slingshot he does not own), or an action
  named twice leaves that slot empty. `ActionSlots.fill_empty_slots()` decides this.
- **Registries:** `FloorRegistry` (`surface`, `floor_01`, `floor_02`, `floor_03`) and
  `ActionRegistry` (`fists`, `small_health_potion`, `slingshot`) are the whitelists that turn
  saved ids back into scenes and resources.
- **Title flow:** Continue calls `load_checkpoint()` again, then `GameState.continue_from()`,
  then loads the saved floor (Floor 3 directly, for a Floor 3 save). New Game calls
  `GameState.start_new_run()` and loads the Surface, whose checkpoint replaces the old save.
- **Test isolation:** `tests/support/game_test.gd` points `save_path` at
  `user://test_saves/<test>.json` before anything runs, and deletes that file at the start
  and the end (`test_surface_traversal.gd` does the same). Tests never touch `savegame.json`.

### Earlier decisions still in force
- Compatibility renderer; 1280×720 base with `canvas_items` stretch and `expand` aspect;
  physical-keycode bindings; Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.6.0`.
- `.godot/` ignored, `.uid` files committed, LF line endings.
- Carl is a floating-mode `CharacterBody2D`; Camera2D inside Carl (zoom 1.5, smoothing);
  physics interpolation on.
- Donut uses a navigation mesh baked when the level loads.
- Combat components: `Health` (all damage through `take_damage()`), `Hurtbox`,
  `MeleeAttack`, and since Phase 6 `ProjectileLauncher` and `Projectile`.
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
| 6     | `enemy_hurtbox`  | Enemy Hurtboxes (Area2D)                   | none; found by Carl's Fists and stones   |
| —     | (none)           | Stairs (Area2D, `monitorable` off)         | 2 `player`: only Carl triggers them      |
| —     | (none)           | Item pickups (Area2D, `monitorable` off)   | 2 `player`: only Carl collects them      |
| —     | (none)           | Slingshot stones (Node2D, Phase 6)         | ray query: 6 `enemy_hurtbox` (hit) and 1 `world` (stops) |

Consequences:
- Carl and the blobs block each other.
- Donut collides only with walls, and she can neither trigger stairs nor collect pickups.
- Carl's Fists and stones target layer 6 only; the Blob's touch targets layer 5 only. So
  Carl's attacks never hurt Carl or Donut.
- Stones are stopped by layer 1 only: they fly over Donut, pickups and stairs.
- Navigation baking reads only layer 1.

## Earlier behaviour changed in Phase 6
1. **A non-consumable carried item is now a reusable item** with no quantity. Before, every
   carried item was counted. `test_action_slots.gd` used a test-only item, "Other", as a
   counted item ("Other x1"); it is now marked `consumable = true`, which keeps what that
   check was about.
2. **Floor 2 has an exit** (stairs down to Floor 3), and its second sign changed.
   `test_inventory_run.gd` and `test_save_game.gd` checked that Floor 2 had no exits at all;
   they now check that its only exit leads down to Floor 3 (still nothing leads up).
3. **Saves are version 2.** `test_save_manager.gd` expected `save_version` 1 and rejected
   version 2; it now expects 2 (with `owned_items`), and rejects 3 and 999.
   `test_save_game.gd` checks `save_version` 2 and an empty `owned_items`.
4. **The pickup scene** groups its gem under `Marker/DefaultGem` and has a `Marker/Icon`
   sprite. Its label comes from `ActionDefinition.get_label()` (unchanged for potions).
5. **`test_windowed_resolutions.gd`** now carries the Slingshot too (the longest HUD text is
   `W: Slingshot   A: Potion x2   S: —   D: Fists`) and checks Floor 2 and Floor 3.

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process. A test fails on a non-zero exit
code or on any engine ERROR/WARNING in its output. Tests with "windowed" in their name get a
real window, which opens briefly. The full run takes about 5 minutes. Each test file can
also be run on its own; the first lines of each file give the command.

| Test file                               | Covers |
|-----------------------------------------|--------|
| `test_input_map.gd` (Phase 0)           | Every action bound to its key; no key shared between actions |
| `test_carl_movement.gd` (Phase 1, 3)    | Exact speed per arrow key, normalized diagonals, facing, tick-rate independence; W/A/S/D never move Carl |
| `test_surface_traversal.gd` (Phase 1)   | Title → Surface, wall collision, Donut following, stairs → Floor 1, Floor 1 walls |
| `test_combat.gd` (Phase 2, 3)           | Health; Fists on D: facing, diagonals, no self-hit, Donut unaffected, W/A/S empty, exact cooldown; Blob pursuit, walls, contact damage, death; HUD HP; downed Carl |
| `test_action_slots.gd` (Phase 3, 4)     | New-game layout; ActionSlots rules; Carl follows reassignment live; cooldown not reset by moving; a test-only second action works next to Fists; HUD slot bar |
| `test_action_menu.gd` (Phase 3)         | Space opens/pauses, Space/Escape close; nothing focused; Carl/Donut frozen while open; reassigning through the menu; no free punch/step across close; blob frozen while open; no menu over GAME OVER |
| `test_floor_loop.gd` (Phase 2, 3)       | Title → new game; reassignment; HP and slots carried to Floor 1; no transition loop; nothing on Floor 1 leads up; real fight and defeat; GAME OVER waits; retry with entry HP; stairs ignore an arrival on top of them |
| `test_inventory.gd` (Phase 4)           | Inventory rules, slots follow the inventory, potion use through a slot, one potion per press, menu quantities, pickups (Donut/enemy can't take them, two collectors) |
| `test_inventory_run.gd` (Phase 4, 5)    | Real potions run through Floor 1 → Floor 2 with retries; Floor 2's only exit leads down (Phase 6) |
| `test_save_manager.gd` (Phase 5, 6)     | Registries (4 floors); version 2 JSON (owned_items); a Floor 3 checkpoint with the Slingshot on W round-trips; 40 kinds of bad data rejected with the file untouched (incl. versions 3/999, Slingshot with a quantity, owned_items not a list/unknown/number/scene path/consumable/innate/duplicate); slots sanitized (incl. an unowned Slingshot); delete; interrupted-save recovery |
| `test_save_game.gd` (Phase 5, 6)        | Real title + levels: checkpoints (save_version 2), Continue, deaths, New Game confirmation, corrupt/unsupported saves |
| `test_save_migration.gd` (Phase 6)      | The two real Phase 5 fixtures load (floor, HP, potions, slots kept; no Slingshot; file untouched); a v1 Slingshot slot is emptied, a v1 `owned_items` ignored, a v1 Slingshot quantity rejected; 13 kinds of malformed v1 data rejected; v2 loads, v2 without owned_items and versions 0/3/999/-1 rejected; title → Continue on the v1 Floor 2 save opens Floor 2 with its state, the file becomes version 2 with the same values, and the game plays on (walk, punch, potion, pick up the Slingshot) |
| `test_slingshot.gd` (Phase 6)           | Ownership model (innate/reusable/consumable, owned once, never removed, snapshots, new run clears it); slots (not before owning, W/A/S/D, one slot, next to Fists and potion, emptied when taken back); pickup (label, icon, Donut/enemy can't take it, disappears, once, two collectors, second pickup); firing right/up/left/down from Carl, empty slots fire nothing; exactly 10 damage, 3 hits kill a 30 HP blob, the stone is gone on the hit; one target only; flies through a dying blob; **hits a blob that steps onto it**; stops at a wall face, blob behind it safe; 320 px / 40 ticks / 8 px per tick; never hurts Carl or Donut, no pickup, no stairs; point blank; cooldown (short press 1, held 3 at exactly 36 ticks, taps can't go faster, moving keeps the cooldown, nothing used up); menu (stone frozen, W in the menu fires nothing, resumes and hits, no free shot on close, key released inside not stuck); HUD and menu labels, shooting changes nothing, potion unaffected |
| `test_slingshot_run.gd` (Phase 6)       | Real run: New Game clears a previous Slingshot; Surface → Floor 1 → Floor 2 → Floor 3, nothing leads up; Floor 2 entry has no Slingshot (run, entry state, disk); collect + W doesn't save; two Floor 2 deaths take it back (pickup back, W empty, no duplicates); quit before Floor 3 → Continue without it; three stones kill the Floor 2 blob; Floor 3 arrival (spawn, Donut, camera, sign, no exits, no loop), the Floor 3 checkpoint in memory and on disk owns it with W = Slingshot; a stone stops at Floor 3's wall tiles, blob behind safe; two Floor 3 deaths keep it on W; Continue opens Floor 3 directly and it fires (three stones kill a blob); New Game clears it |
| `test_windowed_resolutions.gd` (Phase 2–6) | At 1280×720, 640×360, 1024×768: HUD with `W: Slingshot   A: Potion x2`, GAME OVER panel, action menu, camera; the Slingshot pickup and label on screen from Floor 2's spawn; Floor 3's signs on screen and clear of the HUD; a flying stone drawn on screen; the title screen and its confirmation. Prints SKIP and passes when run headless |

Every test uses its own save file under `user://test_saves/` (see Persistent save).

## Validation performed (Phase 6)
All runs used Godot 4.7.2.stable.official on this machine (Intel UHD Graphics, 60 Hz). Every
run that could write a save used an isolated user-data folder (scratch copies with
`config/custom_user_dir_name`), or the tests' own `user://test_saves/` files.
- **Baseline before changes:** the Phase 5 suite at HEAD `fd1d5e7` passed 12 of 12 (3 min 24 s).
- **Version 1 fixtures from the real Phase 5 code:** a throwaway `git worktree` of `fd1d5e7`
  (with its own user-data folder) ran Phase 5's own `SaveManager.save_checkpoint()` to write
  `tests/fixtures/phase5_save_v1_floor_01.json` and `..._floor_02.json`, and Phase 5 loaded
  both back.
- **Clean import:** a copy without `.godot/` imported in the headless editor with no errors or
  warnings; all 62 scripts/scenes/resources load and all 16 scenes instantiate.
- **Strict parse check:** with the 37 default-enabled GDScript warnings raised to errors
  (scratch copy), all 62 files load. This found three warnings in new test code (an integer
  division, two names reused in one block), which were fixed. The game scripts had none.
- **Test suite:** `run_all.gd` passed 15 of 15 (4 min 39 s) on the final code, and 15 of 15
  on an earlier full run. The three new files are `test_slingshot.gd`,
  `test_slingshot_run.gd` and `test_save_migration.gd`.
- **The player's save was never touched:** `savegame.json` in the real user folder has the
  same SHA-256 (`c8801e3c…`) before and after all Phase 6 work, and `test_saves/` is empty
  after the suite.
- **Mutation checks:** 15 regressions were injected, one at a time, into a throwaway copy
  (own user-data folder), each restored afterwards. Every one made the intended test fail:
  - a projectile passing through walls (`test_slingshot`: the stone hit the blob behind the
    wall; `test_slingshot_run`: the Floor 3 stone flew past the wall);
  - a stone passing through an enemy that steps onto it (no `hit_from_inside`);
  - a projectile that hurts Carl (targets `player_hurtbox`);
  - a projectile stopped by Donut (her `companion` layer made blocking);
  - the Slingshot consumed after use (made consumable);
  - a duplicate Slingshot pickup (the pickup never disappears; two collectors both own it);
  - a reusable item owned twice (a second find not ignored);
  - the Slingshot kept after a Floor 2 retry;
  - the Slingshot lost on entering Floor 3 (snapshots dropping owned items);
  - version 1 saves rejected instead of migrated;
  - an unknown owned id accepted;
  - a Slingshot quantity accepted in `inventory` (`test_save_manager` and `test_save_migration`);
  - stones that keep flying while the menu is open;
  - a 0.3 s cooldown;
  - Floor 2's stairs leading back up to Floor 1.

  One test weakness found this way was fixed: the menu-freeze check read the position of a
  stone that had already been freed, so it failed with a script error rather than a clear
  message. It now fails with "the stone flew on and is gone".
- **Real playthrough** (process 1: the isolated scratch copy in a real 1280×720 window,
  driven by key events through Godot's input pipeline, arrow keys steered along navigation
  routes; screenshots inspected):
  1. title (no save: Continue unavailable) → New Game → Surface → stairs → Floor 1;
  2. potions on A; a Floor 1 blob beaten with Fists on D (Carl at 80 HP); stairs → Floor 2;
  3. Floor 2 entry: no Slingshot in the run, the menu or the save (`owned_items: []`);
  4. walked over the Slingshot → owned; the menu listed "Slingshot (no slot)"; Down + W put
     it on W, D stayed Fists; HUD `W: Slingshot   A: Potion x2   S: —   D: Fists`; the save
     was still the entry checkpoint;
  5. **Floor 2 death case:** walked into the blob until GAME OVER; Enter → Slingshot not
     owned, the pickup back, W empty;
  6. collected it again, W = Slingshot; from 288 px, three W presses: each stone flew right
     and stopped on the blob's Hurtbox, blob HP 30 → 20 → 10 → 0; a stone fired up stopped at
     the top wall (y = 32); Donut unaffected (no Health, 60 px from Carl);
  7. stairs → Floor 3: `W: Slingshot` and both potions kept, Donut 57 px from Carl, no exits;
     the Floor 3 checkpoint on disk had `owned_items: ["slingshot"]` and `action_w:
     "slingshot"`;
  8. a stone fired right from the spawn point stopped at the central wall (x = 352), the blob
     behind it unhurt; walked around the wall, three stones killed that blob;
  9. walked into the second blob until GAME OVER; Enter → the Slingshot still owned and on W;
  10. the process quit normally (exit code 0), no engine errors.
- **Bug found and fixed during validation:** in the first real-key run (process 2 below), one
  stone of a held-W volley flew straight through a blob that had just started chasing Carl.
  Cause: a chasing blob can step onto a stone between two ticks, and Godot rays ignore a
  shape they *start* inside, so the stone passed through. None of the earlier tests fired at a
  moving enemy. Fix: the projectile's ray uses `hit_from_inside`. A deterministic test now
  moves a blob onto a flying stone. A scratch sweep of 60 chasing blobs at different
  distances: 6 of 60 stones missed before the fix, 0 of 60 after. The stone was also made a
  little larger (radius 7 instead of 5.5, longer trail) to be easier to follow at 640×360.
- **Real process restart** (process 2, after the fix: a fresh `godot --path <copy>`, the
  normal entry point with no script, real Windows key events via `keybd_event`, and a
  logging-only observer autoload in the scratch copy):
  - the title showed Continue; **Enter loaded Floor 3 directly**: HP 80/100, HUD
    `W: Slingshot   A: Potion x2   S: —   D: Fists`, Slingshot owned;
  - W (facing down): the stone stopped at the south wall (y = 608); Right, W: it stopped at
    the central wall (x = 352);
  - Up, Right, Down around the wall, then W held 1.4 s: three stones hit the blob **while it
    chased Carl** (it moved from x 736 to 630; hits at x 676, 645, 616) and killed it; Carl
    stayed at 80 HP;
  - the save was unchanged by all of this; the game quit normally; no engine errors.
- **Version 1 migration, for real** (process 3: the same copy, with Phase 5's
  `phase5_save_v1_floor_02.json` as its save, real keys):
  - the title offered Continue for the version 1 save; Enter opened Floor 2 with 70/100 HP,
    `W: —   A: —   S: Potion x2   D: Fists`, no Slingshot;
  - Right moved Carl (x 160 → 235), and S drank a potion (70 → 100 HP, x2 → x1). D was
    pressed too; the observer does not record punches, so punching after a migration is
    checked by `test_save_migration.gd` instead;
  - on entering the floor the file had become `save_version: 2` with the same values and
    `owned_items: []`; nothing else wrote it; no engine errors.
- **Visual check** (screenshots inspected) at 1280×720, 640×360 and 1024×768: the title with a
  Floor 3 save ("Saved at the start of Floor 3 - HP 80 / 100", "Version 0.6.0"); Floor 2 with
  the Slingshot pickup (icon and label); a stone in flight on Floor 3; the menu with Fists,
  the potion and the Slingshot; the Floor 3 signs; GAME OVER. Everything is readable and on
  screen; at 640×360 the HUD text is small but legible, as in earlier phases.

## Known issues / limitations
- **Slingshot / projectiles (placeholders and simplifications):**
  - the stone is a drawn disc with a trail; there is no impact effect, sound or animation;
    the blob's existing hit flash is the only feedback on a hit;
  - stones fly in Carl's facing direction, which follows the last arrow keys held. Holding
    two arrows (a diagonal) fires diagonally, exactly as Fists punch diagonally; there is no
    separate aiming;
  - the stone is a point (a ray), not a disc: it hits whatever its centre line touches. A
    blob's Hurtbox is 28 px wide, so this does not matter for aiming in practice;
  - stones are not saved: quitting mid-flight loses them (like everything mid-floor).
- **Floor 3** is a small combat-test room with two reused Gelatinous Blobs and no exit.
  Its Floor Guardian, Dungeon Brute and prototype-complete exit (GAME_SPEC §14) are later work.
- **The Floor 2 Slingshot pickup reappears after Continue if the save somehow owns it on
  Floor 2** (only possible by editing the save). Walking over it then changes nothing.
- **Save system scope (by design):** one slot; saves only on entering a floor or starting a
  new game, so quitting mid-floor loses that floor's progress (including a Slingshot found
  there); no cloud saves; no save-management UI beyond New Game's confirmation.
- **Save format:** a version 1 file stays version 1 on disk until the next checkpoint
  (Continue writes one immediately). Adding an item or floor needs a line in
  `ActionRegistry` / `FloorRegistry`.
- **Retry slot rule:** a slot the player changed mid-floor keeps the player's latest choice;
  only *empty* slots get their checkpoint action back. Continue restores the checkpoint
  layout exactly.
- **Slot behaviour:** moving an action onto an occupied slot unassigns the action that was
  there (no swap).
- The action menu uses Up/Down + W/A/S/D. GAME_SPEC §8's "Equip" submenu with
  Enter/Left/Right is for a later inventory phase.
- Defeated enemies come back when a floor is retried or continued. This is intended.
- **Carried over from earlier phases:**
  - the Blob chases in a straight line and can stall behind walls (Floor 2's dividing wall,
    Floor 3's central wall). Phase 6 deliberately did not change enemy AI;
  - there is no knockback and no invulnerability after a hit;
  - Donut ignores enemies and cannot be hurt;
  - Escape does nothing outside the menus;
  - there is no way back to the title screen during play (close the window, then Continue);
  - camera limits are not set, and world-space signs can slide under the HUD at the top left;
  - hand-written scenes gain `unique_id` fields the first time the editor saves them.
- Godot's `--check-only -s <script>` reports "Identifier not found" for the scripts that
  name an autoload (`level.gd`, `title_screen.gd`, `save_manager.gd`), because it compiles
  the script before autoloads are registered. They compile fine in the game, the tests and
  the runtime load check. By design, this is not worked around.

## Manual verification required
Your own save is `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json`.
Phase 6 reads a Phase 5 save (version 1) and upgrades it the next time a floor is entered.
1. Open the project in Godot 4.7.2. The Output panel should show no errors.
2. Press **F5**. If you have a Phase 5 save, the title offers **Continue** as before; Enter
   opens your saved floor with the same HP, potions and slots.
3. Play to Floor 2 (New Game if you like: Surface → Floor 1 → Floor 2). In the west room,
   walk over the **Slingshot** (a brown Y with the label "Slingshot").
4. Press **Space**, go **Down** to "Slingshot   (no slot)", press **W**, then **Space**. The
   HUD shows `W: Slingshot`.
5. Face the blob in the east room (arrow keys) from a distance and tap **W**: a small pale
   stone flies straight ahead; each hit takes 10 of the blob's 30 HP (a third of its bar),
   so three hits kill it. Hold **W** to fire every 0.6 s. Shoot at a wall: the stone stops there.
6. Let the blob beat you before the stairs, then press **Enter**: the Slingshot is gone,
   W is empty, and its pickup is back. Pick it up again.
7. Take the stairs in the east room's far corner ("Down to Floor 3"). Floor 3 has the sign
   "Floor 3 - Processing Level"; `W: Slingshot` is still on the HUD. Shoot right from where
   you arrive: the stone stops at the wall, and the blob behind it is unhurt.
8. Close the window. **F5**: the title says "Saved at the start of Floor 3 …". **Enter**
   opens Floor 3 directly with the Slingshot on W, and it fires.
9. On Floor 3, lose to a blob and press **Enter**: the Slingshot stays on W.
10. On the title, New Game (Down, Enter, Down, Enter for Yes) starts over with no Slingshot.

## Next phase
Phase 7 is **not specified** here. Provide its prompt, with acceptance criteria, after
Phase 6 is reviewed.

Groundwork for later phases:
- **More items:** a new ranged weapon is a `ProjectileLauncher` scene with its own
  `Projectile` scene and numbers; a reusable or consumable item is one `.tres` plus a line in
  `ActionRegistry`. Carl never changes.
- **More floors:** a new scene, stairs down from the previous floor, and a line in
  `FloorRegistry`. Floor 3 still needs its exit (Floor Guardian, prototype-complete screen).
- **Save format changes:** bump `SaveManager.SAVE_VERSION` to 3, add `_migrate_version_2()`,
  and chain the migrations in `decode()`.
