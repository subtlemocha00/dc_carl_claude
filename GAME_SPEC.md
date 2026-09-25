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

Title screen: Up/Down choose between Continue, New Game and Quit Game (going round the options
on offer; Continue only when a save loads), Enter confirms. Continue is selected first when a
save loads, New Game otherwise, never Quit Game (section 15b).

Escape and Space by situation (canonical since Phase 10, section 15a):
- during play: Escape opens the pause menu; Space opens the action/inventory menu;
- in the action menu: Escape or Space closes it (and does nothing else: the same key press
  never opens the pause menu);
- in the pause menu: Escape resumes; Up/Down choose; Enter confirms; Space and W/A/S/D do
  nothing;
- in a pause-menu question: Escape means No;
- on the GAME OVER screen: Enter retries; Escape and Space do nothing.
At most one of the action menu, the pause menu and the GAME OVER screen is ever up.

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

Canonical since Phase 8 (these values replace the initial concept values above):
- Donut has **60 HP** (60 / 60 in a new run). Enemy attacks (a blob's touch, spit globs) can
  hurt her. Carl's attacks (Fists, Slingshot stones) never can: there is no friendly fire.
- Enemies may choose her as their target, like Carl (section 14a).
- **Scratch**, her one attack, is automatic (there is no key for it): when a living enemy is
  within about **42 px** of her, she scratches the nearest one for **10 damage**, at most once
  every **1.0 s**. She never leaves Carl to hunt enemies: following Carl always comes first.
- At 0 HP she is **DOWNED**, not dead: she lies still (greyed out, with a "DOWNED" label; the HUD
  says DOWNED too), does not follow or scratch, and enemies ignore her. After **6 seconds of
  play** she gets up with **30 / 60 HP** and carries on. The pause menu and GAME OVER stop that
  countdown. There is no revive key, and potions heal Carl only.
- Donut being downed never causes GAME OVER; only Carl reaching 0 HP does. Carl can take the
  stairs while she is downed: she arrives on the next floor downed and gets up 6 s later.
- Her HP carries over between floors (a floor transition does not heal her) and is part of the
  floor-entry checkpoint: a retry or Continue gives her back the HP she had on entering the
  floor (0 means she starts that floor downed, with a fresh 6 s).
- The player never controls Donut directly: no Donut keys, commands, action slots or
  equipment.

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
- Reusable items (the Slingshot; since Phase 9 the Baseball Bat) are found once and then owned.
  They have no quantity, are
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

The second reusable weapon is the **Baseball Bat** (stable id `baseball_bat`, canonical since
Phase 9), a melee weapon that knocks enemies back:
- a reusable item, found on Floor 5: once found it is owned, with no quantity (the menu and the
  HUD say "Baseball Bat"), and never used up. There is no ammunition;
- it can be put on any of W, A, S or D, in one slot at a time, next to Fists, the Slingshot and
  the potion;
- each use swings once in Carl's facing direction (the same facing as Fists and the Slingshot).
  Holding the key swings once every 0.75 s (its cooldown); a short press swings once;
- a swing covers a circle of 28 px radius centred 36 px in front of Carl: it reaches from 8 px to
  64 px in front of his centre, so it hits enemies in front of him (all of them in that area),
  never behind him. It never reaches through a wall: an enemy with a wall between it and Carl
  is not hit;
- each hit deals exactly 20 damage (two hits kill a 30 HP blob; Fists deal 10);
- knockback: an enemy it hits and does not kill is pushed 80 px in the direction of the swing,
  away from Carl, over 0.3 s (fast at first, then slowing). Walls stop the push: the enemy
  ends up against the wall, never in it or beyond it. While it is pushed it neither moves by
  itself nor attacks; then it carries on as before (chasing, keeping its distance, spitting at
  its usual pace). A killing hit does not push: the enemy dies where it stands;
- only enemies are knocked back. The Bat never hurts or pushes Carl or Donut. Fists, Slingshot
  stones, Donut's Scratch and enemy attacks do not knock back;
- a push freezes with everything else while the game is paused (the menu, GAME OVER) and is
  never saved.

## 10. Dungeon structure

Do not implement procedural generation for the three-floor prototype.

All three prototype dungeon floors should be manually authored scenes/layouts.

General progression:
Surface -> Floor 1 -> Floor 2 -> Floor 3 -> Prototype Complete screen.

Playable progression since Phase 9: Surface -> Floor 1 -> Floor 2 -> Floor 3 -> Floor 4 -> Floor 5
-> Floor 6. Floor 3 has stairs down to Floor 4, Floor 4 down to Floor 5 and Floor 5 down to Floor 6,
all manually authored combat-test floors (sections 14a, 14b and 14c); Floor 6 has no exit yet.
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
- (until Phase 8: ignored Donut;) since Phase 8, choose their target between Carl and Donut:
  when an enemy has no target it picks the nearest of the two within its detection range, and
  it keeps that target until the target is downed or farther than its chase range, then picks
  again the same way. It never flips between them just because the other one is a little
  closer. A downed Donut is never a target;
- freeze while the game is paused (the inventory menu, GAME OVER);
- since Phase 9, can be knocked back by the Baseball Bat (section 9): while pushed they do not
  move by themselves or attack; afterwards they go on as before, finding a new path from where
  they landed.

Gelatinous Blob: 30 HP, 55 px/s, notices Carl within 220 px, gives up beyond 320 px. Its touch
takes 10 HP, at most every 0.8 s. Since Phase 8 each touch hurts one party member, Carl or Donut
(the nearer one if it touches both).

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
- never hurts the Spitting Blob that spat it or any other enemy; never collects pickups or
  triggers stairs;
- since Phase 8 it hurts Donut the same way (10, once). It hits only the first of Carl and Donut
  in its way, so one standing in front shields the other; a downed Donut does not stop it.
The Spitting Blob treats Donut as it treats Carl when she is its target: it needs to see her,
keeps 180-280 px from her, and stops spitting at her once she is downed.

Floor 4 — Filtration Level: a walled room with one Gelatinous Blob and one Spitting Blob. A wall
between Carl's arrival point and the Blob makes it walk around; a second wall hides the
Spitting Blob at first, so it has to move before it can spit, and pillars give cover. Since
Phase 8 its only exit is the stairs down to Floor 5 in the far south-east corner; nothing leads
back up.

## 14b. Floor 5 — Holding Pens (canonical since Phase 8)

A walled companion-combat test room (stable id `floor_05`) with two Gelatinous Blobs and one
Spitting Blob, and walls and pillars for navigation and cover. One blob waits in a pen close to
where Donut arrives, farther from Carl, so it goes for Donut: she scratches it while it hurts
her. Carl leads the way toward the others, so they usually pick him. Nothing is scripted: all of
this is ordinary enemy targeting. Nothing leads back up.
Since Phase 9 Floor 5 also holds the **Baseball Bat** pickup, a short walk east of where Carl
arrives, and its only exit is the stairs down to Floor 6 in the far south-east corner.

## 14c. Floor 6 — Batting Cage (canonical since Phase 9)

A walled weapon/knockback test room (stable id `floor_06`, 36 × 20 tiles) with two Gelatinous
Blobs and one Spitting Blob. One blob waits just in front of a tall wall (the "backstop"), so
knocking it back with the Bat pushes it into the wall, where it stops; another waits in the
open south-west part of the room, where a push travels its full distance; the Spitting Blob is
east of the backstop, with a pillar for cover. Nothing is scripted. Floor 6 has no exit yet
(no Floor 7), and nothing leads back up to Floor 5.

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
  The Baseball Bat (Phase 9) works the same way: found after entering Floor 5, it is taken back
  by a Floor 5 retry or by quitting and continuing (pickup back, slot empty); once Carl enters
  Floor 6 with it, the Floor 6 checkpoint owns it, with its slot, for retries and Continue.

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
- Since Phase 8, saves are **version 3**: the checkpoint also holds Donut's HP on entering the
  floor (0 if she entered downed). Version 1 and version 2 saves still load, with Donut at full
  health (60 / 60), and become version 3 at the next checkpoint (Continue writes one at once).
  How far Donut's recovery countdown had got is never saved.
- Phase 9 keeps **version 3**: owning the Baseball Bat is one more id in the list of owned
  reusable items, not a new kind of saved data (like Floor 6, one more floor id). Knockback is
  never saved.
- Phase 10 keeps **version 3**: pausing adds nothing to the save. Whether the pause menu is
  open, what it has selected and its questions are never saved, and neither is anything else
  mid-floor.
- Phase 11 keeps **version 3**: the game's own user-data folder, the Windows renderer and the
  title's Quit Game add nothing to the save.
- No mid-floor saving, multiple save slots or cloud saves in the prototype.

Current-run state (what survives level changes during one playthrough, held in memory) is
separate from disk save data. A later SaveManager writes the needed parts of the run state
to disk; it does not replace it.

Persisted state should eventually include at least:
- current floor/checkpoint
- Carl's relevant health/state
- inventory
- action-slot assignments

## 15a. Pause menu, Return to Title and quitting (canonical since Phase 10)

- Escape during play opens the **pause menu**: Resume, Return to Title, Quit Game, with Resume
  selected each time it opens. Up/Down choose (wrapping round), Enter confirms, Escape resumes.
- While it is open the game is paused exactly as it is while the action menu is open: Carl
  cannot move or act, Donut, the enemies, projectiles and knockback stop, cooldowns and Donut's
  recovery countdown stop counting, and stairs and pickups do nothing. Resume carries on from
  that exact moment: nothing is reset, nothing fires, and no cooldown comes due early.
- The pause menu, the action menu and the GAME OVER screen are never up together: each opens
  only while the game is running.
- **Return to Title** and **Quit Game** first ask, with **No** selected:
  "Return to title? / Quit game? Progress since entering this floor will be lost." Up/Down
  choose, Enter confirms, Escape means No. No goes back to the pause menu, still paused.
- **Neither ever saves.** The save keeps the checkpoint written when Carl entered the floor.
  Everything since (HP lost, Donut's HP, items found or used, enemies killed) is dropped:
  Continue restores the floor-entry checkpoint, with the floor's enemies and pickups as authored.
- Return to Title goes back to the title screen in the same running game. The title describes
  the saved checkpoint (never the live floor that was left), and Continue and New Game work as
  from a fresh start, any number of times.
- Quit Game closes the game. Closing the window (or Alt+F4) does the same, without asking:
  nothing is saved, and the checkpoint is kept.

## 15b. The game's own data folder, the Windows renderer and the title's Quit Game (canonical since Phase 11)

- The game keeps its save (and Godot's logs) in **its own user-data folder, "DC CARL"**, for
  example `%APPDATA%\DC CARL` on Windows. Until Phase 11 it used Godot's default folder for its
  name, `Godot/app_userdata/Carl & Donut Dungeon Prototype`, which another project with the same
  name also used, so each could overwrite the other's save.
- The old folder is left exactly as it is. Nothing is moved, copied or imported from it (its
  save may be another project's, in another format), and the game never looks for saves outside
  its own folder. So the first launch after Phase 11 has no save: Continue is unavailable and
  New Game starts the game as usual.
- The save is still `user://savegame.json`; Godot decides where `user://` is.
- On Windows the Compatibility renderer runs through **ANGLE** (Direct3D 11) instead of the
  graphics driver's own OpenGL, because the native OpenGL driver on the development machine
  sometimes crashed as the game closed (Phase 10). Other platforms are unchanged. There is no
  graphics option for the player.
- The title screen has **Quit Game**: with a save that loads it offers Continue, New Game and
  Quit Game; otherwise New Game and Quit Game (Continue is shown unavailable). Quit Game closes
  the game at once, without asking, because nothing on the title screen can be lost: it saves
  nothing and changes nothing. It is never the first selection, so an Enter pressed as the title
  opens cannot close the game.

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
- floors 7–20 (Floor 4 was added in Phase 7, Floor 5 in Phase 8 and Floor 6 in Phase 9 as
  combat-test floors)
- achievements
- mod support
