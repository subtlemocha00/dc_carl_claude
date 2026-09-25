# ACCEPTANCE TESTS

This file defines cumulative acceptance criteria.

A coding model should check the section for the current phase and all relevant prior phases.

# Phase 0 — Project Foundation

Required:
- [ ] Project targets Godot 4.7.x and opens successfully in Godot 4.7.2 stable.
- [ ] Project is a 2D Godot project using GDScript.
- [ ] Project has a clear main scene.
- [ ] Running the project presents a simple placeholder title/start screen or foundation scene rather than an empty/error state.
- [ ] Reference viewport is configured sensibly for 1280×720.
- [ ] Basic stretch/window behavior is configured.
- [ ] Core input actions exist in InputMap for arrows, W/A/S/D, Space, Enter, and Escape.
- [ ] Arrow keys are reserved for movement actions.
- [ ] W/A/S/D are reserved for action-slot actions.
- [ ] Initial project folders are sensible and not over-engineered.
- [ ] `.godot/` is ignored by Git.
- [ ] `PROJECT_STATE.md` accurately describes the resulting foundation.
- [ ] No gameplay systems from later phases have been unnecessarily implemented.
- [ ] No parser/import errors are present.
- [ ] Git working tree is clean after the phase commit, if committing is supported in the environment.

# Phase 1 — First Traversal Slice

Required:
- [ ] Starting the game reaches the Surface scene.
- [ ] Carl is visibly distinguishable from the environment.
- [ ] Arrow keys move Carl smoothly.
- [ ] W/A/S/D do not move Carl.
- [ ] Carl has collision and cannot walk through solid boundaries.
- [ ] Carl remembers/faces the last movement direction.
- [ ] Camera follows Carl appropriately.
- [ ] Donut is visibly distinguishable from Carl.
- [ ] Donut follows Carl automatically rather than being rigidly attached to him.
- [ ] Donut does not permanently get stuck during the provided Surface traversal.
- [ ] Surface contains a staircase/transition trigger.
- [ ] Entering the staircase transitions to Floor 1.
- [ ] Floor 1 loads successfully with Carl and Donut present.
- [ ] Returning/transition behavior is not required unless explicitly added to Phase 1.
- [ ] No combat, inventory, enemies, loot, or save system is required yet.
- [ ] No parser/runtime errors occur during the normal Surface -> Floor 1 test.
- [ ] `PROJECT_STATE.md` is updated.

# Phase 3 — Action Slots, Action Menu and Run State

Design corrections (these override anything earlier phases said or built):
- Fists start in slot **D**. W, A and S start empty.
- W/A/S/D are configurable action slots. Movement is the arrow keys only.
- Players change what each slot holds in the in-game menu. Physical key rebinding is a
  separate, future concern.
- Dungeon progression is downward only: no stairs or triggers lead back up.
- GAME OVER freezes the game and waits for Enter. It never restarts on a timer.

Required:
- [ ] Arrow keys move Carl; W/A/S/D never move him, whether their slot is empty or not.
- [ ] A new game shows W: empty, A: empty, S: empty, D: Fists.
- [ ] D punches in Carl's facing direction by default; W, A and S do nothing.
- [ ] Carl uses whatever action a slot holds; no key is hard-wired to Fists.
- [ ] Space opens the menu; Space or Escape closes it.
- [ ] While the menu is open, the game is paused: Carl cannot move or attack, Donut stops,
      and enemies cannot move or deal damage.
- [ ] In the menu, Up/Down select an action and W/A/S/D put it in that slot. An action is
      in one slot at a time.
- [ ] After moving Fists to another slot, that slot punches and the old one does not,
      without restarting anything. Moving it again also works.
- [ ] The HUD shows all four slots and updates as soon as an assignment changes.
- [ ] Opening or closing the menu never produces a free attack or step, even if a key
      pressed in the menu is still held when it closes.
- [ ] The menu cannot be opened over GAME OVER.
- [ ] Slot assignments and Carl's HP survive going down a level.
- [ ] Each level records a floor-entry state when it starts.
- [ ] GAME OVER stays on screen until Enter; Enter retries the current floor.
- [ ] A retry restores the HP Carl had on entering the floor (not full health), puts the
      floor's enemies back, and keeps the player's current slot layout.
- [ ] Floor 1 has no way back to the Surface, and arriving on a level never triggers a
      transition loop.
- [ ] A new game resets the run state (full HP, Fists in D).
- [ ] The HUD, GAME OVER screen and menu fit on screen at 1280×720, 640×360 and 1024×768.
- [ ] `PROJECT_STATE.md` and `GAME_SPEC.md` describe the corrected design.

# Phase 4 — Inventory, World Loot, Consumable Action and Floor 2

The Phase 3 control model and design corrections still apply (arrow keys move; W/A/S/D are
configurable slots with Fists on D in a new game; downward-only; GAME OVER waits for Enter).

Required:
- [ ] One current-run inventory holds every quantity. The HUD, menu and pickups only read it
      or change it through its methods.
- [ ] Fists are innate: always available, no quantity, never used up, still assignable.
- [ ] A new run has 0 Small Health Potions, W/A/S empty and D = Fists.
- [ ] Floor 1 has a Small Health Potion pickup. Walking over it gives exactly 2 potions,
      once, and it disappears. Donut and enemies cannot collect it.
- [ ] The menu lists "Small Health Potion x2" only after the pickup, and the potion can be
      put on W, A, S or D. It is in one slot at a time, and Fists can stay on another key.
- [ ] The potion is used through the same slot dispatch as Fists. It heals 30 HP, capped at
      the maximum, and each successful use spends exactly one.
- [ ] At full HP the potion does nothing and is not used up. One short key press uses at
      most one potion.
- [ ] The HUD shows quantities (for example `A: Potion x2`), and the HUD and menu update
      after every use.
- [ ] Using the last potion removes it from the inventory and empties its slot.
- [ ] Floor 1 has stairs down to Floor 2. Inventory quantities and slot assignments survive
      the trip, and Carl and Donut arrive together on Floor 2 without a transition loop.
- [ ] Floor 2 is a playable, walled level with a clear "Floor 2" sign, the HUD and the menu.
      Nothing on Floor 2 leads to Floor 1, and nothing on Floor 1 leads to the Surface.
- [ ] The floor-entry state includes the inventory. A retry restores it: items picked up
      since entry are taken back and their pickup is back in the level, and items used
      since entry are returned.
- [ ] Retrying (any number of times) never duplicates items. A slot holding an item that
      the retry took back becomes empty.
- [ ] GAME OVER still freezes the game, blocks the menu, and waits for Enter.
- [ ] The HUD and the menu with a potion fit at 1280×720, 640×360 and 1024×768.
- [ ] No disk saving, Floor 3, new enemy species or Donut combat were added.

# Phase 5 — Persistent Save/Load and Continue

The Phase 3–4 rules still apply. The save uses the same floor-entry checkpoint as GAME OVER retry.

Required:
- [ ] One save file in `user://` (not in the repository) holds the checkpoint of the floor
      Carl last entered: floor id, HP, item quantities and W/A/S/D assignments, with a
      save-format version. It stores stable ids only.
- [ ] `SaveManager` does all file I/O. `GameState` stays in-memory run state.
- [ ] Writes go to a temporary file that is checked and then renamed over the old save; an
      old save is never deleted before the new one is complete.
- [ ] The checkpoint is written when a new game starts (Surface) and on entering each floor.
      Nothing else writes it: not damage, pickups, potion use, slot changes or death.
- [ ] Title screen: Up/Down + Enter. Continue is available only when the save loads.
      Otherwise it is shown unavailable, and a message appears if a save file exists but
      cannot be loaded.
- [ ] Continue restores the saved floor directly (Floor 2 saves continue on Floor 2), with
      the checkpoint HP, inventory and valid slots. Donut, enemies and pickups are as authored.
- [ ] New Game starts a clean run: 100 HP, no items, D = Fists, the Surface. It asks for
      confirmation (No selected) when a save file exists; No and Escape keep the old save.
- [ ] Malformed JSON, unsupported versions, missing fields, unknown floors, bad HP, negative
      or non-integer quantities, unknown or innate items and wrong slot structures are
      rejected without a crash. Unknown or unavailable slot actions are emptied.
- [ ] Deleting the save is safe when there is none.
- [ ] Death never writes the save. GAME OVER still waits for Enter. The retry restores the
      in-memory checkpoint, and a later Continue restores the same one.
- [ ] Fixed Phase 4 issue: entering a floor with A = potion x1, drinking it (A empties during
      play), then dying and retrying gives back the potion and A = potion.
- [ ] Traversal stays downward-only (Surface → Floor 1 → Floor 2). Floor 2 is still the
      deepest floor.
- [ ] Tests use their own save files, never the player's save.
- [ ] A real process restart continues correctly, a corrupt save leaves the title usable,
      and the title screen fits at 1280×720, 640×360 and 1024×768.

# Phase 6 — Reusable Weapon, Projectile Combat, Save Migration and Floor 3

The Phase 3–5 rules still apply (arrow keys move; W/A/S/D are configurable slots with Fists on
D in a new game; downward-only; GAME OVER waits for Enter; one floor-entry checkpoint).

Required:
- [ ] The action/inventory model has three explicit kinds: innate (Fists: always there, no
      quantity), owned reusable items (Slingshot: found once, no quantity, never used up) and
      consumables (Small Health Potion: counted). No code checks item ids to tell them apart.
- [ ] A new game owns no Slingshot. Floor 2 has one Slingshot pickup. Walking over it owns the
      Slingshot exactly once, and the pickup disappears. Donut and enemies cannot collect it.
- [ ] The menu and the HUD show "Slingshot", never "Slingshot x1". It can only be assigned once
      owned; it can go on W, A, S or D, is in one slot at a time, and sits next to Fists and
      the potion.
- [ ] Its key fires one stone in Carl's facing direction through the normal slot dispatch
      (slot → action → launcher → projectile). Carl's script has no Slingshot code.
- [ ] A stone deals exactly 10 damage to the first enemy it hits, then disappears. Three hits
      kill a 30 HP Gelatinous Blob. It never hits two enemies.
- [ ] Walls stop stones; an enemy behind a wall is not hit. A stone disappears after 320 px.
- [ ] Stones never hurt Carl or Donut, never collect pickups, never trigger stairs.
- [ ] Cooldown 0.6 s: a short press fires once, holding fires every 0.6 s, taps cannot fire faster.
      Using the Slingshot never changes the inventory or its HUD label.
- [ ] While the menu is open nothing fires and stones in flight freeze; they fly on when it
      closes. Opening or closing the menu never fires a stone, even with a key held.
- [ ] Floor 2 has stairs down to Floor 3. Floor 3 is a playable, walled level with a "Floor 3"
      sign, the HUD, the menu, Gelatinous Blobs and a wall where stones can be seen to stop.
      Carl and Donut arrive together without a transition loop. Floor 3 has no exits.
- [ ] Nothing leads up: not Floor 1 → Surface, Floor 2 → Floor 1 or Floor 3 → Floor 2.
- [ ] A Slingshot collected on Floor 2 is not in the Floor 2 checkpoint. Dying there (or
      quitting and continuing) takes it back: not owned, pickup back, its slot empty. Repeated
      retries never duplicate it.
- [ ] Entering Floor 3 with it puts it (and W = Slingshot) in the Floor 3 checkpoint. A Floor 3
      retry and Continue both keep it on W, and it fires.
- [ ] The save is `save_version: 2` and stores owned reusable items as a list of stable ids
      (`owned_items`), never as a quantity. `floor_03` is a known floor.
- [ ] Version 1 (Phase 5) saves still load: floor, HP, potions and slots are kept, with no
      Slingshot. Loading never changes the file; the next checkpoint rewrites it as version 2.
- [ ] Malformed version 1 or 2 data, unsupported versions (0, 3, 999) and unknown, consumable,
      innate or duplicate owned items are rejected safely. A Slingshot slot without owning the
      Slingshot is emptied.
- [ ] New Game clears the Slingshot: no items, W/A/S empty, D = Fists, the Surface.
- [ ] HUD, menu, Slingshot pickup, stones, Floor 3 signs and the title fit at 1280×720, 640×360
      and 1024×768.
- [ ] No ammunition, other weapons, equipment stats, Floor 4, new enemy species, Donut combat or
      enemy-AI rewrite were added.

# Phase 7 — Enemy Navigation, Ranged Enemy Combat and Floor 4

The Phase 3–6 rules still apply (arrow keys move; W/A/S/D are configurable slots with Fists on
D in a new game; downward-only; GAME OVER waits for Enter; one floor-entry checkpoint; Donut
cannot be hurt).

Required:
- [ ] Enemies share one navigation component (`EnemyNavigation`, a NavigationAgent2D on the
      level's baked navigation mesh) and one small base (`Enemy`). No level script chooses
      behaviour by enemy type.
- [ ] The Gelatinous Blob still waits until Carl is within 220 px and gives up beyond 320 px.
      With a wall between them and a way around, it walks around the wall and reaches him; it
      never overlaps a wall, never stalls on the way, and its touch still takes 10 HP every
      0.8 s. With no way around, it stops next to the wall without jittering.
- [ ] One new enemy, the Spitting Blob (id `spitting_blob`): 30 HP, visibly different from the
      Gelatinous Blob (purple, spiky, with a spout). It notices Carl within 360 px, gives up
      beyond 480 px, keeps 180–280 px away, and has no touch attack.
- [ ] It spits only at a Carl within 320 px with no wall between them (a ray on the `world`
      layer). Hidden behind a wall, it spits nothing (no glob wasted on the wall) and walks around
      the wall until it sees him; then it spits again at once.
- [ ] Its glob reuses the Phase 6 projectile: a `Projectile` fired by a `ProjectileLauncher`.
      10 damage to Carl, exactly once, then gone; 240 px/s; gone after 384 px; stopped by walls
      (Carl behind a wall is safe). It never hurts Donut, the blob that spat it, or any other
      enemy, never collects pickups and never triggers stairs.
- [ ] One glob per shot, exactly 1.5 s apart while Carl stays in sight; coming back into sight
      after hiding gives one glob, not a burst.
- [ ] Carl's weapons still work: each Slingshot stone takes exactly 10 HP (three kill a
      Spitting Blob or a Gelatinous Blob); Fists hit either enemy only in Carl's facing
      direction; stones stop at walls and never hurt Carl or Donut.
- [ ] While the action menu is open, both enemies stand still, nothing is spat, and globs and
      stones in flight freeze. Closing it resumes them, with no free glob, no burst of saved-up
      cooldown and no free stone.
- [ ] Globs can take Carl to 0 HP. GAME OVER then freezes the enemies and any glob in flight,
      nothing more is spat, and it waits for Enter. The retry brings back Floor 4's entry state
      and its enemies as authored, with no globs left.
- [ ] Floor 3 has stairs down to Floor 4. Floor 4 (`floor_04`) is a walled level with a "Floor 4"
      sign, the HUD, the menu, one Gelatinous Blob and one Spitting Blob, and walls that make
      navigation and line of sight matter. Carl and Donut arrive together without a transition
      loop. Floor 4 has no exits.
- [ ] Nothing leads up: not Floor 1 → Surface, Floor 2 → Floor 1, Floor 3 → Floor 2 or
      Floor 4 → Floor 3.
- [ ] Entering Floor 4 records and saves its checkpoint (HP, potions, Slingshot, slots).
      Continue opens Floor 4 directly with exactly that state and its enemies as authored.
      Enemy HP and positions, globs, cooldowns and navigation are never saved.
- [ ] `floor_04` is in `FloorRegistry`; unknown floors (such as `floor_05`) are rejected. The
      save stays `save_version: 2` (Floor 4 adds no new kind of saved data). Phase 6 version 2
      saves and Phase 5 version 1 saves still load; other versions are rejected.
- [ ] New Game still starts clean on the Surface (100 HP, no items, D = Fists), after asking.
- [ ] The Spitting Blob, its globs, Carl's stones, the Floor 4 signs, the HUD, the menu, GAME
      OVER and the title fit and are visible at 1280×720, 640×360 and 1024×768.
- [ ] No Donut combat or HP, bosses, Floor 5, other new enemies, ammunition, new weapons,
      procedural spawning or save-slot changes were added.

# Phase 8 — Donut Health, Companion Combat, Enemy Targeting, Save v3 and Floor 5

The Phase 3–7 rules still apply (arrow keys move Carl; W/A/S/D are Carl's configurable slots
with Fists on D in a new game; downward-only; GAME OVER waits for Enter; one floor-entry
checkpoint). Donut stays AI-controlled: no new keys, commands, slots or equipment.

Required:
- [ ] Donut has 60 / 60 HP in a new run, through the shared Health and Hurtbox (her Hurtbox on
      the player's side, player_hurtbox). Enemy attacks hurt her; her HP never goes below 0.
- [ ] Carl's Fists and Slingshot stones never hurt Donut (no friendly fire); her Scratch never
      hurts Carl or herself; enemy attacks never hurt enemies.
- [ ] The HUD shows "Carl HP: x / 100" and "Donut HP: y / 60", and "Donut HP: 0 / 60 - DOWNED"
      when she is downed, with the W/A/S/D bar still readable, at 1280×720, 640×360 and 1024×768.
- [ ] Enemies pick the nearest valid party member (Carl or Donut) within their detection range,
      keep that target while it stays valid and within their chase range (no flipping between
      them at small distance changes), and pick again when it is downed or out of range. A
      downed Donut is never a target; once she gets up she can be picked again.
- [ ] The Gelatinous Blob (30 HP, 55 px/s, 220/320 px, 10 every 0.8 s) navigates around walls to
      Donut as to Carl, and each touch hurts one party member (the nearer one).
- [ ] The Spitting Blob (Phase 7 numbers unchanged) picks Donut, needs to see her (a wall blocks
      its view and its globs), keeps 180–280 px from her, and stops spitting at her once she is
      downed. It still spits at Carl as before.
- [ ] Globs deal 10 to Carl or Donut, only the first of them in the way, once; walls stop them;
      a downed Donut does not stop them; they never hurt the enemy that spat them or others.
- [ ] Scratch: automatic, 10 damage to the nearest enemy within about 42 px, at most once per
      1.0 s; never with no enemy near; Donut never walks toward enemies, only after Carl.
- [ ] At 0 HP Donut is DOWNED: visibly (grey, on her side, DOWNED label); she stops following and
      scratching; more hits do nothing; there is no GAME OVER. After exactly 6 s of play she gets
      up with 30 / 60, looks normal, follows Carl, scratches and can be targeted again. The
      menu and GAME OVER stop the countdown; there is no revive key; potions heal Carl only.
- [ ] Carl reaching 0 HP is GAME OVER whatever Donut's state; Donut reaching 0 is not. GAME OVER
      freezes Donut and her countdown and waits for Enter.
- [ ] Donut's HP carries over between floors unhealed and is part of the floor-entry state. A
      retry and Continue restore her floor-entry HP; 0 starts her downed with a fresh 6 s. No
      stairs lock while she is downed: she arrives downed and gets up 6 s later.
- [ ] Save format version 3 stores Donut's HP ("donut": {"health", "max_health"}), validated
      (whole numbers, 0 ≤ health ≤ max, max 1–1000; a v3 save without it is rejected). Phase 5
      (v1) and Phase 6/7 (v2) saves still load, with Donut at 60 / 60, and become v3 at the next
      checkpoint. Unsupported versions are rejected. The recovery countdown is never saved.
- [ ] New Game resets Donut to 60 / 60, not downed; nothing from an old run leaks in.
- [ ] Floor 4 has stairs down to Floor 5 (`floor_05`, in FloorRegistry): signs, HUD, menu, two
      Gelatinous Blobs and a Spitting Blob, walls, safe arrival, a checkpoint on entry, Continue
      straight into it. Floor 5 has no exits; nothing leads up from any floor.
- [ ] Tests and tools can never read or write the player's save: SaveManager refuses, with an
      error, any file outside user://test_saves/ in a test or tool run.
- [ ] No Donut controls, commands, slots or equipment, permanent Donut death, Donut items or
      potion targeting, bosses, Floor 6, other enemy species, new weapons, ammunition, stair
      locking or other Phase 9+ features were added.

# Phase 9 — Second Reusable Weapon, Knockback, Combat Reactions and Floor 6

The Phase 3–8 rules still apply (arrow keys move Carl; W/A/S/D are Carl's configurable slots
with Fists on D in a new game; downward-only; GAME OVER waits for Enter; one floor-entry
checkpoint; Donut is AI-controlled).

Required:
- [ ] One new reusable weapon, the Baseball Bat (id `baseball_bat`): an ActionDefinition
      (`consumable` false, with an icon) whose performer is a `MeleeAttack` scene, used through
      the normal slot dispatch. Carl's script has no Bat code; no code checks item ids.
- [ ] A new game owns no Bat. Floor 5 has one Bat pickup; walking over it owns the Bat exactly
      once and the pickup disappears. Donut and enemies cannot collect it; two collectors
      cannot both get it.
- [ ] The menu and the HUD show "Baseball Bat", never "Baseball Bat x1". It can only be assigned
      once owned; it can go on W, A, S or D, is in one slot at a time, and sits next to Fists,
      the Slingshot and the potion (e.g. `W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists`).
- [ ] A swing hits in Carl's facing direction only (a 28 px circle 36 px ahead: 8–64 px in
      front of him), never behind him, never through a wall, and never Carl or Donut.
- [ ] Exactly 20 damage per hit (two hits kill a 30 HP blob, which then dies as usual).
      Cooldown 0.75 s (45 ticks): a short press swings once, holding swings every 45 ticks,
      taps cannot swing faster, moving the Bat to another key keeps its cooldown.
- [ ] Knockback: an enemy hit and not killed is pushed 80 px away from Carl, in the swing's
      direction, over 0.3 s (18 ticks), visibly from the first tick. Walls stop it: it ends
      against the wall, never overlapping or beyond it (thin walls too). It always ends.
- [ ] Knockback is reusable: an attack passes a `Knockback` (direction, distance, duration) with
      its damage to `Hurtbox.take_hit()`; a `KnockbackReceiver` on the actor moves its body with
      `move_and_slide()`. Enemies have one; Carl and Donut do not (they are never pushed).
- [ ] While pushed, an enemy neither moves by itself nor attacks (`Enemy.update_knockback()`):
      a chasing blob is still pushed the full 80 px. Afterwards a Gelatinous Blob navigates back
      to Carl and touches him; a Spitting Blob moves to its preferred distance and spits again.
- [ ] The Spitting Blob spits nothing during a push, and its next glob comes exactly one
      cooldown (90 ticks) after the one before: no burst, no extra glob, no reset.
- [ ] A killing hit does not push; an enemy killed during a push stops at once and never moves
      or attacks again.
- [ ] Unchanged: Fists (10, 24 px reach, 0.4 s), Slingshot stones (10, 480 px/s, 320 px, 0.6 s),
      Donut's Scratch (10, 1.0 s) and spit globs (10) — none of them knocks back; enemy touches
      never push Carl.
- [ ] The menu blocks swings, freezes a push in progress (which then completes the same 80 px),
      and closing it with a key held gives no free swing. GAME OVER (the tree pause) freezes a
      push; a retry reloads the floor with its enemies as authored and no push left over.
- [ ] Floor 5 has stairs down to Floor 6 (`floor_06`, in FloorRegistry): walls, safe arrival for
      Carl and Donut, "Floor 6 - Batting Cage" sign, HUD, menu, two Gelatinous Blobs (one just
      in front of a tall wall) and a Spitting Blob, a checkpoint on entry, Continue straight into
      it. Floor 6 has no exits; nothing leads up from any floor.
- [ ] A Bat found on Floor 5 is not in the Floor 5 checkpoint: dying there (or quitting and
      continuing) takes it back (not owned, pickup back, its slot empty); repeated retries never
      duplicate it. Entering Floor 6 with it puts it and its slot in the Floor 6 checkpoint; a
      Floor 6 retry and Continue keep it, and it swings and knocks back right away.
- [ ] The save stays `save_version: 3` with the same fields: the Bat is one more `owned_items`
      id. A real Phase 8 save (version 3, no Bat) loads unchanged; version 1 and 2 saves still
      migrate and never own the Bat. A Bat with a quantity, listed twice, or an unknown owned id
      is rejected; a Bat slot without owning the Bat is emptied. `floor_07` is unknown.
- [ ] New Game clears the Bat: no items, W/A/S empty, D = Fists, the Surface.
- [ ] The Bat pickup, its label, the HUD with the Bat, the menu, Floor 6's signs and a
      knocked-back blob are on screen at 1280×720, 640×360 and 1024×768.
- [ ] Tests can never touch the player's save (the Phase 8 guard); no test save is tracked.
- [ ] No other weapons, upgrades, durability, ammunition, equipment slots, critical hits, status
      effects, new enemies, Floor 7, stair locking, timers or other Phase 10+ features were added.
