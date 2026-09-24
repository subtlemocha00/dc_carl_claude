extends "res://tests/support/game_test.gd"
## Phase 6 end-to-end run with the Slingshot, through the real title screen and levels, on
## this test's own save file. "Quitting" means going back to the title screen in the same
## process (the real process restart is checked separately; see PROJECT_STATE.md).
## - New Game after a run that owned the Slingshot: no Slingshot, W/A/S empty, D = Fists.
## - Surface -> Floor 1 (2 potions on A, one drunk) -> Floor 2. Nothing leads back up.
## - Floor 2 entry: no Slingshot in the run, the floor-entry state or the save; the pickup is there.
## - Carl collects it and puts it on W. Neither writes the save.
## - Dying on Floor 2 takes it back: not owned, the pickup is back, W is empty. Twice.
## - Quitting before Floor 3 and continuing: Floor 2 without the Slingshot, pickup back.
## - Collected again and put on W, three stones kill the Floor 2 blob (10 damage each).
## - Floor 2 -> Floor 3: Carl, Donut and the camera arrive, with no transition loop and no exits.
##   The Slingshot, W = Slingshot and A = potion x1 are kept, recorded in the floor-entry state,
##   and saved (save_version 2, owned_items ["slingshot"]).
## - On Floor 3 a stone shot from the spawn point stops at the wall, and the blob behind it is unhurt.
## - Dying on Floor 3 keeps the Slingshot and W (they are in its checkpoint), without duplicates.
## - Title -> Continue opens Floor 3 directly with the Slingshot on W, and it fires: three stones
##   kill a blob. Fighting does not change the save.
## - New Game then clears the Slingshot again.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_slingshot_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const D := ActionSlots.SLOT_D
## Carl's position in floor_03.tscn, and the x of the west face of its central wall.
const FLOOR_3_CARL_SPAWN := Vector2(160, 320)
const FLOOR_3_WALL_FACE_X := 352.0
const HUD_WITH_SLINGSHOT := "W: Slingshot   A: Potion x1   S: —   D: Fists"
const HUD_WITHOUT_SLINGSHOT := "W: —   A: Potion x1   S: —   D: Fists"

var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")
## Carl's HP on entering Floor 2 (and so Floor 3, as nothing hurts him in between).
var _entry_health := 0


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	for step: Callable in [_new_game_after_a_slingshot_run, _surface_to_floor_1, _floor_1_to_floor_2,
			_check_floor_2_entry, _collect_slingshot_and_put_it_on_w, _floor_2_death_takes_it_back,
			_quit_before_floor_3, _collect_slingshot_and_put_it_on_w, _shoot_the_floor_2_blob,
			_floor_2_to_floor_3, _floor_3_wall_stops_the_stone, _floor_3_retry_keeps_the_slingshot,
			_continue_on_floor_3, _new_game_clears_the_slingshot]:
		if not await step.call():
			break
	finish()


func _new_game_after_a_slingshot_run() -> bool:
	print("-- New Game after a run that owned the Slingshot")
	var state := game_state()
	state.inventory.add(SLINGSHOT, 1)
	state.action_slots.assign(SLINGSHOT, W)
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	check(not state.inventory.has(SLINGSHOT) and state.action_slots.find_slot(SLINGSHOT) == &"",
			"the new game does not own the Slingshot")
	check(_hud_slots() == "W: —   A: —   S: —   D: Fists", "W, A and S are empty and D = Fists", _hud_slots())
	check(_save().get("owned_items") == [] and _save().get("floor_id") == "surface", "the Surface checkpoint owns nothing")
	return true


func _surface_to_floor_1() -> bool:
	print("-- Surface -> Floor 1")
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_1_PATH):
		return false
	await wait_physics_frames(3)
	check(not _destinations().has(SURFACE_PATH), "nothing on Floor 1 leads back to the Surface", str(_destinations()))
	return true


func _floor_1_to_floor_2() -> bool:
	print("-- Floor 1: potions on A, one drunk -> Floor 2")
	await walk_to(current_scene.get_node("Pickups/SmallHealthPotions").global_position)
	await wait_physics_frames(2)
	await _assign_in_menu("Small Health Potion", KEY_A)
	_carl().health.take_damage(50)
	await tap_key(KEY_A)
	check(game_state().inventory.get_quantity(POTION) == 1, "one potion left on A")
	_entry_health = _carl().health.current_health
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_2_PATH):
		return false
	await wait_physics_frames(3)
	check(_carl().health.current_health == _entry_health, "Carl keeps his HP (%d)" % _entry_health)
	return true


func _check_floor_2_entry() -> bool:
	print("-- Floor 2 on arrival: no Slingshot yet")
	var state := game_state()
	check(not state.inventory.has(SLINGSHOT) and not state.floor_entry.inventory["items"].has(SLINGSHOT.id),
			"Carl does not own the Slingshot, and neither does the floor-entry state")
	var save := _save()
	check(save.get("floor_id") == "floor_02" and save.get("owned_items") == [] and save.get("inventory") == {"small_health_potion": 1.0}
			and save.get("save_version") == 2.0, "the Floor 2 checkpoint on disk: 1 potion, no owned items", str(save))
	var pickup := _slingshot_pickup()
	check(pickup != null and pickup.get_node("Label").text == "Slingshot", "the Slingshot pickup is on Floor 2")
	check(_destinations() == [FLOOR_3_PATH], "Floor 2's only exit leads down to Floor 3, nothing back up", str(_destinations()))
	check(await _menu_rows() == ["Fists   (on D)", "Small Health Potion x1   (on A)"], "the menu does not list the Slingshot")
	return true


func _collect_slingshot_and_put_it_on_w() -> bool:
	print("-- Floor 2: collect the Slingshot and put it on W")
	var save_before := _save_text()
	var pickup := _slingshot_pickup()
	if pickup == null:
		check(false, "there is a Slingshot pickup to collect")
		return false
	await walk_to(pickup.global_position)
	await wait_physics_frames(2)
	check(game_state().inventory.has(SLINGSHOT) and _slingshot_pickup() == null, "walking over it owns the Slingshot; the pickup is gone")
	await _assign_in_menu("Slingshot", KEY_W)
	check(_hud_slots() == HUD_WITH_SLINGSHOT, "the HUD shows W: Slingshot", _hud_slots())
	check(await _menu_rows() == ["Fists   (on D)", "Small Health Potion x1   (on A)", "Slingshot   (on W)"],
			"the menu lists the Slingshot on W, without a quantity")
	check(_save_text() == save_before, "collecting and assigning it does not write the save")
	return true


func _floor_2_death_takes_it_back() -> bool:
	for attempt in 2:
		print("-- Floor 2: death and retry %d" % (attempt + 1))
		if not await _die_and_retry(FLOOR_2_PATH):
			return false
		var state := game_state()
		check(not state.inventory.has(SLINGSHOT) and state.action_slots.find_slot(SLINGSHOT) == &"",
				"retry %d: the Slingshot is no longer owned, and no slot holds it" % (attempt + 1))
		check(_slingshot_pickup() != null, "retry %d: the Slingshot pickup is back" % (attempt + 1))
		check(_hud_slots() == HUD_WITHOUT_SLINGSHOT, "retry %d: W is empty; the potion stays on A" % (attempt + 1), _hud_slots())
		check(_carl().health.current_health == _entry_health and state.inventory.get_quantity(POTION) == 1,
				"retry %d: the floor-entry HP and potion" % (attempt + 1))
		check(state.inventory.get_actions() == [FISTS, POTION], "retry %d: nothing duplicated" % (attempt + 1))
		if attempt == 0:
			await _collect_slingshot_and_put_it_on_w()
	return true


func _quit_before_floor_3() -> bool:
	await _collect_slingshot_and_put_it_on_w()
	print("-- Quit on Floor 2 with the Slingshot, then Continue")
	check(game_state().inventory.has(SLINGSHOT), "Carl owns the Slingshot when he quits")
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_2_PATH):
		return false
	await wait_physics_frames(3)
	check(not game_state().inventory.has(SLINGSHOT) and _slingshot_pickup() != null,
			"Continue returns to Floor 2's entry: no Slingshot, the pickup is there")
	check(_hud_slots() == HUD_WITHOUT_SLINGSHOT, "W is empty", _hud_slots())
	return true


func _shoot_the_floor_2_blob() -> bool:
	print("-- Floor 2: three stones kill the blob")
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob")
	# 288 px from the blob: outside its 220 px detection range, inside the stone's 320 px.
	await walk_to(blob.global_position - Vector2(288, 0))
	await tap_key(KEY_RIGHT)
	var damage_taken := []
	blob.health.damaged.connect(func(amount: int) -> void: damage_taken.append(amount))
	var fired := _record_shots()
	await hold_keys([KEY_W], 80)
	for i in 60:
		if blob.health.is_dead():
			break
		await physics_frame
	check(fired.size() == 3 and damage_taken == [10, 10, 10] and blob.health.is_dead(),
			"three stones, 10 damage each, kill the blob", "%d stones, damage %s" % [fired.size(), damage_taken])
	check(game_state().inventory.has(SLINGSHOT) and _hud_slots() == HUD_WITH_SLINGSHOT, "the Slingshot is not used up")
	return true


func _floor_2_to_floor_3() -> bool:
	print("-- Floor 2 -> Floor 3")
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_3_PATH):
		return false
	await wait_physics_frames(3)
	var level := current_scene
	var carl := _carl()
	var donut: CharacterBody2D = level.get_node("Actors/Donut")
	check(carl.global_position.distance_to(FLOOR_3_CARL_SPAWN) < 4.0, "Carl arrives at Floor 3's spawn point", str(carl.global_position))
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0,
			"Donut arrives next to Carl and follows him")
	check(carl.camera.get_screen_center_position().distance_to(carl.global_position) < 1.0, "the camera starts centred on Carl")
	check((level.get_node("Signs/FloorTitle") as Label).text == "Floor 3 - Processing Level", "the Floor 3 sign")
	var state := game_state()
	check(state.inventory.has(SLINGSHOT) and state.action_slots.get_action(W) == SLINGSHOT
			and state.action_slots.get_action(A) == POTION and state.action_slots.get_action(D) == FISTS
			and state.inventory.get_quantity(POTION) == 1 and carl.health.current_health == _entry_health,
			"the Slingshot on W, 1 potion on A, Fists on D and the HP are kept")
	check(_hud_slots() == HUD_WITH_SLINGSHOT, "the HUD shows them", _hud_slots())
	var entry = state.floor_entry
	check(entry.scene_path == FLOOR_3_PATH and entry.inventory["items"].has(SLINGSHOT.id) and entry.action_slots.get(W) == SLINGSHOT,
			"Floor 3's entry state has the Slingshot and W = Slingshot")
	var save := _save()
	check(save.get("save_version") == 2.0 and save.get("floor_id") == "floor_03" and save.get("owned_items") == ["slingshot"]
			and save.get("inventory") == {"small_health_potion": 1.0} and save["carl"]["health"] == float(_entry_health)
			and save.get("action_slots") == {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": null, "action_d": "fists"},
			"the Floor 3 checkpoint on disk owns the Slingshot, with W = Slingshot", _save_text().replace("\n", " ").replace("\t", ""))
	check(_destinations().is_empty(), "Floor 3 has no exits: nothing leads back up", str(_destinations()))
	await wait_seconds(1.5)
	check(current_scene == level, "Carl stays on Floor 3 (no transition loop)")
	return true


func _floor_3_wall_stops_the_stone() -> bool:
	print("-- Floor 3: a stone shot at the wall")
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob")
	check(absf(blob.global_position.y - _carl().global_position.y) < 1.0 and blob.global_position.x > FLOOR_3_WALL_FACE_X,
			"the blob is in line with Carl, behind the wall")
	await tap_key(KEY_RIGHT)
	var fired := _record_shots()
	await tap_key(KEY_W)
	if fired.size() != 1:
		check(false, "a stone was fired")
		return true
	var stops := []
	var stone: Projectile = fired[0]
	stone.stopped.connect(func(collider: Object) -> void: stops.append([collider, stone.global_position]))
	await wait_seconds(1.0)
	check(stops.size() == 1 and stops[0][0] == current_scene.get_node("NavigationRegion2D/Terrain")
			and absf(stops[0][1].x - FLOOR_3_WALL_FACE_X) < 0.5, "the stone stops at the wall tiles' face", str(stops))
	check(blob.health.current_health == 30, "the blob behind the wall is unhurt")
	return true


func _floor_3_retry_keeps_the_slingshot() -> bool:
	for attempt in 2:
		print("-- Floor 3: death and retry %d" % (attempt + 1))
		if not await _die_and_retry(FLOOR_3_PATH):
			return false
		var state := game_state()
		check(state.inventory.has(SLINGSHOT) and state.action_slots.get_action(W) == SLINGSHOT,
				"retry %d: the Slingshot is still owned and on W" % (attempt + 1))
		check(state.inventory.get_actions() == [FISTS, POTION, SLINGSHOT] and state.inventory.get_quantity(POTION) == 1,
				"retry %d: one Slingshot, one potion, no duplicates" % (attempt + 1))
		check(_hud_slots() == HUD_WITH_SLINGSHOT and _carl().health.current_health == _entry_health,
				"retry %d: the HUD and the entry HP" % (attempt + 1), _hud_slots())
	return true


func _continue_on_floor_3() -> bool:
	print("-- Quit and Continue on Floor 3")
	if not await _open_title():
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of Floor 3  -  HP %d / 100" % _entry_health, "the title shows Floor 3", info)
	await tap_key(KEY_ENTER)
	# The first level to appear must be Floor 3 itself: no earlier floor is replayed.
	for i in 120:
		if current_scene != null and current_scene.scene_file_path != _title_path:
			break
		await physics_frame
	check(current_scene != null and current_scene.scene_file_path == FLOOR_3_PATH, "Continue opens Floor 3 directly")
	if not await wait_for_scene(FLOOR_3_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	check(state.inventory.has(SLINGSHOT) and state.action_slots.get_action(W) == SLINGSHOT
			and state.action_slots.get_action(D) == FISTS and state.inventory.get_quantity(POTION) == 1
			and _carl().health.current_health == _entry_health,
			"the Slingshot on W, Fists on D, 1 potion and the HP are restored")
	check(_hud_slots() == HUD_WITH_SLINGSHOT, "the HUD shows W: Slingshot", _hud_slots())
	var save_before := _save_text()

	# Around the wall, 256 px from the blob (outside its detection range), and fire.
	var blob: CharacterBody2D = current_scene.get_node("Actors/GelatinousBlob")
	await walk_to(blob.global_position - Vector2(256, 0))
	await tap_key(KEY_RIGHT)
	var damage_taken := []
	blob.health.damaged.connect(func(amount: int) -> void: damage_taken.append(amount))
	var fired := _record_shots()
	await hold_keys([KEY_W], 80)
	for i in 60:
		if blob.health.is_dead():
			break
		await physics_frame
	check(fired.size() == 3 and damage_taken == [10, 10, 10] and blob.health.is_dead(),
			"after Continue the Slingshot fires: three stones kill a Floor 3 blob", "%d stones, damage %s" % [fired.size(), damage_taken])
	check(_save_text() == save_before, "fighting does not change the save")
	return true


func _new_game_clears_the_slingshot() -> bool:
	print("-- New Game over the Floor 3 save")
	if not await _open_title():
		return false
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	check(not state.inventory.has(SLINGSHOT) and state.inventory.get_actions() == [FISTS],
			"the new game owns no Slingshot and no potions")
	check(_hud_slots() == "W: —   A: —   S: —   D: Fists", "W, A and S are empty and D = Fists", _hud_slots())
	check(_save().get("floor_id") == "surface" and _save().get("owned_items") == [], "the new Surface checkpoint owns nothing")
	return true


## Kills Carl, checks that GAME OVER waits without writing the save, then presses Enter.
func _die_and_retry(level_path: String) -> bool:
	var level := current_scene
	var level_id := level.get_instance_id()
	var save_before := _save_text()
	_carl().health.take_damage(1000)
	await wait_physics_frames(2)
	await wait_seconds(1.0)
	check(paused and level.get_node("HUD/%GameOverMessage").visible and current_scene == level, "GAME OVER waits")
	check(_save_text() == save_before, "death does not write the save")
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != level_id:
			break
		await physics_frame
	if not await wait_for_scene(level_path):
		return false
	await wait_physics_frames(3)
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


## Opens the action menu, reads Carl's list (without the "> " of the selected row), and closes
## it again.
func _menu_rows() -> Array:
	await tap_key(KEY_SPACE)
	var rows := current_scene.get_node("ActionMenu/%ActionList").get_children().map(
			func(row: Label) -> String: return row.text.trim_prefix("> "))
	await tap_key(KEY_SPACE)
	return rows


## Collects every stone Carl's Slingshot fires from now on. Returns the array it fills.
func _record_shots() -> Array:
	var fired := []
	(_carl().get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(
			func(stone: Projectile) -> void: fired.append(stone))
	return fired


func _open_title() -> bool:
	change_scene_to_file(_title_path)
	if not await wait_for_scene(_title_path):
		return false
	await wait_physics_frames(2)
	return true


func _slingshot_pickup() -> Node2D:
	var pickup := current_scene.get_node_or_null("Pickups/Slingshot")
	return pickup if pickup != null and not pickup.is_queued_for_deletion() else null


## Where every exit of the current level leads.
func _destinations() -> Array:
	return current_scene.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node).map(
			func(node: Node) -> String: return node.destination_scene_path)


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _save() -> Dictionary:
	var data: Variant = JSON.parse_string(_save_text())
	return data if data is Dictionary else {}


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")
