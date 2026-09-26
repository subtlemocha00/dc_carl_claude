extends "res://tests/support/game_test.gd"
## Phase 13: playing with rebound controls, through the real title screen, Settings screen, levels
## and key events, on this test's own settings and save files. The starting point is a Floor 7
## checkpoint with the Slingshot on the W slot, 2 potions on A, 2 Blast Bombs on S and the Baseball
## Bat on D (Carl at 70 / 100).
## - On the title's Settings screen, by key presses: Move Up/Down/Left/Right = I/K/J/L, Action Slots
##   W/A/S/D = 1/2/3/4, Inventory = Tab. The save file is not touched.
## - Continue: the slots still hold exactly what the save says; the HUD reads "1: Slingshot
##   2: Potion x2   3: Blast Bomb x2   4: Baseball Bat" and "Tab: action menu"; I/K/J/L move Carl
##   exactly as far as the arrows used to and the arrows (and W/A/S/D) do not move him at all; W, A, S and D use
##   nothing while 1, 2, 3 and 4 fire the Slingshot, drink a potion (70 -> 100, "Potion x1"), throw a
##   bomb ("Blast Bomb x1") and swing the Bat.
## - Inventory: Space opens nothing; Tab opens and closes the menu; Escape still closes it (without
##   pausing). The menu names the current keys ("1   Slingshot", "Slingshot   (on 1)", "1/2/3/4: put
##   it on that key     Tab/Esc: close"); its selection moves with the arrows, not with I/K; literal
##   W assigns nothing, 4 puts Fists on the D slot ("(on 4)"), and 4 then punches.
## - Pause (Escape) > Settings: Action Slot W moves from 1 to Q; after Resume Q fires at once and 1
##   does not; the HUD says "Q: Slingshot".
## - Return to Title: the Settings screen still lists the custom keys; Continue: the checkpoint again
##   (2 potions, 2 bombs) with I and Q working.
## - New Game: the bindings stay (the Surface's sign reads "I/J/K/L to move", the HUD "4: Fists",
##   I moves Carl); Floor 1's sign names Q/2/3/4 and Tab.
## - Reset to Defaults from the pause menu: arrows and W/A/S/D/Space again at once (HUD, signs,
##   movement), and neither the save nor the run (slots, HP, items, floor) changes.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_rebinding_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_7_PATH := "res://scenes/levels/floor_07.tscn"
const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
## How far hold_keys(keys, 20) moves Carl: the key is released only after the tick that follows
## the 20th, so Carl walks 21 ticks at 3 px (180 px/s). (The same for the arrows, see the reset.)
const STEP := 63.0
const CUSTOM_KEYS: Array[Key] = [KEY_I, KEY_K, KEY_J, KEY_L, KEY_1, KEY_2, KEY_3, KEY_4, KEY_TAB]

var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")
var _save_text := ""


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_seed_floor_7_checkpoint()
	await _rebind_on_the_title()
	if not await _continue():
		finish()
		return
	await _check_movement()
	await _check_slots()
	await _check_inventory()
	await _check_rebinding_while_paused()
	await _check_return_to_title_and_continue()
	await _check_new_game()
	await _check_reset_in_play()
	finish()


func _seed_floor_7_checkpoint() -> void:
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 2)
	state.inventory.add(BOMB, 2)
	state.inventory.add(SLINGSHOT, 1)
	state.inventory.add(BAT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BOMB, ActionSlots.SLOT_S)
	state.action_slots.assign(BAT, ActionSlots.SLOT_D)
	state.carl_health = 70
	state.record_floor_entry(FLOOR_7_PATH)
	check(save_manager().save_checkpoint(state.floor_entry), "a Floor 7 checkpoint is saved (Slingshot W, potions A, bombs S, Bat D)")
	state.start_new_run()
	_save_text = FileAccess.get_file_as_string(save_manager().save_path)


func _rebind_on_the_title() -> void:
	print("-- Rebinding on the title screen")
	change_scene_to_file(_title_path)
	if not await wait_for_scene(_title_path):
		return
	var save_time := FileAccess.get_modified_time(save_manager().save_path)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var settings: Control = current_scene.get_node("%SettingsMenu")
	check(settings.is_open(), "Continue, New Game, Settings: Down twice and Enter open Settings")
	for row in CUSTOM_KEYS.size():
		await _select_row(settings, row)
		await tap_key(KEY_ENTER)
		await tap_key(CUSTOM_KEYS[row])
		check(ControlBindings.get_key(ControlBindings.ACTIONS[row]) == CUSTOM_KEYS[row], "%s is now %s" % [
				ControlBindings.get_display_name(ControlBindings.ACTIONS[row]), ControlBindings.get_key_name(CUSTOM_KEYS[row])], settings.get_message())
	check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text and FileAccess.get_modified_time(save_manager().save_path) == save_time,
			"changing the controls does not touch the save")
	await tap_key(KEY_ESCAPE)
	check(not settings.is_open() and current_scene.get_node("%SettingsRow").text == "> Settings", "Escape: back on the title")


func _continue() -> bool:
	print("-- Continue with the new keys")
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	check(current_scene.get_node("%ContinueRow").text == "> Continue", "Up twice selects Continue (the menu keys are still the arrows)")
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_7_PATH):
		return false
	await wait_physics_frames(3)
	var slots: ActionSlots = game_state().action_slots
	check(slots.get_action(ActionSlots.SLOT_W) == SLINGSHOT and slots.get_action(ActionSlots.SLOT_A) == POTION
			and slots.get_action(ActionSlots.SLOT_S) == BOMB and slots.get_action(ActionSlots.SLOT_D) == BAT,
			"the slots hold exactly what the save says: Slingshot, potions, bombs, Bat")
	check(_hud_slots() == "1: Slingshot   2: Potion x2   3: Blast Bomb x2   4: Baseball Bat", "the HUD names the new keys", _hud_slots())
	check(_hud_hint() == "Tab: action menu     Esc: pause", "and the new Inventory key", _hud_hint())
	check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text, "the checkpoint written on entry is the same as before")
	return true


func _check_movement() -> void:
	print("-- Movement")
	var carl := _carl()
	for step: Array in [[KEY_UP, Vector2.ZERO], [KEY_I, Vector2.UP], [KEY_K, Vector2.DOWN], [KEY_LEFT, Vector2.ZERO],
			[KEY_J, Vector2.LEFT], [KEY_RIGHT, Vector2.ZERO], [KEY_L, Vector2.RIGHT], [KEY_DOWN, Vector2.ZERO],
			[KEY_W, Vector2.ZERO], [KEY_A, Vector2.ZERO], [KEY_S, Vector2.ZERO], [KEY_D, Vector2.ZERO]]:
		var start := carl.global_position
		await hold_keys([step[0]], 20)
		var moved := carl.global_position - start
		check(moved.distance_to(step[1] * STEP) <= 1.0, "%s moves Carl %s" % [ControlBindings.get_key_name(step[0]),
				"%s by %d px" % [step[1], STEP] if step[1] != Vector2.ZERO else "nowhere"], str(moved))
	check(carl.facing_direction == Vector2.RIGHT, "Carl faces right (L was the last move)")


func _check_slots() -> void:
	print("-- The four slots")
	var carl := _carl()
	var stones: Array[Projectile] = []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	var bombs: Array[Projectile] = []
	(carl.get_action_performer(BOMB) as ProjectileLauncher).fired.connect(func(bomb: Projectile) -> void: bombs.append(bomb))
	var swings := [0]
	(carl.get_action_performer(BAT) as MeleeAttack).performed.connect(func(_direction: Vector2, _hits: int) -> void: swings[0] += 1)
	var inventory: Inventory = game_state().inventory
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		await tap_key(key)
	await wait_physics_frames(5)
	check(stones.is_empty() and bombs.is_empty() and swings[0] == 0 and carl.health.current_health == 70
			and inventory.get_quantity(POTION) == 2 and inventory.get_quantity(BOMB) == 2, "W, A, S and D use nothing")
	await tap_key(KEY_1)
	check(stones.size() == 1, "1 fires the Slingshot (the W slot)")
	await tap_key(KEY_2)
	check(carl.health.current_health == 100 and inventory.get_quantity(POTION) == 1, "2 drinks a potion (the A slot): 70 -> 100, one left")
	await tap_key(KEY_3)
	check(bombs.size() == 1 and inventory.get_quantity(BOMB) == 1, "3 throws a Blast Bomb (the S slot), one left")
	await tap_key(KEY_4)
	check(swings[0] == 1, "4 swings the Bat (the D slot)")
	check(_hud_slots() == "1: Slingshot   2: Potion x1   3: Blast Bomb x1   4: Baseball Bat", "the HUD counts stay right", _hud_slots())
	await wait_physics_frames(90)


func _check_inventory() -> void:
	print("-- Inventory and assignment")
	var menu: CanvasLayer = current_scene.get_node("ActionMenu")
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	await tap_key(KEY_SPACE)
	check(not menu.is_open() and not paused, "Space no longer opens the action menu")
	await tap_key(KEY_TAB)
	check(menu.is_open() and paused, "Tab opens it")
	await tap_key(KEY_TAB)
	check(not menu.is_open() and not paused, "Tab closes it")
	await tap_key(KEY_TAB)
	await tap_key(KEY_ESCAPE)
	check(not menu.is_open() and not pause.is_open() and not paused, "Escape still closes it, and pauses nothing")
	await tap_key(KEY_TAB)
	var slot_rows: Array = menu.get_node("%SlotList").get_children().map(func(row: Label) -> String: return row.text)
	check(slot_rows == ["1   Slingshot", "2   Small Health Potion x1", "3   Blast Bomb x1", "4   Baseball Bat"], "the slot column names the new keys", str(slot_rows))
	check(_action_rows(menu).has("Slingshot   (on 1)") and _action_rows(menu).has("Baseball Bat   (on 4)"), "so does the inventory column", str(_action_rows(menu)))
	check(menu.get_node("%HelpLabel").text == "Up/Down: choose an action     1/2/3/4: put it on that key     Tab/Esc: close",
			"and the help line", menu.get_node("%HelpLabel").text)
	check(menu.get_selected_action() == FISTS, "Fists are selected")
	await tap_key(KEY_K)
	check(menu.get_selected_action() == FISTS, "K (Move Down) does not move the selection")
	await tap_key(KEY_DOWN)
	check(menu.get_selected_action() != FISTS, "Down does")
	await tap_key(KEY_UP)
	var layout: Dictionary = game_state().action_slots.get_layout()
	await tap_key(KEY_W)
	check(game_state().action_slots.get_layout() == layout, "literal W assigns nothing")
	await tap_key(KEY_4)
	check(game_state().action_slots.get_action(ActionSlots.SLOT_D) == FISTS and game_state().action_slots.find_slot(BAT) == &""
			and menu.get_node("%DetailsLabel").text == "Fists is now on 4." and _action_rows(menu)[0] == "> Fists   (on 4)",
			"4 puts Fists in the D slot: \"Fists is now on 4.\"", str(_action_rows(menu)[0]))
	await tap_key(KEY_TAB)
	var punches := [0]
	(_carl().get_action_performer(FISTS) as MeleeAttack).performed.connect(func(_direction: Vector2, _hits: int) -> void: punches[0] += 1)
	await wait_physics_frames(2)
	await tap_key(KEY_D)
	check(punches[0] == 0, "D does not punch")
	await tap_key(KEY_4)
	check(punches[0] == 1 and _hud_slots().ends_with("4: Fists"), "4 punches with Fists")
	await tap_key(KEY_TAB)
	while menu.get_selected_action() != BAT:
		await tap_key(KEY_DOWN)
	await tap_key(KEY_4)
	await tap_key(KEY_TAB)
	check(game_state().action_slots.get_action(ActionSlots.SLOT_D) == BAT, "and the Bat goes back on 4")


func _check_rebinding_while_paused() -> void:
	print("-- Rebinding from the pause menu")
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	var stones: Array[Projectile] = []
	(_carl().get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	var save_time := FileAccess.get_modified_time(save_manager().save_path)
	await tap_key(KEY_ESCAPE)
	check(pause.is_open(), "Escape opens the pause menu")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var settings: Control = pause.get_node("%SettingsMenu")
	await _select_row(settings, 4)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_Q)
	check(ControlBindings.get_key(&"action_w") == KEY_Q and stones.is_empty(), "Action Slot W moves to Q; nothing fired")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	check(not pause.is_open() and not paused, "back in play")
	await tap_key(KEY_1)
	check(stones.is_empty(), "1 no longer fires")
	await tap_key(KEY_Q)
	check(stones.size() == 1, "Q fires at once")
	check(_hud_slots().begins_with("Q: Slingshot"), "the HUD says Q", _hud_slots())
	check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text and FileAccess.get_modified_time(save_manager().save_path) == save_time,
			"the save is not touched")


func _check_return_to_title_and_continue() -> void:
	print("-- Return to Title and Continue keep the keys")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(_title_path):
		return
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var settings: Control = current_scene.get_node("%SettingsMenu")
	var keys: Array = settings.get_node("%Rows").get_children().filter(func(row: Node) -> bool: return row is HBoxContainer).map(
			func(row: HBoxContainer) -> String: return (row.get_child(1) as Label).text)
	check(keys == ["I", "K", "J", "L", "Q", "2", "3", "4", "Tab"], "the title's Settings still lists the custom keys", str(keys))
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_7_PATH):
		return
	await wait_physics_frames(3)
	check(_hud_slots() == "Q: Slingshot   2: Potion x2   3: Blast Bomb x2   4: Baseball Bat", "Continue: the checkpoint again, with the keys", _hud_slots())
	var carl := _carl()
	var start := carl.global_position
	await hold_keys([KEY_I], 20)
	check((carl.global_position - start).distance_to(Vector2.UP * STEP) <= 1.0, "I moves Carl up")
	var stones: Array[Projectile] = []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	await tap_key(KEY_Q)
	check(stones.size() == 1, "Q fires")


func _check_new_game() -> void:
	print("-- New Game keeps the keys")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(_title_path):
		return
	var settings_text := FileAccess.get_file_as_string(settings_manager().settings_path)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return
	await wait_physics_frames(3)
	check(ControlBindings.get_key(&"move_up") == KEY_I and ControlBindings.get_key(&"action_w") == KEY_Q
			and FileAccess.get_file_as_string(settings_manager().settings_path) == settings_text, "a new game keeps every binding and the settings file")
	check(_hud_slots() == "Q: —   2: —   3: —   4: Fists" and _hud_hint() == "Tab: action menu     Esc: pause",
			"the HUD: Fists on the D slot, under 4", _hud_slots())
	check(current_scene.get_node("Signs/MoveHint").text == "I/J/K/L to move", "the Surface's sign names the movement keys", current_scene.get_node("Signs/MoveHint").text)
	var carl := _carl()
	var start := carl.global_position
	await hold_keys([KEY_I], 20)
	await hold_keys([KEY_UP], 20)
	check((carl.global_position - start).distance_to(Vector2.UP * STEP) <= 1.0, "I moves Carl up, Up does not", str(carl.global_position - start))
	change_scene_to_file(FLOOR_1_PATH)
	if not await wait_for_scene(FLOOR_1_PATH):
		return
	await wait_physics_frames(3)
	check(current_scene.get_node("Signs/CombatHint").text == "Q/2/3/4 use the actions shown top-left. Tab: change them.",
			"Floor 1's sign names the slot and Inventory keys", current_scene.get_node("Signs/CombatHint").text)


func _check_reset_in_play() -> void:
	print("-- Reset to Defaults in play")
	var state := game_state()
	var save_text := FileAccess.get_file_as_string(save_manager().save_path)
	var save_time := FileAccess.get_modified_time(save_manager().save_path)
	var layout: Dictionary = state.action_slots.get_layout()
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var settings: Control = pause.get_node("%SettingsMenu")
	await _select_row(settings, 9)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings_manager().is_default(), "Reset to Defaults: the nine defaults")
	check(_hud_slots() == "W: —   A: —   S: —   D: Fists" and _hud_hint() == "Space: action menu     Esc: pause", "the HUD names them at once", _hud_slots())
	check(current_scene.get_node("Signs/CombatHint").text == "W/A/S/D use the actions shown top-left. Space: change them.",
			"so does the sign", current_scene.get_node("Signs/CombatHint").text)
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	var carl := _carl()
	var start := carl.global_position
	await hold_keys([KEY_I], 20)
	await hold_keys([KEY_UP], 20)
	check((carl.global_position - start).distance_to(Vector2.UP * STEP) <= 1.0, "Up moves Carl again, I does not", str(carl.global_position - start))
	check(state.action_slots.get_layout() == layout and state.floor_entry.scene_path == FLOOR_1_PATH and state.inventory.get_actions() == [FISTS],
			"the run is unchanged: same slots, same floor, same items")
	check(FileAccess.get_file_as_string(save_manager().save_path) == save_text and FileAccess.get_modified_time(save_manager().save_path) == save_time,
			"Reset to Defaults does not touch the save")


func _select_row(settings: Control, row: int) -> void:
	while settings.get_selected_row() != row:
		await tap_key(KEY_DOWN if settings.get_selected_row() < row else KEY_UP)


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _hud_slots() -> String:
	return (current_scene.get_node("HUD/%ActionSlotsLabel") as Label).text


func _hud_hint() -> String:
	return (current_scene.get_node("HUD/%MenuHint") as Label).text


func _action_rows(menu: CanvasLayer) -> Array:
	return menu.get_node("%ActionList").get_children().map(func(row: Label) -> String: return row.text)
