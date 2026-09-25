extends "res://tests/support/game_test.gd"
## Phase 9 end-to-end run: the Baseball Bat on Floor 5 and Floor 6, through the real title screen
## and levels, on this test's own save file:
## - Every level's exits lead one floor down (Floor 5's to Floor 6); Floor 6 has none.
## - A. Continue on a real Phase 8 save (tests/fixtures/phase8_save_v3_floor_05.json: version 3,
##   Floor 5, Carl 80, Donut 40, Slingshot on W, a potion on A, no Bat) opens Floor 5 with that
##   state: no Bat, S empty, and the Bat pickup lying there. Floor 5's enemies are kept idle
##   except where a check needs them.
## - B. Walking over the pickup owns the Bat (it disappears); the menu lists "Baseball Bat" with
##   no quantity; S assigns it; the HUD shows "S: Baseball Bat". The save does not change.
## - C. Two deaths on Floor 5 each take the Bat back (not owned, S empty, pickup back, nothing
##   duplicated), because the Floor 5 checkpoint was made without it.
## - D. Quitting before Floor 6 and continuing also gives Floor 5 without the Bat.
## - E. On Floor 5 the Bat hits a Gelatinous Blob for 20 and knocks it back 80 px.
## - F. Floor 5 -> Floor 6: Carl and Donut arrive safely, the sign, the HUD with the Bat on S,
##   two Gelatinous Blobs and a Spitting Blob, no exits, no loop; the Floor 6 checkpoint owns the
##   Bat with S = Baseball Bat, in memory and on disk (still save_version 3).
## - G. On Floor 6 the Backstop blob comes for Carl; the Bat knocks it into the wall behind it,
##   where it stops without crossing; then it comes back at Carl and touches him.
## - H. GAME OVER while a blob is being knocked back freezes the push; two Floor 6 deaths keep
##   the Bat and S; the retried floor has its enemies as authored and no push left over; the
##   save never holds anything about a push.
## - I. Quit and Continue: Floor 6 directly, the Bat owned on S, and it swings and knocks back.
## - J. New Game after all this: no Bat, W/A/S empty, D = Fists, the Surface checkpoint without it.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_06_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FLOOR_4_PATH := "res://scenes/levels/floor_04.tscn"
const FLOOR_5_PATH := "res://scenes/levels/floor_05.tscn"
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const BLOB_PATH := "res://scenes/enemies/gelatinous_blob.tscn"
const SPITTER_PATH := "res://scenes/enemies/spitting_blob.tscn"
const PHASE_8_SAVE := "res://tests/fixtures/phase8_save_v3_floor_05.json"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const HUD_WITHOUT_BAT := "W: Slingshot   A: Potion x1   S: —   D: Fists"
const HUD_WITH_BAT := "W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists"
const ENTRY_CARL_HP := 80
const ENTRY_DONUT_HP := 40
## Where things are in floor_06.tscn.
const FLOOR_6_SPAWN := Vector2(176, 176)
const BACKSTOP_SPAWN := Vector2(536, 208)
const FLOOR_6_BLOB_SPAWN := Vector2(320, 480)
const FLOOR_6_SPITTER_SPAWN := Vector2(928, 224)
## The west face of Floor 6's Backstop wall (x 576-640, y 96-352). A 13 px blob stops 13 px short.
const BACKSTOP_FACE_X := 576.0


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_downward_only()
	if await _continue_on_floor_5() and await _collect_bat_and_put_it_on_s() and await _floor_5_death_takes_it_back() \
			and await _quit_before_floor_6() and await _bat_on_a_floor_5_blob() and await _floor_5_to_floor_6() \
			and await _check_floor_6_arrival() and await _bat_into_the_backstop() and await _game_over_during_a_push() \
			and await _floor_6_death_keeps_the_bat() and await _continue_on_floor_6():
		await _new_game_clears_the_bat()
	finish()


func _check_downward_only() -> void:
	print("-- Every exit leads one floor down; Floor 6 has none")
	var expected := {
		SURFACE_PATH: [FLOOR_1_PATH], FLOOR_1_PATH: [FLOOR_2_PATH], FLOOR_2_PATH: [FLOOR_3_PATH],
		FLOOR_3_PATH: [FLOOR_4_PATH], FLOOR_4_PATH: [FLOOR_5_PATH], FLOOR_5_PATH: [FLOOR_6_PATH], FLOOR_6_PATH: [],
	}
	for level_path: String in expected:
		var level: Node = (load(level_path) as PackedScene).instantiate()
		var destinations := _destinations(level)
		level.free()
		check(destinations == expected[level_path], "%s leads only to %s" % [level_path.get_file(), expected[level_path]],
				str(destinations))
	check(FloorRegistry.get_scene_path(&"floor_06") == FLOOR_6_PATH, "floor_06 is a registered floor")


func _continue_on_floor_5() -> bool:
	print("-- Continue on a real Phase 8 save (version 3, Floor 5, no Bat)")
	var fixture := FileAccess.get_file_as_string(PHASE_8_SAVE)
	check(JSON.parse_string(fixture).get("save_version") == 3.0 and not fixture.contains("baseball_bat"),
			"the fixture is a version 3 save without the Bat")
	_write_save(fixture)
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(current_scene.is_continue_available() and info == "Saved at the start of Floor 5  -  HP 80 / 100", "the title offers it", info)
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_5_PATH):
		return false
	var state := game_state()
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP and _hud_slots() == HUD_WITHOUT_BAT,
			"Floor 5 opens with Carl 80, Donut 40, the Slingshot on W and the potion on A", _hud_slots())
	check(not state.inventory.has(BAT) and state.action_slots.find_slot(BAT) == &"" and _bat_pickup() != null,
			"the Bat is not owned yet, and its pickup lies on Floor 5")
	check(_bat_pickup().get_node("Label").text == "Baseball Bat" and _bat_pickup().get_node("Marker/Icon").texture == BAT.icon,
			"the pickup shows the Bat icon and 'Baseball Bat'")
	check(not state.floor_entry.inventory["items"].has(BAT.id) and not _save_text().contains("baseball_bat")
			and _save().get("save_version") == 3.0, "the Floor 5 checkpoint (still version 3) has no Bat")
	return true


func _collect_bat_and_put_it_on_s() -> bool:
	print("-- Floor 5: collect the Bat and put it on S")
	var save_before := _save_text()
	var pickup := _bat_pickup()
	if pickup == null:
		check(false, "there is a Bat pickup to collect")
		return false
	await walk_to(pickup.global_position)
	await wait_physics_frames(2)
	check(game_state().inventory.has(BAT) and _bat_pickup() == null, "walking over it owns the Bat; the pickup is gone")
	check((await _menu_rows()).has("Baseball Bat   (no slot)"), "the menu lists 'Baseball Bat', with no quantity")
	await _assign_in_menu("Baseball Bat", KEY_S)
	check(_hud_slots() == HUD_WITH_BAT, "the HUD shows S: Baseball Bat", _hud_slots())
	check((await _menu_rows()).has("Baseball Bat   (on S)"), "the menu shows it on S")
	check(_save_text() == save_before, "collecting and assigning it does not write the save")
	return true


func _floor_5_death_takes_it_back() -> bool:
	for attempt in 2:
		print("-- Floor 5: death and retry %d" % (attempt + 1))
		if not await _die_and_retry(FLOOR_5_PATH):
			return false
		var state := game_state()
		check(not state.inventory.has(BAT) and state.action_slots.find_slot(BAT) == &"",
				"retry %d: the Bat is no longer owned, and no slot holds it" % (attempt + 1))
		check(_bat_pickup() != null, "retry %d: the Bat pickup is back" % (attempt + 1))
		check(_hud_slots() == HUD_WITHOUT_BAT, "retry %d: S is empty; the Slingshot and potion stay" % (attempt + 1), _hud_slots())
		check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP,
				"retry %d: Carl's and Donut's Floor 5 entry HP" % (attempt + 1))
		check(state.inventory.get_actions().size() == 3 and state.inventory.get_actions().count(BAT) == 0,
				"retry %d: nothing duplicated (Fists, the potion, the Slingshot)" % (attempt + 1), str(state.inventory.get_actions()))
		if attempt == 0:
			await _collect_bat_and_put_it_on_s()
	return true


func _quit_before_floor_6() -> bool:
	await _collect_bat_and_put_it_on_s()
	print("-- Quit on Floor 5 with the Bat, then Continue")
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_5_PATH):
		return false
	check(not game_state().inventory.has(BAT) and _bat_pickup() != null and _hud_slots() == HUD_WITHOUT_BAT,
			"Continue returns to Floor 5's entry: no Bat, the pickup is there, S is empty")
	return true


func _bat_on_a_floor_5_blob() -> bool:
	await _collect_bat_and_put_it_on_s()
	print("-- Floor 5: the Bat hits a Gelatinous Blob for 20 and knocks it back")
	var blob: Enemy = current_scene.get_node("Actors/GelatinousBlob")
	var carl := _carl()
	carl.teleport_to(blob.global_position + Vector2(-66, 0))
	await tap_key(KEY_RIGHT)
	var start := blob.global_position
	await tap_key(KEY_S)
	await wait_until(func() -> bool: return not blob.is_knocked_back(), "the push to end", 30)
	var pushed := blob.global_position - start
	check(blob.health.current_health == 10, "exactly 20 damage", "%d HP" % blob.health.current_health)
	check(pushed.distance_to(Vector2(80, 0)) < 0.5, "it is knocked 80 px away from Carl", str(pushed))
	# A second hit kills it: a normal death, with no push.
	blob.death_fade_time = 2.0
	carl.teleport_to(blob.global_position + Vector2(-60, 0))
	await wait_seconds(0.8)
	var died_at := blob.global_position
	await tap_key(KEY_S)
	await wait_physics_frames(20)
	check(blob.health.is_dead() and blob.global_position == died_at and not blob.is_knocked_back() and blob.body_shape.disabled,
			"a second hit kills it: it dies where it stood, and fades out")
	return true


func _floor_5_to_floor_6() -> bool:
	print("-- Floor 5 -> Floor 6")
	await walk_to(current_scene.get_node("Stairs").global_position)
	return await _arrive(FLOOR_6_PATH)


func _check_floor_6_arrival() -> bool:
	print("-- Floor 6 on arrival")
	var level := current_scene
	var carl := _carl()
	var donut := _donut()
	var state := game_state()
	check(carl.global_position.distance_to(FLOOR_6_SPAWN) < 4.0, "Carl arrives at Floor 6's spawn point", str(carl.global_position))
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0, "Donut arrives next to Carl")
	check(carl.camera.get_screen_center_position().distance_to(carl.global_position) < 1.0, "the camera starts centred on Carl")
	check((level.get_node("Signs/FloorTitle") as Label).text == "Floor 6 - Batting Cage", "the Floor 6 sign")
	check(_hud_carl() == "Carl HP: 80 / 100" and _hud_donut() == "Donut HP: 40 / 60" and _hud_slots() == HUD_WITH_BAT,
			"the HUD: Carl 80, Donut 40, S: Baseball Bat", "%s | %s | %s" % [_hud_carl(), _hud_donut(), _hud_slots()])
	check(state.inventory.has(BAT) and state.action_slots.get_action(ActionSlots.SLOT_S) == BAT, "Carl still owns the Bat, on S")
	var blobs := _enemies(BLOB_PATH)
	var spitters := _enemies(SPITTER_PATH)
	check(blobs.size() == 2 and _backstop_blob().global_position == BACKSTOP_SPAWN
			and level.get_node("Actors/GelatinousBlob").global_position == FLOOR_6_BLOB_SPAWN, "two Gelatinous Blobs, as authored")
	check(spitters.size() == 1 and spitters[0].global_position == FLOOR_6_SPITTER_SPAWN, "and a Spitting Blob")
	check(_destinations(level).is_empty(), "Floor 6 has no exits: nothing leads back up to Floor 5")
	var entry = state.floor_entry
	check(entry.scene_path == FLOOR_6_PATH and entry.carl_health == ENTRY_CARL_HP and entry.donut_health == ENTRY_DONUT_HP
			and entry.inventory["items"].has(BAT.id) and entry.inventory["items"].has(SLINGSHOT.id)
			and entry.action_slots == {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_S: BAT, ActionSlots.SLOT_D: FISTS},
			"Floor 6's entry state owns the Bat, with S = Baseball Bat")
	check(_save() == JSON.parse_string(JSON.stringify(_floor_6_save_data())),
			"the Floor 6 checkpoint is saved: version 3, floor_06, owned_items slingshot and baseball_bat, S = baseball_bat",
			_save_text().replace("\n", " ").replace("\t", ""))
	var loaded: FloorEntry = save_manager().load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_6_PATH and loaded.action_slots.get(ActionSlots.SLOT_S) == BAT,
			"it loads back as Floor 6 with the Bat on S")
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 6 (no transition loop)")
	return true


func _bat_into_the_backstop() -> bool:
	print("-- Floor 6: the Bat knocks the Backstop blob into its wall; it stops there, then comes back")
	var carl := _carl()
	var blob := _backstop_blob()
	# Carl steps up to the blob, which waits with its centre 40 px from the Backstop wall.
	carl.teleport_to(BACKSTOP_SPAWN + Vector2(-72, 0))
	await tap_key(KEY_RIGHT)
	check(blob.target == carl, "the Backstop blob notices Carl and comes for him")
	if not await wait_until(func() -> bool: return blob.global_position.x - carl.global_position.x < 72.0, "the blob to come within reach", 240):
		return false
	var touches := []
	carl.health.damaged.connect(func(amount: int) -> void: touches.append(amount))
	var farthest := [blob.global_position.x]
	var hit_from := blob.global_position.x
	await tap_key(KEY_S)
	check(blob.health.current_health == 10 and blob.is_knocked_back(), "the Bat hits it for 20 and knocks it back")
	await wait_until(func() -> bool:
		farthest[0] = maxf(farthest[0], blob.global_position.x)
		return not blob.is_knocked_back(), "the push to end", 30)
	check(hit_from + 80.0 > BACKSTOP_FACE_X - 13.0, "an unobstructed push would have taken it into the wall",
			"hit at x %.1f" % hit_from)
	check(farthest[0] <= BACKSTOP_FACE_X - 13.0 + 0.5 and farthest[0] > BACKSTOP_FACE_X - 13.0 - 2.0,
			"it stops against the Backstop wall, never overlapping or crossing it", "farthest x %.2f" % farthest[0])
	var landed := blob.global_position
	await wait_physics_frames(30)
	check(blob.global_position.x < landed.x - 10.0 and blob.target == carl, "then it comes back at Carl")
	# Donut, beside Carl, may scratch its last 10 HP away as it arrives: either way it got back to Carl.
	await wait_until(func() -> bool: return not touches.is_empty() or blob.health.is_dead(), "the blob to reach Carl", 240)
	check(touches == [10] or (blob.health.is_dead() and blob.global_position.distance_to(carl.global_position) < 60.0),
			"and it reaches him again (its touch takes 10, unless Donut finished it first)", str(touches))
	return true


func _game_over_during_a_push() -> bool:
	print("-- GAME OVER while a blob is being knocked back")
	var carl := _carl()
	# Floor 6's other Gelatinous Blob, still at 30 HP (so the Bat does not kill it).
	var blob: Enemy = current_scene.get_node("Actors/GelatinousBlob")
	var save_before := _save_text()
	carl.teleport_to(blob.global_position + Vector2(-60, 0))
	await tap_key(KEY_RIGHT)
	send_key(KEY_S, true)
	await wait_until(func() -> bool: return blob.is_knocked_back(), "a push", 60)
	send_key(KEY_S, false)
	await wait_physics_frames(3)
	carl.get_node("Hurtbox").take_hit(1000)
	await wait_physics_frames(2)
	var frozen_at := blob.global_position
	await wait_seconds(1.5)
	check(paused and _game_over_visible() and blob.is_knocked_back() and blob.global_position == frozen_at,
			"GAME OVER freezes the push where it was, and waits for Enter")
	check(_save_text() == save_before and _save().keys().size() == 7, "nothing about the push (or the death) is saved")
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_6_PATH):
		return false
	var retried: Enemy = current_scene.get_node("Actors/GelatinousBlob")
	check(retried.global_position == FLOOR_6_BLOB_SPAWN and retried.health.current_health == 30 and not retried.is_knocked_back()
			and _backstop_blob().global_position == BACKSTOP_SPAWN and _backstop_blob().health.current_health == 30,
			"the retried floor has its blobs as authored, with no push left over")
	check(game_state().inventory.has(BAT) and _hud_slots() == HUD_WITH_BAT, "Floor 6's checkpoint keeps the Bat on S")
	return true


func _floor_6_death_keeps_the_bat() -> bool:
	for attempt in 2:
		print("-- Floor 6: death and retry %d" % (attempt + 1))
		if not await _die_and_retry(FLOOR_6_PATH):
			return false
		var state := game_state()
		check(state.inventory.has(BAT) and state.action_slots.get_action(ActionSlots.SLOT_S) == BAT and _hud_slots() == HUD_WITH_BAT,
				"retry %d: the Bat is still owned, on S" % (attempt + 1), _hud_slots())
		check(state.inventory.get_actions().count(BAT) == 1 and state.inventory.get_actions().size() == 4,
				"retry %d: owned once, nothing duplicated" % (attempt + 1))
		check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP,
				"retry %d: Floor 6's entry HP for Carl and Donut" % (attempt + 1))
	return true


func _continue_on_floor_6() -> bool:
	print("-- Quit and Continue on Floor 6")
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(current_scene.is_continue_available() and info == "Saved at the start of Floor 6  -  HP 80 / 100", "the title shows the Floor 6 save", info)
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_6_PATH):
		return false
	var state := game_state()
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP
			and state.inventory.has(BAT) and state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 1
			and _hud_slots() == HUD_WITH_BAT, "Continue opens Floor 6 directly: Carl 80, Donut 40, the potion, the Slingshot, the Bat on S")
	# The blob in the open south-west, so the push can travel its full distance.
	var blob: Enemy = current_scene.get_node("Actors/GelatinousBlob")
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	_carl().teleport_to(blob.global_position + Vector2(-60, 0))
	await tap_key(KEY_RIGHT)
	var start := blob.global_position
	await tap_key(KEY_S)
	await wait_until(func() -> bool: return not blob.is_knocked_back(), "the push to end", 30)
	check(blob.health.current_health == 10 and (blob.global_position - start).distance_to(Vector2(80, 0)) < 0.5,
			"right after Continue, S swings the Bat: 20 damage and the full 80 px knockback",
			"%d HP, pushed %s" % [blob.health.current_health, blob.global_position - start])
	return true


func _new_game_clears_the_bat() -> void:
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
	check(not state.inventory.has(BAT) and not state.inventory.has(SLINGSHOT) and state.inventory.get_quantity(POTION) == 0
			and state.inventory.get_actions() == [FISTS], "New Game: no Bat, no Slingshot, no potions")
	check(_hud_slots() == "W: —   A: —   S: —   D: Fists" and state.action_slots.find_slot(BAT) == &"", "W/A/S empty, D = Fists", _hud_slots())
	check(_carl().health.current_health == 100 and _donut().health.current_health == 60, "Carl 100, Donut 60 / 60")
	check(_save().get("floor_id") == "surface" and _save().get("owned_items") == [] and not _save_text().contains("baseball_bat"),
			"its Surface checkpoint owns nothing")


## The version 3 save data of the Floor 6 checkpoint this run makes.
func _floor_6_save_data() -> Dictionary:
	return {
		"save_version": 3, "floor_id": "floor_06",
		"carl": {"health": ENTRY_CARL_HP, "max_health": 100},
		"donut": {"health": ENTRY_DONUT_HP, "max_health": 60},
		"inventory": {"small_health_potion": 1}, "owned_items": ["slingshot", "baseball_bat"],
		"action_slots": {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": "baseball_bat", "action_d": "fists"},
	}


## Waits for `level_path` to be the current level, then keeps Floor 5's enemies idle: their fights
## are test_floor_05_run.gd's, and here they would only make HP numbers vary.
func _arrive(level_path: String) -> bool:
	if not await wait_for_scene(level_path):
		return false
	await wait_physics_frames(3)
	if level_path == FLOOR_5_PATH:
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


func _bat_pickup() -> Node2D:
	return current_scene.get_node_or_null("Pickups/BaseballBat")


func _backstop_blob() -> Enemy:
	return current_scene.get_node_or_null("Actors/BackstopBlob")


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
