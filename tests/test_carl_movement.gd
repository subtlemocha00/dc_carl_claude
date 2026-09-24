extends SceneTree
## Checks Carl's movement rules (GAME_SPEC.md sections 4-5, Phase 1 acceptance tests).
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_carl_movement.gd
##
## Carl is placed alone in an empty scene (no walls). Keyboard events go through Godot's
## normal input pipeline, so the InputMap key bindings are exercised as well.
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
## Allowed position error in pixels.
const TOLERANCE := 0.01

var _carl: CharacterBody2D
var _failures := PackedStringArray()


func _initialize() -> void:
	_carl = CARL_SCENE.instantiate()
	root.add_child(_carl)
	_run_checks.call_deferred()


func _run_checks() -> void:
	var speed: float = _carl.move_speed
	_check_facing(Vector2.DOWN, "initial facing")

	# One second (60 physics ticks) of each arrow key moves Carl move_speed pixels.
	await _check_move([KEY_RIGHT], 60, Vector2(speed, 0), "Right arrow")
	await _check_move([KEY_LEFT], 60, Vector2(-speed, 0), "Left arrow")
	_check_facing(Vector2.LEFT, "facing after moving left")
	await _check_move([KEY_UP], 60, Vector2(0, -speed), "Up arrow")
	await _check_move([KEY_DOWN], 60, Vector2(0, speed), "Down arrow")

	# Diagonals travel at the same speed as straight movement, not about 1.41x faster.
	var up_right := Vector2(1, -1).normalized()
	await _check_move([KEY_UP, KEY_RIGHT], 60, up_right * speed, "Up+Right diagonal")
	_check_facing(up_right, "facing after moving diagonally")

	# W/A/S/D are action slots: they must neither move Carl nor change his facing.
	# Each key is held on its own, because opposite keys held together would cancel out.
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		await _check_move([key], 30, Vector2.ZERO, "%s held" % OS.get_keycode_string(key))
	_check_facing(up_right, "facing after W/A/S/D")

	# Frame-rate independence: at 120 physics ticks per second, one second still covers move_speed pixels.
	await _set_physics_ticks_per_second(120)
	await _check_move([KEY_RIGHT], 120, Vector2(speed, 0), "Right arrow at 120 ticks/s")
	await _set_physics_ticks_per_second(60)

	# Speed comes from the exported move_speed setting.
	_carl.move_speed = 90.0
	await _check_move([KEY_RIGHT], 60, Vector2(90, 0), "Right arrow with move_speed = 90")

	_finish()


## Holds the given keys for exactly `ticks` physics ticks and checks how far Carl moved.
func _check_move(keys: Array[Key], ticks: int, expected: Vector2, label: String) -> void:
	for key in keys:
		_send_key(key, true)
	# physics_frame is emitted just before nodes run _physics_process, so measuring
	# between two emissions counts exactly the ticks Carl processed in between.
	await physics_frame
	var start := _carl.position
	for i in ticks:
		await physics_frame
	var moved := _carl.position - start
	for key in keys:
		_send_key(key, false)
	await physics_frame

	if moved.distance_to(expected) > TOLERANCE:
		_failures.append("%s: moved %s, expected %s." % [label, moved, expected])
	else:
		print("ok   %s: moved %s" % [label, moved.snapped(Vector2(0.01, 0.01))])


func _check_facing(expected: Vector2, label: String) -> void:
	var facing: Vector2 = _carl.facing_direction
	var arrow_rotation: float = _carl.get_node("%FacingIndicator").rotation
	if not facing.is_equal_approx(expected) or not is_equal_approx(arrow_rotation, expected.angle()):
		_failures.append("%s: facing %s (arrow %.3f rad), expected %s." % [label, facing, arrow_rotation, expected])
	else:
		print("ok   %s: %s" % [label, facing.snapped(Vector2(0.001, 0.001))])


## Godot reads the tick rate once per main-loop iteration, so the new rate only applies
## after the current iteration's idle frame. Waiting for it keeps the measurements exact.
func _set_physics_ticks_per_second(ticks: int) -> void:
	Engine.physics_ticks_per_second = ticks
	await process_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Carl movement checks passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)
