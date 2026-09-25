extends "res://tests/support/game_test.gd"
## End-to-end run through the real game, starting from the title screen (Phases 2-3):
## - a new game starts with Fists in D and full HP, even after an earlier run changed them;
## - on the Surface the player moves Fists to W in the action menu, and Carl takes damage;
## - Surface -> Floor 1: spawn point, camera, Donut, no transition loop, and Carl's HP and
##   slot layout carry over; the floor-entry state is recorded;
## - there is no way back up from Floor 1;
## - W punches a Gelatinous Blob to death; then the player moves Fists to A;
## - the other blob defeats Carl: GAME OVER freezes the game and stays until Enter;
## - Enter retries Floor 1 with the HP Carl entered it with (not full health), the enemies
##   back, and the player's current slot layout; the game still works afterwards;
## - arriving on top of stairs must not trigger them.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_loop.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
## Carl's and the blobs' positions in floor_01.tscn.
const FLOOR_1_CARL_SPAWN := Vector2(480, 456)
const FLOOR_1_BLOB_SPAWNS := [Vector2(480, 150), Vector2(820, 320)]
## Carl takes this much damage on the Surface, so he enters Floor 1 with 70 HP.
const SURFACE_DAMAGE := 30
const FLOOR_1_ENTRY_HP := 70
## Seconds allowed to reach each point of a route before Carl counts as stuck.
const WAYPOINT_TIMEOUT := 10.0


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	if not await _start_new_game():
		finish()
		return
	await _reassign_fists_on_the_surface()
	_take_damage_on_the_surface()
	if not await _go_down_to_floor_1():
		finish()
		return
	if not await _check_no_way_back_up():
		finish()
		return
	await _fight_first_blob()
	await _reassign_fists_on_floor_1()
	await _be_defeated()
	if not await _retry():
		finish()
		return
	await _check_game_works_after_retry()
	await _check_arriving_on_top_of_stairs()
	finish()


func _start_new_game() -> bool:
	print("-- New game from the title screen")
	# Leave the run in a used state first: a new game must reset it.
	var state := game_state()
	state.action_slots.assign(FISTS, ActionSlots.SLOT_S)
	state.carl_health = 25
	# Wait until the title screen really is the current scene: on a busy machine, several
	# physics ticks can pass before a scene change completes, and an early Enter would be lost.
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(title_path)
	if not await wait_for_scene(title_path):
		return false
	await wait_physics_frames(2)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	_check_hud("new game on the Surface", 100, "W: —   A: —   S: —   D: Fists", false)
	check(state.action_slots.find_slot(FISTS) == ActionSlots.SLOT_D, "a new game puts Fists back in D")
	check(state.floor_entry != null and state.floor_entry.scene_path == SURFACE_PATH and state.floor_entry.carl_health == 100,
			"the Surface records its entry state")
	return true


func _reassign_fists_on_the_surface() -> void:
	print("-- Surface: move Fists from D to W in the action menu")
	var punches := _count_punches()
	await tap_key(KEY_SPACE)
	check(paused, "Space opens the menu and pauses the game")
	await tap_key(KEY_W)
	await tap_key(KEY_SPACE)
	check(not paused, "Space closes the menu")
	_check_hud("after the reassignment", 100, "W: Fists   A: —   S: —   D: —", false)
	await hold_keys([KEY_D], 30)
	check(punches[0] == 0, "D no longer punches")
	await tap_key(KEY_W)
	check(punches[0] == 1, "W punches")


func _take_damage_on_the_surface() -> void:
	# The Surface has no enemies, so the damage is applied directly. It stands for any
	# damage taken before going down, which Carl must carry into Floor 1.
	_carl().health.take_damage(SURFACE_DAMAGE)
	_check_hud("Surface after taking damage", FLOOR_1_ENTRY_HP, "W: Fists   A: —   S: —   D: —", false)
	check(game_state().carl_health == FLOOR_1_ENTRY_HP, "GameState keeps Carl's current HP", str(game_state().carl_health))


func _go_down_to_floor_1() -> bool:
	print("-- Surface -> Floor 1")
	var stairs: Node2D = current_scene.get_node("Stairs")
	await _walk_route(_navigation_route(_carl().global_position, stairs.global_position))
	if not await wait_for_scene(FLOOR_1_PATH):
		return false
	await wait_physics_frames(3)
	var level := current_scene
	var carl := _carl()
	check(carl.global_position.distance_to(FLOOR_1_CARL_SPAWN) < 4.0, "Carl arrives at Floor 1's spawn point", str(carl.global_position))
	_check_donut_and_camera()
	_check_hud("on arrival", FLOOR_1_ENTRY_HP, "W: Fists   A: —   S: —   D: —", false)
	check(carl.health.current_health == FLOOR_1_ENTRY_HP, "Carl keeps the HP he had on the Surface")
	check(game_state().action_slots.find_slot(FISTS) == ActionSlots.SLOT_W, "Fists is still on W after the level change")
	var entry = game_state().floor_entry
	check(entry.scene_path == FLOOR_1_PATH and entry.carl_health == FLOOR_1_ENTRY_HP and entry.carl_max_health == 100,
			"Floor 1's entry state is recorded", "%s, %d/%d HP" % [entry.scene_path, entry.carl_health, entry.carl_max_health])
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 1 (no transition loop)")
	var blob_positions := _blobs().map(func(blob: Node2D) -> Vector2: return blob.global_position)
	check(blob_positions == FLOOR_1_BLOB_SPAWNS, "both blobs wait at their spawn points while Carl is far away", str(blob_positions))
	return true


func _check_no_way_back_up() -> bool:
	print("-- Floor 1: no way back up")
	var level := current_scene
	var exits := level.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node)
	var destinations := exits.map(func(node: Node) -> String: return node.destination_scene_path)
	check(not destinations.has(SURFACE_PATH) and not destinations.has(FLOOR_1_PATH),
			"nothing on Floor 1 leads back to the Surface", "destinations: %s" % [destinations])
	# Phase 2's up-stairs were just below the spawn point. Walk there and on to the wall.
	await _walk_route(PackedVector2Array([Vector2(480, 552)]))
	await hold_keys([KEY_DOWN], 60)
	await wait_seconds(0.5)
	check(current_scene == level, "walking to where the up-stairs used to be, and on to the wall, stays on Floor 1",
			"now on %s" % (current_scene.scene_file_path if current_scene != null else "no scene"))
	if current_scene != level:
		return false
	await _walk_route(PackedVector2Array([FLOOR_1_CARL_SPAWN]))
	return true


func _fight_first_blob() -> void:
	print("-- Floor 1: fight the first blob with W")
	var carl := _carl()
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob")
	var other_blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob2")
	# Walk up until the blob notices Carl, then stand still facing it and hold W.
	await hold_keys([KEY_UP], 36)
	var start := blob.global_position
	await wait_seconds(0.5)
	check(blob.global_position.distance_to(start) > 20.0, "the blob notices Carl and comes toward him")
	send_key(KEY_W, true)
	for i in 6 * Engine.physics_ticks_per_second:
		if blob.health.is_dead():
			break
		await physics_frame
	send_key(KEY_W, false)
	check(blob.health.is_dead(), "Carl's punches (W) defeat the blob")
	check(not other_blob.health.is_dead(), "the other blob is untouched")
	await wait_seconds(1.0)
	check(not is_instance_valid(blob), "the defeated blob is removed")
	var hp: int = carl.health.current_health
	check(hp >= 40 and hp <= FLOOR_1_ENTRY_HP, "Carl took only a few contact hits during the fight", "HP %d" % hp)
	_check_hud("after the fight", hp, "W: Fists   A: —   S: —   D: —", false)


func _reassign_fists_on_floor_1() -> void:
	# After entering the floor, the player moves Fists again. A retry must keep this choice
	# rather than the layout Carl had on entering the floor.
	await tap_key(KEY_SPACE)
	await tap_key(KEY_A)
	await tap_key(KEY_SPACE)
	check(game_state().action_slots.find_slot(FISTS) == ActionSlots.SLOT_A, "Fists moved to A on Floor 1")


func _be_defeated() -> void:
	print("-- Floor 1: defeated by the second blob -> GAME OVER")
	var level := current_scene
	var carl := _carl()
	var blob: CharacterBody2D = level.get_node("Actors/GelatinousBlob2")
	# Walk into the blob and stand there without punching.
	var elapsed := 0.0
	while carl.global_position.distance_to(blob.global_position) > 28.0 and elapsed < WAYPOINT_TIMEOUT:
		steer(carl.global_position.direction_to(blob.global_position))
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
	steer(Vector2.ZERO)
	for i in 15 * Engine.physics_ticks_per_second:
		if carl.health.is_dead():
			break
		await physics_frame
	check(carl.health.is_dead(), "the blob's contact damage defeats Carl")
	check(paused, "GAME OVER freezes the game (the scene tree is paused)")
	_check_hud("at GAME OVER", 0, "W: —   A: Fists   S: —   D: —", true)

	var carl_position := carl.global_position
	var blob_position := blob.global_position
	await hold_keys([KEY_LEFT], 20)
	await hold_keys([KEY_A], 20)
	await tap_key(KEY_SPACE)
	check(not level.get_node("ActionMenu").is_open(), "the action menu does not open over GAME OVER")
	# Phase 2 restarted automatically after 2 s. Now nothing happens until Enter.
	await wait_seconds(4.0)
	check(current_scene == level and paused, "4 s later the game is still at GAME OVER; it does not restart by itself")
	_check_hud("4 s after GAME OVER", 0, "W: —   A: Fists   S: —   D: —", true)
	check(carl.global_position == carl_position and blob.global_position == blob_position,
			"Carl cannot move and the blob stays frozen")


func _retry() -> bool:
	print("-- Enter retries Floor 1 from its entry state")
	var old_level_id := current_scene.get_instance_id()
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != old_level_id:
			break
		await physics_frame
	if not await wait_for_scene(FLOOR_1_PATH):
		return false
	check(current_scene.get_instance_id() != old_level_id, "Enter loads Floor 1 again")
	await wait_physics_frames(3)
	var carl := _carl()
	check(not paused, "the game runs again")
	check(carl.health.current_health == FLOOR_1_ENTRY_HP and carl.health.max_health == 100,
			"Carl has the HP he entered Floor 1 with, not full health", "HP %d / %d" % [carl.health.current_health, carl.health.max_health])
	_check_hud("after the retry", FLOOR_1_ENTRY_HP, "W: —   A: Fists   S: —   D: —", false)
	check(carl.global_position.distance_to(FLOOR_1_CARL_SPAWN) < 1.0, "Carl is back at Floor 1's spawn point")
	var blob_positions := _blobs().map(func(b: Node2D) -> Vector2: return b.global_position)
	var blob_health := _blobs().map(func(b: Node2D) -> int: return b.health.current_health)
	check(blob_positions == FLOOR_1_BLOB_SPAWNS and blob_health == [30, 30], "both blobs are back, at full health",
			"%s %s" % [blob_positions, blob_health])
	var entry = game_state().floor_entry
	check(entry.scene_path == FLOOR_1_PATH and entry.carl_health == FLOOR_1_ENTRY_HP, "the floor-entry state is unchanged by the retry")
	return true


func _check_game_works_after_retry() -> void:
	print("-- After the retry")
	var carl := _carl()
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob")
	var start := carl.global_position
	await hold_keys([KEY_UP], 36)
	check(carl.global_position.y < start.y - 90.0, "Carl moves")
	send_key(KEY_A, true)
	for i in 6 * Engine.physics_ticks_per_second:
		if blob.health.is_dead():
			break
		await physics_frame
	send_key(KEY_A, false)
	check(blob.health.is_dead(), "Carl punches with A (his current layout) and defeats a blob")


func _check_arriving_on_top_of_stairs() -> void:
	print("-- Arriving on top of stairs")
	# Load the Surface with Carl standing right on its stairs, as a badly placed spawn point would.
	var level: Node = (load(SURFACE_PATH) as PackedScene).instantiate()
	level.get_node("Actors/Carl").position = level.get_node("Stairs").position
	change_scene_to_node(level)
	await wait_seconds(1.5)
	check(current_scene == level, "stairs ignore Carl when he arrives on top of them")
	await hold_keys([KEY_LEFT], 30)
	await hold_keys([KEY_RIGHT], 30)
	check(await wait_for_scene(FLOOR_1_PATH), "after stepping off and back on, the stairs work")


## Counts the punches of Carl's Fists in the current level. Returns a one-element array.
func _count_punches() -> Array:
	var punches := [0]
	var fists: MeleeAttack = _carl().get_action_performer(FISTS)
	fists.performed.connect(func(_direction: Vector2, _hits: int) -> void: punches[0] += 1)
	return punches


func _check_donut_and_camera() -> void:
	var carl := _carl()
	var donut := _donut()
	check(donut != null and donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0,
			"Donut is present, next to Carl, and following him")
	var camera: Camera2D = carl.camera
	var offset := camera.get_screen_center_position().distance_to(carl.global_position)
	check(offset < 1.0, "the camera starts centred on Carl (no slide from elsewhere)", "%.2f px off" % offset)


func _check_hud(label: String, hp: int, slots_text: String, game_over_visible: bool) -> void:
	var hud := current_scene.get_node("HUD")
	var hp_text: String = hud.get_node("%HealthLabel").text
	var shown_slots: String = hud.get_node("%ActionSlotsLabel").text
	check(hp_text == "Carl HP: %d / 100" % hp and shown_slots == slots_text and hud.get_node("%GameOverMessage").visible == game_over_visible,
			label + ": HUD shows HP, slots and GAME OVER correctly", "%s | %s" % [hp_text, shown_slots])


## Steers Carl through each point in turn, stopping early if the level changes.
func _walk_route(route: PackedVector2Array) -> void:
	var level_id := current_scene.get_instance_id()
	for point in route:
		var elapsed := 0.0
		while true:
			if current_scene == null or current_scene.get_instance_id() != level_id:
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


func _navigation_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	return NavigationServer2D.map_get_path(root.world_2d.navigation_map, from, to, true)


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _donut() -> CharacterBody2D:
	return current_scene.get_node_or_null("Actors/Donut")


func _blobs() -> Array:
	return current_scene.get_node("Actors").get_children().filter(
			func(node: Node) -> bool: return node.scene_file_path == "res://scenes/enemies/gelatinous_blob.tscn")
