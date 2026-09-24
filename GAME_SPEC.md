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
- Enter: confirm menu/inventory selection.

Carl's facing direction is determined by his most recent non-zero movement direction.

W/A/S/D are never movement controls in this game.

## 5. Carl

Carl is the player-controlled character.

Initial target attributes, subject to later tuning:
- Max HP: 100
- Move speed: approximately 180 px/s
- Four action slots mapped to W/A/S/D.
- Starts with Fists in W and the other three slots empty.

Carl reaching 0 HP causes the game-over state.

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

## 7. Combat and action slots

W/A/S/D are four hot-action slots.

The player can assign usable inventory items/actions to these slots through the inventory UI.

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

## 10. Dungeon structure

Do not implement procedural generation for the three-floor prototype.

All three prototype dungeon floors should be manually authored scenes/layouts.

General progression:
Surface -> Floor 1 -> Floor 2 -> Floor 3 -> Prototype Complete screen.

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

## 15. Saving/checkpoints

Initial save design:
- Save/checkpoint at floor transitions.
- Do not save after every pickup.
- Restart Floor reloads the state captured on entering that floor.

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
- floors 4–20
- achievements
- mod support
