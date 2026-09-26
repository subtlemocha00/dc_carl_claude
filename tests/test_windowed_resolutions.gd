extends "res://tests/support/game_test.gd"
## Checks the HUD, the action menu and the camera on Floor 1 at the supported window sizes, in
## a real window. Carl carries potions and the Slingshot, both assigned to slots, so the HUD and
## the menu show their longest texts ("W: Slingshot   A: Potion x2 ..."). Phase 6 adds, at each
## size: Floor 2's Slingshot pickup (icon and label) on screen from the spawn point, and on
## Floor 3 the floor signs clear of the HUD and a flying stone on screen and drawn. Phase 7 adds,
## at each size: Floor 4's three signs clear of the HUD, and the Gelatinous Blob, the Spitting
## Blob, one of its globs and one of Carl's stones all on screen and drawn at the same time (the
## two enemies and the two projectiles look different). Phase 8 adds, at each size: Donut's HP
## on the HUD, in its longest form ("Donut HP: 0 / 60 - DOWNED"), fully on screen and clear of
## Carl's HP and the slot bar; Floor 5's three signs clear of the HUD; a downed Donut's DOWNED
## label drawn on screen; and Donut's colour unlike both enemies'. Phase 9 adds: the longest slot
## bar, with the Baseball Bat on S ("W: Slingshot   A: Potion x2   S: Baseball Bat   D: Fists"),
## fully on screen with its text fitting; the menu listing the Bat; Floor 5's new hint and its
## Bat pickup (icon and label) on screen from the spawn point; Floor 6's three signs clear of the
## HUD; and a blob knocked back by the Bat, drawn on screen while it is pushed. Phase 10 adds: the
## HUD hint "Space: action menu     Esc: pause" on screen and fitting; the pause menu and its two
## questions (Return to Title, Quit Game) on screen, centred and fitting, above the HUD; and the
## title screen reached through Return to Title, on screen with the Floor 6 checkpoint.
## Phase 11 adds: the renderer this window really uses (the Compatibility renderer, through ANGLE
## on Windows: "opengl3_angle"), and the title's Quit Game row, on screen at each size and when
## selected.
## Phase 12 adds, at each size: Floor 6's new stairs hint clear of the HUD and the Blast Bomb x2
## pickup its loot blob drops (icon and label) on screen; Floor 7's three signs clear of the HUD;
## the longest slot bar with the bomb ("W: Baseball Bat   A: Potion x2   S: Blast Bomb x12
## D: Slingshot", a two-digit count) on screen with its text fitting, and its menu row; a
## thrown bomb and its explosion drawn on screen; a bomb frozen in flight under the pause menu.
## Once, the explosion on Floor 7's pair: both blobs hit, all three drawn on screen. The pause menu
## and Return to Title are then checked on Floor 7.
## Then the title screen at each size, with a Floor 7 save: Continue, New Game and Quit Game, the
## "could not be loaded" message, and the New Game confirmation.
## Phase 13 adds, at each size, on Floor 7 through the pause menu's Settings row: the Settings
## screen (its nine controls with their keys, Reset to Defaults, Back) on screen, centred, every row
## inside it and fitting, over the paused game; the key-capture prompt; a conflict message with a
## long key name ("BracketLeft is already assigned to Action Slot W."); the Reset to Defaults
## question. Then, with the controls on 1/2/3/4 and Tab: the HUD's slot bar ("1: Baseball Bat
## 2: Potion x2 ...") and hint ("Tab: action menu") on screen and fitting, and the action menu's slot
## column, "(on 1)" rows and help line ("1/2/3/4: put it on that key     Tab/Esc: close") inside its
## panel and fitting. The pause menu now has four rows (Settings second), and the title four
## (Settings third), each on screen; the title's "Control settings could not be loaded" line too.
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
const FLOOR_5_PATH := "res://scenes/levels/floor_05.tscn"
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const FLOOR_7_PATH := "res://scenes/levels/floor_07.tscn"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(1024, 768)]
## The project's base size (Project Settings > Display > Window).
const BASE_SIZE := Vector2(1280, 720)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: this test needs a real window (run it without --headless).")
		_finished = true
		quit(0)
		return
	var driver := RenderingServer.get_current_rendering_driver_name()
	print("Renderer: %s, driver %s, %s (%s)" % [RenderingServer.get_current_rendering_method(), driver,
			RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "the window uses the Compatibility renderer")
	if OS.get_name() == "Windows":
		check(driver == "opengl3_angle", "on Windows it runs through ANGLE (opengl3_angle)", driver)

	change_scene_to_file(FLOOR_1_PATH)
	await wait_physics_frames(10)
	var hud := current_scene.get_node("HUD")
	var health_label: Control = hud.get_node("%HealthLabel")
	var donut_label: Label = hud.get_node("%DonutHealthLabel")
	var action_slots_label: Control = hud.get_node("%ActionSlotsLabel")
	var action_menu: CanvasLayer = current_scene.get_node("ActionMenu")
	var menu_panel: Control = action_menu.get_node("%Panel")
	var game_over_message: Control = hud.get_node("%GameOverMessage")
	var carl: CharacterBody2D = current_scene.get_node("Actors/Carl")
	game_state().inventory.add(POTION, 2)
	game_state().action_slots.assign(POTION, ActionSlots.SLOT_A)
	game_state().inventory.add(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	game_state().inventory.add(BAT, 1)
	game_state().action_slots.assign(BAT, ActionSlots.SLOT_S)
	check((action_slots_label as Label).text == "W: Slingshot   A: Potion x2   S: Baseball Bat   D: Fists",
			"the HUD shows the Slingshot on W, the potion on A and the Bat on S", (action_slots_label as Label).text)
	# Donut downed: her HUD label shows its longest text.
	current_scene.get_node("Actors/Donut/Hurtbox").take_hit(60)
	check(donut_label.text == "Donut HP: 0 / 60  -  DOWNED", "the HUD shows Donut downed", donut_label.text)

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
		check(visible_rect.encloses(action_slots_label.get_global_rect()) and action_slots_label.get_minimum_size().x <= action_slots_label.size.x,
				label + ": action slot bar, with the Bat, is fully on screen and its text fits", str(action_slots_label.get_global_rect()))
		check(not action_slots_label.get_global_rect().intersects(health_label.get_global_rect()), label + ": slot bar and HP label do not overlap")
		check(visible_rect.encloses(donut_label.get_global_rect()) and donut_label.get_minimum_size().x <= donut_label.size.x,
				label + ": Donut's HP label, DOWNED, is fully on screen and its text fits", str(donut_label.get_global_rect()))
		check(not donut_label.get_global_rect().intersects(health_label.get_global_rect())
				and not donut_label.get_global_rect().intersects(action_slots_label.get_global_rect()),
				label + ": Donut's HP label overlaps neither Carl's HP nor the slot bar")
		var menu_hint: Label = hud.get_node("MenuHint")
		check(visible_rect.encloses(menu_hint.get_global_rect()) and menu_hint.get_minimum_size().x <= menu_hint.size.x
				and not menu_hint.get_global_rect().intersects(action_slots_label.get_global_rect()),
				label + ": the hint \"%s\" is on screen, fits and is clear of the slot bar" % menu_hint.text)
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
		var bat_rows := action_menu.get_node("%ActionList").get_children().filter(
				func(row: Label) -> bool: return row.text.contains("Baseball Bat   (on S)"))
		check(bat_rows.size() == 1 and visible_rect.encloses((bat_rows[0] as Label).get_global_rect()),
				label + ": the menu lists the Baseball Bat on S, on screen")
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
	await _check_floor_5()
	await _check_floor_6()
	await _check_floor_7()
	await _check_settings_screen()
	await _check_pause_menu()
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
	for node_path: String in ["%HealthLabel", "%DonutHealthLabel", "%ActionSlotsLabel", "MenuHint"]:
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
	for node_path: String in ["%HealthLabel", "%DonutHealthLabel", "%ActionSlotsLabel", "MenuHint"]:
		hud_rects.append((hud.get_node(node_path) as Control).get_global_rect())
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var visible_rect := root.get_visible_rect()
		for sign_path: String in ["Signs/FloorTitle", "Signs/Hint", "Signs/CoverHint"]:
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


## Floor 5: its signs are on screen and clear of the HUD from the spawn point; a downed Donut's
## DOWNED label is drawn on screen; Donut looks unlike both enemies.
func _check_floor_5() -> void:
	game_state().start_new_run()
	change_scene_to_file(FLOOR_5_PATH)
	await wait_for_scene(FLOOR_5_PATH)
	var level := current_scene
	var hud := level.get_node("HUD")
	var hud_rects: Array[Rect2] = []
	for node_path: String in ["%HealthLabel", "%DonutHealthLabel", "%ActionSlotsLabel", "MenuHint"]:
		hud_rects.append((hud.get_node(node_path) as Control).get_global_rect())
	var donut: CharacterBody2D = level.get_node("Actors/Donut")
	var hue := func(actor: Node2D, body_path: String) -> float: return (actor.get_node(body_path) as Polygon2D).color.h
	var donut_hue: float = hue.call(donut, "Look/Body")
	for enemy_name: String in ["GelatinousBlob", "SpittingBlob"]:
		var enemy_hue: float = hue.call(level.get_node("Actors/" + enemy_name), "Body")
		check(absf(donut_hue - enemy_hue) > 0.15, "Donut (orange) looks unlike the %s" % enemy_name, "hues %.2f / %.2f" % [donut_hue, enemy_hue])
	donut.get_node("Hurtbox").take_hit(60)
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		for sign_path: String in ["Signs/FloorTitle", "Signs/Hint", "Signs/CompanionHint"]:
			var sign_rect := _on_screen(level.get_node(sign_path))
			check(visible_rect.encloses(sign_rect) and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(sign_rect)),
					"%s: Floor 5's %s is on screen and clear of the HUD" % [label, sign_path.get_file()], str(sign_rect))
		var downed_rect := _on_screen(donut.downed_label)
		check(donut.is_downed() and donut.downed_label.is_visible_in_tree() and visible_rect.encloses(downed_rect)
				and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(downed_rect)),
				label + ": the downed Donut's DOWNED label is drawn on screen, clear of the HUD", str(downed_rect))
		var pickup: Node2D = level.get_node("Pickups/BaseballBat")
		var icon: Sprite2D = pickup.get_node("Marker/Icon")
		var icon_rect := icon.get_global_transform_with_canvas() * icon.get_rect()
		var pickup_label: Label = pickup.get_node("Label")
		var pickup_label_rect := _on_screen(pickup_label)
		check(icon.is_visible_in_tree() and icon.texture == BAT.icon and visible_rect.encloses(icon_rect)
				and visible_rect.encloses(pickup_label_rect) and pickup_label.text == "Baseball Bat"
				and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(pickup_label_rect)),
				label + ": the Baseball Bat pickup and its label are on screen from the spawn point, clear of the HUD", str(icon_rect))
	check(FloorRegistry.get_floor_id(game_state().floor_entry.scene_path) == &"floor_05", "the save now holds the Floor 5 checkpoint")


## Floor 6: its signs are on screen and clear of the HUD from the spawn point, and a blob knocked
## back by the Bat is drawn on screen while it is pushed.
func _check_floor_6() -> void:
	game_state().start_new_run()
	game_state().inventory.add(BAT, 1)
	game_state().action_slots.assign(BAT, ActionSlots.SLOT_S)
	change_scene_to_file(FLOOR_6_PATH)
	await wait_for_scene(FLOOR_6_PATH)
	var level := current_scene
	var hud := level.get_node("HUD")
	var hud_rects: Array[Rect2] = []
	for node_path: String in ["%HealthLabel", "%DonutHealthLabel", "%ActionSlotsLabel", "MenuHint"]:
		hud_rects.append((hud.get_node(node_path) as Control).get_global_rect())
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var visible_rect := root.get_visible_rect()
		for sign_path: String in ["Signs/FloorTitle", "Signs/Hint", "Signs/StairsHint"]:
			var sign_rect := _on_screen(level.get_node(sign_path))
			check(visible_rect.encloses(sign_rect) and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(sign_rect)),
					"%dx%d: Floor 6's %s is on screen and clear of the HUD" % [window_size.x, window_size.y, sign_path.get_file()],
					str(sign_rect))

	var blob: Enemy = level.get_node("Actors/BackstopBlob")
	var spawn := blob.global_position
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	var carl: CharacterBody2D = level.get_node("Actors/Carl")
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		blob.global_position = spawn + Vector2(-60, 0)
		blob.reset_physics_interpolation()
		blob.health.set_health(30, 30)
		carl.teleport_to(spawn + Vector2(-110, 0))
		carl.facing_direction = Vector2.RIGHT
		await wait_seconds(0.8)
		var start := blob.global_position
		await tap_key(KEY_S)
		await wait_physics_frames(4)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		check(blob.is_knocked_back() and blob.global_position.x - start.x > 20.0 and blob.is_visible_in_tree()
				and visible_rect.has_point(blob.get_global_transform_with_canvas().origin),
				label + ": a blob hit by the Bat is drawn on screen while it is knocked back",
				"pushed %.1f px" % (blob.global_position.x - start.x))
		await wait_seconds(0.5)
	check(FloorRegistry.get_floor_id(game_state().floor_entry.scene_path) == &"floor_06", "the save now holds the Floor 6 checkpoint")

	# Phase 12: the loot blob's Blast Bomb x2 drop, seen from where Carl killed it.
	var loot_blob: Enemy = level.get_node("Actors/GelatinousBlob")
	loot_blob.detection_range = 0.0
	loot_blob.chase_range = 0.0
	carl.teleport_to(loot_blob.global_position + Vector2(-110, 0))
	await wait_physics_frames(3)
	loot_blob.get_node("Hurtbox").take_hit(30)
	await wait_physics_frames(3)
	var drop: Node2D = level.get_node_or_null("Actors/BlastBombDrop")
	check(drop != null, "the loot blob dropped a Blast Bomb pickup")
	if drop == null:
		return
	var drop_icon: Sprite2D = drop.get_node("Marker/Icon")
	var drop_label: Label = drop.get_node("Label")
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var visible_rect := root.get_visible_rect()
		var icon_rect := drop_icon.get_global_transform_with_canvas() * drop_icon.get_rect()
		var drop_label_rect := _on_screen(drop_label)
		check(drop_icon.is_visible_in_tree() and drop_icon.texture == BOMB.icon and visible_rect.encloses(icon_rect)
				and visible_rect.encloses(drop_label_rect) and drop_label.text == "Blast Bomb x2"
				and drop_label.get_minimum_size().x <= drop_label.size.x,
				"%dx%d: the dropped Blast Bomb x2 pickup (icon and label) is on screen" % [window_size.x, window_size.y], str(icon_rect))


## Phase 12: Floor 7 at each size: its signs clear of the HUD, the longest slot bar with the bomb,
## the menu row, a thrown bomb and its explosion on screen, and a bomb frozen under the pause menu.
## Once: an explosion on the pair, with both blobs hit and on screen.
func _check_floor_7() -> void:
	var state := game_state()
	state.start_new_run()
	for item: ActionDefinition in [SLINGSHOT, BAT]:
		state.inventory.add(item, 1)
	state.inventory.add(POTION, 2)
	state.inventory.add(BOMB, 12)
	state.action_slots.assign(BAT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BOMB, ActionSlots.SLOT_S)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_D)
	change_scene_to_file(FLOOR_7_PATH)
	await wait_for_scene(FLOOR_7_PATH)
	var level := current_scene
	for enemy in level.get_node("Actors").get_children():
		if enemy is Enemy:
			enemy.detection_range = 0.0
			enemy.chase_range = 0.0
	var hud := level.get_node("HUD")
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	var carl: CharacterBody2D = level.get_node("Actors/Carl")
	var action_menu: CanvasLayer = level.get_node("ActionMenu")
	var pause: CanvasLayer = level.get_node("PauseMenu")
	var hud_rects: Array[Rect2] = []
	for node_path: String in ["%HealthLabel", "%DonutHealthLabel", "%ActionSlotsLabel", "MenuHint"]:
		hud_rects.append((hud.get_node(node_path) as Control).get_global_rect())
	var launcher := carl.get_action_performer(BOMB) as ProjectileLauncher
	var bombs := []
	var explosions := []
	launcher.fired.connect(func(bomb: Projectile) -> void:
		bombs.append(bomb)
		bomb.get_node("DetonateOnStop").exploded.connect(func(explosion: AreaDamage, _targets: Array[Hurtbox]) -> void:
			explosions.append(explosion)))
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		# The signs are read from the spawn point (the bomb below is thrown from elsewhere).
		carl.teleport_to(Vector2(176, 176))
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		for sign_path: String in ["Signs/FloorTitle", "Signs/Hint", "Signs/PrototypeNote"]:
			var sign_label: Label = level.get_node(sign_path)
			var sign_rect := _on_screen(sign_label)
			check(visible_rect.encloses(sign_rect) and sign_label.get_minimum_size().x <= sign_label.size.x
					and hud_rects.all(func(r: Rect2) -> bool: return not r.intersects(sign_rect)),
					"%s: Floor 7's %s is on screen, fits and is clear of the HUD" % [label, sign_path.get_file()], str(sign_rect))
		var bombs_left: int = state.inventory.get_quantity(BOMB)
		check(bombs_left >= 10 and slot_bar.text == "W: Baseball Bat   A: Potion x2   S: Blast Bomb x%d   D: Slingshot" % bombs_left
				and visible_rect.encloses(slot_bar.get_global_rect()) and slot_bar.get_minimum_size().x <= slot_bar.size.x,
				label + ": the longest slot bar, with the bomb, is on screen and its text fits", slot_bar.text)
		action_menu.open()
		await process_frame
		var bomb_rows := action_menu.get_node("%ActionList").get_children().filter(
				func(row: Label) -> bool: return row.text.contains("Blast Bomb x%d   (on S)" % bombs_left))
		check(bomb_rows.size() == 1 and visible_rect.encloses((bomb_rows[0] as Label).get_global_rect())
				and (bomb_rows[0] as Label).get_minimum_size().x <= (bomb_rows[0] as Label).size.x,
				label + ": the menu lists 'Blast Bomb x%d   (on S)', on screen" % bombs_left)
		action_menu.close()
		await wait_physics_frames(2)

		# A bomb in flight, then its explosion.
		carl.teleport_to(Vector2(176, 400))
		carl.facing_direction = Vector2.RIGHT
		await wait_physics_frames(10)
		var thrown := bombs.size()
		await tap_key(KEY_S)
		await wait_physics_frames(15)
		var bomb: Projectile = bombs[-1] if bombs.size() == thrown + 1 else null
		check(bomb != null and is_instance_valid(bomb) and bomb.is_visible_in_tree()
				and visible_rect.has_point(bomb.get_global_transform_with_canvas().origin),
				label + ": a thrown bomb is drawn on screen in flight")
		if bomb != null and is_instance_valid(bomb):
			await tap_key(KEY_ESCAPE)
			var frozen_at := bomb.global_position
			await wait_physics_frames(30)
			check(pause.is_open() and is_instance_valid(bomb) and bomb.global_position == frozen_at
					and visible_rect.has_point(bomb.get_global_transform_with_canvas().origin),
					label + ": under the pause menu the bomb hangs, still drawn on screen")
			await tap_key(KEY_ESCAPE)
		var exploded := explosions.size()
		await wait_until(func() -> bool: return explosions.size() > exploded, "the bomb to explode", 120)
		var explosion: AreaDamage = explosions[-1] if explosions.size() > exploded else null
		check(explosion != null and is_instance_valid(explosion) and explosion.is_visible_in_tree()
				and visible_rect.has_point(explosion.get_global_transform_with_canvas().origin),
				label + ": its explosion is drawn on screen")
		await wait_seconds(1.2)

	# The pair: one explosion, both blobs hit, everything on screen.
	DisplayServer.window_set_size(WINDOW_SIZES[0])
	var north: Enemy = level.get_node("Actors/PairBlobNorth")
	var south: Enemy = level.get_node("Actors/PairBlobSouth")
	carl.teleport_to(Vector2(400, 176))
	carl.facing_direction = Vector2.RIGHT
	await wait_physics_frames(10)
	var before := explosions.size()
	await tap_key(KEY_S)
	await wait_until(func() -> bool: return explosions.size() > before, "the bomb to explode on the pair", 120)
	await wait_physics_frames(2)
	var visible := root.get_visible_rect()
	var blast: AreaDamage = explosions[-1] if explosions.size() > before else null
	check(north.health.current_health == 10 and south.health.current_health == 10 and blast != null and is_instance_valid(blast)
			and [north, south, blast].all(func(node: Node2D) -> bool: return visible.has_point(node.get_global_transform_with_canvas().origin)),
			"1280x720: one explosion hits both blobs of the pair, all drawn on screen")
	check(FloorRegistry.get_floor_id(state.floor_entry.scene_path) == &"floor_07", "the save now holds the Floor 7 checkpoint")


## Phase 13: the Settings screen, opened from the pause menu on Floor 7, at each size; then the HUD
## and the action menu with rebound keys. The controls are back on their defaults afterwards.
func _check_settings_screen() -> void:
	var level := current_scene
	var pause: CanvasLayer = level.get_node("PauseMenu")
	var settings: Control = pause.get_node("%SettingsMenu")
	var panel: Control = settings.get_node("%SettingsPanel")
	var message: Label = settings.get_node("%MessageLabel")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings.is_open() and paused, "Settings opens from the pause menu, the game paused")
	await _check_settings_layout(settings, panel, "Settings")
	# The capture prompt.
	for i in 4:
		await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await _check_settings_layout(settings, panel, "capture prompt")
	check(message.text == "Press a key for Action Slot W   (Esc: cancel)", "the capture prompt reads \"%s\"" % message.text)
	await tap_key(KEY_BRACKETLEFT)
	# A conflict with a long key name.
	for i in 4:
		await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_BRACKETLEFT)
	check(message.text == "BracketLeft is already assigned to Action Slot W.", "the conflict message", message.text)
	await _check_settings_layout(settings, panel, "conflict message")
	# The Reset to Defaults question, then Yes.
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var confirm: Control = settings.get_node("%ResetConfirmPanel")
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		var rect := confirm.get_global_rect()
		check(confirm.is_visible_in_tree() and not panel.is_visible_in_tree() and visible_rect.encloses(rect) and rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
				label + ": the Reset to Defaults question is on screen and centred", str(rect))
		for row_name: String in ["%ResetQuestion", "%ResetNoRow", "%ResetYesRow"]:
			var row: Label = settings.get_node(row_name)
			check(rect.encloses(row.get_global_rect()) and row.get_minimum_size().x <= row.size.x,
					"%s: %s \"%s\" is inside it and fits" % [label, row_name.trim_prefix("%"), row.text])
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings_manager().is_default(), "Yes restores the defaults")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	check(not paused, "back in play")

	# The HUD and the action menu with the controls on 1/2/3/4 and Tab.
	for pair: Array in [[&"action_w", KEY_1], [&"action_a", KEY_2], [&"action_s", KEY_3], [&"action_d", KEY_4], [&"inventory_toggle", KEY_TAB]]:
		settings_manager().set_binding(pair[0], pair[1])
	var hud := level.get_node("HUD")
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	var hint: Label = hud.get_node("%MenuHint")
	var action_menu: CanvasLayer = level.get_node("ActionMenu")
	var menu_panel: Control = action_menu.get_node("%Panel")
	var bombs: int = game_state().inventory.get_quantity(BOMB)
	check(slot_bar.text == "1: Baseball Bat   2: Potion x2   3: Blast Bomb x%d   4: Slingshot" % bombs and hint.text == "Tab: action menu     Esc: pause",
			"the HUD names 1/2/3/4 and Tab", "%s | %s" % [slot_bar.text, hint.text])
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		check(visible_rect.encloses(slot_bar.get_global_rect()) and slot_bar.get_minimum_size().x <= slot_bar.size.x,
				label + ": the rebound slot bar is on screen and fits", slot_bar.text)
		check(visible_rect.encloses(hint.get_global_rect()) and hint.get_minimum_size().x <= hint.size.x
				and not hint.get_global_rect().intersects(slot_bar.get_global_rect()), label + ": the rebound hint is on screen, fits, clear of the slot bar")
		await tap_key(KEY_TAB)
		check(action_menu.is_open(), label + ": Tab opens the action menu")
		await process_frame
		var panel_rect := menu_panel.get_global_rect()
		var help: Label = action_menu.get_node("%HelpLabel")
		check(help.text == "Up/Down: choose an action     1/2/3/4: put it on that key     Tab/Esc: close"
				and panel_rect.encloses(help.get_global_rect()) and help.get_minimum_size().x <= help.size.x,
				label + ": the menu's help line names 1/2/3/4 and Tab, inside the panel", help.text)
		var slot_rows: Array = action_menu.get_node("%SlotList").get_children()
		check(slot_rows.size() == 4 and (slot_rows[0] as Label).text == "1   Baseball Bat"
				and slot_rows.all(func(row: Label) -> bool: return panel_rect.encloses(row.get_global_rect())),
				label + ": the slot column names 1/2/3/4, inside the panel", str(slot_rows.map(func(row: Label) -> String: return row.text)))
		var on_one := action_menu.get_node("%ActionList").get_children().filter(func(row: Label) -> bool: return row.text.contains("Baseball Bat   (on 1)"))
		check(on_one.size() == 1 and panel_rect.encloses((on_one[0] as Label).get_global_rect()), label + ": the Bat's row says \"(on 1)\"")
		await tap_key(KEY_TAB)
	settings_manager().reset_to_defaults()
	check(slot_bar.text.begins_with("W: Baseball Bat") and hint.text == "Space: action menu     Esc: pause", "defaults again: the HUD says W and Space")
	DisplayServer.window_set_size(WINDOW_SIZES[0])
	await wait_physics_frames(10)


## The Settings screen at each size: on screen and centred, every row inside it and fitting.
func _check_settings_layout(settings: Control, panel: Control, what: String) -> void:
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d %s" % [window_size.x, window_size.y, what]
		var visible_rect := root.get_visible_rect()
		var rect := panel.get_global_rect()
		check(settings.is_open() and visible_rect.encloses(rect) and rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
				label + ": the Settings screen is on screen and centred", str(rect))
		var labels: Array[Label] = []
		for row in settings.get_node("%Rows").get_children():
			if row is HBoxContainer:
				labels.append(row.get_child(0) as Label)
				labels.append(row.get_child(1) as Label)
			else:
				labels.append(row as Label)
		labels.append(settings.get_node("%MessageLabel") as Label)
		check(labels.size() == 21 and labels.all(func(row: Label) -> bool:
				return rect.encloses(row.get_global_rect()) and row.get_minimum_size().x <= row.size.x),
				label + ": its 9 controls with their keys, Reset to Defaults, Back and the message are inside it and fit",
				str(labels.filter(func(row: Label) -> bool: return not rect.encloses(row.get_global_rect()) or row.get_minimum_size().x > row.size.x).map(
						func(row: Label) -> String: return row.text)))


## Phase 10: on the current floor (Floor 7 since Phase 12) at each size, the pause menu (its three
## rows) and both of its questions (Return to Title, Quit Game: the warning text fits) are on screen
## and centred, drawn over the HUD. Then Return to Title through the menu: the title screen is on
## screen at each size and describes the Floor 7 checkpoint.
func _check_pause_menu() -> void:
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	var hud: CanvasLayer = current_scene.get_node("HUD")
	check(pause.layer > hud.layer and pause.layer > (current_scene.get_node("ActionMenu") as CanvasLayer).layer,
			"the pause menu is drawn above the HUD and the action menu")
	await tap_key(KEY_ESCAPE)
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var label := "%dx%d" % [window_size.x, window_size.y]
		var visible_rect := root.get_visible_rect()
		var panel_rect := (pause.get_node("%MenuPanel") as Control).get_global_rect()
		check(pause.is_open() and visible_rect.encloses(panel_rect) and panel_rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
				label + ": the pause menu is on screen and centred", str(panel_rect))
		for row_name: String in ["%ResumeRow", "%SettingsRow", "%ReturnToTitleRow", "%QuitRow"]:
			var row: Label = pause.get_node(row_name)
			check(panel_rect.encloses(row.get_global_rect()) and row.get_minimum_size().x <= row.size.x,
					"%s: %s \"%s\" is inside the panel and fits" % [label, row_name.trim_prefix("%"), row.text])
	# Past Settings (Phase 13, checked above) to Return to Title, then Quit Game.
	await tap_key(KEY_DOWN)
	for option: int in [2, 3]:
		await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		var question: Label = pause.get_node("%ConfirmQuestion")
		for window_size in WINDOW_SIZES:
			DisplayServer.window_set_size(window_size)
			await wait_physics_frames(10)
			var label := "%dx%d" % [window_size.x, window_size.y]
			var visible_rect := root.get_visible_rect()
			var panel_rect := (pause.get_node("%ConfirmPanel") as Control).get_global_rect()
			check(pause.is_confirming() and visible_rect.encloses(panel_rect) and panel_rect.get_center().distance_to(visible_rect.get_center()) < 2.0,
					"%s: the \"%s\" question is on screen and centred" % [label, question.text.get_slice("
", 0)], str(panel_rect))
			check(panel_rect.encloses(question.get_global_rect()) and question.get_minimum_size().x <= question.size.x
					and panel_rect.encloses((pause.get_node("%NoRow") as Control).get_global_rect())
					and panel_rect.encloses((pause.get_node("%YesRow") as Control).get_global_rect()),
					label + ": the warning, No and Yes fit inside it")
		await tap_key(KEY_ESCAPE)
	# Quit Game is selected now: Up, then Return to Title > Yes.
	await tap_key(KEY_UP)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if not await wait_for_scene(title_path):
		return
	for window_size in WINDOW_SIZES:
		DisplayServer.window_set_size(window_size)
		await wait_physics_frames(10)
		var visible_rect := root.get_visible_rect()
		var info: Label = current_scene.get_node("%SaveInfoLabel")
		check(visible_rect.encloses(info.get_global_rect()) and visible_rect.encloses(current_scene.get_node("%ContinueRow").get_global_rect())
				and visible_rect.encloses(current_scene.get_node("%QuitRow").get_global_rect()) and info.text.begins_with("Saved at the start of Floor 7"),
				"%dx%d: after Return to Title, the title is on screen and describes the Floor 7 checkpoint" % [window_size.x, window_size.y], info.text)
	DisplayServer.window_set_size(WINDOW_SIZES[0])


## A world-space Control's rectangle on screen (after the camera).
func _on_screen(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


## The title menu fits at every size. Floor 7 above saved the last checkpoint, so Continue is
## available and names Floor 7; a broken save file then shows the error message.
func _check_title_screen() -> void:
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	for broken_save in [false, true]:
		if broken_save:
			var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
			file.store_string("{broken")
			file.close()
			# Phase 13: a broken settings file too, so the title shows its message.
			var settings_file := FileAccess.open(settings_manager().settings_path, FileAccess.WRITE)
			settings_file.store_string("{broken")
			settings_file.close()
			settings_manager().load_settings()
		change_scene_to_file(title_path)
		await wait_for_scene(title_path)
		var title := current_scene
		check(title.is_continue_available() != broken_save, "title: Continue is %s" % ("unavailable with a broken save" if broken_save else "available"))
		if not broken_save:
			var info: String = title.get_node("%SaveInfoLabel").text
			check(info.begins_with("Saved at the start of Floor 7"), "title: the save is at the start of Floor 7", info)
		for window_size in WINDOW_SIZES:
			DisplayServer.window_set_size(window_size)
			await wait_physics_frames(10)
			var label := "title %dx%d%s" % [window_size.x, window_size.y, " (broken save)" if broken_save else ""]
			var visible_rect := root.get_visible_rect()
			for row_name: String in ["%ContinueRow", "%NewGameRow", "%SettingsRow", "%QuitRow", "%SaveInfoLabel", "%VersionLabel"]:
				check(visible_rect.encloses(title.get_node(row_name).get_global_rect()), "%s: %s is on screen" % [label, row_name.trim_prefix("%")])
			var rows: Array = ["%ContinueRow", "%NewGameRow", "%SettingsRow", "%QuitRow"].map(func(row_name: String) -> Rect2: return title.get_node(row_name).get_global_rect())
			check(rows[0].end.y <= rows[1].position.y and rows[1].end.y <= rows[2].position.y and rows[2].end.y <= rows[3].position.y
					and rows[3].end.y <= title.get_node("%SaveInfoLabel").get_global_rect().position.y,
					"%s: the four rows are stacked in order above the save line" % label, str(rows))
			var settings_info: Label = title.get_node("%SettingsInfoLabel")
			check(settings_info.visible == broken_save and (not broken_save or (visible_rect.encloses(settings_info.get_global_rect())
					and settings_info.text == "Control settings could not be loaded. Defaults restored.")),
					"%s: the settings line is %s" % [label, "on screen" if broken_save else "hidden"])
		# Quit Game selected (Up goes round to it from the first option), then back.
		await tap_key(KEY_UP)
		var quit_row: Label = title.get_node("%QuitRow")
		for window_size in WINDOW_SIZES:
			DisplayServer.window_set_size(window_size)
			await wait_physics_frames(10)
			check(quit_row.text == "> Quit Game" and root.get_visible_rect().encloses(quit_row.get_global_rect()),
					"title %dx%d%s: Quit Game selected, on screen" % [window_size.x, window_size.y, " (broken save)" if broken_save else ""], quit_row.text)
		await tap_key(KEY_DOWN)
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
