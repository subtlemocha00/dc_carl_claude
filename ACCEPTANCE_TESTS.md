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
