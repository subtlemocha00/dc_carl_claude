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
