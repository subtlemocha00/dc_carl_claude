extends SceneTree
## Sanity check for the game's InputMap actions (GAME_SPEC.md section 4).
## Phase 13: the nine gameplay controls below are the defaults the player can rebind in Settings
## (they must equal ControlBindings.DEFAULT_KEYS, so no settings file means exactly these keys).
## The menus have their own fixed actions, menu_up/down/left/right on the arrow keys, which share the
## arrows with the default movement keys on purpose (a menu never moves Carl, and play never moves a
## menu selection) and are never rebound, like ui_confirm_game (Enter) and pause_back (Escape).
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_input_map.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

## Each game action and the key it must be bound to.
## Every key here is reserved for its action: no other game action may use it.
## That rule is what keeps W/A/S/D out of movement and the arrows out of the action slots.
const EXPECTED_BINDINGS: Dictionary = {
	&"move_up": KEY_UP,
	&"move_down": KEY_DOWN,
	&"move_left": KEY_LEFT,
	&"move_right": KEY_RIGHT,
	&"action_w": KEY_W,
	&"action_a": KEY_A,
	&"action_s": KEY_S,
	&"action_d": KEY_D,
	&"inventory_toggle": KEY_SPACE,
	&"ui_confirm_game": KEY_ENTER,
	&"pause_back": KEY_ESCAPE,
}


## The menus' own actions (Phase 13), fixed on the arrow keys and bound to nothing else.
const MENU_BINDINGS: Dictionary = {
	&"menu_up": KEY_UP,
	&"menu_down": KEY_DOWN,
	&"menu_left": KEY_LEFT,
	&"menu_right": KEY_RIGHT,
}


func _initialize() -> void:
	var failures := PackedStringArray()
	for action: StringName in EXPECTED_BINDINGS:
		failures.append_array(_check_action(action))
	for action: StringName in MENU_BINDINGS:
		if not InputMap.has_action(action):
			failures.append("Missing input action '%s'." % action)
		elif _get_bound_keys(action) != [MENU_BINDINGS[action]]:
			failures.append("'%s' must be bound to %s only, not %s." % [action, OS.get_keycode_string(MENU_BINDINGS[action]), _get_bound_keys(action)])
	# The rebindable controls and their defaults (Phase 13).
	if ControlBindings.ACTIONS.size() != 9:
		failures.append("There must be nine rebindable controls, not %d." % ControlBindings.ACTIONS.size())
	for action in ControlBindings.ACTIONS:
		if ControlBindings.DEFAULT_KEYS.get(action) != EXPECTED_BINDINGS.get(action):
			failures.append("The default key of '%s' is not %s." % [action, OS.get_keycode_string(EXPECTED_BINDINGS.get(action, KEY_NONE))])
	for fixed: StringName in [&"ui_confirm_game", &"pause_back"] + MENU_BINDINGS.keys():
		if fixed in ControlBindings.ACTIONS:
			failures.append("'%s' is a menu key and must not be rebindable." % fixed)

	if failures.is_empty():
		print("PASS: all %d input actions are bound as specified." % (EXPECTED_BINDINGS.size() + MENU_BINDINGS.size()))
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check_action(action: StringName) -> PackedStringArray:
	if not InputMap.has_action(action):
		return PackedStringArray(["Missing input action '%s'." % action])

	var problems := PackedStringArray()
	var bound_keys := _get_bound_keys(action)
	var expected_key: Key = EXPECTED_BINDINGS[action]
	if expected_key not in bound_keys:
		problems.append("'%s' is not bound to %s." % [action, OS.get_keycode_string(expected_key)])

	for key in bound_keys:
		var reserved_for: Variant = EXPECTED_BINDINGS.find_key(key)
		if reserved_for != null and reserved_for != action:
			problems.append("'%s' is bound to %s, which is reserved for '%s'."
					% [action, OS.get_keycode_string(key), reserved_for])
	return problems


func _get_bound_keys(action: StringName) -> Array[Key]:
	var keys: Array[Key] = []
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		# A binding may store the physical key position or the logical keycode.
		if key_event.physical_keycode != KEY_NONE:
			keys.append(key_event.physical_keycode)
		else:
			keys.append(key_event.keycode)
	return keys
