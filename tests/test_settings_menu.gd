extends "res://tests/support/game_test.gd"
## Phase 13: the Settings screen, driven by key events through Godot's input pipeline, on this
## test's own settings and save files.
## - Title: Settings is offered (New Game, Settings, Quit Game without a save; Continue first with
##   one); Enter opens the screen with no run started; it lists the nine controls and their keys,
##   then Reset to Defaults and Back; Up/Down go round; Escape and Back return to the title with
##   Settings still selected.
## - Key capture: Enter on a control waits ("Press a key for ...", its key shown as "..."); the next
##   key becomes its binding and is written; Escape cancels, changing nothing and leaving the screen
##   open; the key press that was captured (and its key repeat) never also moves the selection.
## - Refusals, with their messages and nothing changed: a key another control uses (slot vs
##   Inventory, movement vs slot), Enter, Shift on its own.
## - Reset to Defaults asks first with No selected; No (and Escape) keep the custom keys; Yes
##   restores the nine defaults, applies and writes them.
## - Pause: Settings is the pause menu's second row; opening it keeps the game paused (gameplay
##   time, enemies, Donut, a flying stone, a cooldown and Donut's recovery countdown all stay
##   frozen); Action Slot D (Fists) moved from D to F while paused: the F press that chose it and D
##   both punch nobody; Escape goes back to the pause menu (still paused, Settings selected, the HUD
##   already says "F: Fists"); after Resume F punches at once and D does not; F held through Resume
##   gives no free punch. Escape still opens the pause menu after the controls change. Nothing of
##   this writes the save.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_settings_menu.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
## Rows of the Settings screen.
const ROW_MOVE_UP := 0
const ROW_MOVE_DOWN := 1
const ROW_SLOT_A := 5
const ROW_SLOT_S := 6
const ROW_SLOT_D := 7
const ROW_INVENTORY := 8
const ROW_RESET := 9
const ROW_BACK := 10
const DEFAULT_ROWS := ["> Move Up|Up", "   Move Down|Down", "   Move Left|Left", "   Move Right|Right",
		"   Action Slot W|W", "   Action Slot A|A", "   Action Slot S|S", "   Action Slot D|D", "   Inventory|Space",
		"   Reset to Defaults", "   Back"]


## Counts physics ticks of play. It is an ordinary gameplay node in the level, so it stops
## whenever the rest of the level does.
class TickCounter extends Node:
	var ticks := 0

	func _physics_process(_delta: float) -> void:
		ticks += 1


var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	await _check_title_settings()
	await _check_capture()
	await _check_refusals()
	await _check_reset()
	await _check_pause_settings()
	finish()


func _check_title_settings() -> void:
	print("-- Settings on the title screen")
	if not await _open_title():
		return
	check(_title_rows() == ["   Continue", "> New Game", "   Settings", "   Quit Game"],
			"no save: New Game (selected), Settings and Quit Game are offered", str(_title_rows()))
	await tap_key(KEY_DOWN)
	check(_title_rows()[2] == "> Settings", "Down selects Settings")
	await tap_key(KEY_ENTER)
	var settings := _settings()
	check(settings.is_open() and settings.visible, "Enter opens the Settings screen")
	check(current_scene.scene_file_path == _title_path and game_state().floor_entry == null and not save_manager().has_save_file(),
			"no run is started for it: still the title, no floor entry, no save")
	check(_settings_rows() == DEFAULT_ROWS, "it lists the nine controls with their keys, then Reset to Defaults and Back, Move Up selected",
			str(_settings_rows()))
	check(settings.get_node("%SettingsPanel/Layout/Title").text == "Settings" and settings.get_node("%SettingsPanel/Layout/SectionLabel").text == "Controls",
			"its one section is Controls")
	for i in 10:
		await tap_key(KEY_DOWN)
	check(settings.get_selected_row() == ROW_BACK and _settings_rows()[ROW_BACK] == "> Back", "Down goes through to Back")
	await tap_key(KEY_DOWN)
	check(settings.get_selected_row() == ROW_MOVE_UP, "and round to Move Up")
	await tap_key(KEY_UP)
	check(settings.get_selected_row() == ROW_BACK, "Up from Move Up goes round to Back")
	check(_title_rows()[2] == "> Settings", "the title's selection underneath does not move")
	await tap_key(KEY_ESCAPE)
	check(not settings.is_open() and current_scene.scene_file_path == _title_path and _title_rows()[2] == "> Settings",
			"Escape closes it: back on the title with Settings selected")
	await tap_key(KEY_ENTER)
	check(settings.is_open() and settings.get_selected_row() == ROW_MOVE_UP, "opened again, Move Up is selected")
	await tap_key(KEY_UP)
	await tap_key(KEY_ENTER)
	check(not settings.is_open() and _title_rows()[2] == "> Settings", "Enter on Back closes it too")
	check(not settings_manager().has_settings_file(), "looking at the settings writes nothing")


func _check_capture() -> void:
	print("-- Key capture")
	var settings := _settings()
	await tap_key(KEY_ENTER)
	await _select_row(4)
	await tap_key(KEY_ENTER)
	check(settings.get_capturing_action() == &"action_w" and settings.get_message() == "Press a key for Action Slot W   (Esc: cancel)"
			and _settings_rows()[4] == "> Action Slot W|...", "Enter on Action Slot W waits for a key", str(_settings_rows()[4]))
	await tap_key(KEY_Q)
	check(settings.get_capturing_action() == &"" and ControlBindings.get_key(&"action_w") == KEY_Q and _settings_rows()[4] == "> Action Slot W|Q",
			"Q becomes Action Slot W's key, and the list shows it", str(_settings_rows()[4]))
	check(settings.get_message() == "Action Slot W is now Q." and settings.get_selected_row() == 4, "a message says so, and the selection stays")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_manager().settings_path))
	check(saved is Dictionary and saved.get("settings_version") == 1.0 and saved.get("keyboard", {}).get("action_w") == "Q",
			"the change is written to the settings file at once", str(saved))
	await tap_key(KEY_ENTER)
	check(settings.get_capturing_action() == &"action_w", "Enter waits again")
	await tap_key(KEY_ESCAPE)
	check(settings.get_capturing_action() == &"" and settings.is_open() and ControlBindings.get_key(&"action_w") == KEY_Q
			and settings.get_message() == "Nothing changed.", "Escape cancels: Q stays, the screen stays open")
	# A captured key is used up: Down becomes Action Slot S's key, and neither that press nor its
	# key repeat moves the selection. (Move Down first goes to K, which frees Down.)
	await _select_row(ROW_MOVE_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_K)
	check(ControlBindings.get_key(&"move_down") == KEY_K, "Move Down can be moved to K")
	await _select_row(ROW_SLOT_S)
	await tap_key(KEY_ENTER)
	send_key(KEY_DOWN, true)
	for i in 3:
		_send_echo(KEY_DOWN)
		await physics_frame
	check(ControlBindings.get_key(&"action_s") == KEY_DOWN and settings.get_selected_row() == ROW_SLOT_S,
			"Down becomes Action Slot S's key; its press and key repeat do not move the selection", "row %d" % settings.get_selected_row())
	send_key(KEY_DOWN, false)
	await tap_key(KEY_DOWN)
	check(settings.get_selected_row() == ROW_SLOT_S + 1, "the next press of Down moves the selection again (menus keep the arrows)")


func _check_refusals() -> void:
	print("-- Refused keys")
	var settings := _settings()
	var file_text := FileAccess.get_file_as_string(settings_manager().settings_path)
	await _select_row(ROW_INVENTORY)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_Q)
	check(settings.get_message() == "Q is already assigned to Action Slot W." and ControlBindings.get_key(&"inventory_toggle") == KEY_SPACE
			and ControlBindings.get_key(&"action_w") == KEY_Q and settings.get_capturing_action() == &"",
			"Inventory -> Q is refused (\"Q is already assigned to Action Slot W.\"): Inventory keeps Space, Action Slot W keeps Q", settings.get_message())
	check(_settings_rows()[ROW_INVENTORY] == "> Inventory|Space", "the list still shows Space")
	await _select_row(ROW_MOVE_UP)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_I)
	await _select_row(ROW_SLOT_A)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_I)
	check(settings.get_message() == "I is already assigned to Move Up." and ControlBindings.get_key(&"action_a") == KEY_A
			and ControlBindings.get_key(&"move_up") == KEY_I, "movement and slots share one set of keys: Action Slot A -> I is refused", settings.get_message())
	file_text = FileAccess.get_file_as_string(settings_manager().settings_path)
	await _select_row(ROW_SLOT_D)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_ENTER)
	check(settings.get_message() == "Enter is reserved for confirming in menus." and ControlBindings.get_key(&"action_d") == KEY_D
			and settings.get_capturing_action() == &"" and settings.get_selected_row() == ROW_SLOT_D,
			"Enter cannot be a control's key: refused, D kept, and the Enter did not start another wait", settings.get_message())
	await tap_key(KEY_ENTER)
	await tap_key(KEY_ESCAPE)
	check(ControlBindings.get_key(&"action_d") == KEY_D and settings.get_message() == "Nothing changed.", "Escape can never become a key either: it cancels")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_SHIFT)
	check(settings.get_message() == "Shift cannot be used for a control." and ControlBindings.get_key(&"action_d") == KEY_D,
			"Shift on its own is refused", settings.get_message())
	check(FileAccess.get_file_as_string(settings_manager().settings_path) == file_text, "refusals write nothing")


func _check_reset() -> void:
	print("-- Reset to Defaults")
	var settings := _settings()
	var custom: Dictionary = settings_manager().get_bindings()
	await _select_row(ROW_RESET)
	await tap_key(KEY_ENTER)
	var question: Label = settings.get_node("%ResetQuestion")
	check(settings.is_confirming_reset() and question.is_visible_in_tree() and question.text == "Reset all controls to defaults?"
			and not settings.is_yes_selected() and settings.get_node("%ResetNoRow").text == "> No", "Reset to Defaults asks first, with No selected")
	await tap_key(KEY_ENTER)
	check(not settings.is_confirming_reset() and settings_manager().get_bindings() == custom, "No keeps the custom keys")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	check(settings.is_yes_selected(), "Down selects Yes")
	await tap_key(KEY_ESCAPE)
	check(not settings.is_confirming_reset() and settings.is_open() and settings_manager().get_bindings() == custom, "Escape is No as well")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_UP)
	await tap_key(KEY_ENTER)
	check(settings_manager().is_default() and settings.get_message() == "All controls are back to their defaults.", "Yes restores the nine defaults")
	var rows := _settings_rows()
	check(rows.slice(0, 9) == DEFAULT_ROWS.slice(0, 9).map(func(row: String) -> String: return row.replace("> ", "   ")),
			"the list shows them at once", str(rows))
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_manager().settings_path))
	check(saved is Dictionary and saved.get("keyboard", {}).get("action_w") == "W" and saved.get("keyboard", {}).get("move_down") == "Down",
			"and the settings file has them", str(saved))
	await tap_key(KEY_ESCAPE)
	check(not settings.is_open() and current_scene.scene_file_path == _title_path, "Escape: back on the title")


func _check_pause_settings() -> void:
	print("-- Settings from the pause menu")
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 2)
	state.inventory.add(SLINGSHOT, 1)
	state.inventory.add(BAT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BAT, ActionSlots.SLOT_S)
	change_scene_to_file(FLOOR_6_PATH)
	if not await wait_for_scene(FLOOR_6_PATH):
		return
	await wait_physics_frames(3)
	var counter := TickCounter.new()
	current_scene.add_child(counter)
	var carl: CharacterBody2D = current_scene.get_node("Actors/Carl")
	var donut: CharacterBody2D = current_scene.get_node("Actors/Donut")
	var blob: Node2D = current_scene.get_node("Actors/BackstopBlob")
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	var punches := [0]
	(carl.get_action_performer(FISTS) as MeleeAttack).performed.connect(func(_direction: Vector2, _hits: int) -> void: punches[0] += 1)
	var launcher := carl.get_action_performer(SLINGSHOT) as ProjectileLauncher
	var stones: Array[Projectile] = []
	launcher.fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	# Something in flight and a cooldown running, and Donut downed with her countdown running.
	await hold_keys([KEY_UP], 5)
	await tap_key(KEY_W)
	donut.get_node("Hurtbox").take_hit(60)
	await wait_physics_frames(2)
	var save_text := FileAccess.get_file_as_string(save_manager().save_path)
	await tap_key(KEY_ESCAPE)
	check(pause.is_open() and paused and _pause_rows() == ["> Resume", "   Settings", "   Return to Title", "   Quit Game"],
			"the pause menu offers Resume, Settings, Return to Title and Quit Game", str(_pause_rows()))
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var settings: Control = pause.get_node("%SettingsMenu")
	check(settings.is_open() and pause.is_open() and paused and not (pause.get_node("%MenuPanel") as Control).visible,
			"Settings opens over the pause menu; the game stays paused")
	check(settings.scene_file_path == "res://scenes/ui/settings_menu.tscn", "it is the same Settings screen as the title's")
	var frozen := {
		"ticks": counter.ticks, "carl": carl.global_position, "blob": blob.global_position, "donut": donut.global_position,
		"stone": stones[0].global_position if stones.size() == 1 and is_instance_valid(stones[0]) else Vector2.INF,
		"cooldown": launcher.can_fire(), "recovery": donut.get_recovery_time_left(),
	}
	check(stones.size() == 1 and not launcher.can_fire() and donut.is_downed(), "a stone is in flight, the Slingshot cooling down, Donut downed")
	await _select_row(ROW_SLOT_D)
	await tap_key(KEY_ENTER)
	await hold_keys([KEY_F], 10)
	await hold_keys([KEY_D], 10)
	await wait_physics_frames(60)
	check(ControlBindings.get_key(&"action_d") == KEY_F and _settings_rows()[ROW_SLOT_D] == "> Action Slot D|F", "Action Slot D moves from D to F while paused")
	var now := {
		"ticks": counter.ticks, "carl": carl.global_position, "blob": blob.global_position, "donut": donut.global_position,
		"stone": stones[0].global_position if is_instance_valid(stones[0]) else Vector2.INF,
		"cooldown": launcher.can_fire(), "recovery": donut.get_recovery_time_left(),
	}
	check(now == frozen, "nothing in play moved or counted while the controls changed: time, Carl, the blob, Donut, the stone, the cooldown, Donut's countdown",
			"%s -> %s" % [frozen, now])
	check(punches[0] == 0, "neither the F that chose the key nor D punched")
	check(state.action_slots.get_action(ActionSlots.SLOT_D) == FISTS and state.action_slots.get_action(ActionSlots.SLOT_W) == SLINGSHOT,
			"Fists are still in the D slot; nothing else moved")
	check((current_scene.get_node("HUD/%ActionSlotsLabel") as Label).text == "W: Slingshot   A: Potion x2   S: Baseball Bat   F: Fists",
			"the HUD already names the new key", current_scene.get_node("HUD/%ActionSlotsLabel").text)
	await tap_key(KEY_ESCAPE)
	check(not settings.is_open() and pause.is_open() and paused and (pause.get_node("%MenuPanel") as Control).visible
			and _pause_rows()[1] == "> Settings", "Escape goes back to the pause menu, still paused, Settings selected")
	await tap_key(KEY_ESCAPE)
	check(not pause.is_open() and not paused, "Escape resumes")
	await wait_physics_frames(2)
	check(counter.ticks > frozen["ticks"] and (not is_instance_valid(stones[0]) or stones[0].global_position != frozen["stone"]),
			"play carries on: the stone flies on")
	await tap_key(KEY_D)
	await wait_physics_frames(2)
	check(punches[0] == 0, "D no longer punches")
	await tap_key(KEY_F)
	check(punches[0] == 1, "F punches at once")
	await wait_physics_frames(30)
	await tap_key(KEY_ESCAPE)
	send_key(KEY_F, true)
	await wait_physics_frames(2)
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(40)
	check(punches[0] == 1, "F held through Resume gives no free punch")
	send_key(KEY_F, false)
	await wait_physics_frames(2)
	await tap_key(KEY_F)
	check(punches[0] == 2, "once let go, F punches again")
	# Escape is fixed: it still opens the pause menu, whatever the controls are.
	await tap_key(KEY_ESCAPE)
	check(pause.is_open(), "Escape still opens the pause menu")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await _select_row(ROW_RESET)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings_manager().is_default() and (current_scene.get_node("HUD/%ActionSlotsLabel") as Label).text == "W: Slingshot   A: Potion x2   S: Baseball Bat   D: Fists",
			"Reset to Defaults from the pause menu: the HUD says D again")
	check(state.action_slots.get_action(ActionSlots.SLOT_D) == FISTS and state.inventory.get_quantity(POTION) == 2 and carl.health.current_health == 100,
			"and the run is untouched: slots, potions, HP")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	check(not paused and FileAccess.get_file_as_string(save_manager().save_path) == save_text, "none of this wrote the save")


## Moves the Settings screen's selection to `row` with Up/Down key presses.
func _select_row(row: int) -> void:
	var settings := _current_settings()
	while settings.get_selected_row() != row:
		await tap_key(KEY_DOWN if settings.get_selected_row() < row else KEY_UP)


func _send_echo(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _open_title() -> bool:
	change_scene_to_file(_title_path)
	return await wait_for_scene(_title_path)


func _settings() -> Control:
	return current_scene.get_node("%SettingsMenu")


## The Settings screen of the title or of the level's pause menu.
func _current_settings() -> Control:
	if current_scene.has_node("PauseMenu"):
		return current_scene.get_node("PauseMenu/%SettingsMenu")
	return _settings()


func _title_rows() -> Array:
	return ["%ContinueRow", "%NewGameRow", "%SettingsRow", "%QuitRow"].map(
			func(row: String) -> String: return (current_scene.get_node(row) as Label).text)


func _pause_rows() -> Array:
	var pause := current_scene.get_node("PauseMenu")
	return ["%ResumeRow", "%SettingsRow", "%ReturnToTitleRow", "%QuitRow"].map(
			func(row: String) -> String: return (pause.get_node(row) as Label).text)


## Each row of the Settings screen: "name|key" for a control, the text for the last two.
func _settings_rows() -> Array:
	var rows: Node = _current_settings().get_node("%Rows")
	var texts := []
	for row in rows.get_children():
		if row is HBoxContainer:
			texts.append("%s|%s" % [(row.get_child(0) as Label).text, (row.get_child(1) as Label).text])
		else:
			texts.append((row as Label).text)
	return texts
