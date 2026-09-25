extends "res://tests/support/game_test.gd"
## Phase 10 Return to Title, in one process, through the real title screen, levels and pause
## menu, driven by key events, on this test's own save file:
## - the confirmation: "Return to title? Progress since entering this floor will be lost.", No
##   selected; Escape and No both go back to the pause menu, still paused, with the live floor
##   untouched (Carl's and Donut's HP, items, enemies, a stone in flight);
## - Yes returns to the title screen in the same process, unpaused. Nothing is saved: the save
##   file is byte for byte the Floor 6 entry checkpoint and was not rewritten. The level and
##   everything in it (Carl, Donut, enemies, projectiles, the HUD and menus) is gone, and GameState
##   holds no run. The title describes the saved checkpoint (HP 80), not the live floor (HP 60);
## - Continue then restores the checkpoint: Carl 80, Donut 40, the potion back on A, the Bat on S,
##   the enemy killed mid-floor back where it was authored, no projectiles;
## - Continue reads the save from disk, never the memory of the run: with a different checkpoint
##   written to disk while the title is up (and a stale run planted in GameState), Continue opens
##   what the disk says;
## - five Continue -> play -> Return to Title cycles: never two Carls, Donuts, HUDs, menus or
##   extra enemies, no stones left over, no signal connections piling up, no engine errors;
## - New Game after returning to the title still asks first (No selected, No keeps the save) and
##   Yes starts the canonical new run on the Surface;
## - the save stays version 3 with its seven fields and nothing about pausing; a Phase 5 (version
##   1) and a Phase 6 (version 2) save still load after returning to the title, and Continue works
##   on each again after a second return.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_return_to_title.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const V1_FIXTURE := "res://tests/fixtures/phase5_save_v1_floor_02.json"
const V2_FIXTURE := "res://tests/fixtures/phase6_save_v2_floor_03.json"
const SAVE_FIELDS := ["action_slots", "carl", "donut", "floor_id", "inventory", "owned_items", "save_version"]
const FLOOR_6_ENEMIES := {
	"BackstopBlob": Vector2(536, 208),
	"GelatinousBlob": Vector2(320, 480),
	"SpittingBlob": Vector2(928, 224),
}
const CYCLES := 5

var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")
## The Floor 6 entry checkpoint as written to disk.
var _checkpoint_text := ""


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_seed_floor_6_checkpoint()
	if not await _continue_from_title("Floor 6", 80):
		finish()
		return
	_check_floor_6_checkpoint_state("Continue")
	await _check_confirmation()
	if not await _check_return_discards_the_floor():
		finish()
		return
	await _check_continue_reads_the_disk()
	await _check_repeated_cycles()
	await _check_new_game_after_return()
	await _check_older_saves_after_return()
	finish()


## Writes the Floor 6 entry checkpoint: Carl 80 / 100, Donut 40 / 60, the Slingshot on W, one
## potion on A, the Bat on S, Fists on D. GameState is cleared again afterwards.
func _seed_floor_6_checkpoint() -> void:
	print("-- A Floor 6 checkpoint on disk")
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 1)
	state.inventory.add(SLINGSHOT, 1)
	state.inventory.add(BAT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BAT, ActionSlots.SLOT_S)
	state.carl_health = 80
	state.donut_health = 40
	state.record_floor_entry(FLOOR_6_PATH)
	check(save_manager().save_checkpoint(state.floor_entry), "the checkpoint is saved")
	state.start_new_run()
	_checkpoint_text = _save_text()


func _check_confirmation() -> void:
	print("-- Return to Title asks first; Escape and No keep the live floor")
	var level := current_scene
	var carl := _carl()
	var pause: CanvasLayer = level.get_node("PauseMenu")
	# Some live progress: Carl and Donut hurt, the potion drunk, a stone in flight.
	carl.get_node("Hurtbox").take_hit(50)
	_donut().get_node("Hurtbox").take_hit(30)
	await tap_key(KEY_A)
	check(carl.health.current_health == 60 and not game_state().inventory.has(POTION) and _hud_slots().contains("A: —"),
			"live floor: Carl hurt to 30 then drinks the potion (60 HP, none left, A empty)", _hud_slots())
	await hold_keys([KEY_RIGHT], 1)
	await tap_key(KEY_W)
	var stone: Projectile = _projectiles()[0] if _projectiles().size() == 1 else null
	check(stone != null, "a stone is in flight")

	await tap_key(KEY_ESCAPE)
	var stone_position: Vector2 = stone.global_position if stone != null else Vector2.ZERO
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var question: Label = pause.get_node("%ConfirmQuestion")
	check(pause.is_confirming() and pause.get_node("%ConfirmPanel").visible and not pause.get_node("%MenuPanel").visible,
			"Enter on Return to Title opens the confirmation")
	check(question.text == "Return to title?\nProgress since entering this floor will be lost.", "it warns", question.text)
	check(not pause.is_yes_selected() and _row(pause, "%NoRow") == "> No" and _row(pause, "%YesRow") == "   Yes", "No is selected")
	await tap_key(KEY_ESCAPE)
	check(not pause.is_confirming() and pause.is_open() and paused and current_scene == level,
			"Escape cancels: back to the pause menu, still paused")
	check(_row(pause, "%ReturnToTitleRow") == "> Return to Title", "Return to Title is still selected")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_ENTER)
	check(not pause.is_confirming() and pause.is_open() and paused and current_scene == level,
			"Enter on No: back to the pause menu, still paused")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_UP)
	check(not pause.is_yes_selected(), "Up/Down in the pause menu do not touch the question's answer")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	check(pause.is_yes_selected() and _row(pause, "%YesRow") == "> Yes", "Down selects Yes")
	await tap_key(KEY_UP)
	check(not pause.is_yes_selected(), "Up selects No again")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_ESCAPE)
	check(not pause.is_open() and not paused and current_scene == level, "Escape resumes the same floor")
	check(carl.health.current_health == 60 and _donut().health.current_health == 10 and not game_state().inventory.has(POTION),
			"the live floor is untouched: Carl 60, Donut 10, no potion")
	check(stone != null and is_instance_valid(stone) and stone.global_position != stone_position, "the stone flies on")
	check(_save_text() == _checkpoint_text, "the save is still the Floor 6 entry checkpoint")


func _check_return_discards_the_floor() -> bool:
	print("-- Yes: back to the title, nothing saved, the floor discarded")
	var level := current_scene
	var level_ref: WeakRef = weakref(level)
	var backstop_blob: Enemy = level.get_node("Actors/BackstopBlob")
	backstop_blob.health.take_damage(30)
	await wait_seconds(1.0)
	check(level.get_node_or_null("Actors/BackstopBlob") == null, "live floor: the Backstop blob is killed")
	await hold_keys([KEY_RIGHT], 1)
	await tap_key(KEY_W)
	var modified_time := FileAccess.get_modified_time(save_manager().save_path)
	await _return_to_title()
	if not await wait_for_scene(_title_path):
		return false
	await wait_physics_frames(3)
	check(not paused, "the title screen runs (the game is no longer paused)")
	check(level_ref.get_ref() == null, "the level has been freed")
	check(_count_nodes(func(node: Node) -> bool: return node is Projectile or node is Enemy or node.scene_file_path.begins_with("res://scenes/levels/") or node.is_in_group(&"party")) == 0,
			"no Carl, Donut, enemy, projectile or level is left anywhere")
	check(_save_text() == _checkpoint_text, "the save is still exactly the Floor 6 entry checkpoint")
	check(FileAccess.get_modified_time(save_manager().save_path) == modified_time, "the save file was not rewritten")
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of Floor 6  -  HP 80 / 100", "the title describes the checkpoint (HP 80), not the live floor (HP 60)", info)
	check(current_scene.is_continue_available() and _row(current_scene, "%ContinueRow") == "> Continue", "Continue is available and selected")
	_check_no_run_in_memory()
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_6_PATH):
		return false
	await wait_physics_frames(3)
	_check_floor_6_checkpoint_state("Continue after Return to Title")
	return true


func _check_continue_reads_the_disk() -> void:
	print("-- Continue loads the checkpoint from disk, not from memory")
	_carl().get_node("Hurtbox").take_hit(70)
	await _return_to_title()
	if not await wait_for_scene(_title_path):
		return
	await wait_physics_frames(3)
	_check_no_run_in_memory()
	# Another checkpoint arrives on disk while the title is up, and a stale run is planted in memory.
	var other := _checkpoint_text.replace("\"health\": 80", "\"health\": 55").replace("\"health\": 40", "\"health\": 25")
	check(other != _checkpoint_text, "a different checkpoint (Carl 55, Donut 25)")
	_write_save(other)
	var state := game_state()
	state.carl_health = 7
	state.donut_health = 3
	state.record_floor_entry(FLOOR_3_PATH)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_6_PATH):
		return
	await wait_physics_frames(3)
	check(_carl().health.current_health == 55 and _donut().health.current_health == 25,
			"Continue opens Floor 6 with the disk's Carl 55 and Donut 25 (not the stale 7 / 3 on Floor 3)",
			"Carl %d, Donut %d" % [_carl().health.current_health, _donut().health.current_health])
	# Put the Floor 6 checkpoint back for the rest of the test.
	await _return_to_title()
	await wait_for_scene(_title_path)
	_write_save(_checkpoint_text)


func _check_repeated_cycles() -> void:
	print("-- %d Continue -> play -> Return to Title cycles" % CYCLES)
	var in_level := {}
	var on_title := {}
	for cycle in CYCLES:
		change_scene_to_file(_title_path)
		if not await wait_for_scene(_title_path):
			return
		await wait_physics_frames(3)
		var title_counts := _counts()
		if cycle == 0:
			on_title = title_counts
		check(title_counts == on_title, "cycle %d: the title screen has the same nodes and connections as the first time" % (cycle + 1), str(title_counts))
		await tap_key(KEY_ENTER)
		if not await wait_for_scene(FLOOR_6_PATH):
			return
		await wait_physics_frames(3)
		_check_floor_6_checkpoint_state("cycle %d" % (cycle + 1))
		var level_counts := _counts()
		if cycle == 0:
			in_level = level_counts
		check(level_counts == in_level, "cycle %d: exactly one Carl, Donut, HUD, action menu and pause menu, 3 enemies, the same connections" % (cycle + 1),
				str(level_counts))
		# Play a little: walk, punch, fire, open and close the action menu, take a hit.
		await hold_keys([KEY_RIGHT], 20)
		await tap_key(KEY_D)
		await tap_key(KEY_W)
		await tap_key(KEY_SPACE)
		await tap_key(KEY_SPACE)
		_carl().get_node("Hurtbox").take_hit(15)
		await tap_key(KEY_W)
		await _return_to_title()
		if not await wait_for_scene(_title_path):
			return
		await wait_physics_frames(3)
		check(_count_nodes(func(node: Node) -> bool: return node is Projectile or node is Enemy or node.is_in_group(&"party")) == 0,
				"cycle %d: back on the title, nothing of the floor is left" % (cycle + 1))
		check(_save_text() == _checkpoint_text, "cycle %d: the save is unchanged" % (cycle + 1))


func _check_new_game_after_return() -> void:
	print("-- New Game after returning to the title")
	var title := current_scene
	check(title.scene_file_path == _title_path, "on the title screen")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(title.is_confirming() and _row(title, "%NoRow") == "> No", "New Game asks first, No selected")
	await tap_key(KEY_ENTER)
	check(not title.is_confirming() and _save_text() == _checkpoint_text and current_scene == title, "No keeps the save")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(SURFACE_PATH):
		return
	await wait_physics_frames(3)
	var state := game_state()
	check(_carl().health.current_health == 100 and _donut().health.current_health == 60, "Yes: the Surface with Carl 100 / 100 and Donut 60 / 60")
	check(state.inventory.get_actions() == [FISTS] and _hud_slots() == "W: —   A: —   S: —   D: Fists",
			"no potions, no Slingshot, no Bat; W/A/S empty, D = Fists", _hud_slots())
	check(_count_nodes(func(node: Node) -> bool: return node.is_in_group(&"party")) == 2, "one Carl and one Donut")
	var saved: Dictionary = JSON.parse_string(_save_text())
	check(saved.get("floor_id") == "surface" and saved.get("carl") == {"health": 100.0, "max_health": 100.0}
			and saved.get("donut") == {"health": 60.0, "max_health": 60.0} and saved.get("inventory") == {}
			and saved.get("owned_items") == [], "the Surface checkpoint replaced the save", _save_text())


func _check_older_saves_after_return() -> void:
	print("-- Save version 3; version 1 and 2 saves after returning to the title")
	var saved: Dictionary = JSON.parse_string(_save_text())
	var keys := saved.keys()
	keys.sort()
	check(keys == SAVE_FIELDS and saved["save_version"] == 3.0, "the save is version 3 with exactly its seven fields (nothing about pausing)", str(keys))
	for fixture: Array in [[V1_FIXTURE, FLOOR_2_PATH, "Floor 2"], [V2_FIXTURE, FLOOR_3_PATH, "Floor 3"]]:
		_write_save(FileAccess.get_file_as_string(fixture[0]))
		if current_scene.scene_file_path == _title_path:
			change_scene_to_file(_title_path)  # open it again, so it reads the new file
		else:
			await _return_to_title()
		if not await wait_for_scene(_title_path):
			return
		await wait_physics_frames(3)
		var version := int(JSON.parse_string(FileAccess.get_file_as_string(fixture[0]))["save_version"])
		check(current_scene.get_node("%SaveInfoLabel").text == "Saved at the start of %s  -  HP 70 / 100" % fixture[2],
				"a version %d save: the title offers %s, HP 70" % [version, fixture[2]], current_scene.get_node("%SaveInfoLabel").text)
		for attempt in 2:
			await tap_key(KEY_ENTER)
			if not await wait_for_scene(fixture[1]):
				return
			await wait_physics_frames(3)
			check(_carl().health.current_health == 70 and game_state().inventory.get_quantity(POTION) == 2
					and _donut().health.current_health == 60,
					"version %d, Continue %d: %s with Carl 70, 2 potions, Donut 60" % [version, attempt + 1, fixture[2]])
			var migrated: Dictionary = JSON.parse_string(_save_text())
			check(migrated["save_version"] == 3.0, "version %d, Continue %d: the file is now version 3" % [version, attempt + 1])
			_carl().get_node("Hurtbox").take_hit(40)
			await _return_to_title()
			if not await wait_for_scene(_title_path):
				return
			await wait_physics_frames(3)
			check(current_scene.get_node("%SaveInfoLabel").text.ends_with("HP 70 / 100"), "version %d: after returning, the title still says HP 70" % version)


## Escape, Down, Enter, Down (Yes), Enter: the whole Return to Title, by keys.
func _return_to_title() -> void:
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)


## Opens the title and presses Enter on Continue. Returns false (recording why) on failure.
func _continue_from_title(floor_name: String, carl_health: int) -> bool:
	change_scene_to_file(_title_path)
	if not await wait_for_scene(_title_path):
		return false
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of %s  -  HP %d / 100" % [floor_name, carl_health], "the title describes the save", info)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_6_PATH):
		return false
	await wait_physics_frames(3)
	return true


func _check_floor_6_checkpoint_state(label: String) -> void:
	var state := game_state()
	check(_carl().health.current_health == 80 and _donut().health.current_health == 40,
			label + ": Carl 80 / 100 and Donut 40 / 60", "Carl %d, Donut %d" % [_carl().health.current_health, _donut().health.current_health])
	check(state.inventory.get_quantity(POTION) == 1 and state.inventory.has(SLINGSHOT) and state.inventory.has(BAT),
			label + ": one potion, the Slingshot and the Bat")
	check(_hud_slots() == "W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists", label + ": the checkpoint's slots", _hud_slots())
	var enemies := {}
	for enemy in current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool: return node is Enemy):
		enemies[String(enemy.name)] = enemy.global_position
		check((enemy as Enemy).health.current_health == 30, "%s: %s has 30 HP" % [label, enemy.name])
	check(enemies == FLOOR_6_ENEMIES, label + ": the enemies are back where they were authored", str(enemies))
	check(_projectiles().is_empty(), label + ": no projectiles")


func _check_no_run_in_memory() -> void:
	var state := game_state()
	check(state.floor_entry == null and state.carl_health == 100 and state.donut_health == 60
			and state.inventory.get_actions() == [FISTS] and state.action_slots.get_action(ActionSlots.SLOT_D) == FISTS
			and state.action_slots.get_action(ActionSlots.SLOT_A) == null,
			"GameState holds no run on the title screen (no floor entry, new-run values)")


## Nodes and signal connections that must not pile up from one visit to the next.
func _counts() -> Dictionary:
	var state := game_state()
	return {
		"root children": root.get_child_count(),
		"party": _count_nodes(func(node: Node) -> bool: return node.is_in_group(&"party")),
		"enemies": _count_nodes(func(node: Node) -> bool: return node is Enemy),
		"projectiles": _projectiles().size(),
		"HUDs": _count_nodes(func(node: Node) -> bool: return node.name == &"HUD"),
		"action menus": _count_nodes(func(node: Node) -> bool: return node.name == &"ActionMenu"),
		"pause menus": _count_nodes(func(node: Node) -> bool: return node.name == &"PauseMenu"),
		"inventory connections": state.inventory.changed.get_connections().size(),
		"slot connections": state.action_slots.changed.get_connections().size(),
	}


func _count_nodes(matches: Callable) -> int:
	return root.find_children("*", "", true, false).filter(matches).size()


func _projectiles() -> Array:
	return root.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is Projectile)


func _write_save(text: String) -> void:
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _donut() -> CharacterBody2D:
	return current_scene.get_node("Actors/Donut")


func _row(owner_node: Node, path: String) -> String:
	return (owner_node.get_node(path) as Label).text
