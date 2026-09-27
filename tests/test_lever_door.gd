extends "res://tests/support/game_test.gd"
## Phase 15: the one-shot Lever and the Controlled Door on their own, in small arenas with a real
## Carl (and Donut, enemies, stones and bombs), keys sent through Godot's input pipeline. Nothing
## here uses a level, so it checks the reusable parts themselves:
## - Lever: a solid StaticBody2D on `world` with an Interactable child ("Pull Lever", one_shot);
##   inactive at first (red knob, handle left); "E: Pull Lever" next to it; E pulls it: active look,
##   its Interactable off, the prompt gone, `activated` exactly once; E again, holding E, key
##   repeat and interact() do nothing more. A lever connected to nothing works the same.
## - Rebinding: with Interact on Q, "Q: Pull Lever", E does nothing, Q pulls it; the settings file
##   (version 2) holds Q and the key survives a reload of the file.
## - Controlled Door: closed at first (closed look, collision on `world`); Carl walking into it
##   stops in front of it; Donut following Carl cannot pass it (a navigation arena whose doorway is
##   in the mesh, as in a level); a slingshot stone and a thrown Blast Bomb stop at it and the enemy
##   behind it is not hurt (the bomb explodes in front of it and the door shields the blast).
##   A lever connected to its open() in the arena opens it: the open look, `opened` once, the
##   collision gone; Carl walks through; Donut follows him through; a stone and a bomb fly through
##   and hurt the enemy behind it; open() again is harmless (no second `opened`, still open); it
##   stays open (never closes); nothing is hurt or pushed by the opening.
## - Architecture: the Lever's and the Door's code look nothing up by path or in the tree, and name
##   no floor, door (the lever), lever (the door), stairs, chest, inventory, GameState or
##   SaveManager; Carl's scripts and the interaction controller name neither; the only autoloads are
##   still GameState, SaveManager and SettingsManager (no event bus).
## - Several interactables (a Lever, a Treasure Chest and a plain Interactable): the nearest one is
##   prompted; one press uses only it; a pulled lever is skipped and the next one is prompted; ties
##   between a lever and another interactable go to the one earlier in the tree, 0.3 px nearer is
##   still a tie, 1 px nearer wins.
## - A paused game: no lever prompt, the key does nothing, a key held through the resume does
##   nothing, the next press pulls it. Carl down: nothing.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_lever_door.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const LEVER_SCENE: PackedScene = preload("res://scenes/props/lever.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/props/controlled_door.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/props/treasure_chest.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const STONE_SCENE: PackedScene = preload("res://scenes/projectiles/slingshot_stone.tscn")
const BOMB_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/blast_bomb.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/interaction/interactable.gd")
const CENTRE := Vector2(400, 300)
## The door for the collision checks: vertical (rotated), its centre 100 px right of Carl.
const DOOR_AT := CENTRE + Vector2(100, 0)

var _arena: Node2D


## Counts a signal's emissions.
class Counter:
	var count := 0

	func record(_a: Variant = null) -> void:
		count += 1


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	await _check_lever()
	await _check_rebinding()
	await _check_door_blocks()
	await _check_lever_opens_door()
	await _check_donut_and_the_door()
	_check_architecture()
	await _check_several_interactables()
	await _check_ties()
	await _check_pause_and_carl_down()
	finish()


func _check_lever() -> void:
	print("-- The lever")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var lever := _add_lever(CENTRE + Vector2(30, 0))
	var pulls := Counter.new()
	lever.activated.connect(pulls.record)
	var interactable: Interactable = lever.get_node("Interactable")
	check(lever is Lever and lever.collision_layer == 1 and interactable != null and interactable.prompt_text == "Pull Lever"
			and interactable.one_shot and interactable.is_in_group(Interactable.GROUP),
			"a solid body on `world` with a one_shot Interactable child, \"Pull Lever\"")
	check(not lever.is_active() and lever.inactive_look.visible and not lever.active_look.visible, "it starts inactive (the inactive look)")
	await wait_physics_frames(2)
	check(controller.find_interactable() == interactable and controller.get_prompt_text() == "E: Pull Lever", "next to it: \"E: Pull Lever\"",
			controller.get_prompt_text())
	await tap_key(KEY_E)
	check(lever.is_active() and lever.active_look.visible and not lever.inactive_look.visible, "E pulls it: the active look")
	check(pulls.count == 1 and not interactable.enabled, "`activated` once; its Interactable is off")
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "" and controller.find_interactable() == null, "the prompt is gone")
	await tap_key(KEY_E)
	await hold_keys([KEY_E], 30)
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	Input.flush_buffered_events()
	await wait_physics_frames(2)
	send_key(KEY_E, false)
	check(not interactable.interact(carl), "interact() on the pulled lever does nothing")
	check(pulls.count == 1 and lever.is_active(), "E again, E held and key repeat pull nothing more: `activated` stays at 1")
	await wait_seconds(1.0)
	check(lever.is_active() and lever.active_look.visible, "it stays pulled (it does not toggle back)")
	check(take_engine_messages().is_empty(), "a lever connected to nothing reports nothing")


func _check_rebinding() -> void:
	print("-- A rebound Interact key")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var lever := _add_lever(CENTRE + Vector2(0, 30))
	await wait_physics_frames(2)
	check(settings_manager().set_binding(&"interact", KEY_Q) == "", "Interact moves to Q")
	check(controller.get_prompt_text() == "Q: Pull Lever", "the prompt says \"Q: Pull Lever\"", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(not lever.is_active(), "E does nothing")
	await tap_key(KEY_Q)
	check(lever.is_active(), "Q pulls it")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_manager().settings_path))
	check(data is Dictionary and data.get("settings_version") == 2.0 and data.get("keyboard", {}).get("interact") == "Q",
			"the settings file (version 2) holds Interact = Q", str(data))
	settings_manager().load_settings()
	check(ControlBindings.get_key(&"interact") == KEY_Q, "reading the file again: still Q")
	settings_manager().reset_to_defaults()


func _check_door_blocks() -> void:
	print("-- A closed door")
	var carl := await _new_arena()
	var door := _add_door(DOOR_AT)
	check(door is ControlledDoor and door.collision_layer == 1 and not door.is_open() and door.is_blocking()
			and door.closed_look.visible and not door.open_look.visible, "it starts closed: the closed look, solid on `world`")
	check(door.get_node_or_null("Interactable") == null, "it has no Interactable: Carl cannot open it himself")
	await hold_keys([KEY_RIGHT], 90)
	await wait_physics_frames(2)
	check(carl.global_position.x < DOOR_AT.x - 16.0 - 12.0 + 0.5 and carl.global_position.x > DOOR_AT.x - 40.0,
			"Carl walking into it stops in front of it", str(carl.global_position))
	# 40 px behind the door: within the blast's 72 px of where a bomb explodes in front of it.
	var blob := _add_idle_blob(DOOR_AT + Vector2(40, 0))
	var stone := await _fire(STONE_SCENE, carl, DOOR_AT + Vector2(-70, 0))
	check(stone[1].count == 1 and stone[2][0] == door and absf(stone[3].x - (DOOR_AT.x - 16.0)) < 1.0,
			"a slingshot stone stops at the door", str(stone[3]))
	check(blob.health.current_health == 30, "the enemy behind it is not hit")
	var bomb := await _fire(BOMB_PROJECTILE_SCENE, carl, DOOR_AT + Vector2(-70, 0))
	check(bomb[1].count == 1 and bomb[2][0] == door, "a thrown Blast Bomb stops at the door (and explodes there)")
	await wait_physics_frames(2)
	check(blob.health.current_health == 30, "the door shields the enemy from the blast")
	check(not door.is_open() and door.is_blocking() and carl.health.current_health == 100, "the door is still closed; Carl is unhurt")


func _check_lever_opens_door() -> void:
	print("-- A lever opens the door")
	var carl := await _new_arena()
	var door := _add_door(DOOR_AT)
	var lever := _add_lever(CENTRE + Vector2(0, -30))
	# The level scene makes this connection in the editor; here the test makes it.
	lever.activated.connect(door.open)
	var openings := Counter.new()
	door.opened.connect(openings.record)
	var blob := _add_idle_blob(DOOR_AT + Vector2(80, 0))
	await wait_physics_frames(2)
	check(not door.is_open(), "the door is closed until the lever is pulled")
	await tap_key(KEY_E)
	check(lever.is_active() and door.is_open() and openings.count == 1 and door.open_look.visible and not door.closed_look.visible,
			"pulling the lever opens the door: the open look, `opened` once")
	await wait_physics_frames(1)
	check(not door.is_blocking(), "its collision is gone")
	var query := PhysicsRayQueryParameters2D.create(DOOR_AT + Vector2(-40, 0), DOOR_AT + Vector2(40, 0), 1)
	check(root.world_2d.direct_space_state.intersect_ray(query).is_empty(), "nothing on `world` is left in the doorway")
	check(carl.health.current_health == 100, "the opening hurt nobody")
	var stone := await _fire(STONE_SCENE, carl, DOOR_AT + Vector2(-70, 0))
	check(stone[2][0] is Hurtbox and blob.health.current_health == 20, "a stone flies through the doorway and hits the enemy behind it",
			str(blob.health.current_health))
	var bomb := await _fire(BOMB_PROJECTILE_SCENE, carl, DOOR_AT + Vector2(-70, 0))
	await wait_physics_frames(2)
	check(bomb[2][0] is Hurtbox and blob.health.current_health == 0, "a Blast Bomb flies through and its blast reaches the enemy",
			str(blob.health.current_health))
	await hold_keys([KEY_RIGHT], 90)
	check(carl.global_position.x > DOOR_AT.x + 40.0, "Carl walks through the doorway", str(carl.global_position))
	door.open()
	door.open()
	check(openings.count == 1 and door.is_open() and not door.is_blocking(), "open() again changes nothing: no second `opened`")
	await wait_seconds(1.0)
	check(door.is_open() and not door.is_blocking() and door.open_look.visible, "it stays open")
	await hold_keys([KEY_LEFT], 90)
	check(carl.global_position.x < DOOR_AT.x - 40.0, "and Carl can walk back through it", str(carl.global_position))
	check(take_engine_messages().is_empty(), "no error")


func _check_donut_and_the_door() -> void:
	print("-- Donut and the door")
	if _arena != null:
		_arena.free()
		_arena = null
	# A navigation arena like a level: a wall from top to bottom with a 64 px doorway, the door in it.
	# The door is outside the NavigationRegion2D, so the doorway is part of the navigation mesh.
	var walls: Array[Rect2] = [Rect2(400, 0, 32, 268), Rect2(400, 332, 32, 268)]
	_arena = await build_navigation_arena(Vector2(832, 600), walls)
	if _arena == null:
		return
	var state := game_state()
	state.start_new_run()
	var door := _add_door(Vector2(416, 300))
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = Vector2(560, 300)
	_arena.add_child(carl)
	carl.inventory = state.inventory
	carl.action_slots = state.action_slots
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = Vector2(250, 300)
	_arena.add_child(donut)
	await wait_seconds(3.0)
	check(donut.global_position.x < 416.0 - 16.0 - 10.0 + 0.5, "the door closed, Donut cannot follow Carl past it", str(donut.global_position))
	door.open()
	var through := func() -> bool: return donut.global_position.x > 460.0 and donut.global_position.distance_to(carl.global_position) < 100.0
	check(await wait_until(through, "Donut to come through the doorway", 300), "the door open, Donut follows Carl through the doorway",
			str(donut.global_position))
	check(donut.health.current_health == 60, "unhurt")


func _check_architecture() -> void:
	print("-- Architecture")
	var lever_code := _code("res://scripts/props/lever.gd")
	var door_code := _code("res://scripts/props/controlled_door.gd")
	for word in ["get_node", "/root", "get_tree", "NodePath", "floor", "Floor", "door", "Door", "stairs", "Stairs", "chest", "Chest",
			"inventory", "Inventory", "GameState", "SaveManager"]:
		check(not lever_code.contains(word), "the Lever's code does not use \"%s\"" % word)
	for word in ["get_node", "/root", "get_tree", "NodePath", "floor", "Floor", "lever", "Lever", "stairs", "Stairs", "chest", "Chest",
			"inventory", "Inventory", "GameState", "SaveManager"]:
		check(not door_code.contains(word), "the Door's code does not use \"%s\"" % word)
	for path in ["res://scripts/actors/carl.gd", "res://scripts/interaction/interaction_controller.gd", "res://scripts/interaction/interactable.gd",
			"res://scripts/props/stairs.gd"]:
		var code := _code(path)
		check(not code.contains("Lever") and not code.contains("lever") and not code.contains("Door") and not code.contains("door"),
				"%s knows no lever and no door" % path.get_file())
	var autoloads := ProjectSettings.get_property_list().map(func(p: Dictionary) -> String: return p["name"]).filter(
			func(name: String) -> bool: return name.begins_with("autoload/"))
	autoloads.sort()
	check(autoloads == ["autoload/GameState", "autoload/SaveManager", "autoload/SettingsManager"],
			"the autoloads are still GameState, SaveManager and SettingsManager: no event bus", str(autoloads))


func _check_several_interactables() -> void:
	print("-- Several interactables")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var pickups := Node2D.new()
	_arena.add_child(pickups)
	var chest: TreasureChest = CHEST_SCENE.instantiate()
	chest.contents = {&"small_health_potion": 1}
	chest.loot_parent = pickups
	chest.position = CENTRE + Vector2(-46, 0)
	_arena.add_child(chest)
	var lever := _add_lever(CENTRE + Vector2(30, 0))
	var plain := _add_plain("Plain Thing", CENTRE + Vector2(0, -52))
	var pulls := Counter.new()
	lever.activated.connect(pulls.record)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Pull Lever", "the nearest, the lever, is prompted", controller.get_prompt_text())
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(pulls.count == 1 and not chest.is_open() and plain[1].count == 0, "one press uses only the lever")
	check(controller.get_prompt_text() == "E: Open Chest", "the pulled lever is skipped: the chest (next nearest) is prompted",
			controller.get_prompt_text())
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	check(chest.is_open() and pulls.count == 1 and plain[1].count == 0, "the next press opens only the chest")
	check(controller.get_prompt_text() == "E: Plain Thing", "then the last one", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(plain[1].count == 1 and pulls.count == 1, "and only it is used")


func _check_ties() -> void:
	print("-- Ties between a lever and another interactable")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var lever := _add_lever(CENTRE + Vector2(40, 0))
	var plain := _add_plain("Plain Thing", CENTRE + Vector2(-40, 0))
	var pulls := Counter.new()
	lever.activated.connect(pulls.record)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Pull Lever", "the same distance: the one earlier in the tree (the lever)", controller.get_prompt_text())
	_arena.move_child(plain[0], 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Plain Thing", "moved earlier in the tree, the other one wins", controller.get_prompt_text())
	lever.position = CENTRE + Vector2(39.7, 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Plain Thing", "the lever 0.3 px nearer: still a tie, the earlier one")
	await tap_key(KEY_E)
	check(plain[1].count == 1 and pulls.count == 0, "one press uses only that one")
	lever.position = CENTRE + Vector2(39, 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Pull Lever", "the lever 1 px nearer wins")
	for i in 3:
		await wait_physics_frames(1)
		check(controller.get_prompt_text() == "E: Pull Lever", "the choice is stable, tick %d" % i)


func _check_pause_and_carl_down() -> void:
	print("-- A paused game, and Carl down")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var lever := _add_lever(CENTRE + Vector2(30, 0))
	await wait_physics_frames(2)
	paused = true
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "", "paused: no prompt")
	await tap_key(KEY_E)
	check(not lever.is_active(), "paused: E does nothing")
	send_key(KEY_E, true)
	await wait_physics_frames(3)
	paused = false
	await wait_physics_frames(30)
	check(not lever.is_active() and controller.get_prompt_text() == "E: Pull Lever", "E held through the resume pulls nothing; the prompt is back")
	send_key(KEY_E, false)
	await wait_physics_frames(2)
	await tap_key(KEY_E)
	check(lever.is_active(), "the next press pulls it")
	var other := _add_lever(CENTRE + Vector2(0, 30))
	await wait_physics_frames(2)
	carl.get_node("Hurtbox").take_hit(100)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "", "Carl down: no prompt")
	await tap_key(KEY_E)
	check(not other.is_active(), "Carl down: E does nothing")


## A fresh arena with Carl at CENTRE and the default keys.
func _new_arena() -> CharacterBody2D:
	if _arena != null:
		_arena.free()
	paused = false
	settings_manager().reset_to_defaults()
	_arena = Node2D.new()
	root.add_child(_arena)
	var state := game_state()
	state.start_new_run()
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = CENTRE
	_arena.add_child(carl)
	carl.inventory = state.inventory
	carl.action_slots = state.action_slots
	await wait_physics_frames(2)
	return carl


func _add_lever(at: Vector2) -> Lever:
	var lever: Lever = LEVER_SCENE.instantiate()
	lever.position = at
	_arena.add_child(lever)
	return lever


## A vertical door (rotated 90 degrees, 32 px wide and 64 px high) centred on `at`.
func _add_door(at: Vector2) -> ControlledDoor:
	var door: ControlledDoor = DOOR_SCENE.instantiate()
	door.position = at
	door.rotation = PI / 2.0
	_arena.add_child(door)
	return door


func _add_idle_blob(at: Vector2) -> Enemy:
	var blob: Enemy = BLOB_SCENE.instantiate()
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	blob.position = at
	_arena.add_child(blob)
	return blob


## A plain Interactable (no object of its own) and a Counter of its uses: [Interactable, Counter].
func _add_plain(prompt_text: String, at: Vector2) -> Array:
	var thing := Node2D.new()
	thing.set_script(INTERACTABLE_SCRIPT)
	thing.name = prompt_text.to_pascal_case()
	thing.prompt_text = prompt_text
	_arena.add_child(thing)
	thing.global_position = at
	var counter := Counter.new()
	thing.interacted.connect(counter.record)
	return [thing, counter]


## Fires a projectile of `scene` from `from` to the right, thrown by `source`, and waits until it
## stops: [projectile, Counter of `stopped`, [what stopped it], where it stopped].
func _fire(scene: PackedScene, source: Node, from: Vector2) -> Array:
	var projectile := scene.instantiate() as Projectile
	projectile.source = source
	var stopped := Counter.new()
	var result := [null, Vector2.ZERO]
	projectile.stopped.connect(stopped.record)
	projectile.stopped.connect(func(collider: Object) -> void:
		result[0] = collider
		result[1] = projectile.global_position)
	_arena.add_child(projectile)
	projectile.launch(from, Vector2.RIGHT)
	await wait_until(func() -> bool: return stopped.count > 0, "the projectile to stop", 120)
	return [projectile, stopped, result, result[1]]


## A script's code without its comments.
func _code(path: String) -> String:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var code := PackedStringArray()
	for line in lines:
		var hash_at := line.find("#")
		code.append(line if hash_at == -1 else line.substr(0, hash_at))
	return "\n".join(code)
