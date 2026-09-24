extends "res://tests/support/game_test.gd"
## Phase 4 end-to-end run through the real game, starting from the title screen:
## - a new game starts with no potions, even after an earlier run had some;
## - Floor 1 starts with 0 potions recorded and its potion pickup in place;
## - Carl walks over the pickup: +2 potions, the pickup disappears, the menu shows x2;
## - he puts the potion on A in the menu; GAME OVER and retry take the potions back, empty
##   slot A, and put the pickup back; retrying again never creates potions;
## - he picks them up again, uses one (60 -> 90 HP), and takes the stairs down to Floor 2;
## - Floor 2: Carl and Donut arrive, the potion (x1) and slot A are still there, the entry
##   state records 1 potion, and nothing leads back up;
## - on Floor 2 he uses his last potion and dies: the retry gives the potion back, once, and
##   (since Phase 5) puts it back on A, as it was when he entered Floor 2.
## Damage is applied directly where it only stands in for a fight; test_floor_loop.gd covers
## real fights and deaths.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_inventory_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
## Carl's position in floor_02.tscn.
const FLOOR_2_CARL_SPAWN := Vector2(160, 288)
## Seconds allowed to reach each point of a route before Carl counts as stuck.
const WAYPOINT_TIMEOUT := 10.0


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	if not await _start_new_game():
		finish()
		return
	if not await _take_stairs(FLOOR_1_PATH):
		finish()
		return
	await _check_floor_1_start()
	if not await _collect_potions_and_assign_to_a():
		finish()
		return
	if not await _retry_takes_floor_1_potions_back():
		finish()
		return
	if not await _collect_potions_and_assign_to_a():
		finish()
		return
	await _use_a_potion_on_floor_1()
	if not await _take_stairs(FLOOR_2_PATH):
		finish()
		return
	_check_floor_2_arrival()
	await _retry_restores_floor_2_potion()
	finish()


func _start_new_game() -> bool:
	print("-- New game")
	var state := game_state()
	# An earlier run in this process ended with potions and a potion slot.
	state.inventory.add(POTION, 4)
	state.action_slots.assign(POTION, ActionSlots.SLOT_W)
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(title_path)
	if not await wait_for_scene(title_path):
		return false
	await wait_physics_frames(2)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	check(state.inventory.get_quantity(POTION) == 0, "the new game has no potions")
	_check_hud("new game", "W: —   A: —   S: —   D: Fists")
	return true


func _check_floor_1_start() -> void:
	print("-- Floor 1 on arrival")
	var entry = game_state().floor_entry
	check(entry.scene_path == FLOOR_1_PATH and _snapshot_quantity(entry) == 0, "Floor 1's entry state records 0 potions")
	check(_pickup() != null, "the potion pickup is on Floor 1")
	var rows := await _open_menu_and_read_rows()
	check(rows == ["> Fists   (on D)"], "the menu does not list potions Carl does not have", str(rows))


## Walks Carl onto Floor 1's potion pickup, then puts the potion on A through the menu.
func _collect_potions_and_assign_to_a() -> bool:
	print("-- Floor 1: collect the potions and put them on A")
	var pickup := _pickup()
	if pickup == null:
		_failures.append("There is no potion pickup to collect.")
		return false
	var pickup_position := pickup.global_position
	var before: int = game_state().inventory.get_quantity(POTION)
	await _walk_route(await _navigation_route(_carl().global_position, pickup_position))
	await wait_physics_frames(2)
	check(game_state().inventory.get_quantity(POTION) == before + 2, "walking over the pickup gives exactly 2 potions",
			"%d -> %d" % [before, game_state().inventory.get_quantity(POTION)])
	check(_pickup() == null, "the pickup is gone")
	await tap_key(KEY_SPACE)
	check(_menu_rows() == ["> Fists   (on D)", "Small Health Potion x2   (no slot)"], "the menu shows Small Health Potion x2",
			str(_menu_rows()))
	await tap_key(KEY_DOWN)
	await tap_key(KEY_A)
	await tap_key(KEY_SPACE)
	_check_hud("potion on A", "W: —   A: Potion x2   S: —   D: Fists")
	return true


func _retry_takes_floor_1_potions_back() -> bool:
	print("-- Floor 1: GAME OVER and retry take the new potions back")
	if not await _die_and_retry(FLOOR_1_PATH):
		return false
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 0, "after the retry Carl has 0 potions again, as on entering Floor 1")
	check(state.action_slots.get_action(ActionSlots.SLOT_A) == null and state.action_slots.get_action(ActionSlots.SLOT_D) == FISTS,
			"slot A (the potion) is emptied, Fists stays on D")
	_check_hud("after the retry", "W: —   A: —   S: —   D: Fists")
	check(_pickup() != null, "the potion pickup is back on the floor")
	# A second retry cycle changes nothing.
	if not await _die_and_retry(FLOOR_1_PATH):
		return false
	check(state.inventory.get_quantity(POTION) == 0 and _pickup() != null, "a second retry: still 0 potions, pickup still there")
	return true


func _use_a_potion_on_floor_1() -> void:
	print("-- Floor 1: use a potion")
	var carl := _carl()
	var fists: MeleeAttack = carl.get_action_performer(FISTS)
	var punches := [0]
	fists.performed.connect(func(_d: Vector2, _h: int) -> void: punches[0] += 1)
	await tap_key(KEY_D)
	check(punches[0] == 1, "D still punches")
	await tap_key(KEY_A)
	check(carl.health.current_health == 100 and game_state().inventory.get_quantity(POTION) == 2, "at full HP no potion is used")
	carl.health.take_damage(40)
	await tap_key(KEY_A)
	check(carl.health.current_health == 90 and game_state().inventory.get_quantity(POTION) == 1,
			"at 60 HP, A heals to 90 and uses one potion",
			"HP %d, potions %d" % [carl.health.current_health, game_state().inventory.get_quantity(POTION)])
	_check_hud("after drinking one", "W: —   A: Potion x1   S: —   D: Fists")


func _check_floor_2_arrival() -> void:
	print("-- Floor 2 on arrival")
	var carl := _carl()
	var donut: CharacterBody2D = current_scene.get_node("Actors/Donut")
	check(carl.global_position.distance_to(FLOOR_2_CARL_SPAWN) < 4.0, "Carl arrives at Floor 2's spawn point", str(carl.global_position))
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0,
			"Donut arrives next to Carl and follows him")
	var camera: Camera2D = carl.camera
	var offset := camera.get_screen_center_position().distance_to(carl.global_position)
	check(offset < 1.0, "the camera starts centred on Carl", "%.2f px off" % offset)
	check(carl.health.current_health == 90 and game_state().inventory.get_quantity(POTION) == 1,
			"Carl keeps his HP (90) and his potion (x1)")
	check(game_state().action_slots.get_action(ActionSlots.SLOT_A) == POTION, "the potion is still on A")
	_check_hud("on Floor 2", "W: —   A: Potion x1   S: —   D: Fists")
	var entry = game_state().floor_entry
	check(entry.scene_path == FLOOR_2_PATH and entry.carl_health == 90 and _snapshot_quantity(entry) == 1,
			"Floor 2's entry state records 90 HP and 1 potion")
	var exits := current_scene.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node)
	check(exits.is_empty(), "nothing on Floor 2 leads anywhere, and certainly not back up",
			str(exits.map(func(node: Node) -> String: return node.destination_scene_path)))


func _retry_restores_floor_2_potion() -> void:
	print("-- Floor 2: use the last potion, die, retry")
	var level := current_scene
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 2 (no transition loop)")
	var carl := _carl()
	carl.health.take_damage(60)
	await tap_key(KEY_A)
	check(carl.health.current_health == 60 and game_state().inventory.get_quantity(POTION) == 0,
			"the last potion heals 30 and is used up")
	check(game_state().action_slots.get_action(ActionSlots.SLOT_A) == null, "slot A empties with the last potion")
	_check_hud("no potions left", "W: —   A: —   S: —   D: Fists")
	if not await _die_and_retry(FLOOR_2_PATH):
		return
	var state := game_state()
	check(_carl().health.current_health == 90 and state.inventory.get_quantity(POTION) == 1,
			"the retry restores Floor 2's entry state: 90 HP and 1 potion",
			"HP %d, potions %d" % [_carl().health.current_health, state.inventory.get_quantity(POTION)])
	var rows := await _open_menu_and_read_rows()
	# Phase 4 left slot A empty here (a documented known issue). Phase 5 restores the slot the
	# potion had on entering the floor.
	check(rows == ["> Fists   (on D)", "Small Health Potion x1   (on A)"],
			"the retry puts the restored potion back on A, as at floor entry", str(rows))
	_check_hud("after the retry", "W: —   A: Potion x1   S: —   D: Fists")
	if not await _die_and_retry(FLOOR_2_PATH):
		return
	check(state.inventory.get_quantity(POTION) == 1 and _carl().health.current_health == 90,
			"another retry: still exactly 1 potion, no duplicates")


## Kills Carl, checks that GAME OVER waits, then presses Enter. Returns false if the level
## was not loaded again.
func _die_and_retry(level_path: String) -> bool:
	var level := current_scene
	_carl().health.take_damage(1000)
	await wait_physics_frames(2)
	var game_over: Control = level.get_node("HUD/%GameOverMessage")
	check(paused and game_over.visible, "GAME OVER: the game is paused and the message shows")
	await wait_seconds(2.5)
	check(current_scene == level and paused and game_over.visible, "2.5 s later GAME OVER is still waiting for Enter")
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene != level:
			break
		await physics_frame
	if not await wait_for_scene(level_path):
		return false
	await wait_physics_frames(3)
	check(current_scene != level and not paused, "Enter loads the floor again and the game runs")
	return true


func _take_stairs(destination_path: String) -> bool:
	print("-- Stairs down to %s" % destination_path.get_file())
	var stairs: Node2D = current_scene.get_node("Stairs")
	var route := await _navigation_route(_carl().global_position, stairs.global_position)
	if route.is_empty():
		_failures.append("No navigation route to the stairs.")
		return false
	await _walk_route(route)
	if not await wait_for_scene(destination_path):
		return false
	await wait_physics_frames(3)
	return true


func _pickup() -> Node2D:
	var pickup := current_scene.get_node_or_null("Pickups/SmallHealthPotions")
	return pickup if pickup != null and not pickup.is_queued_for_deletion() else null


## How many potions a floor-entry state recorded.
func _snapshot_quantity(entry: Object) -> int:
	return entry.inventory["quantities"].get(POTION.id, 0)


## The rows of Carl's list in the action menu (its "inventory" column).
func _menu_rows() -> Array:
	return current_scene.get_node("ActionMenu/%ActionList").get_children().map(func(row: Label) -> String: return row.text)


## Opens the action menu with Space, reads its inventory rows, and closes it again.
func _open_menu_and_read_rows() -> Array:
	await tap_key(KEY_SPACE)
	var rows := _menu_rows()
	await tap_key(KEY_SPACE)
	return rows


func _check_hud(label: String, slots_text: String) -> void:
	var shown: String = current_scene.get_node("HUD/%ActionSlotsLabel").text
	check(shown == slots_text, label + ": the HUD slot bar reads '%s'" % slots_text, shown)


## Steers Carl through each point in turn, stopping early if the level changes.
func _walk_route(route: PackedVector2Array) -> void:
	var level := current_scene
	for point in route:
		var elapsed := 0.0
		while true:
			if current_scene != level:
				steer(Vector2.ZERO)
				return
			var carl := _carl()
			if carl.global_position.distance_to(point) <= 3.0:
				break
			if elapsed > WAYPOINT_TIMEOUT:
				_failures.append("Carl got stuck at %s on the way to %s." % [carl.global_position, point])
				steer(Vector2.ZERO)
				return
			steer(carl.global_position.direction_to(point))
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
	steer(Vector2.ZERO)


## A navigation route between two points. A level's navigation map is only ready after its
## first physics frames (a slow machine may need more), so this waits for a route first.
func _navigation_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	for i in 60:
		var route := NavigationServer2D.map_get_path(root.world_2d.navigation_map, from, to, true)
		if not route.is_empty():
			return route
		await physics_frame
	return PackedVector2Array()


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")
