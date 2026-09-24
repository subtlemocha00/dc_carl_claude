extends "res://tests/support/game_test.gd"
## Checks the HUD and camera on Floor 1 at the supported window sizes, in a real window.
##
## Run from the project folder (NOT headless; a game window opens briefly):
##     godot --path . -s res://tests/test_windowed_resolutions.gd
##
## When started with --headless there is no window to resize, so it reports SKIP and passes.
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(1024, 768)]
## The project's base size (Project Settings > Display > Window).
const BASE_SIZE := Vector2(1280, 720)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: this test needs a real window (run it without --headless).")
		quit(0)
		return

	change_scene_to_file(FLOOR_1_PATH)
	await wait_physics_frames(10)
	var hud := current_scene.get_node("HUD")
	var health_label: Control = hud.get_node("%HealthLabel")
	var game_over_message: Control = hud.get_node("%GameOverMessage")
	var carl: CharacterBody2D = current_scene.get_node("Actors/Carl")

	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		# "expand" stretch: the base size is scaled to fit, and any extra width or height
		# of a different aspect ratio shows more of the game instead of black bars.
		var scale := minf(window_size.x / BASE_SIZE.x, window_size.y / BASE_SIZE.y)
		var expected_size := Vector2(window_size) / scale
		check(visible_rect.size.distance_to(expected_size) < 1.0, label + ": visible area", "%s (expected %s)" % [visible_rect.size, expected_size])
		check(visible_rect.encloses(health_label.get_global_rect()), label + ": HP label is fully on screen")
		game_over_message.visible = true
		await process_frame
		var message_rect := game_over_message.get_global_rect()
		check(visible_rect.encloses(message_rect) and message_rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
				label + ": game-over message is on screen and centred")
		game_over_message.visible = false
		var carl_on_screen := carl.get_global_transform_with_canvas().origin
		check(carl_on_screen.distance_to(visible_rect.get_center()) < 1.5, label + ": camera is centred on Carl",
				"Carl drawn at %s, screen centre %s" % [carl_on_screen, visible_rect.get_center()])

	# The camera follows Carl while he walks (with a little smoothing lag) and re-centres when he stops.
	DisplayServer.window_set_size(WINDOW_SIZES[0])
	await wait_physics_frames(10)
	var camera: Camera2D = carl.camera
	send_key(KEY_LEFT, true)
	var largest_lag := 0.0
	for i in 40:
		await physics_frame
		largest_lag = maxf(largest_lag, camera.get_screen_center_position().distance_to(carl.global_position))
	send_key(KEY_LEFT, false)
	await wait_seconds(1.5)
	var final_offset := camera.get_screen_center_position().distance_to(carl.global_position)
	check(largest_lag > 1.0 and largest_lag < 60.0, "the camera follows a walking Carl with a small lag", "%.1f px" % largest_lag)
	check(final_offset < 0.5, "the camera re-centres on Carl after he stops", "%.2f px off" % final_offset)
	finish()
