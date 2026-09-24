extends "res://tests/support/game_test.gd"
## Phase 3 action-slot checks, in an empty arena (no level):
## - a new game's layout: W, A and S empty, Fists in D;
## - ActionSlots rules: moving an action empties its old slot, actions that cannot be
##   assigned are refused, and `changed` is emitted only for real changes;
## - Carl uses whatever each slot holds: Fists on D, then on W, then on A and S, without
##   restarting anything, and moving Fists does not reset its cooldown;
## - a second, test-only action works next to Fists with no change to Carl;
## - the HUD's slot bar follows every change at once.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_action_slots.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const S := ActionSlots.SLOT_S
const D := ActionSlots.SLOT_D

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_new_game_layout()
	_check_assignment_rules()
	await _check_carl_follows_the_slots()
	await _check_a_second_action()
	finish()


func _check_new_game_layout() -> void:
	print("-- New game layout")
	var state := game_state()
	# Leave the slots in a different state first: a new run must reset them.
	state.action_slots.assign(FISTS, W)
	state.start_new_run()
	var slots: ActionSlots = state.action_slots
	check(slots.get_action(W) == null and slots.get_action(A) == null and slots.get_action(S) == null,
			"W, A and S start empty")
	check(slots.get_action(D) != null and slots.get_action(D).id == &"fists", "D starts with Fists")
	var actions: Array[ActionDefinition] = state.inventory.get_actions()
	check(actions.size() == 1 and actions[0].id == &"fists",
			"Carl starts with one action: Fists", str(actions.map(func(a: ActionDefinition) -> StringName: return a.id)))
	check(FISTS.display_name == "Fists" and FISTS.assignable and FISTS.performer_scene != null,
			"Fists has a name, can be assigned, and has a performer scene")


func _check_assignment_rules() -> void:
	print("-- ActionSlots rules")
	# Since Phase 4, slots only hold actions Carl has, so they need an inventory. Fists is innate,
	# and the test-only actions below are added as carried items.
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	var slots := ActionSlots.new(inventory)
	var changes := [0]
	slots.changed.connect(func() -> void: changes[0] += 1)
	slots.assign(FISTS, D)
	check(slots.find_slot(FISTS) == D and changes[0] == 1, "assigning Fists to D", "changes %d" % changes[0])

	check(slots.assign(FISTS, W) and slots.get_action(W) == FISTS and slots.get_action(D) == null,
			"moving Fists from D to W empties D")
	check(_count_slots_holding(slots, FISTS) == 1 and changes[0] == 2, "Fists is in exactly one slot", "changes %d" % changes[0])
	check(slots.assign(FISTS, W) and changes[0] == 2, "assigning Fists to the slot it is already in changes nothing")

	# A copy of the definition has the same id, so it is the same action.
	check(slots.assign(FISTS.duplicate(), S) and slots.get_action(W) == null and _count_slots_holding(slots, FISTS) == 1,
			"actions are identified by id")

	var locked := ActionDefinition.new()
	locked.id = &"test_locked"
	locked.display_name = "Locked"
	locked.assignable = false
	inventory.add(locked, 1)
	check(not slots.assign(locked, A) and slots.get_action(A) == null and changes[0] == 3,
			"an action that is not assignable is refused and nothing changes")

	var other := ActionDefinition.new()
	other.id = &"test_other"
	other.display_name = "Other"
	inventory.add(other, 1)
	slots.assign(other, S)
	check(slots.get_action(S) == other and slots.find_slot(FISTS) == &"",
			"putting another action in Fists' slot leaves Fists unassigned")
	check(slots.get_display_name(S) == "Other x1" and slots.get_display_name(A) == ActionSlots.EMPTY_LABEL,
			"display names: the action's name (with the quantity of a carried item), or the empty label", "%s / %s" % [slots.get_display_name(S), slots.get_display_name(A)])
	slots.clear_all()
	check(ActionSlots.SLOTS.all(func(slot: StringName) -> bool: return slots.get_action(slot) == null), "clear_all empties every slot")


func _check_carl_follows_the_slots() -> void:
	print("-- Carl uses whatever each slot holds")
	var slots: ActionSlots = _new_arena().action_slots
	var carl := _spawn_carl()
	var blob := _spawn_blob(Vector2(45, 0), carl)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_action_slots(slots, game_state().inventory)
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	var fists: MeleeAttack = carl.get_action_performer(FISTS)
	var punches := []
	fists.performed.connect(func(direction: Vector2, hits: int) -> void: punches.append([direction, hits]))
	await tap_key(KEY_RIGHT)
	await wait_seconds(0.5)

	check(slot_bar.text == "W: —   A: —   S: —   D: Fists", "HUD shows the new-game layout", slot_bar.text)
	await _hold_each([KEY_W, KEY_A, KEY_S])
	check(punches.is_empty() and blob.health.current_health == 1000, "W, A and S do not punch")
	await tap_key(KEY_D)
	check(punches.size() == 1 and blob.health.current_health == 990, "D punches", "blob HP %d" % blob.health.current_health)

	await wait_seconds(0.5)
	slots.assign(FISTS, W)
	check(slot_bar.text == "W: Fists   A: —   S: —   D: —", "HUD updates as soon as Fists moves to W", slot_bar.text)
	check(carl.get_action_performer(FISTS) == fists, "Carl keeps the same Fists performer")
	await _hold_each([KEY_D, KEY_A, KEY_S])
	check(punches.size() == 1, "after the move, D (now empty) does not punch")
	await tap_key(KEY_W)
	check(punches.size() == 2 and blob.health.current_health == 980, "after the move, W punches", "blob HP %d" % blob.health.current_health)
	await wait_seconds(0.5)
	await tap_key(KEY_LEFT)
	await tap_key(KEY_W)
	check(punches.size() == 3 and punches[2][0] == Vector2.LEFT and punches[2][1] == 0,
			"W punches the way Carl faces: facing left, the blob on the right is missed")
	await tap_key(KEY_RIGHT)

	# Reassigning again works straight away, without restarting anything.
	await wait_seconds(0.5)
	slots.assign(FISTS, A)
	check(slot_bar.text == "W: —   A: Fists   S: —   D: —", "HUD updates when Fists moves to A", slot_bar.text)
	await _hold_each([KEY_W, KEY_S, KEY_D])
	await tap_key(KEY_A)
	check(punches.size() == 4 and blob.health.current_health == 970, "then only A punches", "%d punches" % punches.size())

	# Moving an action does not reset its cooldown, so it cannot be used to punch faster.
	slots.assign(FISTS, S)
	await hold_keys([KEY_S], 10)
	check(punches.size() == 4, "moving Fists right after a punch does not skip its cooldown")
	await wait_seconds(0.5)
	await tap_key(KEY_S)
	check(punches.size() == 5 and blob.health.current_health == 960, "after the cooldown, S punches")


func _check_a_second_action() -> void:
	print("-- A second action next to Fists (test-only)")
	var slots: ActionSlots = _new_arena().action_slots
	# A weaker melee action that exists only in this test. Carl's script knows nothing about
	# it; it only needs a definition and a performer scene.
	var jab_attack := MeleeAttack.new()
	jab_attack.damage = 7
	jab_attack.target_layers = 32  # enemy_hurtbox
	var jab_scene := PackedScene.new()
	jab_scene.pack(jab_attack)
	jab_attack.free()
	var jab := ActionDefinition.new()
	jab.id = &"test_jab"
	jab.display_name = "Test Jab"
	jab.performer_scene = jab_scene
	game_state().inventory.add(jab, 1)

	var carl := _spawn_carl()
	var blob := _spawn_blob(Vector2(45, 0), carl)
	await tap_key(KEY_RIGHT)
	slots.assign(jab, A)
	await wait_physics_frames(1)
	await tap_key(KEY_A)
	check(blob.health.current_health == 993, "A uses the test action (7 damage)", "blob HP %d" % blob.health.current_health)
	await tap_key(KEY_D)
	check(blob.health.current_health == 983, "D still uses Fists (10 damage)", "blob HP %d" % blob.health.current_health)
	check(carl.get_action_performer(jab) != carl.get_action_performer(FISTS), "each action has its own performer")


## Holds each key on its own for half a second.
func _hold_each(keys: Array[Key]) -> void:
	for key in keys:
		await hold_keys([key], 30)


func _count_slots_holding(slots: ActionSlots, action: ActionDefinition) -> int:
	return ActionSlots.SLOTS.filter(func(slot: StringName) -> bool:
		var held := slots.get_action(slot)
		return held != null and held.id == action.id).size()


## Starts an empty arena and a new run. Returns GameState.
func _new_arena() -> Node:
	if _arena != null:
		_arena.free()
	_arena = Node2D.new()
	root.add_child(_arena)
	var state := game_state()
	state.start_new_run()
	return state


func _spawn_carl() -> CharacterBody2D:
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	_arena.add_child(carl)
	carl.action_slots = game_state().action_slots
	return carl


## A blob with lots of HP that never moves (its detection range is 0), so every hit can be counted.
func _spawn_blob(at: Vector2, carl: Node2D) -> CharacterBody2D:
	var blob: CharacterBody2D = BLOB_SCENE.instantiate()
	blob.target = carl
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	blob.get_node("Health").max_health = 1000
	blob.position = at
	_arena.add_child(blob)
	return blob
