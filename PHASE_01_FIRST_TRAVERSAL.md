# PHASE 1 — FIRST PLAYABLE TRAVERSAL

DO NOT START THIS PHASE UNTIL PHASE 0 HAS BEEN REVIEWED/ACCEPTED.

## Objective

Produce the first genuinely playable slice:

Launch -> Surface -> move Carl -> Donut follows -> enter stairs -> Floor 1 loads.

No combat or inventory yet.

## Requirements

### Carl
- Create Carl as a reusable scene.
- Use a suitable Godot 2D moving-body node, normally CharacterBody2D.
- Smooth arrow-key movement.
- Target initial speed around 180 px/s.
- Normalize movement so diagonal input, if supported, is not faster.
- Maintain the most recent non-zero facing direction.
- Add simple collision.
- Use a clear original placeholder visual.

### Camera
- Follow Carl.
- Avoid obviously jittery movement.
- Keep implementation simple.

### Donut
- Create Donut as a reusable scene.
- Use an original orange cat-like placeholder.
- Follow Carl automatically.
- Do not attach Donut as a rigid child that simply inherits Carl's transforms.
- Aim for a loose following distance around 50–100 px.
- For this small phase, use the simplest reliable navigation/follow solution suitable for the Surface layout.
- Do not implement Donut combat yet.

### Surface
- Create a small manually-authored Surface scene.
- Include boundaries/obstacles that demonstrate collision.
- Include a clearly recognizable staircase/entrance area.
- The Surface does not need polished art or story sequences.

### Floor 1
- Create only enough of Floor 1 to prove scene transition works.
- A bounded placeholder room is sufficient in this phase.
- Carl and Donut must appear in sensible spawn positions.

### Transition
- Walking Carl into the stair trigger transitions to Floor 1.
- Avoid tying floor transitions to hard-coded scene-tree accidents.
- Build the smallest transition mechanism that can reasonably extend to later floors.

### Explicit exclusions
Do NOT add:
- enemies
- damage
- weapons
- W/A/S/D attacks
- inventory UI
- item pickups
- loot tables
- saving
- boss
- procedural generation

## Verification

Run the game and verify every Phase 1 acceptance test in `ACCEPTANCE_TESTS.md`.

Update `PROJECT_STATE.md`.

Commit the completed phase if possible.
