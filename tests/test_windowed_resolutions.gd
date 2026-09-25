extends "res://tests/support/game_test.gd"
## Checks the HUD, the action menu and the camera on Floor 1 at the supported window sizes, in
## a real window. Carl carries potions and the Slingshot, both assigned to slots, so the HUD and
## the menu show their longest texts ("W: Slingshot   A: Potion x2 ..."). Phase 6 adds, at each
## size: Floor 2's Slingshot pickup (icon and label) on screen from the spawn point, and on
## Floor 3 the floor signs clear of the HUD and a flying stone on screen and drawn. Phase 7 adds,
## at each size: Floor 4's three signs clear of the HUD, and the Gelatinous Blob, the Spitting
## Blob, one of its globs and one of Carl's stones all on screen and drawn at the same time (the
## two enemies and the two projectiles look different).
## Then the title screen at each size, with a Floor 4 save: Continue and New Game, the "could not
## be loaded" message, and the New Game confirmation.
##
## Run from the project folder (NOT headless; a game window opens briefly):
##     godot --path . -s res://tests/test_windowed_resolutions.gd
##
## When started with --headless there is no window to resize, so it reports SKIP and passes.
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FLOOR_4_PATH := "res://scenes/levels/floor_04.tscn"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
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
	var action_slots_label: Control = hud.get_node("%ActionSlotsLabel")
	var action_menu: CanvasLayer = current_scene.get_node("ActionMenu")
	var menu_panel: Control = action_menu.get_node("%Panel")
	var game_over_message: Control = hud.get_node("%GameOverMessage")
	var carl: CharacterBody2D = current_scene.get_node("Actors/Carl")
	game_state().inventory.add(POTION, 2)
	game_state().action_slots.assign(POTION, ActionSlots.SLOT_A)
	game_state().inventory.add(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	check((action_slots_label as Label).text == "W: Slingshot   A: Potion x2   S: —   D: Fists",
			"the HUD shows the Slingshot on W and the potion on A", (action_slots_label as Label).text)

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
		check(visible_rect.encloses(action_slots_label.get_global_rect()), label + ": action slot bar is fully on screen")
		check(not action_slots_label.get_global_rect().intersects(health_label.get_global_rect()), label + ": slot bar and HP label do not overlap")
		game_over_message.visible = true
		await process_frame
		var message_rect := game_over_message.get_global_rect()
		check(visible_rect.encloses(message_rect) and message_rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
				label + ": game-over message is on screen and centred")
		check(not message_rect.intersects(action_slots_label.get_global_rect()), label + ": game-over message and slot bar do not overlap")
		game_over_message.visible = false
		action_menu.open()
		await process_frame
		var panel_rect := menu_panel.get_global_rect()
		check(visible_rect.encloses(panel_rect) and panel_rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
				label + ": action menu is on screen and centred", str(panel_rect))
		action_menu.close()
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
	await _check_slingshot_pickup()
	await _check_floor_3()
	await _check_floor_4()
	await _check_title_screen()
	finish()


## Floor 2's Slingshot pickup (its icon and its label) is on screen from Carl's spawn point.
func _check_slingshot_pickup() -> void:
	game_state().start_new_run()
	change_scene_to_file(FLOOR_2_PATH)
	await wait_for_scene(FLOOR_2_PATH)
	var pickup: Node2D = current_scene.get_node("Pickups/Slingshot")
	var icon: Sprite2D = pickup.get_node("Marker/Icon")
	var label: Label = pickup.get_node("Label")
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var visible_rect := root.get_visible_rect()
		var icon_rect := icon.get_global_transform_with_canvas() * icon.get_rect()
		check(icon.is_visible_in_tree() and visible_rect.encloses(icon_rect) and visible_rect.encloses(_on_screen(label)),
				"%dx%d: the Slingshot pickup and its label are on screen from the spawn point" % [window_size.x, window_size.y],
				str(icon_rect))


## Floor 3: its signs are on screen and clear of the HUD, and a stone in flight is on screen.
func _check_floor_3() -> void:
	game_state().inventory.add(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	change_scene_to_file(FLOOR_3_PATH)
	await wait_for_scene(FLOOR_3_PATH)
	var hud := current_scene.get_node("HUD")
	var hud_rects: Array[Rect2] = []
	for node_path: String in ["%HealthLabel", "%ActionSlotsLabel", "MenuHint"]:
		hud_rects.append((hud.get_node(node_path) as Control).get_global_rect())
	var launcher: ProjectileLauncher = current_scene.get_node("Actors/Carl").get_action_performer(SLINGSHOT)
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		for sign_path: String in ["Signs/FloorTitle", "Signs/Hint"]:
			var sign_rect := _on_screen(current_scene.get_node(sign_path))
			check(visible_rect.encloses(sign_rect) and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(sign_rect)),
					"%s: Floor 3's %s is on screen and clear of the HUD" % [label, sign_path.get_file()], str(sign_rect))
		var stones := []
		launcher.fired.connect(func(fired_stone: Projectile) -> void: stones.append(fired_stone), CONNECT_ONE_SHOT)
		await wait_seconds(0.7)
		await tap_key(KEY_W)
		await wait_physics_frames(8)
		var stone: Projectile = stones[0] if stones.size() == 1 else null
		check(stone != null and is_instance_valid(stone) and stone.is_visible_in_tree()
				and visible_rect.has_point(stone.get_global_transform_with_canvas().origin),
				label + ": a flying stone is drawn on screen")
		await wait_seconds(0.8)


## Floor 4: its signs are on screen and clear of the HUD from the spawn point. Then, with Carl
## between the two enemies, both enemies, a glob and a stone are drawn on screen together.
func _check_floor_4() -> void:
	change_scene_to_file(FLOOR_4_PATH)
	await wait_for_scene(FLOOR_4_PATH)
	var level := current_scene
	var hud := level.get_node("HUD")
	var hud_rects: Array[Rect2] = []
	for node_path: String in ["%HealthLabel", "%ActionSlotsLabel", "MenuHint"]:
		hud_rects.append((hud.get_node(node_path) as Control).get_global_rect())
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var visible_rect := root.get_visible_rect()
		for sign_path: String in ["Signs/FloorTitle", "Signs/PrototypeNote", "Signs/CoverHint"]:
			var sign_rect := _on_screen(level.get_node(sign_path))
			check(visible_rect.encloses(sign_rect) and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(sign_rect)),
					"%dx%d: Floor 4's %s is on screen and clear of the HUD" % [window_size.x, window_size.y, sign_path.get_file()],
					str(sign_rect))

	var blob: Node2D = level.get_node("Actors/GelatinousBlob")
	var spitter: Node2D = level.get_node("Actors/SpittingBlob")
	var body_hue := func(enemy: Node2D) -> float: return (enemy.get_node("Body") as Polygon2D).color.h
	check(absf(body_hue.call(blob) - body_hue.call(spitter)) > 0.25 and spitter.get_node_or_null("Spikes") != null
			and spitter.get_node_or_null("Mouth") != null,
			"the Spitting Blob looks different from the Gelatinous Blob: another colour, spikes and a spout")
	blob.detection_range = 0.0
	var carl: CharacterBody2D = level.get_node("Actors/Carl")
	carl.teleport_to(Vector2(640, 150))
	spitter.global_position = Vector2(880, 150)
	spitter.reset_physics_interpolation()
	var launcher: ProjectileLauncher = carl.get_action_performer(SLINGSHOT)
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		var globs := []
		spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void: globs.append(glob), CONNECT_ONE_SHOT)
		await wait_until(func() -> bool: return globs.size() == 1, "a glob", 120)
		var stones := []
		launcher.fired.connect(func(fired_stone: Projectile) -> void: stones.append(fired_stone), CONNECT_ONE_SHOT)
		await tap_key(KEY_RIGHT)
		await tap_key(KEY_W)
		await wait_physics_frames(6)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		for item: Array in [["the Gelatinous Blob", blob], ["the Spitting Blob", spitter],
				["a glob", globs[0] if globs.size() == 1 else null], ["a stone", stones[0] if stones.size() == 1 else null]]:
			var node: Node2D = item[1]
			check(node != null and is_instance_valid(node) and node.is_visible_in_tree()
					and visible_rect.has_point(node.get_global_transform_with_canvas().origin),
					"%s: %s is drawn on screen" % [label, item[0]])
		# Carl steps back to where he was, and his HP is topped up for the next size.
		carl.teleport_to(Vector2(640, 150))
		carl.health.set_health(100, 100)
		await wait_seconds(1.6)
	check(FloorRegistry.get_floor_id(game_state().floor_entry.scene_path) == &"floor_04", "the save now holds the Floor 4 checkpoint")


## A world-space Control's rectangle on screen (after the camera).
func _on_screen(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


## The title menu fits at every size. Floor 4 above saved the last checkpoint, so Continue is
## available and names Floor 4; a broken save file then shows the error message.
func _check_title_screen() -> void:
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	for broken_save in [false, true]:
		if broken_save:
			var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
			file.store_string("{broken")
			file.close()
		change_scene_to_file(title_path)
		await wait_for_scene(title_path)
		var title := current_scene
		check(title.is_continue_available() != broken_save, "title: Continue is %s" % ("unavailable with a broken save" if broken_save else "available"))
		if not broken_save:
			var info: String = title.get_node("%SaveInfoLabel").text
			check(info.begins_with("Saved at the start of Floor 4"), "title: the save is at the start of Floor 4", info)
		for window_size in WINDOW_SIZES:
			DisplayServer.window_set_size(window_size)
			await wait_physics_frames(10)
			var label := "title %dx%d%s" % [window_size.x, window_size.y, " (broken save)" if broken_save else ""]
			var visible_rect := root.get_visible_rect()
			for row_name: String in ["%ContinueRow", "%NewGameRow", "%SaveInfoLabel", "%VersionLabel"]:
				check(visible_rect.encloses(title.get_node(row_name).get_global_rect()), "%s: %s is on screen" % [label, row_name.trim_prefix("%")])
		# The confirmation panel (New Game with a save file present), then back out with Escape.
		if not broken_save:
			await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		var panel: Control = title.get_node("%ConfirmPanel")
		for window_size in WINDOW_SIZES:
			DisplayServer.window_set_size(window_size)
			await wait_physics_frames(10)
			var visible_rect := root.get_visible_rect()
			var panel_rect := panel.get_global_rect()
			check(panel.visible and visible_rect.encloses(panel_rect) and panel_rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
					"title %dx%d: the New Game confirmation is on screen and centred" % [window_size.x, window_size.y], str(panel_rect))
		await tap_key(KEY_ESCAPE)
		check(not panel.visible, "Escape closes the confirmation")
	DisplayServer.window_set_size(WINDOW_SIZES[0])
