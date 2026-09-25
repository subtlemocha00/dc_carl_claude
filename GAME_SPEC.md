# GAME SPECIFICATION
## Carl & Donut Dungeon Prototype

## 1. Product goal

Build a small but complete 2D top-down action dungeon crawler prototype for Windows PC.

The eventual prototype contains an introductory surface scene and three dungeon floors. It is intended to establish a maintainable baseline that can later grow to approximately 20 floors.

This project is a private learning/fan prototype. All game code, placeholder art, UI, dialogue, sound, and other created content must be original. Do not reproduce text, audiobook dialogue, official illustrations, logos, maps, music, or other copyrighted source material.

## 2. Premise

The protagonist is Carl, accompanied by his sentient pet cat:

**Grand Champion, Breed Winner Regional, National Winner Princess Donut the Queen Anne Chonk**

Use **Donut** as the normal in-game short name.

Carl and Donut begin on Earth's surface. An unseen alien/system voice informs them that they must enter a dungeon through a staircase in order to survive.

The prototype covers the surface introduction and Dungeon Floors 1–3.

## 3. Camera and presentation

- 2D top-down perspective.
- Smooth real-time movement.
- Camera primarily follows Carl.
- Placeholder visuals are expected during initial development.
- Prefer 32×32 environment tiles, but gameplay logic must not depend on a rigid movement grid.
- Initial reference resolution: 1280×720.
- The game must remain usable when resized.

## 4. Controls

Gameplay:
- Arrow Up: move north.
- Arrow Down: move south.
- Arrow Left: move west.
- Arrow Right: move east.
- W: action slot 1.
- A: action slot 2.
- S: action slot 3.
- D: action slot 4.
- Space: open/close inventory.
- Escape: pause/back/cancel as appropriate.
- Enter: confirm menu/inventory selection; on the GAME OVER screen, retry the current floor.

Title screen: Up/Down choose between Continue and New Game, Enter confirms.

Carl's facing direction is determined by his most recent non-zero movement direction.

W/A/S/D are never movement controls in this game. Movement is the arrow keys only.

The W/A/S/D keys themselves are fixed. What each of the four slots holds is the player's
choice, changed through the in-game inventory/action menu (section 7). Rebinding the
physical keys is a separate, future settings concern.

## 5. Carl

Carl is the player-controlled character.

Initial target attributes, subject to later tuning:
- Max HP: 100
- Move speed: approximately 180 px/s
- Four action slots mapped to W/A/S/D.
- Starts a new game with Fists in D and slots W, A and S empty.

Carl reaching 0 HP causes the game-over state:
- gameplay freezes: Carl cannot move or act, and Donut and the enemies stop;
- the GAME OVER screen stays up. It never restarts or disappears on a timer;
- pressing Enter retries the current floor from the state captured when Carl entered it
  (section 15).

## 6. Donut

Donut is an AI-controlled companion.

Initial behavior:
- Automatically follows Carl.
- Tries to remain roughly 50–100 px from Carl when possible.
- Must not be implemented as a child node that mechanically inherits Carl's movement.
- Should navigate sensibly around level geometry.
- Automatically detects and attacks nearby hostile enemies.
- Initial conceptual detection range: ~250 px.
- Initial conceptual attack range: ~180 px.
- Initial conceptual attack cooldown: ~1.25 s.
- Initial attack may be a simple original magical/ranged projectile.

Donut can take damage.

At 0 HP:
- Donut is stunned/disabled for approximately 5 seconds.
- She cannot attack while stunned.
- She then recovers with partial health.
- Donut reaching 0 HP does not end the game.

Exact combat values may be tuned later.

Current state (Phase 7): Donut's combat, damage and stun are not built yet. Until they are, she
cannot be hurt: enemies never target her, and neither enemy attacks (touch, spit) nor Carl's
attacks affect her.

## 7. Combat and action slots

W/A/S/D are four hot-action slots.

The player can assign usable inventory items/actions to these slots through the inventory UI.
An action sits in one slot at a time: assigning it to another slot empties its old slot.
An empty slot does nothing when its key is pressed.
A slot can only hold something Carl has. When the last of a consumable is used up, its slot
becomes empty; a newly found one must be assigned again.

Examples:
- W = Steel Pipe
- A = Rock
- S = Health Potion
- D = Stun Wand

Weapons/actions normally act in Carl's current facing direction unless the specific item's design says otherwise.

The item architecture must be data-driven. Item behavior must not be implemented as a growing monolithic chain of `if item_name == ...` checks.

Conceptual reusable item properties may include:
- id
- display_name
- description
- icon
- item_type
- damage
- range
- cooldown
- attack_type
- projectile_speed
- knockback
- stackable
- max_stack
- quantity/charges where appropriate

Do not over-engineer the initial item framework merely to satisfy every hypothetical future item.

## 8. Inventory

Space opens/closes inventory.

Opening the inventory pauses active gameplay.

Keyboard-only navigation is required:
- Up/Down: move selection.
- Left/Right: navigate submenus/slot choices as appropriate.
- Enter: confirm.
- Escape: go back/cancel.
- Space: close inventory.

From an inventory item, the player must eventually be able to choose Equip and assign the item to W, A, S, or D.
The first version of this menu assigns directly: select an action with Up/Down, then press
W, A, S or D to put it in that slot. Escape also closes the menu.

Inventory contents:
- Innate actions (Fists) are always available, have no quantity and are never used up.
- Reusable items (the Slingshot) are found once and then owned. They have no quantity, are
  never used up, and the menu and the HUD show only their name. Finding one Carl already
  owns changes nothing.
- Consumables have a quantity, shown in the menu and the HUD (for example "x2"). A consumable
  whose quantity reaches 0 leaves the inventory.
- Items are found as pickups in levels. Carl collects one by walking over it; there is no
  interaction key. Donut and enemies never collect pickups.

HUD must eventually show all four action slots and their assigned items.

## 9. Example prototype items

Planned prototype pool:
- Fists — default/basic melee.
- Steel Pipe — melee.
- Rock — projectile or throwable.
- Health Potion — consumable.
- Stun Wand — ranged/special.
- Bomb — throwable/AOE.
- Heavy Hammer — slow melee.
- Strange Alien Device — Floor 3 special item.

These are baseline design targets, not a demand to implement all items in early phases.

The health potion is implemented as the **Small Health Potion**:
- a consumable;
- it heals 30 HP, never above Carl's maximum;
- each use that heals spends exactly one;
- using it at full HP does nothing and spends nothing.

The first ranged weapon is the **Slingshot** (stable id `slingshot`):
- a reusable item, found on Floor 2: once found it is owned, with no quantity, and never used
  up. There is no ammunition;
- it can be put on any of W, A, S or D;
- each use fires one stone in Carl's facing direction. Holding the key fires once every
  0.6 s (its cooldown); a short press fires once;
- a stone deals 10 damage to the first enemy it hits and disappears. It never hits more than
  one enemy;
- a stone stops at walls and solid obstacles, so nothing behind them is hit. It flies at
  480 px/s and disappears after 320 px (10 tiles);
- stones never hurt Carl or Donut, never collect pickups and never trigger stairs. Like
  everything else in play, they freeze while the game is paused.

## 10. Dungeon structure

Do not implement procedural generation for the three-floor prototype.

All three prototype dungeon floors should be manually authored scenes/layouts.

General progression:
Surface -> Floor 1 -> Floor 2 -> Floor 3 -> Prototype Complete screen.

Playable progression since Phase 7: Surface -> Floor 1 -> Floor 2 -> Floor 3 -> Floor 4. Floor 3
has stairs down to Floor 4, a manually authored combat-test floor (section 14a) with no exit yet.
The Floor 3 Guardian and the Prototype Complete screen are still to come.

Progression is downward only. Once Carl descends, he can never return to the Surface or to a
shallower floor. Levels have no stairs, exits or triggers that lead back up. This is a design
rule, not a missing feature. Tests and development tools may still load any level scene
directly.

Level/floor metadata should nevertheless be data-driven enough that Floors 4–20 can later be added without rewriting the core game loop.

A floor definition may eventually contain:
- floor number
- display name
- scene reference/path
- allowed enemy types
- loot configuration
- difficulty parameters
- music/audio references
- other floor-specific metadata

Avoid hardcoding the entire game around `if floor == 1`, `elif floor == 2`, etc.

## 11. Surface

Purpose:
- Start the game.
- Establish Carl and Donut.
- Allow the player to learn movement.
- Provide a staircase/transition into Floor 1.

Keep initial story presentation minimal and original.

## 12. Floor 1 — Maintenance Level

Purpose:
- Teach basic gameplay.

Target:
- 4–6 rooms with connecting corridors.
- Simple stone/concrete visual language.
- Exit stairs at the far end.

Initial enemies:
- Dungeon Rat: fast, weak, melee.
- Gelatinous Blob: slow, tougher, contact/melee.

Concepts introduced:
- movement
- basic combat
- Donut combat
- health/damage
- pickups
- inventory
- assigning/equipping an item

Target playtime later: roughly 5–8 minutes.

## 13. Floor 2 — Utility Level

Reuses previous enemy types and introduces:
- Spitter: ranged enemy that attempts to maintain distance.
- Crawler: fast aggressive pursuer.

May introduce:
- ranged combat pressure
- environmental hazards
- more complex room geometry
- more consumables
- mixed enemy encounters

Possible hazard:
- periodically electrified floor panel.

Target playtime later: roughly 8–12 minutes.

## 14. Floor 3 — Processing Level

May use all previous enemies.

Introduces:
- Dungeon Brute: slow, high HP, heavy melee.

Boss/miniboss:
- Floor Guardian.

Floor Guardian should eventually have three recognizable behaviors:
- chase
- charge
- area-of-effect slam

Defeating the Guardian unlocks the final exit.

Final exit leads to a prototype-complete screen that communicates that Carl and Donut survived the first three floors and that additional floors remain outside the prototype.

## 14a. Enemy behaviour and Floor 4 (canonical since Phase 7)

All enemies:
- notice Carl by distance (their detection range), not through the whole floor, and give up
  when he is farther away than their chase range;
- move along the level's navigation mesh, so they walk around walls to reach him instead of
  getting stuck behind them. They never pass through walls;
- ignore Donut: they never target her, and nothing they do can hurt her;
- freeze while the game is paused (the inventory menu, GAME OVER).

Gelatinous Blob: 30 HP, 55 px/s, notices Carl within 220 px, gives up beyond 320 px. Its touch
takes 10 HP, at most every 0.8 s.

**Spitting Blob** (stable id `spitting_blob`), the prototype's first ranged enemy (the Spitter
of section 13, placed on Floor 4 for now):
- 30 HP (three Slingshot stones), 60 px/s. No touch attack: its threat is its spit;
- notices Carl within 360 px and gives up beyond 480 px;
- spits only when Carl is within 320 px and in plain sight: a wall between them blocks its view.
  A hidden Carl makes it walk around the wall until it sees him again. It never spits at a wall;
- keeps 180-280 px away: it closes in when he is farther and backs off when he is closer;
- spits at most once every 1.5 s, straight at where Carl is at that moment (no leading).

Spit glob (the Spitting Blob's projectile, the same kind of projectile as the Slingshot stone):
- 10 damage to Carl, once, then it disappears; 240 px/s; gone after 384 px;
- stopped by walls, so Carl can take cover;
- never hurts Donut, the Spitting Blob that spat it or any other enemy; never collects pickups
  or triggers stairs.

Floor 4 — Filtration Level: a walled room with one Gelatinous Blob and one Spitting Blob. A wall
between Carl's arrival point and the Blob makes it walk around; a second wall hides the
Spitting Blob at first, so it has to move before it can spit, and pillars give cover. Floor 4
has no stairs yet, and no way back up.

## 15. Saving/checkpoints

Initial save design:
- Save/checkpoint at floor transitions.
- Do not save after every pickup.
- Restart Floor reloads the state captured on entering that floor.
  Retrying after GAME OVER does this. Carl's HP returns to what he had on entering the
  floor, and the floor's enemies start over. The action-slot layout stays as the player
  last set it.
  Carl's inventory also returns to what he had on entering the floor:
  - items picked up since are taken back, and their pickups are back in the level;
  - items used since are returned;
  - a slot holding an item Carl no longer has becomes empty;
  - a slot that is empty at the retry gets back what it held on entering the floor, if Carl
    has that item again (for example a potion slot that emptied when the last potion was drunk).
  Retrying never creates extra items.
  Reusable items follow the same rule. A Slingshot found after entering Floor 2 is taken back
  by a Floor 2 retry (its pickup is back, and its slot empties). Once Carl enters Floor 3
  with it, it is part of the Floor 3 checkpoint and a retry keeps it, with its slot.

Persistent save (canonical since Phase 5):
- There is one save slot, holding one floor-entry checkpoint: the floor Carl last entered,
  and his HP, inventory (consumable quantities and owned reusable items) and slot
  assignments at that moment.
- It is written when a new game starts on the Surface and each time Carl enters a floor.
  Nothing during play writes it: not damage, pickups, potions or death. Death never saves
  progress.
- Continue on the title screen resumes at the start of the saved floor with exactly that
  state (Floor 2 saves continue on Floor 2). The floor's enemies and pickups are as authored.
  Nothing mid-floor is saved: not positions, enemies, collected pickups or cooldowns.
- New Game asks for confirmation when a save file exists, because its first checkpoint
  replaces the save.
- A save that is corrupt, from an unsupported version, or otherwise invalid is never loaded:
  Continue is unavailable, and New Game still works. Invalid slot assignments inside an
  otherwise valid save are emptied.
- The save format has a version number. A save from an older version the game still
  supports is upgraded when it is loaded, and keeps its progress. (Since Phase 6, saves are
  version 2. Version 1 saves from Phase 5 load with the same floor, HP, potions and slots, and
  no Slingshot.) The version only changes when the saved data changes: adding a floor, such as
  Floor 4 in Phase 7, keeps version 2.
- No mid-floor saving, multiple save slots or cloud saves in the prototype.

Current-run state (what survives level changes during one playthrough, held in memory) is
separate from disk save data. A later SaveManager writes the needed parts of the run state
to disk; it does not replace it.

Persisted state should eventually include at least:
- current floor/checkpoint
- Carl's relevant health/state
- inventory
- action-slot assignments

## 16. HUD

Eventually display:
- Carl HP.
- Donut HP/state.
- Floor number/name.
- W/A/S/D action slots and assigned items/counts.

No minimap is required for the initial prototype.

## 17. Placeholder visuals

Early builds should intentionally use simple original placeholders.

Examples:
- Carl: blue placeholder character.
- Donut: orange cat-like placeholder.
- Rat: grey.
- Blob: green.
- Spitter: purple.
- Crawler: yellow.
- Brute: red.
- Boss: larger/darker placeholder.

Simple procedural shapes or original placeholder SVG/PNG assets are acceptable.

Do not spend significant implementation effort on polished art before the mechanics are stable.

## 18. Explicitly out of scope for the initial three-floor prototype

Do not implement unless the user later expands scope:
- procedural dungeon generation
- multiplayer/networking
- online accounts
- Steam integration
- controller support
- skill trees
- crafting
- quest system
- dialogue trees
- character creator
- advanced animation framework
- separate full inventory for Donut
- randomized item affixes
- advanced lighting/rendering
- voice acting
- floors 5–20 (Floor 4 was added in Phase 7 as a combat-test floor)
- achievements
- mod support
