extends SceneTree
## Shared helpers for test scripts. A test extends this file, runs its checks from
## _initialize(), and ends with finish().
## Any engine error or warning logged while the test runs also counts as a failure.


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


func _init() -> void:
	OS.add_logger(_error_recorder)


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


func finish() -> void:
	steer(Vector2.ZERO)
	for message in _error_recorder.messages:
		_failures.append("Engine error/warning: " + message)
	if _failures.is_empty():
		print("PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)
