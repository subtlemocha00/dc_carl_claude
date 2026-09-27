extends "res://tests/support/game_test.gd"
## Phase 15 end-to-end run: Floor 8's stairs down to Floor 9, which never depend on the side room,
## and Floor 9 itself, through the real title screen, levels and menus, keys sent through Godot's
## input pipeline, on this test's own save and settings files. Floor 8 runs start from a real
## Phase 14 save (tests/fixtures/phase14_save_v3_floor_08.json, written by the Phase 14 game on
## entering Floor 8: Carl 80, Donut 40, the Slingshot on W, one Blast Bomb on A, the Bat on S).
## - A. floor_09 is registered as "Floor 9" (ten floors, no floor_10); every exit leads one floor
##   down, Floor 8's to Floor 9, and Floor 9 has none. The stairs' code looks at nothing but Carl's
##   body and the paused tree: no lever, door, chest, enemy or inventory.
## - B. The skip path: Continue on Floor 8, the lever never touched, the door closed, the chest
##   closed; Carl walks from the spawn point to the stairs along the navigation route; Floor 9
##   opens. Its checkpoint (memory and disk, save_version 3) has exactly the Floor 8 entry items.
## - C. The side room used, only the potion collected: Floor 9's checkpoint gains the potion only;
##   the bomb left lying on Floor 8 is not carried.
## - D. Both collected (the potion put on W): Floor 9 arrival (Carl at the spawn point, Donut beside
##   him, the camera, the sign, the HUD, a Gelatinous and a Spitting Blob, no lever, door, chest or
##   exit, no loop); its checkpoint in memory and on disk: potion 1, bombs 2, the same seven fields.
## - E. Floor 9 plays: both enemies notice Carl, a bomb hurts the blob, the potion heals; a death and
##   retry restore the Floor 9 entry (potion 1, bombs 2, slots, Carl 80, Donut 40, the enemies).
## - F. Return to Title: the title describes the Floor 9 checkpoint; Continue opens Floor 9 directly
##   with the carried items.
## - G. Compatibility: the save format is still 3 and the settings format still 2; real version 1,
##   2 and 3 saves (Phases 5, 6, 11 and 14) still load; a version 3 Floor 9 save loads; a
##   floor_10 save is refused; a real Phase 14 settings file (version 2, Interact on Q) loads as
##   it is, unchanged, and the lever then says "Q: Pull Lever" and Q pulls it (E does nothing).
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_09_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_PATHS: Array[String] = [
	"res://scenes/levels/surface.tscn", "res://scenes/levels/floor_01.tscn", "res://scenes/levels/floor_02.tscn",
	"res://scenes/levels/floor_03.tscn", "res://scenes/levels/floor_04.tscn", "res://scenes/levels/floor_05.tscn",
	"res://scenes/levels/floor_06.tscn", "res://scenes/levels/floor_07.tscn", "res://scenes/levels/floor_08.tscn",
	"res://scenes/levels/floor_09.tscn",
]
const FLOOR_8_PATH := "res://scenes/levels/floor_08.tscn"
const FLOOR_9_PATH := "res://scenes/levels/floor_09.tscn"
const BLOB_PATH := "res://scenes/enemies/gelatinous_blob.tscn"
const SPITTER_PATH := "res://scenes/enemies/spitting_blob.tscn"
const FLOOR_8_FIXTURE := "res://tests/fixtures/phase14_save_v3_floor_08.json"
const SETTINGS_FIXTURE := "res://tests/fixtures/phase14_settings_v2_interact_q.json"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const LEVER_PATH := "NavigationRegion2D/Props/SideRoomLever"
const DOOR_PATH := "Doors/SideRoomDoor"
const CHEST_PATH := "NavigationRegion2D/Props/SideRoomChest"
const PULL_FROM := Vector2(338, 432)
const OPEN_FROM := Vector2(144, 488)
const ENTRY_CARL_HP := 80
const ENTRY_DONUT_HP := 40
const SPAWN := Vector2(176, 176)
const DONUT_SPAWN := Vector2(176, 232)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60")
	_check_registry_and_exits()
	if await _skip_path() and await _only_the_potion() and await _both_to_floor_9() and await _floor_9_plays_and_retries():
		await _return_to_title_and_continue_floor_9()
	await _check_compatibility()
	finish()


func _check_registry_and_exits() -> void:
	print("-- A. floor_09 and the exits")
	check(FloorRegistry.FLOORS.size() == 10 and FloorRegistry.FLOORS.keys()[9] == &"floor_09" and FloorRegistry.get_scene_path(&"floor_09") == FLOOR_9_PATH
			and FloorRegistry.get_display_name(&"floor_09") == "Floor 9" and FloorRegistry.get_floor_id(FLOOR_9_PATH) == &"floor_09",
			"floor_09 is the tenth registered floor, shown as 'Floor 9'")
	check(not FloorRegistry.has_floor(&"floor_10") and FloorRegistry.get_scene_path(&"floor_10") == "", "there is no floor_10")
	for i in FLOOR_PATHS.size():
		var level: Node = (load(FLOOR_PATHS[i]) as PackedScene).instantiate()
		var expected: Array = [FLOOR_PATHS[i + 1]] if i + 1 < FLOOR_PATHS.size() else []
		var destinations := _destinations(level)
		check(destinations == expected, "%s leads only to %s" % [FLOOR_PATHS[i].get_file(), expected], str(destinations))
		level.free()
	var code := _code("res://scripts/props/stairs.gd")
	for word in ["Lever", "lever", "Door", "door", "Chest", "chest", "Enemy", "enemies", "inventory", "Inventory", "GameState", "is_active", "is_open"]:
		check(not code.contains(word), "the stairs' code does not use \"%s\"" % word)


func _skip_path() -> bool:
	print("-- B. The skip path: straight to the stairs, the side room untouched")
	_use_floor_8_fixture()
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_8_PATH):
		return false
	var lever: Lever = current_scene.get_node(LEVER_PATH)
	var door: ControlledDoor = current_scene.get_node(DOOR_PATH)
	var chest: TreasureChest = current_scene.get_node(CHEST_PATH)
	var states := []
	var record_states := func() -> void: states.append([lever.is_active(), door.is_open(), door.is_blocking(), chest.is_open()])
	# Recorded the moment the stairs change the level (before Floor 8 goes away).
	current_scene.get_node("Stairs").body_entered.connect(func(_body: Node2D) -> void: record_states.call())
	check(not lever.is_active() and not door.is_open() and door.is_blocking() and not chest.is_open(), "the lever inactive, the door closed, the chest closed")
	var stairs_at: Vector2 = current_scene.get_node("Stairs").global_position
	check(await walk_to(stairs_at), "Carl walks from the spawn point to the stairs along the navigation route")
	if not await _arrive(FLOOR_9_PATH):
		return false
	check(states == [[false, false, true, false]], "on the stairs the lever was still inactive, the door closed and solid, the chest closed", str(states))
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1, "Floor 9: exactly the Floor 8 entry items (one bomb)")
	check(state.floor_entry.scene_path == FLOOR_9_PATH and state.floor_entry.inventory["quantities"] == {&"blast_bomb": 1},
			"the Floor 9 checkpoint holds them", str(state.floor_entry.inventory))
	check(_save().get("floor_id") == "floor_09" and _save().get("save_version") == 3.0 and _save().get("inventory") == {"blast_bomb": 1.0},
			"and so does the save (version 3)", _save_text())
	return true


func _only_the_potion() -> bool:
	print("-- C. Only the potion collected: the bomb left behind is not carried")
	if not await _continue_floor_8_fixture():
		return false
	await _pull_and_open()
	var loot := _loot()
	if loot.size() != 2:
		check(false, "the loot appeared")
		return false
	await _collect(loot[0])
	check(game_state().inventory.get_quantity(POTION) == 1 and _loot().size() == 1, "the potion collected, the bomb still lying there")
	if not await _take_the_stairs():
		return false
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 1, "Floor 9: the potion and the one bomb Carl carried")
	check(state.floor_entry.inventory["quantities"] == {&"blast_bomb": 1, &"small_health_potion": 1}, "the checkpoint holds exactly that",
			str(state.floor_entry.inventory))
	check(_save().get("inventory") == {"small_health_potion": 1.0, "blast_bomb": 1.0}, "and so does the save", _save_text())
	return true


func _both_to_floor_9() -> bool:
	print("-- D. Both collected, the potion put on W, then Floor 9")
	if not await _continue_floor_8_fixture():
		return false
	await _pull_and_open()
	for pickup: ItemPickup in _loot():
		await _collect(pickup)
	await _assign_in_menu("Small Health Potion", KEY_W)
	var hud_carried := "W: Potion x1   A: Blast Bomb x2   S: Baseball Bat   D: Fists"
	check(_hud_slots() == hud_carried, "Floor 8: the potion on W, two bombs on A", _hud_slots())
	if not await _take_the_stairs():
		return false
	var level := current_scene
	var carl := _carl()
	var donut := _donut()
	check(carl.global_position == SPAWN and donut.global_position.distance_to(DONUT_SPAWN) < 40.0, "Carl arrives at the spawn point, Donut beside him",
			"%s %s" % [carl.global_position, donut.global_position])
	check(carl.camera.is_current() and level.get_node("Signs/FloorTitle").text == "Floor 9 - Lower Hall", "the camera follows Carl; the floor sign says Floor 9")
	check(_hud_slots() == hud_carried and level.get_node("HUD/%HealthLabel").text == "Carl HP: 80 / 100"
			and level.get_node("HUD/%DonutHealthLabel").text == "Donut HP: 40 / 60", "the HUD: the carried slots, Carl 80, Donut 40", _hud_slots())
	check(_enemies(BLOB_PATH).size() == 1 and _enemies(SPITTER_PATH).size() == 1 and _enemies().size() == 2, "a Gelatinous Blob and a Spitting Blob")
	check(_destinations(level).is_empty(), "no exits: nothing leads back up to Floor 8, and nothing further down")
	check(level.find_children("*", "StaticBody2D", true, false).filter(func(node: Node) -> bool:
			return node is Lever or node is ControlledDoor or node is TreasureChest).is_empty() and _all_pickups().is_empty(),
			"no lever, door, chest or loot on Floor 9")
	var entry: FloorEntry = game_state().floor_entry
	check(entry.scene_path == FLOOR_9_PATH and entry.carl_health == ENTRY_CARL_HP and entry.donut_health == ENTRY_DONUT_HP
			and entry.inventory["quantities"] == {&"blast_bomb": 2, &"small_health_potion": 1}
			and entry.action_slots == {&"action_w": POTION, &"action_a": BOMB, &"action_s": BAT, &"action_d": FISTS},
			"the Floor 9 checkpoint in memory: potion 1, bombs 2, W potion, A bombs, S Bat, D Fists")
	var expected := {
		"save_version": 3, "floor_id": "floor_09", "carl": {"health": 80, "max_health": 100}, "donut": {"health": 40, "max_health": 60},
		"inventory": {"small_health_potion": 1, "blast_bomb": 2}, "owned_items": ["slingshot", "baseball_bat"],
		"action_slots": {"action_w": "small_health_potion", "action_a": "blast_bomb", "action_s": "baseball_bat", "action_d": "fists"},
	}
	check(_save() == JSON.parse_string(JSON.stringify(expected)), "and on disk: save_version 3, the same seven fields", _save_text())
	await wait_seconds(1.0)
	check(current_scene == level, "Carl stays on Floor 9 (no transition loop)")
	return true


func _floor_9_plays_and_retries() -> bool:
	print("-- E. Floor 9 plays, then a retry restores its checkpoint")
	var carl := _carl()
	var blob: Enemy = _enemies(BLOB_PATH)[0]
	var spitter: Enemy = _enemies(SPITTER_PATH)[0]
	carl.teleport_to(blob.global_position + Vector2(-150, 0))
	await wait_physics_frames(10)
	check(blob.target == carl, "the blob notices Carl")
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_A)
	await wait_until(func() -> bool: return blob.health.current_health < 30, "the bomb to hit the blob", 90)
	check(blob.health.current_health == 10 and game_state().inventory.get_quantity(BOMB) == 1, "a bomb takes 20 from the blob; 1 bomb left")
	carl.teleport_to(spitter.global_position + Vector2(-150, 60))
	await wait_physics_frames(10)
	check(spitter.target == carl or spitter.target == _donut(), "the Spitting Blob notices the party")
	carl.health.take_damage(50)
	await tap_key(KEY_W)
	check(game_state().inventory.get_quantity(POTION) == 0 and carl.health.current_health >= 60, "the potion heals and is used up",
			str(carl.health.current_health))
	if not await _die_and_retry(FLOOR_9_PATH):
		return false
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 2
			and _hud_slots() == "W: Potion x1   A: Blast Bomb x2   S: Baseball Bat   D: Fists", "the retry: potion 1 on W, bombs 2 on A", _hud_slots())
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP and _carl().global_position == SPAWN,
			"Carl 80 at the spawn point, Donut 40")
	check(_enemies().size() == 2 and _enemies().all(func(enemy: Enemy) -> bool: return enemy.health.current_health == 30), "the enemies as authored")
	return true


func _return_to_title_and_continue_floor_9() -> void:
	print("-- F. Return to Title, then Continue on Floor 9")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if not await wait_for_scene(title_path):
		return
	await wait_physics_frames(2)
	check(current_scene.get_node("%SaveInfoLabel").text == "Saved at the start of Floor 9  -  HP 80 / 100", "the title describes the Floor 9 checkpoint",
			current_scene.get_node("%SaveInfoLabel").text)
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_9_PATH):
		return
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 2 and state.inventory.has(SLINGSHOT) and state.inventory.has(BAT)
			and _hud_slots() == "W: Potion x1   A: Blast Bomb x2   S: Baseball Bat   D: Fists", "Continue opens Floor 9 with the carried items and slots", _hud_slots())
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP, "Carl 80, Donut 40")


func _check_compatibility() -> void:
	print("-- G. Compatibility")
	var saves := save_manager()
	check(saves.SAVE_VERSION == 3 and settings_manager().SETTINGS_VERSION == 2, "the save format is still 3 and the settings format still 2")
	for case: Array in [
			["res://tests/fixtures/phase5_save_v1_floor_01.json", "res://scenes/levels/floor_01.tscn"],
			["res://tests/fixtures/phase6_save_v2_floor_03.json", "res://scenes/levels/floor_03.tscn"],
			["res://tests/fixtures/phase11_save_v3_floor_06.json", "res://scenes/levels/floor_06.tscn"],
			[FLOOR_8_FIXTURE, FLOOR_8_PATH]]:
		var entry: FloorEntry = saves.decode(JSON.parse_string(FileAccess.get_file_as_string(case[0])))
		check(entry != null and entry.scene_path == case[1], "%s still loads" % case[0].get_file(), saves.last_error)
	var floor_9 := {
		"save_version": 3, "floor_id": "floor_09", "carl": {"health": 55, "max_health": 100}, "donut": {"health": 60, "max_health": 60},
		"inventory": {"blast_bomb": 2}, "owned_items": ["slingshot"],
		"action_slots": {"action_w": "slingshot", "action_a": "blast_bomb", "action_s": null, "action_d": "fists"},
	}
	var loaded: FloorEntry = saves.decode(JSON.parse_string(JSON.stringify(floor_9)))
	check(loaded != null and loaded.scene_path == FLOOR_9_PATH and loaded.carl_health == 55 and loaded.inventory["quantities"] == {&"blast_bomb": 2},
			"a version 3 Floor 9 save loads", saves.last_error)
	var floor_10 := floor_9.duplicate(true)
	floor_10["floor_id"] = "floor_10"
	check(saves.decode(JSON.parse_string(JSON.stringify(floor_10))) == null and saves.last_error.contains("floor_10"), "a floor_10 save is refused",
			saves.last_error)
	# A real Phase 14 settings file: version 2, Interact on Q.
	var fixture_text := FileAccess.get_file_as_string(SETTINGS_FIXTURE)
	var fixture: Variant = JSON.parse_string(fixture_text)
	check(fixture is Dictionary and fixture.get("settings_version") == 2.0 and fixture.get("keyboard", {}).get("interact") == "Q"
			and fixture.get("keyboard", {}).size() == 10, "the Phase 14 settings file is version 2 with ten keys, Interact on Q")
	var file := FileAccess.open(settings_manager().settings_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	check(settings_manager().load_settings() and settings_manager().migrated_from_version == 0 and ControlBindings.get_key(&"interact") == KEY_Q
			and ControlBindings.get_key(&"move_up") == KEY_UP, "it loads as it is: Interact on Q, the rest the defaults")
	check(FileAccess.get_file_as_string(settings_manager().settings_path) == fixture_text, "and is not rewritten")
	if not await _continue_floor_8_fixture():
		return
	_carl().teleport_to(PULL_FROM)
	await wait_physics_frames(3)
	check(_prompt() == "Q: Pull Lever", "the lever says \"Q: Pull Lever\"", _prompt())
	await tap_key(KEY_E)
	check(not current_scene.get_node(LEVER_PATH).is_active(), "E does nothing")
	await tap_key(KEY_Q)
	check(current_scene.get_node(LEVER_PATH).is_active() and current_scene.get_node(DOOR_PATH).is_open(), "Q pulls it and the door opens")
	settings_manager().reset_to_defaults()


## Puts the real Phase 14 Floor 8 save in this test's save file.
func _use_floor_8_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(save_manager().save_path.get_base_dir())
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FLOOR_8_FIXTURE))
	file.close()


func _continue_floor_8_fixture() -> bool:
	_use_floor_8_fixture()
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	return await _arrive(FLOOR_8_PATH)


## Pulls the lever with the Interact key, walks into the side room and opens the chest.
func _pull_and_open() -> void:
	_carl().teleport_to(PULL_FROM)
	await wait_physics_frames(3)
	await tap_key(ControlBindings.get_key(&"interact"))
	await wait_physics_frames(2)
	await walk_to(OPEN_FROM)
	await wait_physics_frames(3)
	await tap_key(ControlBindings.get_key(&"interact"))
	await wait_physics_frames(2)
	check((current_scene.get_node(CHEST_PATH) as TreasureChest).is_open(), "the lever pulled, the side room entered, the chest opened")


## Walks Carl onto `pickup` from beside it.
func _collect(pickup: ItemPickup) -> void:
	var at := pickup.global_position
	_carl().teleport_to(at + Vector2(0, 28))
	await wait_physics_frames(2)
	await walk_to(at)
	await wait_physics_frames(3)


func _take_the_stairs() -> bool:
	var stairs: Node2D = current_scene.get_node("Stairs")
	_carl().teleport_to(stairs.global_position + Vector2(-70, 0))
	await wait_physics_frames(3)
	await walk_to(stairs.global_position)
	return await _arrive(FLOOR_9_PATH)


## Waits for `level_path`. On Floor 8 its enemies are kept idle (their fights are other tests'), so
## Carl can walk anywhere and every number is exact; Floor 9's enemies are left as they are.
func _arrive(level_path: String) -> bool:
	if not await wait_for_scene(level_path):
		return false
	await wait_physics_frames(3)
	if level_path == FLOOR_8_PATH:
		for enemy in _enemies():
			enemy.detection_range = 0.0
			enemy.chase_range = 0.0
	return true


func _die_and_retry(level_path: String) -> bool:
	var level_id := current_scene.get_instance_id()
	var save_before := _save_text()
	_carl().health.take_damage(1000)
	await wait_physics_frames(3)
	check(paused and _game_over_visible(), "GAME OVER waits")
	check(_save_text() == save_before, "death does not write the save")
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != level_id:
			break
		await physics_frame
	return await _arrive(level_path)


## Opens the action menu, selects the first action whose name starts with `action_name`, presses
## `key` to put it in that slot, and closes the menu.
func _assign_in_menu(action_name: String, key: Key) -> void:
	await tap_key(KEY_SPACE)
	var list := current_scene.get_node("ActionMenu/%ActionList")
	for i in list.get_child_count():
		if (list.get_child(i) as Label).text.begins_with("> " + action_name):
			break
		await tap_key(KEY_DOWN)
	await tap_key(key)
	await tap_key(KEY_SPACE)


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
	return level.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node).map(
			func(node: Node) -> String: return node.destination_scene_path)


func _enemies(scene_path: String = "") -> Array:
	return current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool:
		return node is Enemy and (scene_path.is_empty() or node.scene_file_path == scene_path))


func _loot() -> Array:
	return current_scene.get_node("Pickups").get_children().filter(func(node: Node) -> bool:
		return node is ItemPickup and not node.is_queued_for_deletion())


func _all_pickups() -> Array:
	return current_scene.find_children("*", "Area2D", true, false).filter(func(node: Node) -> bool:
		return node is ItemPickup and not node.is_queued_for_deletion())


func _prompt() -> String:
	return (_carl().get_node("InteractionController") as InteractionController).get_prompt_text()


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _save() -> Dictionary:
	var data: Variant = JSON.parse_string(_save_text())
	return data if data is Dictionary else {}


func _game_over_visible() -> bool:
	return current_scene.get_node("HUD/%GameOverMessage").visible


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _donut() -> CharacterBody2D:
	return current_scene.get_node("Actors/Donut")


## A script's code without its comments.
func _code(path: String) -> String:
	var code := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var hash_at := line.find("#")
		code.append(line if hash_at == -1 else line.substr(0, hash_at))
	return "\n".join(code)
