extends "res://tests/support/game_test.gd"
## Phase 2 end-to-end loop in the real levels, starting from the title screen:
## - Surface -> Floor 1 -> Surface, twice, then down again (spawn points, camera, HUD,
##   no transition loops);
## - fight and defeat a Gelatinous Blob on Floor 1;
## - let the other blob defeat Carl, and check that the floor restarts with Carl at full health;
## - arriving on top of stairs must not bounce Carl straight back.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_loop.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
## Carl's and the blobs' positions in floor_01.tscn.
const FLOOR_1_CARL_SPAWN := Vector2(480, 456)
const FLOOR_1_BLOB_SPAWNS := [Vector2(480, 150), Vector2(820, 320)]
## Seconds allowed to reach each point of a route before Carl counts as stuck.
const WAYPOINT_TIMEOUT := 10.0


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await wait_physics_frames(5)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		finish()
		return
	await wait_physics_frames(3)
	_check_hud("Surface at game start", 100, false)

	for trip in [1, 2]:
		if not await _go_down_to_floor_1("trip %d" % trip):
			finish()
			return
		if not await _go_up_to_surface("trip %d" % trip):
			finish()
			return
	if not await _go_down_to_floor_1("trip 3"):
		finish()
		return

	await _fight_first_blob()
	await _be_defeated_and_restart()
	await _check_arriving_on_top_of_stairs()
	finish()


func _go_down_to_floor_1(label: String) -> bool:
	print("-- %s: Surface -> Floor 1" % label)
	var stairs: Node2D = current_scene.get_node("Stairs")
	await _walk_route(_navigation_route(_carl().global_position, stairs.global_position))
	if not await wait_for_scene(FLOOR_1_PATH):
		return false
	await wait_physics_frames(3)
	var level := current_scene
	var carl := _carl()
	check(carl.global_position.distance_to(FLOOR_1_CARL_SPAWN) < 4.0, label + ": Carl arrives at Floor 1's spawn point", str(carl.global_position))
	_check_donut_and_camera(label)
	_check_hud(label + " on Floor 1", 100, false)
	await wait_seconds(1.5)
	check(current_scene == level, label + ": Carl stays on Floor 1 (no transition loop)")
	var blob_positions := _blobs().map(func(blob: Node2D) -> Vector2: return blob.global_position)
	check(blob_positions == FLOOR_1_BLOB_SPAWNS, label + ": both blobs wait at their spawn points while Carl is far away", str(blob_positions))
	return true


func _go_up_to_surface(label: String) -> bool:
	print("-- %s: Floor 1 -> Surface" % label)
	var stairs_up: Node2D = current_scene.get_node("StairsUp")
	await _walk_route(PackedVector2Array([stairs_up.global_position]))
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	var level := current_scene
	var spawn: Marker2D = level.get_node("SpawnPoints/FromFloor1")
	check(_carl().global_position.distance_to(spawn.global_position) < 4.0, label + ": Carl arrives beside the dungeon entrance", str(_carl().global_position))
	var donut_expected: Vector2 = spawn.global_position + level.donut_spawn_offset
	check(_donut().global_position.distance_to(donut_expected) < 4.0, label + ": Donut arrives next to Carl", str(_donut().global_position))
	_check_donut_and_camera(label)
	_check_hud(label + " on the Surface", 100, false)
	await wait_seconds(1.5)
	check(current_scene == level, label + ": Carl stays on the Surface (no transition loop)")
	return true


func _fight_first_blob() -> void:
	print("-- Floor 1: fight the first blob")
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
	check(blob.health.is_dead(), "Carl's punches defeat the blob")
	check(not other_blob.health.is_dead(), "the other blob is untouched")
	await wait_seconds(1.0)
	check(not is_instance_valid(blob), "the defeated blob is removed")
	var hp: int = carl.health.current_health
	check(hp >= 70 and hp <= 100, "Carl took only a few contact hits during the fight", "HP %d" % hp)
	_check_hud("after the fight", hp, false)


func _be_defeated_and_restart() -> void:
	print("-- Floor 1: defeated by the second blob, then the floor restarts")
	var level_id := current_scene.get_instance_id()
	var carl := _carl()
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob2")
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
	var died_tick := Engine.get_physics_frames()
	check(carl.health.is_dead(), "the blob's contact damage defeats Carl")
	_check_hud("when Carl is down", 0, true)
	var position_when_down := carl.global_position
	await hold_keys([KEY_LEFT], 20)
	check(carl.global_position == position_when_down, "a downed Carl cannot move")

	while current_scene == null or current_scene.get_instance_id() == level_id:
		await physics_frame
		if Engine.get_physics_frames() - died_tick > 5 * Engine.physics_ticks_per_second:
			break
	if not await wait_for_scene(FLOOR_1_PATH):
		return
	var seconds := float(Engine.get_physics_frames() - died_tick) / Engine.physics_ticks_per_second
	var restart_delay: float = current_scene.restart_delay
	check(current_scene.get_instance_id() != level_id and absf(seconds - restart_delay) < 0.1,
			"Floor 1 restarts restart_delay seconds after Carl is defeated", "%.2f s (restart_delay %.1f)" % [seconds, restart_delay])
	await wait_physics_frames(3)
	var new_carl := _carl()
	check(new_carl.health.current_health == new_carl.health.max_health, "Carl is back to full health")
	check(new_carl.global_position.distance_to(FLOOR_1_CARL_SPAWN) < 1.0, "Carl restarts at Floor 1's spawn point")
	_check_hud("after the restart", 100, false)
	var blob_positions := _blobs().map(func(b: Node2D) -> Vector2: return b.global_position)
	check(blob_positions == FLOOR_1_BLOB_SPAWNS, "both blobs are back at full strength", str(blob_positions))


func _check_arriving_on_top_of_stairs() -> void:
	print("-- Arriving on top of stairs")
	# Load Floor 1 with Carl standing right on the up-stairs, as a badly placed spawn point would.
	var level: Node = (load(FLOOR_1_PATH) as PackedScene).instantiate()
	level.get_node("Actors/Carl").position = level.get_node("StairsUp").position
	change_scene_to_node(level)
	await wait_seconds(1.5)
	check(current_scene == level, "stairs ignore Carl when he arrives on top of them")
	await hold_keys([KEY_UP], 30)
	await hold_keys([KEY_DOWN], 30)
	check(await wait_for_scene(SURFACE_PATH), "after stepping off and back on, the stairs work")


func _check_donut_and_camera(label: String) -> void:
	var carl := _carl()
	var donut := _donut()
	check(donut != null and donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0,
			label + ": Donut is present, next to Carl, and following him")
	var camera: Camera2D = carl.camera
	var offset := camera.get_screen_center_position().distance_to(carl.global_position)
	check(offset < 1.0, label + ": the camera starts centred on Carl (no slide from elsewhere)", "%.2f px off" % offset)


func _check_hud(label: String, hp: int, game_over_visible: bool) -> void:
	var hud := current_scene.get_node("HUD")
	var text: String = hud.get_node("%HealthLabel").text
	check(text == "HP: %d / 100" % hp and hud.get_node("%GameOverMessage").visible == game_over_visible,
			label + ": HUD shows the right health", text)


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
