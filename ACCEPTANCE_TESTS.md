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
