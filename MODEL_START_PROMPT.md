# PROMPT TO GIVE THE CODING MODEL

You are implementing an existing game specification, not inventing a new one.

Work directly in this repository.

Before writing or modifying code, read these files completely:

1. `README_FIRST.md`
2. `GAME_SPEC.md`
3. `ARCHITECTURE_RULES.md`
4. `ACCEPTANCE_TESTS.md`
5. `PROJECT_STATE.md`
6. `PHASE_00_PROJECT_FOUNDATION.md`

The target engine is **Godot 4.7.2 stable** and the scripting language is **GDScript**.

Your task in this session is **Phase 0 only: Project Foundation**.

Important constraints:

- Do not implement Phase 1 or later gameplay early.
- Do not redesign the controls or product premise.
- Arrow keys are movement.
- W/A/S/D are action slots, not movement.
- Prefer straightforward Godot-native architecture.
- Do not create speculative systems or large frameworks.
- Do not modify the specification/rules merely to make your implementation easier.
- Placeholder visuals must be original and simple.
- If the Godot executable is available, actually run/validate the project before claiming success.
- Do not claim tests, runtime validation, or a Git commit succeeded unless you actually performed them.
- Update `PROJECT_STATE.md` before finishing.
- Review `git status` before finishing.
- Commit the phase if the environment permits.

Proceed autonomously through Phase 0. Fix issues you encounter rather than stopping after the first error.

At completion, give me a concise report containing:
1. files created;
2. files modified;
3. InputMap actions configured;
4. validation/tests actually run and results;
5. known issues;
6. Git commit hash if one was created;
7. any manual step I need to perform;
8. explicit confirmation that you stopped at the Phase 0 boundary.
