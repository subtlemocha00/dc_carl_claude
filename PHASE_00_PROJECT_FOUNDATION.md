# PHASE 0 — PROJECT FOUNDATION

## Objective

Create a clean, minimal Godot 4.7.2 project foundation that later phases can safely build on.

This phase is intentionally boring.

Do not implement Carl movement, Donut AI, enemies, combat, inventory, loot, dungeon mechanics, saving, or the three finished floors.

## Required work

1. Inspect all repository files before changing anything.
2. Create/verify a valid Godot 4.7.2 project.
3. Configure a 2D project appropriate for a 1280×720 reference viewport and reasonable resizable-window behavior.
4. Create a sensible source directory structure. Only create directories that have an immediate foreseeable purpose.
5. Configure InputMap actions for:
   - move_up = Up Arrow
   - move_down = Down Arrow
   - move_left = Left Arrow
   - move_right = Right Arrow
   - action_w = W
   - action_a = A
   - action_s = S
   - action_d = D
   - inventory_toggle = Space
   - ui_confirm_game = Enter
   - pause_back = Escape
6. Create a minimal main/start scene that proves the project runs. A plain background plus title/version text is enough.
7. Make the main/start scene the project's run scene.
8. Ensure Git ignores Godot-generated cache data, especially `.godot/`.
9. Keep all placeholder content original and simple.
10. Update `PROJECT_STATE.md`.
11. Run/validate the project using Godot if the environment provides access to the Godot executable.
12. Check errors/warnings relevant to the work.
13. Check Git status.
14. Commit Phase 0 if the environment permits.

## Recommended initial folders

Use this as guidance, not a demand to create empty folders for everything:

- `scenes/`
- `scripts/`
- `assets/`
- `resources/`
- `ui/` only if useful now or nested under scenes

Future folders may be added when their systems are introduced.

## Phase 0 completion response

When finished, report:
1. Files created.
2. Files modified.
3. Input actions created.
4. Godot validation actually performed and its result.
5. Any warnings/errors.
6. Git commit hash if committed.
7. Any manual steps the human must perform.
8. Confirmation that Phase 1 has NOT been implemented.
