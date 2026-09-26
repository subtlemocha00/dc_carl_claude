extends "res://tests/support/game_test.gd"
## Phase 12 end-to-end run: Floor 6's Blast Bomb drop and Floor 7, through the real title screen
## and levels, on this test's own save file:
## - Every level's exits lead one floor down (Floor 6's to Floor 7); Floor 7 has none; floor_07 is
##   registered as "Floor 7".
## - A. Continue on a real Phase 11 save (tests/fixtures/phase11_save_v3_floor_06.json: version 3,
##   Floor 6, Carl 80, Donut 40, Slingshot W, a potion on A, the Bat on S, no bombs) opens Floor 6
##   with exactly that, and writes the same checkpoint back unchanged. The south-west Gelatinous
##   Blob carries Blast Bomb x2 (a LootDrop); nothing is dropped yet. Floor 6's enemies are kept
##   idle, so every number is exact.
## - B. The Bat kills that blob: a "Blast Bomb x2" pickup appears where it died, and Carl has no
##   bombs until he walks over it; then exactly 2, the pickup gone; the menu lists "Blast Bomb x2";
##   A assigns it; the HUD shows "A: Blast Bomb x2". The save does not change.
## - C. Two deaths on Floor 6 each take the bombs back (0, A back to the potion, the blob alive at
##   its spawn with its drop not made, no pickup lying there, nothing duplicated).
## - D. Pause > Return to Title > Yes before Floor 7, then Continue: Floor 6's entry again (no
##   bombs, the blob alive).
## - E. A bomb thrown at the Backstop blob takes exactly 20 and leaves 1; the stairs lead to
##   Floor 7: spawn, Donut, sign, HUD "A: Blast Bomb x1", four enemies (three Gelatinous Blobs, a
##   Spitting Blob), the pair within one blast, the shielded blob behind its wall, no exits, no
##   loop; the Floor 7 checkpoint holds the bomb (x1) and A = Blast Bomb, in memory and on disk
##   (still version 3, the same seven fields).
## - F. The last bomb, thrown at the pair: both lose exactly 20; 0 left, A empty, the HUD and the
##   menu follow; Carl and Donut unhurt.
## - G. A retry restores the bomb and A = Blast Bomb; the pair is back at 30.
## - H. Thrown at the blast wall, the bomb spares the blob behind it (inside the blast's 72 px).
## - I. Quit and Continue on Floor 7: the bomb on A, and it throws at once.
## - J. New Game: no bombs, W/A/S empty, D = Fists, the Surface checkpoint without bombs.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_07_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FLOOR_4_PATH := "res://scenes/levels/floor_04.tscn"
const FLOOR_5_PATH := "res://scenes/levels/floor_05.tscn"
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const FLOOR_7_PATH := "res://scenes/levels/floor_07.tscn"
const BLOB_PATH := "res://scenes/enemies/gelatinous_blob.tscn"
const SPITTER_PATH := "res://scenes/enemies/spitting_blob.tscn"
const PHASE_11_SAVE := "res://tests/fixtures/phase11_save_v3_floor_06.json"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const A := ActionSlots.SLOT_A
const HUD_ENTRY := "W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists"
const ENTRY_CARL_HP := 80
const ENTRY_DONUT_HP := 40
## Where things are in floor_06.tscn and floor_07.tscn.
const LOOT_BLOB_SPAWN := Vector2(320, 480)
const BACKSTOP_SPAWN := Vector2(536, 208)
const FLOOR_7_SPAWN := Vector2(176, 176)
const PAIR_NORTH_SPAWN := Vector2(560, 164)
const PAIR_SOUTH_SPAWN := Vector2(560, 196)
const SHIELDED_SPAWN := Vector2(768, 448)
const FLOOR_7_SPITTER_SPAWN := Vector2(992, 192)
## Floor 7's blast wall: x 704-736, y 384-512.
const BLAST_WALL_FACE_X := 704.0
## Where Carl throws from on Floor 7: in line with the pair (and 227 px from it, so it stays idle)
## and in line with the shielded blob (268 px from it).
const PAIR_THROW_POINT := Vector2(330, 176)
const WALL_THROW_POINT := Vector2(500, 448)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_downward_only()
	if await _continue_on_floor_6() and await _earn_bombs() and await _floor_6_deaths_take_them_back() \
			and await _return_to_title_before_floor_7() and await _one_bomb_then_floor_7() and await _check_floor_7_arrival() \
			and await _last_bomb_on_the_pair() and await _floor_7_retry_restores_it() and await _bomb_against_the_blast_wall() \
			and await _continue_on_floor_7():
		await _new_game_has_no_bombs()
	finish()


func _check_downward_only() -> void:
	print("-- Every exit leads one floor down; Floor 7 has none")
	var expected := {
		SURFACE_PATH: [FLOOR_1_PATH], FLOOR_1_PATH: [FLOOR_2_PATH], FLOOR_2_PATH: [FLOOR_3_PATH],
		FLOOR_3_PATH: [FLOOR_4_PATH], FLOOR_4_PATH: [FLOOR_5_PATH], FLOOR_5_PATH: [FLOOR_6_PATH],
		FLOOR_6_PATH: [FLOOR_7_PATH], FLOOR_7_PATH: [],
	}
	for level_path: String in expected:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var destinations := _destinations(level)
		level.free()
		check(destinations == expected[level_path], "%s leads only to %s" % [level_path.get_file(), expected[level_path]],
				str(destinations))
	check(FloorRegistry.has_floor(&"floor_07") and FloorRegistry.get_scene_path(&"floor_07") == FLOOR_7_PATH
			and FloorRegistry.get_display_name(&"floor_07") == "Floor 7" and FloorRegistry.get_floor_id(FLOOR_7_PATH) == &"floor_07",
			"floor_07 is a registered floor, shown as 'Floor 7'")


func _continue_on_floor_6() -> bool:
	print("-- Continue on a real Phase 11 save (version 3, Floor 6, no bombs)")
	var fixture := FileAccess.get_file_as_string(PHASE_11_SAVE)
	check(JSON.parse_string(fixture).get("save_version") == 3.0 and not fixture.contains("blast_bomb"),
			"the fixture is a version 3 save without bombs")
	_write_save(fixture)
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(current_scene.is_continue_available() and info == "Saved at the start of Floor 6  -  HP 80 / 100", "the title offers it", info)
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_6_PATH):
		return false
	var state := game_state()
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP and _hud_slots() == HUD_ENTRY,
			"Floor 6 opens with Carl 80, Donut 40, W Slingshot, A potion, S Bat", _hud_slots())
	check(state.inventory.get_quantity(BOMB) == 0 and not state.inventory.has(BOMB), "no Blast Bombs")
	check(_save() == JSON.parse_string(fixture), "Continue wrote the same checkpoint back: a Phase 11 save needs no change")
	var loot := _loot_drop()
	check(loot != null and loot.item == BOMB and loot.quantity == 2 and not loot.has_dropped(),
			"the south-west Gelatinous Blob carries Blast Bomb x2, not dropped yet")
	check(_drops().is_empty(), "no Blast Bomb pickup lies on Floor 6")
	return true


## Kills the south-west blob with the Bat, collects its drop and puts the bombs on A.
func _earn_bombs() -> bool:
	print("-- Floor 6: the loot blob dies and drops Blast Bomb x2; Carl collects them")
	var save_before := _save_text()
	var blob := _loot_blob()
	var carl := _carl()
	var state := game_state()
	var drops := []
	_loot_drop().dropped.connect(func(pickup: ItemPickup) -> void: drops.append(pickup))
	blob.death_fade_time = 3.0
	carl.teleport_to(blob.global_position + Vector2(-60, 0))
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_S)
	await wait_until(func() -> bool: return not blob.is_knocked_back(), "the push to end", 30)
	check(blob.health.current_health == 10, "the Bat hits it for 20")
	await wait_seconds(0.8)
	carl.teleport_to(blob.global_position + Vector2(-60, 0))
	await wait_physics_frames(2)
	var died_at := blob.global_position
	await tap_key(KEY_S)
	check(blob.health.is_dead() and state.inventory.get_quantity(BOMB) == 0, "a second hit kills it; its death alone gives no bombs")
	await wait_physics_frames(2)
	var pickups := _drops()
	check(pickups.size() == 1 and drops == pickups, "one pickup is dropped", "%d pickups" % pickups.size())
	if pickups.size() != 1:
		return false
	var pickup: ItemPickup = pickups[0]
	check(pickup.global_position.distance_to(died_at) < 0.01 and pickup.get_node("Label").text == "Blast Bomb x2"
			and pickup.get_node("Marker/Icon").texture == BOMB.icon, "'Blast Bomb x2', with the bomb icon, where the blob died",
			"%s at %s" % [pickup.get_node("Label").text, pickup.global_position])
	await walk_to(pickup.global_position)
	await wait_physics_frames(2)
	check(state.inventory.get_quantity(BOMB) == 2 and _drops().is_empty(), "walking over it gives exactly 2; the pickup is gone",
			str(state.inventory.get_quantity(BOMB)))
	check((await _menu_rows()).has("Blast Bomb x2   (no slot)"), "the menu lists 'Blast Bomb x2'")
	await _assign_in_menu("Blast Bomb", KEY_A)
	check(_hud_slots() == "W: Slingshot   A: Blast Bomb x2   S: Baseball Bat   D: Fists", "A assigns it; the HUD shows A: Blast Bomb x2",
			_hud_slots())
	check((await _menu_rows()).has("Blast Bomb x2   (on A)") and (await _menu_rows()).has("Small Health Potion x1   (no slot)"),
			"the menu shows it on A (the potion keeps no slot)")
	check(_save_text() == save_before, "the kill, the pickup and the assignment do not write the save")
	return true


func _floor_6_deaths_take_them_back() -> bool:
	for attempt in 2:
		print("-- Floor 6: death and retry %d" % (attempt + 1))
		if not await _die_and_retry(FLOOR_6_PATH):
			return false
		var state := game_state()
		check(state.inventory.get_quantity(BOMB) == 0 and not state.inventory.has(BOMB) and state.action_slots.find_slot(BOMB) == &"",
				"retry %d: no bombs, and no slot holds one" % (attempt + 1))
		check(_hud_slots() == HUD_ENTRY and state.action_slots.get_action(A) == POTION,
				"retry %d: A has the potion again, as at floor entry" % (attempt + 1), _hud_slots())
		check(state.inventory.get_actions() == [FISTS, POTION, SLINGSHOT, BAT],
				"retry %d: nothing duplicated (Fists, the potion, the Slingshot, the Bat)" % (attempt + 1), str(state.inventory.get_actions()))
		var blob := _loot_blob()
		check(blob != null and blob.global_position == LOOT_BLOB_SPAWN and blob.health.current_health == 30
				and not _loot_drop().has_dropped(), "retry %d: the loot blob is alive at its spawn, carrying its drop" % (attempt + 1))
		check(_drops().is_empty(), "retry %d: no Blast Bomb pickup lies on the floor" % (attempt + 1))
		check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP,
				"retry %d: Floor 6's entry HP" % (attempt + 1))
		if attempt == 0 and not await _earn_bombs():
			return false
	return true


func _return_to_title_before_floor_7() -> bool:
	if not await _earn_bombs():
		return false
	print("-- Pause > Return to Title with the bombs, then Continue")
	var save_before := _save_text()
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if not await wait_for_scene(title_path):
		return false
	await wait_physics_frames(2)
	check(_save_text() == save_before and game_state().inventory.get_quantity(BOMB) == 0,
			"the title: the save is unchanged, and the run in memory has no bombs")
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_6_PATH):
		return false
	check(game_state().inventory.get_quantity(BOMB) == 0 and _hud_slots() == HUD_ENTRY,
			"Continue gives Floor 6's entry: no bombs, A = potion", _hud_slots())
	check(_loot_blob() != null and _loot_blob().health.current_health == 30 and _drops().is_empty(),
			"the loot blob is alive again, and nothing is dropped")
	return true


func _one_bomb_then_floor_7() -> bool:
	if not await _earn_bombs():
		return false
	print("-- Floor 6: one bomb at the Backstop blob, then the stairs to Floor 7")
	var carl := _carl()
	var backstop: Enemy = current_scene.get_node("Actors/BackstopBlob")
	var damage_taken := []
	backstop.health.damaged.connect(func(amount: int) -> void: damage_taken.append(amount))
	carl.teleport_to(BACKSTOP_SPAWN + Vector2(-150, 0))
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_A)
	await wait_physics_frames(60)
	check(damage_taken == [20] and backstop.health.current_health == 10, "the bomb hits the Backstop blob for exactly 20",
			str(damage_taken))
	check(game_state().inventory.get_quantity(BOMB) == 1 and _hud_slots() == "W: Slingshot   A: Blast Bomb x1   S: Baseball Bat   D: Fists",
			"one throw spent one: A: Blast Bomb x1", _hud_slots())
	check(carl.health.current_health == ENTRY_CARL_HP, "Carl is unhurt")
	await walk_to(current_scene.get_node("Stairs").global_position)
	return await _arrive(FLOOR_7_PATH)


func _check_floor_7_arrival() -> bool:
	print("-- Floor 7 on arrival")
	var level := current_scene
	var carl := _carl()
	var donut := _donut()
	var state := game_state()
	check(carl.global_position.distance_to(FLOOR_7_SPAWN) < 4.0, "Carl arrives at Floor 7's spawn point", str(carl.global_position))
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0, "Donut arrives next to Carl")
	check(carl.camera.get_screen_center_position().distance_to(carl.global_position) < 1.0, "the camera starts centred on Carl")
	check((level.get_node("Signs/FloorTitle") as Label).text == "Floor 7 - Blast Range", "the Floor 7 sign")
	check(_hud_carl() == "Carl HP: 80 / 100" and _hud_donut() == "Donut HP: 40 / 60"
			and _hud_slots() == "W: Slingshot   A: Blast Bomb x1   S: Baseball Bat   D: Fists",
			"the HUD: Carl 80, Donut 40, A: Blast Bomb x1", "%s | %s | %s" % [_hud_carl(), _hud_donut(), _hud_slots()])
	var blobs := _enemies(BLOB_PATH)
	var spitters := _enemies(SPITTER_PATH)
	check(blobs.size() == 3 and spitters.size() == 1, "three Gelatinous Blobs and a Spitting Blob",
			"%d blobs, %d spitters" % [blobs.size(), spitters.size()])
	var north: Enemy = level.get_node("Actors/PairBlobNorth")
	var south: Enemy = level.get_node("Actors/PairBlobSouth")
	var shielded: Enemy = level.get_node("Actors/ShieldedBlob")
	check(north.global_position == PAIR_NORTH_SPAWN and south.global_position == PAIR_SOUTH_SPAWN
			and shielded.global_position == SHIELDED_SPAWN and spitters[0].global_position == FLOOR_7_SPITTER_SPAWN, "as authored")
	var pair_middle := (north.global_position + south.global_position) / 2.0
	check(pair_middle.distance_to(north.global_position) + 14.0 < 72.0 and pair_middle.distance_to(south.global_position) + 14.0 < 72.0,
			"the pair stands close enough for one blast to reach both")
	var blast_point := Vector2(BLAST_WALL_FACE_X - 2.0, SHIELDED_SPAWN.y)
	var ray := PhysicsRayQueryParameters2D.create(blast_point, shielded.global_position, 1)
	check(blast_point.distance_to(shielded.global_position) < 72.0
			and not level.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),
			"the shielded blob is inside 72 px of the blast wall's west face, with the wall in between")
	check(_destinations(level).is_empty(), "Floor 7 has no exits: nothing leads back up to Floor 6")
	var entry: FloorEntry = state.floor_entry
	check(entry.scene_path == FLOOR_7_PATH and entry.inventory["quantities"].get(BOMB.id) == 1
			and entry.action_slots.get(A) == BOMB, "Floor 7's entry state holds one bomb, with A = Blast Bomb")
	check(_save() == JSON.parse_string(JSON.stringify(_floor_7_save_data())),
			"the Floor 7 checkpoint is saved: version 3, floor_07, blast_bomb 1, A = blast_bomb",
			_save_text().replace("\n", " ").replace("\t", ""))
	check(_save().keys().size() == 7 and _save().get("save_version") == 3.0, "still save_version 3 with the same seven fields")
	var loaded: FloorEntry = save_manager().load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_7_PATH and loaded.action_slots.get(A) == BOMB
			and loaded.inventory["quantities"].get(BOMB.id) == 1, "it loads back as Floor 7 with one bomb on A")
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 7 (no transition loop)")
	return true


func _last_bomb_on_the_pair() -> bool:
	print("-- Floor 7: the last bomb at the pair hits both")
	if not await _throw_at_the_pair():
		return false
	var state := game_state()
	check(state.inventory.get_quantity(BOMB) == 0 and state.action_slots.get_action(A) == null
			and _hud_slots() == "W: Slingshot   A: —   S: Baseball Bat   D: Fists", "the last bomb: 0 left, A empty", _hud_slots())
	check(not (await _menu_rows()).any(func(row: String) -> bool: return row.contains("Blast Bomb")), "the menu no longer lists it")
	return true


func _floor_7_retry_restores_it() -> bool:
	print("-- Floor 7: death and retry")
	if not await _die_and_retry(FLOOR_7_PATH):
		return false
	var state := game_state()
	check(state.inventory.get_quantity(BOMB) == 1 and state.action_slots.get_action(A) == BOMB
			and _hud_slots() == "W: Slingshot   A: Blast Bomb x1   S: Baseball Bat   D: Fists",
			"the retry gives the checkpoint's bomb back, on A", _hud_slots())
	check(current_scene.get_node("Actors/PairBlobNorth").health.current_health == 30
			and current_scene.get_node("Actors/PairBlobSouth").health.current_health == 30, "the pair is back at 30")
	return true


func _bomb_against_the_blast_wall() -> bool:
	print("-- Floor 7: a bomb against the blast wall spares the blob behind it")
	var level := current_scene
	var shielded: Enemy = level.get_node("Actors/ShieldedBlob")
	var carl := _carl()
	await walk_to(WALL_THROW_POINT)
	await tap_key(KEY_RIGHT)
	var launcher := carl.get_action_performer(BOMB) as ProjectileLauncher
	var explosions := []
	launcher.fired.connect(func(bomb: Projectile) -> void:
		bomb.get_node("DetonateOnStop").exploded.connect(func(explosion: AreaDamage, targets: Array[Hurtbox]) -> void:
			explosions.append([explosion.global_position, targets.size()])), CONNECT_ONE_SHOT)
	await tap_key(KEY_A)
	await wait_until(func() -> bool: return not explosions.is_empty(), "the bomb to explode", 120)
	if explosions.is_empty():
		return false
	var blast_at: Vector2 = explosions[0][0]
	check(absf(blast_at.x - (BLAST_WALL_FACE_X - 2.0)) < 0.5 and blast_at.distance_to(shielded.global_position) < 72.0,
			"it explodes against the wall's face, within 72 px of the blob behind it", str(blast_at))
	check(explosions[0][1] == 0 and shielded.health.current_health == 30, "the wall shields the blob: it takes nothing")
	check(carl.health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP, "Carl and Donut unhurt")
	check(game_state().inventory.get_quantity(BOMB) == 0 and game_state().action_slots.get_action(A) == null, "the bomb is spent; A empty")
	return true


func _continue_on_floor_7() -> bool:
	print("-- Quit and Continue on Floor 7")
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of Floor 7  -  HP 80 / 100", "the title says Floor 7", info)
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_7_PATH):
		return false
	check(game_state().inventory.get_quantity(BOMB) == 1 and game_state().action_slots.get_action(A) == BOMB
			and _hud_slots() == "W: Slingshot   A: Blast Bomb x1   S: Baseball Bat   D: Fists",
			"Continue opens Floor 7 with the bomb on A", _hud_slots())
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP, "Carl 80, Donut 40")
	return await _throw_at_the_pair()


func _new_game_has_no_bombs() -> void:
	print("-- New Game")
	if not await _open_title():
		return
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await _arrive(SURFACE_PATH):
		return
	var state := game_state()
	check(state.inventory.get_quantity(BOMB) == 0 and state.inventory.get_actions() == [FISTS], "New Game: no bombs, nothing but Fists")
	check(_hud_slots() == "W: —   A: —   S: —   D: Fists", "W/A/S empty, D = Fists", _hud_slots())
	check(_carl().health.current_health == 100 and _donut().health.current_health == 60, "Carl 100, Donut 60 / 60")
	check(_save().get("floor_id") == "surface" and _save().get("inventory") == {} and not _save_text().contains("blast_bomb"),
			"its Surface checkpoint has no bombs")


## From PAIR_THROW_POINT, throws the bomb on A at Floor 7's pair: both lose exactly 20.
func _throw_at_the_pair() -> bool:
	var level := current_scene
	var north: Enemy = level.get_node("Actors/PairBlobNorth")
	var south: Enemy = level.get_node("Actors/PairBlobSouth")
	var north_damage := []
	var south_damage := []
	north.health.damaged.connect(func(amount: int) -> void: north_damage.append(amount))
	south.health.damaged.connect(func(amount: int) -> void: south_damage.append(amount))
	var carl := _carl()
	await walk_to(PAIR_THROW_POINT)
	await tap_key(KEY_RIGHT)
	check(north.target == null and south.target == null, "the pair has not noticed Carl yet")
	await tap_key(KEY_A)
	await wait_physics_frames(90)
	check(north_damage == [20] and south_damage == [20] and north.health.current_health == 10 and south.health.current_health == 10,
			"one explosion: both blobs of the pair lose exactly 20, once", "%s, %s" % [north_damage, south_damage])
	check(carl.health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP, "Carl and Donut unhurt")
	check(north.global_position == PAIR_NORTH_SPAWN and south.global_position == PAIR_SOUTH_SPAWN, "and nothing is knocked back")
	return true


## The version 3 save data of the Floor 7 checkpoint this run makes.
func _floor_7_save_data() -> Dictionary:
	return {
		"save_version": 3, "floor_id": "floor_07",
		"carl": {"health": ENTRY_CARL_HP, "max_health": 100},
		"donut": {"health": ENTRY_DONUT_HP, "max_health": 60},
		"inventory": {"small_health_potion": 1, "blast_bomb": 1}, "owned_items": ["slingshot", "baseball_bat"],
		"action_slots": {"action_w": "slingshot", "action_a": "blast_bomb", "action_s": "baseball_bat", "action_d": "fists"},
	}


## Waits for `level_path` to be the current level, then keeps Floor 6's and Floor 7's enemies idle
## (their own fights are other tests'), so HP numbers are exact.
func _arrive(level_path: String) -> bool:
	if not await wait_for_scene(level_path):
		return false
	await wait_physics_frames(3)
	if level_path in [FLOOR_6_PATH, FLOOR_7_PATH]:
		for enemy in _enemies():
			enemy.detection_range = 0.0
			enemy.chase_range = 0.0
	return true


func _die_and_retry(level_path: String) -> bool:
	var level := current_scene
	var level_id := level.get_instance_id()
	var save_before := _save_text()
	_carl().health.take_damage(1000)
	await wait_physics_frames(2)
	await wait_seconds(1.0)
	check(paused and _game_over_visible() and current_scene == level, "GAME OVER waits")
	check(_save_text() == save_before, "death does not write the save")
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != level_id:
			break
		await physics_frame
	if not await _arrive(level_path):
		return false
	check(not paused and _save_text() == save_before, "the floor is loaded again, and the save still holds its checkpoint")
	return true


## Opens the action menu, selects the first action whose name starts with `action_name`,
## presses `key` to put it in that slot, and closes the menu.
func _assign_in_menu(action_name: String, key: Key) -> void:
	await tap_key(KEY_SPACE)
	var list := current_scene.get_node("ActionMenu/%ActionList")
	for i in list.get_child_count():
		if (list.get_child(i) as Label).text.begins_with("> " + action_name):
			break
		await tap_key(KEY_DOWN)
	await tap_key(key)
	await tap_key(KEY_SPACE)


## Opens the action menu, reads Carl's list (without the "> " of the selected row), and closes it.
func _menu_rows() -> Array:
	await tap_key(KEY_SPACE)
	var rows := current_scene.get_node("ActionMenu/%ActionList").get_children().map(
			func(row: Label) -> String: return row.text.trim_prefix("> "))
	await tap_key(KEY_SPACE)
	return rows


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


## The Blast Bomb pickups lying in the level (none is authored: only drops).
func _drops() -> Array:
	return current_scene.find_children("*", "Area2D", true, false).filter(func(node: Node) -> bool:
		return node is ItemPickup and node.item == BOMB and not node.is_queued_for_deletion())


func _loot_blob() -> Enemy:
	return current_scene.get_node_or_null("Actors/GelatinousBlob")


func _loot_drop() -> LootDrop:
	return current_scene.get_node_or_null("Actors/GelatinousBlob/LootDrop")


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
