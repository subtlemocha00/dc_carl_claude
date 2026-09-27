extends "res://tests/support/game_test.gd"
## Phase 14: the Treasure Chest (scenes/props/treasure_chest.tscn), in small arenas with a real
## Carl, keys sent through Godot's input pipeline:
## - Its make-up: a solid body on `world`, an Interactable that is one_shot with "Open Chest".
## - Closed at first (the closed look); Carl next to it sees "E: Open Chest".
## - E opens it: the open look, `opened` once, the prompt gone; the inventory unchanged (then and
##   later: opening gives nothing by itself); one ordinary ItemPickup per entry, in order, at the
##   first two loot spots (82 px below it, side by side, 80 px apart), "Potion x1" and
##   "Blast Bomb x2" with the bomb's icon, in `loot_parent`. E again, or interact(), does nothing:
##   still open, still two pickups, `opened` still once.
## - Only Carl collects: Donut, a Gelatinous and a Spitting Blob standing on the pickups, and a
##   stone and a thrown bomb flying over them, take nothing; Carl walking over them gets exactly
##   Potion x1 and Blast Bomb x2, once; the pickups are gone; walking there again gives nothing.
## - Configuration: another chest holding the Slingshot, the Bat and 3 potions puts those three
##   pickups at the first three free spots; unknown ids (a look-alike, a resource path, an empty id),
##   quantities of 0, -1, 1000 and a reusable item x2 are reported and left out (nothing is loaded
##   from the id), the valid entries still appear; a chest with nothing valid opens and drops
##   nothing; no crash.
## - Placement: never in a wall or beyond one. Against a wall below it, the loot goes above it;
##   boxed in, it goes on the chest (reported as an error). Opened from the farthest point Carl can
##   stand toward a loot spot, the pickup does not land on him.
## - A chest removed in the frame it opened drops nothing and does not crash.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_treasure_chest.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/props/treasure_chest.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/enemies/spitting_blob.tscn")
const STONE_SCENE: PackedScene = preload("res://scenes/projectiles/slingshot_stone.tscn")
const BOMB_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/blast_bomb.tscn")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const CHEST_AT := Vector2(400, 300)
const FLOOR_7_CONTENTS: Dictionary[StringName, int] = {&"small_health_potion": 1, &"blast_bomb": 2}

var _arena: Node2D
var _pickups_node: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_scene()
	await _check_opening()
	await _check_collecting()
	await _check_other_contents()
	await _check_invalid_contents()
	await _check_placement()
	await _check_never_on_carl()
	await _check_removed_while_opening()
	finish()


func _check_scene() -> void:
	print("-- The chest scene")
	var chest: TreasureChest = CHEST_SCENE.instantiate()
	check(chest is StaticBody2D and chest.collision_layer == 1 and chest.collision_mask == 0, "a solid body on the world layer")
	var interactable := chest.get_node("Interactable") as Interactable
	check(interactable != null and interactable.one_shot and interactable.enabled and interactable.prompt_text == "Open Chest",
			"its Interactable is one_shot and says Open Chest")
	check(chest.contents.is_empty(), "the scene itself holds nothing: each placed chest sets its contents")
	chest.free()


func _check_opening() -> void:
	print("-- Opening")
	var carl := await _new_arena()
	var chest := _add_chest(FLOOR_7_CONTENTS)
	var inventory: Inventory = game_state().inventory
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	var opened := [0]
	chest.opened.connect(func() -> void: opened[0] += 1)
	var spawned := []
	chest.loot_spawned.connect(func(made: Array[ItemPickup]) -> void: spawned.append(made))
	var controller: InteractionController = carl.get_node("InteractionController")
	await wait_physics_frames(2)
	check(not chest.is_open() and chest.get_node("ClosedLook").visible and not chest.get_node("OpenLook").visible, "it starts closed")
	check(controller.get_prompt_text() == "", "from 100 px away there is no prompt")
	carl.teleport_to(CHEST_AT + Vector2(0, -30))
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Open Chest", "next to it: \"E: Open Chest\"", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(chest.is_open() and opened[0] == 1 and not chest.get_node("ClosedLook").visible and chest.get_node("OpenLook").visible,
			"E opens it: it looks open, `opened` once")
	check(controller.get_prompt_text() == "", "its prompt goes away")
	check(changes[0] == 0 and inventory.get_quantity(POTION) == 0 and inventory.get_quantity(BOMB) == 0, "opening changes nothing in the inventory")
	await wait_physics_frames(2)
	var pickups := _pickups()
	check(spawned.size() == 1 and spawned[0] == pickups and pickups.size() == 2, "two pickups appear, announced once", "%d" % pickups.size())
	if pickups.size() == 2:
		var potion: ItemPickup = pickups[0]
		var bomb: ItemPickup = pickups[1]
		check(potion.item == POTION and potion.quantity == 1 and potion.get_node("Label").text == "Potion x1", "the first is Potion x1")
		check(bomb.item == BOMB and bomb.quantity == 2 and bomb.get_node("Label").text == "Blast Bomb x2"
				and bomb.get_node("Marker/Icon").visible and bomb.get_node("Marker/Icon").texture == BOMB.icon,
				"the second is Blast Bomb x2, with the bomb icon")
		check(potion.global_position == CHEST_AT + Vector2(-40, 72) and bomb.global_position == CHEST_AT + Vector2(40, 72),
				"they lie side by side below the chest, 80 px apart", "%s %s" % [potion.global_position, bomb.global_position])
		check(pickups.all(func(p: ItemPickup) -> bool: return p.get_parent() == _pickups_node), "in the chest's loot_parent")
	await wait_seconds(0.5)
	check(changes[0] == 0, "half a second later Carl still has nothing from it")
	await tap_key(KEY_E)
	check(not (chest.get_node("Interactable") as Interactable).interact(carl), "interact() on the open chest does nothing")
	await wait_physics_frames(2)
	check(chest.is_open() and opened[0] == 1 and _pickups().size() == 2 and spawned.size() == 1, "E again: nothing more, no new pickups")


func _check_collecting() -> void:
	print("-- Only Carl collects the loot")
	var carl := await _new_arena()
	_add_chest(FLOOR_7_CONTENTS)
	var inventory: Inventory = game_state().inventory
	carl.teleport_to(CHEST_AT + Vector2(0, -30))
	await wait_physics_frames(2)
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	var pickups := _pickups()
	if pickups.size() != 2:
		check(false, "the loot appeared")
		return
	var potion: ItemPickup = pickups[0]
	var bomb: ItemPickup = pickups[1]
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = potion.position
	_arena.add_child(donut)
	var blob: Enemy = BLOB_SCENE.instantiate()
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	blob.position = bomb.position + Vector2(0, 6)
	_arena.add_child(blob)
	var spitter: Enemy = SPITTER_SCENE.instantiate()
	spitter.detection_range = 0.0
	spitter.chase_range = 0.0
	spitter.position = potion.position + Vector2(0, -6)
	_arena.add_child(spitter)
	await wait_seconds(0.5)
	check(is_instance_valid(potion) and is_instance_valid(bomb) and inventory.get_quantity(POTION) == 0 and inventory.get_quantity(BOMB) == 0,
			"Donut and two enemies standing on the loot take nothing")
	donut.queue_free()
	blob.queue_free()
	spitter.queue_free()
	await wait_physics_frames(2)
	var stone := STONE_SCENE.instantiate() as Projectile
	_arena.add_child(stone)
	stone.launch(potion.position + Vector2(-150, 0), Vector2.RIGHT)
	var thrown := BOMB_PROJECTILE_SCENE.instantiate() as Projectile
	_arena.add_child(thrown)
	thrown.launch(bomb.position + Vector2(0, 150), Vector2.UP)
	await wait_seconds(1.5)
	check(is_instance_valid(potion) and is_instance_valid(bomb) and inventory.get_quantity(POTION) == 0 and inventory.get_quantity(BOMB) == 0,
			"a stone and a bomb flying over the loot take nothing")
	carl.teleport_to(potion.position + Vector2(-60, 0))
	await wait_physics_frames(2)
	check(inventory.get_quantity(POTION) == 0, "nothing yet from standing near it")
	await _walk_carl_to(carl, potion.position)
	check(inventory.get_quantity(POTION) == 1 and inventory.get_quantity(BOMB) == 0, "Carl walking over the potion gets exactly 1")
	await _walk_carl_to(carl, bomb.position)
	check(inventory.get_quantity(POTION) == 1 and inventory.get_quantity(BOMB) == 2, "and over the bombs exactly 2")
	await wait_physics_frames(2)
	check(_pickups().is_empty(), "both pickups are gone")
	await _walk_carl_to(carl, CHEST_AT + Vector2(-40, 72))
	await _walk_carl_to(carl, CHEST_AT + Vector2(40, 72))
	check(inventory.get_quantity(POTION) == 1 and inventory.get_quantity(BOMB) == 2, "walking over the spots again gives nothing more")


func _check_other_contents() -> void:
	print("-- Other contents: only data changes")
	var carl := await _new_arena()
	var chest := _add_chest({&"slingshot": 1, &"baseball_bat": 1, &"small_health_potion": 3})
	carl.teleport_to(CHEST_AT + Vector2(-30, 0))
	await wait_physics_frames(2)
	await tap_key(KEY_E)
	await wait_physics_frames(2)
	var pickups := _pickups()
	check(chest.is_open() and pickups.size() == 3, "three entries: three pickups", "%d" % pickups.size())
	if pickups.size() == 3:
		check(pickups[0].item == SLINGSHOT and pickups[0].get_node("Label").text == "Slingshot" and pickups[1].item == BAT
				and pickups[2].item == POTION and pickups[2].quantity == 3 and pickups[2].get_node("Label").text == "Potion x3",
				"in order: the Slingshot, the Bat, Potion x3")
		check(pickups[0].global_position == CHEST_AT + Vector2(-40, 72) and pickups[1].global_position == CHEST_AT + Vector2(40, 72)
				and pickups[2].global_position == CHEST_AT + Vector2(-40, -72), "at the first three loot spots")
	check(not game_state().inventory.has(SLINGSHOT) and not game_state().inventory.has(BAT), "and nothing is owned yet")


func _check_invalid_contents() -> void:
	print("-- Invalid contents are left out safely")
	var cases: Array = [
		[{&"blast_bomb": 2, &"no_such_item": 1}, [BOMB]],
		[{&"Blast_Bomb": 1, &"small_health_potion": 1}, [POTION]],
		[{&"res://resources/actions/slingshot.tres": 1}, []],
		[{&"": 1}, []],
		[{&"blast_bomb": 0}, []],
		[{&"blast_bomb": -1}, []],
		[{&"blast_bomb": 1000}, []],
		[{&"slingshot": 2}, []],
		[{&"small_health_potion": 999}, [POTION]],
	]
	for case: Array in cases:
		var carl := await _new_arena()
		var contents: Dictionary[StringName, int] = {}
		contents.assign(case[0])
		var chest := _add_chest(contents)
		carl.teleport_to(CHEST_AT + Vector2(0, -30))
		await wait_physics_frames(2)
		await tap_key(KEY_E)
		await wait_physics_frames(2)
		var expected: Array = case[1]
		var errors := take_engine_messages()
		var items := _pickups().map(func(p: ItemPickup) -> ActionDefinition: return p.item)
		check(chest.is_open() and items == expected, "%s: opens, and drops only %s" % [str(case[0]), expected.map(func(i: ActionDefinition) -> String: return i.id)],
				str(items))
		check(errors.size() == contents.size() - expected.size() and Array(errors).all(func(e: String) -> bool: return e.contains("left out")),
				"%s: each invalid entry is reported" % str(case[0]), str(errors))
		check(game_state().inventory.get_actions().size() == 1, "%s: the inventory is untouched" % str(case[0]))


func _check_placement() -> void:
	print("-- Placement")
	# A wall just below the chest: the first two spots are blocked, so the loot goes above it.
	await _new_arena(Vector2(100, 100))
	_arena.add_child(new_wall(Rect2(CHEST_AT + Vector2(-120, 40), Vector2(240, 32))))
	var chest := _add_chest(FLOOR_7_CONTENTS)
	var opened := chest.get_node("Interactable") as Interactable
	await wait_physics_frames(2)
	opened.interact(null)
	await wait_physics_frames(2)
	var spots := _pickups().map(func(p: ItemPickup) -> Vector2: return p.global_position)
	check(spots == [CHEST_AT + Vector2(-40, -72), CHEST_AT + Vector2(40, -72)], "a wall below: the loot goes above the chest", str(spots))
	for spot: Vector2 in spots:
		check(_is_clear_of_walls(spot) and _nothing_between(CHEST_AT, spot), "%s is clear of walls and in the room" % spot)
	# Past a wall (the spot itself is free, but beyond a wall): not used.
	await _new_arena(Vector2(100, 100))
	_arena.add_child(new_wall(Rect2(CHEST_AT + Vector2(-60, 30), Vector2(120, 8))))
	chest = _add_chest(FLOOR_7_CONTENTS)
	await wait_physics_frames(2)
	(chest.get_node("Interactable") as Interactable).interact(null)
	await wait_physics_frames(2)
	spots = _pickups().map(func(p: ItemPickup) -> Vector2: return p.global_position)
	check(spots == [CHEST_AT + Vector2(-40, -72), CHEST_AT + Vector2(40, -72)], "free spots beyond a thin wall are not used", str(spots))
	# Boxed in: everything goes on the chest, with a warning.
	await _new_arena(Vector2(100, 100))
	for rect: Rect2 in [Rect2(CHEST_AT + Vector2(-60, -60), Vector2(120, 16)), Rect2(CHEST_AT + Vector2(-60, 44), Vector2(120, 16)),
			Rect2(CHEST_AT + Vector2(-60, -60), Vector2(16, 120)), Rect2(CHEST_AT + Vector2(44, -60), Vector2(16, 120))]:
		_arena.add_child(new_wall(rect))
	chest = _add_chest(FLOOR_7_CONTENTS)
	await wait_physics_frames(2)
	(chest.get_node("Interactable") as Interactable).interact(null)
	await wait_physics_frames(2)
	var reported := take_engine_messages()
	spots = _pickups().map(func(p: ItemPickup) -> Vector2: return p.global_position)
	check(spots == [CHEST_AT, CHEST_AT] and reported.size() == 1 and reported[0].contains("no free spot"),
			"boxed in by walls: the loot lies on the chest, reported as an error", "%s %s" % [spots, reported])


func _check_never_on_carl() -> void:
	print("-- The loot never lands on Carl")
	for offset: Vector2 in [Vector2(-40, 72), Vector2(40, 72)]:
		var carl := await _new_arena()
		_add_chest(FLOOR_7_CONTENTS)
		# As far toward the loot spot as Carl can stand and still reach the chest.
		carl.teleport_to(CHEST_AT + offset.normalized() * 55.0)
		await wait_physics_frames(2)
		check(carl.get_node("InteractionController").get_prompt_text() == "E: Open Chest", "Carl at %s can open it" % carl.global_position)
		await tap_key(KEY_E)
		await wait_physics_frames(5)
		check(_pickups().size() == 2 and game_state().inventory.get_quantity(POTION) == 0 and game_state().inventory.get_quantity(BOMB) == 0,
				"opened toward %s, nothing lands on him and nothing is collected" % offset)


func _check_removed_while_opening() -> void:
	print("-- A chest removed in the frame it opened")
	await _new_arena()
	var chest := _add_chest(FLOOR_7_CONTENTS)
	await wait_physics_frames(2)
	(chest.get_node("Interactable") as Interactable).interact(null)
	chest.get_parent().remove_child(chest)
	await wait_physics_frames(2)
	check(_pickups().is_empty(), "it drops nothing and nothing breaks")
	chest.free()


## A fresh arena: Carl at `carl_at` (100 px above the chest by default) and a Pickups node.
func _new_arena(carl_at: Vector2 = CHEST_AT + Vector2(0, -100)) -> CharacterBody2D:
	if _arena != null:
		_arena.free()
	paused = false
	_arena = Node2D.new()
	root.add_child(_arena)
	_pickups_node = Node2D.new()
	_pickups_node.name = "Pickups"
	_arena.add_child(_pickups_node)
	var state := game_state()
	state.start_new_run()
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = carl_at
	_arena.add_child(carl)
	carl.inventory = state.inventory
	carl.action_slots = state.action_slots
	await wait_physics_frames(2)
	return carl


func _add_chest(contents: Dictionary[StringName, int]) -> TreasureChest:
	var chest: TreasureChest = CHEST_SCENE.instantiate()
	chest.contents = contents
	chest.loot_parent = _pickups_node
	chest.position = CHEST_AT
	_arena.add_child(chest)
	return chest


func _pickups() -> Array:
	return _pickups_node.get_children().filter(func(node: Node) -> bool: return node is ItemPickup and not node.is_queued_for_deletion())


func _walk_carl_to(carl: CharacterBody2D, target: Vector2) -> void:
	for i in 300:
		if carl.global_position.distance_to(target) <= 3.0:
			break
		steer(carl.global_position.direction_to(target))
		await physics_frame
	steer(Vector2.ZERO)
	await wait_physics_frames(2)


func _is_clear_of_walls(spot: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, spot)
	query.collision_mask = 1
	return root.world_2d.direct_space_state.intersect_shape(query).filter(
			func(hit: Dictionary) -> bool: return not hit["collider"] is TreasureChest).is_empty()


## True if no wall lies on the line (the chest itself does not count).
func _nothing_between(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] is TreasureChest
