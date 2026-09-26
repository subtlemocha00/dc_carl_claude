extends SceneTree
## Shared helpers for test scripts. A test extends this file, runs its checks from
## _initialize(), and ends with finish(). A run that ends any other way (the game quit the
## process, Phase 11) fails with exit code 1 (_finalize()).
## Any engine error or warning logged while the test runs also counts as a failure.
## Every test saves into its own file under TEST_SAVE_FOLDER, which is deleted when the test
## starts and finishes, so tests never read or write a player's save. SaveManager enforces
## this too (Phase 8): in a test run it refuses, with an error, any file outside that folder,
## including the player's save, so a test that never chose its own file fails instead of
## touching it (see test_save_isolation.gd).
## Phase 13: the control settings follow the same rules. Every test also gets its own settings
## file, TEST_SAVE_FOLDER + "<test>_settings.json", deleted when it starts and finishes, and starts
## with the default bindings; SettingsManager refuses any other file in a test run
## (see test_settings_manager.gd).

## Where tests keep their save files (never SaveManager.DEFAULT_SAVE_PATH). The same folder as
## SaveManager.TEST_SAVE_FOLDER.
const TEST_SAVE_FOLDER := "user://test_saves/"


## Records engine errors and warnings (push_error, failed checks inside Godot, and so on).
class ErrorRecorder extends Logger:
	## "text (file:line)" for each error or warning.
	var messages := PackedStringArray()
	## The same errors' text alone, as the engine prints it after "ERROR: ".
	var texts := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if not rationale.is_empty() else code
		_mutex.lock()
		messages.append("%s (%s:%d)" % [text, file, line])
		texts.append(text)
		_mutex.unlock()

	## Returns the messages recorded so far and forgets them. Each one's text is printed as
	## "EXPECTED ERROR: <text>", so run_all.gd excuses the engine's "ERROR: <text>" line for it.
	func take() -> PackedStringArray:
		_mutex.lock()
		var taken := messages.duplicate()
		for text in texts:
			print("EXPECTED ERROR: " + text)
		messages.clear()
		texts.clear()
		_mutex.unlock()
		return taken


var _failures := PackedStringArray()
var _error_recorder := ErrorRecorder.new()
var _finished := false


func _init() -> void:
	OS.add_logger(_error_recorder)
	# Autoloads only exist once the test runs. This deferred call is queued before anything a
	# test's _initialize() defers, so it happens before any level can save.
	_use_test_save_file.call_deferred()


## The SaveManager autoload.
func save_manager() -> Node:
	return root.get_node("SaveManager")


## The SettingsManager autoload (Phase 13).
func settings_manager() -> Node:
	return root.get_node("SettingsManager")


## Points SaveManager at this test's own save file and deletes it, so the test starts with no
## save and never touches the player's. The same for SettingsManager and this test's own
## settings file; the test starts with the default bindings.
func _use_test_save_file() -> void:
	var test_name := (get_script() as Script).resource_path.get_file().get_basename()
	save_manager().save_path = TEST_SAVE_FOLDER + test_name + ".json"
	save_manager().delete_save()
	settings_manager().settings_path = TEST_SAVE_FOLDER + test_name + "_settings.json"
	settings_manager().delete_settings_file()
	settings_manager().load_settings()


## Returns the engine errors and warnings recorded so far and forgets them, so they do not fail
## the test (nor, through the "EXPECTED ERROR" lines this prints, run_all.gd). Only for a check
## that provokes an error on purpose and then checks it was reported.
func take_engine_messages() -> PackedStringArray:
	return _error_recorder.take()


## The GameState autoload. Test scripts are compiled before autoloads exist, so they cannot
## use the name GameState directly.
func game_state() -> Node:
	return root.get_node("GameState")


func check(condition: bool, label: String, detail: String = "") -> void:
	var text := label if detail.is_empty() else "%s: %s" % [label, detail]
	if condition:
		print("ok   " + text)
	else:
		_failures.append(text)


func check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	check(absf(actual - expected) <= tolerance, label, "%.2f (expected %.2f +/- %.2f)" % [actual, expected, tolerance])


## Sends a keyboard event through Godot's normal input pipeline (and so through the InputMap).
func send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Holds the keys while the game runs exactly `ticks` physics ticks, then releases them.
func hold_keys(keys: Array[Key], ticks: int) -> void:
	for key in keys:
		send_key(key, true)
	# physics_frame is emitted just before nodes run _physics_process, so after waiting
	# ticks + 1 times the nodes have processed exactly `ticks` ticks with the keys held.
	await wait_physics_frames(ticks + 1)
	for key in keys:
		send_key(key, false)


func tap_key(key: Key) -> void:
	await hold_keys([key], 1)


func wait_physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait_seconds(seconds: float) -> void:
	await wait_physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


## Presses the move actions with analog strengths, which lets Carl walk in any direction.
func steer(direction: Vector2) -> void:
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


## Waits until the current scene is `scene_path`. Returns false (and records a failure) on timeout.
func wait_for_scene(scene_path: String, max_frames: int = 120) -> bool:
	for i in max_frames:
		await physics_frame
		if current_scene != null and current_scene.scene_file_path == scene_path:
			return true
	var actual := current_scene.scene_file_path if current_scene != null else "none"
	_failures.append("Expected scene %s, but the current scene is %s." % [scene_path, actual])
	return false


## A navigation route in the current level. A level's navigation map is only ready after its
## first physics frames, so this waits for a route. Empty if there is none.
func navigation_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	for i in 60:
		var route := NavigationServer2D.map_get_path(root.world_2d.navigation_map, from, to, true)
		if not route.is_empty():
			return route
		await physics_frame
	return PackedVector2Array()


## Waits, one physics tick at a time, until `condition` returns true. Returns false (and records
## a failure naming `what`) if that takes more than `max_ticks` ticks.
func wait_until(condition: Callable, what: String, max_ticks: int = 180) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await physics_frame
	if condition.call():
		return true
	_failures.append("Timed out after %d ticks waiting for %s." % [max_ticks, what])
	return false


## The length of a navigation route, in pixels.
func route_length(route: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	return length


## Builds an arena under root with a navigation mesh like a level's (see level_navigation.gd):
## the mesh covers the rectangle from the origin to `size` and keeps 14 px from walls, and each
## rectangle in `walls` is a solid block on the "world" layer, cut out of the mesh. Returns the
## arena, or null (with a failure recorded) if the navigation map never picked it up.
## Navigation maps are rebuilt a few ticks after a change, and until then path queries still
## answer with the old mesh. So this first waits until any earlier arena's mesh is gone, then
## until a route across the first wall bends around it: only this arena's mesh can do that.
func build_navigation_arena(size: Vector2, walls: Array[Rect2]) -> Node2D:
	var map := root.world_2d.navigation_map
	var corner := Vector2(20, 20)
	var map_is_empty := func() -> bool:
		return NavigationServer2D.map_get_regions(map).is_empty() \
				and NavigationServer2D.map_get_path(map, corner, size - corner, true).is_empty()
	if not await wait_until(map_is_empty, "the previous navigation mesh to leave the map"):
		return null
	var arena := Node2D.new()
	var region := NavigationRegion2D.new()
	var mesh := NavigationPolygon.new()
	mesh.add_outline(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]))
	mesh.agent_radius = 14.0
	mesh.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.parsed_collision_mask = 1
	region.navigation_polygon = mesh
	for rect in walls:
		region.add_child(new_wall(rect))
	arena.add_child(region)
	root.add_child(arena)
	region.bake_navigation_polygon(false)
	var ready_check := func() -> bool:
		return not NavigationServer2D.map_get_path(map, corner, size - corner, true).is_empty()
	if not walls.is_empty():
		# A route from just west of the first wall to just east of it must go around one of its ends.
		var wall := walls[0]
		var west := Vector2(wall.position.x - 30, wall.get_center().y)
		var east := Vector2(wall.end.x + 30, wall.get_center().y)
		var goes_around_wall := func(point: Vector2) -> bool:
			return point.x > wall.position.x - 30 and point.x < wall.end.x + 30 \
					and (point.y < wall.position.y or point.y > wall.end.y)
		ready_check = func() -> bool:
			var route := NavigationServer2D.map_get_path(map, west, east, true)
			return route.size() >= 3 and Array(route.slice(1, -1)).all(goes_around_wall)
	if not await wait_until(ready_check, "the navigation map to include the new arena"):
		return null
	return arena


## A solid block covering `rect`, on the "world" layer like the wall tiles.
func new_wall(rect: Rect2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	wall.add_child(shape)
	wall.position = rect.get_center()
	return wall


## Steers Carl ("Actors/Carl") along the navigation route to `target`, like a player holding
## the arrow keys. Stops early if the level changes (for example on stairs). Returns false
## (and records a failure) if there is no route or Carl gets stuck.
func walk_to(target: Vector2) -> bool:
	var level := current_scene
	var route := await navigation_route(level.get_node("Actors/Carl").global_position, target)
	if route.is_empty():
		_failures.append("No navigation route to %s." % target)
		return false
	for point in route:
		var elapsed := 0.0
		while true:
			if current_scene != level:
				steer(Vector2.ZERO)
				return true
			var carl: Node2D = level.get_node("Actors/Carl")
			if carl.global_position.distance_to(point) <= 3.0:
				break
			if elapsed > 10.0:
				_failures.append("Carl got stuck at %s on the way to %s." % [carl.global_position, point])
				steer(Vector2.ZERO)
				return false
			steer(carl.global_position.direction_to(point))
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
	steer(Vector2.ZERO)
	return true


func finish() -> void:
	_finished = true
	steer(Vector2.ZERO)
	save_manager().delete_save()
	settings_manager().delete_settings_file()
	for message in _error_recorder.messages:
		_failures.append("Engine error/warning: " + message)
	if _failures.is_empty():
		print("PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


## Runs when the process ends. A test that ends without reaching finish() did not complete: the
## game quit the process (for example Enter on a Quit Game the test did not mean to select,
## Phase 11), which would otherwise exit with code 0 and hide every failed check.
func _finalize() -> void:
	if _finished:
		return
	for failure in _failures:
		printerr("FAIL: " + failure)
	printerr("FAIL: the test ended before finish(): something quit the game while it ran")
	quit(1)
