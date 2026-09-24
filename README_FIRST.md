# Carl & Donut Dungeon Prototype — LLM Starter Package

This package is the shared source of truth for three independent implementations of the same game prototype.

Target engine: **Godot 4.7.2 stable**
Language: **GDScript**
Target platform: **Windows PC**
Game type: **2D top-down action dungeon crawler**

## Important workflow rule

Do not ask an AI coding model to build the whole game in one pass.

Each implementation proceeds through numbered phases. A phase is complete only after:
1. The project opens in Godot without import/parser errors.
2. The phase acceptance tests pass.
3. The model summarizes what changed.
4. The model reports any known issues honestly.
5. The changes are committed to Git.
6. Only then is the next phase started.

## Three independent implementations

Create three sibling folders/repos:

- `carl-donut-codex`
- `carl-donut-claude`
- `carl-donut-qwen`

Copy this starter package into each repository.

Do not allow one model to inspect or copy another model's implementation.

## Files the coding model must read before coding

1. `GAME_SPEC.md`
2. `ARCHITECTURE_RULES.md`
3. `ACCEPTANCE_TESTS.md`
4. `PROJECT_STATE.md`
5. The current `PHASE_XX_*.md` file

The coding model must treat those files as requirements, not suggestions.

## Current scope

The prototype eventually contains:
- an introductory surface scene;
- Carl;
- Donut;
- keyboard movement;
- combat;
- inventory;
- four assignable W/A/S/D action slots;
- pickups;
- enemies;
- three manually designed dungeon floors;
- a Floor 3 boss;
- save/checkpoint behavior;
- game over and prototype victory states.

However, Phase 0 does **not** implement gameplay.

Phase 1 implements only the first playable traversal slice:
Surface -> move Carl -> Donut follows -> stairs -> Floor 1.

Do not implement later systems early unless a tiny amount of groundwork is required to prevent rework.
