extends SceneTree
## End-to-end check of the Phase 1 traversal (ACCEPTANCE_TESTS.md, Phase 1):
## title screen -> Enter -> Surface -> walk Carl to the stairs -> Floor 1.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_surface_traversal.gd
##
## Carl is steered along the level's navigation path to the stairs, like a player holding
## the arrow keys, so this check keeps working if the Surface layout is edited.
## Any engine error or warning during the run also fails the check.
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const BLOB_PATH := "res://scenes/enemies/gelatinous_blob.tscn"
## Donut may briefly fall farther behind than her 50-100 px target while rounding corners.
const DONUT_MAX_ALLOWED_DISTANCE := 200.0
## Seconds allowed to reach each point of the route before Carl counts as stuck.
const WAYPOINT_TIMEOUT := 10.0


## Records engine errors and warnings (push_error, failed checks inside Godot, and so on).
class ErrorRecorder extends Logger:
	var messages := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		messages.append("%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line])
		_mutex.unlock()


var _failures := PackedStringArray()
var _error_recorder := ErrorRecorder.new()


func _initialize() -> void:
	OS.add_logger(_error_recorder)
	_run_checks.call_deferred()


func _run_checks() -> void:
	# 1. The main scene is the title screen, and Enter starts the game on the Surface.
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _wait_physics_frames(5)
	_send_key(KEY_ENTER, true)
	_send_key(KEY_ENTER, false)
	if not await _wait_for_scene(SURFACE_PATH):
		_finish()
		return
	await _wait_physics_frames(5)
	_check_actors("Surface")

	# 2. Walls stop Carl: walk right from the spawn point into the barrier wall.
	await _check_walk_into_wall(Vector2.RIGHT, 4.0, "Surface, walking right from the spawn")

	# 3. Walk to the stairs along the navigation path while watching Donut.
	var stairs: Node2D = current_scene.get_node("Stairs")
	var route := _get_route(_find_carl().global_position, stairs.global_position)
	if route.is_empty():
		_failures.append("No navigation route from Carl to the stairs.")
		_finish()
		return
	# Stop about 120 px before the stairs so Donut can be checked while Carl stands still.
	var max_donut_distance := await _walk_route(_trim_route_end(route, 120.0))
	_check_value("largest Carl-Donut distance while walking", max_donut_distance, 0.0, DONUT_MAX_ALLOWED_DISTANCE)
	await _hold_direction(Vector2.ZERO, 3.0)
	_check_value("Carl-Donut distance after Carl stops", _donut_distance(), 50.0, 100.0)

	# 4. Stepping onto the stairs loads Floor 1.
	await _walk_route(PackedVector2Array([stairs.global_position]))
	_steer(Vector2.ZERO)
	if not await _wait_for_scene(FLOOR_1_PATH):
		_finish()
		return
	await _wait_physics_frames(5)
	_check_actors("Floor 1")
	# This test covers traversal, collision and Donut only. Floor 1's enemies would
	# chase and block Carl here, so they are removed; test_combat.gd and
	# test_floor_loop.gd cover them.
	for enemy in current_scene.find_children("*", "CharacterBody2D", true, false):
		if enemy.scene_file_path == BLOB_PATH:
			enemy.queue_free()
	await _wait_physics_frames(2)

	# 5. Floor 1: Donut follows and the room's walls keep Carl inside.
	await _hold_direction(Vector2.LEFT, 1.5)
	await _hold_direction(Vector2.ZERO, 3.0)
	_check_value("Floor 1 Carl-Donut distance after walking and stopping", _donut_distance(), 50.0, 100.0)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		await _check_walk_into_wall(direction, 6.0, "Floor 1, walking %s into the boundary" % direction)

	_finish()


func _check_actors(level_name: String) -> void:
	var carl := _find_carl()
	var donut := _find_donut()
	if carl == null or donut == null:
		_failures.append("%s: Carl or Donut is missing." % level_name)
		return
	if donut.follow_target != carl:
		_failures.append("%s: Donut's follow_target is not Carl." % level_name)
	if carl.is_ancestor_of(donut):
		_failures.append("%s: Donut is a child of Carl; she must move on her own." % level_name)
	print("ok   %s loaded with Carl at %s and Donut at %s" % [level_name, carl.global_position, donut.global_position])


## Holds a direction long enough to reach a wall. Carl must first walk some distance,
## then be stopped by the wall (no progress during the final second), without
## overlapping it or leaving the level.
func _check_walk_into_wall(direction: Vector2, seconds: float, label: String) -> void:
	var carl := _find_carl()
	var start := carl.global_position
	_steer(direction)
	await _wait_physics_frames(roundi((seconds - 1.0) * Engine.physics_ticks_per_second))
	var one_second_before_end := carl.global_position
	await _wait_physics_frames(Engine.physics_ticks_per_second)
	_steer(Vector2.ZERO)
	var end := carl.global_position

	var terrain: TileMapLayer = current_scene.get_node("NavigationRegion2D/Terrain")
	var tile_size := Vector2(terrain.tile_set.tile_size)
	var cells := terrain.get_used_rect()
	var level_rect := Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)

	if (end - start).dot(direction) < tile_size.x:
		_failures.append("%s: Carl only moved from %s to %s." % [label, start, end])
	elif (end - one_second_before_end).dot(direction) > 0.5:
		_failures.append("%s: Carl was still moving at %s; no wall stopped him." % [label, end])
	elif carl.test_move(carl.global_transform, Vector2.ZERO):
		_failures.append("%s: Carl is overlapping a wall at %s." % [label, end])
	elif not level_rect.has_point(end):
		_failures.append("%s: Carl left the level at %s." % [label, end])
	else:
		print("ok   %s: walked from %s and was stopped at %s" % [label, start.round(), end.round()])


## Steers Carl through each point in turn. Returns the largest Carl-Donut distance seen.
func _walk_route(route: PackedVector2Array) -> float:
	var max_distance := 0.0
	for point in route:
		var carl := _find_carl()
		var elapsed := 0.0
		while carl != null and carl.global_position.distance_to(point) > 3.0:
			if elapsed > WAYPOINT_TIMEOUT:
				_failures.append("Carl got stuck at %s on the way to %s." % [carl.global_position, point])
				_steer(Vector2.ZERO)
				return max_distance
			_steer(carl.global_position.direction_to(point))
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
			if is_instance_valid(carl) and _find_donut() != null:
				max_distance = maxf(max_distance, _donut_distance())
			else:
				return max_distance  # The level changed (Carl reached the stairs).
	_steer(Vector2.ZERO)
	return max_distance


func _hold_direction(direction: Vector2, seconds: float) -> void:
	_steer(direction)
	await _wait_physics_frames(roundi(seconds * Engine.physics_ticks_per_second))
	_steer(Vector2.ZERO)


## Presses the move actions with analog strengths, which lets Carl walk in any direction.
## (The keyboard can only press them fully; the movement test covers that.)
func _steer(direction: Vector2) -> void:
	var strengths := {
		&"move_right": maxf(direction.x, 0.0),
		&"move_left": maxf(-direction.x, 0.0),
		&"move_down": maxf(direction.y, 0.0),
		&"move_up": maxf(-direction.y, 0.0),
	}
	for action: StringName in strengths:
		if strengths[action] > 0.0:
			Input.action_press(action, strengths[action])
		else:
			Input.action_release(action)


func _get_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var map := root.world_2d.navigation_map
	return NavigationServer2D.map_get_path(map, from, to, true)


## Returns the route shortened so that it ends `trim_length` pixels before its last point.
func _trim_route_end(route: PackedVector2Array, trim_length: float) -> PackedVector2Array:
	var trimmed := route.duplicate()
	var remaining := trim_length
	while trimmed.size() >= 2:
		var last := trimmed[trimmed.size() - 1]
		var previous := trimmed[trimmed.size() - 2]
		var segment_length := previous.distance_to(last)
		if segment_length > remaining:
			trimmed[trimmed.size() - 1] = last.move_toward(previous, remaining)
			break
		remaining -= segment_length
		trimmed.remove_at(trimmed.size() - 1)
	return trimmed


func _wait_for_scene(scene_path: String) -> bool:
	for i in 60:
		await physics_frame
		if current_scene != null and current_scene.scene_file_path == scene_path:
			print("ok   scene loaded: %s" % scene_path)
			return true
	var actual := current_scene.scene_file_path if current_scene != null else "none"
	_failures.append("Expected scene %s, but the current scene is %s." % [scene_path, actual])
	return false


func _wait_physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _find_carl() -> CharacterBody2D:
	return current_scene.find_child("Carl", true, false) if current_scene != null else null


func _find_donut() -> CharacterBody2D:
	return current_scene.find_child("Donut", true, false) if current_scene != null else null


func _donut_distance() -> float:
	return _find_carl().global_position.distance_to(_find_donut().global_position)


func _check_value(label: String, value: float, minimum: float, maximum: float) -> void:
	if value < minimum or value > maximum:
		_failures.append("%s is %.1f, expected %.0f-%.0f." % [label, value, minimum, maximum])
	else:
		print("ok   %s: %.1f (allowed %.0f-%.0f)" % [label, value, minimum, maximum])


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finish() -> void:
	_steer(Vector2.ZERO)
	for message in _error_recorder.messages:
		_failures.append("Engine error/warning: " + message)
	if _failures.is_empty():
		print("PASS: Surface -> Floor 1 traversal checks passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)
