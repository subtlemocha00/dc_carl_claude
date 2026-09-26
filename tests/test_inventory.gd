extends "res://tests/support/game_test.gd"
## Phase 4 inventory checks in an empty arena (no level):
## - a new run: no potions, Fists innate and on D, W/A/S empty;
## - Inventory rules: quantities, labels, removing, snapshots;
## - ActionSlots and the inventory: only owned actions can be assigned, one slot per action,
##   the slot of the last potion empties itself, a restored snapshot removes stale slots;
## - the Small Health Potion used through a slot: heals 30 (capped at max), spends exactly one,
##   never at full HP, one per key press; HUD and menu quantities follow;
## - world pickups: Carl gets exactly the pickup's quantity once; Donut and enemies cannot
##   take it; two collectors touching it at the same moment cannot both get it.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_inventory.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/props/item_pickup.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const S := ActionSlots.SLOT_S
const D := ActionSlots.SLOT_D

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_new_run()
	_check_inventory_rules()
	_check_slots_follow_the_inventory()
	await _check_potion_use()
	await _check_one_potion_per_press()
	await _check_menu_quantities()
	await _check_pickup()
	await _check_pickup_taken_once()
	finish()


func _check_new_run() -> void:
	print("-- A new run")
	var state := game_state()
	# Leave a used run behind first: a new run must not inherit any of it.
	state.inventory.add(POTION, 5)
	state.action_slots.assign(POTION, A)
	state.start_new_run()
	var inventory: Inventory = state.inventory
	var slots: ActionSlots = state.action_slots
	check(inventory.get_quantity(POTION) == 0 and not inventory.has(POTION), "a new run has no Small Health Potions")
	check(slots.get_action(W) == null and slots.get_action(A) == null and slots.get_action(S) == null
			and slots.get_action(D) == FISTS, "a new run has W, A, S empty and Fists on D")
	check(inventory.has(FISTS) and inventory.is_innate(FISTS) and inventory.get_quantity(FISTS) == 0,
			"Fists is innate: always there, with no quantity")
	check(POTION.id == &"small_health_potion" and POTION.display_name == "Small Health Potion"
			and POTION.consumable and POTION.assignable and not FISTS.consumable,
			"the potion is an assignable consumable; Fists is not consumable")


func _check_inventory_rules() -> void:
	print("-- Inventory rules")
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	inventory.add(POTION, 2)
	check(inventory.get_quantity(POTION) == 2 and inventory.has(POTION) and changes[0] == 1, "adding 2 potions")
	check(inventory.get_actions() == [FISTS, POTION], "Carl's actions: innate first, then carried items")
	check(inventory.get_label(POTION) == "Small Health Potion x2" and inventory.get_label(POTION, true) == "Potion x2"
			and inventory.get_label(FISTS) == "Fists", "labels show a carried item's quantity, and none for Fists",
			"%s / %s / %s" % [inventory.get_label(POTION), inventory.get_label(POTION, true), inventory.get_label(FISTS)])
	check(not inventory.remove(POTION, 3) and inventory.get_quantity(POTION) == 2, "removing more than Carl has removes nothing")
	var snapshot := inventory.get_snapshot()
	check(inventory.remove(POTION, 1) and inventory.get_quantity(POTION) == 1, "removing one")
	check(inventory.remove(POTION, 1) and not inventory.has(POTION) and inventory.get_actions() == [FISTS],
			"after the last one, the potion leaves the inventory")
	check(not inventory.remove(POTION, 1), "removing from an empty stack fails safely")
	inventory.restore_snapshot(snapshot)
	check(inventory.get_quantity(POTION) == 2, "restoring a snapshot brings back its quantities")
	inventory.add(POTION, 3)
	inventory.restore_snapshot(snapshot)
	check(inventory.get_quantity(POTION) == 2, "restoring replaces quantities instead of adding to them",
			"%d potions" % inventory.get_quantity(POTION))
	check(inventory.has(FISTS), "restoring never touches innate actions")


func _check_slots_follow_the_inventory() -> void:
	print("-- Slots and the inventory")
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	var slots := ActionSlots.new(inventory)
	slots.assign(FISTS, D)
	check(not slots.assign(POTION, A) and slots.get_action(A) == null, "a potion Carl does not have cannot be assigned")
	var empty_snapshot := inventory.get_snapshot()
	inventory.add(POTION, 2)
	check(slots.assign(POTION, A) and slots.get_action(A) == POTION and slots.get_action(D) == FISTS,
			"after collecting, the potion can go on A while Fists stays on D")
	check(slots.assign(POTION, W) and slots.get_action(W) == POTION and slots.get_action(A) == null,
			"reassigning the potion moves it; it is never in two slots")
	for slot: StringName in [A, S, D]:
		slots.assign(POTION, slot)
		check(slots.get_action(slot) == POTION and slots.find_slot(POTION) == slot,
				"the potion can go on " + ActionSlots.SLOT_NAMES[slot])
	check(slots.find_slot(FISTS) == &"", "putting the potion on Fists' key unassigns Fists")
	slots.assign(FISTS, D)
	slots.assign(POTION, A)
	var changes := [0]
	slots.changed.connect(func() -> void: changes[0] += 1)
	inventory.remove(POTION, 1)
	check(slots.get_action(A) == POTION and changes[0] == 0, "using one of two potions keeps the slot")
	inventory.remove(POTION, 1)
	check(slots.get_action(A) == null and slots.get_action(D) == FISTS and changes[0] == 1,
			"using the last potion empties its slot by itself")
	inventory.add(POTION, 1)
	check(slots.get_action(A) == null and slots.assign(POTION, A), "a newly collected potion can be assigned again")
	inventory.restore_snapshot(empty_snapshot)
	check(slots.get_action(A) == null and slots.get_action(D) == FISTS,
			"restoring a snapshot without the potion empties the potion's slot and keeps Fists")


func _check_potion_use() -> void:
	print("-- Using the Small Health Potion from a slot")
	var carl := _new_arena_with_carl()
	var state := game_state()
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_action_slots(state.action_slots, state.inventory)
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	var punches := [0]
	(carl.get_action_performer(FISTS) as MeleeAttack).performed.connect(func(_d: Vector2, _h: int) -> void: punches[0] += 1)

	carl.collect_item(POTION, 2)
	state.action_slots.assign(POTION, A)
	check(slot_bar.text == "W: —   A: Potion x2   S: —   D: Fists", "the HUD shows the potion and its quantity", slot_bar.text)
	await wait_physics_frames(2)

	await tap_key(KEY_A)
	check(carl.health.current_health == 100 and state.inventory.get_quantity(POTION) == 2,
			"at full HP the potion does nothing and is not used up")
	carl.health.take_damage(40)
	await tap_key(KEY_A)
	check(carl.health.current_health == 90 and state.inventory.get_quantity(POTION) == 1,
			"at 60 HP the potion heals 30 (to 90), and exactly one is used",
			"HP %d, potions %d" % [carl.health.current_health, state.inventory.get_quantity(POTION)])
	check(slot_bar.text == "W: —   A: Potion x1   S: —   D: Fists", "the HUD quantity drops to 1", slot_bar.text)

	await wait_seconds(1.1)
	await tap_key(KEY_A)
	check(carl.health.current_health == 100 and state.inventory.get_quantity(POTION) == 0,
			"at 90 HP the potion heals only up to 100, and one is still used",
			"HP %d, potions %d" % [carl.health.current_health, state.inventory.get_quantity(POTION)])
	check(state.action_slots.get_action(A) == null and slot_bar.text == "W: —   A: —   S: —   D: Fists",
			"after the last potion, A is empty in the slots and on the HUD", slot_bar.text)

	carl.health.take_damage(50)
	await wait_seconds(1.1)
	await hold_keys([KEY_A], 30)
	check(carl.health.current_health == 50 and state.inventory.get_quantity(POTION) == 0,
			"with no potions left, A does nothing (and nothing errors)")
	await tap_key(KEY_D)
	check(punches[0] == 1, "Fists on D still punches")


func _check_one_potion_per_press() -> void:
	print("-- One potion per key press")
	var carl := _new_arena_with_carl()
	var inventory: Inventory = game_state().inventory
	carl.collect_item(POTION, 3)
	game_state().action_slots.assign(POTION, S)
	carl.health.take_damage(90)
	await wait_physics_frames(2)
	# A quick human key press lasts about a tenth of a second: 6 physics ticks.
	await hold_keys([KEY_S], 6)
	check(carl.health.current_health == 40 and inventory.get_quantity(POTION) == 2,
			"a short press uses exactly one potion, although a second would still heal",
			"HP %d, potions %d" % [carl.health.current_health, inventory.get_quantity(POTION)])
	await wait_seconds(1.1)
	# Holding the key uses one per second (the potion's cooldown) while Carl is hurt.
	await hold_keys([KEY_S], 90)
	check(carl.health.current_health == 100 and inventory.get_quantity(POTION) == 0,
			"holding S for 1.5 s uses two more (40 -> 70 -> 100)",
			"HP %d, potions %d" % [carl.health.current_health, inventory.get_quantity(POTION)])


func _check_menu_quantities() -> void:
	print("-- The action menu shows the inventory")
	var carl := _new_arena_with_carl()
	var state := game_state()
	var menu: CanvasLayer = MENU_SCENE.instantiate()
	_arena.add_child(menu)
	menu.setup(state.inventory, state.action_slots)

	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)"], "before any pickup the menu lists only Fists", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_SPACE)

	carl.collect_item(POTION, 2)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)", "Small Health Potion x2   (no slot)"],
			"after the pickup the menu lists Small Health Potion x2", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_DOWN)
	await tap_key(KEY_A)
	check(_rows(menu, "%ActionList") == ["Fists   (on D)", "> Small Health Potion x2   (on A)"]
			and _rows(menu, "%SlotList") == ["W   —", "A   Small Health Potion x2", "S   —", "D   Fists"],
			"Down selects the potion and A assigns it", "%s %s" % [_rows(menu, "%ActionList"), _rows(menu, "%SlotList")])
	await tap_key(KEY_SPACE)

	carl.health.take_damage(50)
	await tap_key(KEY_A)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["Fists   (on D)", "> Small Health Potion x1   (on A)"],
			"after one use the menu shows x1", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_SPACE)
	await wait_seconds(1.1)
	await tap_key(KEY_A)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)"] and _rows(menu, "%SlotList")[1] == "A   —",
			"after the last one the potion is gone from the menu and slot A is empty",
			"%s %s" % [_rows(menu, "%ActionList"), _rows(menu, "%SlotList")])
	await tap_key(KEY_SPACE)
	check(not paused, "the menu closed")


func _check_pickup() -> void:
	print("-- Picking up an item")
	var carl := _new_arena_with_carl()
	var inventory: Inventory = game_state().inventory
	var pickup := _spawn_pickup(Vector2(80, 0), 2)
	check(pickup.get_node("Label").text == "Potion x2", "the pickup is labelled with what it gives")

	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = pickup.position
	_arena.add_child(donut)
	var blob: CharacterBody2D = BLOB_SCENE.instantiate()
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	blob.position = pickup.position + Vector2(0, 6)
	_arena.add_child(blob)
	await wait_seconds(0.5)
	check(is_instance_valid(pickup) and inventory.get_quantity(POTION) == 0,
			"Donut and an enemy standing on the pickup do not take it")
	blob.queue_free()
	await wait_physics_frames(2)

	await hold_keys([KEY_RIGHT], 40)
	check(inventory.get_quantity(POTION) == 2, "Carl walking over it gets exactly 2 potions",
			"%d potions" % inventory.get_quantity(POTION))
	await wait_physics_frames(2)
	check(not is_instance_valid(pickup), "the pickup disappears")
	await hold_keys([KEY_LEFT], 40)
	await hold_keys([KEY_RIGHT], 40)
	check(inventory.get_quantity(POTION) == 2, "walking over the spot again gives nothing more")


func _check_pickup_taken_once() -> void:
	print("-- A pickup can only be taken once")
	var carl := _new_arena_with_carl()
	var other_carl: CharacterBody2D = CARL_SCENE.instantiate()
	var other_inventory := Inventory.new()
	other_inventory.reset([FISTS])
	other_carl.inventory = other_inventory
	other_carl.position = Vector2(-60, 40)
	_arena.add_child(other_carl)
	var pickup := _spawn_pickup(Vector2(0, 60), 2)
	await wait_physics_frames(2)
	# Both collectors touch the pickup in the same physics step.
	carl.teleport_to(pickup.position + Vector2(-4, 0))
	other_carl.teleport_to(pickup.position + Vector2(4, 0))
	await wait_physics_frames(3)
	var total: int = game_state().inventory.get_quantity(POTION) + other_inventory.get_quantity(POTION)
	check(total == 2, "two collectors touching it at once get 2 potions in total, not 4", "%d in total" % total)


## Starts an empty arena and a new run, with Carl at the origin using the run's state.
func _new_arena_with_carl() -> CharacterBody2D:
	if _arena != null:
		_arena.free()
	# An earlier check may have ended with the menu open: never start the next one paused.
	paused = false
	_arena = Node2D.new()
	root.add_child(_arena)
	var state := game_state()
	state.start_new_run()
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	_arena.add_child(carl)
	carl.inventory = state.inventory
	carl.action_slots = state.action_slots
	return carl


func _spawn_pickup(at: Vector2, quantity: int) -> Area2D:
	var pickup: Area2D = PICKUP_SCENE.instantiate()
	pickup.item = POTION
	pickup.quantity = quantity
	pickup.position = at
	_arena.add_child(pickup)
	return pickup


## The texts of the rows in one of the menu's lists.
func _rows(menu: CanvasLayer, list_path: String) -> Array:
	return menu.get_node(list_path).get_children().map(func(row: Label) -> String: return row.text)
