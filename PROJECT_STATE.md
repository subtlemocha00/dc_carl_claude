# PROJECT STATE

## Engine
Godot 4.7.2 stable (Standard build, not .NET)

## Language
GDScript

## Current phase
Phase 13 — Persistent Control Rebinding and Settings Menu: **complete, awaiting human review**.
- Phase 12 — Enemy Loot Drops, Blast Bombs, Area Damage and Floor 7: complete (commit `b471ffe`).
- Phase 11 — Project Data Isolation, Windows ANGLE Stability and Title-Screen Quit: complete
  (commit `41c57f2`).
- Phase 10 — Pause Menu, Return to Title, Clean Quit and Runtime Stability: complete (commit
  `8dff143`).
- Phase 9 — Second Reusable Weapon (Baseball Bat), Knockback, Combat Reactions and Floor 6:
  complete (commit `042d76b`).
- Phase 8 — Donut Health, Companion Combat, Enemy Targeting, Save v3 and Floor 5: complete
  (commit `3351ceb`).
- Phase 7 — Enemy Navigation, Ranged Enemy Combat and Floor 4: complete (commit `02b1fb2`).
- Phase 6 — Reusable Weapon, Projectile Combat, Save Migration and Floor 3: complete (commit
  `c2da685`; `08564ea` then added `.vscode/settings.json`).
- Phase 5 — Persistent Save/Load and Continue: complete (commit `fd1d5e7`).
- Phase 4 — Inventory, World Loot, Consumable Action and Floor 2: complete (commit `4ea1123`).
- Phase 3 — Action Slots, Action Menu and Run State: complete (commit `a7ef551`).
- Phase 2 — First Combat Loop: complete (commit `074114d`).
- Phase 1 — First Traversal Slice: complete (commit `3cb8854`).
- Phase 0 — Project Foundation: complete (commit `37b2c87`).

There are no `PHASE_02_*.md` to `PHASE_13_*.md` files. Phases 2–13 came from the owner's
prompts. Their acceptance criteria are recorded in `ACCEPTANCE_TESTS.md`.

## Canonical design decisions (do not reintroduce the old behaviour)
Phase 3 decisions, still in force:
- **Movement is the arrow keys only.** W/A/S/D never move Carl.
- **W/A/S/D are configurable action slots.** A new game has **Fists in D** and W, A and S
  empty. The player changes what each slot holds in the in-game action menu (Space).
- **The keys themselves are fixed.** Rebinding physical keys is a separate, future
  settings concern. (Superseded in Phase 13: the nine gameplay controls can be rebound in
  Settings; the slots stay the same four logical slots, and the menus' own keys stay fixed.)
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

Phase 9 decisions (also written into `GAME_SPEC.md` §8, §9, §10, §14a, §14b, §14c and §15):
- **The Baseball Bat** (id `baseball_bat`) is the second reusable weapon: found once on Floor 5,
  owned, no quantity, never used up, no ammunition, on any of W/A/S/D. It is a `MeleeAttack`
  scene, like Fists: **20 damage**, **0.75 s** cooldown (45 ticks), a **28 px** circle centred
  **36 px** ahead, so it reaches **8–64 px** in front of Carl's centre (an enemy's centre up to
  78 px away straight ahead, since a blob's Hurtbox is 14 px). It hits every enemy in that area
  (like Fists), only enemies (`enemy_hurtbox`), and **never through a wall** (a ray on `world`
  from Carl's centre to the target's centre).
- **Knockback** is new and reusable: **80 px** in the swing's direction over **0.3 s** (18 ticks),
  fast first then slowing (tick i of 18 moves 80 × (18 − i) / 171 px: 8.4 px, then 7.9 px, …,
  0.47 px; the push starts at 505 px/s). Walls stop it (`move_and_slide()`). A killing hit
  never pushes.
- **Reaction rule:** while pushed, an enemy does nothing else (no target choice, navigation or
  attack), then carries on; its cooldowns keep counting, so the Spitting Blob's next glob is
  exactly one cooldown after its last one.
- **Only enemies can be pushed**, and **only the Bat pushes**: Carl and Donut have no
  `KnockbackReceiver`; Fists, stones, Scratch and enemy attacks pass no knockback.
- **Floor 5** gains the Bat pickup and **stairs down to Floor 6**; **Floor 6** (`floor_06`, "Batting
  Cage") is a knockback test floor with no exits. Progression: Surface → … → Floor 6, downward only.
- **Checkpoints:** a Bat found on Floor 5 is not in the Floor 5 checkpoint (retry or Continue
  takes it back, pickup back, slot empty); the Floor 6 checkpoint owns it, with its slot.
- **The save stays version 3.** The Bat is one more id in `owned_items`, which already holds any
  reusable item generically; Floor 6 is one more `floor_id`. Nothing about knockback is saved.
- **Phase 9 choices the prompt left open** (the narrowest fit with the existing code):
  - the Bat hits every enemy in its circle (as Fists do), not only the nearest;
  - the push goes in the swing's direction (Carl's facing), which is always away from Carl for
    anything the circle can reach;
  - facing may be diagonal, as it has been for every action since Phase 2 (Carl faces his last
    movement direction, diagonals included); the prompt's "up/down/left/right" was taken as a
    description, and Carl's movement/facing code was left unchanged;
  - a push that meets a wall simply keeps pressing into it until its 0.3 s are over (the enemy
    stays put, or slides along a wall hit at an angle); it does not end early;
  - a new hit during a push restarts the push (the Bat's cooldown is longer than a push anyway);
  - the knockback event carries direction, distance and duration only: no source (nothing needs
    it yet).

Phase 10 decisions (also written into `GAME_SPEC.md` §4, §15 and §15a):
- **Escape during play opens the pause menu**: Resume, Return to Title, Quit Game, Resume
  selected each time. Up/Down choose (wrapping), Enter confirms, Escape resumes.
- **One pause model:** the pause menu pauses the scene tree, exactly as the action menu and GAME
  OVER already did. Everything in play counts physics ticks (cooldowns, pushes, Donut's
  countdown, projectiles), so all of it stops, and nothing needed its own pause flag.
- **Only one modal at a time:** the action menu and the pause menu each open only while the tree
  is not paused, and an open menu takes every key press. So Escape closes the action menu without
  opening the pause menu, Space never opens the action menu over the pause menu, and neither
  opens over GAME OVER.
- **Escape at GAME OVER does nothing** (the narrower of the two options the prompt allowed):
  GAME OVER keeps Enter = retry and nothing else; the window can still be closed.
- **Return to Title and Quit Game ask first** ("… Progress since entering this floor will be
  lost.", No selected; Escape and No go back to the pause menu, still paused).
- **Leaving never saves.** The save keeps the floor-entry checkpoint. Return to Title goes to the
  title screen in the same process; the title screen drops the run from memory
  (`GameState.end_run()`), describes the save file, and Continue loads it from disk. Quit Game
  calls `quit()`; closing the window is left to Godot's default (quit, no question), and nothing
  writes on the way out either way.
- **The pause menu belongs to every level, from `Level._ready()`**, not to the floor scenes, so no
  floor has pause logic and future floors get it for free.
- **The save stays version 3.** Pausing, its selection and its questions are never saved.
- **Lifecycle fix (found in this phase):** stairs no longer change level once the game is frozen
  (see Architecture > Pause menu and the game session).
- **Phase 10 choices the prompt left open** (the narrowest fit with the existing code):
  - No in a question goes back to the pause menu (still paused), not straight to the game;
  - the pause menu's selection wraps round (Up on Resume selects Quit Game);
  - a key held while resuming counts as released until let go (the existing
    `NOTIFICATION_UNPAUSED` rule in `carl.gd`), as after the action menu;
  - the HUD hint now reads "Space: action menu     Esc: pause";
  - closing the window never asks (Godot's default), as the prompt preferred.

Phase 11 decisions (also written into `GAME_SPEC.md` §4, §15 and §15b):
- **The project has its own user-data folder, "DC CARL"** (`application/config/use_custom_user_dir
  = true`, `application/config/custom_user_dir_name = "DC CARL"`). Until now it used Godot's
  default folder for its name, `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype`,
  which the sibling project `../codex` (same `config/name`) also uses, so each could overwrite the
  other's save (it happened during Phase 10). `config/name` is unchanged; only the folder moved.
- **The old shared folder is not this project's any more.** Nothing reads, moves, copies, imports
  or cleans it, and nothing searches other folders for saves: its save may be the other project's,
  in another format. So the first launch after Phase 11 has no save ("No saved game yet.";
  Continue unavailable), which is expected. (The save *format* migrations, versions 1 and 2 to 3,
  are unchanged; they apply to files in the new folder.)
- **SaveManager is unchanged**: still `user://savegame.json`; Godot decides where `user://` is.
- **Windows renders through ANGLE:** `rendering/gl_compatibility/driver.windows =
  "opengl3_angle"`. The project is still a Compatibility-renderer project; every other platform's
  driver and the two fallbacks (`fallback_to_angle`, `fallback_to_native`) stay at Godot's
  defaults. Reason: the intermittent crash on exit found in Phase 10 is in Intel's OpenGL driver
  and never happened through ANGLE. Native OpenGL is still available for diagnosis with
  `--rendering-driver opengl3`. No graphics option for the player.
- **The title screen has Quit Game.** It quits at once with no question (nothing on the title can
  be lost), through `get_tree().quit()`, like the pause menu's Quit Game. Continue (or New Game
  when no save loads) is still the first selection, never Quit Game.
- **Phase 11 choices the prompt left open** (the narrowest fit with the existing code):
  - Up/Down go round the title's options (Up on the first selects Quit Game), as in the pause menu;
    an unavailable Continue is skipped, as before;
  - with no save that loads, the Continue row is still shown, greyed, as in Phases 5–10, above
    New Game and Quit Game;
  - the folder name is exactly `DC CARL` (with the space), which Godot 4.7.2 accepts as is:
    `OS.get_user_data_dir()` is `C:/Users/Owner/AppData/Roaming/DC CARL` on this machine.

Phase 12 decisions (also written into `GAME_SPEC.md` §8, §9, §10, §14c, §14d, §15 and §18):
- **The Blast Bomb** (id `blast_bomb`, "Blast Bomb") is the first area-damage item and the second
  consumable: counted in the one inventory like the potion ("Blast Bomb x2"), one spent per
  successful throw, gone (and its slot emptied) at 0, assignable again after collecting more. It is
  neither owned like the Slingshot/Bat nor innate like Fists. **Carl's script is unchanged**: the
  generic dispatch (slot → definition → performer → spend one if consumable) throws it.
- **Throw:** its performer is an ordinary `ProjectileLauncher` (**1.0 s** cooldown = 60 ticks)
  throwing `scenes/projectiles/blast_bomb.tscn`, an ordinary `Projectile`: **220 px/s**, at most
  **240 px** (66 ticks, 1.1 s), `target_layers` enemy_hurtbox (so an enemy stops it), stopped by
  `world`, **damage 0** (the impact itself hurts nobody). Facing as for every action (the last
  movement direction, diagonals included); no mouse aiming, no arc.
- **Detonation:** a child `DetonateOnStop` listens to the projectile's `stopped` signal, which a
  `Projectile` emits exactly once (enemy hit, wall hit, or range used up), and puts **one**
  explosion where it stopped (2 px back out of a wall's face, so the centre is never on or in the
  wall). The projectile then frees itself as always. So a bomb can never explode twice.
- **Area damage** is a new reusable component, `AreaDamage` (`scripts/combat/area_damage.gd`,
  the explosion scene's root): on `detonate()` (once only) it damages every Hurtbox on its
  `target_layers` overlapping a circle of `radius` around it, **once each**, through
  `Hurtbox.take_hit(damage)` (so Health, hit flashes and deaths work as for every attack), skips
  Hurtboxes that cannot be hit (dying), that belong to its `source`, or that are **shielded**: a ray
  from its centre to the Hurtbox's centre on `blocking_layers` (`world`, the layer Spitting Blob
  sight and projectiles already use) hits a wall. It passes **no Knockback**. Then it draws a
  fading orange disc and ring the size of the area for 0.35 s (21 ticks, pausing with the game) and
  frees itself. It knows nothing about bombs or enemy types.
- **The Blast Bomb's explosion:** **20 damage**, **72 px** radius (a blob's 14 px Hurtbox is reached
  when its centre is up to 86 px away), `enemy_hurtbox` only, walls shield. **Carl and Donut are on
  `player_hurtbox`, so no explosion of Carl's can hurt them**, even at its centre; and none pushes
  anyone (the Bat stays the only knockback).
- **Deterministic enemy drops:** `LootDrop` (`scripts/enemies/loot_drop.gd`), a child node of an
  enemy placed in a level, with `item` and `quantity`. When the enemy's Health dies it creates an
  ordinary `item_pickup.tscn` (class `ItemPickup` since this phase) where the enemy died, added next
  to it in the level (deferred to the end of the physics step: the pickup is an Area2D). The death
  alone gives nothing; the pickup's own rules apply (only Carl's body, once). No chances, rarity or
  loot tables. Enemy scenes are unchanged; any enemy with a `Health` child can carry one.
- **Floor 6** gains the drop (its south-west Gelatinous Blob, `Actors/GelatinousBlob`, carries
  Blast Bomb x2, marked by the sign "This blob carries Blast Bombs."), stairs down to Floor 7 in the
  far south-east corner, and its note `Signs/PrototypeNote` became `Signs/StairsHint`.
- **Checkpoints:** unchanged rules. Bombs dropped on Floor 6 are not in the Floor 6 checkpoint (made
  on entry), so a retry, Return to Title or quitting takes them back (their slot empties, then
  refills from the checkpoint layout), the blob is authored alive and no drop exists; Floor 7's
  checkpoint holds the bombs carried in, with their slot. Nothing saves on death, pickup or throw.
- **Floor 7** (`floor_07`, "Floor 7 - Blast Range", 36 × 20 tiles) is an area-damage test floor:
  a pair of Gelatinous Blobs one blast can reach together, a Gelatinous Blob shielded by a thin
  wall, a Spitting Blob with a pillar. No exits. Progression: Surface → … → Floor 7, downward only.
- **The save stays version 3.** Its `inventory` already stores any consumable's quantity by stable
  id (validated through `ActionRegistry`: known, not innate, not reusable, a whole number 0–999) and
  `floor_id` any registered floor. The two registry lines were all the save needed. No drop, bomb in
  flight or explosion is ever saved.
- **Phase 12 choices the prompt left open** (the narrowest fit with the existing code):
  - the prompt's recommended numbers were kept: 220 px/s, 240 px, 72 px (at 32 px tiles 72 px is
    2¼ tiles: a pair of blobs 32 px apart is easily caught, a whole room is not);
  - "within the radius" means the Hurtbox overlaps the circle, the same rule every melee attack
    uses; "behind a wall" means a wall on the line between the two centres, the Bat's rule;
  - the thrown bomb stops on the first enemy Hurtbox in its path (a direct hit) and explodes there;
    the impact itself deals nothing, so the enemy it hit takes exactly the blast's 20 once;
  - a dying enemy's Hurtbox cannot be hit, so it neither stops a bomb nor takes blast damage (as
    for stones);
  - the drop appears exactly where the enemy's centre was when it died, and belongs to the level
    (next to the enemy, which fades out), not to the enemy;
  - the loot blob is the south-west one (in the open, reachable, away from the Backstop and the
    Spitting Blob), and keeps its node name `GelatinousBlob`, which Phase 9's tests use;
  - Floor 7's loot and stairs: none (the prompt asked for no exit and no Floor 8);
  - the drop reuses the pink pickup label colour; the bomb has its own 32 × 32 icon, used by the
    pickup (the menu and HUD show names only, as for every item).

Phase 13 decisions (also written into `GAME_SPEC.md` §4, §5, §8, §15, §15a, §15b, §15c and §16):
- **Slot contents are run state; key bindings are application settings.** The four action slots
  stay the logical slots `action_w` … `action_d` ("the W slot"), saved in the checkpoint as before.
  Which physical key triggers each is a setting, kept apart from the save. Changing a key never
  moves or clears what a slot holds, and nothing about slots changed in the save.
- **Nine rebindable gameplay controls**, exactly the existing InputMap actions: `move_up`,
  `move_down`, `move_left`, `move_right`, `action_w`, `action_a`, `action_s`, `action_d`,
  `inventory_toggle`. Canonical defaults (Reset to Defaults): the arrow keys, W/A/S/D, Space, the
  same as `project.godot`, so a player without a settings file sees no difference.
- **Fixed menu keys:** menus no longer read the movement actions. New InputMap actions `menu_up`,
  `menu_down`, `menu_left`, `menu_right` (the arrow keys) drive the title, the pause menu, its
  questions, the action menu's selection and the Settings screen, next to the existing
  `ui_confirm_game` (Enter) and `pause_back` (Escape). None of the six can be rebound, so no binding
  can make a menu unusable. (By default the arrows are both movement and menu keys, on purpose: a
  menu never moves Carl, and play never moves a selection.)
- **Settings** is on the title (Continue, New Game, **Settings**, Quit Game) and in the pause menu
  (Resume, **Settings**, Return to Title, Quit Game). Both instantiate the same scene,
  `scenes/ui/settings_menu.tscn`. From the pause menu the game stays paused throughout.
- **One section, Controls:** the nine controls with their keys, Reset to Defaults, Back. No empty
  Audio/Graphics pages.
- **Capture:** Enter on a control waits for the next key press, which becomes its key at once
  (applied and saved); Escape cancels. The press is used up: its key repeat and release are ignored
  by the screen, and the changed action counts as released until its new key is pressed again, so
  it never also triggers the gameplay action (and Carl's existing held-through-unpause rule covers
  holding it through Resume).
- **Conflicts are refused, never swapped or stolen:** "Q is already assigned to Action Slot W.";
  one pool of keys for movement, slots and Inventory.
- **Reserved and unusable keys:** Escape, Enter and keypad Enter are reserved. Allowed: printable
  keys (letters, digits, Space, punctuation), Tab, Backspace, Insert, Delete, Home, End, Page Up/Down,
  the arrows and the keypad digits/operators. Refused: modifiers alone, lock keys, **function keys**
  (F10 is special to Windows) and media keys. No chords.
- **`SettingsManager`**, a third autoload (`scripts/autoload/settings_manager.gd`): defaults,
  current bindings, validation, InputMap application, loading before the title appears, the safe
  write, Reset to Defaults and the test-path guard. `ControlBindings`
  (`scripts/settings/control_bindings.gd`, static) holds the list of controls, their names and
  defaults, the key policy and the key names, and reads the InputMap for the UI. SaveManager and
  GameState are unchanged in role and know nothing about bindings.
- **Settings file** `user://settings.json` (`%APPDATA%\DC CARL\settings.json`), its own format
  `settings_version: 1` (the save stays `save_version: 3`), stable control ids and key names:
  `{"settings_version": 1, "keyboard": {"move_up": "I", ..., "inventory_toggle": "Tab"}}`.
- **Invalid settings files are ignored as a whole** (defaults applied, a message on the title and the
  Settings screen, the file left until the next change replaces it); they never affect the save.
- **Dynamic hints:** the HUD slot bar and hint, the action menu's slot column, "(on …)", details and
  help line, and the two signs that name keys (Surface, Floor 1) all show the current keys.
- **Phase 13 choices the prompt left open** (the narrowest fit with the existing code):
  - `SettingsManager` is an autoload although `ARCHITECTURE_RULES.md` §4 names only GameState and
    SaveManager: the prompt asked for it by name, and only an autoload is guaranteed to have applied
    the bindings before the main scene (the title) exists. It is the only addition;
  - the menus got their own fixed actions (`menu_*`) rather than Godot's `ui_up`/`ui_down`, whose
    defaults also include gamepad buttons (no controller support yet);
  - keys are stored by Godot's layout-independent key name (`OS.get_keycode_string()`, "Q", "Tab",
    "Kp 1") and bound by physical position, as `project.godot` always did;
  - a refused capture (conflict, reserved, unusable key) ends the capture with its message; press
    Enter to try again;
  - in the action menu the fixed menu keys win over a control bound to the same key (Escape, Up and
    Down always work there); a slot on Up or Down Arrow can then only be assigned by moving it;
  - an unusable settings file is not rewritten on load (so a newer version's file is not destroyed);
    the title says the defaults are in use until the next change or Reset writes a valid file;
  - a test run loads a settings file at startup only when given `--settings-file=<file in
    user://test_saves/>` (for the restart tests); the game always loads `user://settings.json`.

## Implemented
- **Title screen** (main scene):
  - **Continue** (available only when the save loads) resumes the saved floor checkpoint;
    a line shows where, for example "Saved at the start of Floor 3 - HP 80 / 100".
  - **New Game** starts a clean run on the Surface (100 HP, no items, no Slingshot, Fists on
    D; Donut 60 / 60). If a save file exists, it first asks "Start a new game? Existing progress will be
    replaced." with No selected.
  - An unloadable save shows "Save data could not be loaded." and leaves Continue
    unavailable.
  - **Quit Game (Phase 11)** closes the game at once, without a question, saving nothing.
    Continue (or New Game when no save loads) is selected first, never Quit Game.
  - **Settings (Phase 13)**, between New Game and Quit Game, opens the Settings screen; no run is
    started. A red line "Control settings could not be loaded. Defaults restored." shows while
    `SettingsManager.load_failed` is set.
  - **Phase 10:** it is also where Return to Title lands, in the same process. On opening it
    drops the run from memory (`GameState.end_run()`) and reads the save again, so its line
    describes the saved checkpoint, never the floor just left.
- **Pause menu (Phase 10,** `scenes/ui/pause_menu.tscn` + `scripts/ui/pause_menu.gd`**):** Escape
  during play. "Paused" with Resume / Settings (Phase 13) / Return to Title / Quit Game (a CanvasLayer on layer 11,
  above the HUD and the action menu, over a dimmed screen); the two leaving options first ask
  "Return to title? / Quit game?" + "Progress since entering this floor will be lost." with No
  and Yes (an orange-bordered panel like the title's New Game question). Every level adds one in
  `Level._ready()`. See Architecture > Pause menu and the game session.
- **Settings screen (Phase 13,** `scenes/ui/settings_menu.tscn` + `scripts/ui/settings_menu.gd`**):**
  "Settings" / "Controls", the nine controls with their current keys (blue; "..." in orange while
  waiting), Reset to Defaults, Back, a message line and "Up/Down: choose     Enter: change     Esc:
  back"; the Reset question ("Reset all controls to defaults?", No / Yes) in an orange-bordered panel
  like the title's. One instance in the title scene and one in the pause menu scene. See Architecture
  > Settings and control bindings.
- **SettingsManager autoload (Phase 13):** the control bindings in `user://settings.json`
  (`settings_version: 1`), applied to the InputMap before the title appears.
- **Carl** (`scenes/actors/carl.tscn`): **code unchanged in Phases 6–13** (Phase 8 only puts his scene
  in the `party` group; Phase 9 added the Bat and Phase 12 the Blast Bomb without touching his script;
  Phase 13 only corrected his description comment: he reads input actions, so rebinding needs nothing
  from him).
  - Movement (the `move_*` actions, arrow keys by default) at 180 px/s, wall collision, facing arrow,
    smoothed camera.
  - **Action slots:** holding a slot's key (W/A/S/D by default) uses the slot's action toward his
    facing direction. An empty slot does nothing.
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
- **Baseball Bat (Phase 9):** `resources/actions/baseball_bat.tres` (reusable: `consumable` false,
  with an original 32×32 placeholder icon `assets/items/baseball_bat.png`: a tan wooden bat with
  a dark grip, lying diagonally) + `scenes/actions/baseball_bat.tscn` (a `MeleeAttack`: 20 damage,
  reach 36 px, radius 28 px, 0.75 s cooldown, targets `enemy_hurtbox`, blocked by `world`, 80 px
  knockback over 0.3 s, a brief tan swing circle). See Architecture > Knockback.
- **Blast Bomb (Phase 12):** `resources/actions/blast_bomb.tres` (consumable, with an original 32×32
  placeholder icon `assets/items/blast_bomb.png`: a dark round bomb with a lit fuse) +
  `scenes/actions/blast_bomb.tscn` (a `ProjectileLauncher`, 1.0 s) throwing
  `scenes/projectiles/blast_bomb.tscn` (a `Projectile`: 0 impact damage, 220 px/s, 240 px, stopped by
  enemies and walls; a charcoal bomb with a grey trail and an orange fuse spark) whose
  `DetonateOnStop` makes one `scenes/effects/blast_explosion.tscn` (an `AreaDamage`: 20 damage,
  72 px, `enemy_hurtbox`, walls shield; a fading orange disc and ring the size of the blast). See
  Architecture > Area damage.
- **Item pickup:** `scenes/props/item_pickup.tscn` (`ItemPickup` since Phase 12), a reusable Area2D.
  It bobs gently and shows its item's icon (the Slingshot, the Bat, the Blast Bomb) or, without an
  icon, a pink diamond (the potion), and a label from `ActionDefinition.get_label()`: "Potion x2",
  "Slingshot", "Baseball Bat", "Blast Bomb x2". **Phase 12:** it can also be created while the game
  runs (by a `LootDrop`); it then works exactly like a placed one.
- **Enemy loot drops (Phase 12):** `LootDrop` (`scripts/enemies/loot_drop.gd`), a child of an
  enemy placed in a level. See Architecture > Enemy loot drops.
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
  Scratch damage it through the same `Hurtbox` → `Health`. **Phase 9:** a `KnockbackReceiver`, so
  the Bat pushes it back.
- **Spitting Blob (Phase 7,** `scenes/enemies/spitting_blob.tscn`**):** a purple, spiky blob with
  a spout that turns toward its target. 30 HP; it spits `scenes/projectiles/spit_glob.tscn` (a
  violet teardrop glob with a trail) through its `SpitLauncher`, a `ProjectileLauncher` (1.5 s).
  Phase 8: its target may be Donut; its globs hurt her too. Phase 9: a `KnockbackReceiver`, like the
  Gelatinous Blob. See Architecture > Enemies.
- **Phase 12:** both blobs take the Blast Bomb's 20 through their existing Hurtbox; neither scene
  changed.
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
  - the signs "Floor 5 - Holding Pens", `Signs/Hint` "The stairs down to Floor 6 are in the far
    south-east corner." (Phase 9; it used to be `Signs/PrototypeNote`, "Prototype: the way further
    down is not built yet.") and "Donut fights back now. If she is downed, she gets up again after
    a while.", HUD and menu;
  - **Phase 9:** the **Baseball Bat pickup** (`Pickups/BaseballBat`) at (432, 144), 256 px east of
    and just north of Carl's arrival point, in view from it and clear of the signs and of the
    routes the Floor 5 tests walk;
  - **Phase 9:** **stairs down to Floor 6** at (1072, 560), the far south-east corner, labelled
    "Down to Floor 6". No stairs back up.
- **Floor 6 (Phase 9,** `scenes/levels/floor_06.tscn`**, "Batting Cage", 36×20 tiles, 1152×640 px):**
  - Carl arrives at (176, 176), Donut at (176, 232), as on Floor 5;
  - the **Backstop** wall (2×8 tiles, x 576–640, y 96–352) and the **Backstop blob**
    (`BackstopBlob`, a Gelatinous Blob) just in front of it at (536, 208), its centre 40 px from the
    wall's face: 360 px from Carl's arrival point, so it waits until he comes closer. When Carl
    walks up and swings at it, it has usually moved only 40–70 px toward him, so the 80 px push
    carries it into the wall, where it stops (at x = 563, its 13 px body against the face at
    576), then it comes back. (It was first placed 64 px from the wall; in the real playthrough
    it walked too far toward Carl for the push to reach the wall, so it was moved closer.)
  - a second **Gelatinous Blob** at (320, 480) in the open south-west, where a push travels its
    full 80 px;
  - a pillar (2×3 tiles, x 768–832, y 384–480) and the **Spitting Blob** at (928, 224), east of the
    Backstop, which hides it from Carl's side at first;
  - the signs "Floor 6 - Batting Cage", `Signs/Hint` "The Baseball Bat knocks enemies back. Walls
    stop them." and `Signs/PrototypeNote` "Prototype: the way further down is not built yet.",
    HUD and menu;
  - **Phase 12:** the south-west `GelatinousBlob` carries a `LootDrop` (Blast Bomb x2),
    marked by `Signs/LootSign` "This blob carries Blast Bombs." at (200–440, 418–438) above it;
    `Signs/PrototypeNote` became `Signs/StairsHint` "The stairs down to Floor 7 are in the far
    south-east corner."; **stairs down to Floor 7** at (1072, 560), labelled "Down to Floor 7"
    (`Signs/StairsSign`). No stairs back up.
- **Floor 7 (Phase 12,** `scenes/levels/floor_07.tscn`**, "Blast Range", 36×20 tiles, 1152×640 px):**
  - Carl arrives at (176, 176), Donut at (176, 232), as on Floors 5 and 6;
  - the **pair**, `PairBlobNorth` (560, 164) and `PairBlobSouth` (560, 196), two Gelatinous Blobs
    32 px apart: a bomb thrown east from (330, 176) (227 px away, so they are still idle) hits the
    north one's Hurtbox and the blast (72 px) reaches both;
  - the **blast wall**, 1 × 4 tiles (x 704–736, y 384–512), and the **`ShieldedBlob`** (a Gelatinous
    Blob) behind it at (768, 448): a bomb thrown east from (500, 448) (268 px away, idle) explodes at
    the wall's west face, 66 px from the blob's centre (inside 72 px), and the wall shields it;
  - a 2×2 pillar (x 832–896, y 256–320) and the **Spitting Blob** at (992, 192) in the east;
  - the signs "Floor 7 - Blast Range", `Signs/Hint` "A Blast Bomb hurts every enemy in its blast.
    Walls block the blast." and `Signs/PrototypeNote` "Prototype: the way further down is not built
    yet.", HUD and menu;
  - **no exits**: no way up, and Floor 8 is out of scope.
- **Stairs** (`scenes/props/stairs.tscn`): stairs **down**. They load `destination_scene_path`
  and ignore Carl for the first 2 physics frames of a level (no transition loops). **Phase 10:**
  they never change level once the game is frozen (Carl killed in the tick he reached them).
- **HUD** (`scenes/ui/hud.tscn`; Phase 13: every key it names is the current binding, for example
  `Q: Slingshot   2: Potion x1 ...` and "Tab: action menu     Esc: pause"): "Carl HP: x / 100" and,
  beside it (Phase 8), "Donut HP: y / 60"
  in orange, or "Donut HP: 0 / 60  -  DOWNED" in red; the slot bar, for example
  `W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists` (no quantity for the Slingshot or the
  Bat); a "Space: action menu     Esc: pause" hint (Phase 10; it said "Space: action menu"); the
  centred GAME OVER panel. Unchanged in Phases 9 and 12: the longest
  slot bar still fits (checked at every window size; since Phase 12 with
  `W: Baseball Bat   A: Potion x2   S: Blast Bomb x12   D: Slingshot`).
- **Action menu** (`scenes/ui/action_menu.tscn`): lists the four slots and Carl's inventory,
  for example "Fists (on D)", "Small Health Potion x1 (on A)", "Slingshot (on W)", "Baseball Bat
  (on S)", "Blast Bomb x2 (no slot)", with a description or confirmation line. Phase 13: the keys it
  names ("1   Slingshot", "(on 1)", "Fists is now on 4.", "Up/Down: choose an action     1/2/3/4:
  put it on that key     Tab/Esc: close") and the keys that assign are the current bindings; its
  selection moves with the fixed `menu_up`/`menu_down`.
- **GameState autoload:** Carl's and Donut's HP, inventory, slots and the floor-entry state (see
  Architecture).
- **SaveManager autoload:** the persistent checkpoint in `user://savegame.json`, format
  version 3, with the version 1 and 2 migrations and the test-run guard (see Architecture).

Not implemented (later phases): gamepad/controller or mouse bindings, key chords, audio, graphics,
resolution, fullscreen, language or accessibility settings, Donut controls, commands, slots or
equipment, Donut items or
healing, a revive key, permanent Donut death, ammunition, more weapons, weapon upgrades or
durability, equipment slots or stats, critical hits, status effects, knockback on anything but
the Bat (explosions included), random loot tables, drop chances, rarity, currency, crafting,
destructible walls, Floor 8, other enemy types (Dungeon Rat, Crawler, Dungeon Brute), bosses (Floor Guardian), the
prototype-complete screen, stairs that open only after goals or events, countdown timers,
shops/economy, multiple save slots, mid-floor or cloud saving, save-anywhere.

## Controls
Rebindable gameplay controls (Phase 13; the key is the default, which Settings > Reset to Defaults
restores):

| Action             | Settings name | Default     | Effect                                                              |
|--------------------|---------------|-------------|---------------------------------------------------------------------|
| `move_up`          | Move Up       | Up Arrow    | Moves Carl north                                                    |
| `move_down`        | Move Down     | Down Arrow  | Moves Carl south                                                    |
| `move_left`        | Move Left     | Left Arrow  | Moves Carl west                                                     |
| `move_right`       | Move Right    | Right Arrow | Moves Carl east                                                     |
| `action_w`         | Action Slot W | W           | Uses the W slot (empty in a new game). In the action menu: put the selection in the W slot |
| `action_a`         | Action Slot A | A           | Uses the A slot (empty in a new game). In the action menu: put the selection in the A slot |
| `action_s`         | Action Slot S | S           | Uses the S slot (empty in a new game). In the action menu: put the selection in the S slot |
| `action_d`         | Action Slot D | D           | Uses the D slot (**Fists** in a new game). In the action menu: put the selection in the D slot |
| `inventory_toggle` | Inventory     | Space       | Opens / closes the action menu (not over GAME OVER or the pause menu) |

Fixed menu and system keys (never rebindable):

| Action             | Key         | Effect                                                              |
|--------------------|-------------|---------------------------------------------------------------------|
| `menu_up` (Phase 13)    | Up Arrow    | Any menu: select the previous row (wrapping where it did before)    |
| `menu_down` (Phase 13)  | Down Arrow  | Any menu: select the next row                                        |
| `menu_left` (Phase 13)  | Left Arrow  | Yes/No questions: toggle                                             |
| `menu_right` (Phase 13) | Right Arrow | Yes/No questions: toggle                                             |
| `ui_confirm_game`  | Enter       | Title, pause menu, Settings: confirm the selection / Yes / No / start waiting for a key. GAME OVER: retry the floor |
| `pause_back`       | Escape      | Play: opens the pause menu. Action menu: closes it (only). Pause menu: resumes. Settings: back (while waiting for a key: cancel). A question: No. GAME OVER: nothing |

Settings screen (Phase 13): **Up/Down** choose a control, Reset to Defaults or Back (wrapping),
**Enter** changes the selected control (then the next key press is its key; **Escape** cancels) or
chooses Reset (a No/Yes question, No selected) or Back, **Escape** goes back.

Pause menu (Phase 10): **Up/Down** choose Resume, Settings (Phase 13), Return to Title or Quit Game (wrapping),
**Enter** confirms, **Escape** resumes. In its questions, Up/Down (or Left/Right) choose No or Yes,
Enter confirms, Escape means No. Space and W/A/S/D do nothing there.

Title screen: **Up/Down** choose Continue, New Game, Settings (Phase 13) or Quit Game (going round;
Continue only when a save loads), **Enter** confirms. Quit Game closes the game at once (Phase 11). In the New Game
confirmation, Up/Down (or Left/Right) choose No or Yes, Enter confirms, and **Escape** means No.

Whatever slot holds the Slingshot fires it; whatever slot holds the Baseball Bat swings it;
whatever slot holds the Blast Bomb throws one (Phase 12).
Holding a slot key repeats its action as fast as the action's cooldown allows: Fists every
0.4 s, the Slingshot every 0.6 s, the Bat every 0.75 s, a potion every 1 s while it can heal, a
Blast Bomb every 1 s while any are left. Pickups need no key. No input actions were added in Phases 3–12
(the pause menu used the existing `pause_back`, `ui_confirm_game` and `move_up`/`move_down`); Phase 13
added the four fixed `menu_*` actions and moved every menu onto them. Donut has no keys (her Scratch
is automatic), and the slot keys never move or command her.

## Scene structure
```
project.godot                                   Settings, InputMap (menu_* actions: Phase 13), physics layer names, GameState + SaveManager + SettingsManager (Phase 13) autoloads; own user-data folder "DC CARL" and ANGLE on Windows (Phase 11)
assets/tiles/placeholder_world_tiles.png        Original 4-tile placeholder atlas
assets/items/slingshot.png                      Original 32×32 placeholder Slingshot icon (Phase 6)
assets/items/baseball_bat.png                   Original 32×32 placeholder Baseball Bat icon (Phase 9)
assets/items/blast_bomb.png                     Original 32×32 placeholder Blast Bomb icon (Phase 12)
resources/tile_sets/placeholder_world_tiles.tres  Shared TileSet (wall tiles collide)
resources/actions/fists.tres                    ActionDefinition: Fists (innate)
resources/actions/small_health_potion.tres      ActionDefinition: Small Health Potion (consumable)
resources/actions/slingshot.tres                ActionDefinition: Slingshot (reusable, with icon; Phase 6)
resources/actions/baseball_bat.tres             ActionDefinition: Baseball Bat (reusable, with icon; Phase 9)
resources/actions/blast_bomb.tres               ActionDefinition: Blast Bomb (consumable, with icon; Phase 12)
scenes/actions/fists.tscn                       Fists' performer: a MeleeAttack
scenes/actions/small_health_potion.tscn         The potion's performer: a HealAction (30 HP)
scenes/actions/slingshot.tscn                   The Slingshot's performer: a ProjectileLauncher (Phase 6)
scenes/actions/baseball_bat.tscn                The Bat's performer: a MeleeAttack with walls blocking and knockback (Phase 9)
scenes/actions/blast_bomb.tscn                  The Blast Bomb's performer: a ProjectileLauncher, 1.0 s (Phase 12)
scenes/projectiles/slingshot_stone.tscn         The Slingshot's Projectile (Phase 6)
scenes/projectiles/spit_glob.tscn               The Spitting Blob's Projectile (Phase 7)
scenes/projectiles/blast_bomb.tscn              The thrown Blast Bomb: a Projectile (no impact damage) + DetonateOnStop (Phase 12)
scenes/effects/blast_explosion.tscn             The Blast Bomb's explosion: an AreaDamage, 20 damage, 72 px (Phase 12)
scenes/ui/title_screen.tscn                     Main scene: Continue / New Game / Settings / Quit Game menu (Quit Game: Phase 11; Settings: Phase 13), overwrite confirmation, a SettingsMenu instance
scenes/ui/settings_menu.tscn                    The Settings screen: Controls (nine rows), Reset to Defaults (with its question), Back (Phase 13)
scenes/ui/hud.tscn                              Carl's and Donut's HP, slot bar, menu hint, GAME OVER panel (CanvasLayer)
scenes/ui/action_menu.tscn                      The action/inventory menu (CanvasLayer 10)
scenes/ui/pause_menu.tscn                       The pause menu and its two questions (CanvasLayer 11; Phase 10), a SettingsMenu instance (Phase 13)
scenes/actors/carl.tscn                         Carl (group "party"): Health, Hurtbox, Camera2D (performers added at run time)
scenes/actors/donut.tscn                        Donut (group "party"): Look (her shapes), DownedLabel, Health, Hurtbox, Scratch (MeleeAttack), NavigationAgent2D
scenes/enemies/gelatinous_blob.tscn             Blob: Health, Hurtbox, ContactAttack (MeleeAttack), KnockbackReceiver (Phase 9), NavigationAgent2D (EnemyNavigation)
scenes/enemies/spitting_blob.tscn               Spitting Blob (Phase 7): Health, Hurtbox, SpitLauncher (ProjectileLauncher), KnockbackReceiver (Phase 9), NavigationAgent2D
scenes/props/stairs.tscn                        Reusable stairs down
scenes/props/item_pickup.tscn                   Reusable world pickup (item + quantity; icon or default gem)
scenes/levels/surface.tscn, floor_01.tscn … floor_07.tscn   The eight levels (floor_04: Phase 7; floor_05: Phase 8; floor_06: Phase 9; floor_07: Phase 12)
scripts/autoload/game_state.gd                  GameState: the current run's state
scripts/autoload/save_manager.gd                SaveManager: the one save file (encode, validate, migrate, safe write, load, delete)
scripts/autoload/settings_manager.gd            SettingsManager (Phase 13): the control bindings (defaults, validation, InputMap, settings.json, reset)
scripts/settings/control_bindings.gd            class ControlBindings (Phase 13): the nine controls, their names and defaults, the key policy, key names from the InputMap
scripts/state/floor_entry.gd                    class FloorEntry: a floor checkpoint (Carl's and Donut's HP, inventory snapshot, slot layout)
scripts/actions/action_registry.gd              class ActionRegistry: action id -> ActionDefinition (for loading saves)
scripts/levels/floor_registry.gd                class FloorRegistry: floor id -> scene and name (the only floors a save can open)
scripts/actions/action_definition.gd            class ActionDefinition (Resource): one slot-able action or item
scripts/actions/action_performer.gd             class ActionPerformer (Node2D): base for what carries an action out
scripts/actions/action_slots.gd                 class ActionSlots: which action each logical slot (W, A, S, D) holds
scripts/actions/inventory.gd                    class Inventory: innate actions, owned reusable items, consumable quantities
scripts/actions/heal_action.gd                  class HealAction (an ActionPerformer): heals the user
scripts/combat/health.gd                        class Health: hit points, take_damage(), heal(), set_health(), set_down() and revive() (Phase 8)
scripts/combat/hurtbox.gd                       class Hurtbox: where an actor can be hit; passes a hit's Knockback on (Phase 9)
scripts/combat/melee_attack.gd                  class MeleeAttack (an ActionPerformer): cooldown-limited hit circle (max_targets: Phase 8; blocking_layers and knockback: Phase 9)
scripts/combat/knockback.gd                     class Knockback: the push that comes with a hit: direction, distance, duration (Phase 9)
scripts/combat/knockback_receiver.gd            class KnockbackReceiver: moves its body through a Knockback with move_and_slide() (Phase 9)
scripts/combat/projectile_launcher.gd           class ProjectileLauncher (an ActionPerformer): fires a Projectile (Phase 6)
scripts/combat/projectile.gd                    class Projectile: flies, stops at walls, hits one target (Phase 6; source rule Phase 7; damage 0 = no impact damage, Phase 12)
scripts/combat/area_damage.gd                   class AreaDamage: once, damages every target in a circle that no wall shields (Phase 12)
scripts/combat/detonate_on_stop.gd              class DetonateOnStop: makes its Projectile explode (an AreaDamage) where it stops (Phase 12)
scripts/enemies/loot_drop.gd                    class LootDrop: a fixed item + quantity an enemy drops as a pickup when it dies (Phase 12)
scripts/enemies/enemy.gd                        class Enemy: what every enemy shares (target choice, navigation, sight, hit flash, death) (Phase 7; party targets Phase 8; update_knockback() Phase 9)
scripts/enemies/enemy_navigation.gd             class EnemyNavigation (a NavigationAgent2D): which way to move to reach a goal (Phase 7)
scripts/enemies/gelatinous_blob.gd              The Gelatinous Blob (an Enemy): chase and touch
scripts/enemies/spitting_blob.gd                The Spitting Blob (an Enemy): keep distance, spit when in sight (Phase 7)
scripts/actors/donut.gd                         Donut: follow, Scratch, downed and recovery (Phase 8)
scripts/levels/level.gd                         class Level: run-state wiring (Carl and Donut), GAME OVER, retry; adds the pause menu, Return to Title, Quit Game (Phase 10)
scripts/ui/pause_menu.gd                        The pause menu: Resume / Settings / Return to Title / Quit Game, the questions (Phase 10; Settings: Phase 13)
scripts/ui/settings_menu.gd                     The Settings screen: key capture, refusals, Reset to Defaults (Phase 13)
scripts/ui/key_hint_label.gd                    A Label that names the current keys (template with {action} placeholders; Phase 13): the Surface's and Floor 1's key signs
scripts/levels/level_navigation.gd              Bakes a level's navigation mesh on load
scripts/props/item_pickup.gd                    class ItemPickup (Phase 12 name): walk-over pickup, gives its item to Carl once; placed or dropped
scripts/<actors|enemies|props|ui>/*.gd          One script per scene that needs one
tests/                                          Test scripts (not part of the game), see Tests
tests/fixtures/                                 Real save files from earlier phases: two save_version 1 (Phase 5), two save_version 2 (Phase 6), one save_version 2 (Phase 7, Floor 4), one save_version 3 (Phase 8, Floor 5) and one save_version 3 (Phase 11, Floor 6; Phase 12)
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
│   ├── enemies          e.g. GelatinousBlob, SpittingBlob (they find Carl and Donut themselves);
│   │   └── (LootDrop)   optional child of a placed enemy: what it drops (Phase 12)
│   └── (run-time nodes) Stones, globs and bombs while they fly, explosions while they show,
│                        and dropped pickups (Phase 12)
├── HUD                  hud.tscn instance
├── ActionMenu           action_menu.tscn instance
└── (PauseMenu)          pause_menu.tscn, added by Level._ready() (Phase 10; not in the scene file)
```
**To add a floor:** duplicate `floor_07.tscn` (or another floor), then:
1. Repaint Terrain and resize the NavigationPolygon outline.
2. Place Carl (the entry point), Donut (with `follow_target` = Carl) and the enemies, and set the
   root's `carl` and `donut` (enemies need no wiring: they hunt the `party` group).
3. Add pickups and stairs down, if any.
4. Point the previous floor's stairs down at the new file. Never add stairs back up.
5. Add one line to `FloorRegistry`, so the floor can be saved and continued. (Floors 4, 5, 6 and
   7 needed nothing else: no level or title code, and no save version change.)

**To add an enemy:** make a scene whose root script `extends Enemy` (scripts/enemies/enemy.gd),
with the children Enemy expects (Health, Hurtbox on `enemy_hurtbox`, CollisionShape2D on
`enemy`, NavigationAgent2D with `enemy_navigation.gd`, a unique HealthBarFill, and (Phase 9) a
`KnockbackReceiver` node that its Hurtbox's `knockback_receiver` points at), plus its attack
nodes (a MeleeAttack, a ProjectileLauncher with its own projectile scene, …). Its
`_physics_process()` starts with `if update_knockback(): return` (Phase 9), then combines
`update_activity()` (which also chooses `target`, Carl or Donut), `navigate_toward()`,
`stop_moving()` and `has_line_of_sight_to()`. Its attacks target `player_hurtbox`. Place it in a
level's Actors; no wiring and no level code changes. (Leave the KnockbackReceiver out for an
enemy that must never be pushed.)

**To add an item:**
1. Write an ActionDefinition `.tres`: id, names, `consumable` (true = counted and used up,
   false = reusable: found once, never used up), `performer_scene`, optional `icon`.
2. Give it a performer scene: an existing ActionPerformer (MeleeAttack, HealAction,
   ProjectileLauncher) with new numbers, or a new ActionPerformer subclass for a new kind of
   behaviour.
3. Add one line to `ActionRegistry`, so saves can name it.
4. Place `item_pickup.tscn` instances with `item` and `quantity` set.

Carl's script does not change (it did not change in Phases 6–12). A new item needs no save
version change either: `owned_items` already stores any reusable item's id (Phase 9 added the
Bat this way) and `inventory` any consumable's quantity (Phase 12 added the Blast Bomb this way).

**To make an enemy drop something** (Phase 12; deterministic: always that item and quantity):
1. In the level scene, add a `Node` child named `LootDrop` to the placed enemy (right-click the
   enemy instance > Add Child Node > Node), and give it the script `scripts/enemies/loot_drop.gd`.
2. Set its `item` (any ActionDefinition `.tres`: a potion, a Blast Bomb, even the Slingshot) and
   `quantity` (for example 2).
That is all: when that enemy dies, an ordinary pickup for that item appears where it died, Carl
collects it by walking over it, and the floor's checkpoint rules apply (a retry takes it back and
brings the enemy back). No enemy scene, Carl, HUD, menu or save change. (Chances, rarities or loot
tables would be a later extension of `LootDrop`, not built yet.)

**To add another area-damage item** (for example a bigger bomb or a firework), following the Blast
Bomb:
1. Copy `scenes/effects/blast_explosion.tscn` and set the `AreaDamage` numbers: `damage`, `radius`,
   `target_layers` (keep `enemy_hurtbox` = 32 for a player item), `blocking_layers` (1 = walls
   shield; 0 = nothing shields), the flash colours and `flash_duration`.
2. Copy `scenes/projectiles/blast_bomb.tscn` and point its `DetonateOnStop.explosion_scene` at the
   new explosion; set the `Projectile` numbers (`speed`, `max_distance`; keep `damage = 0` so only
   the blast hurts) and its look.
3. Copy `scenes/actions/blast_bomb.tscn` (a `ProjectileLauncher`) and point its `projectile_scene` at
   the new projectile; set its `cooldown`.
4. Copy `resources/actions/blast_bomb.tres` with a new `id`, names, description and icon
   (`consumable = true` for a counted item) and point `performer_scene` at the new launcher. Then
   steps 3–4 of "To add an item" (or give an enemy a `LootDrop` for it).
A spell or enemy area attack reuses `AreaDamage` the same way: create the explosion scene where it
happens, set `source` (the attacker, which it never hurts), add it to the level and call
`detonate()`; an enemy's blast would target `player_hurtbox` (16). An explosion that should push
would pass a `Knockback` to `take_hit()` in its own copy of `AreaDamage.detonate()` (none does now).

**To add a weapon with its own knockback** (for example a heavy hammer that pushes 150 px, or a
pipe that pushes 40 px), following the Bat:
1. Copy `scenes/actions/baseball_bat.tscn` and change its numbers: `damage`, `reach`,
   `hit_radius`, `cooldown`, and `knockback_distance` (px; 0 = no push) / `knockback_duration`
   (s). Keep `target_layers = 32` (enemies only) and `blocking_layers = 1` (walls block it).
2. Copy `resources/actions/baseball_bat.tres` with a new `id`, names, description and icon, and
   point `performer_scene` at the new scene. Then steps 3–4 of "To add an item".
That is all: `MeleeAttack.attack()` builds the `Knockback`, `Hurtbox.take_hit()` hands it to the
enemy's `KnockbackReceiver`, and every enemy already reacts through `Enemy.update_knockback()`.
Carl, the HUD, the menu, the levels and the save format do not change. A ranged weapon with
knockback would pass a `Knockback` from `Projectile._physics_process()` to `take_hit()` the same
way (not done in Phase 9: stones must not push).

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
  | reusable item | Slingshot, Baseball Bat | `consumable = false`, not innate | none | never | `owned_items: ["slingshot", "baseball_bat"]` |
  | consumable | Small Health Potion, Blast Bomb (Phase 12) | `consumable = true` | 0–999 | one per use | `inventory: {"small_health_potion": 1, "blast_bomb": 2}` |

  No script checks item ids to tell them apart.
- **`ActionPerformer`** (Node2D base): the root of a `performer_scene`. It has
  `perform(direction) -> bool`, which returns true only if the action really happened, and
  a `user` (Carl), which Carl sets before adding it. Each performer keeps its own state,
  such as its cooldown.
  - **`MeleeAttack`**: Fists and (Phase 9) the Baseball Bat. The Blob's ContactAttack and Donut's
    Scratch call `attack()` directly. `max_targets` (Phase 8) limits how many Hurtboxes one use
    damages, nearest to the hit circle's centre first: 0 (Fists, the Bat) = all in the circle, 1
    for the Blob's touch and Scratch. Two optional extras (Phase 9), both off unless a scene sets
    them, so Fists, the touch and Scratch behave exactly as before:
    - `blocking_layers`: a Hurtbox is skipped if a ray from the attacker's centre to the
      Hurtbox's centre hits one of these layers (the Bat: `world`, so no hits through walls);
    - `knockback_distance` / `knockback_duration`: `get_knockback(direction)` builds one
      `Knockback` per use (null when the distance is 0 or the attack has no direction), passed to
      every `take_hit()` of that use.

    | MeleeAttack | Damage | Circle (reach, radius) | Cooldown | Targets | Walls block | Knockback |
    |-------------|--------|------------------------|----------|---------|-------------|-----------|
    | Fists | 10 | 24 px, 18 px (6–42 px ahead) | 0.4 s | all, `enemy_hurtbox` | no | none |
    | Baseball Bat | 20 | 36 px, 28 px (8–64 px ahead) | 0.75 s | all, `enemy_hurtbox` | yes | 80 px / 0.3 s |
    | Blob's touch | 10 | 0, 19 px | 0.8 s | 1, `player_hurtbox` | no | none |
    | Donut's Scratch | 10 | 0, 28 px | 1.0 s | 1, `enemy_hurtbox` | no | none |
  - **`HealAction`**: the potion. It returns false (so no potion is spent) when nothing was
    healed or it is cooling down.
  - **`ProjectileLauncher`** (Phase 6): the Slingshot and (Phase 12) the Blast Bomb. `perform()` creates its
    `projectile_scene`, adds it to the user's parent (the level's Actors node, so the stone
    flies on independently of Carl), calls `launch(user position, direction)`, starts its
    cooldown and emits `fired(projectile)`. It returns false while cooling down.
- **Carl's generic dispatch** (`_use_slot`), unchanged:
  1. slot → action;
  2. a consumable with 0 left does nothing;
  3. `performer.perform(facing)`;
  4. if that returned true and the action is consumable, `inventory.remove(action, 1)`.

  So: `W → Slingshot definition → ProjectileLauncher.perform() → Projectile`, and
  `S → Baseball Bat definition → MeleeAttack.perform() → Hurtbox.take_hit(20, Knockback) →
  Health + KnockbackReceiver`, and (Phase 12) `A → Blast Bomb definition →
  ProjectileLauncher.perform() → Projectile (the bomb) → stopped → DetonateOnStop → AreaDamage.detonate()
  → Hurtbox.take_hit(20) for each enemy in the blast → Health`, then `inventory.remove(bomb, 1)`
  because the launcher returned true and the bomb is consumable. Carl knows nothing about
  projectiles, knockback or explosions.

### Area damage (Phase 12, `scripts/combat/area_damage.gd`, `detonate_on_stop.gd`)
The first attack that hurts several targets at once on purpose from one point, kept separate from
knockback and from the projectile that carries it.
- **`AreaDamage`** (Node2D, the root of an explosion scene): exports `damage`, `radius`,
  `target_layers` (the side it hurts), `blocking_layers` (what shields: `world`), the flash colours
  and `flash_duration`; `source` is set by whoever makes it. `detonate()`:
  1. only the first call does anything (`has_detonated()`), so one explosion never hits twice;
  2. `find_targets()`: a circle shape query (`radius`) on `target_layers`, areas only. Each
     `Hurtbox` found is kept once if it `can_be_hit()` (a dying enemy cannot), does not belong to
     `source` (`source.is_ancestor_of()`, the projectiles' rule), and is not shielded;
  3. `is_shielded()`: a ray from the explosion's centre to the Hurtbox's centre on
     `blocking_layers`; any hit means a wall is in between. The same test as the Bat's
     `blocking_layers` and the Spitting Blob's line of sight, on the same `world` layer;
  4. `take_hit(damage)` on each target: no Knockback, so nothing is pushed;
  5. emits `detonated(targets)`, then draws a fading orange disc and ring of `radius` and a
     shrinking bright core for `flash_duration` (0.35 s = 21 physics ticks, so it freezes while the
     game is paused) and frees itself.
- **`DetonateOnStop`** (Node, a child of a `Projectile`): connects to the projectile's `stopped`
  signal. `Projectile` emits it exactly once (it stops flying and frees itself right after), for
  an enemy hit (the collider is a `Hurtbox`), a wall hit (a body) or the range used up (null). It
  instantiates `explosion_scene`, gives it the projectile's `source`, adds it to the projectile's
  parent (the level's Actors, so it outlives the bomb), places it where the bomb stopped (2 px back
  along the flight direction after a wall hit, `WALL_CLEARANCE`, so the centre is in front of the
  wall's face and the wall shields what is behind it), calls `detonate()` and emits
  `exploded(explosion, targets)`.
- **The Blast Bomb** is only data around these: the bomb `Projectile` has `damage = 0`
  (`Projectile` now skips `take_hit()` when its damage is 0, so the enemy it lands on takes exactly
  the blast's 20, once), `target_layers` enemy_hurtbox (so an enemy stops it) and `blocking_layers`
  world; the explosion is `AreaDamage` with 20 / 72 px / enemy_hurtbox / world.

  | Explosion | Made by | Damage | Radius | Targets | Walls shield | Knockback |
  |-----------|---------|--------|--------|---------|--------------|-----------|
  | `blast_explosion.tscn` | the Blast Bomb (DetonateOnStop) | 20 | 72 px (a blob's centre up to 86 px) | every `enemy_hurtbox` in it, once | yes | none |

- **Pause, GAME OVER, retry:** a flying bomb is an ordinary pausable `Projectile`; the flash counts
  physics ticks. A retry or leaving reloads the level, so no bomb or explosion survives; neither is
  ever saved.

### Enemy loot drops (Phase 12, `scripts/enemies/loot_drop.gd`)
- **`LootDrop`** (Node): a child of an enemy placed in a level (not of the enemy scene, so each
  placed enemy decides), with `item` (ActionDefinition) and `quantity`. In `_ready()` it connects to
  its parent's `Health.died` (any enemy has one).
- On death (once: `has_dropped()`), it records the enemy's position and, at the end of that frame
  (`call_deferred`: deaths happen inside physics steps, and the pickup is an Area2D), instantiates
  `item_pickup.tscn`, sets `item` and `quantity`, names it after the item (`BlastBombDrop`), adds it
  to the enemy's parent (the level's Actors) and puts it where the enemy died. It then emits
  `dropped(pickup)`. If the level was left in that same frame it does nothing.
- It never touches the inventory or GameState: **only the pickup gives items**, by its usual rules
  (Area2D mask `player`, `collect_item()` on Carl only, a `_collected` flag, then freed). So Donut,
  enemies and projectiles cannot take it, it is taken once, and the quantity is exact.
- **Checkpoints:** nothing records drops. A retry or Continue reloads the level (the enemy is back,
  with its LootDrop not yet used, and no dropped pickup exists) and restores the floor-entry
  inventory, so drops follow the same rules as placed pickups and can never be duplicated.

### Knockback (Phase 9, `scripts/combat/knockback.gd`, `knockback_receiver.gd`)
The one combat reaction so far. It is deliberately small: damage plus an optional push, no
status effects, stagger meters or resistances.
- **`Knockback`** (RefCounted): `direction` (unit vector), `distance` (px), `duration` (s). This
  is the "damage event" extra: `Hurtbox.take_hit(damage, knockback = null)`. Every older call
  (`take_hit(damage)`: stones, globs, the Blob's touch, Scratch, tests) is unchanged.
- **`Hurtbox`** gains an optional `knockback_receiver` export. `take_hit()` first applies the
  damage through `Health` as always, then, only if the hit really did damage and the actor is
  still alive, calls `knockback_receiver.apply(knockback)`. So **death comes first**: a killing
  hit never pushes. A Hurtbox without a receiver (Carl's, Donut's) ignores knockback.
- **`KnockbackReceiver`** (Node, a child of a CharacterBody2D): `apply()` stores the push and its
  length in physics ticks (`roundi(duration × 60)` = 18 for the Bat); `step()` moves the body one
  tick with `body.velocity` and `move_and_slide()`, so walls and other bodies stop it exactly as
  they stop ordinary movement (it never sets a position directly, never tunnels: at most 8.4 px
  per tick against 32 px tiles). Each tick moves `distance × (n − i) / (n(n+1)/2)` for tick
  `i` of `n`, so the push starts fast and eases out, and adds up to exactly `distance` when
  nothing is in the way. On the last tick it zeroes the velocity. `stop()` ends a push at once.
  `is_active()` says whether one is going on.
- **`Enemy.update_knockback()`**: each enemy's `_physics_process()` starts with
  `if update_knockback(): return`. While a push is active the enemy moves one tick of it and
  does nothing else: no `update_activity()`, no `navigate_toward()`, no attack. So navigation
  never fights the push, the Spitting Blob neither walks nor spits, and the Blob's touch is
  off. The push lasts a fixed number of ticks, so it always ends; the next tick the enemy runs
  its normal AI, and `navigate_toward()` sets a new `target_position` (a fresh path from where it
  landed). NavigationAgent2D state is never touched by the push.
- **Cooldowns keep counting during a push** (they live in the attack nodes' own
  `_physics_process()`), so nothing is saved up or reset: the Spitting Blob's next glob comes
  exactly 1.5 s after its previous one (or later, if its target is out of sight), never in a
  burst.
- **Death:** `Enemy._on_died()` also calls `knockback_receiver.stop()` and, as before, turns off
  its `_physics_process()`: a blob killed mid-push (by Donut's Scratch, say) stops where it is
  and never moves or attacks again.
- **Pause and GAME OVER:** a push only advances inside the enemy's `_physics_process()`, which
  the tree pause stops, so it freezes where it is and finishes its remaining ticks after the
  menu closes. After GAME OVER the retry reloads the level, so no push survives. Knockback is
  never saved (it is not run state).
- **Who is pushed:** only actors with a `KnockbackReceiver`, which today means the two enemy
  scenes. **Who pushes:** only attacks that build a `Knockback`, which today means the Bat's
  `MeleeAttack` (its `knockback_distance` is 80; every other MeleeAttack has 0, and projectiles
  pass none).

### Projectiles (`Projectile`, `scripts/combat/projectile.gd`, Phase 6, shared since Phase 7)
- A plain Node2D (not a physics body) with `damage`, `speed`, `max_distance`,
  `target_layers` (whom it may hurt) and `blocking_layers` (what stops it), the `direction`
  set by `launch()`, and (Phase 7) its `source`, whoever fired it. Emits `stopped(collider)`
  once (null when it ran out of range).
- **Three kinds, one class** (Phase 7; the bomb Phase 12). Each is just a scene with its own numbers and look:

  | Projectile | Fired by | `target_layers` | Damage | Speed | Range | Look |
  |------------|----------|-----------------|--------|-------|-------|------|
  | `slingshot_stone.tscn` | Carl's Slingshot | `enemy_hurtbox` | 10 | 480 px/s | 320 px (40 ticks) | pale round stone, short trail |
  | `spit_glob.tscn` | a Spitting Blob's SpitLauncher | `player_hurtbox` | 10 | 240 px/s | 384 px (96 ticks) | violet teardrop, longer trail |
  | `blast_bomb.tscn` (Phase 12) | Carl's Blast Bomb | `enemy_hurtbox` (stops it; the blast does the damage) | 0 | 220 px/s | 240 px (66 ticks) | charcoal bomb, grey trail, orange fuse spark |

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
- **Knockback (Phase 9):** both enemy scenes have a `KnockbackReceiver`, and both scripts start
  their tick with `if update_knockback(): return` (see Architecture > Knockback).
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

### Action menu — unchanged in Phase 6 (keys: Phase 13)
- The Inventory key (Space by default) opens it only while the game is not paused (never over
  GAME OVER). It pauses the scene tree; the Inventory key or Escape closes it. Paused stones stay
  where they are and fly on after.
- It lists `Inventory.get_actions()` with labels and each action's slot. Up/Down (`menu_up`/
  `menu_down`, fixed) select; the slot keys (W/A/S/D by default: the `action_*` actions) assign.
  It refreshes on inventory and slot changes, and on binding changes (`control_hints` group).
  Escape, Up and Down are checked first, so they keep their menu meaning even if a control shares
  their key.
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
- ARCHITECTURE_RULES names two autoloads, `GameState` and `SaveManager`. Phase 13 added a third,
  `SettingsManager`, which the Phase 13 prompt asked for by name (application settings must be
  applied before the title exists). There are no others (`test_project_setup.gd` checks the list).

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
- **Location:** `user://savegame.json` (`DEFAULT_SAVE_PATH`), in the project's own user-data
  folder (Phase 11), never in the project folder. On Windows that is
  `%APPDATA%\DC CARL\savegame.json` (`C:/Users/Owner/AppData/Roaming/DC CARL/savegame.json` on this
  machine). Before Phase 11 it was `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon
  Prototype\savegame.json`, a folder shared with `../codex`; see Architecture > User-data folder
  and renderer.
  `save_path` can be changed; tests always change it (see Test save isolation below).
- **Format version 3** (`SAVE_VERSION`, Phase 8; unchanged in Phases 9–12), stable ids only:
  ```
  {"save_version": 3, "floor_id": "floor_07", "carl": {"health": 80, "max_health": 100},
   "donut": {"health": 40, "max_health": 60},
   "inventory": {"blast_bomb": 1, "small_health_potion": 1},
   "owned_items": ["slingshot", "baseball_bat"],
   "action_slots": {"action_w": "slingshot", "action_a": "blast_bomb", "action_s": "baseball_bat", "action_d": "fists"}}
  ```
  - `donut`: Donut's HP on entering the floor (Phase 8). 0 = she entered downed;
  - `inventory`: the quantity of each consumable (same meaning as in version 1);
  - `owned_items`: the ids of the reusable items Carl owns (Phase 6);
  - innate actions are never saved.
- **Why Phase 12 is still version 3:** carrying Blast Bombs is the value `"blast_bomb": 1` in
  `inventory`, which has held any consumable's quantity by stable id since Phase 5 (validated through
  `ActionRegistry`: known, not innate, not reusable, a whole number 0–999), and Floor 7 is the value
  `"floor_07"` of `floor_id`. Adding the two registry lines was all the save needed. A Phase 11
  save (tested with a real Phase 11 Floor 6 file) loads unchanged, has no bombs, and is written back
  byte-identical in content; version 1 and 2 saves migrate as before with no bombs. Bombs in the
  wrong place are rejected like any item (`owned_items: ["blast_bomb"]`: a consumable is not a
  reusable item; negative, fractional, string or > 999 quantities; look-alike ids such as
  `Blast_Bomb` are unknown), and a bomb slot with no bombs is emptied.
- **Why Phase 9 is still version 3:** a version changes when the *shape or meaning* of the saved
  data changes (version 2 added `owned_items`, version 3 added `donut`). Since Phase 6
  `owned_items` holds any reusable item's id, validated through `ActionRegistry` (known, not
  innate, not consumable, not listed twice), so owning the Bat is just the value
  `"baseball_bat"` in that list, and Floor 6 is just the value `"floor_06"` of `floor_id`. Adding
  the two registry lines was all the save needed. Phase 8 (version 3) saves load unchanged and
  own no Bat (tested with a real Phase 8 file); version 1 and 2 saves migrate as before and own
  no Bat (a version 1 file's `owned_items` is still ignored).
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
  pickups; enemy drops and dropped pickups (Phase 12); projectiles, bombs in flight and explosions;
  cooldowns (Scratch, the Bat and the bomb included), knockback in progress (Phase 9),
  Donut's recovery countdown, animation and navigation; the live menu state; anything after floor
  entry.
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
- **Registries:** `FloorRegistry` (`surface`, `floor_01` … `floor_07`) and
  `ActionRegistry` (`fists`, `small_health_potion`, `slingshot`, `baseball_bat`, `blast_bomb`) are the
  whitelists that turn saved ids back into scenes and resources.
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

### Pause menu and the game session (Phase 10)
- **Where it lives:** `Level._ready()` instantiates `scenes/ui/pause_menu.tscn` as the level's last
  child and connects its two signals. The floor scenes do not contain it, so every level, including
  future ones, has exactly one, and none has pause code of its own. It never touches GameState or
  the save; it only emits `return_to_title_requested` / `quit_requested`, like the HUD's
  `retry_requested`.
- **Pausing:** `open()` sets `get_tree().paused = true`, `resume()` sets it back. That is the same
  pause the action menu and GAME OVER use. Everything in play is `process_mode` Inherit and counts
  physics ticks (MeleeAttack/ProjectileLauncher/HealAction cooldowns, KnockbackReceiver, Donut's
  countdown, projectile flight, Stairs arming), so all of it stops, and it all picks up exactly
  where it left off. The paused tree also turns the physics server off, so stairs and pickups
  (Area2D) report nothing. Only the three CanvasLayers (HUD, ActionMenu, PauseMenu) run while
  paused (`process_mode` Always).
- **Which menu gets a key (modal precedence).** The rule has two parts, and each menu follows both:
  1. a menu opens only while the tree is **not** paused, so the action menu, the pause menu and GAME
     OVER can never stack;
  2. an open menu takes **every** key event (`set_input_as_handled()`), and Escape/Enter are read
     without key repeat.
  So one Escape that closes the action menu cannot also open the pause menu. The pause menu (the
  level's last child) sees the event first, but the tree is still paused then, so it ignores it;
  the action menu then closes. Space over the pause menu is taken by the pause menu, and the action
  menu would refuse anyway (paused). At GAME OVER both refuse (paused) and only the HUD's Enter
  works. Carl reads key *state*, not events, but he is paused, and keys still held on resuming are
  ignored until released (`NOTIFICATION_UNPAUSED` in `carl.gd`).
- **Return to Title:** `Level._on_return_to_title_requested()` unpauses and calls
  `change_scene_to_file(application/run/main_scene)`. In Godot 4.7 that takes the level out of the
  tree at once and frees it at the end of the frame, so no tick of it runs unpaused (checked: the
  old scene is out of the tree before the next physics step). Its nodes (Carl, Donut, enemies,
  projectiles, pushes, tweens, menus) all go with it, and their connections to GameState's
  Inventory and ActionSlots are removed automatically when they are freed (the tests count the
  connections: the same after every cycle).
- **No stale run:** `title_screen.gd` calls `GameState.end_run()` (a new run's values, no floor
  entry) in `_ready()`, then reads the save as it always did. Continue already re-read the save
  and called `GameState.continue_from()`; now nothing from the floor that was left is in memory
  at all while the title is up.
- **Quit Game:** `get_tree().quit()`, with the game still paused, so nothing runs before the
  process ends. **Window close / Alt+F4:** left to Godot's default (`auto_accept_quit`): the game
  quits without asking. Nothing saves in either path; no script has `_exit_tree()`,
  `NOTIFICATION_WM_CLOSE_REQUEST` or file code that runs at shutdown.
- **Lifecycle fix: stairs in a frozen game.** Stairs change level with a deferred call, at the end
  of the physics step in which Carl touched them. If Carl was killed in that same step (a blob's
  touch or a glob), GAME OVER paused the tree first, and in Phase 9 the deferred call still ran:
  the next floor opened **still paused, with no GAME OVER screen** (no key did anything), and its
  `Level._ready()` saved a checkpoint with **Carl at 0 HP**, which `decode()` rejects, so the save
  could no longer be loaded. Reproduced on the Phase 9 code by emitting the stairs' `body_entered`
  and killing Carl in one tick. `Stairs._change_level()` now returns when the tree is paused; the
  retry reloads the floor, stairs included. `test_pause_menu.gd` checks it.

### Settings and control bindings (Phase 13)
**Slot contents are run state; key bindings are application settings.**

| Concern | Owner | Where it lives | Survives |
|---------|-------|----------------|----------|
| What each slot holds (`action_w` = Slingshot) | `GameState.action_slots` (run) / `SaveManager` (checkpoint) | memory; `savegame.json` `action_slots` | floors, retries, Continue |
| Which key triggers each control (`action_w` = Q) | `SettingsManager` | the InputMap; `settings.json` `keyboard` | everything: New Game, Continue, Return to Title, a deleted save, restarts |

- **`ControlBindings`** (`scripts/settings/control_bindings.gd`, a static class, no state):
  `ACTIONS` (the nine controls, in Settings order), `DISPLAY_NAMES` ("Action Slot W"),
  `DEFAULT_KEYS`, `RESERVED_KEYS` (Escape, Enter, keypad Enter, each with its message),
  `EXTRA_ALLOWED_KEYS`, `HINT_GROUP` (`control_hints`), and:
  - `get_key(action)` / `get_key_label(action)`: the key bound in the **InputMap** now (the first
    keyboard event of the action) and its name. The HUD, the action menu, the signs and the Settings
    screen use these, so they never depend on the autoload and always show what is really bound;
  - `get_key_name(key)` / `get_key_from_name(name)`: Godot's layout-independent key names
    (`OS.get_keycode_string()`: "Q", "1", "Space", "Up", "Tab", "Kp 1"), used on screen and in the
    file; a name must round-trip exactly ("q" is not a key name);
  - `get_event_key(event)`: the physical key of an event (as `project.godot` binds keys);
  - `get_key_problem(key)`: "" or why it cannot be bound (reserved, or not a printable key and not in
    `EXTRA_ALLOWED_KEYS`: modifiers alone, lock, function and media keys).
- **`SettingsManager`** (autoload, `scripts/autoload/settings_manager.gd`):
  - `_ready()` (autoloads are ready before the main scene is added): `load_settings()` from
    `user://settings.json`, which applies the file's bindings or the defaults. So the InputMap is
    final before the title appears, and every level simply reads actions;
  - `set_binding(action, key) -> String`: "" when `action` is now on `key`, else the refusal message
    (reserved/unusable key; "Q is already assigned to Action Slot W." when another control has it).
    Nothing is ever taken from another control or swapped. On success: apply, then `save_settings()`;
  - `reset_to_defaults()`: `DEFAULT_KEYS`, apply, save;
  - `_use_bindings()`: for each control whose key changed, erase its **keyboard** events (other kinds
    of event would be kept: none exist yet), add one `InputEventKey` with the physical key, and
    `Input.action_release()` it, so a held key never carries over as a press of the new binding; then
    emits `bindings_changed` and calls `refresh_control_hints()` on the `control_hints` group (the HUD,
    the action menu and the key signs join it);
  - `encode()` / `decode(data)`: the file format; `decode()` rejects the whole file unless it is
    exactly `{"settings_version": 1, "keyboard": {<the nine ids>: <a usable key name>}}` with nine
    different keys (any other field, version, type, id, missing id, reserved/unusable/unknown key or
    duplicate). Nothing is ever partly applied;
  - `load_failed` / `last_error`: set when a file existed but could not be used (the defaults then
    apply, and the title and the Settings screen show "Control settings could not be loaded. Defaults
    restored."). The bad file is not rewritten on load; the next change or Reset replaces it;
  - **safe write** (the save's method): JSON to `settings.json.tmp`, read back and compared, then
    renamed over `settings.json`; a failure logs an error, returns false (`last_save_failed`), keeps
    the old file, and the new binding still applies for this session (the Settings screen says it
    could not be saved). A finished `.tmp` left by an interrupted write is loaded if `settings.json`
    is missing;
  - **written only** when a binding really changes or Reset is confirmed; never on load, on a key press
    in play, by New Game, Continue or leaving.
- **Test isolation (the save's rule, for settings):** in a test or tool run (`-s`), SettingsManager
  starts with the defaults and **no file at all**, and refuses (with an error, touching nothing) any
  path outside `user://test_saves/`, including `user://settings.json` and
  `user://test_saves/../settings.json`. `game_test.gd` gives every test
  `user://test_saves/<test>_settings.json` (deleted at the start and end, defaults loaded). Only a
  test run started with `--settings-file=<file inside the test folder>` loads a file at startup,
  exactly as the game does (`tests/support/settings_child.gd`, for the restart tests); a production
  path there is refused like any other. The game itself never reads that argument.
- **Menus:** the title, pause menu, action menu and Settings screen read the fixed `menu_*`,
  `ui_confirm_game` and `pause_back` actions. Each menu takes every key event while open, so a key
  pressed in a menu never reaches the game. The Settings screen is a child of the title and of the
  pause menu (each checks `settings_menu.is_open()` first and leaves the keys to it).
- **Adding a rebindable control later:** add its InputMap action in `project.godot`, then one entry
  each in `ControlBindings.ACTIONS`, `DISPLAY_NAMES` and `DEFAULT_KEYS`. The Settings screen builds
  its rows from `ACTIONS`. A settings file without the new control is then rejected as a whole (the
  defaults apply), so give it a `settings_version` 2 migration in `decode()` if players' keys should
  survive. A gamepad binding would be another block beside `"keyboard"` and events of another type in
  `_use_bindings()`; Carl and the menus would not change.

### User-data folder and renderer (Phase 11)
- **User data:** `project.godot` sets `application/config/use_custom_user_dir=true` and
  `application/config/custom_user_dir_name="DC CARL"`. Godot then puts `user://` in the operating
  system's app-data folder + `DC CARL` (`OS.get_data_dir()` + `/DC CARL`): on Windows
  `%APPDATA%\DC CARL`, observed as `C:/Users/Owner/AppData/Roaming/DC CARL`. Everything the game
  writes goes there: `savegame.json` (and its `.tmp` while saving), Godot's `logs/`, and the
  tests' `test_saves/`. No script names an absolute path (`test_project_setup.gd` checks every
  game script).
- **No path migration:** the old folder `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon
  Prototype` is simply no longer used. A save in it is not imported (it may be the other project's
  format); the player can copy their own old `savegame.json` into the new folder by hand if they
  want it back (SaveManager checks it like any other file). The save *format* migrations (v1/v2
  to v3) are unchanged.
- **Test isolation is unchanged:** tests still use only `user://test_saves/` (now
  `%APPDATA%\DC CARL\test_saves`), and the Phase 8 guard still refuses `user://savegame.json` in
  any `-s` run. Having its own folder does not make the player's save available to tests.
- **Renderer:** `rendering/gl_compatibility/driver.windows="opengl3_angle"` is the only renderer
  line added. `rendering/renderer/rendering_method` stays `gl_compatibility`; `driver`,
  `driver.linuxbsd`, `driver.macos`, `driver.web`, `driver.android`, `driver.ios`,
  `fallback_to_angle` and `fallback_to_native` stay at Godot's defaults (`test_project_setup.gd`
  checks each). With `fallback_to_native` on (the default), a Windows machine without Direct3D 11
  support would still start, on native OpenGL. A real launch here reports
  `RenderingServer.get_current_rendering_driver_name()` = **`opengl3_angle`** ("ANGLE (Intel, Intel(R) UHD Graphics (0x000046A3) Direct3D11 …,
  D3D11-31.0.101.4032)", OpenGL ES 3.0 through ANGLE 2.1.1).
  For a diagnostic comparison, native OpenGL can still be forced for one run:
  `godot --path . --rendering-driver opengl3`.

### Earlier decisions still in force
- Compatibility renderer; 1280×720 base with `canvas_items` stretch and `expand` aspect;
  physical-keycode bindings; Godot's `ui_*` actions untouched.
- Version in Project Settings, now `0.13.0` (the game's version; the save format is still 3, the
  settings format 1).
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
| —     | (none)           | Baseball Bat swing (MeleeAttack, Phase 9)  | shape query: 6 `enemy_hurtbox`; ray: 1 `world` (blocks the hit) |
| —     | (none)           | Knockback (Phase 9)                        | the enemy body's own mask (1 `world`, 2 `player`, 4 `enemy`) via `move_and_slide()` |
| —     | (none)           | Thrown Blast Bombs (Node2D, Phase 12)      | ray query: 6 `enemy_hurtbox` (stops it) and 1 `world` (stops it) |
| —     | (none)           | Blast Bomb explosion (AreaDamage, Phase 12) | shape query: 6 `enemy_hurtbox`; ray: 1 `world` (shields the target) |
| —     | (none)           | Dropped pickups (ItemPickup, Phase 12)     | 2 `player`, like placed pickups: only Carl collects them |

Consequences:
- Carl and the blobs block each other.
- Donut's body collides only with walls, and she can neither trigger stairs nor collect
  pickups. Carl and the enemies pass through her body (her `companion` layer is not in their
  masks); her Hurtbox is what attacks find.
- Carl's Fists and stones and Donut's Scratch target layer 6 only; the Blob's touch and the
  globs target layer 5 only. So the player's side (Carl, Donut) never hurts itself, and enemy
  attacks never hurt enemies.
- Stones, globs and bombs are stopped by layer 1 only: they fly over bodies, pickups and stairs.
- The Blast Bomb's explosion targets layer 6 only, so it can never hurt Carl or Donut (layer 5);
  a wall (layer 1) between its centre and an enemy's shields that enemy.
  Enemies see through everything but walls, exactly where their globs can fly.
- Navigation baking reads only layer 1.

## Earlier behaviour changed in Phase 13
1. **Menus use their own fixed keys** (`menu_up`, `menu_down`, `menu_left`, `menu_right`, on the
   arrows) instead of the movement actions. With default keys nothing changes for the player.
2. **The title has four rows** (Continue, New Game, **Settings**, Quit Game) and **the pause menu
   four** (Resume, **Settings**, Return to Title, Quit Game). Tests that reach Return to Title or Quit
   Game by Down presses press Down once more (`test_pause_menu.gd`, `test_return_to_title.gd`,
   `test_title_quit.gd`, `test_floor_07_run.gd`, `test_windowed_resolutions.gd`,
   `tests/support/quit_game_child.gd`), and their row lists include Settings.
3. **`ActionSlots.KEY_LABELS` became `ActionSlots.SLOT_NAMES`** (the slots' logical names). Every key
   shown to the player comes from `ControlBindings.get_key_label()`; four tests use the new name for
   their labels.
4. **The action menu checks Escape and Up/Down before the Inventory and slot keys**, so the menu keys
   win when a control is bound to the same key (only possible after rebinding).
5. **The HUD's hint, the action menu's help line and the Surface's and Floor 1's key signs are
   built from the bindings** (identical texts with the default keys).
6. **A third autoload, SettingsManager.** `game_test.gd` also gives every test its own settings file.
7. `test_input_map.gd` also checks the `menu_*` actions and that the defaults equal
   `ControlBindings.DEFAULT_KEYS`; `test_project_setup.gd` checks version `0.13.0`, settings format 1,
   the settings path and the autoload list.
8. Version in Project Settings: `0.13.0`.

## Earlier behaviour changed in Phase 12
1. **Floor 6 has an exit** (stairs down to Floor 7) and a loot-carrying blob; its note
   `Signs/PrototypeNote` became `Signs/StairsHint`, and it gained `Signs/LootSign` and
   `Signs/StairsSign`. `test_floor_04_run.gd`, `test_floor_05_run.gd` and `test_floor_06_run.gd` now
   expect Floor 6's only exit to lead to Floor 7 and Floor 7 to have none;
   `test_windowed_resolutions.gd` checks `Signs/StairsHint`.
2. **`floor_07` and `blast_bomb` exist.** `test_save_manager.gd` now lists eight floors and five
   actions, and rejects `floor_08` (instead of `floor_07`) as unknown.
3. **`Projectile` with `damage` 0 no longer calls `take_hit()`** on the Hurtbox it stops at (it
   used to call `take_hit(0)`, which did nothing). Stones and globs deal 10 as before.
4. **`item_pickup.gd` has a class name, `ItemPickup`**, so a `LootDrop` can create one; nothing
   else about pickups changed.
5. **The windowed test visits Floor 7 last**, so its pause-menu and title checks now expect the
   Floor 7 checkpoint ("Saved at the start of Floor 7"). `test_pause_menu.gd` checks every
   registered floor, now including Floor 7.
6. Version in Project Settings: `0.12.0`.

## Earlier behaviour changed in Phase 11
1. **Where the save lives:** `%APPDATA%\DC CARL\savegame.json` instead of the shared
   `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\savegame.json`. A save made
   before Phase 11 is not seen (not migrated, by design). Tests' `test_saves/` and Godot's logs
   moved with it.
2. **Windows renders through ANGLE** (Direct3D 11) instead of native OpenGL. Nothing in the game
   changed for it; the tests and the visual check were repeated on it.
3. **The title screen has a third row, Quit Game**, and Up/Down go round the rows (with two rows
   they used to toggle). `test_save_game.gd`'s "Up/Down cannot select the unavailable Continue"
   still passes unchanged (Up then Down: New Game > Quit Game > New Game);
   `test_windowed_resolutions.gd` now checks the Quit Game row.
4. **Tests fail if the game quits them early.** `game_test.gd` (and `test_surface_traversal.gd`)
   now fail with exit code 1 in `_finalize()` when a run ends before `finish()`. Before, a test
   that accidentally pressed Enter on a Quit Game ended its own process with exit code 0 and
   hid its failed checks (found by a Phase 11 mutation check). `quit_game_child.gd` opts out,
   because the game is meant to end it. The windowed test's headless SKIP counts as finished.
5. Version in Project Settings: `0.11.0`.

## Earlier behaviour changed in Phase 10
1. **Escape does something during play** (it opens the pause menu); before, it only closed the
   action menu and answered No on the title's question. It still does both.
2. **The title screen clears GameState** (`GameState.end_run()`) when it opens. Nothing used to
   rely on GameState surviving a visit to the title: Continue and New Game both reset it anyway.
   `test_save_game.gd`'s "Quit to the title" steps now pass through a cleared GameState.
3. **Stairs ignore Carl once the game is frozen** (the lifecycle fix above). Normal stairs use is
   unchanged; every stairs test passes as before.
4. **Every level has a PauseMenu child** (added at run time). Tests that list a level's children
   by name still find what they did; nothing depended on the child count.
5. **The HUD hint is "Space: action menu     Esc: pause"** and its label is wider (340 px, was
   220 px); `test_windowed_resolutions.gd` checks it fits and stays clear of the signs.
6. Version in Project Settings: `0.10.0`.

## Earlier behaviour changed in Phase 9
1. **Floor 5 has an exit** (stairs down to Floor 6) and the Bat pickup; its note
   `Signs/PrototypeNote` became `Signs/Hint`. `test_floor_05_run.gd` and `test_floor_04_run.gd` now
   expect Floor 5's only exit to lead to Floor 6 and Floor 6 to have none;
   `test_windowed_resolutions.gd` checks `Signs/Hint`.
2. **`floor_06` exists.** `test_save_manager.gd` now lists seven floors and rejects `floor_07`
   (instead of `floor_06`) as unknown, and lists the four actions.
3. **The title screen's last save in `test_windowed_resolutions.gd` is Floor 6** (it now also
   visits Floor 6), and its longest HUD text includes `S: Baseball Bat`.
4. **`Hurtbox.take_hit()` takes an optional Knockback.** Every existing call still passes only
   the damage and behaves as before.
5. **Enemies start each tick with `update_knockback()`.** Without a push (every earlier test and
   fight) it returns false at once, so nothing changes.
6. Version in Project Settings: `0.9.0`.

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
only `test_save_isolation.gd` does this). A test that ends before reaching `finish()` (for
example because the game quit its process) fails with exit code 1 (Phase 11). Tests with "windowed" in their name get a real window,
which opens briefly. The full run takes about 15 minutes (35 test files). Each test file can
also be run on its own; the first lines of each file give the command.

| Test file                               | Covers |
|-----------------------------------------|--------|
| `test_input_map.gd` (Phase 0, 13)       | Every action bound to its key; no key shared between gameplay/system actions; **the fixed `menu_*` actions on the arrows only; the nine rebindable controls' defaults equal `ControlBindings.DEFAULT_KEYS`; no menu key is rebindable** |
| `test_settings_manager.gd` (Phase 13)   | SettingsManager on its own test file: the nine defaults (each the only key event of its action) and the fixed menu keys; isolation (the player's `user://settings.json`, `test_saves/../`, look-alikes refused with errors, nothing touched; a stray file proves it first); a binding applies at once (old key dead, new key live, a held key released), emits once, refreshes hints, writes `settings_version` 1 + `keyboard` only, no `.tmp` left; all nine rebound; 17 refusals (conflicts across movement/slots/Inventory with their messages, Escape, Enter, keypad Enter, Shift, Ctrl, Alt, Meta, Caps Lock, F1, F10, volume, none) change nothing; loading a valid file, no file, a leftover `.tmp`; **27 kinds of bad file** each give the defaults with `load_failed`, the file untouched, the next change replacing it; a failed write keeps the old file; Reset to Defaults; **independence**: key changes leave the slots, inventory and save file (text and time) alone, the save is still version 3 with 7 fields and no bindings, New Game/end of run/deleting the save keep the bindings |
| `test_settings_menu.gd` (Phase 13)      | Real title and Floor 6, keys through the input pipeline: Settings on the title (no run started), the list of nine controls + Reset + Back, wrapping, Escape/Back back to Settings selected, nothing written; capture (prompt, "...", Q applied and written, message, selection kept), Escape cancels, a captured Down (and its key repeat) does not move the selection; refusals (Inventory → Q, Action Slot A → I, Enter, Shift) with messages; Reset (No selected, No/Escape keep, Yes restores, list and file updated); **pause**: Settings second row, game stays paused (time, Carl, blob, Donut, a flying stone, a cooldown, Donut's countdown frozen) while Action Slot D moves to F, the F and D pressed there punch nobody, Fists stay in the D slot, HUD "F: Fists", Escape back to the paused menu, after Resume D does nothing and F punches, F held through Resume gives no free punch, Escape still pauses, Reset from the pause menu, the save untouched |
| `test_rebinding_run.gd` (Phase 13)      | Real title/levels from a Floor 7 checkpoint (Slingshot W, potions A, bombs S, Bat D): all nine rebound by keys on the title (save untouched); Continue: same slots, HUD "1: Slingshot   2: Potion x2   3: Blast Bomb x2   4: Baseball Bat" + "Tab: action menu"; I/K/J/L move exactly like the arrows did, arrows and W/A/S/D do not; W/A/S/D use nothing, 1/2/3/4 fire, heal, throw, swing; Space opens nothing, Tab opens/closes, Escape closes; menu names 1/2/3/4/Tab, arrows move its selection (K does not), literal W assigns nothing, 4 puts Fists in the D slot and 4 punches; pause > Settings W → Q, Q fires at once; Return to Title keeps the keys, Continue plays with them; New Game keeps them (Surface sign "I/J/K/L to move", Floor 1 sign "Q/2/3/4 ... Tab"); Reset to Defaults in play updates HUD and sign at once, arrows move again, run and save untouched |
| `test_settings_restart.gd` (Phase 13)   | Fresh processes (`tests/support/settings_child.gd`, loading this test's settings file at startup as the game loads `user://settings.json`): the custom keys are in the InputMap before any scene; title, Settings list, Continue with the same slots, HUD, I/Up, 1/W, Tab/Space; the Reset-then-Quit-Game process, then a fresh one with the defaults; 5 bad files (truncated, version 2, duplicate, Escape, missing control) each start with the defaults and the title message while the valid save continues, file and save untouched; the player's `user://settings.json` refused at startup and neither created nor changed |
| `test_carl_movement.gd` (Phase 1, 3)    | Exact speed per arrow key, normalized diagonals, facing, tick-rate independence; W/A/S/D never move Carl |
| `test_surface_traversal.gd` (Phase 1)   | Title → Surface, wall collision, Donut following, stairs → Floor 1, Floor 1 walls |
| `test_combat.gd` (Phase 2, 3, 8)        | Health; Fists on D: facing, diagonals, no self-hit, W/A/S empty, exact cooldown, **Donut in the way is not hit and keeps 60 / 60 HP (Phase 8)**; Blob pursuit, walls, contact damage, death (in an arena with no navigation mesh, Carl the only party member); HUD "Carl HP"; downed Carl |
| `test_action_slots.gd` (Phase 3, 4)     | New-game layout; ActionSlots rules; Carl follows reassignment live; cooldown not reset by moving; a test-only second action works next to Fists; HUD slot bar |
| `test_action_menu.gd` (Phase 3)         | Space opens/pauses, Space/Escape close; nothing focused; Carl/Donut frozen while open; reassigning through the menu; no free punch/step across close; blob frozen while open; no menu over GAME OVER |
| `test_floor_loop.gd` (Phase 2, 3)       | Title → new game; reassignment; HP and slots carried to Floor 1; no transition loop; nothing on Floor 1 leads up; real fight and defeat; GAME OVER waits; retry with entry HP; stairs ignore an arrival on top of them |
| `test_inventory.gd` (Phase 4)           | Inventory rules, slots follow the inventory, potion use through a slot, one potion per press, menu quantities, pickups (Donut/enemy can't take them, two collectors) |
| `test_inventory_run.gd` (Phase 4, 5)    | Real potions run through Floor 1 → Floor 2 with retries; Floor 2's only exit leads down (Phase 6) |
| `test_save_manager.gd` (Phase 5–12)     | Registries (**8 floors, `floor_07` shown as "Floor 7", no `floor_08`; the 5 actions, `baseball_bat` reusable and assignable, `blast_bomb` consumable and assignable, look-alike ids unknown**); **Phase 12: a Floor 7 checkpoint with 1 bomb on A is still version 3 with the same 7 fields, `inventory` {"small_health_potion": 1, "blast_bomb": 1}, and loads back with A = Blast Bomb; the bomb in owned_items, negative/fractional/string/null/above-999 bomb quantities and look-alike ids (`Blast_Bomb`, `blast_bombs`, `blast_bomb `) are rejected; a bomb slot with no bombs (missing or 0) is emptied, kept with 2, one slot only**; **version 3 JSON with `donut`** (and owned_items); Floor 3, 4 and 5 checkpoints with the Slingshot on W and Donut's HP round-trip; **Donut at 0 (downed) round-trips**; a checkpoint has exactly the 7 fields; **Phase 9: a Floor 6 checkpoint owning the Slingshot and the Bat (on S) is still version 3 with the same 7 fields, `owned_items` ["slingshot", "baseball_bat"], and loads back with S = Baseball Bat; a Bat with a quantity, the Bat listed twice, an unknown owned id next to it are rejected; a Bat slot without the Bat is emptied, kept with it**; 55 kinds of bad data rejected with the file untouched (incl. versions 4/999, `floor_06`, **14 kinds of bad Donut data: missing, null, a number, a list, no health/max, a string, -1, above her maximum, fractional, max 0, max above 1000**, Slingshot with a quantity, bad owned_items); slots sanitized; Donut 0 and exactly 60 accepted; delete; interrupted-save recovery |
| `test_save_game.gd` (Phase 5, 6, 8)     | Real title + levels: checkpoints (save_version 3, Donut 60 / 60), Continue, deaths, New Game confirmation, corrupt/unsupported saves |
| `test_save_migration.gd` (Phase 6–12)   | The two real Phase 5 fixtures (version 1), the two real Phase 6 fixtures and **the real Phase 7 Floor 4 fixture** (version 2) load with their floor, HP, items and slots and **Donut at 60 / 60**, the files untouched, and are written back with the same values as version 3 plus Donut; a v1 Slingshot slot is emptied, a v1 `owned_items` ignored, a v1 Slingshot quantity rejected; 13 kinds of malformed v1 data rejected; v2 loads (a `donut` in a v2 file is ignored), v2 without owned_items rejected; **v3 loads with its own Donut HP, v3 without `donut` rejected**; versions 0/4/999/-1 rejected; title → Continue on the v1 Floor 2 save and **on the Phase 7 Floor 4 save** open those floors with their state and Donut at 60 / 60, and the files become version 3; the migrated game plays on; **Phase 9: the real Phase 8 Floor 5 save (version 3, no Bat) loads unchanged and is written back identically; no migrated v1/v2 fixture owns the Bat; a v1 file naming the Bat in owned_items and on W owns no Bat and W is emptied**; **Phase 12: the real Phase 11 Floor 6 save (`phase11_save_v3_floor_06.json`: version 3, Carl 80, Donut 40, Slingshot W, potion A, Bat S) loads unchanged with no bombs and is written back identically; no v1, v2 or Phase 8 fixture has bombs** |
| `test_slingshot.gd` (Phase 6, 8)        | Ownership model (innate/reusable/consumable, owned once, never removed, snapshots, new run clears it); slots; pickup; firing in four directions; exactly 10 damage, 3 hits kill a blob; one target only; flies through a dying blob; hits a blob that steps onto it; stops at a wall face; 320 px / 40 ticks; never hurts Carl, **nor Donut, whose real Hurtbox is in the line of fire (60 / 60, Phase 8)**; no pickup, no stairs; point blank; cooldown; menu; HUD and menu labels |
| `test_slingshot_run.gd` (Phase 6–8)     | Real run: New Game clears a previous Slingshot; Surface → Floor 1 → Floor 2 → Floor 3, nothing leads up (Floor 3's only exit leads down to Floor 4); Floor 2 entry has no Slingshot (run, entry state, disk: version 3, Donut 60 / 60); collect + W doesn't save; two Floor 2 deaths take it back; quit before Floor 3 → Continue without it; three stones kill the Floor 2 blob; Floor 3 arrival, the Floor 3 checkpoint owns it with W = Slingshot; a stone stops at Floor 3's wall tiles; two Floor 3 deaths keep it; Continue opens Floor 3 and it fires; New Game clears it |
| `test_windowed_resolutions.gd` (Phase 2–13) | At 1280×720, 640×360, 1024×768: HUD with `W: Slingshot   A: Potion x2` **and "Donut HP: 0 / 60 - DOWNED" fully on screen, its text fitting, clear of Carl's HP and the slot bar**, GAME OVER panel, action menu, camera; Floor 2's Slingshot pickup; Floor 3's signs clear of the HUD; a flying stone; Floor 4's three signs clear of the HUD; the two blobs, a glob and a stone on screen together; **Floor 5's three signs clear of the HUD; a downed Donut's DOWNED label drawn on screen, clear of the HUD; Donut's colour unlike both blobs'**; **Phase 9: the slot bar `W: Slingshot   A: Potion x2   S: Baseball Bat   D: Fists` on screen with its text fitting; "Baseball Bat   (on S)" in the menu; Floor 5's Hint and its Bat pickup (icon and label) on screen and clear of the HUD; Floor 6's three signs clear of the HUD; a blob drawn on screen while the Bat knocks it back**; **Phase 10: the HUD hint "Space: action menu     Esc: pause" on screen and fitting; the pause menu above the HUD and action menu, on screen and centred with its rows fitting; both questions on screen and centred with the warning, No and Yes fitting; the title after Return to Title on screen with the Floor 6 checkpoint**; **Phase 11: the renderer the window really uses (Compatibility; on Windows `opengl3_angle`, printed with the adapter); the title's Quit Game row on screen at each size, the three rows stacked above the save line, and Quit Game selected on screen**; **Phase 12: Floor 6's `Signs/StairsHint` clear of the HUD; the dropped Blast Bomb x2 pickup (icon and label) on screen; Floor 7's three signs on screen, fitting and clear of the HUD; the longest slot bar `W: Baseball Bat   A: Potion x2   S: Blast Bomb x12   D: Slingshot` on screen with its text fitting, and its menu row; a thrown bomb drawn on screen in flight, frozen under the pause menu and still drawn, and its explosion drawn; once, one explosion on the pair: both hit, all on screen; the pause menu and Return to Title now on Floor 7**; the title screen (with a Floor 7 save, and broken) and its confirmation. Prints SKIP and passes when run headless; **Phase 13 (289 checks): the Settings screen from the pause menu (nine rows with keys, Reset, Back, the message) on screen, centred and fitting at each size, with the capture prompt and a "BracketLeft is already assigned to Action Slot W." conflict; the Reset question; with 1/2/3/4 and Tab the HUD slot bar and hint and the action menu's slot column, "(on 1)" row and help line fit at each size; the pause menu's and title's four rows; the title's settings-error line** |
| `test_enemy_navigation.gd` (Phase 7, 8) | Arenas with a real baked navigation mesh, each waiting until the map holds exactly its mesh: the Blob waits beyond 220 px, notices Carl behind a wall, gives up beyond 320 px; it follows a route around a wall to Carl (its own path bends round the wall's end), never overlaps the wall, never stalls, reaches him and hurts him every 0.8 s; with no way around it stops beside the wall without jittering; the Spitting Blob with Carl hidden walks around the wall and spits only once it sees him; **Phase 8: with Carl far away, a blob picks Donut behind the wall, walks around it without overlapping it, reaches her and hurts her 10 every 0.8 s (60 → 30)** |
| `test_spitting_blob.gd` (Phase 7, 8)    | Arenas (Carl the only party member): its numbers; waits beyond 360 px, closes in and spits at 320 px, holds at 280 px, backs off to 180 px, gives up beyond 480 px; touching it never hurts; a wall stops it spitting, stepping into sight or removing the wall makes it spit at once; a glob takes exactly 10 HP once; walls stop globs; a glob flies past stairs, a pickup, another Spitting Blob and a Gelatinous Blob and hits Carl, hurting none of them nor its own blob, even when made to target enemies; 384 px / 96 ticks; 5 globs exactly 90 ticks apart, no burst; three stones kill it; Fists by facing; the menu freezes everything, no free glob, stone or burst |
| `test_donut.gd` (Phase 8)               | Arenas: a new run (also after one where she was downed) gives Donut 60 / 60; Health 60, Hurtbox on `player_hurtbox`, the `party` group, Scratch's numbers; an enemy's touch takes 10 every 0.8 s; HP never below 0; Carl's point-blank punch and a stone through her never hurt her; Scratch never hurts Carl or Donut and never fires with no enemy near; exactly 10 per scratch, exactly 60 ticks apart, three kill a blob, none on a dead one; an enemy 38 px away is scratched, 46 px is not; the nearest of two only; she stays by Carl and follows him, never toward an enemy; downed at 0: HUD "0 / 60 - DOWNED" in another colour, grey, on her side, DOWNED label, cannot be hit; no following, no scratching, a touch finds nothing, nothing paused; she gets up on her 360th downed tick (not at 359) with exactly 30 / 60, looks normal, catches up with Carl, scratches again; 5 s of menu do not count toward the 6 s; GAME OVER (the tree pause) and a downed Carl hold her countdown |
| `test_party_targeting.gd` (Phase 8)     | Arenas: an enemy picks Carl or Donut, whoever is nearest within 220 px, nobody beyond; keeps Donut every tick while Carl alternates 1 px nearer and farther for 2 s, and even with Carl much nearer; drops her beyond its chase range and picks Carl; drops a downed Donut on the next tick (picks Carl, or goes idle) and never goes back; picks her again when she gets up; the Blob chases Donut at its speed and its touch takes exactly 10 every 0.8 s; touching both, each touch hurts only the nearer; the Spitting Blob picks Donut, never spits at her through a wall (3 s), spits at once when the wall goes, the glob takes exactly 10, the next exactly 1.5 s later, a wall stops a glob flying at her, it drops her when she is downed and spits no more; it still spits at Carl; it keeps 280 px / backs off to 180 px from Donut; a glob hits only the first of Carl and Donut in its way (either order), once, flies past a Gelatinous Blob, and flies past a downed Donut to Carl |
| `test_floor_05_run.gd` (Phase 8, 9, 12) | Real run: every level's exits lead one floor down, Floor 7 has none (Phase 12; Floor 6 until then); Continue on a version 3 Floor 4 save (Carl 80, Donut 40) → Floor 4 with both HPs; its stairs → Floor 5: spawn, Donut, camera, sign, HUD (Carl 80, Donut 40), two blobs and a Spitting Blob, only the stairs down to Floor 6 (Phase 9), no loop, entry state and checkpoint (version 3, Donut 40); the penned blob picks Donut over Carl, walks around the pen wall, three scratches kill it while its three touches take her 40 → 10; Carl untouched; the entry state and save unchanged; Carl down → GAME OVER waits, Donut frozen; retry → Carl 80, Donut 40, enemies as authored; Donut downed by the penned blob: no GAME OVER, HUD and label DOWNED, the blob turns on Carl, Carl punches it dead, she never moved or scratched; the menu freezes her countdown and the enemies; she gets up after 6 s of play with 30 / 60 and follows Carl; GAME OVER while she is downed holds her countdown 7 s; retry → Donut 40; quit and Continue opens Floor 5 directly with everything, the penned blob going for Donut; a Floor 4 save with Donut at 0: she starts downed, Carl takes the stairs anyway, she arrives downed, the checkpoint says 0, enemies ignore her, she gets up after a fresh 6 s (359 ticks) on Floor 5 and can be picked again; New Game: Carl 100, Donut 60 / 60, save version 3 |
| `test_baseball_bat.gd` (Phase 9)        | Arenas: a new run owns no Bat; its data (id, reusable, own icon; MeleeAttack 20 damage, 0.75 s, 36 px + 28 px = 64 px reach, `enemy_hurtbox`, blocked by `world`, 80 px / 0.3 s knockback); owned once, never removed, "Baseball Bat" with no quantity, snapshots, a new run clears it; not assignable before owned, then on W/A/S/D one at a time, next to Fists/Slingshot/potion, emptied when taken back; the pickup (label, icon; Donut and both enemies standing on it don't take it; Carl does, once; two collectors: one); swings right/up/left/down hit the enemy in front for 20, not the ones behind or beside; empty slots nothing; 20 then 10 (its last HP) kill a blob, which dies normally and is not pushed; one swing per tap and per 10-tick press, every 45 ticks while held, taps no faster, moving it to W keeps the cooldown; a swing through Donut hurts neither her nor Carl and pushes neither (no KnockbackReceiver); a thin wall within reach blocks the hit; knockback in four directions: visible at once, exactly 80 px, then no drift; exactly 18 ticks and the full 80 px for a blob chasing Carl, which then comes back; against a thick and a thin wall: stops against it, never overlaps or crosses, no sideways deflection; killed mid-push: stops at once, never moves or touches Carl; on a real navigation mesh: pushed into a wall it stops, then navigates back (fresh path ending at Carl) and touches him for 10; the Spitting Blob: no glob during the 18 push ticks, exactly 80 px, backs off again afterwards, next globs exactly 90 ticks after the one before; on a mesh it returns to 180 px and spits again; Fists (10, no push), stones (10, no push), Scratch (10 every 60 ticks, no push) and globs unchanged; a touch never pushes Carl; the menu: S selects nothing, freezes a push, completes it after, no free swing with S held, the blob chases again; a tree pause (GAME OVER) freezes a push, which then finishes its 80 px; HUD "S: Baseball Bat" and menu rows, unchanged by swinging |
| `test_floor_06_run.gd` (Phase 9, 12)    | Real run from a real Phase 8 save (`phase8_save_v3_floor_05.json`): every exit leads one floor down, Floor 5's to Floor 6, Floor 6's to Floor 7 and Floor 7 none (Phase 12), `floor_06` registered; Continue → Floor 5 without the Bat, its pickup there; collect it, menu "Baseball Bat   (no slot)", assign S through the menu, HUD, save unchanged; two Floor 5 deaths take it back (pickup back, S empty, entry HP, nothing duplicated); quit before Floor 6 → Continue without it; the Bat hits a Floor 5 blob for 20 and pushes it 80 px, a second hit kills it where it stands; Floor 5 → Floor 6: spawn, Donut, camera, sign, HUD with S: Baseball Bat, two blobs and a Spitting Blob as authored, only the stairs down to Floor 7 (Phase 12), entry state and save (version 3, owned_items slingshot + baseball_bat, S = baseball_bat), no loop; the Backstop blob comes for Carl, the Bat pushes it into the Backstop wall where it stops at x 563 without overlapping, then it comes back at Carl; GAME OVER during a push freezes it, nothing about it is saved, the retry has the blobs as authored with no push; two Floor 6 deaths keep the Bat on S with the entry HP; Continue opens Floor 6 with the Bat on S and it swings and knocks back at once; New Game: no Bat, no items, D = Fists, the Surface checkpoint owns nothing |
| `test_blast_bomb.gd` (Phase 12)         | Arenas (122 checks): the bomb's data (consumable, own icon; ProjectileLauncher 1.0 s; Projectile 220 px/s, 240 px, 0 impact damage, stopped by enemies and walls; DetonateOnStop; AreaDamage 20, 72 px, enemy_hurtbox, walls shield; registered); a new run has none (also after one that had 3 on S); not assignable at 0; "Blast Bomb x2"; W/A/S/D one at a time; the slot empties at 0 and it is assignable again after more; snapshots never duplicate; thrown right/up/left/down from Carl's centre, one per tap, each spending exactly one; one per 10-tick press; holding S throws at 0, 60 and 120 ticks; taps no faster; a press half a second after a throw spends nothing; ready again exactly 60 ticks after a throw; none at 0; in the open exactly 240 px in 66 ticks, one explosion where it stopped, never again; a wall stops it at its face and the blob 52 px behind the wall is unhurt; an enemy stops it and loses exactly 20 once; a second `detonate()` does nothing; one explosion: a Gelatinous and a Spitting Blob each lose exactly 20 once, a second kills both, a dying one is not hit, four around it each lose 20; reach: a blob 84 px away is hit, 88 px is not; explosions at Carl's and Donut's centres and a bomb against a wall 50 px away hurt and move neither; no push, nothing moves; wall shielding: 60 px behind a wall nothing, 60 px in the open 20, wall removed 20; the flash shows 0.35 s then goes; a tree pause freezes a bomb in flight (still lands 240 px away) and a flash; the menu: S throws nothing, closing it with S held throws nothing, one throw after, no burst; Carl down + frozen: nothing thrown; HUD `S: Blast Bomb x2` → x1 → `S: —`, menu rows follow; **loot drop**: nothing while the enemy lives, its death gives nothing, one pickup exactly where it died ("Blast Bomb x2", bomb icon, in the blob's parent), it stays after the blob fades, Donut and two enemies on it and a stone and a bomb over it take nothing, Carl walking over it gets exactly 2 once, two collectors get 2 in all, a death announced twice drops once, a Spitting Blob drops too, a bomb kill drops too; the Bat (20, 80 px push) and a stone (10, no push) unchanged |
| `test_floor_07_run.gd` (Phase 12)       | Real run from the real Phase 11 save (118 checks): every exit leads one floor down, Floor 6's to Floor 7, Floor 7 none, `floor_07` registered as "Floor 7"; Continue → Floor 6 with no bombs, the checkpoint written back identical to the Phase 11 file, the loot blob carrying Blast Bomb x2, no drop lying there; the Bat kills it: no bombs from the death, one "Blast Bomb x2" pickup where it died, walking over it gives exactly 2, the menu lists it, A assigns it, HUD `A: Blast Bomb x2`, the save unchanged; two Floor 6 deaths: no bombs, A back to the potion, nothing duplicated, the blob alive at its spawn with its drop unused, no pickup; pause > Return to Title > Yes, then Continue: no bombs, the blob alive; a bomb at the Backstop blob: exactly 20, x1 left; the stairs → Floor 7: spawn, Donut, camera, sign, HUD `A: Blast Bomb x1`, three Gelatinous Blobs and a Spitting Blob as authored, the pair within one blast, the shielded blob within 72 px of the wall's face with the wall in between, no exits, the checkpoint in memory and on disk (version 3, seven fields, blast_bomb 1, A = blast_bomb) and loaded back, no loop; the last bomb at the pair: both lose exactly 20, unmoved, Carl and Donut unhurt, 0 left, A empty, the menu without it; a Floor 7 death: the bomb back on A, the pair at 30; a bomb against the blast wall explodes at its face within 72 px of the blob behind it, which takes nothing; quit and Continue: Floor 7 with the bomb on A, which hits the pair; New Game: no bombs, only Fists, the Surface checkpoint without bombs |
| `test_save_isolation.gd` (Phase 8)      | The save guard: in a test run the player's save path, look-alike paths (`user://test_saves/../savegame.json`, `user://test_saves_old/...`), the `.tmp` beside it and other files are refused, test-folder paths allowed; a stray file outside the folder is neither written, loaded nor deleted, each refusal reported; then, pointed at the player's save, SaveManager finds and loads nothing and refuses to write, and a level starting in that state cannot save its checkpoint; the player's save (if any) keeps its modification time; the test's own file still works |
| `test_pause_menu.gd` (Phase 10, 13)         | Real levels, keys through the input pipeline: every level (Surface, Floors 1–6) has exactly one pause menu, Escape opens it (Resume selected, rows, no focus), gameplay ticks stop, Escape and Enter on Resume resume, the save untouched; Up/Down wrap, Resume selected on reopening; paused Carl cannot move, turn, punch, fire, swing, drink or reassign; a key held while resuming gives no free action, then D/W/S/A work; Donut stops mid-stride; a blob touching Carl while Donut scratches it: nothing happens for 180 paused ticks, then the next scratch is exactly 60 and the next touch exactly 48 ticks of play after the last; the Spitting Blob's glob freezes in flight, nothing is spat for 180 ticks, globs exactly 90 ticks of play apart; a stone freezes then flies on, no extra stone; a Bat push freezes unfinished, then completes exactly 80 px; Donut gets up after exactly 360 ticks of play with or without a 180-tick pause (her countdown holds); Space/Escape between the two menus (echo included, same-frame key pairs): never both open, paused exactly when one is open; GAME OVER: Escape/Space open nothing, everything frozen, Enter retries, the pause menu works after; stairs and a pickup do nothing while paused and work after; **the lifecycle fix: stairs + death in one tick keep GAME OVER on the floor with a loadable checkpoint, then retry and stairs work**; **Phase 13: four rows, Settings second, Down goes through all four** |
| `test_return_to_title.gd` (Phase 10, 13)    | Real title and Floor 6 from a seeded checkpoint (Carl 80, Donut 40, potion on A, Slingshot W, Bat S): the question's text, No selected, Escape and No go back to the paused menu, Down/Up toggle Yes/No, the live floor untouched (Carl 60, Donut 10, no potion, stone flying on); Yes: the title in the same process, unpaused, the level freed, no Carl/Donut/enemy/projectile left, the save byte-identical and not rewritten, the title says HP 80 (not 60), GameState holds no run; Continue restores everything (HP, items, slots, the killed blob back, 30 HP each, no projectiles); **Continue reads the disk: a different checkpoint written while the title is up and a stale run planted in GameState → Continue opens the disk's Carl 55 / Donut 25**; 5 Continue → play → Return cycles with identical node and connection counts (one Carl, Donut, HUD, action menu, pause menu, 3 enemies); New Game after returning asks (No keeps the save), Yes gives the canonical Surface run and checkpoint; the save is version 3 with its seven fields; a Phase 5 v1 and a Phase 6 v2 save load after returning, Continue twice each, the file becomes version 3; **Phase 13: Return to Title is the third row** |
| `test_quit_game.gd` (Phase 10, 13)          | Real process exits: a seeded Floor 6 checkpoint, then `tests/support/quit_game_child.gd` in its own Godot process: Continue, live changes (Carl 60, Donut 10, no potion, a kill, a stone), pause > Quit Game (the warning, No selected, Escape and No cancel, Yes quits): exit code 0, no engine error or crash marker, the save byte-identical and last written on floor entry; the same with the window's close request; after each, this process's title and Continue restore the checkpoint; the helper refuses (exit 2, nothing run) the player's save path, a `test_saves/../` path and no path, and the player's save keeps its modification time; **Phase 13: the child reaches Return to Title / Quit Game past Settings** |
| `test_project_setup.gd` (Phase 11–13)  | Project settings in a real process: Use Custom User Dir on, Custom User Dir Name `DC CARL`; `OS.get_user_data_dir()` = app-data folder + `DC CARL` (printed), not `Godot/app_userdata/...`; `user://savegame.json` resolves inside it; no game script names an absolute or per-user path; the test guard refuses the player's save (also through `test_saves/../`), this test's own file is in `test_saves/` inside the new folder; the Compatibility renderer, `driver.windows` = `opengl3_angle`, the other platforms' drivers and both fallbacks at Godot's defaults, `project.godot`'s only driver line; version 0.12.0 (Phase 12); save format 3; **Phase 13: version 0.13.0, settings format 1, `user://settings.json` in the DC CARL folder and refused in a test run, this test's own settings file, the autoloads exactly GameState, SaveManager, SettingsManager** |
| `test_title_quit.gd` (Phase 11, 13)         | Real title screen, keys through the input pipeline: no save → Continue greyed, New Game selected, Quit Game offered, Up/Down go round New Game and Quit Game only; a Floor 6 save → Continue selected, Up/Down round all three; New Game's question (No selected, its Up/Down leave the menu alone, Escape back, save untouched); an unloadable save → New Game selected, Quit Game offered, New Game still asks; Floor 6 > Return to Title → Quit Game selectable, then Continue restores the checkpoint. Real process exits (`quit_game_child.gd`): Quit Game on the title with no save (exit 0, no file created), with the save (exit 0, byte-identical, not rewritten), and after Return to Title (exit 0, the checkpoint, last written on floor entry); each pressed with Quit Game selected and GameState the title's cleared run; **Phase 13: four rows (Settings third) with and without a save and after Return to Title** |
| `test_floor_04_run.gd` (Phase 7–9, 12)  | Real run from a real Phase 6 Floor 3 save: title → Continue → Floor 3 (the same checkpoint saved again as version 3 with Donut 60 / 60); every level's exits lead one floor down, **Floor 4's only exit to Floor 5**, Floor 5's to Floor 6 (Phase 9), Floor 6's to Floor 7 and Floor 7 none (Phase 12); Floor 3 → Floor 4 arrival and checkpoint (version 3); the Blob walks around wall A and three punches kill it; the Spitting Blob walks around wall B, spits only in sight, the menu freezes it and its glob; globs take Carl to 0 HP, GAME OVER waits; retry restores everything; GAME OVER with a glob in flight freezes it; three stones kill the Spitting Blob; quit and Continue on Floor 4; New Game starts clean (Donut 60 / 60). Donut is present and fights along throughout |

Every test uses its own save file under `user://test_saves/`, and SaveManager refuses anything
else in a test run (see Persistent save > Test save isolation). The child process of
`test_quit_game.gd` and `test_title_quit.gd` (`tests/support/quit_game_child.gd`, not a test itself:
it only runs when one of them starts it; Phase 11 added its `title_quit` and `return_title_quit` modes)
takes its save file on the command line and refuses, before doing anything, a path outside that
folder or no path; being a `-s` run, SaveManager would refuse the player's save too.
Every test also has its own settings file under `user://test_saves/` (Phase 13), and SettingsManager
refuses anything else in a test run. `tests/support/settings_child.gd` (the child of
`test_settings_restart.gd`) takes its files on the command line and refuses, before doing anything,
save or settings paths outside that folder (except in its `production` mode, which exists to show
SettingsManager refusing the player's file at startup).

## Validation performed (Phase 13)
All runs used Godot 4.7.2.stable.official on the Phase 12 machine: Windows 10 (user `Komputer`), an
NVIDIA GeForce GTX 750 Ti (driver 32.0.15.6094). (Phase 12's validation record is in
`PROJECT_STATE.md` at commit `b471ffe`, Phase 11's at `41c57f2`.) Everything that could write a save
or a settings file ran either as a guarded test (`-s`, its own files in `user://test_saves/`) or in a
scratch copy of the project whose only differences were its own `custom_user_dir_name` (and, for the
played sessions, a scratch-only driver autoload): `dc_carl_p13_play`, `dc_carl_p13_mutation`.
- **Baseline before changes:** HEAD `b471ffe` = `origin/main`, clean tree. The unmodified Phase 12
  suite passed **31 of 31** (842 s). The normal entry point (title screen, real window, no script,
  240 frames) exited 0 on "OpenGL ES 3.0 (ANGLE 2.1.1) … ANGLE (NVIDIA, NVIDIA GeForce GTX 750 Ti
  Direct3D11 …)": **`opengl3_angle`**. (The class cache was current this time; one `--import` after
  adding the new scripts registered `ControlBindings`.)
- **Test suite:** `run_all.gd` passed **35 of 35** on the Phase 13 code, and again **35 of 35**
  (906 s) on the final tree; a normal launch of the final tree then exited 0 on `opengl3_angle` and
  wrote no settings file. New: `test_settings_manager.gd` (222 checks), `test_settings_menu.gd` (58),
  `test_rebinding_run.gd` (74), `test_settings_restart.gd` (72, with `tests/support/settings_child.gd`). Changed: see Tests and
  "Earlier behaviour changed in Phase 13". The windowed test (real window, ANGLE) now makes 289
  checks.
- **Mutation checks** (`dc_carl_p13_mutation`, its own user-data folder; each mutation applied, its
  tests run, the files restored; "caught" = FAIL lines or an exit code the unmutated copy does not
  have; `test_project_setup.gd` always reports its two folder-name failures in the copy, which were
  subtracted). **All 13 caught:**
  settings stored inside the savegame instead of their own file (settings_manager, save_manager,
  settings_restart); New Game resets custom controls (rebinding_run, settings_manager); changing a
  slot's key clears that slot's action (settings_menu, rebinding_run, settings_manager); HUD still
  hard-coded to W/A/S/D (settings_menu, rebinding_run); inventory assignment listening to literal
  W/A/S/D (rebinding_run); duplicate keys accepted (settings_manager, settings_menu); Escape allowed
  as a binding (settings_manager, settings_restart); corrupt settings crash startup, i.e. validation
  removed (settings_manager, settings_restart); settings loaded by the level instead of at startup
  (settings_restart); Reset to Defaults modifies the savegame (rebinding_run, settings_menu,
  settings_manager); save schema bumped to 4 (project_setup, settings_manager, save_manager); renderer
  reverted from ANGLE (project_setup, windowed_resolutions); automated tests using the production
  settings file, with the guard opened (settings_manager, project_setup).
- **Real gameplay, real processes** (`dc_carl_p13_play`: the normal title screen as main scene, real
  windows, real key events through Godot's input pipeline, movement included, pressing whichever
  keys are bound; no `--rendering-driver` argument: every run reported `opengl3_angle`; every run
  ended through the game's own Quit Game, exit code 0; no engine error, warning or crash in any log):
  - *rebind*, at **1280×720, 640×360 and 1024×768**, each from a fresh folder holding only the real
    Phase 11 Floor 6 save (48 checks each, all passed): at startup the defaults and no settings file;
    the title offers Continue, New Game, Settings, Quit Game; Settings rebinds by key presses Move Up/
    Down/Left/Right = I/K/J/L, Action Slots W/A/S/D = 1/2/3/4, Inventory = Tab (capture prompt shown);
    Inventory → 1 refused ("1 is already assigned to Action Slot W."); Reset asks with No selected, No
    keeps them; the copy's `settings.json` holds `settings_version` 1 and the keys, and the save is
    untouched. Continue: HUD "1: Slingshot   2: Potion x1   3: Baseball Bat   4: Fists" and "Tab:
    action menu". Up/Down/Left/Right and W/A/S/D move Carl 0 px; L/K/J/I move him 60 px right, down,
    left, up. Literal W/A/S/D use nothing; **2** drinks the potion (80 → 100, "2: —"); **3** swings
    the Bat at the loot blob ([20, 10]); walking over its drop with I/J/K/L gives 2 Blast Bombs; Space
    opens nothing, **Tab** opens the menu, literal W assigns nothing, **2** puts the bombs in the A
    slot ("Blast Bomb x2 (on 2)", help "1/2/3/4: put it on that key     Tab/Esc: close"), Tab and
    Escape close it (Escape pauses nothing); at the Backstop blob **1** fires a stone (10), **4**
    punches (10) and **2** throws a bomb whose blast kills it (one bomb left). Escape: the pause menu
    with Settings; Action Slot D 4 → F while paused (the F punched nothing, nothing moved); after
    Resume 4 does nothing and F punches, HUD "F: Fists". Return to Title: the title's Settings lists
    I, K, J, L, 1, 2, 3, F, Tab; Continue: the Floor 6 checkpoint again with those keys, I moves Carl.
  - *restart* (1280×720), a **new process**: the custom keys were in the InputMap before the title
    ran; the title's Settings lists them; Continue re-saved an identical checkpoint; HUD "1: Slingshot
    2: Potion x1   3: Baseball Bat   F: Fists"; I moves Carl, Up does not; 1 fires, W does not; Tab
    opens the menu. Back on the title: Settings > Reset to Defaults > Yes (No was selected first): the
    nine defaults, the save unchanged; Quit Game on the title: exit 0 (9 checks).
  - *defaults* (1280×720), a **new process** after that: the defaults at startup, HUD "W: Slingshot
    A: Potion x1   S: Baseball Bat   D: Fists" and "Space: action menu"; Up moves Carl, I does not; W
    fires, 1 does not; Space opens the menu (5 checks).
  - *corrupt* settings, written into the copy's folder before a launch: a truncated file (at all three
    sizes), a file binding I to Move Up and Action Slot W (duplicate), and a file binding Inventory to
    Escape (reserved), each with the valid save present (6 checks each): the game started with the
    defaults and `load_failed`; the title showed "Control settings could not be loaded. Defaults
    restored." (in red, under the save line) and still offered Continue; the Settings screen showed the
    same message; Continue opened Floor 6, Up moved Carl, W fired. The bad file and the save kept the
    same hashes.
  - Across all ten launches the save file kept one hash (Continue writes the same checkpoint back).
- **Visual check under ANGLE** (the sessions' screenshots, inspected, plus the windowed test's layout
  checks) at 1280×720, 640×360 and 1024×768: the title with Settings (selected and not), the Settings
  screen with the defaults and the custom keys, the capture prompt ("..." and "Press a key for Action
  Slot W   (Esc: cancel)"), the conflict message, the Reset question, the pause menu's four rows, the
  Settings screen over the paused Floor 6, the rebound HUD ("F: Fists", "Tab: action menu"), the
  rebound action menu ("(on 2)", "1/2/3/4 ... Tab/Esc: close"), and the title and Settings screen
  with the settings error. Everything is drawn, centred and inside its panel; at 640×360 the text is
  small but legible, as before. (The Settings panel was then made fully opaque, because the title
  showed faintly through its 98 % background.)
- **Save and settings locations, before and after** (read-only snapshots):
  - *production folder* `%APPDATA%\DC CARL\`: **no `savegame.json` and no `settings.json` at the
    start or at the end**; `test_saves/` empty at the end. The one normal launch only read (no
    settings file: defaults, nothing written);
  - *old shared folder* `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\`: every file's
    hash, size and time identical at the end;
  - *sibling project* `../dc_carl_codex`: `git status` and HEAD (`3e5b9de`) identical before and after;
  - scratch saves and settings lived only in the `dc_carl_p13_*` folders.
- No test file is left in `test_saves/`, and no save or settings file is tracked by Git.

## Known issues / limitations
- **Control settings (Phase 13 simplifications):**
  - keyboard only: one key per control, no gamepad, mouse or chords; function keys, modifiers on
    their own, lock and media keys cannot be bound;
  - key names are Godot's English, layout-independent names of the physical key position ("Q",
    "BracketLeft", "Kp 1", "QuoteLeft"): on a non-US layout a key may be labelled differently from
    what is printed on it (the binding itself follows the physical key, as before Phase 13);
  - long key names can make the HUD's slot bar and the signs longer than their boxes (checked with
    1/2/3/4 and Tab at every size; "BracketLeft" for all four slots with the longest items would not
    fit at 640×360);
  - in the action menu Escape, Up and Down keep their menu meaning, so a slot bound to Up or Down Arrow
    cannot be assigned by its key there (assign it to another slot's key, or rebind it);
  - a refused capture ends with its message; press Enter to try again;
  - an unusable settings file stays on disk until the next change or Reset (the defaults are used and
    the title says so at every launch until then);
  - the signs that name keys follow the bindings; other world text never names keys;
  - the pause menu and the title keep their fixed hints ("Up/Down: choose ...").
- **Blast Bomb, area damage and drops (Phase 12 placeholders and simplifications):**
  - the bomb, its fuse spark and the explosion are drawn shapes: no sprite animation, particles,
    sound, screen shake or throwing arc (it flies straight, top-down). The explosion's disc is drawn
    as a full circle, also over and beyond walls, although the damage behind a wall is shielded;
  - the bomb is thrown in Carl's facing direction, which follows the last arrow keys held,
    diagonals included; there is no separate aiming. It is a point (a ray), so it passes between
    two enemies whose Hurtboxes do not touch its centre line, and it stops on the **first** enemy
    in its path even if the player meant one behind it;
  - thrown at a wall right in front of Carl, it explodes there: harmless to Carl and Donut by
    design (their Hurtboxes are on the player's side), so the bomb is never a risk to the player;
  - shielding is decided by one ray between the two centres, as for the Bat: an enemy whose centre
    is hidden behind a wall corner is shielded even if part of it shows, and one whose centre is
    visible is hit even if most of it is behind the corner. Only walls (`world`) shield; Donut,
    other enemies and Carl never do;
  - a blast does not alert enemies: an idle enemy it hurts stays idle until Carl comes within its
    detection range (detection is by distance, as since Phase 2);
  - a dying enemy (fading out) is neither hit by a blast nor stops a bomb, as for stones;
  - drops are deterministic only: one item and quantity per enemy, no chances, rarity or tables.
    The drop appears exactly where the enemy's centre was, which is always a spot Carl can reach
    (enemy bodies keep clear of walls like his);
  - Floor 6's loot blob is marked by a world sign placed where it waits; once it chases Carl the
    sign stays behind;
  - a Blast Bomb pickup on Floor 6 could only be kept by reaching Floor 7 with it; quitting or
    dying before that takes it back, by design (the floor-entry checkpoint rule);
  - Floor 7 is a small test room with no exit ("Prototype: the way further down is not built
    yet."). Walking straight in wakes the pair (they notice Carl within 220 px).
- **This phase ran on a different machine** from Phases 10–11 (user `Komputer`, an NVIDIA GeForce
  GTX 750 Ti with driver 32.0.15.6094, and the sibling project at `../dc_carl_codex`). ANGLE started
  and rendered normally there. The Intel native-OpenGL exit crash (below) was not re-tested: it is a
  driver issue of the Phase 10–11 machine.
- **Title screen and project setup (Phase 11 placeholders and simplifications):**
  - Quit Game on the title quits without asking, by design (nothing can be lost there);
  - a save made before Phase 11 is not offered (see "The old shared user-data folder" below);
  - there is no in-game graphics or renderer option, by design; Windows always asks for ANGLE, and
    Godot's default `fallback_to_native` would start native OpenGL only if ANGLE cannot start;
  - the stress windows take the keyboard focus as they open, so typing elsewhere during a stress
    run can reach a game window (it happened once in Phase 11; see its validation record at
    commit `41c57f2`);
  - in a *broken* test run where the game quits the test process mid-test (only seen with an
    injected regression), the headless process sometimes ends with an access violation
    (`0xC0000005`) instead of exit code 1. Either way the run fails; normal test runs never
    do this.
- **Pause menu (Phase 10 placeholders and simplifications):**
  - keyboard only (no mouse), three options only: no settings, volume, key rebinding or
    save-anywhere (out of scope);
  - Return to Title and Quit Game drop everything since the floor was entered, by design: that
    is what the question warns about;
  - closing the window (or Alt+F4) quits at once without asking, the same as Quit Game > Yes;
  - while the game is paused the camera does not move, so resizing the window during a pause
    (or GAME OVER, as before) shows the level off-centre until play resumes. The menus
    themselves stay centred.
- **Baseball Bat and knockback (Phase 9 placeholders and simplifications):**
  - the swing is shown only as a brief tan circle where it hits (like Fists' white one); there is
    no bat sprite on Carl, swing animation, sound or impact effect. The pickup icon is a small
    original placeholder;
  - the swing's area is a circle, not an arc: it hits every enemy whose Hurtbox overlaps it,
    which includes enemies slightly to the side in front of Carl, never ones level with him or
    behind him;
  - "through a wall" is decided by one ray from Carl's centre to the enemy's centre: an enemy
    whose centre is hidden behind a wall corner is not hit even if part of it shows;
  - the push goes in Carl's facing direction, which can be diagonal (facing has followed the last
    movement direction, diagonals included, since Phase 2; this phase did not change it);
  - a push that meets a wall keeps pressing into it until its 0.3 s are over: the enemy stands
    still against a wall hit square on, or slides along one hit at an angle. It does not end
    early and does not bounce;
  - pushed enemies collide with Carl, walls and other enemies (their body's mask), and pass
    through Donut, as when they walk;
  - a pushed enemy can end up 1 px inside the 14 px margin the navigation mesh keeps from walls
    (a 13 px blob against a wall). The navigation server then starts its path from the nearest
    point of the mesh, which works (tested on Floor 6 and in the arenas);
  - nothing but the Bat knocks back, and nothing knocks Carl or Donut back. Hitting an enemy
    during its push restarts the push;
  - enemies still have no invulnerability after a hit: Donut can scratch a blob while it is
    being pushed.
- **Crash on closing with Intel's native OpenGL driver (found in Phase 10; avoided by default
  since Phase 11, not fixed).** With native OpenGL, about 1 real exit in 25 on this machine ended in
  an access violation (exit code `-1073741819` / `0xC0000005`, no Godot backtrace) *after* the game
  had shut down. Windows Error Reporting put every one in `igxelpicd64.dll` (Intel's OpenGL driver,
  version 31.0.101.4032, from 2022) at the same offset, on the title screen too and with the Phase 9
  code. That is still a driver/environment issue: neither the Intel driver nor Godot was changed
  or fixed. Since Phase 11 the project runs through ANGLE (Direct3D 11) on Windows by default, so a
  normal launch no longer uses that path; Phase 11's ANGLE stress runs gave **0 crashes in 234 real processes** (see
  Phase 11's validation record in `PROJECT_STATE.md` at commit `41c57f2`). Native OpenGL is still reachable for diagnosis
  (`--rendering-driver opengl3`) and would still show the crash. Updating the Intel driver was
  deliberately not done here (machine administration, outside the project). Nothing is lost if it
  happens: the game saves only on entering a floor, never at exit.
- **The old shared user-data folder is left as it was.** Until Phase 10 this project and `../codex`
  (same `config/name`) both used `%APPDATA%\Godot\app_userdata\Carl & Donut Dungeon Prototype\`.
  This project now uses `%APPDATA%\DC CARL\` and never looks at the old folder, so a save made
  before Phase 11 is not offered (by design; its `savegame.json` currently holds the codex
  project's format). To keep an old save of this game's own format, copy it by hand into
  `%APPDATA%\DC CARL\` (the game checks it like any save). `../codex` still uses the old folder;
  that is its own business (it was not changed).
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
- **Floors 3, 4, 5, 6 and 7 are small combat-test rooms.** Floor 7 has no exit ("Prototype: the way
  further down is not built yet."). The Floor Guardian, Dungeon Brute and prototype-complete
  exit (GAME_SPEC §14) are later work. Floor 5's penned blob goes for Donut as soon as she
  arrives (by design); a player who walks straight on leaves her to fight it alone.
- **The Floor 5 Bat pickup reappears after Continue if the save somehow owns the Bat on
  Floor 5** (only possible by editing the save), like the Slingshot on Floor 2. Walking over it
  then changes nothing.
- **The Floor 2 Slingshot pickup reappears after Continue if the save somehow owns it on
  Floor 2** (only possible by editing the save). Walking over it then changes nothing.
- **Save system scope (by design):** one slot; saves only on entering a floor or starting a
  new game, so quitting mid-floor loses that floor's progress (including a Slingshot or a
  Baseball Bat found there, or Blast Bombs dropped there); no cloud saves; no save-management UI beyond New Game's confirmation.
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
  - there is no invulnerability after a hit (a glob and a Blob's touch can land in the same
    moment); knockback exists only for the Bat (Phase 9);
  - camera limits are not set, and world-space signs can slide under the HUD at the top left;
  - hand-written scenes gain `unique_id` fields the first time the editor saves them.
- Godot's `--check-only -s <script>` reports "Identifier not found" for the scripts that
  name an autoload (`level.gd`, `title_screen.gd`, `save_manager.gd`), because it compiles
  the script before autoloads are registered. They compile fine in the game, the tests and
  the runtime load check. By design, this is not worked around.

## Manual verification required
Your save is `%APPDATA%\DC CARL\savegame.json` and your control settings will be
`%APPDATA%\DC CARL\settings.json` (created the first time you change a key). Nothing in Phase 13
created or changed either: the tests use `user://test_saves/`, and every game-mode run used a scratch
copy with its own folder.
1. Open the project in Godot 4.7.2 and let it import (three new scripts, one new scene). The Output
   panel should show no errors, and the renderer line should still mention **ANGLE**.
2. Run the game: the title shows **Continue / New Game / Settings / Quit Game**. Choose **Settings**:
   "Controls" lists Move Up … Inventory with Up, Down, Left, Right, W, A, S, D, Space.
3. Select **Action Slot W**, press Enter ("Press a key for Action Slot W"), press **Q**: the row says Q.
   Select **Inventory**, Enter, press **Q**: "Q is already assigned to Action Slot W." and Inventory
   stays Space. Enter then Escape changes nothing; Enter then Enter says Enter is reserved.
4. Rebind movement to **I/K/J/L** (Move Up = I, Move Down = K, Move Left = J, Move Right = L) and
   Inventory to **Tab**. Escape back to the title, Continue (or New Game).
5. In play: the arrows do nothing, I/J/K/L move Carl; the HUD reads "Q: …" for the W slot and "Tab:
   action menu"; Q uses whatever the W slot holds and W does nothing; Tab opens the menu, which says
   "(on Q)", and Q assigns the selected item to the W slot.
6. **Escape > Settings** (the game stays paused), change one key, Back, Resume: the new key works at
   once. Return to Title and quit the game; start it again: Settings still lists your keys.
7. **Settings > Reset to Defaults**: No keeps them; Yes restores the arrows, W/A/S/D and Space, and
   your save is untouched (Continue shows the same floor, HP and slots).
8. Optional: close the game, put a few random characters into `settings.json` and start it: the title
   says "Control settings could not be loaded. Defaults restored.", Continue still works, and the next
   change in Settings writes a good file.

## Next phase
Phase 14 is **not specified** here. Provide its prompt, with acceptance criteria, after Phase 13 is
reviewed. (Controller bindings, audio/graphics settings and Floor 8, possible next steps, were
deliberately not started.)

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
  `Projectile` scene and numbers; a new melee weapon is a `MeleeAttack` scene with its own
  numbers, knockback included (see "To add a weapon with its own knockback"); a reusable or
  consumable item is one `.tres` plus a line in `ActionRegistry`. Carl and the save format never
  change.
- **More reactions:** `Knockback` + `KnockbackReceiver` are the pattern. Carl or Donut could be
  made pushable by giving them a receiver (and making their scripts respect it); an enemy attack
  could push by setting its own knockback numbers. Neither is done yet.
- **More floors:** a new scene, stairs down from the previous floor (Floor 7 has none yet),
  and a line in `FloorRegistry`.
- **More drops:** a `LootDrop` child on any placed enemy (see "To make an enemy drop something").
  Random or weighted drops would extend `LootDrop` (for example a list of item/quantity/weight
  entries and one roll on death); the pickup, checkpoint and save sides would not change.
- **More area damage:** `AreaDamage` is reusable as it is (see "To add another area-damage item"):
  another explosive, a spell, or an enemy's blast on `player_hurtbox`.
- **Save format changes:** bump `SaveManager.SAVE_VERSION` to 4, add `_migrate_version_3()`,
  and chain the migrations in `decode()`.
- **More settings / controller bindings:** see Architecture > Settings and control bindings ("Adding
  a rebindable control later"). A new kind of setting is another block in `settings.json` with a
  `settings_version` bump and a migration in `SettingsManager.decode()`; the save never changes.
