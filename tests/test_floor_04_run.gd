extends "res://tests/support/game_test.gd"
## Phase 7 end-to-end run on Floor 4, through the real title screen and levels, on this test's
## own save file. It starts from a real Phase 6 save (tests/fixtures/phase6_save_v2_floor_03.json:
## Floor 3, 70/100 HP, Slingshot on W, 2 potions on S, Fists on D).
## - Title -> Continue opens Floor 3 with that state; the save it writes on entry holds the same
##   values, as save_version 3 with Donut at full health (Phase 8 migration).
## - Every level's exits lead one floor down: Floor 4's only exit leads to Floor 5 (Phase 8), and
##   Floor 5 has none (downward-only).
## - Floor 3 -> Floor 4: Carl, Donut and the camera arrive, with no transition loop. Floor 4 has
##   its sign, a Gelatinous Blob and a Spitting Blob, and walls that matter: the straight line from
##   the blob to Carl's side is blocked, and wall B hides the approach from the Spitting Blob.
## - The Floor 4 checkpoint is recorded and saved (floor_04, save_version 3 since Phase 8,
##   Slingshot owned, Donut's HP).
## - The blob walks around wall A to Carl; Fists kill it.
## - The Spitting Blob, hidden behind wall B, walks around it and spits only when it can see Carl;
##   each glob takes 10 HP. The menu freezes it and its glob.
## - Its globs take Carl to 0 HP: GAME OVER waits for Enter, with everything frozen and nothing
##   more spat. A second GAME OVER with a glob in flight freezes that glob. Each retry brings back
##   the Floor 4 entry state and the enemies as authored, with no globs left.
## - Three Slingshot stones kill the Spitting Blob.
## - Quit and Continue: the title shows Floor 4; Continue opens Floor 4 directly with the saved HP,
##   potions, Slingshot and slots, the enemies back as authored; the Spitting Blob's globs still
##   hurt Carl. Nothing during play changes the save.
## - New Game over the Floor 4 save starts clean on the Surface.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_04_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const PHASE_6_FLOOR_3_SAVE := "res://tests/fixtures/phase6_save_v2_floor_03.json"
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
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const S := ActionSlots.SLOT_S
const D := ActionSlots.SLOT_D
## Where things are in floor_04.tscn.
const FLOOR_4_CARL_SPAWN := Vector2(160, 320)
const FLOOR_4_BLOB_SPAWN := Vector2(512, 320)
const FLOOR_4_SPITTER_SPAWN := Vector2(896, 320)
const WALL_A := Rect2(352, 224, 64, 192)
const WALL_B := Rect2(736, 224, 64, 192)
## West of wall A, where the blob notices Carl; and between the walls, where the Spitting Blob does.
const WEST_OF_WALL_A := Vector2(300, 320)
const WEST_OF_WALL_B := Vector2(560, 320)
## A way along the north wall, out of the blob's reach (more than 220 px from it), to a spot where
## the Spitting Blob notices Carl (within 360 px) and sees him over wall B.
const NORTH_ROUTE: Array[Vector2] = [Vector2(160, 50), Vector2(700, 50)]
const ENTRY_HP := 70
const HUD_SLOTS := "W: Slingshot   A: —   S: Potion x2   D: Fists"
const ENEMY_RADIUS := 13.0

var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")
## The save text right after entering Floor 4.
var _floor_4_save := ""


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	for step: Callable in [_continue_phase_6_save, _check_downward_only, _floor_3_to_floor_4, _check_floor_4,
			_blob_goes_around_wall_a, _spitter_goes_around_wall_b, _spit_to_game_over, _retry_restores_floor_4,
			_game_over_freezes_a_glob_in_flight, _retry_restores_floor_4, _slingshot_kills_the_spitter,
			_continue_on_floor_4, _new_game_over_floor_4]:
		if not await step.call():
			break
	finish()


func _continue_phase_6_save() -> bool:
	print("-- A Phase 6 save: title -> Continue -> Floor 3")
	var fixture := FileAccess.get_file_as_string(PHASE_6_FLOOR_3_SAVE)
	_write_save(fixture)
	if not await _open_title():
		return false
	check(current_scene.is_continue_available(), "the title offers Continue for the Phase 6 save")
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of Floor 3  -  HP 70 / 100", "it shows Floor 3, 70 HP", info)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_3_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	check(_carl().health.current_health == ENTRY_HP and state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 2
			and state.action_slots.get_action(W) == SLINGSHOT and state.action_slots.get_action(S) == POTION
			and state.action_slots.get_action(D) == FISTS and state.action_slots.get_action(A) == null,
			"Floor 3 opens with 70 HP, the Slingshot on W, 2 potions on S and Fists on D")
	var migrated: Dictionary = JSON.parse_string(fixture)
	migrated["save_version"] = 3
	migrated["donut"] = {"health": 60, "max_health": 60}
	check(JSON.parse_string(_save_text()) == JSON.parse_string(JSON.stringify(migrated)),
			"entering Floor 3 saves the same checkpoint as save_version 3, with Donut at 60 / 60", _save_text())
	return true


func _check_downward_only() -> bool:
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
	return true


func _floor_3_to_floor_4() -> bool:
	print("-- Floor 3 -> Floor 4")
	# Along the south wall, out of the Floor 3 blobs' reach, then onto the stairs.
	await walk_to(Vector2(160, 580))
	await walk_to(Vector2(900, 580))
	check(_carl().health.current_health == ENTRY_HP, "Carl reaches the Floor 3 stairs unhurt")
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_4_PATH):
		return false
	await wait_physics_frames(3)
	return true


func _check_floor_4() -> bool:
	print("-- Floor 4 on arrival")
	var level := current_scene
	var carl := _carl()
	var donut: CharacterBody2D = level.get_node("Actors/Donut")
	check(carl.global_position.distance_to(FLOOR_4_CARL_SPAWN) < 4.0, "Carl arrives at Floor 4's spawn point", str(carl.global_position))
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0,
			"Donut arrives next to Carl and follows him")
	check(carl.camera.get_screen_center_position().distance_to(carl.global_position) < 1.0, "the camera starts centred on Carl")
	check((level.get_node("Signs/FloorTitle") as Label).text == "Floor 4 - Filtration Level", "the Floor 4 sign")
	var blobs := _enemies(BLOB_PATH)
	var spitters := _enemies(SPITTER_PATH)
	check(blobs.size() == 1 and blobs[0].global_position == FLOOR_4_BLOB_SPAWN, "Floor 4 has a Gelatinous Blob")
	check(spitters.size() == 1 and spitters[0].global_position == FLOOR_4_SPITTER_SPAWN, "Floor 4 has a Spitting Blob")
	check(_destinations(level) == [FLOOR_5_PATH], "Floor 4's only exit leads down to Floor 5: nothing leads back up to Floor 3",
			str(_destinations(level)))

	var state := game_state()
	check(carl.health.current_health == ENTRY_HP and state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 2
			and _hud_slots() == HUD_SLOTS, "Carl keeps 70 HP, the Slingshot on W, 2 potions on S and Fists on D", _hud_slots())
	var entry = state.floor_entry
	check(entry.scene_path == FLOOR_4_PATH and entry.carl_health == ENTRY_HP and entry.inventory["items"].has(SLINGSHOT.id)
			and entry.action_slots == {W: SLINGSHOT, S: POTION, D: FISTS}, "Floor 4's entry state is recorded")
	var save := _save()
	check(save.get("save_version") == 3.0 and save.get("floor_id") == "floor_04" and save["carl"]["health"] == float(ENTRY_HP)
			and save.get("donut") == {"health": 60.0, "max_health": 60.0}
			and save.get("owned_items") == ["slingshot"] and save.get("inventory") == {"small_health_potion": 2.0}
			and save.get("action_slots") == {"action_w": "slingshot", "action_a": null, "action_s": "small_health_potion", "action_d": "fists"},
			"the Floor 4 checkpoint is saved: floor_04, save_version 3, HP (Carl's and Donut's), potions, Slingshot, slots",
			_save_text().replace("\n", " ").replace("\t", ""))
	_floor_4_save = _save_text()
	var loaded: FloorEntry = save_manager().load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_4_PATH, "the save loads back as Floor 4", save_manager().last_error)

	if not await _wait_for_floor_4_navigation():
		return false
	var blob_route := await navigation_route(FLOOR_4_BLOB_SPAWN, WEST_OF_WALL_A)
	check(not _is_clear(FLOOR_4_BLOB_SPAWN, WEST_OF_WALL_A) and blob_route.size() >= 3,
			"wall A blocks the straight line from the blob to Carl's side, and the route bends around it", str(blob_route))
	check(not _is_clear(FLOOR_4_SPITTER_SPAWN, WEST_OF_WALL_B),
			"wall B hides the approach between the walls from the Spitting Blob")
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 4 (no transition loop)")
	check(not blobs[0].is_active() and not spitters[0].is_active() and blobs[0].global_position == FLOOR_4_BLOB_SPAWN
			and spitters[0].global_position == FLOOR_4_SPITTER_SPAWN, "both enemies wait while Carl is at the spawn point")
	return true


func _blob_goes_around_wall_a() -> bool:
	print("-- Floor 4: the blob walks around wall A; Fists kill it")
	var carl := _carl()
	var blob: Enemy = _enemies(BLOB_PATH)[0]
	await walk_to(WEST_OF_WALL_A)
	var smallest_clearance := INF
	var passed_wall_end := false
	for i in 12 * Engine.physics_ticks_per_second:
		await physics_frame
		smallest_clearance = minf(smallest_clearance, _distance_to_rect(blob.global_position, WALL_A) - ENEMY_RADIUS)
		passed_wall_end = passed_wall_end or (blob.global_position.x > WALL_A.position.x - 16 and blob.global_position.x < WALL_A.end.x + 16
				and (blob.global_position.y < WALL_A.position.y or blob.global_position.y > WALL_A.end.y))
		if blob.global_position.distance_to(carl.global_position) <= 26.0:
			break
	check(blob.is_active() and passed_wall_end and blob.global_position.distance_to(carl.global_position) <= 26.0,
			"the blob notices Carl, walks around the end of wall A and reaches him", str(blob.global_position))
	check(smallest_clearance > -0.5, "it never overlaps the wall", "closest %.2f px" % smallest_clearance)
	await _face(blob.global_position)
	var damage := []
	blob.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	await hold_keys([KEY_D], 60)
	await wait_physics_frames(2)
	check(damage == [10, 10, 10] and blob.health.is_dead(), "three punches (Fists on D) kill it", str(damage))
	check(carl.health.current_health >= 40, "Carl took a few touches", "HP %d" % carl.health.current_health)
	await wait_seconds(1.0)
	return true


func _spitter_goes_around_wall_b() -> bool:
	print("-- Floor 4: the Spitting Blob walks around wall B and spits once it sees Carl")
	var carl := _carl()
	var spitter: Enemy = _enemies(SPITTER_PATH)[0]
	await walk_to(WEST_OF_WALL_B)
	var shots := _record_shots(spitter)
	var damage := []
	carl.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	check(spitter.is_active() and not spitter.has_line_of_sight_to(carl.global_position),
			"Carl between the walls: the Spitting Blob notices him, but wall B is in the way")
	var smallest_clearance := INF
	for i in 10 * Engine.physics_ticks_per_second:
		await physics_frame
		smallest_clearance = minf(smallest_clearance, _distance_to_rect(spitter.global_position, WALL_B) - ENEMY_RADIUS)
		if not shots.is_empty():
			break
	check(shots.size() == 1 and shots[0]["in_sight"], "it walks around wall B and spits once it can see Carl")
	check(smallest_clearance > -0.5, "it never overlaps wall B", "closest %.2f px" % smallest_clearance)
	if shots.is_empty():
		return false

	# The menu freezes the Spitting Blob and its glob in flight.
	await wait_physics_frames(10)
	var glob: Projectile = shots[0]["glob"]
	await tap_key(KEY_SPACE)
	var frozen := [spitter.global_position, glob.global_position if is_instance_valid(glob) else Vector2.INF]
	var hp: int = carl.health.current_health
	await wait_seconds(2.0)
	check(paused and is_instance_valid(glob) and glob.global_position == frozen[1] and spitter.global_position == frozen[0]
			and shots.size() == 1 and carl.health.current_health == hp,
			"with the menu open, the Spitting Blob and its glob freeze and nothing is spat")
	await tap_key(KEY_SPACE)
	await wait_until(func() -> bool: return carl.health.current_health < hp, "the glob to arrive", 90)
	check(not paused and carl.health.current_health == hp - 10 and damage == [10], "after the menu closes, the glob hits Carl: exactly 10 HP",
			str(damage))
	return true


func _spit_to_game_over() -> bool:
	print("-- Floor 4: the Spitting Blob's globs defeat Carl")
	var level := current_scene
	var carl := _carl()
	var spitter: Enemy = _enemies(SPITTER_PATH)[0]
	var shots := _record_shots(spitter)
	var save_before := _save_text()
	await wait_until(func() -> bool: return carl.health.is_dead(), "Carl to be defeated by globs", 20 * Engine.physics_ticks_per_second)
	check(carl.health.current_health == 0 and shots.all(func(shot: Dictionary) -> bool: return shot["in_sight"]),
			"globs take Carl to 0 HP, every one spat with Carl in plain sight", "%d globs" % shots.size())
	var game_over: Control = level.get_node("HUD/%GameOverMessage")
	check(paused and game_over.visible, "GAME OVER: the game is frozen")
	var spitter_position := spitter.global_position
	var shot_count := shots.size()
	await wait_seconds(3.0)
	check(spitter.global_position == spitter_position and shots.size() == shot_count and carl.health.current_health == 0,
			"3 s later the Spitting Blob has not moved or spat, and Carl takes nothing more")
	check(current_scene == level and paused and game_over.visible, "GAME OVER stays until Enter")
	check(_save_text() == save_before, "death does not write the save")
	return true


func _game_over_freezes_a_glob_in_flight() -> bool:
	print("-- Floor 4: GAME OVER with a glob in flight")
	var level := current_scene
	var carl := _carl()
	var spitter: Enemy = _enemies(SPITTER_PATH)[0]
	await walk_to(WEST_OF_WALL_B)
	var shots := _record_shots(spitter)
	await wait_until(func() -> bool: return not shots.is_empty(), "a glob", 10 * Engine.physics_ticks_per_second)
	await wait_physics_frames(5)
	var glob: Projectile = shots[0]["glob"] if not shots.is_empty() else null
	if glob == null or not is_instance_valid(glob):
		check(false, "a glob is in flight")
		return false
	carl.health.take_damage(1000)
	await wait_physics_frames(2)
	var frozen_at := glob.global_position
	await wait_seconds(2.0)
	check(paused and level.get_node("HUD/%GameOverMessage").visible, "GAME OVER")
	check(is_instance_valid(glob) and glob.global_position == frozen_at and shots.size() == 1,
			"the glob in flight stops where it was, and nothing more is spat")
	return true


func _retry_restores_floor_4() -> bool:
	print("-- Enter retries Floor 4 from its entry state")
	var old_level_id := current_scene.get_instance_id()
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != old_level_id:
			break
		await physics_frame
	if not await wait_for_scene(FLOOR_4_PATH):
		return false
	await wait_physics_frames(3)
	var level := current_scene
	var state := game_state()
	check(level.get_instance_id() != old_level_id and not paused, "Floor 4 is loaded again and runs")
	check(_carl().health.current_health == ENTRY_HP and _carl().global_position.distance_to(FLOOR_4_CARL_SPAWN) < 1.0,
			"Carl is back at the spawn point with his Floor 4 entry HP (70)")
	check(state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 2 and _hud_slots() == HUD_SLOTS,
			"the Slingshot on W, 2 potions on S and Fists on D", _hud_slots())
	var blobs := _enemies(BLOB_PATH)
	var spitters := _enemies(SPITTER_PATH)
	check(blobs.size() == 1 and blobs[0].global_position == FLOOR_4_BLOB_SPAWN and blobs[0].health.current_health == 30
			and spitters.size() == 1 and spitters[0].global_position == FLOOR_4_SPITTER_SPAWN and spitters[0].health.current_health == 30
			and not spitters[0].is_active(), "both enemies are back where they started, at full health")
	check(level.find_children("*", "Projectile", true, false).is_empty(), "no globs are left over")
	check(level.get_node("Actors/Donut").global_position.distance_to(_carl().global_position) < 120.0, "Donut is back next to Carl")
	check(_save_text() == _floor_4_save, "the save still holds the Floor 4 checkpoint")
	return await _wait_for_floor_4_navigation()


func _slingshot_kills_the_spitter() -> bool:
	print("-- Floor 4: three Slingshot stones kill the Spitting Blob")
	var carl := _carl()
	var spitter: Enemy = _enemies(SPITTER_PATH)[0]
	var blob: Enemy = _enemies(BLOB_PATH)[0]
	for point in NORTH_ROUTE:
		await walk_to(point)
	# Shoot once it has come within range and stopped there.
	await wait_until(func() -> bool:
		return spitter.is_active() and spitter.velocity == Vector2.ZERO and spitter.has_line_of_sight_to(carl.global_position),
		"the Spitting Blob to settle within sight", 10 * Engine.physics_ticks_per_second)
	check(not blob.is_active(), "the Gelatinous Blob never noticed Carl on the way")
	await _face(spitter.global_position)
	var damage := []
	spitter.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	var stones := []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	await hold_keys([KEY_W], 80)
	await wait_until(func() -> bool: return spitter.health.is_dead(), "the Spitting Blob to die", 60)
	check(stones.size() == 3 and damage == [10, 10, 10] and spitter.health.is_dead(),
			"three stones, 10 damage each, kill it", "%d stones, damage %s" % [stones.size(), damage])
	check(game_state().inventory.has(SLINGSHOT) and _save_text() == _floor_4_save, "the Slingshot is not used up, and fighting never saves")
	return true


func _continue_on_floor_4() -> bool:
	print("-- Quit and Continue on Floor 4")
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of Floor 4  -  HP 70 / 100", "the title shows Floor 4", info)
	await tap_key(KEY_ENTER)
	# The first level to appear must be Floor 4 itself: no earlier floor is replayed.
	for i in 120:
		if current_scene != null and current_scene.scene_file_path != _title_path:
			break
		await physics_frame
	check(current_scene != null and current_scene.scene_file_path == FLOOR_4_PATH, "Continue opens Floor 4 directly")
	if not await wait_for_scene(FLOOR_4_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	var carl := _carl()
	check(carl.health.current_health == ENTRY_HP, "HP 70 is restored")
	check(state.inventory.get_quantity(POTION) == 2 and state.inventory.has(SLINGSHOT) and state.inventory.get_actions() == [FISTS, POTION, SLINGSHOT],
			"2 potions and the Slingshot are restored, nothing duplicated", str(state.inventory.get_actions()))
	check(state.action_slots.get_action(W) == SLINGSHOT and state.action_slots.get_action(A) == null
			and state.action_slots.get_action(S) == POTION and state.action_slots.get_action(D) == FISTS and _hud_slots() == HUD_SLOTS,
			"W = Slingshot, A empty, S = potion, D = Fists", _hud_slots())
	check(current_scene.get_node("Actors/Donut").global_position.distance_to(carl.global_position) < 120.0, "Donut is there")
	var blobs := _enemies(BLOB_PATH)
	var spitters := _enemies(SPITTER_PATH)
	check(blobs.size() == 1 and blobs[0].global_position == FLOOR_4_BLOB_SPAWN and blobs[0].health.current_health == 30
			and spitters.size() == 1 and spitters[0].global_position == FLOOR_4_SPITTER_SPAWN and spitters[0].health.current_health == 30,
			"both enemies (killed before quitting) are back as authored: nothing mid-floor was saved")
	check(_save_text() == _floor_4_save, "Continue saved the same Floor 4 checkpoint again")
	if not await _wait_for_floor_4_navigation():
		return false

	var globs_on_carl := [0]
	var carl_hurtbox := carl.get_node("Hurtbox")
	(spitters[0] as Enemy).spit_launcher.fired.connect(func(glob: Projectile) -> void:
		glob.stopped.connect(func(collider: Object) -> void:
			if collider == carl_hurtbox:
				globs_on_carl[0] += 1))
	for point in NORTH_ROUTE:
		await walk_to(point)
	await wait_until(func() -> bool: return carl.health.current_health < ENTRY_HP, "a glob to hit Carl", 10 * Engine.physics_ticks_per_second)
	check(carl.health.current_health == ENTRY_HP - 10 and globs_on_carl[0] == 1 and not blobs[0].is_active(),
			"after Continue the Spitting Blob spits at Carl, and its glob takes 10 HP", "HP %d, %d globs" % [carl.health.current_health, globs_on_carl[0]])
	return true


func _new_game_over_floor_4() -> bool:
	print("-- New Game over the Floor 4 save")
	if not await _open_title():
		return false
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(current_scene.is_confirming(), "New Game asks first, because a save exists")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	check(_carl().health.current_health == 100 and state.inventory.get_actions() == [FISTS] and _hud_slots() == "W: —   A: —   S: —   D: Fists",
			"the new game: 100 HP, no potions, no Slingshot, W/A/S empty, D = Fists", _hud_slots())
	check(_save().get("floor_id") == "surface" and _save().get("owned_items") == [] and _save().get("save_version") == 3.0
			and _save().get("donut") == {"health": 60.0, "max_health": 60.0},
			"its Surface checkpoint replaces the Floor 4 save")
	return true


## Waits until the navigation map holds Floor 4's own mesh (see build_navigation_arena()): a route
## from the Spitting Blob's spawn to just west of wall B must go around wall B, which no other
## level has there.
func _wait_for_floor_4_navigation() -> bool:
	var map := root.world_2d.navigation_map
	var west_of_b := Vector2(WALL_B.position.x - 30, WALL_B.get_center().y)
	return await wait_until(func() -> bool:
		var route := NavigationServer2D.map_get_path(map, FLOOR_4_SPITTER_SPAWN, west_of_b, true)
		return route.size() >= 3, "Floor 4's navigation mesh")


## Turns Carl toward `point` (one tick of the arrow keys that way).
func _face(point: Vector2) -> void:
	steer(_carl().global_position.direction_to(point))
	await physics_frame
	steer(Vector2.ZERO)
	await physics_frame


## Records every glob `spitter` spits as {"glob", "in_sight" (could it see Carl then)}.
func _record_shots(spitter: Enemy) -> Array:
	var shots := []
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void:
		shots.append({"glob": glob, "in_sight": spitter.has_line_of_sight_to(spitter.target.global_position)}))
	return shots


func _enemies(scene_path: String) -> Array:
	return current_scene.get_node("Actors").get_children().filter(
			func(node: Node) -> bool: return node.scene_file_path == scene_path)


## Where every exit of `level` leads.
func _destinations(level: Node) -> Array:
	return level.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node).map(
			func(node: Node) -> String: return node.destination_scene_path)


func _is_clear(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return root.world_2d.direct_space_state.intersect_ray(query).is_empty()


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position, rect.end))


func _open_title() -> bool:
	change_scene_to_file(_title_path)
	if not await wait_for_scene(_title_path):
		return false
	await wait_physics_frames(2)
	return true


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


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")
