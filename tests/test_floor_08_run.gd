extends "res://tests/support/game_test.gd"
## Phase 14 end-to-end run: Floor 7's treasure chest, the Interact key in the real game, and Floor 8,
## through the real title screen, levels and menus, keys sent through Godot's input pipeline, on this
## test's own save and settings files. The run starts from a Floor 7 checkpoint (Carl 80, Donut 40,
## the Slingshot on W, one Blast Bomb on A, the Bat on S, Fists on D, no potion).
## - A. floor_08 is registered as "Floor 8", the ninth floor (Phase 15 adds floor_09, no floor_10);
##   every exit leads one floor down: Floor 7's to Floor 8, Floor 8's (Phase 15) to Floor 9, which
##   has none. Floor 7 has one chest, under its navigation
##   region, holding Small Health Potion x1 and Blast Bomb x2, dropping into its Pickups node.
## - B. Continue opens Floor 7: the chest closed, no loot lying anywhere, no prompt at the spawn.
## - C. Modal safety at the chest, "E: Open Chest" shown: E does nothing while the action menu is
##   open, and closing it does not open the chest (not even with E held through the close); E does
##   nothing in the pause menu or the Settings screen (the prompt hidden meanwhile); Interact is
##   rebound to Q there by key capture, and neither the captured Q nor the Escapes that resume use
##   the chest; the prompt then says "Q: Open Chest", E does nothing; at GAME OVER neither Q nor E
##   does anything, and the retry has the chest closed and Interact still on Q; Q opens it.
## - D. Opening puts two pickups below it and changes no inventory; collecting them gives exactly
##   Potion x1 and Blast Bomb x2 (bombs 3 in all); it cannot be opened again; nothing is saved.
## - E. Two Floor 7 deaths: each retry has the chest closed, no loot lying around, the potion gone,
##   one bomb (on A), the enemies as authored; opening it again drops exactly one set; nothing is
##   ever duplicated.
## - F. Return to Title after collecting, then Continue: the chest closed, no loot, the entry items.
## - G. Collecting only the potion and taking the stairs: Floor 8's checkpoint has the potion and
##   one bomb, not the two left lying on Floor 7.
## - H. Collecting both (and putting the potion on W in the menu), then the stairs: Floor 8 arrival
##   (Carl, Donut, camera, sign, HUD, a Gelatinous and a Spitting Blob, only the stairs down to
##   Floor 9 and its closed side-room chest since Phase 15, no loop), its
##   checkpoint in memory and on disk (still save_version 3, seven fields: potion 1, bombs 3, the
##   Slingshot and the Bat owned, W potion, A bombs, S Bat, D Fists).
## - I. Floor 8 plays: the blob and the Spitting Blob notice Carl, a bomb hurts the blob, the potion
##   heals; then a death and retry restore the checkpoint (potion 1, bombs 3, slots, HP).
## - J. With Interact on Q (a setting), Return to Title and Continue open Floor 8 with the carried
##   items; the key stays Q, and neither file holds the other's data.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_floor_08_run.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_PATHS: Array[String] = [
	"res://scenes/levels/surface.tscn", "res://scenes/levels/floor_01.tscn", "res://scenes/levels/floor_02.tscn",
	"res://scenes/levels/floor_03.tscn", "res://scenes/levels/floor_04.tscn", "res://scenes/levels/floor_05.tscn",
	"res://scenes/levels/floor_06.tscn", "res://scenes/levels/floor_07.tscn", "res://scenes/levels/floor_08.tscn",
	"res://scenes/levels/floor_09.tscn",
]
const FLOOR_7_PATH := "res://scenes/levels/floor_07.tscn"
const FLOOR_8_PATH := "res://scenes/levels/floor_08.tscn"
const BLOB_PATH := "res://scenes/enemies/gelatinous_blob.tscn"
const SPITTER_PATH := "res://scenes/enemies/spitting_blob.tscn"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const CHEST_PATH := "NavigationRegion2D/Props/TreasureChest"
const CHEST_AT := Vector2(240, 496)
## Where Carl stands to open the chest (just above it, 30 px from its centre).
const OPEN_FROM := Vector2(240, 466)
const ENTRY_CARL_HP := 80
const ENTRY_DONUT_HP := 40
const HUD_FLOOR_7_ENTRY := "W: Slingshot   A: Blast Bomb x1   S: Baseball Bat   D: Fists"
const FLOOR_8_SPAWN := Vector2(176, 176)
const FLOOR_8_DONUT_SPAWN := Vector2(176, 232)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60")
	_check_registry_and_exits()
	if await _continue_on_floor_7() and await _modal_safety_at_the_chest() and await _collect_the_loot() \
			and await _floor_7_retries() and await _return_to_title_before_floor_8() and await _partial_loot_to_floor_8() \
			and await _all_loot_to_floor_8() and await _floor_8_plays_and_retries():
		await _continue_floor_8_with_interact_on_q()
	finish()


func _check_registry_and_exits() -> void:
	print("-- A. floor_08 and the exits")
	check(FloorRegistry.FLOORS.keys()[8] == &"floor_08" and FloorRegistry.has_floor(&"floor_08") and FloorRegistry.get_scene_path(&"floor_08") == FLOOR_8_PATH
			and FloorRegistry.get_display_name(&"floor_08") == "Floor 8" and FloorRegistry.get_floor_id(FLOOR_8_PATH) == &"floor_08",
			"floor_08 is the ninth registered floor, shown as 'Floor 8'")
	check(FloorRegistry.FLOORS.size() == 10 and not FloorRegistry.has_floor(&"floor_10"), "then floor_09 (Phase 15), and no floor_10")
	for i in FLOOR_PATHS.size():
		var level: Node = (load(FLOOR_PATHS[i]) as PackedScene).instantiate()
		var expected: Array = [FLOOR_PATHS[i + 1]] if i + 1 < FLOOR_PATHS.size() else []
		var destinations := _destinations(level)
		check(destinations == expected, "%s leads only to %s" % [FLOOR_PATHS[i].get_file(), expected], str(destinations))
		if FLOOR_PATHS[i] == FLOOR_7_PATH:
			var chests := level.find_children("*", "StaticBody2D", true, false).filter(func(node: Node) -> bool: return node is TreasureChest)
			var chest: TreasureChest = level.get_node_or_null(CHEST_PATH)
			check(chests.size() == 1 and chest != null and chest.position == CHEST_AT and chest.get_parent().get_parent() == level.get_node("NavigationRegion2D"),
					"Floor 7 has one chest, under its NavigationRegion2D (so paths go around it)")
			check(chest != null and chest.contents == {&"small_health_potion": 1, &"blast_bomb": 2} and chest.loot_parent == level.get_node("Pickups"),
					"it holds Small Health Potion x1 and Blast Bomb x2, dropped into the level's Pickups node")
		level.free()


func _continue_on_floor_7() -> bool:
	print("-- B. Continue on Floor 7")
	_write_floor_7_save()
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_7_PATH):
		return false
	check(not _chest().is_open() and _loot().is_empty() and _all_pickups().is_empty(), "the chest is closed and no loot lies anywhere")
	check(_hud_slots() == HUD_FLOOR_7_ENTRY and _carl().health.current_health == ENTRY_CARL_HP, "Carl 80 with the entry slots", _hud_slots())
	check(_prompt() == "", "no prompt at the spawn point")
	return true


func _modal_safety_at_the_chest() -> bool:
	print("-- C. The menus never open the chest")
	var chest := _chest()
	var menu: CanvasLayer = current_scene.get_node("ActionMenu")
	var pause: CanvasLayer = current_scene.get_node("PauseMenu")
	var settings: Control = pause.get_node("%SettingsMenu")
	_carl().teleport_to(OPEN_FROM)
	await wait_physics_frames(3)
	check(_prompt() == "E: Open Chest", "next to the chest: \"E: Open Chest\"", _prompt())
	# The action menu.
	await tap_key(KEY_SPACE)
	check(menu.is_open() and _prompt() == "", "the action menu is open; the prompt is hidden")
	await tap_key(KEY_E)
	await tap_key(KEY_SPACE)
	await wait_physics_frames(10)
	check(not menu.is_open() and not chest.is_open() and _prompt() == "E: Open Chest", "E in the action menu did nothing; the prompt is back")
	await tap_key(KEY_SPACE)
	send_key(KEY_E, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	await wait_physics_frames(20)
	check(not menu.is_open() and not chest.is_open(), "E held while the menu closes opens nothing")
	send_key(KEY_E, false)
	await wait_physics_frames(2)
	# The pause menu.
	await tap_key(KEY_ESCAPE)
	check(pause.is_open() and _prompt() == "", "the pause menu is open; the prompt is hidden")
	await tap_key(KEY_E)
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(10)
	check(not pause.is_open() and not chest.is_open(), "E in the pause menu did nothing")
	# The Settings screen: E on the list, then Interact captured as Q.
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(settings.is_open() and paused, "Settings is open over the paused game")
	await tap_key(KEY_E)
	check(settings.get_capturing_action() == &"" and not chest.is_open(), "E on the Settings list does nothing")
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
	check(not paused and not chest.is_open(), "back in play: neither the captured Q nor the Escapes opened the chest")
	check(_prompt() == "Q: Open Chest", "the prompt now says Q", _prompt())
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(not chest.is_open(), "E does nothing now")
	# GAME OVER.
	var level := current_scene
	var level_id := level.get_instance_id()
	_carl().health.take_damage(1000)
	await wait_physics_frames(3)
	check(paused and _game_over_visible() and _prompt() == "", "GAME OVER: the prompt is hidden")
	await tap_key(KEY_Q)
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(not chest.is_open(), "at GAME OVER neither Q nor E opens the chest")
	await tap_key(KEY_ENTER)
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != level_id:
			break
		await physics_frame
	if not await _arrive(FLOOR_7_PATH):
		return false
	check(not _chest().is_open() and ControlBindings.get_key(&"interact") == KEY_Q, "the retry: the chest is closed, Interact still on Q")
	_carl().teleport_to(OPEN_FROM)
	await wait_physics_frames(3)
	await tap_key(KEY_Q)
	check(_chest().is_open(), "Q opens it")
	return true


func _collect_the_loot() -> bool:
	print("-- D. The loot")
	var state := game_state()
	var save_before := _save_text()
	var save_time := FileAccess.get_modified_time(save_manager().save_path)
	await wait_physics_frames(2)
	check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1, "opening it changed no inventory")
	var loot := _loot()
	check(loot.size() == 2 and loot[0].item == POTION and loot[0].quantity == 1 and loot[1].item == BOMB and loot[1].quantity == 2,
			"two pickups: Potion x1 and Blast Bomb x2", str(loot.map(func(p: ItemPickup) -> String: return p.get_node("Label").text)))
	if loot.size() != 2:
		return false
	check(loot[0].global_position == CHEST_AT + Vector2(-40, 72) and loot[1].global_position == CHEST_AT + Vector2(40, 72),
			"below the chest, side by side", "%s %s" % [loot[0].global_position, loot[1].global_position])
	settings_manager().reset_to_defaults()
	check(_prompt() == "", "the open chest shows no prompt")
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(_loot().size() == 2, "E at the open chest drops nothing more")
	await _collect(loot[0])
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 1, "the potion: exactly 1")
	await _collect(loot[1])
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 3, "the bombs: exactly 2 more (3)")
	check(_loot().is_empty() and _hud_slots() == "W: Slingshot   A: Blast Bomb x3   S: Baseball Bat   D: Fists", "the pickups are gone; HUD A: Blast Bomb x3",
			_hud_slots())
	var rows := await _menu_rows()
	check(rows.has("Small Health Potion x1   (no slot)") and rows.has("Blast Bomb x3   (on A)"), "the menu lists them", str(rows))
	check(_save_text() == save_before and FileAccess.get_modified_time(save_manager().save_path) == save_time,
			"opening the chest and collecting its loot saved nothing")
	return true


func _floor_7_retries() -> bool:
	print("-- E. Floor 7 deaths take the chest's loot back")
	for attempt in 2:
		if not await _die_and_retry(FLOOR_7_PATH):
			return false
		var state := game_state()
		check(not _chest().is_open() and _loot().is_empty() and _all_pickups().is_empty(), "retry %d: the chest is closed, no loot lies around" % (attempt + 1))
		check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1 and _hud_slots() == HUD_FLOOR_7_ENTRY,
				"retry %d: no potion, one bomb on A, as on entering" % (attempt + 1), _hud_slots())
		var enemies := _enemies()
		check(enemies.size() == 4 and enemies.all(func(enemy: Enemy) -> bool: return enemy.health.current_health == 30),
				"retry %d: the four enemies as authored" % (attempt + 1))
		await _open_chest()
		var loot := _loot()
		check(loot.size() == 2 and loot[0].item == POTION and loot[1].item == BOMB and loot[1].quantity == 2,
				"retry %d: opening it again drops exactly one set" % (attempt + 1))
		for pickup: ItemPickup in loot:
			await _collect(pickup)
		check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 3,
				"retry %d: collected again: potion 1, bombs 3, never more" % (attempt + 1))
	return true


func _return_to_title_before_floor_8() -> bool:
	print("-- F. Return to Title, then Continue")
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if not await wait_for_scene(title_path):
		return false
	await wait_physics_frames(2)
	check(current_scene.get_node("%SaveInfoLabel").text == "Saved at the start of Floor 7  -  HP 80 / 100", "the title still describes the Floor 7 checkpoint")
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_7_PATH):
		return false
	var state := game_state()
	check(not _chest().is_open() and _all_pickups().is_empty(), "Continue: the chest is closed, no loot")
	check(state.inventory.get_quantity(POTION) == 0 and state.inventory.get_quantity(BOMB) == 1 and _hud_slots() == HUD_FLOOR_7_ENTRY,
			"the Floor 7 entry items: no potion, one bomb", _hud_slots())
	return true


func _partial_loot_to_floor_8() -> bool:
	print("-- G. Only the potion collected: the bombs left behind are not carried")
	await _open_chest()
	var loot := _loot()
	if loot.size() != 2:
		check(false, "the loot appeared")
		return false
	await _collect(loot[0])
	check(game_state().inventory.get_quantity(POTION) == 1 and _loot().size() == 1, "the potion collected, the bombs still lying there")
	if not await _take_the_stairs():
		return false
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 1, "Floor 8: the potion and the one bomb Carl carried")
	check(state.floor_entry.inventory["quantities"] == {&"small_health_potion": 1, &"blast_bomb": 1}, "the checkpoint holds exactly that",
			str(state.floor_entry.inventory))
	check(_save().get("floor_id") == "floor_08" and _save().get("inventory") == {"small_health_potion": 1.0, "blast_bomb": 1.0},
			"and so does the save: no bombs from the chest", _save_text())
	return true


func _all_loot_to_floor_8() -> bool:
	print("-- H. Both collected, the potion put on W, then Floor 8")
	_write_floor_7_save()
	if not await _open_title():
		return false
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_7_PATH):
		return false
	await _open_chest()
	for pickup: ItemPickup in _loot():
		await _collect(pickup)
	await _assign_in_menu("Small Health Potion", KEY_W)
	var hud_carried := "W: Potion x1   A: Blast Bomb x3   S: Baseball Bat   D: Fists"
	check(_hud_slots() == hud_carried, "Floor 7: the potion on W, three bombs on A", _hud_slots())
	if not await _take_the_stairs():
		return false
	var level := current_scene
	var carl := _carl()
	var donut := _donut()
	check(carl.global_position == FLOOR_8_SPAWN and donut.global_position.distance_to(FLOOR_8_DONUT_SPAWN) < 40.0, "Carl arrives at the spawn point, Donut beside him",
			"%s %s" % [carl.global_position, donut.global_position])
	check(carl.camera.is_current() and level.get_node("Signs/FloorTitle").text == "Floor 8 - Storeroom", "the camera follows Carl; the floor sign says Floor 8")
	check(_hud_slots() == hud_carried and current_scene.get_node("HUD/%HealthLabel").text == "Carl HP: 80 / 100"
			and current_scene.get_node("HUD/%DonutHealthLabel").text == "Donut HP: 40 / 60", "the HUD: the carried slots, Carl 80, Donut 40", _hud_slots())
	check(_enemies(BLOB_PATH).size() == 1 and _enemies(SPITTER_PATH).size() == 1 and _enemies().size() == 2, "a Gelatinous Blob and a Spitting Blob")
	check(_destinations(level) == ["res://scenes/levels/floor_09.tscn"], "only the stairs down to Floor 9 (Phase 15): nothing leads back up to Floor 7")
	var chests := level.find_children("*", "StaticBody2D", true, false).filter(func(node: Node) -> bool: return node is TreasureChest)
	check(chests.size() == 1 and not chests[0].is_open() and _all_pickups().is_empty(),
			"Floor 8's one chest (Phase 15, in its side room) is closed, and no loot lies anywhere")
	var state := game_state()
	var entry: FloorEntry = state.floor_entry
	check(entry.scene_path == FLOOR_8_PATH and entry.carl_health == ENTRY_CARL_HP and entry.donut_health == ENTRY_DONUT_HP
			and entry.inventory["quantities"] == {&"small_health_potion": 1, &"blast_bomb": 3}
			and entry.action_slots == {&"action_w": POTION, &"action_a": BOMB, &"action_s": BAT, &"action_d": FISTS},
			"the Floor 8 checkpoint in memory: potion 1, bombs 3, W potion, A bombs, S Bat, D Fists")
	var expected := {
		"save_version": 3, "floor_id": "floor_08", "carl": {"health": 80, "max_health": 100}, "donut": {"health": 40, "max_health": 60},
		"inventory": {"small_health_potion": 1, "blast_bomb": 3}, "owned_items": ["slingshot", "baseball_bat"],
		"action_slots": {"action_w": "small_health_potion", "action_a": "blast_bomb", "action_s": "baseball_bat", "action_d": "fists"},
	}
	check(_save() == JSON.parse_string(JSON.stringify(expected)), "and on disk: save_version 3, the same seven fields", _save_text())
	var loaded: FloorEntry = save_manager().load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_8_PATH and loaded.inventory["quantities"].get(&"blast_bomb") == 3,
			"it loads back as a Floor 8 checkpoint")
	await wait_seconds(1.0)
	check(current_scene == level, "Carl stays on Floor 8 (no transition loop)")
	return true


func _floor_8_plays_and_retries() -> bool:
	print("-- I. Floor 8 plays, then a retry restores its checkpoint")
	var carl := _carl()
	var blob: Enemy = _enemies(BLOB_PATH)[0]
	var spitter: Enemy = _enemies(SPITTER_PATH)[0]
	carl.teleport_to(Vector2(704, 336))
	await wait_physics_frames(10)
	check(blob.target == carl and spitter.target == carl, "the blob and the Spitting Blob notice Carl")
	await tap_key(KEY_UP)
	await tap_key(KEY_A)
	await wait_until(func() -> bool: return blob.health.current_health < 30, "the bomb to hit the blob", 90)
	check(blob.health.current_health == 10 and game_state().inventory.get_quantity(BOMB) == 2, "a bomb takes 20 from the blob; 2 bombs left")
	carl.health.take_damage(50)
	await tap_key(KEY_W)
	check(carl.health.current_health == 60 and game_state().inventory.get_quantity(POTION) == 0, "the potion heals 30 (30 -> 60) and is used up",
			str(carl.health.current_health))
	if not await _die_and_retry(FLOOR_8_PATH):
		return false
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 3
			and _hud_slots() == "W: Potion x1   A: Blast Bomb x3   S: Baseball Bat   D: Fists", "the retry: potion 1 on W, bombs 3 on A", _hud_slots())
	check(_carl().health.current_health == ENTRY_CARL_HP and _donut().health.current_health == ENTRY_DONUT_HP and _carl().global_position == FLOOR_8_SPAWN,
			"Carl 80 at the spawn point, Donut 40")
	check(_enemies().all(func(enemy: Enemy) -> bool: return enemy.health.current_health == 30), "the enemies as authored")
	return true


func _continue_floor_8_with_interact_on_q() -> void:
	print("-- J. Continue on Floor 8, Interact on Q")
	check(settings_manager().set_binding(&"interact", KEY_Q) == "", "Interact is set to Q")
	if not await _open_title():
		return
	check(current_scene.get_node("%SaveInfoLabel").text == "Saved at the start of Floor 8  -  HP 80 / 100", "the title describes the Floor 8 checkpoint")
	await tap_key(KEY_ENTER)
	if not await _arrive(FLOOR_8_PATH):
		return
	var state := game_state()
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.get_quantity(BOMB) == 3 and state.inventory.has(SLINGSHOT) and state.inventory.has(BAT)
			and _hud_slots() == "W: Potion x1   A: Blast Bomb x3   S: Baseball Bat   D: Fists", "Continue: the carried items and slots", _hud_slots())
	check(ControlBindings.get_key(&"interact") == KEY_Q, "Interact is still Q")
	var settings_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_manager().settings_path))
	check(settings_data is Dictionary and settings_data.get("settings_version") == 2.0 and settings_data.get("keyboard", {}).get("interact") == "Q"
			and not settings_data.has("inventory"), "the settings file holds Interact = Q and no run", str(settings_data))
	check(not _save().has("keyboard") and not _save_text().contains("interact") and _save().get("save_version") == 3.0,
			"the save holds no key bindings and is still version 3")
	settings_manager().reset_to_defaults()


## Opens the chest from OPEN_FROM with E.
func _open_chest() -> void:
	_carl().teleport_to(OPEN_FROM)
	await wait_physics_frames(3)
	check(_prompt() == "E: Open Chest", "the prompt says E: Open Chest", _prompt())
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(_chest().is_open(), "E opens the chest")


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
	return await _arrive(FLOOR_8_PATH)


func _write_floor_7_save() -> void:
	var data := {
		"save_version": 3, "floor_id": "floor_07",
		"carl": {"health": ENTRY_CARL_HP, "max_health": 100}, "donut": {"health": ENTRY_DONUT_HP, "max_health": 60},
		"inventory": {"blast_bomb": 1}, "owned_items": ["slingshot", "baseball_bat"],
		"action_slots": {"action_w": "slingshot", "action_a": "blast_bomb", "action_s": "baseball_bat", "action_d": "fists"},
	}
	DirAccess.make_dir_recursive_absolute(save_manager().save_path.get_base_dir())
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## Waits for `level_path`, then keeps Floor 7's enemies idle (their fights are other tests'), so
## Carl can walk to the chest and the stairs and every number is exact.
func _arrive(level_path: String) -> bool:
	if not await wait_for_scene(level_path):
		return false
	await wait_physics_frames(3)
	if level_path == FLOOR_7_PATH:
		for enemy in _enemies():
			enemy.detection_range = 0.0
			enemy.chase_range = 0.0
	return true


func _die_and_retry(level_path: String) -> bool:
	var level := current_scene
	var level_id := level.get_instance_id()
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
	return level.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node).map(
			func(node: Node) -> String: return node.destination_scene_path)


func _enemies(scene_path: String = "") -> Array:
	return current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool:
		return node is Enemy and (scene_path.is_empty() or node.scene_file_path == scene_path))


func _chest() -> TreasureChest:
	return current_scene.get_node_or_null(CHEST_PATH)


## The chest's loot lying in Floor 7's Pickups node, in the order it was dropped.
func _loot() -> Array:
	var pickups := current_scene.get_node_or_null("Pickups")
	if pickups == null:
		return []
	return pickups.get_children().filter(func(node: Node) -> bool: return node is ItemPickup and not node.is_queued_for_deletion())


## Every pickup anywhere in the level.
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
