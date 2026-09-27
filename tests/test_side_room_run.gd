extends "res://tests/support/game_test.gd"
## Phase 15 end-to-end run: Floor 8's optional side room (a Lever, a Controlled Door and a Treasure
## Chest), through the real title screen, levels and menus, keys sent through Godot's input
## pipeline, on this test's own save and settings files. The run starts from a Floor 8 checkpoint
## (Carl 80, Donut 40, the Slingshot on W, one Blast Bomb on A, the Bat on S, Fists on D, no potion).
## - A. As authored: one Lever under NavigationRegion2D/Props, outside the side room; one Controlled
##   Door, vertical, in the side room's doorway, under Doors (outside the NavigationRegion2D, so the
##   navigation mesh keeps the doorway); the side room is walled all round except that doorway; one
##   Treasure Chest (the Phase 14 scene) inside it holding Small Health Potion x1 and Blast Bomb x1,
##   dropping into Pickups; the lever's `activated` is connected to the door's open() in the scene
##   (a persistent, editor-made connection) and to nothing else; the stairs lie outside the side
##   room and know nothing but their destination.
## - B. Continue on Floor 8: the lever inactive, the door closed and solid, the chest closed, no loot,
##   no prompt at the spawn; Carl cannot walk through the closed door.
## - C. Modal safety at the lever ("E: Pull Lever"): E does nothing in the action menu, nor held while
##   it closes; nothing in the pause menu, its Return to Title question or the Settings screen (the
##   prompt hidden meanwhile);
##   Interact is captured as Q there, and neither the Q nor the Escapes pull the lever; "Q: Pull
##   Lever", E does nothing; at GAME OVER neither Q nor E does anything; the retry has the lever
##   inactive, the door closed and Interact still on Q. Q pulls it: active, the door opens (solid no
##   more), the prompt goes; Q again does nothing and the door opens only once.
## - D. Carl walks into the side room through the doorway and Donut follows him in. "Q: Open Chest"; Q
##   opens it: Potion x1 and Blast Bomb x1 as two pickups below it, no inventory change; collecting
##   gives exactly potion 1 and bombs 2; nothing is saved by any of it.
## - E. Two Floor 8 deaths: each retry has the lever inactive, the door closed and solid, the chest
##   closed, no loot lying anywhere, the entry items (no potion, one bomb), Carl 80, Donut 40, the
##   enemies as authored; doing it all again gives exactly one set each time, never more.
## - F. Return to Title after collecting, then Continue: the title describes the Floor 8 checkpoint;
##   the lever inactive, the door closed, the chest closed, no loot, the entry items.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_side_room_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_8_PATH := "res://scenes/levels/floor_08.tscn"
const FLOOR_9_PATH := "res://scenes/levels/floor_09.tscn"
const CHEST_SCENE_PATH := "res://scenes/props/treasure_chest.tscn"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const LEVER_PATH := "NavigationRegion2D/Props/SideRoomLever"
const DOOR_PATH := "Doors/SideRoomDoor"
const CHEST_PATH := "NavigationRegion2D/Props/SideRoomChest"
const LEVER_AT := Vector2(304, 432)
const DOOR_AT := Vector2(272, 512)
const CHEST_AT := Vector2(144, 456)
## The side room's floor (tiles 1-7 by 13-18); its walls are row 12 and column 8.
const SIDE_ROOM := Rect2(32, 416, 224, 192)
## Where Carl stands to pull the lever (east of it) and to open the chest (below it).
const PULL_FROM := Vector2(338, 432)
const OPEN_FROM := Vector2(144, 488)
const ENTRY_CARL_HP := 80
const ENTRY_DONUT_HP := 40
const HUD_ENTRY := "W: Slingshot   A: Blast Bomb x1   S: Baseball Bat   D: Fists"
const WALL_TILE := Vector2i(3, 0)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60")
	_check_as_authored()
	if await _continue_on_floor_8() and await _modal_safety_at_the_lever() and await _into_the_side_room() \
			and await _floor_8_retries():
		await _return_to_title_and_continue()
	finish()


func _check_as_authored() -> void:
	print("-- A. Floor 8's side room as authored")
	var level: Node = (load(FLOOR_8_PATH) as PackedScene).instantiate()
	var levers := level.find_children("*", "StaticBody2D", true, false).filter(func(node: Node) -> bool: return node is Lever)
	var doors := level.find_children("*", "StaticBody2D", true, false).filter(func(node: Node) -> bool: return node is ControlledDoor)
	var chests := level.find_children("*", "StaticBody2D", true, false).filter(func(node: Node) -> bool: return node is TreasureChest)
	var lever: Lever = level.get_node_or_null(LEVER_PATH)
	var door: ControlledDoor = level.get_node_or_null(DOOR_PATH)
	var chest: TreasureChest = level.get_node_or_null(CHEST_PATH)
	var region := level.get_node("NavigationRegion2D")
	check(levers.size() == 1 and lever != null and lever.position == LEVER_AT and lever.get_parent().get_parent() == region
			and lever.position.x > SIDE_ROOM.end.x + 32.0, "one Lever, under NavigationRegion2D/Props, outside the side room (east of its wall)")
	check(doors.size() == 1 and door != null and door.position == DOOR_AT and is_equal_approx(door.rotation, PI / 2.0)
			and door.get_parent().name == &"Doors" and not region.is_ancestor_of(door),
			"one Controlled Door, vertical, in the doorway, outside the NavigationRegion2D (the mesh keeps the doorway)")
	check(chests.size() == 1 and chest != null and chest.scene_file_path == CHEST_SCENE_PATH and SIDE_ROOM.has_point(chest.position)
			and chest.get_parent().get_parent() == region, "one Treasure Chest (the Phase 14 scene), inside the side room, under NavigationRegion2D/Props")
	check(chest != null and chest.contents == {&"small_health_potion": 1, &"blast_bomb": 1} and chest.loot_parent == level.get_node("Pickups"),
			"it holds Small Health Potion x1 and Blast Bomb x1, dropped into the level's Pickups node")
	var connections: Array = lever.get_signal_connection_list(&"activated") if lever != null else []
	check(connections.size() == 1 and connections[0]["callable"].get_object() == door and connections[0]["callable"].get_method() == &"open"
			and (connections[0]["flags"] & CONNECT_PERSIST) != 0, "the lever's `activated` is connected to the door's open() in the scene, and to nothing else",
			str(connections))
	# The side room is closed all round except for the doorway (column 8, rows 15 and 16).
	var terrain: TileMapLayer = level.get_node("NavigationRegion2D/Terrain")
	var openings := []
	for x in range(0, 9):
		if terrain.get_cell_atlas_coords(Vector2i(x, 12)) != WALL_TILE:
			openings.append(Vector2i(x, 12))
	for y in range(12, 20):
		if terrain.get_cell_atlas_coords(Vector2i(8, y)) != WALL_TILE:
			openings.append(Vector2i(8, y))
	for y in range(12, 20):
		if terrain.get_cell_atlas_coords(Vector2i(0, y)) != WALL_TILE:
			openings.append(Vector2i(0, y))
	for x in range(0, 9):
		if terrain.get_cell_atlas_coords(Vector2i(x, 19)) != WALL_TILE:
			openings.append(Vector2i(x, 19))
	check(openings == [Vector2i(8, 15), Vector2i(8, 16)], "the side room's only opening is the doorway the door fills", str(openings))
	var stairs: Node2D = level.get_node("Stairs")
	check(stairs.destination_scene_path == FLOOR_9_PATH and not SIDE_ROOM.grow(32).has_point(stairs.position),
			"the stairs down to Floor 9 are outside the side room", str(stairs.position))
	var stored := (stairs.get_script() as Script).get_script_property_list().filter(
			func(p: Dictionary) -> bool: return (p["usage"] & PROPERTY_USAGE_STORAGE) != 0).map(func(p: Dictionary) -> String: return p["name"])
	check(stored == ["destination_scene_path"], "the stairs know nothing but their destination", str(stored))
	level.free()


func _continue_on_floor_8() -> bool:
	print("-- B. Continue on Floor 8")
	_write_floor_8_save()
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await _arrive():
		return false
	check(not _lever().is_active() and _lever().inactive_look.visible, "the lever is inactive")
	check(not _door().is_open() and _door().is_blocking() and _door().closed_look.visible, "the door is closed and solid")
	check(not _chest().is_open() and _all_pickups().is_empty(), "the chest is closed and no loot lies anywhere")
	check(_hud_slots() == HUD_ENTRY and _carl().health.current_health == ENTRY_CARL_HP, "Carl 80 with the entry slots", _hud_slots())
	check(_prompt() == "", "no prompt at the spawn point")
	_carl().teleport_to(DOOR_AT + Vector2(48, 0))
	await wait_physics_frames(2)
	await hold_keys([KEY_LEFT], 60)
	check(_carl().global_position.x > DOOR_AT.x + 16.0 + 12.0 - 0.5 and not SIDE_ROOM.has_point(_carl().global_position),
			"Carl cannot walk through the closed door", str(_carl().global_position))
	return true


func _modal_safety_at_the_lever() -> bool:
	print("-- C. The menus never pull the lever")
	var menu: CanvasLayer = current_scene.get_node("ActionMenu")
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	var settings: Control = pause.get_node("%SettingsMenu")
	_carl().teleport_to(PULL_FROM)
	await wait_physics_frames(3)
	check(_prompt() == "E: Pull Lever", "next to the lever: \"E: Pull Lever\"", _prompt())
	# The action menu.
	await tap_key(KEY_SPACE)
	check(menu.is_open() and _prompt() == "", "the action menu is open; the prompt is hidden")
	await tap_key(KEY_E)
	await tap_key(KEY_SPACE)
	await wait_physics_frames(10)
	check(not menu.is_open() and not _lever().is_active() and _prompt() == "E: Pull Lever", "E in the action menu did nothing; the prompt is back")
	await tap_key(KEY_SPACE)
	send_key(KEY_E, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	await wait_physics_frames(20)
	check(not menu.is_open() and not _lever().is_active(), "E held while the menu closes pulls nothing")
	send_key(KEY_E, false)
	await wait_physics_frames(2)
	# The pause menu.
	await tap_key(KEY_ESCAPE)
	check(pause.is_open() and _prompt() == "", "the pause menu is open; the prompt is hidden")
	await tap_key(KEY_E)
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(10)
	check(not pause.is_open() and not _lever().is_active(), "E in the pause menu did nothing")
	# The Return to Title question (a confirmation dialog): E there, then No and resume.
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(pause.is_confirming() and _prompt() == "", "the Return to Title question is up; the prompt is hidden")
	await tap_key(KEY_E)
	check(pause.is_confirming() and not _lever().is_active(), "E at the question does nothing")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(10)
	check(not pause.is_open() and not _lever().is_active() and current_scene.scene_file_path == FLOOR_8_PATH,
			"No, then resume: still on Floor 8, the lever untouched")
	# The Settings screen: E on the list, then Interact captured as Q.
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings.is_open() and paused, "Settings is open over the paused game")
	await tap_key(KEY_E)
	check(settings.get_capturing_action() == &"" and not _lever().is_active(), "E on the Settings list does nothing")
	while settings.get_selected_row() != ControlBindings.ACTIONS.find(&"interact"):
		await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings.get_capturing_action() == &"interact", "Enter on Interact waits for a key")
	await tap_key(KEY_Q)
	check(ControlBindings.get_key(&"interact") == KEY_Q and settings.get_message() == "Interact is now Q.", "Q is captured for Interact",
			settings.get_message())
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(20)
	check(not paused and not _lever().is_active() and not _door().is_open(), "back in play: neither the captured Q nor the Escapes pulled the lever")
	check(_prompt() == "Q: Pull Lever", "the prompt now says Q", _prompt())
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(not _lever().is_active(), "E does nothing now")
	# GAME OVER.
	var level_id := current_scene.get_instance_id()
	_carl().health.take_damage(1000)
	await wait_physics_frames(3)
	check(paused and _game_over_visible() and _prompt() == "", "GAME OVER: the prompt is hidden")
	await tap_key(KEY_Q)
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(not _lever().is_active() and not _door().is_open(), "at GAME OVER neither Q nor E pulls the lever")
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != level_id:
			break
		await physics_frame
	if not await _arrive():
		return false
	check(not _lever().is_active() and not _door().is_open() and _door().is_blocking() and ControlBindings.get_key(&"interact") == KEY_Q,
			"the retry: the lever inactive, the door closed, Interact still on Q")
	_carl().teleport_to(PULL_FROM)
	await wait_physics_frames(3)
	check(_prompt() == "Q: Pull Lever", "\"Q: Pull Lever\"", _prompt())
	var openings := [0]
	_door().opened.connect(func() -> void: openings[0] += 1)
	await tap_key(KEY_Q)
	check(_lever().is_active() and _lever().active_look.visible and _door().is_open() and _door().open_look.visible,
			"Q pulls it: the lever active, the door open")
	await wait_physics_frames(2)
	check(not _door().is_blocking() and _prompt() == "", "the door is solid no more; the prompt is gone")
	await tap_key(KEY_Q)
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(_lever().is_active() and openings[0] == 1, "Q again does nothing; the door opened once")
	return true


func _into_the_side_room() -> bool:
	print("-- D. The side room")
	var state := game_state()
	var save_before := _save_text()
	var save_time := FileAccess.get_modified_time(save_manager().save_path)
	var donut := _donut()
	check(await walk_to(OPEN_FROM) and SIDE_ROOM.has_point(_carl().global_position), "Carl walks through the doorway into the side room",
			str(_carl().global_position))
	check(await wait_until(func() -> bool: return SIDE_ROOM.has_point(donut.global_position), "Donut to follow into the side room", 300),
			"Donut follows him in", str(donut.global_position))
	await wait_physics_frames(3)
	check(_prompt() == "Q: Open Chest", "at the chest: \"Q: Open Chest\"", _prompt())
	await tap_key(KEY_Q)
	await wait_physics_frames(2)
	check(_chest().is_open(), "Q opens it")
	check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1, "opening it changed no inventory")
	var loot := _loot()
	check(loot.size() == 2 and loot[0].item == POTION and loot[0].quantity == 1 and loot[1].item == BOMB and loot[1].quantity == 1,
			"two pickups: Potion x1 and Blast Bomb x1", str(loot.map(func(p: ItemPickup) -> String: return p.get_node("Label").text)))
	if loot.size() != 2:
		return false
	check(loot[0].global_position == CHEST_AT + Vector2(-40, 72) and loot[1].global_position == CHEST_AT + Vector2(40, 72)
			and SIDE_ROOM.has_point(loot[0].global_position) and SIDE_ROOM.has_point(loot[1].global_position),
			"below the chest, inside the side room", "%s %s" % [loot[0].global_position, loot[1].global_position])
	await wait_physics_frames(30)
	check(_loot().size() == 2 and state.inventory.get_quantity(POTION) == 0, "Donut takes nothing")
	settings_manager().reset_to_defaults()
	await _collect(loot[0])
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 1, "the potion: exactly 1")
	await _collect(loot[1])
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 2, "the bomb: exactly 1 more (2)")
	check(_loot().is_empty() and _hud_slots() == "W: Slingshot   A: Blast Bomb x2   S: Baseball Bat   D: Fists", "the pickups are gone; HUD A: Blast Bomb x2",
			_hud_slots())
	check(_save_text() == save_before and FileAccess.get_modified_time(save_manager().save_path) == save_time,
			"pulling the lever, opening the door and the chest and collecting the loot saved nothing")
	return true


func _floor_8_retries() -> bool:
	print("-- E. Floor 8 deaths put the side room back")
	for attempt in 2:
		if not await _die_and_retry():
			return false
		var state := game_state()
		var label := "retry %d: " % (attempt + 1)
		check(not _lever().is_active() and _lever().inactive_look.visible, label + "the lever is inactive")
		check(not _door().is_open() and _door().is_blocking() and _door().closed_look.visible, label + "the door is closed and solid")
		check(not _chest().is_open() and _loot().is_empty() and _all_pickups().is_empty(), label + "the chest is closed, no loot lies anywhere")
		check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1 and _hud_slots() == HUD_ENTRY,
				label + "no potion, one bomb on A, as on entering", _hud_slots())
		check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP, label + "Carl 80, Donut 40")
		var enemies := _enemies()
		check(enemies.size() == 2 and enemies.all(func(enemy: Enemy) -> bool: return enemy.health.current_health == 30),
				label + "the two enemies as authored")
		await _pull_and_open()
		var loot := _loot()
		check(loot.size() == 2 and loot[0].item == POTION and loot[0].quantity == 1 and loot[1].item == BOMB and loot[1].quantity == 1,
				label + "the chest drops exactly one set again")
		for pickup: ItemPickup in loot:
			await _collect(pickup)
		check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 2, label + "collected again: potion 1, bombs 2, never more")
	return true


func _return_to_title_and_continue() -> void:
	print("-- F. Return to Title, then Continue")
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
	check(current_scene.get_node("%SaveInfoLabel").text == "Saved at the start of Floor 8  -  HP 80 / 100", "the title describes the Floor 8 checkpoint")
	await tap_key(KEY_ENTER)
	if not await _arrive():
		return
	var state := game_state()
	check(not _lever().is_active() and not _door().is_open() and _door().is_blocking(), "Continue: the lever inactive, the door closed")
	check(not _chest().is_open() and _all_pickups().is_empty(), "the chest closed, no loot")
	check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1 and _hud_slots() == HUD_ENTRY,
			"the Floor 8 entry items: no potion, one bomb", _hud_slots())


## Pulls the lever with E, walks into the side room and opens the chest with E.
func _pull_and_open() -> void:
	_carl().teleport_to(PULL_FROM)
	await wait_physics_frames(3)
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(_lever().is_active() and _door().is_open(), "E pulls the lever and the door opens")
	await walk_to(OPEN_FROM)
	await wait_physics_frames(3)
	check(_prompt() == "E: Open Chest", "at the chest: \"E: Open Chest\"", _prompt())
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(_chest().is_open(), "E opens it")


## Walks Carl onto `pickup` from beside it.
func _collect(pickup: ItemPickup) -> void:
	var at := pickup.global_position
	_carl().teleport_to(at + Vector2(0, 28))
	await wait_physics_frames(2)
	await walk_to(at)
	await wait_physics_frames(3)


func _write_floor_8_save() -> void:
	var data := {
		"save_version": 3, "floor_id": "floor_08",
		"carl": {"health": ENTRY_CARL_HP, "max_health": 100}, "donut": {"health": ENTRY_DONUT_HP, "max_health": 60},
		"inventory": {"blast_bomb": 1}, "owned_items": ["slingshot", "baseball_bat"],
		"action_slots": {"action_w": "slingshot", "action_a": "blast_bomb", "action_s": "baseball_bat", "action_d": "fists"},
	}
	DirAccess.make_dir_recursive_absolute(save_manager().save_path.get_base_dir())
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## Waits for Floor 8, then keeps its enemies idle (their fights are other tests'), so every number
## is exact.
func _arrive() -> bool:
	if not await wait_for_scene(FLOOR_8_PATH):
		return false
	await wait_physics_frames(3)
	for enemy in _enemies():
		enemy.detection_range = 0.0
		enemy.chase_range = 0.0
	return true


func _die_and_retry() -> bool:
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
	return await _arrive()


func _open_title() -> bool:
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	paused = false
	change_scene_to_file(title_path)
	if not await wait_for_scene(title_path):
		return false
	await wait_physics_frames(2)
	return true


func _enemies() -> Array:
	return current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool: return node is Enemy)


func _lever() -> Lever:
	return current_scene.get_node_or_null(LEVER_PATH)


func _door() -> ControlledDoor:
	return current_scene.get_node_or_null(DOOR_PATH)


func _chest() -> TreasureChest:
	return current_scene.get_node_or_null(CHEST_PATH)


## The chest's loot lying in Floor 8's Pickups node, in the order it was dropped.
func _loot() -> Array:
	return current_scene.get_node("Pickups").get_children().filter(func(node: Node) -> bool:
		return node is ItemPickup and not node.is_queued_for_deletion())


## Every pickup anywhere in the level.
func _all_pickups() -> Array:
	return current_scene.find_children("*", "Area2D", true, false).filter(func(node: Node) -> bool:
		return node is ItemPickup and not node.is_queued_for_deletion())


func _prompt() -> String:
	return (_carl().get_node("InteractionController") as InteractionController).get_prompt_text()


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _game_over_visible() -> bool:
	return current_scene.get_node("HUD/%GameOverMessage").visible


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _donut() -> CharacterBody2D:
	return current_scene.get_node("Actors/Donut")
