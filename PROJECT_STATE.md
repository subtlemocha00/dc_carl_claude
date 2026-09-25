# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 8 — Donut Health, Companion Combat, Enemy Targeting, Save v3 and Floor 5: **complete,
awaiting human review**.
- Phase 7 — Enemy Navigation, Ranged Enemy Combat and Floor 4: complete (commit `02b1fb2`).
- Phase 6 — Reusable Weapon, Projectile Combat, Save Migration and Floor 3: complete (commit
  `c2da685`; `08564ea` then added `.vscode/settings.json`).
- Phase 5 — Persistent Save/Load and Continue: complete (commit `fd1d5e7`).
- Phase 4 — Inventory, World Loot, Consumable Action and Floor 2: complete (commit `4ea1123`).
- Phase 3 — Action Slots, Action Menu and Run State: complete (commit `a7ef551`).
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There are no `PHASE_02_*.md` to `PHASE_08_*.md` files. Phases 2–8 came from the owner's
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
  at the next checkpoint save, which Continue triggers at once by opening the floor. (Version 3
  since Phase 8, which adds Donut's HP; versions 1 and 2 are migrated to it the same way.)

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
  A projectile also never hurts its own `source`. Donut had no Hurtbox, so nothing could hurt
  her (superseded in Phase 8: her Hurtbox is on `player_hurtbox`, so enemy attacks can, and
  player attacks still cannot).
- **Floor 4** (`floor_04`) is below Floor 3 (Phase 8 added its stairs down to Floor 5).
  Progression is downward only.
- **The save stays version 2** in Phase 7: Floor 4 adds a floor id, not a new kind of saved
  data. (Phase 8's Donut HP is new saved data, hence version 3.)

Phase 8 decisions (also written into `GAME_SPEC.md` §6, §10, §14a, §14b and §15):
- **Donut has 60 HP** (60 / 60 in a new run), through the shared `Health` and a `Hurtbox` on
  `player_hurtbox`, the player's side. Enemy attacks hurt her; Carl's never do (no friendly fire).
- **Enemies choose between Carl and Donut.** With no target, an enemy picks the nearest valid
  party member within its detection range; it keeps that target while it stays valid and within
  chase range, then picks again. A downed Donut is never valid. No flipping between the two.
- **Scratch**, Donut's automatic attack: 10 damage to the nearest enemy within about 42 px of her
  centre, at most once per 1.0 s. She never leaves Carl to hunt: following comes first.
- **Downed at 0 HP**, never dead: she lies still (grey, on her side, a DOWNED label; the HUD says
  DOWNED), does not follow or scratch, and cannot be hit or targeted. After **6 s of play**
  (360 physics ticks; the menu and GAME OVER stop the countdown) she gets up with **30 / 60**.
  No revive key; potions heal Carl only.
- **Only Carl's death is GAME OVER.** Donut downed never is. Stairs never wait for her: she arrives
  on the next floor downed and gets up 6 s later.
- **Donut's HP is run state:** it carries over between floors unhealed, is part of the
  floor-entry checkpoint (a retry and Continue restore it; 0 starts her downed with a fresh
  6 s), and is saved. Her countdown, Scratch cooldown and enemy targets are never saved.
- **Save format version 3** adds `"donut": {"health", "max_health"}`. Versions 1 and 2 migrate
  (Donut 60 / 60).
- **Floor 5** (`floor_05`) is below Floor 4: a companion-combat test floor with no exits.
  Progression: Surface → Floor 1 → … → Floor 5, downward only.
- **Tests can never touch the player's save:** in a test or tool run, SaveManager refuses (with
  an error) any file outside `user://test_saves/`.
- **Phase 8 choices the prompt left open** (the narrowest fit with the existing code):
  - Scratch range is measured centre to centre: a 28 px hit circle around Donut reaches the
    blobs' 14 px Hurtboxes 42 px away;
  - the Blob's touch now hits **one** party member per touch (the nearer); Fists still hit
    every enemy in their circle;
  - enemies re-pick with their detection range (not their chase range) when their target is
    downed, as when they first notice anyone;
  - the save calls her block `"donut"`, mirroring `"carl"`, and stores her `max_health` too;
  - the HUD shows "Carl HP" and "Donut HP" side by side on its top line, so the slot bar and
    hint keep their places;
  - the title's save line still shows Carl's HP only.

## Implemented
- **Title screen** (main scene):
  - **Continue** (available only when the save loads) resumes the saved floor checkpoint;
    a line shows where, for example "Saved at the start of Floor 3 - HP 80 / 100".
  - **New Game** starts a clean run on the Surface (100 HP, no items, no Slingshot, Fists on
    D; Donut 60 / 60). If a save file exists, it first asks "Start a new game? Existing progress will be
    replaced." with No selected.
  - An unloadable save shows "Save data could not be loaded." and leaves Continue
    unavailable.
- **Carl** (`scenes/actors/carl.tscn`): **unchanged in Phases 6–8** (Phase 8 only puts his scene in
  the `party` group).
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
- **Donut** (`scenes/actors/donut.tscn`, **Phase 8**): she follows Carl on the navigation mesh as
  before, never collects pickups or uses the inventory, and freezes while the game is paused.
  New: 60 HP (`Health`), a `Hurtbox` on `player_hurtbox`, her automatic **Scratch** (a
  `MeleeAttack`: 10 damage, 28 px circle = 42 px to a blob's centre, 1.0 s, one target, a brief
  orange flash), a red hurt flash, and the **downed** state (grey, on her side, "DOWNED" label)
  with recovery to 30 / 60 after 6 s of play. See Architecture > Donut.
- **Gelatinous Blob** (`scenes/enemies/gelatinous_blob.tscn`): same numbers (30 HP, 55 px/s,
  220 px detection, gives up beyond 320 px, touch damage 10 every 0.8 s). **Phase 7:** it follows
  the navigation mesh, so it walks around walls. **Phase 8:** it goes for Carl or Donut (see
  Architecture > Enemies), and each touch hurts one of them (`max_targets` 1). Fists, stones and
  Scratch damage it through the same `Hurtbox` → `Health`.
- **Spitting Blob (Phase 7,** `scenes/enemies/spitting_blob.tscn`**):** a purple, spiky blob with
  a spout that turns toward its target. 30 HP; it spits `scenes/projectiles/spit_glob.tscn` (a
  violet teardrop glob with a trail) through its `SpitLauncher`, a `ProjectileLauncher` (1.5 s).
  Phase 8: its target may be Donut; its globs hurt her too. See Architecture > Enemies.
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
  - the signs "Floor 4 - Filtration Level", `Signs/Hint` "The stairs down to Floor 5 are in the
    far south-east corner." (Phase 8; it used to say the way down was not built) and "Spit
    cannot pass through walls. Use them as cover.", HUD and menu;
  - **Phase 8:** **stairs down to Floor 5** at (1072, 560), labelled "Down to Floor 5", away from
    every route the Floor 4 tests walk. No stairs back up.
- **Floor 5 (Phase 8,** `scenes/levels/floor_05.tscn`**, "Holding Pens", 36×20 tiles, 1152×640 px):**
  - Carl arrives at (176, 176), Donut at (176, 232), just south of him;
  - a **pen** south-west of the arrival point, closed by a wall along row 10 (x 32–320, y 320–352)
    and open to the east; the **penned Gelatinous Blob** (`PenBlob`) at (208, 416) is 187 px from
    Donut's arrival point but 242 px from Carl's, so it notices (and goes for) Donut, walking
    round the pen wall's east end; she scratches it while it hurts her;
  - a central block (x 480–544, y 96–288) and a south pillar (x 480–544, y 416–544); a second
    **Gelatinous Blob** at (656, 208) east of the block, which Carl, leading, usually meets first;
  - an **east wall** (x 800–864, y 192–416) as cover in front of the **Spitting Blob** at (1008, 320);
  - the signs "Floor 5 - Holding Pens", "Prototype: the way further down is not built yet." and
    "Donut fights back now. If she is downed, she gets up again after a while.", HUD and menu;
  - **no exits**: no way up, and Floor 6 is out of scope.
- **Stairs** (`scenes/props/stairs.tscn`): stairs **down**. They load `destination_scene_path`
  and ignore Carl for the first 2 physics frames of a level (no transition loops).
- **HUD** (`scenes/ui/hud.tscn`): "Carl HP: x / 100" and, beside it (Phase 8), "Donut HP: y / 60"
  in orange, or "Donut HP: 0 / 60  -  DOWNED" in red; the slot bar, for example
  `W: Slingshot   A: Potion x1   S: —   D: Fists` (no quantity for the Slingshot); a "Space:
  action menu" hint; the centred GAME OVER panel.
- **Action menu** (`scenes/ui/action_menu.tscn`): lists the four slots and Carl's inventory,
  for example "Fists (on D)", "Small Health Potion x1 (on A)", "Slingshot (on W)", with a
  description or confirmation line. Unchanged in Phase 6.
- **GameState autoload:** Carl's and Donut's HP, inventory, slots and the floor-entry state (see
  Architecture).
- **SaveManager autoload:** the persistent checkpoint in `user://savegame.json`, format
  version 3, with the version 1 and 2 migrations and the test-run guard (see Architecture).

Not implemented (later phases): Donut controls, commands, slots or equipment, Donut items or
healing, a revive key, permanent Donut death, ammunition, other weapons, equipment stats,
Floor 6, other enemy types (Dungeon Rat, Crawler, Dungeon Brute), bosses (Floor Guardian), the
prototype-complete screen, stairs that open only after goals, shops/economy, multiple save
slots, mid-floor or cloud saving, pause menu.

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
1 s while it can heal. Pickups need no key. No input actions were added in Phases 3–8: Donut
has no keys (her Scratch is automatic), and W/A/S/D never move or command her.

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
scenes/ui/hud.tscn                              Carl's and Donut's HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action/inventory menu (CanvasLayer 10)
scenes/actors/carl.tscn                         Carl (group "party"): Health, Hurtbox, Camera2D (performers added at run time)
scenes/actors/donut.tscn                        Donut (group "party"): Look (her shapes), DownedLabel, Health, Hurtbox, Scratch (MeleeAttack), NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack), NavigationAgent2D (EnemyNavigation)
scenes/enemies/spitting_blob.tscn               Spitting Blob (Phase 7): Health, Hurtbox, SpitLauncher (ProjectileLauncher), NavigationAgent2D
scenes/props/stairs.tscn                        Reusable stairs down
scenes/props/item_pickup.tscn                   Reusable world pickup (item + quantity; icon or default gem)
scenes/levels/surface.tscn, floor_01.tscn … floor_05.tscn   The six levels (floor_04: Phase 7; floor_05: Phase 8)
scripts/autoload/game_state.gd                  GameState: the current run's state
scripts/autoload/save_manager.gd                SaveManager: the one save file (encode, validate, migrate, safe write, load, delete)
scripts/state/floor_entry.gd                    class FloorEntry: a floor checkpoint (Carl's and Donut's HP, inventory snapshot, slot layout)
scripts/actions/action_registry.gd              class ActionRegistry: action id -> ActionDefinition (for loading saves)
scripts/levels/floor_registry.gd                class FloorRegistry: floor id -> scene and name (the only floors a save can open)
scripts/actions/action_definition.gd            class ActionDefinition (Resource): one slot-able action or item
scripts/actions/action_performer.gd             class ActionPerformer (Node2D): base for what carries an action out
scripts/actions/action_slots.gd                 class ActionSlots: which action each W/A/S/D slot holds
scripts/actions/inventory.gd                    class Inventory: innate actions, owned reusable items, consumable quantities
scripts/actions/heal_action.gd                  class HealAction (an ActionPerformer): heals the user
scripts/combat/health.gd                        class Health: hit points, take_damage(), heal(), set_health(), set_down() and revive() (Phase 8)
scripts/combat/hurtbox.gd                       class Hurtbox: where an actor can be hit
scripts/combat/melee_attack.gd                  class MeleeAttack (an ActionPerformer): cooldown-limited hit circle (max_targets: Phase 8)
scripts/combat/projectile_launcher.gd           class ProjectileLauncher (an ActionPerformer): fires a Projectile (Phase 6)
scripts/combat/projectile.gd                    class Projectile: flies, stops at walls, hits one target (Phase 6; source rule Phase 7)
scripts/enemies/enemy.gd                        class Enemy: what every enemy shares (target choice, navigation, sight, hit flash, death) (Phase 7; party targets Phase 8)
scripts/enemies/enemy_navigation.gd             class EnemyNavigation (a NavigationAgent2D): which way to move to reach a goal (Phase 7)
scripts/enemies/gelatinous_blob.gd              The Gelatinous Blob (an Enemy): chase and touch
scripts/enemies/spitting_blob.gd                The Spitting Blob (an Enemy): keep distance, spit when in sight (Phase 7)
scripts/actors/donut.gd                         Donut: follow, Scratch, downed and recovery (Phase 8)
scripts/levels/level.gd                         class Level: run-state wiring (Carl and Donut), GAME OVER, retry
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/props/item_pickup.gd                    Walk-over pickup: gives its item to Carl once
scripts/<actors|enemies|props|ui>/*.gd          One script per scene that needs one
tests/                                          Test scripts (not part of the game), see Tests
tests/fixtures/                                 Real save files from earlier phases: two save_version 1 (Phase 5), two save_version 2 (Phase 6) and one save_version 2 (Phase 7, Floor 4)
```

Every level scene uses this layout:
```
<LevelRoot> (Node2D, level.gd)   exports: carl, donut, hud, action_menu
├── NavigationRegion2D   level_navigation.gd; NavigationPolygon outline = level bounds
│   └── Terrain          TileMapLayer with the shared TileSet
├── Signs                world-space Labels
├── Stairs               (optional) stairs.tscn leading DOWN to the next level
├── Pickups              (optional) item_pickup.tscn instances (item + quantity)
├── Actors               Node2D with Y-sort on
│   ├── Carl             placed at the level's entry point (also where a retry starts)
│   ├── Donut            follow_target = ../Carl
│   ├── enemies          e.g. GelatinousBlob, SpittingBlob (they find Carl and Donut themselves)
│   └── (projectiles)    Stones and globs are added here while they fly
├── HUD                  hud.tscn instance
└── ActionMenu           action_menu.tscn instance
```
**To add a floor:** duplicate `floor_04.tscn` (or another floor), then:
1. Repaint Terrain and resize the NavigationPolygon outline.
2. Place Carl (the entry point), Donut (with `follow_target` = Carl) and the enemies, and set the
   root's `carl` and `donut` (enemies need no wiring: they hunt the `party` group).
3. Add pickups and stairs down, if any.
4. Point the previous floor's stairs down at the new file. Never add stairs back up.
5. Add one line to `FloorRegistry`, so the floor can be saved and continued. (Floors 4 and 5
   needed nothing else: no level or title code.)

**To add an enemy:** make a scene whose root script `extends Enemy` (scripts/enemies/enemy.gd),
with the children Enemy expects (Health, Hurtbox on `enemy_hurtbox`, CollisionShape2D on
`enemy`, NavigationAgent2D with `enemy_navigation.gd`, a unique HealthBarFill), plus its attack
nodes (a MeleeAttack, a ProjectileLauncher with its own projectile scene, …). Its
`_physics_process()` combines `update_activity()` (which also chooses `target`, Carl or Donut),
`navigate_toward()`, `stop_moving()` and `has_line_of_sight_to()`. Its attacks target
`player_hurtbox`. Place it in a level's Actors; no wiring and no level code changes.

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
  - **`MeleeAttack`**: Fists. The Blob's ContactAttack and Donut's Scratch call `attack()`
    directly. `max_targets` (Phase 8) limits how many Hurtboxes one use damages, nearest to the
    hit circle's centre first: 0 (Fists) = all in the circle, 1 for the Blob's touch and Scratch.
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
- **Sides (factions) are Hurtbox layers.** `player_hurtbox` is the player's side: Carl's
  Hurtbox and, since Phase 8, Donut's. `enemy_hurtbox` is the enemies' side. A stone looks for
  `enemy_hurtbox` only, so it can hurt enemies and never Carl or Donut. A glob looks for
  `player_hurtbox` only, so it can hurt Carl or Donut and never the blob that spat it or any
  other enemy: its ray does not even report enemy Hurtboxes. It stops at the **first** party
  Hurtbox on its path, so whoever stands in front shields the other, and it never hits two. A
  downed Donut's Hurtbox `can_be_hit()` false, so a glob flies past her. Pickups and stairs detect
  only the `player` body, which a projectile is not. No scene-specific collision exceptions are
  used; the same layers drive the melee attacks (Fists, the Blob's touch, Scratch).
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

### Enemies (Phase 7, `scripts/enemies/`; party targeting Phase 8)
Composition first, with one thin shared base:
- **`Enemy`** (`enemy.gd`, extends CharacterBody2D): what every enemy has in common, lifted out
  of the Phase 6 Blob script. Exports `move_speed`, `detection_range`, `chase_range`,
  `sight_blocking_layers` (`world`), `death_fade_time`. Provides:
  - **`target`** (Phase 8, not exported: levels no longer set it) and `update_activity()`,
    which chooses it once per tick:
    1. drop the target if it is no longer valid (see below) or farther than `chase_range`;
    2. with no target, pick the nearest valid **party member** within `detection_range`
       (straight-line distance; exact ties go to the one earlier in the scene tree);
    3. the enemy is active while it has a target.
    The party is the `party` group (`Enemy.PARTY_GROUP`), which `carl.tscn` and `donut.tscn`
    join. A member is valid while it is in the tree and its `Health` is above 0
    (`is_valid_target()`), so a downed Donut or a downed Carl is dropped at once. Because a kept
    target is only dropped for those reasons, the enemy never flips between Carl and Donut when
    one becomes slightly nearer;
  - `navigate_toward(goal)` / `stop_moving()`: move the body with `move_and_slide()` in the
    direction `EnemyNavigation` gives, at `move_speed`;
  - `has_line_of_sight_to(point)`: a ray from the enemy's centre on `sight_blocking_layers`.
    Donut, other enemies and Carl's body do not block it (they are not on `world`);
  - hit flash, health bar, and dying (stop, stop blocking, fade, free), as before.
  Each enemy writes its own `_physics_process()` from these. There is no enemy-type `match`
  anywhere; levels only place enemy scenes.
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
- **Gelatinous Blob** (`gelatinous_blob.gd`): active: `navigate_toward(target)`; otherwise it
  stands still. Its `ContactAttack` (MeleeAttack, `player_hurtbox`, `max_targets` 1) hurts the
  nearest party member it touches, whether or not that is its target, one per touch.
- **Spitting Blob** (`spitting_blob.gd`), each physics tick while active, for its target (Carl
  or Donut alike):
  1. if the target is in sight and within `max_firing_distance` (320 px), `SpitLauncher.perform()`
     toward it; the launcher refuses while cooling down (90 ticks), so there is one glob per
     cooldown and never one at a hidden target;
  2. move: toward the target (along the mesh) if it is hidden or farther than 280 px; away from
     it (toward a point 48 px behind itself, along the mesh) if closer than 180 px; otherwise
     stand still. The spout (`%Mouth`) turns toward it.
  So a hidden target makes it walk around the wall; as soon as it can see it, it spits.
- **Pause and GAME OVER:** enemies, their launchers and their projectiles are ordinary
  pausable nodes, so the tree pause that the menu and GAME OVER already use freezes all of
  them. Cooldowns count physics ticks, which do not run while paused, so nothing is saved up:
  after a pause the next glob comes exactly one cooldown of running time after the last.
- **Not saved:** enemy HP, positions, activity, paths, cooldowns and projectiles are level
  state. A retry or Continue reloads the level, so enemies start as authored.

### Donut (Phase 8, `scripts/actors/donut.gd`, `scenes/actors/donut.tscn`)
- **Following**, unchanged: along the navigation mesh to within 60 px of Carl, full speed
  (200 px/s) from 100 px. She never paths toward enemies.
- **Health and Hurtbox:** the shared `Health` (max 60) and a `Hurtbox` on `player_hurtbox`, so
  every enemy attack reaches her exactly as it reaches Carl, and no player attack can.
- **Scratch:** a `MeleeAttack` child (`reach` 0, `hit_radius` 28, `damage` 10, `cooldown` 1.0,
  `target_layers` `enemy_hurtbox`, `max_targets` 1, an orange flash). Each tick she is up she
  calls `attack()` if it is ready and `find_targets()` is not empty, the same pattern as the
  Blob's touch. The circle reaches a blob's 14 px Hurtbox when its centre is within 42 px. Its
  cooldown counts physics ticks, so it pauses with the game and never saves up a burst.
- **Downed:** `Health.died` → `_on_downed()`: velocity 0, the countdown set to
  `down_time` (6 s = 360 ticks), `%Look` (her shapes) greyed and turned on its side, and
  `%DownedLabel` shown. While downed her `_physics_process()` only counts down: no following, no
  Scratch. Her Hurtbox's `can_be_hit()` is false (0 HP), so more hits, touches and globs do
  nothing, and enemies drop her (`Enemy.is_valid_target()`).
- **Recovery:** after 360 downed ticks, `Health.revive(recovery_health)` (30) and her normal
  look. The countdown is counted in `_physics_process()`, so the action menu and GAME OVER (tree
  pauses) stop it. It also holds while Carl is down (Carl's `Health` at 0), which in a level is
  GAME OVER anyway. Every downing starts a fresh 6 s; it is never saved.
- **Starting a level:** `Level._ready()` calls `donut.start_with_health(hp, max)`:
  `Health.set_health()` for 1 HP or more, `Health.set_down()` for 0, which emits `died`, so a
  Donut who entered the floor downed goes through the same `_on_downed()` (fresh 6 s).
- **`Health` additions** (shared, used only by Donut so far): `set_down(max)` (0 HP without it
  counting as damage; emits `health_changed` and `died`) and `revive(amount)` (a dead actor comes
  back with 1–max HP). `heal()` still refuses a dead actor, so a potion could never revive.

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
  `donut_health`, `donut_max_health` (Phase 8; 0 = downed), `inventory`, `action_slots`,
  `floor_entry` (a `FloorEntry`). It has no gameplay rules and does **no disk I/O**.
- `INNATE_ACTIONS` (`[Fists]`) is the one list of innate actions.
- `start_new_run()` resets everything in place, so references stay valid: Carl 100/100,
  Donut 60/60 (`NEW_RUN_DONUT_MAX_HEALTH`), inventory = Fists only (no potions, no Slingshot),
  Fists on D, no floor entry.
- `continue_from(checkpoint)` (Continue) starts a run with exactly the checkpoint's HP,
  inventory (including owned reusable items) and slot layout.
- **Levels connect GameState to the game** (`Level._ready()`): Carl gets the HP, `inventory`
  and `action_slots`; Donut gets her HP (`start_with_health()`), and her `health_changed` keeps
  `store_donut_health()` up to date; the HUD gets both HPs, the slots and the inventory; the
  menu gets the slots and the inventory. Carl, the HUD,
  the menu, pickups and projectiles never name `GameState` themselves. Test scripts compile
  before autoloads exist, so anything a test preloads must not name it.
- ARCHITECTURE_RULES allows exactly two autoloads, `GameState` and `SaveManager`, and those
  are the only two.

### Floor-entry state and retry
- Every level calls `GameState.record_floor_entry(scene_file_path)` when it starts, then
  `SaveManager.save_checkpoint(GameState.floor_entry)`. This single place in `Level._ready()`
  writes every checkpoint, for all current and future floors (Floor 3 needed no code).
- The checkpoint (`FloorEntry`) holds the scene path, Carl's HP and max HP, Donut's HP and max
  HP (Phase 8), `inventory.get_snapshot()` (consumables and owned reusable items) and
  `action_slots.get_layout()`.
- **GAME OVER** (`Level._on_carl_died()`) pauses the scene tree. **Death never writes the
  save.**
- Enter on the GAME OVER panel makes the level:
  1. call `GameState.restore_floor_entry()`: Carl's and Donut's HP go back; the carried items are replaced by
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
  `save_path` can be changed; tests always change it (see Test save isolation below).
- **Format version 3** (`SAVE_VERSION`, Phase 8), stable ids only:
  ```
  {"save_version": 3, "floor_id": "floor_05", "carl": {"health": 80, "max_health": 100},
   "donut": {"health": 40, "max_health": 60},
   "inventory": {"small_health_potion": 1},
   "owned_items": ["slingshot"],
   "action_slots": {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": null, "action_d": "fists"}}
  ```
  - `donut`: Donut's HP on entering the floor (Phase 8). 0 = she entered downed;
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
- **Version 2 → 3 migration** (Phase 8, `_migrate_version_2()`), chained after the version 1
  one: `decode()` sends version 1 through `_migrate_version_2(_migrate_version_1(data))` and
  version 2 through `_migrate_version_2(data)`. The copy gets `save_version: 3` and
  `"donut": {"health": 60, "max_health": 60}`: before Phase 8 Donut could not be hurt, so any
  older checkpoint means she was unhurt. Anything a version 2 file held under `donut` is
  replaced. Then the version 3 rules check it. As before, loading never writes: the file becomes
  version 3 at the next checkpoint save, which Continue triggers at once by opening the floor.
  - Any other version (0, 4, 999, ...) is rejected: "save_version N is not supported".
  - A version 4 later means bumping `SAVE_VERSION`, adding `_migrate_version_3()` and chaining it.
- **Persisted:** floor id, Carl's HP and max HP, Donut's HP and max HP, consumable quantities,
  owned reusable items and the four slot assignments, all at floor entry.
- **Not persisted (on purpose):** positions; enemies, their HP and their targets; collected
  pickups; projectiles; cooldowns (Scratch included), Donut's recovery countdown, animation and
  navigation; the live menu state; anything after floor entry.
- **API:** `save_checkpoint(entry) -> bool`; `load_checkpoint() -> FloorEntry` (null, with
  the reason in `last_error`); `has_save_file()`; `delete_save()`; `encode(entry)` /
  `decode(data)`.
- **Safe writes:** the text is written to `savegame.json.tmp`, read back and compared, then
  renamed over `savegame.json`. A failure logs an error and leaves the old save as it was.
  A finished `.tmp` left by an interrupted save is loaded (and validated) instead.
- **Validation (untrusted input).** `decode()` rejects the whole save, without logging an
  engine error, if:
  - the file is not valid JSON, or its root is not a JSON object;
  - `save_version` is not a whole number, or is not 1 or 2 (migrated) or 3;
  - `floor_id` is not in `FloorRegistry`. No path is ever read from the file;
  - Carl's HP is not a whole number with 1 ≤ health ≤ max_health ≤ 1000;
  - `donut` (version 3) is missing or not an object, or Donut's HP is not a whole number with
    0 ≤ health ≤ max_health, 1 ≤ max_health ≤ 1000 (a missing value is never made up);
  - `inventory` is not an object; an id is not in `ActionRegistry`, is innate (Fists) or is
    a reusable item (the Slingshot has no quantity); or a quantity is not a whole number
    from 0 to 999;
  - `owned_items` (version 2) is not a list; or an entry is not a string, not in
    `ActionRegistry`, innate, consumable, or listed twice;
  - `action_slots` is not exactly the four slot names, each with an id or null.

  It **sanitizes** slots instead of rejecting the save: an unknown action id, an action
  Carl would not have (a potion with quantity 0, a Slingshot he does not own), or an action
  named twice leaves that slot empty. `ActionSlots.fill_empty_slots()` decides this.
- **Registries:** `FloorRegistry` (`surface`, `floor_01` … `floor_05`) and
  `ActionRegistry` (`fists`, `small_health_potion`, `slingshot`) are the whitelists that turn
  saved ids back into scenes and resources.
- **Title flow:** Continue calls `load_checkpoint()` again, then `GameState.continue_from()`,
  then loads the saved floor (Floor 3 directly, for a Floor 3 save). New Game calls
  `GameState.start_new_run()` and loads the Surface, whose checkpoint replaces the old save.
- **Test save isolation** (strengthened in Phase 8):
  - `tests/support/game_test.gd` points `save_path` at `user://test_saves/<test>.json` before
    anything runs, and deletes that file at the start and the end (`test_surface_traversal.gd`
    does the same);
  - **the guard (fail closed):** SaveManager itself refuses, in a *test or tool run*, any path
    outside `TEST_SAVE_FOLDER` (`user://test_saves/`; checked after `simplify_path()`, so
    `user://test_saves/../savegame.json` is refused too). A test or tool run is one started
    with a script as its main loop (`godot -s <script>`), which is how every test runs:
    `Engine.get_main_loop().get_script() != null`. `has_save_file()`, `load_checkpoint()`,
    `save_checkpoint()` and `delete_save()` all check it first; a refusal reads, writes and
    deletes nothing and logs an error ("SaveManager refused to use ..."), which fails the test.
    So a test or scratch script that forgets to choose its own file can no longer silently use
    the player's save, which is how the Phase 7 slip happened. The game itself (the title screen
    as the main scene, from the editor or an export) is never affected;
  - `test_save_isolation.gd` proves it without risk: it first shows that a stray file outside
    the folder is neither written, loaded nor deleted, and only then points SaveManager at the
    player's save path (it never calls `delete_save()` on it, and compares only the file's
    existence and modification time, never its content);
  - a test that provokes an error on purpose takes it with `take_engine_messages()`, which
    prints `EXPECTED ERROR: <text>`; `run_all.gd` then excuses exactly one `ERROR: <text>` line
    with that text. Any other error or warning still fails the test.

### Earlier decisions still in force
- Compatibility renderer; 1280×720 base with `canvas_items` stretch and `expand` aspect;
  physical-keycode bindings; Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.8.0`.
- `.godot/` ignored, `.uid` files committed, LF line endings.
- Carl is a floating-mode `CharacterBody2D`; Camera2D inside Carl (zoom 1.5, smoothing);
  physics interpolation on.
- Donut uses a navigation mesh baked when the level loads (so do enemies, since Phase 7).
- Combat components: `Health` (all damage through `take_damage()`), `Hurtbox`,
  `MeleeAttack`, and since Phase 6 `ProjectileLauncher` and `Projectile`. Donut uses the same
  ones (Phase 8): no pet-only health or damage code.
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
| 5     | `player_hurtbox` | Carl's and (Phase 8) Donut's Hurtboxes     | none; found by enemy attacks' queries    |
| 6     | `enemy_hurtbox`  | Enemy Hurtboxes (Area2D)                   | none; found by Fists, stones and Scratch |
| —     | (none)           | Stairs (Area2D, `monitorable` off)         | 2 `player`: only Carl triggers them      |
| —     | (none)           | Item pickups (Area2D, `monitorable` off)   | 2 `player`: only Carl collects them      |
| —     | (none)           | Slingshot stones (Node2D, Phase 6)         | ray query: 6 `enemy_hurtbox` (hit) and 1 `world` (stops) |
| —     | (none)           | Spit globs (Node2D, Phase 7)               | ray query: 5 `player_hurtbox` (hit) and 1 `world` (stops) |
| —     | (none)           | Enemy line of sight (Phase 7)              | ray query: 1 `world` only                |
| —     | (none)           | Donut's Scratch (MeleeAttack, Phase 8)     | shape query: 6 `enemy_hurtbox`           |

Consequences:
- Carl and the blobs block each other.
- Donut's body collides only with walls, and she can neither trigger stairs nor collect
  pickups. Carl and the enemies pass through her body (her `companion` layer is not in their
  masks); her Hurtbox is what attacks find.
- Carl's Fists and stones and Donut's Scratch target layer 6 only; the Blob's touch and the
  globs target layer 5 only. So the player's side (Carl, Donut) never hurts itself, and enemy
  attacks never hurt enemies.
- Stones and globs are stopped by layer 1 only: they fly over bodies, pickups and stairs.
  Enemies see through everything but walls, exactly where their globs can fly.
- Navigation baking reads only layer 1.

## Earlier behaviour changed in Phase 8
1. **Donut can be hurt and fights** (GAME_SPEC §6). Earlier tests asserted the old rule; they
   now assert the new one, never less:
   - `test_combat.gd` ("Donut has no Health") now checks that Carl's punch leaves her at 60 / 60;
     its Carl-only fights keep Donut out of reach so the numbers stay Carl's; the check "the
     blob's touch only finds Carl, not Donut" moved to `test_party_targeting.gd` as "each touch
     hurts the nearer party member";
   - `test_slingshot.gd` ("Donut has nothing it could damage") now checks that a stone flying
     straight through her real Hurtbox leaves her at 60 / 60;
   - `test_enemy_navigation.gd` ("enemies ignore Donut") now checks that a blob that picks Donut
     walks around a wall to reach her and hurts her by touch;
   - `test_spitting_blob.gd`: Donut left the line of bystanders a glob flies past (a glob now
     hits her, which `test_party_targeting.gd` covers).
2. **Enemies choose their own target** (the `party` group); `Enemy.target` is no longer an
   export, and the levels' `target = ../Carl` lines are gone. Tests no longer set it by hand:
   in the old tests a pre-set target was ignored for a still enemy, but with Phase 8 rules it
   would count as already chosen. The "no target set" warning is gone (no wiring to forget).
3. **The Gelatinous Blob's touch hurts one party member per touch** (the nearer), not every
   Hurtbox in reach. With only Carl there (every earlier fight), nothing changes.
4. **The HUD's HP line reads "Carl HP: x / 100"** (it was "HP: x / 100"), with "Donut HP" beside
   it. `test_combat.gd` and `test_floor_loop.gd` check the new text.
5. **Save format version 3** (with `donut`). Tests that compared whole save files
   (`test_save_game.gd`, `test_slingshot_run.gd`, `test_floor_04_run.gd`, `test_save_manager.gd`,
   `test_save_migration.gd`) now expect version 3 and Donut's HP; `test_save_manager.gd` now
   rejects version 4 and `floor_06` instead of version 3 and `floor_05`.
6. **Floor 4 has an exit** (stairs down to Floor 5); its note `Signs/PrototypeNote` became
   `Signs/Hint`. `test_floor_04_run.gd` checks that Floor 4's only exit leads down to Floor 5,
   and `test_windowed_resolutions.gd` checks `Signs/Hint`.
7. **SaveManager refuses non-test save paths in test and tool runs** (see Persistent save).
   Earlier tests all used their own files already, so none changed for this.
8. `run_all.gd` accepts an error a test provoked and checked (`EXPECTED ERROR:`), and only that.
9. Version in Project Settings: `0.8.0`.

## Tests
Run the whole suite from the project folder:
```
godot --headless --path . -s res://tests/run_all.gd
```
It runs every `tests/test_*.gd` in its own Godot process. A test fails on a non-zero exit
code or on any engine ERROR/WARNING in its output, except an error the test provoked on purpose
and checked (it prints `EXPECTED ERROR: <text>`, which excuses exactly one `ERROR: <text>` line;
only `test_save_isolation.gd` does this). Tests with "windowed" in their name get a real window,
which opens briefly. The full run takes about 10 minutes. Each test file can
also be run on its own; the first lines of each file give the command.

| Test file                               | Covers |
|-----------------------------------------|--------|
| `test_input_map.gd` (Phase 0)           | Every action bound to its key; no key shared between actions |
| `test_carl_movement.gd` (Phase 1, 3)    | Exact speed per arrow key, normalized diagonals, facing, tick-rate independence; W/A/S/D never move Carl |
| `test_surface_traversal.gd` (Phase 1)   | Title → Surface, wall collision, Donut following, stairs → Floor 1, Floor 1 walls |
| `test_combat.gd` (Phase 2, 3, 8)        | Health; Fists on D: facing, diagonals, no self-hit, W/A/S empty, exact cooldown, **Donut in the way is not hit and keeps 60 / 60 HP (Phase 8)**; Blob pursuit, walls, contact damage, death (in an arena with no navigation mesh, Carl the only party member); HUD "Carl HP"; downed Carl |
| `test_action_slots.gd` (Phase 3, 4)     | New-game layout; ActionSlots rules; Carl follows reassignment live; cooldown not reset by moving; a test-only second action works next to Fists; HUD slot bar |
| `test_action_menu.gd` (Phase 3)         | Space opens/pauses, Space/Escape close; nothing focused; Carl/Donut frozen while open; reassigning through the menu; no free punch/step across close; blob frozen while open; no menu over GAME OVER |
| `test_floor_loop.gd` (Phase 2, 3)       | Title → new game; reassignment; HP and slots carried to Floor 1; no transition loop; nothing on Floor 1 leads up; real fight and defeat; GAME OVER waits; retry with entry HP; stairs ignore an arrival on top of them |
| `test_inventory.gd` (Phase 4)           | Inventory rules, slots follow the inventory, potion use through a slot, one potion per press, menu quantities, pickups (Donut/enemy can't take them, two collectors) |
| `test_inventory_run.gd` (Phase 4, 5)    | Real potions run through Floor 1 → Floor 2 with retries; Floor 2's only exit leads down (Phase 6) |
| `test_save_manager.gd` (Phase 5–8)      | Registries (6 floors, `floor_05` shown as "Floor 5", no `floor_06`); **version 3 JSON with `donut`** (and owned_items); Floor 3, 4 and 5 checkpoints with the Slingshot on W and Donut's HP round-trip; **Donut at 0 (downed) round-trips**; a checkpoint has exactly the 7 fields; 55 kinds of bad data rejected with the file untouched (incl. versions 4/999, `floor_06`, **14 kinds of bad Donut data: missing, null, a number, a list, no health/max, a string, -1, above her maximum, fractional, max 0, max above 1000**, Slingshot with a quantity, bad owned_items); slots sanitized; Donut 0 and exactly 60 accepted; delete; interrupted-save recovery |
| `test_save_game.gd` (Phase 5, 6, 8)     | Real title + levels: checkpoints (save_version 3, Donut 60 / 60), Continue, deaths, New Game confirmation, corrupt/unsupported saves |
| `test_save_migration.gd` (Phase 6–8)    | The two real Phase 5 fixtures (version 1), the two real Phase 6 fixtures and **the real Phase 7 Floor 4 fixture** (version 2) load with their floor, HP, items and slots and **Donut at 60 / 60**, the files untouched, and are written back with the same values as version 3 plus Donut; a v1 Slingshot slot is emptied, a v1 `owned_items` ignored, a v1 Slingshot quantity rejected; 13 kinds of malformed v1 data rejected; v2 loads (a `donut` in a v2 file is ignored), v2 without owned_items rejected; **v3 loads with its own Donut HP, v3 without `donut` rejected**; versions 0/4/999/-1 rejected; title → Continue on the v1 Floor 2 save and **on the Phase 7 Floor 4 save** open those floors with their state and Donut at 60 / 60, and the files become version 3; the migrated game plays on |
| `test_slingshot.gd` (Phase 6, 8)        | Ownership model (innate/reusable/consumable, owned once, never removed, snapshots, new run clears it); slots; pickup; firing in four directions; exactly 10 damage, 3 hits kill a blob; one target only; flies through a dying blob; hits a blob that steps onto it; stops at a wall face; 320 px / 40 ticks; never hurts Carl, **nor Donut, whose real Hurtbox is in the line of fire (60 / 60, Phase 8)**; no pickup, no stairs; point blank; cooldown; menu; HUD and menu labels |
| `test_slingshot_run.gd` (Phase 6–8)     | Real run: New Game clears a previous Slingshot; Surface → Floor 1 → Floor 2 → Floor 3, nothing leads up (Floor 3's only exit leads down to Floor 4); Floor 2 entry has no Slingshot (run, entry state, disk: version 3, Donut 60 / 60); collect + W doesn't save; two Floor 2 deaths take it back; quit before Floor 3 → Continue without it; three stones kill the Floor 2 blob; Floor 3 arrival, the Floor 3 checkpoint owns it with W = Slingshot; a stone stops at Floor 3's wall tiles; two Floor 3 deaths keep it; Continue opens Floor 3 and it fires; New Game clears it |
| `test_windowed_resolutions.gd` (Phase 2–8) | At 1280×720, 640×360, 1024×768: HUD with `W: Slingshot   A: Potion x2` **and "Donut HP: 0 / 60 - DOWNED" fully on screen, its text fitting, clear of Carl's HP and the slot bar**, GAME OVER panel, action menu, camera; Floor 2's Slingshot pickup; Floor 3's signs clear of the HUD; a flying stone; Floor 4's three signs clear of the HUD; the two blobs, a glob and a stone on screen together; **Floor 5's three signs clear of the HUD; a downed Donut's DOWNED label drawn on screen, clear of the HUD; Donut's colour unlike both blobs'**; the title screen (with a Floor 5 save) and its confirmation. Prints SKIP and passes when run headless |
| `test_enemy_navigation.gd` (Phase 7, 8) | Arenas with a real baked navigation mesh, each waiting until the map holds exactly its mesh: the Blob waits beyond 220 px, notices Carl behind a wall, gives up beyond 320 px; it follows a route around a wall to Carl (its own path bends round the wall's end), never overlaps the wall, never stalls, reaches him and hurts him every 0.8 s; with no way around it stops beside the wall without jittering; the Spitting Blob with Carl hidden walks around the wall and spits only once it sees him; **Phase 8: with Carl far away, a blob picks Donut behind the wall, walks around it without overlapping it, reaches her and hurts her 10 every 0.8 s (60 → 30)** |
| `test_spitting_blob.gd` (Phase 7, 8)    | Arenas (Carl the only party member): its numbers; waits beyond 360 px, closes in and spits at 320 px, holds at 280 px, backs off to 180 px, gives up beyond 480 px; touching it never hurts; a wall stops it spitting, stepping into sight or removing the wall makes it spit at once; a glob takes exactly 10 HP once; walls stop globs; a glob flies past stairs, a pickup, another Spitting Blob and a Gelatinous Blob and hits Carl, hurting none of them nor its own blob, even when made to target enemies; 384 px / 96 ticks; 5 globs exactly 90 ticks apart, no burst; three stones kill it; Fists by facing; the menu freezes everything, no free glob, stone or burst |
| `test_donut.gd` (Phase 8)               | Arenas: a new run (also after one where she was downed) gives Donut 60 / 60; Health 60, Hurtbox on `player_hurtbox`, the `party` group, Scratch's numbers; an enemy's touch takes 10 every 0.8 s; HP never below 0; Carl's point-blank punch and a stone through her never hurt her; Scratch never hurts Carl or Donut and never fires with no enemy near; exactly 10 per scratch, exactly 60 ticks apart, three kill a blob, none on a dead one; an enemy 38 px away is scratched, 46 px is not; the nearest of two only; she stays by Carl and follows him, never toward an enemy; downed at 0: HUD "0 / 60 - DOWNED" in another colour, grey, on her side, DOWNED label, cannot be hit; no following, no scratching, a touch finds nothing, nothing paused; she gets up on her 360th downed tick (not at 359) with exactly 30 / 60, looks normal, catches up with Carl, scratches again; 5 s of menu do not count toward the 6 s; GAME OVER (the tree pause) and a downed Carl hold her countdown |
| `test_party_targeting.gd` (Phase 8)     | Arenas: an enemy picks Carl or Donut, whoever is nearest within 220 px, nobody beyond; keeps Donut every tick while Carl alternates 1 px nearer and farther for 2 s, and even with Carl much nearer; drops her beyond its chase range and picks Carl; drops a downed Donut on the next tick (picks Carl, or goes idle) and never goes back; picks her again when she gets up; the Blob chases Donut at its speed and its touch takes exactly 10 every 0.8 s; touching both, each touch hurts only the nearer; the Spitting Blob picks Donut, never spits at her through a wall (3 s), spits at once when the wall goes, the glob takes exactly 10, the next exactly 1.5 s later, a wall stops a glob flying at her, it drops her when she is downed and spits no more; it still spits at Carl; it keeps 280 px / backs off to 180 px from Donut; a glob hits only the first of Carl and Donut in its way (either order), once, flies past a Gelatinous Blob, and flies past a downed Donut to Carl |
| `test_floor_05_run.gd` (Phase 8)        | Real run: every level's exits lead one floor down, Floor 5 has none; Continue on a version 3 Floor 4 save (Carl 80, Donut 40) → Floor 4 with both HPs; its stairs → Floor 5: spawn, Donut, camera, sign, HUD (Carl 80, Donut 40), two blobs and a Spitting Blob, no exits, no loop, entry state and checkpoint (version 3, Donut 40); the penned blob picks Donut over Carl, walks around the pen wall, three scratches kill it while its three touches take her 40 → 10; Carl untouched; the entry state and save unchanged; Carl down → GAME OVER waits, Donut frozen; retry → Carl 80, Donut 40, enemies as authored; Donut downed by the penned blob: no GAME OVER, HUD and label DOWNED, the blob turns on Carl, Carl punches it dead, she never moved or scratched; the menu freezes her countdown and the enemies; she gets up after 6 s of play with 30 / 60 and follows Carl; GAME OVER while she is downed holds her countdown 7 s; retry → Donut 40; quit and Continue opens Floor 5 directly with everything, the penned blob going for Donut; a Floor 4 save with Donut at 0: she starts downed, Carl takes the stairs anyway, she arrives downed, the checkpoint says 0, enemies ignore her, she gets up after a fresh 6 s (359 ticks) on Floor 5 and can be picked again; New Game: Carl 100, Donut 60 / 60, save version 3 |
| `test_save_isolation.gd` (Phase 8)      | The save guard: in a test run the player's save path, look-alike paths (`user://test_saves/../savegame.json`, `user://test_saves_old/...`), the `.tmp` beside it and other files are refused, test-folder paths allowed; a stray file outside the folder is neither written, loaded nor deleted, each refusal reported; then, pointed at the player's save, SaveManager finds and loads nothing and refuses to write, and a level starting in that state cannot save its checkpoint; the player's save (if any) keeps its modification time; the test's own file still works |
| `test_floor_04_run.gd` (Phase 7, 8)     | Real run from a real Phase 6 Floor 3 save: title → Continue → Floor 3 (the same checkpoint saved again as version 3 with Donut 60 / 60); every level's exits lead one floor down, **Floor 4's only exit to Floor 5**, Floor 5 none; Floor 3 → Floor 4 arrival and checkpoint (version 3); the Blob walks around wall A and three punches kill it; the Spitting Blob walks around wall B, spits only in sight, the menu freezes it and its glob; globs take Carl to 0 HP, GAME OVER waits; retry restores everything; GAME OVER with a glob in flight freezes it; three stones kill the Spitting Blob; quit and Continue on Floor 4; New Game starts clean (Donut 60 / 60). Donut is present and fights along throughout |

Every test uses its own save file under `user://test_saves/`, and SaveManager refuses anything
else in a test run (see Persistent save > Test save isolation).

## Validation performed (Phase 8)
All runs used Godot 4.7.2.stable.official on this machine (NVIDIA GeForce GTX 750 Ti, OpenGL
3.3, Compatibility renderer, 60 Hz). Everything that could write a save ran either as a test
(protected by the new guard, with its own file in `user://test_saves/`) or in a scratch copy
of the project with its own user-data folder (`config/custom_user_dir_name`).
- **Baseline before changes:** the Phase 7 suite at HEAD `02b1fb2` passed 18 of 18 (7 min 17 s).
  It ran in a scratch copy with its own user-data folder, because Phase 7 code had no guard yet.
  The normal entry point (the title screen, in a real window) ran there too: 240 frames, exit
  0, no engine errors.
- **The Phase 7 fixture from the real Phase 7 code:** in that same Phase 7 copy, Phase 7's own
  `Level` and `SaveManager` entered Floor 4 with Carl at 80 HP, the Slingshot on W and a
  potion on A, and wrote `tests/fixtures/phase7_save_v2_floor_04.json` (version 2); Phase 7
  loaded it back.
- **Clean import:** a copy without `.godot/` imported with no errors or warnings. All 76
  scripts, scenes and resources load, and all 20 scenes instantiate.
- **Strict parse check:** with the 37 default-enabled GDScript warnings raised to errors, all 76
  files load. It found three warnings in new or changed test code (two unused locals, a ternary
  mixing StringName and String), which were fixed. The game scripts had none.
- **Test suite:** `run_all.gd` passed 22 of 22 (9 min 56 s) on the final code, and 22 of 22 on
  an earlier full run (597 s, slowed by the mutation run going on at the same time). The four
  new files are `test_donut.gd`, `test_party_targeting.gd`, `test_floor_05_run.gd` and
  `test_save_isolation.gd`.
- **The player's save was not touched by this work.** There is a real
  `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json` (310 bytes). Its
  SHA-256 (`4ACABE89…A9B3`) is the same at the end as when Phase 8 work began; it was never read,
  written, moved or deleted by this work. Its modification time did change once, from 22:53:03
  to 23:01:17 on 2026-09-24, with identical content. At that moment no process of this work had
  the real project open (the first one, an import, ran at about 23:06; the baseline and the
  Phase 7 fixture ran in a scratch copy). Identical content rewritten at a floor-entry
  checkpoint is what the game itself does on a retry or Continue, so it is most likely the game
  run from the open editor. Since then the guard has made test runs unable to reach that file
  at all. `test_saves/` is empty after the suite. (One stray test file of this work,
  `test_saves/probe_floor5.json`, left by a scratch probe that had to be stopped, was removed.)
- **Mutation checks:** 19 regressions were injected, one at a time, into a scratch copy with its
  own user-data folder, and each was restored afterwards. The chosen test files all passed in
  the copy first. Every regression made at least one of them fail:
  - a Slingshot stone that can hurt Donut (`test_donut`, `test_slingshot`);
  - enemy attacks unable to hurt Donut (her Hurtbox moved off `player_hurtbox`);
  - a downed Donut staying a valid target (`test_party_targeting`, `test_floor_05_run`);
  - Donut going down causing GAME OVER (`test_floor_05_run`);
  - Scratch every 0.5 s; Scratch reaching across the room; Scratch able to hurt Carl;
  - the recovery countdown running while the game is paused (`test_donut`, `test_floor_05_run`);
  - Donut getting up with 60 instead of 30;
  - a retry restoring the wrong Donut HP (full instead of her floor-entry HP);
  - Donut's HP not carried into the next floor;
  - enemies re-picking the nearest party member every tick (flip-flop, `test_party_targeting`);
  - the Blob's touch hurting everyone it touches;
  - version 2 saves rejected instead of migrated (`test_save_migration`, `test_floor_04_run`);
  - version 2 migration giving Donut 0 HP;
  - Floor 5 missing from `FloorRegistry` (`test_save_manager`, `test_floor_05_run`);
  - stairs back up from Floor 5 to Floor 4;
  - **a persistence test that forgets to choose its own save file** (`test_save_manager`,
    `test_save_game`, `test_floor_05_run` all fail with the guard's refusal; nothing is written);
  - **the save guard switched off** (`test_save_isolation`).
- **Bug found and fixed by the suite:** the first version of the guard asked the SaveManager
  node for its tree, which does not exist yet when a test sets its save path in `_initialize()`
  (`test_surface_traversal.gd` does). The guard then errored and refused, failing closed, which
  is safe but wrong. It now uses `Engine.get_main_loop()`, which always works.
- **Real playthrough** (a scratch copy with its own user-data folder, a real 1280×720 window,
  driven by key events through Godot's input pipeline with the arrow keys steered along
  navigation routes, like a player; logs and screenshots inspected). Three sessions:
  1. from the **real Phase 7 Floor 4 save (version 2)**: the title offered Continue; Floor 4
     opened with Carl 80, **Donut 60 / 60** (migrated) and the save became version 3. The Floor 4
     blob went for Carl; Carl stood just behind Donut, so its touches took her 60 → 30 while her
     three scratches (10 each, a second apart) killed it. Carl walked to the new stairs →
     **Floor 5 with Carl 80 and Donut 30** (carried over, not healed), saved as version 3.
     The **penned blob picked Donut** at once, walked round the pen wall, and **downed her**
     (30 → 0; her two scratches left it at 10): **no GAME OVER**, the HUD said "Donut HP: 0 / 60 -
     DOWNED", **and the blob switched to Carl**, who **punched it dead (D)**. With the **menu
     open for 2 s her countdown stayed at 5.98 s**. She **got up 8.06 s after going down, 6.06 s
     of play without the menu, with 30 / 60**, and **followed Carl**. A **Slingshot stone (W)**
     hit the second blob (−10); Carl stood behind Donut and **she scratched it again** twice to
     kill it. The Spitting Blob then shot Carl to 0: **GAME OVER** froze everything for 3 s;
     Enter → **Carl 80, Donut 30** (Floor 5 entry), enemies as authored. Quit, exit 0.
  2. an earlier session from the same save showed Donut fighting on Floor 4 and 5 (scratches,
     hits), the second blob targeting Carl, a potion on **A** (30 → 60), the Spitting Blob's globs
     stopped by walls and hitting only in sight, and GAME OVER / retry to the entry HP;
  3. a session from a Floor 5 checkpoint (Carl 60, Donut 50) where the second blob, with Carl
     standing behind her, downed Donut (no GAME OVER, DOWNED on the HUD), the menu held her
     countdown (5.28 s before and after 2 s), and she got up after 6 s of play with 30 / 60.
  No engine errors in any session (the only messages were from the scratch driver itself).
- **Real process restart** (a fresh `godot --path <copy>`, the normal entry point with no
  script, real Windows key events via `keybd_event`, sent only while the game window was in
  front; a logging-only observer autoload):
  - the title showed "Saved at the start of Floor 5 - HP 80 / 100"; **Enter opened Floor 5
    directly** with Carl 80, **Donut 30 / 60**, `W: Slingshot   A: Potion x1   S: —   D: Fists`, and
    the three enemies as authored;
  - companion combat after Continue: the penned blob went for Donut, she scratched it twice, it
    downed her with no GAME OVER, **it switched to Carl**, and she **got up exactly 6.0 s later**
    with 30 / 60; then W, A and D were pressed: the penned blob (10 HP, pressing Carl) died as
    they began (the observer does not log which hit), and A drank the potion (30 → 60); after
    Right, Donut followed Carl;
  - the save was unchanged; Alt+F4 closed the game normally (exit 0); no engine errors.
- **Migration with real fixtures, real restarts** (the same copy, real keys): the Phase 5
  **version 1** Floor 2 save → Continue opened Floor 2 with Carl 70, 2 potions on S and **Donut
  60 / 60**, and the file became version 3 (`owned_items: []`, Donut 60 / 60); the Phase 6
  **version 2** Floor 3 save → Floor 3 with the Slingshot on W and Donut 60 / 60, file version 3.
  The Phase 7 **version 2** Floor 4 save is session 1 above. All exited 0 with no engine errors.
- **Visual check** (screenshots inspected) at 1280×720, 640×360 and 1024×768: Floor 5 on arrival
  ("Carl HP" and the orange "Donut HP: 40 / 60" side by side above the slot bar; the three signs);
  a Scratch (an orange ring around Donut, the blob flashing); Donut downed (grey, on her side, a
  red "DOWNED" label; the HUD in red "Donut HP: 0 / 60 - DOWNED"); the action menu; GAME OVER with
  Donut downed; the title with a Floor 5 save ("Version 0.8.0"). Donut, orange with ears, is easy
  to tell from the green and purple blobs and the projectiles. Everything is readable and on
  screen; at 640×360 the HUD text is small but legible, as in earlier phases.

## Known issues / limitations
- **Donut and party targeting (Phase 8 placeholders and simplifications):**
  - the downed look is a placeholder: her shapes greyed and turned on their side, and a small
    "DOWNED" label; no animation, sound or particle. Scratch shows only a brief orange circle;
  - recovery is a fixed 6 s countdown with no revive action. It holds while Carl is down, which in
    a level is GAME OVER anyway;
  - Scratch hits the enemy nearest her centre, not the one she "faces" (she has no facing), and
    only an enemy within reach: she never steps toward one. An enemy standing just beyond her
    reach while it spits or waits is never scratched;
  - a downed Donut stays where she fell. Carl can walk far away; when she gets up she catches up
    through the navigation mesh at 200 px/s (no teleport). A new floor always starts her next to
    Carl;
  - enemies pick the nearest party member only when they have no target, using straight-line
    distance (walls included), and drop a target only when it is downed or beyond chase range.
    So an enemy chasing Carl ignores Donut scratching it, and one that notices Donut first keeps
    going for her even if Carl hits it. There is no threat or aggro system;
  - after a downed target, enemies re-pick within their detection range (220 / 360 px), not
    their chase range, so one can go idle next to a Carl standing 250 px away;
  - Donut has no hurt-invulnerability either: a touch and a glob can land in the same moment;
  - the HUD shows Donut's HP but not how long until she gets up;
  - the title's save line shows Carl's HP only, not Donut's.
- **Test save isolation:** the guard identifies a test or tool run by its main loop having a
  script (`godot -s`). A tool that runs the real main scene without `-s` (as the scratch
  playthrough copies do) is treated as the game, which is why those always use a copy with its
  own `config/custom_user_dir_name`. The guard does not stop the game run from the editor (F5)
  from using the player's save: that is the game, and it is meant to.
- **Enemies (Phase 7 simplifications):**
  - detection is by straight-line distance, not sight (as in Phase 2): a Blob notices Carl
    through a wall, and a Spitting Blob notices a hidden Carl and walks round to find him.
    Only spitting needs line of sight;
  - (Phase 8: "Carl" below means the enemy's target, Carl or Donut);
  - line of sight is one ray from the Spitting Blob's centre to Carl's centre. If only the edge
    of Carl shows past a wall, it counts him as hidden;
  - globs fly at where Carl is when spat and do not lead a moving target, so a Carl who keeps
    moving across its line dodges them. This is intended;
  - enemies do not steer around each other or Donut (no navigation avoidance). Two enemies
    push and slide along each other, and they pass through Donut's body, whose `companion` layer
    is not in their mask (they still hurt her through her Hurtbox);
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
- **Floors 3, 4 and 5 are small combat-test rooms.** Floor 5 has no exit ("Prototype: the way
  further down is not built yet."). The Floor Guardian, Dungeon Brute and prototype-complete
  exit (GAME_SPEC §14) are later work. Floor 5's penned blob goes for Donut as soon as she
  arrives (by design); a player who walks straight on leaves her to fight it alone.
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
Phase 8 reads Phase 5 (version 1) and Phase 6/7 (version 2) saves and upgrades them to version 3
the next time a floor is entered; Donut then starts at 60 / 60. Tests never touch that file.
1. Open the project in Godot 4.7.2 and let it import the new files. The Output panel should
   show no errors.
2. Press **F5**. With an older save, **Continue** opens your floor as before; the HUD now shows
   "Carl HP" and, beside it, "Donut HP: 60 / 60".
3. Play to Floor 4 (Continue, or New Game and down through the floors). Floor 4's second sign
   now says the stairs down to Floor 5 are in the far south-east corner. On the way, let a
   Spitting Blob glob hit Donut: her HP drops by 10. Your punches and stones never hurt her.
4. Take the stairs ("Down to Floor 5"). Floor 5, "Holding Pens": Donut's HP is what it was on
   Floor 4 (not healed).
5. Stand still. The blob in the pen south-west of you walks round its wall and goes for Donut.
   Its touch takes 10 from her; she scratches it (a small orange flash) for 10 about once a
   second, without leaving you. Help her with Fists (D) if you like.
6. Let Donut run out of HP (for example, stand so she is between you and the Spitting Blob). She
   greys out, lies on her side and shows "DOWNED"; the HUD says "Donut HP: 0 / 60 - DOWNED".
   The game goes on: no GAME OVER. Enemies turn to you.
7. Press **Space** for a few seconds while she is down, then close it: the menu time does not
   count. About 6 s of play after going down she gets up with 30 / 60 and follows you again.
8. Let Carl lose: GAME OVER as always. **Enter**: Carl and Donut are back at the HP they had when
   you entered Floor 5, and the enemies are back.
9. Close the window. **F5**: "Saved at the start of Floor 5 …". **Enter** opens Floor 5 directly
   with Carl's and Donut's HP, your items and slots.
10. On the title, New Game (Down, Enter, Down, Enter for Yes) starts over with Donut at 60 / 60.

## Next phase
Phase 9 is **not specified** here. Provide its prompt, with acceptance criteria, after
Phase 8 is reviewed. (Stairs that open only after goals or events, discussed as a possible
future design, were deliberately not started.)

Groundwork for later phases:
- **Donut:** her numbers are exports on `donut.tscn` (`Health.max_health`, `down_time`,
  `recovery_health`, the Scratch `MeleeAttack`). A revive action, healing items for her or
  commands would build on `Health.revive()` and her script; her HP is already run state and
  saved (version 3).
- **More enemies:** a scene whose root script extends `Enemy` and writes its own
  `_physics_process()` from `update_activity()` (which chooses Carl or Donut),
  `navigate_toward()`, `stop_moving()` and `has_line_of_sight_to()`, with `Health`, a `Hurtbox` on
  `enemy_hurtbox`, an `EnemyNavigation` agent, and its attack (a `MeleeAttack` or a
  `ProjectileLauncher` with its own `Projectile` scene on `player_hurtbox`). Levels only place it.
- **More items:** a new ranged weapon is a `ProjectileLauncher` scene with its own
  `Projectile` scene and numbers; a reusable or consumable item is one `.tres` plus a line in
  `ActionRegistry`. Carl never changes.
- **More floors:** a new scene, stairs down from the previous floor (Floor 5 has none yet),
  and a line in `FloorRegistry`.
- **Save format changes:** bump `SaveManager.SAVE_VERSION` to 4, add `_migrate_version_3()`,
  and chain the migrations in `decode()`.
