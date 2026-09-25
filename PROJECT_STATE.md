# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 7 — Enemy Navigation, Ranged Enemy Combat and Floor 4: **complete, awaiting human
review**.
- Phase 6 — Reusable Weapon, Projectile Combat, Save Migration and Floor 3: complete (commit
  `c2da685`; `08564ea` then added `.vscode/settings.json`).
- Phase 5 — Persistent Save/Load and Continue: complete (commit `fd1d5e7`).
- Phase 4 — Inventory, World Loot, Consumable Action and Floor 2: complete (commit `4ea1123`).
- Phase 3 — Action Slots, Action Menu and Run State: complete (commit `a7ef551`).
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There are no `PHASE_02_*.md` to `PHASE_07_*.md` files. Phases 2–7 came from the owner's
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

Phase 7 decisions (also written into `GAME_SPEC.md` §6, §10, §14a and §15):
- **Enemies navigate.** They follow the level's baked navigation mesh (`EnemyNavigation`), so
  they walk around walls instead of stalling behind them. Detection is unchanged in kind: by
  straight-line distance, never the whole floor.
- **One ranged enemy, the Spitting Blob** (id `spitting_blob`): 30 HP, 60 px/s, notices Carl
  within **360 px**, gives up beyond **480 px**, keeps **180–280 px** away, spits only when Carl
  is within **320 px** and in plain sight, at most every **1.5 s**. No touch attack.
- **Line of sight** is a ray on the `world` layer (the same layer that stops projectiles). It
  never spits at a hidden Carl; it walks around the wall until it sees him.
- **Its spit glob is a Phase 6 `Projectile`**, fired by a Phase 6 `ProjectileLauncher`:
  **10 damage**, **240 px/s**, gone after **384 px** (12 tiles, 1.6 s), stopped by walls.
- **Sides are Hurtbox layers:** stones target `enemy_hurtbox`, globs target `player_hurtbox`.
  A projectile also never hurts its own `source`. Donut has no Hurtbox: nothing can hurt her.
- **Floor 4** (`floor_04`) is below Floor 3 and has no exits. Progression: Surface → Floor 1 →
  Floor 2 → Floor 3 → Floor 4, downward only.
- **The save stays version 2.** Floor 4 adds a floor id, not a new kind of saved data.

## Implemented
- **Title screen** (main scene):
  - **Continue** (available only when the save loads) resumes the saved floor checkpoint;
    a line shows where, for example "Saved at the start of Floor 3 - HP 80 / 100".
  - **New Game** starts a clean run on the Surface (100 HP, no items, no Slingshot, Fists on
    D). If a save file exists, it first asks "Start a new game? Existing progress will be
    replaced." with No selected.
  - An unloadable save shows "Save data could not be loaded." and leaves Continue
    unavailable.
- **Carl** (`scenes/actors/carl.tscn`): **unchanged in Phases 6 and 7.**
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
  Enemies never target her; globs and stones pass her by.
- **Gelatinous Blob** (`scenes/enemies/gelatinous_blob.tscn`): same numbers (30 HP, 55 px/s,
  notices Carl within 220 px, gives up beyond 320 px, touch damage 10 every 0.8 s). **Phase 7:**
  it now follows the navigation mesh, so it walks around walls to reach Carl. Fists and stones
  damage it through the same `Hurtbox` → `Health`.
- **Spitting Blob (Phase 7,** `scenes/enemies/spitting_blob.tscn`**):** a purple, spiky blob with
  a spout that turns toward Carl. 30 HP; it spits `scenes/projectiles/spit_glob.tscn` (a violet
  teardrop glob with a trail) through its `SpitLauncher`, a `ProjectileLauncher` (1.5 s). See
  Architecture > Enemies.
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
  - the sign "Floor 3 - Processing Level", HUD and menu;
  - **Phase 7:** **stairs down to Floor 4** at (928, 544), the far south-east corner, labelled
    "Down to Floor 4". The second sign (now `Signs/Hint`) says where they are; it used to say
    the way down was not built. No stairs back up.
- **Floor 4 (Phase 7,** `scenes/levels/floor_04.tscn`**, 36×20 tiles, 1152×640 px):**
  - Carl arrives at (160, 320), Donut at (104, 332);
  - **wall A** (2×6 tiles, x 352–416, y 224–416) 6 tiles east of the spawn point, with room to
    walk around either end; the **Gelatinous Blob** at (512, 320) behind it. It notices Carl
    once he nears wall A and has to walk around it;
  - **wall B** (2×6 tiles, x 736–800, y 224–416) in front of the **Spitting Blob** at (896, 320):
    from between the walls it cannot see Carl, so it has to walk around wall B first;
  - two 2×2 pillars (x 544–608, y 96–160 and y 480–544) for cover;
  - the signs "Floor 4 - Filtration Level", "Prototype: the way further down is not built
    yet." and "Spit cannot pass through walls. Use them as cover.", HUD and menu;
  - **no exits**: no way up, and Floor 5 is out of scope.
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

Not implemented (later phases): ammunition, other weapons, equipment stats, Floor 5, other
enemy types (Dungeon Rat, Crawler, Dungeon Brute), bosses (Floor Guardian), the
prototype-complete screen, Donut combat/damage/stun, shops/economy, multiple save slots,
mid-floor or cloud saving, pause menu.

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
1 s while it can heal. Pickups need no key. No input actions were added in Phases 3–7.

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
scenes/projectiles/spit_glob.tscn               The Spitting Blob's Projectile (Phase 7)
scenes/ui/title_screen.tscn                     Main scene: Continue / New Game menu, overwrite confirmation
scenes/ui/hud.tscn                              HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action/inventory menu (CanvasLayer 10)
scenes/actors/carl.tscn                         Carl: Health, Hurtbox, Camera2D (performers added at run time)
scenes/actors/donut.tscn                        Donut + NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack), NavigationAgent2D (EnemyNavigation)
scenes/enemies/spitting_blob.tscn               Spitting Blob (Phase 7): Health, Hurtbox, SpitLauncher (ProjectileLauncher), NavigationAgent2D
scenes/props/stairs.tscn                        Reusable stairs down
scenes/props/item_pickup.tscn                   Reusable world pickup (item + quantity; icon or default gem)
scenes/levels/surface.tscn, floor_01.tscn … floor_04.tscn   The five levels (floor_04: Phase 7)
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
scripts/combat/projectile.gd                    class Projectile: flies, stops at walls, hits one target (Phase 6; source rule Phase 7)
scripts/enemies/enemy.gd                        class Enemy: what every enemy shares (activity, navigation, sight, hit flash, death) (Phase 7)
scripts/enemies/enemy_navigation.gd             class EnemyNavigation (a NavigationAgent2D): which way to move to reach a goal (Phase 7)
scripts/enemies/gelatinous_blob.gd              The Gelatinous Blob (an Enemy): chase and touch
scripts/enemies/spitting_blob.gd                The Spitting Blob (an Enemy): keep distance, spit when in sight (Phase 7)
scripts/levels/level.gd                         class Level: run-state wiring, GAME OVER, retry
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/props/item_pickup.gd                    Walk-over pickup: gives its item to Carl once
scripts/<actors|enemies|props|ui>/*.gd          One script per scene that needs one
tests/                                          Test scripts (not part of the game), see Tests
tests/fixtures/                                 Real save files from earlier phases: two save_version 1 (Phase 5) and two save_version 2 (Phase 6)
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
│   ├── enemies          e.g. GelatinousBlob, SpittingBlob, each with target = ../Carl
│   └── (projectiles)    Stones and globs are added here while they fly
├── HUD                  hud.tscn instance
└── ActionMenu           action_menu.tscn instance
```
**To add a floor:** duplicate `floor_04.tscn` (or another floor), then:
1. Repaint Terrain and resize the NavigationPolygon outline.
2. Place Carl (the entry point) and Donut, and the enemies (set each enemy's `target` to Carl).
3. Add pickups and stairs down, if any.
4. Point the previous floor's stairs down at the new file. Never add stairs back up.
5. Add one line to `FloorRegistry`, so the floor can be saved and continued. (Floor 4 needed
   nothing else: no save format change, no level or title code.)

**To add an enemy:** make a scene whose root script `extends Enemy` (scripts/enemies/enemy.gd),
with the children Enemy expects (Health, Hurtbox on `enemy_hurtbox`, CollisionShape2D on
`enemy`, NavigationAgent2D with `enemy_navigation.gd`, a unique HealthBarFill), plus its attack
nodes (a MeleeAttack, a ProjectileLauncher with its own projectile scene, …). Its
`_physics_process()` combines `update_activity()`, `navigate_toward()`, `stop_moving()` and
`has_line_of_sight_to()`. Place it in a level's Actors with `target` = Carl. No level code changes.

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

### Projectiles (`Projectile`, `scripts/combat/projectile.gd`, Phase 6, shared since Phase 7)
- A plain Node2D (not a physics body) with `damage`, `speed`, `max_distance`,
  `target_layers` (whom it may hurt) and `blocking_layers` (what stops it), the `direction`
  set by `launch()`, and (Phase 7) its `source`, whoever fired it. Emits `stopped(collider)`
  once (null when it ran out of range).
- **Two kinds, one class** (Phase 7). Each is just a scene with its own numbers and look:

  | Projectile | Fired by | `target_layers` | Damage | Speed | Range | Look |
  |------------|----------|-----------------|--------|-------|-------|------|
  | `slingshot_stone.tscn` | Carl's Slingshot | `enemy_hurtbox` | 10 | 480 px/s | 320 px (40 ticks) | pale round stone, short trail |
  | `spit_glob.tscn` | a Spitting Blob's SpitLauncher | `player_hurtbox` | 10 | 240 px/s | 384 px (96 ticks) | violet teardrop, longer trail |

  Both are fired by a `ProjectileLauncher`, which sets `source = user`, adds the projectile to
  the user's parent (the level's Actors) and launches it from the user's centre.
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
- **Sides (factions) are Hurtbox layers.** A stone looks for `enemy_hurtbox` only, so it can
  hurt enemies and never Carl (`player_hurtbox`). A glob looks for `player_hurtbox` only, so
  it can hurt Carl and never the blob that spat it or any other enemy: its ray does not even
  report enemy Hurtboxes. Donut has no Hurtbox and her body's `companion` layer is in neither
  mask, so neither kind can hurt her or stop at her. Pickups and stairs detect only the
  `player` body, which a projectile is not. No scene-specific collision exceptions are used.
- **Source rule (Phase 7):** on top of the layers, a projectile skips any Hurtbox inside its
  `source` (`source.is_ancestor_of(hurtbox)`). A glob starts inside its own blob's Hurtbox, so
  this keeps a blob safe from its own spit even if a glob were ever given enemy layers too
  (tested). The source may be gone (a blob that died while its glob flies); that is checked.
- **Glob numbers:** 240 px/s is 4 px per tick. At the Spitting Blob's usual 180–280 px, a glob
  takes 0.75–1.2 s to arrive, while Carl walks 135–210 px in that time: a Carl who keeps moving
  across its line dodges it, a Carl who stands still or walks straight at it is hit. 384 px
  (12 tiles) is more than its 320 px firing range, so a glob spat at the edge of that range
  still arrives even if Carl steps back a little, and it never crosses the whole screen.
- **Numbers:** 480 px/s (fast, but still easy to follow at 8 px per tick) and 320 px range
  (10 tiles: well inside the 853×480 px the camera shows at zoom 1.5, and longer than a blob's
  220 px detection range, so a careful player can hit a blob before it notices him).

### Enemies (Phase 7, `scripts/enemies/`)
Composition first, with one thin shared base:
- **`Enemy`** (`enemy.gd`, extends CharacterBody2D): what every enemy has in common, lifted out
  of the Phase 6 Blob script. Exports `target`, `move_speed`, `detection_range`, `chase_range`,
  `sight_blocking_layers` (`world`), `death_fade_time`. Provides:
  - `update_activity()`: active once the target is within `detection_range` (straight-line
    distance), inactive beyond `chase_range`, and inactive while the target is down (0 HP);
  - `navigate_toward(goal)` / `stop_moving()`: move the body with `move_and_slide()` in the
    direction `EnemyNavigation` gives, at `move_speed`;
  - `has_line_of_sight_to(point)`: a ray from the enemy's centre on `sight_blocking_layers`.
    Donut, other enemies and Carl's body do not block it (they are not on `world`);
  - hit flash, health bar, and dying (stop, stop blocking, fade, free), as before.
  Each enemy writes its own `_physics_process()` from these. There is no enemy-type `match`
  anywhere; levels only place enemy scenes and set their `target`.
- **`EnemyNavigation`** (`enemy_navigation.gd`, extends NavigationAgent2D, one per enemy scene,
  `path_desired_distance` 6): `get_move_direction(goal)` sets the agent's target (a new path
  each tick, cheap on these levels, so it follows a moving Carl) and returns the direction to
  the next path corner. The levels already bake a navigation mesh on load
  (`level_navigation.gd`, agent radius 14 px; Donut uses it too), and both enemy bodies are
  13 px, so every path has room for them.
  - When the path ends (the goal is inside a wall, or across a wall with no way round) it
    returns zero: the enemy stops at the nearest point instead of pushing into the wall.
  - Before the navigation map is built (the level's first physics frames) it returns zero.
  - In a world with **no navigation mesh at all** (the test arenas, which have no level) it
    returns the straight direction to the goal, which is exactly the Phase 6 behaviour. Walls
    still stop the body there. Every level has a mesh, so this never applies in the game.
- **Gelatinous Blob** (`gelatinous_blob.gd`): active: `navigate_toward(Carl)`; otherwise it
  stands still. Its `ContactAttack` (MeleeAttack, `player_hurtbox`) hits whatever it touches,
  as before.
- **Spitting Blob** (`spitting_blob.gd`), each physics tick while active:
  1. if Carl is in sight and within `max_firing_distance` (320 px), `SpitLauncher.perform()`
     toward him; the launcher refuses while cooling down (90 ticks), so there is one glob per
     cooldown and never one at a hidden Carl;
  2. move: toward Carl (along the mesh) if he is hidden or farther than 280 px; away from him
     (toward a point 48 px behind itself, along the mesh) if closer than 180 px; otherwise
     stand still. The spout (`%Mouth`) turns toward Carl.
  So a hidden Carl makes it walk around the wall; as soon as it can see him it spits.
- **Pause and GAME OVER:** enemies, their launchers and their projectiles are ordinary
  pausable nodes, so the tree pause that the menu and GAME OVER already use freezes all of
  them. Cooldowns count physics ticks, which do not run while paused, so nothing is saved up:
  after a pause the next glob comes exactly one cooldown of running time after the last.
- **Not saved:** enemy HP, positions, activity, paths, cooldowns and projectiles are level
  state. A retry or Continue reloads the level, so enemies start as authored.

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
- Gelatinous Blob: 30 HP, speed 55, detection 220, chase 320, touch damage 10 every 0.8 s
  (straight-line pursuit until Phase 7; it now navigates).

## Collision layers/masks
Names are set in Project Settings > Layer Names > 2D Physics.

| Layer | Name             | Used by                                    | Mask (collides with / detects)           |
|-------|------------------|--------------------------------------------|------------------------------------------|
| 1     | `world`          | Wall/barrier tiles (TileSet physics layer) | none (static)                            |
| 2     | `player`         | Carl's body                                | 1 `world`, 4 `enemy`                     |
| 3     | `companion`      | Donut's body                               | 1 `world` only                           |
| 4     | `enemy`          | Enemy bodies (both blobs)                  | 1 `world`, 2 `player`, 4 `enemy`         |
| 5     | `player_hurtbox` | Carl's Hurtbox (Area2D)                    | none; found by enemy attacks' shape query |
| 6     | `enemy_hurtbox`  | Enemy Hurtboxes (Area2D)                   | none; found by Carl's Fists and stones   |
| —     | (none)           | Stairs (Area2D, `monitorable` off)         | 2 `player`: only Carl triggers them      |
| —     | (none)           | Item pickups (Area2D, `monitorable` off)   | 2 `player`: only Carl collects them      |
| —     | (none)           | Slingshot stones (Node2D, Phase 6)         | ray query: 6 `enemy_hurtbox` (hit) and 1 `world` (stops) |
| —     | (none)           | Spit globs (Node2D, Phase 7)               | ray query: 5 `player_hurtbox` (hit) and 1 `world` (stops) |
| —     | (none)           | Enemy line of sight (Phase 7)              | ray query: 1 `world` only                |

Consequences:
- Carl and the blobs block each other.
- Donut collides only with walls, and she can neither trigger stairs nor collect pickups.
- Carl's Fists and stones target layer 6 only; the Blob's touch and the globs target layer 5
  only. So Carl's attacks never hurt Carl or Donut, and enemy attacks never hurt enemies or
  Donut.
- Stones and globs are stopped by layer 1 only: they fly over Donut, other bodies, pickups and
  stairs. Enemies see through everything but walls, exactly where their globs can fly.
- Navigation baking reads only layer 1.

## Earlier behaviour changed in Phase 7
1. **The Gelatinous Blob navigates** instead of pushing straight at Carl. Its numbers,
   detection and touch damage are unchanged, and the Phase 2–6 tests that fight blobs pass
   unchanged. In a test arena without a navigation mesh it still moves straight (see
   Architecture > Enemies), so `test_combat.gd`'s exact pursuit-speed and wall checks still hold.
2. **An enemy whose target is down stops chasing** (`Enemy.update_activity()`). Before, a blob
   kept pressing a downed Carl (it could not hurt him, and the game is paused at GAME OVER
   anyway). It keeps the Spitting Blob from ever spitting at a downed Carl.
3. **Floor 3 has an exit** (stairs down to Floor 4) and its second sign changed (node
   `Signs/PrototypeNote` became `Signs/Hint`). `test_slingshot_run.gd` checked that Floor 3 had no
   exits; it now checks that its only exit leads down to Floor 4 (still nothing leads up).
   `test_windowed_resolutions.gd` checks `Signs/Hint` instead of `Signs/PrototypeNote`.
4. **`FloorRegistry` has five floors.** `test_save_manager.gd` expected exactly four; it now
   expects `floor_04` too (and rejects `floor_05`).
5. **The "no target" warning** now reads "Enemy '...' has no target set" (it lives in `Enemy`).
6. Version in Project Settings: `0.7.0`.

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process. A test fails on a non-zero exit
code or on any engine ERROR/WARNING in its output. Tests with "windowed" in their name get a
real window, which opens briefly. The full run takes about 7 minutes. Each test file can
also be run on its own; the first lines of each file give the command.

| Test file                               | Covers |
|-----------------------------------------|--------|
| `test_input_map.gd` (Phase 0)           | Every action bound to its key; no key shared between actions |
| `test_carl_movement.gd` (Phase 1, 3)    | Exact speed per arrow key, normalized diagonals, facing, tick-rate independence; W/A/S/D never move Carl |
| `test_surface_traversal.gd` (Phase 1)   | Title → Surface, wall collision, Donut following, stairs → Floor 1, Floor 1 walls |
| `test_combat.gd` (Phase 2, 3)           | Health; Fists on D: facing, diagonals, no self-hit, Donut unaffected, W/A/S empty, exact cooldown; Blob pursuit, walls, contact damage, death (in an arena with no navigation mesh); HUD HP; downed Carl |
| `test_action_slots.gd` (Phase 3, 4)     | New-game layout; ActionSlots rules; Carl follows reassignment live; cooldown not reset by moving; a test-only second action works next to Fists; HUD slot bar |
| `test_action_menu.gd` (Phase 3)         | Space opens/pauses, Space/Escape close; nothing focused; Carl/Donut frozen while open; reassigning through the menu; no free punch/step across close; blob frozen while open; no menu over GAME OVER |
| `test_floor_loop.gd` (Phase 2, 3)       | Title → new game; reassignment; HP and slots carried to Floor 1; no transition loop; nothing on Floor 1 leads up; real fight and defeat; GAME OVER waits; retry with entry HP; stairs ignore an arrival on top of them |
| `test_inventory.gd` (Phase 4)           | Inventory rules, slots follow the inventory, potion use through a slot, one potion per press, menu quantities, pickups (Donut/enemy can't take them, two collectors) |
| `test_inventory_run.gd` (Phase 4, 5)    | Real potions run through Floor 1 → Floor 2 with retries; Floor 2's only exit leads down (Phase 6) |
| `test_save_manager.gd` (Phase 5–7)      | Registries (5 floors, `floor_04` shown as "Floor 4"); version 2 JSON (owned_items); a Floor 3 checkpoint with the Slingshot on W round-trips; **a Floor 4 checkpoint has exactly a Floor 3 checkpoint's fields, save_version 2, and round-trips**; 41 kinds of bad data rejected with the file untouched (incl. versions 3/999, `floor_05`, Slingshot with a quantity, owned_items not a list/unknown/number/scene path/consumable/innate/duplicate); slots sanitized (incl. an unowned Slingshot); delete; interrupted-save recovery |
| `test_save_game.gd` (Phase 5, 6)        | Real title + levels: checkpoints (save_version 2), Continue, deaths, New Game confirmation, corrupt/unsupported saves |
| `test_save_migration.gd` (Phase 6, 7)   | **Phase 7: the two real Phase 6 fixtures (version 2, Floor 2 and Floor 3 with the Slingshot) load with their floor, HP, items and slots, the files untouched, and Phase 7 encodes both checkpoints to byte-identical files (no format change).** The two real Phase 5 fixtures load (floor, HP, potions, slots kept; no Slingshot; file untouched); a v1 Slingshot slot is emptied, a v1 `owned_items` ignored, a v1 Slingshot quantity rejected; 13 kinds of malformed v1 data rejected; v2 loads, v2 without owned_items and versions 0/3/999/-1 rejected; title → Continue on the v1 Floor 2 save opens Floor 2 with its state, the file becomes version 2 with the same values, and the game plays on (walk, punch, potion, pick up the Slingshot) |
| `test_slingshot.gd` (Phase 6)           | Ownership model (innate/reusable/consumable, owned once, never removed, snapshots, new run clears it); slots (not before owning, W/A/S/D, one slot, next to Fists and potion, emptied when taken back); pickup (label, icon, Donut/enemy can't take it, disappears, once, two collectors, second pickup); firing right/up/left/down from Carl, empty slots fire nothing; exactly 10 damage, 3 hits kill a 30 HP blob, the stone is gone on the hit; one target only; flies through a dying blob; **hits a blob that steps onto it**; stops at a wall face, blob behind it safe; 320 px / 40 ticks / 8 px per tick; never hurts Carl or Donut, no pickup, no stairs; point blank; cooldown (short press 1, held 3 at exactly 36 ticks, taps can't go faster, moving keeps the cooldown, nothing used up); menu (stone frozen, W in the menu fires nothing, resumes and hits, no free shot on close, key released inside not stuck); HUD and menu labels, shooting changes nothing, potion unaffected |
| `test_slingshot_run.gd` (Phase 6, 7)    | Real run: New Game clears a previous Slingshot; Surface → Floor 1 → Floor 2 → Floor 3, nothing leads up (Floor 3's only exit leads down to Floor 4); Floor 2 entry has no Slingshot (run, entry state, disk); collect + W doesn't save; two Floor 2 deaths take it back (pickup back, W empty, no duplicates); quit before Floor 3 → Continue without it; three stones kill the Floor 2 blob; Floor 3 arrival (spawn, Donut, camera, sign, only exit down, no loop), the Floor 3 checkpoint in memory and on disk owns it with W = Slingshot; a stone stops at Floor 3's wall tiles, blob behind safe; two Floor 3 deaths keep it on W; Continue opens Floor 3 directly and it fires (three stones kill a blob); New Game clears it |
| `test_windowed_resolutions.gd` (Phase 2–7) | At 1280×720, 640×360, 1024×768: HUD with `W: Slingshot   A: Potion x2`, GAME OVER panel, action menu, camera; the Slingshot pickup and label on screen from Floor 2's spawn; Floor 3's signs on screen and clear of the HUD; a flying stone drawn on screen; **Floor 4's three signs clear of the HUD; the Gelatinous Blob, the Spitting Blob, a glob and a stone drawn on screen together; the two blobs differ (colour, spikes, spout)**; the title screen (with a Floor 4 save) and its confirmation. Prints SKIP and passes when run headless |
| `test_enemy_navigation.gd` (Phase 7)    | Arenas with a real baked navigation mesh, each waiting until the map holds exactly its mesh: the Blob waits beyond 220 px, notices Carl behind a wall, gives up beyond 320 px; with a wall between them it follows a route around the wall (its own path bends round the wall's end), passes the end, never overlaps the wall, gets closer every half second, reaches Carl and hurts him every 0.8 s; with no way around it stops beside the wall without jittering and never gets through; the Spitting Blob with Carl hidden walks around the wall, never overlaps it, spits only once it sees him, and every glob reaches Carl (none on the wall); neither enemy notices or targets Donut |
| `test_spitting_blob.gd` (Phase 7)       | Arenas: its numbers (30 HP, 360/480 px, 180–280 px, 320 px, 1.5 s, no touch attack; glob 10 / 240 px/s / 384 px, `player_hurtbox` only); waits beyond 360 px, closes in and spits at 320 px, holds at 280 px, backs off to 180 px, gives up beyond 480 px; touching it never hurts (only globs do); a wall stops it spitting for 4 s and no glob hits the wall, stepping into sight or removing the wall makes it spit at once, straight at Carl; a glob takes exactly 10 HP once and is gone; walls stop globs (also one already in flight); a glob flies past stairs, a pickup, another Spitting Blob, a Gelatinous Blob and Donut and hits Carl, hurting none of them nor its own blob, even when made to target enemies; 384 px / 96 ticks / 4 px per tick; 5 globs in 6 s exactly 90 ticks apart, one glob per shot, no burst after hiding; three stones kill it, a stone still hurts a blob, Fists hit it only facing it; the menu freezes both enemies, a glob and a stone, spits nothing, W fires nothing, and after closing the next glob comes exactly 90 running ticks after the last, with no free stone and no burst |
| `test_floor_04_run.gd` (Phase 7)        | Real run from a real Phase 6 Floor 3 save: title → Continue → Floor 3 (same checkpoint saved again); every level's exits lead one floor down, Floor 4 has none; Floor 3 → Floor 4: spawn, Donut, camera, sign, one Blob and one Spitting Blob, checkpoint in memory and on disk (floor_04, version 2), walls that block the straight line and hide the Spitting Blob, no loop, enemies idle; the Blob walks around wall A and three punches kill it; the Spitting Blob walks around wall B and spits only in sight, the menu freezes it and its glob, the glob then takes 10 HP; globs take Carl to 0 HP, GAME OVER freezes everything for 3 s and waits, death does not save; retry restores HP, items, slots and both enemies, with no globs left; GAME OVER with a glob in flight freezes it; three stones kill the Spitting Blob; quit and Continue: title shows Floor 4, Continue opens it directly with HP 70, 2 potions, the Slingshot and the slots, enemies back as authored, globs still take 10 HP; New Game starts clean |

Every test uses its own save file under `user://test_saves/` (see Persistent save).

## Validation performed (Phase 7)
All runs used Godot 4.7.2.stable.official on this machine (NVIDIA GeForce GTX 750 Ti, OpenGL
3.3, Compatibility renderer, 60 Hz). Every run that could write a save used an isolated
user-data folder (scratch copies with `config/custom_user_dir_name`), or the tests' own
`user://test_saves/` files. The one exception was a mistake, described below.
- **Baseline before changes:** the Phase 6 suite at HEAD `08564ea` passed 15 of 15 (4 min 51 s).
- **Version 2 fixtures from the real Phase 6 code:** a throwaway `git worktree` of `08564ea`
  (with its own user-data folder) set up two runs and entered Floor 2 and Floor 3, so Phase 6's
  own `Level` and `SaveManager` wrote `tests/fixtures/phase6_save_v2_floor_02.json` and
  `..._floor_03.json` exactly as in play. Phase 6 loaded both back. The worktree was removed.
- **Clean import:** a copy without `.godot/` imported in the headless editor with no errors or
  warnings. All 71 scripts, scenes and resources load, and all 19 scenes instantiate.
- **Strict parse check:** all 71 files still load with the 37 default-enabled GDScript warnings
  raised to errors (scratch copy). A planted unused variable made its script fail to load,
  which shows the check works.
- **Test suite:** `run_all.gd` passed 18 of 18 (7 min 14 s) on the final code, and 18 of 18 on
  an earlier full run. The three new files are `test_enemy_navigation.gd`,
  `test_spitting_blob.gd` and `test_floor_04_run.gd`.
- **The player's save folder: one mistake, undone.** A scratch probe script (checking Floor 4's
  lines of sight) was run once against the real project without save isolation. Loading
  Floor 4 made `Level._ready()` write a Floor 4 checkpoint to the real
  `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json`. There was no
  save file there when Phase 7 work began. The file was checked (the probe's own checkpoint:
  Floor 4, 100 HP, no items) and deleted, so the folder is back as it was, with no
  `savegame.json`. Every later ad-hoc run used a scratch copy with its own user-data folder.
  `test_saves/` is empty after the suite.
- **Mutation checks:** 15 regressions were injected, one at a time, into a throwaway copy (own
  user-data folder), and each was restored afterwards. Each run used the five test files Phase 7
  touches most (`test_enemy_navigation`, `test_spitting_blob`, `test_floor_04_run`,
  `test_save_manager`, `test_save_migration`), which all passed in the copy first. Every
  regression made at least one of them fail:
  - the Blob back to straight-line pursuit (navigation: it stalls at 417 px, its path does not
    bend round the wall; Floor 4 run: it never reaches Carl around wall A);
  - the Spitting Blob ignoring line of sight (globs wasted on the wall while Carl hides);
  - a glob that hurts Donut (she was given a Hurtbox on `player_hurtbox`);
  - a glob stopped by Donut (`companion` made a target layer);
  - a glob that hurts other enemies (`enemy_hurtbox` made a target layer);
  - projectiles passing through walls;
  - a 0.75 s spit cooldown;
  - globs that keep flying while the game is paused;
  - a Spitting Blob that keeps acting while the game is paused;
  - `floor_04` missing from `FloorRegistry` (the checkpoint stays Floor 3);
  - stairs back up from Floor 4 to Floor 3;
  - a projectile allowed to hurt its own source;
  - the save format bumped to version 3 with nothing new stored;
  - enemies that never give up the chase;
  - a Spitting Blob that notices Carl anywhere on the floor.
- **Real playthrough** (process 1: the isolated scratch copy in a real 1280×720 window,
  started from the real Phase 6 Floor 3 save, driven by key events through Godot's input
  pipeline, arrow keys steered along navigation routes; screenshots inspected):
  1. title: "Saved at the start of Floor 3 - HP 70 / 100" → Continue → Floor 3 with HP 70,
     `W: Slingshot   A: —   S: Potion x2   D: Fists`; the menu moved the potion to A, and
     A drank one (70 → 100);
  2. the south route to the new stairs → Floor 4: Carl at (160, 320), Donut 57 px away, the
     Blob and the Spitting Blob idle where authored; the save on disk became `floor_04`,
     version 2, 100 HP, 1 potion on A, the Slingshot owned and on W;
  3. the Blob noticed Carl and **walked around the south end of wall A** ((478, 366) →
     (445, 410) → (399, 429) → (344, 430) → (321, 380)) to reach him; three punches killed it
     (Carl 100 → 80);
  4. between the walls, hidden from the Spitting Blob, nothing was spat for 3 s; it **walked
     round the north end of wall B** to (762, 210) and spat as soon as it saw Carl (232 px);
  5. the menu opened with the glob in flight: the glob and the Spitting Blob stayed frozen for
     1.5 s; after closing, the glob hit (80 → 70) and the next came one cooldown later;
  6. from cover the Spitting Blob could not see Carl and repositioned ((698, 200) → (638, 191)
     → (579, 182)) before spitting again; a dodged glob stopped on the wall tiles;
  7. globs took Carl to 0 HP: GAME OVER, everything frozen 3 s later; Enter restored HP 100
     and both enemies as authored (30 HP, idle);
  8. along the north route, lined up diagonally, three Slingshot stones killed the Spitting
     Blob; the save was unchanged by all of this; quit normally (exit 0), no engine errors.
- **Real process restart** (process 2: a fresh `godot --path <copy>`, the normal entry point
  with no script, real Windows key events via `keybd_event` sent only while the game window
  was in front, and a logging-only observer autoload in the scratch copy):
  - the title showed "Saved at the start of Floor 4 - HP 100 / 100"; **Enter loaded Floor 4
    directly**: HP 100/100, `W: Slingshot   A: Potion x1   S: —   D: Fists`, Donut 57 px
    from Carl, the Blob at (512, 320) and the Spitting Blob at (896, 320) with 30 HP, idle;
  - Up then Right took Carl along the north wall to (700, 44); the Spitting Blob noticed him
    at 319 px, came round to 279 px and spat at 11.66, 13.16, 14.66, 16.16 and 17.66 s
    (exactly 1.5 s apart); every glob took 10 HP (100 → 60);
  - W fired a stone to the right; A drank the potion (60 → 90, `A: —`);
  - the save was unchanged; Alt+F4 closed the game normally (exit 0); no engine errors.
- **Version 1 migration, for real** (process 3: the same copy with Phase 5's
  `phase5_save_v1_floor_02.json` as its save, real keys): the title offered "Saved at the
  start of Floor 2 - HP 70 / 100"; Enter opened Floor 2 with 70 HP and
  `W: —   A: —   S: Potion x2   D: Fists`; the file became `save_version: 2` with the same
  values and `owned_items: []`; Alt+F4, exit 0, no engine errors.
- **Visual check** (screenshots inspected) at 1280×720, 640×360 and 1024×768: Floor 4 on
  arrival (signs clear of the HUD); the Blob, the Spitting Blob, a glob and a stone on screen
  together; the action menu over frozen combat; GAME OVER on Floor 4; the title with a
  Floor 4 save ("Version 0.7.0"). The green round Blob and the purple spiky Spitting Blob
  with its spout are easy to tell apart, as are the violet teardrop glob and the pale stone.
  Everything is readable and on screen; at 640×360 the HUD text is small but legible, as in
  earlier phases.
- **No game bug was found** by the playthroughs. Test and driver problems found while
  writing them were fixed there (for example, the navigation map keeps the previous
  arena's mesh for a few physics frames, so the navigation tests wait until the map holds
  exactly their own mesh).

## Known issues / limitations
- **Enemies (Phase 7 simplifications):**
  - detection is by straight-line distance, not sight (as in Phase 2): a Blob notices Carl
    through a wall, and a Spitting Blob notices a hidden Carl and walks round to find him.
    Only spitting needs line of sight;
  - line of sight is one ray from the Spitting Blob's centre to Carl's centre. If only the edge
    of Carl shows past a wall, it counts him as hidden;
  - globs fly at where Carl is when spat and do not lead a moving target, so a Carl who keeps
    moving across its line dodges them. This is intended;
  - enemies do not steer around each other or Donut (no navigation avoidance). Two enemies
    push and slide along each other, and they pass through Donut, whose `companion` layer is
    not in their mask;
  - a cornered Spitting Blob cannot back away further; it stays where it is and keeps spitting;
  - each enemy asks for a new path every physics tick. That is cheap on these small floors;
    big floors with many enemies may want a slower re-path rate;
  - a level must bake its navigation mesh (every level does, via `level_navigation.gd`).
    Without one, `EnemyNavigation` falls back to straight-line pursuit, which is what the
    test arenas rely on. A future level that forgot its mesh would not fail loudly;
  - the mesh is baked for a 14 px agent radius. Both blobs are 13 px; a bigger enemy would
    need its own mesh;
  - there is no spit sound, splash, or wind-up animation. The spout turning toward Carl is the
    only tell.
- **Projectiles (placeholders and simplifications):**
  - the stone and the glob are drawn shapes with trails; there is no impact effect, sound or
    animation; the hit flash (and Carl's HP) is the only feedback on a hit;
  - stones fly in Carl's facing direction, which follows the last arrow keys held (diagonals
    included); there is no separate aiming;
  - a projectile is a point (a ray), not a disc: it hits whatever its centre line touches;
  - projectiles are not saved: quitting mid-flight loses them (like everything mid-floor).
- **Floors 3 and 4 are small combat-test rooms.** Floor 4 has no exit ("Prototype: the way
  further down is not built yet."). The Floor Guardian, Dungeon Brute and prototype-complete
  exit (GAME_SPEC §14) are later work.
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
  - there is no knockback and no invulnerability after a hit (a glob and a Blob's touch can
    land in the same moment);
  - Donut does not fight and cannot be hurt; enemies ignore her;
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
Phase 7 reads Phase 5 (version 1) and Phase 6 (version 2) saves; the save format is unchanged.
1. Open the project in Godot 4.7.2 and let it import the new files. The Output panel should
   show no errors.
2. Press **F5**. With a Phase 6 save, **Continue** opens your saved floor as before.
3. Play to Floor 3 (New Game: Surface → Floor 1 → Floor 2, where the Slingshot is → Floor 3).
   Floor 3's sign now says the stairs down are in the far south-east corner. Take them
   ("Down to Floor 4").
4. Floor 4, "Filtration Level", has two brick walls across the middle. Walk toward the first
   wall: the green Gelatinous Blob comes **around the end of the wall** instead of sticking
   to it. Punch it (D) or shoot it (W).
5. The purple, spiky **Spitting Blob** waits behind the second wall. While the wall hides
   you, it spits nothing; it walks around the wall until it can see you, then spits a violet
   glob about every 1.5 s. Each glob takes 10 HP. Step behind a wall: the globs stop on it.
   Keep moving sideways: the globs miss.
6. Walk up to it: it backs away to keep its distance, and touching it never hurts.
7. Press **Space** while a glob is flying: everything freezes. Close the menu: the glob flies
   on, and no extra glob appears.
8. Three stones or three punches kill it.
9. Let the globs beat you: GAME OVER freezes everything. **Enter** restarts Floor 4 with both
   blobs back.
10. Close the window. **F5**: the title says "Saved at the start of Floor 4 …". **Enter** opens
    Floor 4 directly with your HP, items and slots from when you arrived.
11. On the title, New Game (Down, Enter, Down, Enter for Yes) still starts over on the Surface.

## Next phase
Phase 8 is **not specified** here. Provide its prompt, with acceptance criteria, after
Phase 7 is reviewed.

Groundwork for later phases:
- **More enemies:** a scene whose root script extends `Enemy` and writes its own
  `_physics_process()` from `update_activity()`, `navigate_toward()`, `stop_moving()` and
  `has_line_of_sight_to()`, with `Health`, a `Hurtbox` on `enemy_hurtbox`, an
  `EnemyNavigation` agent, and its attack (a `MeleeAttack` or a `ProjectileLauncher` with its
  own `Projectile` scene on `player_hurtbox`). Levels only place it and set its `target`.
- **More items:** a new ranged weapon is a `ProjectileLauncher` scene with its own
  `Projectile` scene and numbers; a reusable or consumable item is one `.tres` plus a line in
  `ActionRegistry`. Carl never changes.
- **More floors:** a new scene, stairs down from the previous floor (Floor 4 has none yet),
  and a line in `FloorRegistry`.
- **Save format changes:** bump `SaveManager.SAVE_VERSION` to 3, add `_migrate_version_2()`,
  and chain the migrations in `decode()`. Phase 7 needed none.
