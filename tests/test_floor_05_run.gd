extends "res://tests/support/game_test.gd"
## Phase 8 end-to-end run on Floor 5, through the real title screen and levels, on this test's
## own save file:
## - A. Continue on a Floor 4 save (save_version 3: Carl 80/100, Donut 40/60, Slingshot on W,
##   a potion on A) opens Floor 4 with both HPs. Carl walks to Floor 4's new stairs (its enemies
##   are kept idle: their fights are test_floor_04_run.gd's) and arrives on Floor 5 with Donut:
##   Carl 80, Donut 40 carried over, the HUD, the sign, two Gelatinous Blobs and a Spitting Blob,
##   no exits, no transition loop, and the Floor 5 checkpoint (version 3, Donut 40) in memory and
##   on disk. Every level's exits lead one floor down; nothing leads up, not even from Floor 5.
##   The penned blob picks Donut, who is nearer to it than Carl, walks around the pen wall,
##   and fights her: her scratches kill it (10 each), its touches take 10 each from her; Carl is
##   never touched. Her damage changes neither the floor-entry state nor the save.
## - B. Carl down: GAME OVER freezes everything (Donut too) and waits for Enter; Donut being hurt
##   never caused it. The retry brings back Carl 80, Donut 40 and the enemies as authored.
## - C. Donut downed on Floor 5 (hurt first, then the penned blob's touch): no GAME OVER, the
##   HUD says DOWNED, she stays where she fell and does not scratch, and the blob turns on Carl.
##   The menu stops both her countdown and the enemies; she gets up exactly 6 s of play after
##   going down, with 30 / 60, and follows Carl again. Downed again, then Carl down: GAME OVER
##   holds her countdown however long it lasts; the retry brings her back at 40.
## - D. Quit and Continue: the title shows Floor 5; Continue opens it directly with Carl 80,
##   Donut 40, the Slingshot, the potion and the slots, the enemies as authored, and the penned
##   blob going for Donut again.
## - E. A Floor 4 save with Donut at 0: Continue starts her downed. Carl takes the stairs anyway
##   (no stair lock): Donut arrives on Floor 5 downed, the checkpoint says 0, enemies ignore her,
##   and she gets up after a fresh 6 s on Floor 5 (the time already spent downed on Floor 4
##   does not count), with 30 / 60; then the penned blob can pick her.
## - F. New Game after all this: the Surface with Carl at 100 and Donut at 60 / 60, not downed.
## Where it helps, hits are dealt through a Hurtbox, exactly as an enemy's attack would, so the
## run reaches a given HP quickly; the enemies' own attacks are covered by test_party_targeting.gd.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_05_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FLOOR_4_PATH := "res://scenes/levels/floor_04.tscn"
const FLOOR_5_PATH := "res://scenes/levels/floor_05.tscn"
const BLOB_PATH := "res://scenes/enemies/gelatinous_blob.tscn"
const SPITTER_PATH := "res://scenes/enemies/spitting_blob.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
## Where things are in floor_05.tscn.
const CARL_SPAWN := Vector2(176, 176)
const PEN_BLOB_SPAWN := Vector2(208, 416)
const BLOB_SPAWN := Vector2(656, 208)
const SPITTER_SPAWN := Vector2(1008, 320)
const PEN_WALL := Rect2(32, 320, 288, 32)
const ENTRY_CARL_HP := 80
const ENTRY_DONUT_HP := 40
const HUD_SLOTS := "W: Slingshot   A: Potion x1   S: —   D: Fists"
const DOWN_TICKS := 360


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_downward_only()
	if await _continue_on_floor_4(ENTRY_DONUT_HP) and await _floor_4_to_floor_5() and await _check_floor_5_arrival() \
			and await _penned_blob_fights_donut() and await _carl_down_and_retry() and await _donut_downed_on_floor_5() \
			and await _game_over_while_donut_is_downed() and await _continue_on_floor_5() \
			and await _stairs_while_donut_is_downed():
		await _new_game_resets_donut()
	finish()


func _check_downward_only() -> void:
	print("-- Every exit leads one floor down; Floor 5 has none")
	var expected := {
		SURFACE_PATH: [FLOOR_1_PATH], FLOOR_1_PATH: [FLOOR_2_PATH], FLOOR_2_PATH: [FLOOR_3_PATH],
		FLOOR_3_PATH: [FLOOR_4_PATH], FLOOR_4_PATH: [FLOOR_5_PATH], FLOOR_5_PATH: [],
	}
	for level_path: String in expected:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var destinations := _destinations(level)
		level.free()
		check(destinations == expected[level_path], "%s leads only to %s" % [level_path.get_file(), expected[level_path]],
				str(destinations))


## Title -> Continue on a version 3 Floor 4 save with Donut at `donut_health`.
func _continue_on_floor_4(donut_health: int) -> bool:
	print("-- Continue on a Floor 4 save: Carl %d, Donut %d" % [ENTRY_CARL_HP, donut_health])
	_write_save(JSON.stringify(_save_data("floor_04", ENTRY_CARL_HP, donut_health), "\t"))
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(current_scene.is_continue_available() and info == "Saved at the start of Floor 4  -  HP 80 / 100", "the title shows the Floor 4 save", info)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_4_PATH):
		return false
	await wait_physics_frames(3)
	var donut := _donut()
	check(_carl().health.current_health == ENTRY_CARL_HP and donut.health.current_health == donut_health and donut.health.max_health == 60
			and _hud_slots() == HUD_SLOTS, "Floor 4 opens with Carl %d, Donut %d / 60 and the slots" % [ENTRY_CARL_HP, donut_health], _hud_slots())
	check(donut.is_downed() == (donut_health == 0) and _hud_donut() == "Donut HP: %d / 60%s" % [donut_health, "  -  DOWNED" if donut_health == 0 else ""],
			"the HUD shows Donut's HP%s" % (" and that she is DOWNED" if donut_health == 0 else ""), _hud_donut())
	# Floor 4's own fights are test_floor_04_run.gd's; here its enemies stay idle.
	for enemy in _enemies():
		enemy.detection_range = 0.0
		enemy.chase_range = 0.0
	return true


func _floor_4_to_floor_5() -> bool:
	print("-- Floor 4 -> Floor 5")
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_5_PATH):
		return false
	await wait_physics_frames(3)
	return true


func _check_floor_5_arrival() -> bool:
	print("-- Floor 5 on arrival")
	var level := current_scene
	var carl := _carl()
	var donut := _donut()
	check(carl.global_position.distance_to(CARL_SPAWN) < 4.0, "Carl arrives at Floor 5's spawn point", str(carl.global_position))
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0, "Donut arrives next to Carl")
	check(carl.camera.get_screen_center_position().distance_to(carl.global_position) < 1.0, "the camera starts centred on Carl")
	check((level.get_node("Signs/FloorTitle") as Label).text == "Floor 5 - Holding Pens", "the Floor 5 sign")
	check(carl.health.current_health == ENTRY_CARL_HP and donut.health.current_health == ENTRY_DONUT_HP,
			"Carl keeps 80 HP and Donut 40: her HP carries over from Floor 4, unhealed")
	check(_hud_carl() == "Carl HP: 80 / 100" and _hud_donut() == "Donut HP: 40 / 60" and _hud_slots() == HUD_SLOTS,
			"the HUD shows both HPs and the slots", "%s | %s | %s" % [_hud_carl(), _hud_donut(), _hud_slots()])
	var blobs := _enemies(BLOB_PATH)
	var spitters := _enemies(SPITTER_PATH)
	check(blobs.size() == 2 and _near_spawn(_pen_blob(), PEN_BLOB_SPAWN) and _blob().global_position == BLOB_SPAWN,
			"Floor 5 has two Gelatinous Blobs (one in the pen)")
	check(spitters.size() == 1 and spitters[0].global_position == SPITTER_SPAWN, "and a Spitting Blob")
	check(_destinations(level).is_empty(), "Floor 5 has no exits: nothing leads back up to Floor 4")
	var entry = game_state().floor_entry
	check(entry.scene_path == FLOOR_5_PATH and entry.carl_health == ENTRY_CARL_HP and entry.donut_health == ENTRY_DONUT_HP
			and entry.donut_max_health == 60 and entry.inventory["items"].has(SLINGSHOT.id)
			and entry.action_slots == {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS},
			"Floor 5's entry state is recorded, with Donut's 40 HP")
	var save := _save()
	check(save == JSON.parse_string(JSON.stringify(_save_data("floor_05", ENTRY_CARL_HP, ENTRY_DONUT_HP))),
			"the Floor 5 checkpoint is saved: save_version 3, floor_05, Carl 80, Donut 40 / 60, the potion, the Slingshot, the slots",
			_save_text().replace("\n", " ").replace("\t", ""))
	var loaded: FloorEntry = save_manager().load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_5_PATH and loaded.donut_health == ENTRY_DONUT_HP, "it loads back as Floor 5 with Donut at 40")
	check(_pen_blob().target == donut and _blob().target == null and spitters[0].target == null,
			"the penned blob picks Donut (187 px from it) over Carl (242 px); the others wait")
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 5 (no transition loop)")
	return true


func _penned_blob_fights_donut() -> bool:
	print("-- The penned blob goes around its wall for Donut, and she fights back")
	var carl := _carl()
	var donut := _donut()
	var pen_blob := _pen_blob()
	var entry_save := _save_text()
	var donut_damage := []
	var blob_damage := []
	var blob_died := [false]
	donut.health.damaged.connect(func(amount: int) -> void: donut_damage.append(amount))
	pen_blob.health.damaged.connect(func(amount: int) -> void: blob_damage.append(amount))
	pen_blob.health.died.connect(func() -> void: blob_died[0] = true)
	var passed_wall_end := false
	var smallest_clearance := INF
	var ticks := 0
	while not blob_died[0] and not donut.is_downed() and ticks < 20 * 60:
		await physics_frame
		ticks += 1
		if not blob_died[0]:
			passed_wall_end = passed_wall_end or pen_blob.global_position.x > PEN_WALL.end.x
			smallest_clearance = minf(smallest_clearance, _distance_to_rect(pen_blob.global_position, PEN_WALL) - 13.0)
	check(passed_wall_end and smallest_clearance > -0.5, "it walks around the end of the pen wall without overlapping it")
	check(blob_died[0] and blob_damage == [10, 10, 10], "Donut scratches it to death: three scratches of 10", str(blob_damage))
	check(donut_damage.size() == 3 and donut_damage.all(func(amount: int) -> bool: return amount == 10) and donut.health.current_health == 10,
			"its touches take 10 each from Donut: 40 -> 10", str(donut_damage))
	check(carl.health.current_health == ENTRY_CARL_HP, "Carl, never its target, is untouched")
	check(game_state().donut_health == 10 and game_state().floor_entry.donut_health == ENTRY_DONUT_HP and _save_text() == entry_save,
			"the run knows Donut's 10 HP, but neither the floor-entry state nor the save changed")
	return true


func _carl_down_and_retry() -> bool:
	print("-- Carl down: GAME OVER, then retry")
	var donut := _donut()
	var donut_position := donut.global_position
	check(not paused and not _game_over_visible(), "Donut being hurt never caused GAME OVER")
	_carl().get_node("Hurtbox").take_hit(1000)
	await wait_physics_frames(2)
	check(paused and _game_over_visible(), "Carl at 0 HP: GAME OVER, the game is frozen")
	await wait_seconds(3.0)
	check(paused and _game_over_visible() and donut.global_position == donut_position and donut.health.current_health == 10,
			"3 s later it still waits for Enter; Donut has not moved")
	return await _retry_restores_entry()


## Presses Enter on GAME OVER and checks the Floor 5 entry state is back.
func _retry_restores_entry() -> bool:
	var entry_save := _save_text()
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_5_PATH):
		return false
	await wait_physics_frames(3)
	var donut := _donut()
	check(not paused and _carl().health.current_health == ENTRY_CARL_HP and donut.health.current_health == ENTRY_DONUT_HP
			and not donut.is_downed() and _hud_donut() == "Donut HP: 40 / 60" and _hud_slots() == HUD_SLOTS,
			"the retry brings back Carl 80 and Donut 40 (their Floor 5 entry HP) and the slots", _hud_donut())
	check(_pen_blob() != null and _near_spawn(_pen_blob(), PEN_BLOB_SPAWN) and _pen_blob().health.current_health == 30
			and _blob().global_position == BLOB_SPAWN and _enemies(SPITTER_PATH)[0].global_position == SPITTER_SPAWN,
			"and all three enemies as authored")
	check(_save_text() == entry_save, "the retry saves the same checkpoint again")
	return true


func _donut_downed_on_floor_5() -> bool:
	print("-- Donut downed on Floor 5")
	var carl := _carl()
	var donut := _donut()
	var pen_blob := _pen_blob()
	# She has been hurt before (30 HP gone), so the penned blob's touch downs her.
	donut.get_node("Hurtbox").take_hit(30)
	var downed_at := [-1]
	var revived_at := [-1]
	donut.health.died.connect(func() -> void: downed_at[0] = Engine.get_physics_frames())
	donut.health.health_changed.connect(func(current: int, _maximum: int) -> void:
		if current > 0 and downed_at[0] >= 0 and revived_at[0] < 0:
			revived_at[0] = Engine.get_physics_frames())
	var scratches := [0]
	donut.scratch.performed.connect(func(_d: Vector2, _h: int) -> void: scratches[0] += 1)
	if not await wait_until(func() -> bool: return donut.is_downed(), "the penned blob to down Donut", 20 * 60):
		return false
	var fell_at := donut.global_position
	var scratches_when_downed: int = scratches[0]
	await wait_physics_frames(2)
	check(not paused and not _game_over_visible(), "Donut at 0 HP: no GAME OVER, the game goes on")
	check(_hud_donut() == "Donut HP: 0 / 60  -  DOWNED" and donut.downed_label.visible, "the HUD and her label say DOWNED", _hud_donut())
	check(pen_blob.health.current_health > 0 and pen_blob.target == carl, "the blob drops her and turns on Carl")
	# Carl punches it when it comes (it approaches from Donut's side: south).
	await wait_until(func() -> bool: return pen_blob.global_position.distance_to(carl.global_position) < 40.0, "the blob to reach Carl", 300)
	send_key(KEY_D, true)
	await wait_until(func() -> bool: return pen_blob.health.is_dead(), "Carl to punch the blob to death", 180)
	send_key(KEY_D, false)
	check(pen_blob.health.is_dead(), "Carl punches it to death (Fists on D)")
	check(donut.global_position == fell_at and scratches[0] == scratches_when_downed,
			"downed, Donut stayed where she fell and did not scratch the blob right beside her")

	# The menu freezes her countdown and the enemies.
	var ticks_downed: int = Engine.get_physics_frames() - downed_at[0]
	current_scene.get_node("ActionMenu").open()
	var blob_position := _blob().global_position
	await wait_physics_frames(120)
	check(paused and donut.is_downed() and _blob().global_position == blob_position, "2 s with the menu open: nothing moves")
	current_scene.get_node("ActionMenu").close()
	await wait_until(func() -> bool: return revived_at[0] >= 0, "Donut to get up", DOWN_TICKS)
	check(revived_at[0] - downed_at[0] - 120 in [DOWN_TICKS - 1, DOWN_TICKS],
			"she gets up after 6 s of play: the 2 s in the menu did not count",
			"%d ticks after going down (%d before the menu)" % [revived_at[0] - downed_at[0], ticks_downed])
	check(donut.health.current_health == 30 and _hud_donut() == "Donut HP: 30 / 60" and not donut.downed_label.visible,
			"she gets up with 30 / 60", _hud_donut())
	await hold_keys([KEY_RIGHT], 80)
	await wait_seconds(1.5)
	check(donut.global_position.distance_to(carl.global_position) < 75.0 and donut.global_position.distance_to(fell_at) > 100.0,
			"and follows Carl again", "%.0f px from Carl" % donut.global_position.distance_to(carl.global_position))
	return true


func _game_over_while_donut_is_downed() -> bool:
	print("-- GAME OVER while Donut is downed")
	var donut := _donut()
	donut.get_node("Hurtbox").take_hit(100)
	await wait_physics_frames(60)
	_carl().get_node("Hurtbox").take_hit(1000)
	await wait_physics_frames(2)
	check(paused and _game_over_visible() and donut.is_downed(), "Carl down: GAME OVER, with Donut downed")
	await wait_seconds(7.0)
	check(donut.is_downed() and donut.get_recovery_time_left() > 4.9, "7 s of GAME OVER later she is still downed: her countdown is frozen",
			"%.2f s left" % donut.get_recovery_time_left())
	return await _retry_restores_entry()


func _continue_on_floor_5() -> bool:
	print("-- Quit and Continue on Floor 5")
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(current_scene.is_continue_available() and info == "Saved at the start of Floor 5  -  HP 80 / 100", "the title shows the Floor 5 save", info)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_5_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	var donut := _donut()
	check(_carl().health.current_health == ENTRY_CARL_HP and donut.health.current_health == ENTRY_DONUT_HP and not donut.is_downed()
			and state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 1 and _hud_slots() == HUD_SLOTS,
			"Continue opens Floor 5 directly: Carl 80, Donut 40 / 60, the Slingshot on W, the potion on A, Fists on D")
	check(_near_spawn(_pen_blob(), PEN_BLOB_SPAWN) and _blob().global_position == BLOB_SPAWN
			and _enemies(SPITTER_PATH).size() == 1, "the enemies are there as authored")
	check(_pen_blob().target == donut, "and the penned blob goes for Donut again")
	return true


func _stairs_while_donut_is_downed() -> bool:
	print("-- Floor 4 -> Floor 5 with Donut downed")
	if not await _continue_on_floor_4(0):
		return false
	await wait_seconds(4.0)
	check(_donut().is_downed(), "4 s later she is still downed")
	var stairs: Node2D = current_scene.get_node("Stairs")
	# Straight to the stairs, before she gets up: nothing stops Carl.
	_carl().teleport_to(stairs.global_position + Vector2(-70, 0))
	await wait_physics_frames(2)
	await walk_to(stairs.global_position)
	if not await wait_for_scene(FLOOR_5_PATH):
		return false
	var arrived_at := Engine.get_physics_frames()
	await wait_physics_frames(2)
	var donut := _donut()
	check(donut.is_downed() and donut.health.current_health == 0 and _hud_donut() == "Donut HP: 0 / 60  -  DOWNED",
			"the stairs work while Donut is downed: she arrives on Floor 5 downed", _hud_donut())
	check(donut.global_position.distance_to(_carl().global_position) < 120.0, "she arrives next to Carl, as always")
	check(game_state().floor_entry.donut_health == 0 and _save().get("donut") == {"health": 0.0, "max_health": 60.0},
			"the Floor 5 checkpoint records Donut at 0")
	await wait_seconds(5.0)
	check(donut.is_downed() and _pen_blob().target == null, "5 s after arriving she is still downed: a fresh 6 s; the penned blob ignores her")
	await wait_until(func() -> bool: return not donut.is_downed(), "Donut to get up on Floor 5", 90)
	var ticks_on_floor_5 := Engine.get_physics_frames() - arrived_at
	check(ticks_on_floor_5 >= DOWN_TICKS - 1 and ticks_on_floor_5 <= DOWN_TICKS + 2 and donut.health.current_health == 30,
			"she gets up 6 s after arriving on Floor 5, with 30 / 60", "%d ticks" % ticks_on_floor_5)
	await wait_physics_frames(2)
	check(_pen_blob().target == donut, "now the penned blob can pick her")
	return true


func _new_game_resets_donut() -> void:
	print("-- New Game")
	if not await _open_title():
		return
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return
	await wait_physics_frames(3)
	var state := game_state()
	var donut := _donut()
	check(_carl().health.current_health == 100 and donut.health.current_health == 60 and donut.health.max_health == 60 and not donut.is_downed()
			and state.donut_health == 60 and _hud_donut() == "Donut HP: 60 / 60",
			"New Game: the Surface with Carl at 100 and Donut at 60 / 60, not downed", _hud_donut())
	check(not state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 0 and _hud_slots() == "W: —   A: —   S: —   D: Fists",
			"no items, Fists on D")
	check(_save().get("floor_id") == "surface" and _save().get("save_version") == 3.0 and _save().get("donut") == {"health": 60.0, "max_health": 60.0},
			"its Surface checkpoint (version 3) has Donut at 60 / 60")


## Version 3 save data: Carl `carl_health`/100, Donut `donut_health`/60, a potion on A, the
## Slingshot on W, Fists on D.
func _save_data(floor_id: String, carl_health: int, donut_health: int) -> Dictionary:
	return {
		"save_version": 3, "floor_id": floor_id,
		"carl": {"health": carl_health, "max_health": 100},
		"donut": {"health": donut_health, "max_health": 60},
		"inventory": {"small_health_potion": 1}, "owned_items": ["slingshot"],
		"action_slots": {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": null, "action_d": "fists"},
	}


func _open_title() -> bool:
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	paused = false
	change_scene_to_file(title_path)
	if not await wait_for_scene(title_path):
		return false
	await wait_physics_frames(2)
	return true


## Where every exit of `level` leads.
func _destinations(level: Node) -> Array:
	var destinations := []
	for node in level.find_children("*", "Area2D", true, false):
		if node.get_script() == preload("res://scripts/props/stairs.gd"):
			destinations.append(node.destination_scene_path)
	return destinations


func _enemies(scene_path: String = "") -> Array:
	return current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool:
		return node is Enemy and (scene_path.is_empty() or node.scene_file_path == scene_path))


## True if `enemy` is where the level placed it. The penned blob goes for Donut from the first
## tick, so a few ticks after a level starts it may already have moved a few pixels.
func _near_spawn(enemy: Node2D, spawn: Vector2) -> bool:
	return enemy != null and enemy.global_position.distance_to(spawn) < 6.0


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position, rect.end))


func _write_save(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(save_manager().save_path.get_base_dir())
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _save() -> Dictionary:
	var data: Variant = JSON.parse_string(_save_text())
	return data if data is Dictionary else {}


func _game_over_visible() -> bool:
	return current_scene.get_node("HUD/%GameOverMessage").visible


func _hud_carl() -> String:
	return current_scene.get_node("HUD/%HealthLabel").text


func _hud_donut() -> String:
	return current_scene.get_node("HUD/%DonutHealthLabel").text


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _donut() -> CharacterBody2D:
	return current_scene.get_node("Actors/Donut")


func _pen_blob() -> Enemy:
	return current_scene.get_node_or_null("Actors/PenBlob")


func _blob() -> Enemy:
	return current_scene.get_node_or_null("Actors/GelatinousBlob")
