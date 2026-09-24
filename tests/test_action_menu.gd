extends "res://tests/support/game_test.gd"
## Phase 3 action menu checks in the real levels, driven by key events:
## - Space opens the menu and pauses the game; Space or Escape closes it;
## - while it is open, Carl cannot move or attack and Donut stops;
## - selecting Fists and pressing W/S/D reassigns it; the menu, the HUD and GameState agree,
##   and the new slot punches in the game while the old one does not;
## - opening and closing the menu never produces a free punch or step, even when a key
##   pressed in the menu is still held when it closes;
## - on Floor 1, an enemy touching Carl cannot hurt him while the menu is open;
## - the menu cannot be opened over the GAME OVER screen.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_action_menu.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")

## Every Fists punch Carl performs in the current level.
var _punch_count := 0


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	game_state().start_new_run()
	if not await _load_level(SURFACE_PATH):
		finish()
		return
	await _check_open_and_close()
	await _check_gameplay_stops_while_open()
	await _check_reassigning_in_the_menu()
	await _check_no_free_actions()
	if not await _load_level(FLOOR_1_PATH):
		finish()
		return
	await _check_enemies_frozen_while_open()
	await _check_no_menu_on_game_over()
	finish()


func _check_open_and_close() -> void:
	print("-- Space opens and closes the menu")
	var menu := _menu()
	check(not menu.is_open() and not paused, "the menu starts closed and the game running")
	await tap_key(KEY_SPACE)
	check(menu.is_open() and menu.visible and paused, "Space opens the menu and pauses the game")
	check(_rows("%SlotList") == ["W   —", "A   —", "S   —", "D   Fists"], "the menu lists the four slots", str(_rows("%SlotList")))
	check(_rows("%ActionList") == ["> Fists   (on D)"], "the menu lists Carl's actions with Fists selected", str(_rows("%ActionList")))
	check(menu.get_node("%DetailsLabel").text == FISTS.description, "the menu describes the selected action")
	check(root.gui_get_focus_owner() == null,
			"nothing in the menu has keyboard focus, so Godot's ui_accept (Space, Enter) cannot press anything")
	await tap_key(KEY_SPACE)
	check(not menu.is_open() and not menu.visible and not paused, "Space closes the menu and resumes the game")
	await tap_key(KEY_SPACE)
	await tap_key(KEY_ESCAPE)
	check(not menu.is_open() and not paused, "Escape also closes the menu")
	check(_punch_count == 0, "opening and closing the menu never punched")


func _check_gameplay_stops_while_open() -> void:
	print("-- While the menu is open")
	var carl := _carl()
	var donut: Node2D = current_scene.get_node("Actors/Donut")
	# Walk away from Donut so she is moving when the menu opens.
	await hold_keys([KEY_RIGHT], 45)
	send_key(KEY_RIGHT, true)
	await tap_key(KEY_SPACE)
	var carl_position := carl.global_position
	var donut_position := donut.global_position
	var facing: Vector2 = carl.facing_direction
	await wait_seconds(0.5)
	send_key(KEY_RIGHT, false)
	for key: Key in [KEY_LEFT, KEY_UP, KEY_DOWN]:
		await hold_keys([key], 20)
	await hold_keys([KEY_D], 20)
	check(carl.global_position == carl_position and carl.facing_direction == facing, "Carl cannot move or turn",
			"moved %s" % (carl.global_position - carl_position))
	check(_punch_count == 0, "Carl cannot attack (D only acts on the menu)")
	check(donut.global_position == donut_position, "Donut stops too", "moved %s" % (donut.global_position - donut_position))
	await tap_key(KEY_SPACE)
	await hold_keys([KEY_LEFT], 20)
	check(carl.global_position.x < carl_position.x - 50.0, "after closing the menu Carl moves again")


func _check_reassigning_in_the_menu() -> void:
	print("-- Reassigning Fists in the menu")
	var slots: ActionSlots = game_state().action_slots
	var slot_bar: Label = current_scene.get_node("HUD/%ActionSlotsLabel")
	check(slot_bar.text == "W: —   A: —   S: —   D: Fists", "HUD before", slot_bar.text)
	await tap_key(KEY_SPACE)
	await tap_key(KEY_W)
	check(slots.get_action(ActionSlots.SLOT_W) == FISTS and slots.get_action(ActionSlots.SLOT_D) == null,
			"pressing W in the menu moves Fists from D to W in GameState")
	check(_rows("%SlotList") == ["W   Fists", "A   —", "S   —", "D   —"] and _rows("%ActionList") == ["> Fists   (on W)"],
			"the menu shows Fists on W", "%s %s" % [_rows("%SlotList"), _rows("%ActionList")])
	check(slot_bar.text == "W: Fists   A: —   S: —   D: —", "the HUD shows Fists on W while the menu is still open", slot_bar.text)
	check(_menu().get_node("%DetailsLabel").text == "Fists is now on W.", "the menu confirms the change")
	check(_punch_count == 0, "pressing W in the menu did not punch")
	await tap_key(KEY_SPACE)

	await hold_keys([KEY_D], 30)
	check(_punch_count == 0, "back in the game, D (now empty) does not punch")
	await tap_key(KEY_W)
	check(_punch_count == 1, "back in the game, W punches")

	# Again, without restarting anything: W -> S.
	await tap_key(KEY_SPACE)
	await tap_key(KEY_S)
	await tap_key(KEY_SPACE)
	check(slot_bar.text == "W: —   A: —   S: Fists   D: —", "HUD after moving Fists to S", slot_bar.text)
	await wait_seconds(0.5)
	await hold_keys([KEY_W], 30)
	check(_punch_count == 1, "W no longer punches")
	await tap_key(KEY_S)
	check(_punch_count == 2, "S punches")

	# Back to D for the next checks.
	await tap_key(KEY_SPACE)
	await tap_key(KEY_D)
	await tap_key(KEY_SPACE)
	check(slot_bar.text == "W: —   A: —   S: —   D: Fists", "Fists back on D", slot_bar.text)


func _check_no_free_actions() -> void:
	print("-- Opening and closing the menu gives no free actions")
	var carl := _carl()
	await wait_seconds(0.5)  # let the Fists cool down
	var punches_before := _punch_count

	# A slot key pressed in the menu (to assign) and still held when the menu closes.
	await tap_key(KEY_SPACE)
	send_key(KEY_D, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	var position_after_close := carl.global_position
	await wait_seconds(0.5)
	check(_punch_count == punches_before and not paused, "D held from the menu does not punch after it closes")
	send_key(KEY_D, false)
	await wait_physics_frames(2)
	await tap_key(KEY_D)
	check(_punch_count == punches_before + 1, "pressing D again afterwards punches normally")

	# An arrow key used in the menu and still held when it closes.
	await tap_key(KEY_SPACE)
	send_key(KEY_UP, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	position_after_close = carl.global_position
	await wait_seconds(0.5)
	check(carl.global_position == position_after_close, "Up held from the menu does not move Carl after it closes")
	send_key(KEY_UP, false)
	await wait_physics_frames(2)
	await hold_keys([KEY_UP], 20)
	check(carl.global_position.y < position_after_close.y - 50.0, "pressing Up again afterwards moves Carl normally")

	# A slot key held when the menu opens and released inside it must not keep punching.
	await wait_seconds(0.5)
	punches_before = _punch_count
	send_key(KEY_D, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	send_key(KEY_D, false)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	await wait_seconds(1.0)
	check(_punch_count == punches_before + 1, "a key released inside the menu is not stuck afterwards",
			"%d punches" % (_punch_count - punches_before))


func _check_enemies_frozen_while_open() -> void:
	print("-- Floor 1: enemies are frozen while the menu is open")
	var carl := _carl()
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob2")
	carl.teleport_to(blob.global_position + Vector2(-27, 0))
	for i in 3 * Engine.physics_ticks_per_second:
		if carl.health.current_health < 100:
			break
		await physics_frame
	check(carl.health.current_health == 90, "the blob touching Carl hurts him", "HP %d" % carl.health.current_health)

	await tap_key(KEY_SPACE)
	var blob_position := blob.global_position
	await wait_seconds(3.0)
	check(carl.health.current_health == 90, "with the menu open, the blob does not hurt Carl for 3 s", "HP %d" % carl.health.current_health)
	check(blob.global_position == blob_position, "with the menu open, the blob does not move")
	await tap_key(KEY_SPACE)
	await wait_seconds(1.0)
	check(carl.health.current_health < 90, "after the menu closes, the blob hurts Carl again", "HP %d" % carl.health.current_health)


func _check_no_menu_on_game_over() -> void:
	print("-- The menu cannot open over GAME OVER")
	var carl := _carl()
	carl.health.take_damage(1000)
	await wait_physics_frames(2)
	var game_over: Control = current_scene.get_node("HUD/%GameOverMessage")
	check(paused and game_over.visible, "Carl is down: GAME OVER, game paused")
	await tap_key(KEY_SPACE)
	await tap_key(KEY_ESCAPE)
	check(not _menu().is_open() and paused and game_over.visible, "Space does not open the menu over GAME OVER")
	# Leave through the normal retry so the test ends unpaused.
	await tap_key(KEY_ENTER)
	await wait_for_scene(FLOOR_1_PATH)
	await wait_physics_frames(2)
	check(not paused, "Enter retries and the game runs again")


## Loads a level directly and starts counting Carl's punches in it.
func _load_level(path: String) -> bool:
	change_scene_to_file(path)
	if not await wait_for_scene(path):
		return false
	await wait_physics_frames(3)
	_punch_count = 0
	var fists: MeleeAttack = _carl().get_action_performer(FISTS)
	fists.performed.connect(func(_direction: Vector2, _hits: int) -> void: _punch_count += 1)
	return true


func _menu() -> CanvasLayer:
	return current_scene.get_node("ActionMenu")


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


## The texts of the rows in one of the menu's lists.
func _rows(list_path: String) -> Array:
	return _menu().get_node(list_path).get_children().map(func(row: Label) -> String: return row.text)
