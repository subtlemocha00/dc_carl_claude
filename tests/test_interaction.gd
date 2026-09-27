extends "res://tests/support/game_test.gd"
## Phase 14: the generic interaction system (Interactable + Carl's InteractionController), in small
## arenas with a real Carl and test Interactables (plain Node2Ds with the Interactable script, so
## nothing here depends on the chest), keys sent through Godot's input pipeline:
## - Carl has an InteractionController (56 px range, walls block) with a hidden prompt; the
##   `interact` action is bound to E.
## - Nothing in range: no prompt, and the Interact key does nothing (no error either).
## - One in range: the prompt "E: <prompt_text>" appears above it; the key uses it once, with Carl
##   as the interactor. 56 px counts, 57 px does not; walking away removes the prompt.
## - Several in range: the nearest is shown and used, and one press uses only that one; a
##   disabled one and a one_shot one already used are skipped; ties (the same distance, or less than
##   0.5 px apart) always go to the one earlier in the scene tree, whichever that is; 1 px nearer wins.
## - A wall between Carl and it: no prompt, not usable; the object's own solid body is not a wall.
## - Holding the key uses it once; key repeat (echo) does nothing.
## - Rebinding: with Interact on Q the prompt says "Q: ...", E does nothing and Q works; back on E.
## - A paused game (the tree pause every menu and GAME OVER use): no prompt, the key does nothing, a
##   key pressed while paused and still held on resuming does nothing, and the next press works.
## - Carl down: no prompt, nothing usable.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_interaction.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/interaction/interactable.gd")
const CENTRE := Vector2(400, 300)

var _arena: Node2D


## A test object: counts its uses.
class Counter:
	var uses := 0
	var interactors: Array[Node2D] = []

	func record(interactor: Node2D) -> void:
		uses += 1
		interactors.append(interactor)


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	await _check_setup()
	await _check_nothing_in_range()
	await _check_one_in_range()
	await _check_nearest()
	await _check_ties()
	await _check_disabled_and_one_shot()
	await _check_walls()
	await _check_held_and_echo()
	await _check_rebinding()
	await _check_pause()
	await _check_carl_down()
	finish()


func _check_setup() -> void:
	print("-- Setup")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	check(controller != null and controller.user == carl and controller.interaction_range == 56.0 and controller.blocking_layers == 1,
			"Carl has an InteractionController: 56 px range, walls block")
	check(not controller.prompt_label.visible and controller.get_prompt_text() == "", "its prompt starts hidden")
	check(ControlBindings.get_key(&"interact") == KEY_E and ControlBindings.get_key_label(&"interact") == "E", "the interact action is on E")


func _check_nothing_in_range() -> void:
	print("-- Nothing in range")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var far := _add_interactable("Far Thing", CENTRE + Vector2(200, 0))
	await wait_physics_frames(2)
	check(controller.find_interactable() == null and controller.get_prompt_text() == "", "no prompt with nothing in range")
	await tap_key(KEY_E)
	check(far[1].uses == 0, "E does nothing")


func _check_one_in_range() -> void:
	print("-- One in range")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var pair := _add_interactable("Test Thing", CENTRE + Vector2(40, 0))
	var thing: Interactable = pair[0]
	var counter: Counter = pair[1]
	await wait_physics_frames(2)
	check(controller.find_interactable() == thing and controller.get_prompt_text() == "E: Test Thing", "the prompt appears",
			controller.get_prompt_text())
	var prompt_rect := Rect2(controller.prompt_label.global_position, controller.prompt_label.size)
	var anchor := thing.global_position + thing.prompt_offset
	check(absf(prompt_rect.get_center().x - anchor.x) < 1.0 and absf(prompt_rect.end.y - anchor.y) < 1.0,
			"it sits centred above the object", str(prompt_rect))
	await tap_key(KEY_E)
	check(counter.uses == 1 and counter.interactors == [carl], "E uses it once, with Carl as the interactor")
	await tap_key(KEY_E)
	check(counter.uses == 2, "a second press uses it again (it is not one_shot)")
	for case: Array in [[56.0, true], [57.0, false], [30.0, true]]:
		thing.global_position = CENTRE + Vector2(0, case[0])
		await wait_physics_frames(2)
		var in_range: bool = controller.find_interactable() == thing
		check(in_range == case[1] and (controller.get_prompt_text() != "") == case[1],
				"%d px away: %s" % [case[0], "in range, prompt shown" if case[1] else "out of range, no prompt"])
	# Walking away removes the prompt; E then does nothing.
	var uses := counter.uses
	await hold_keys([KEY_LEFT], 30)
	check(controller.get_prompt_text() == "" and carl.global_position.distance_to(thing.global_position) > 56.0,
			"walking away removes the prompt", str(carl.global_position))
	await tap_key(KEY_E)
	check(counter.uses == uses, "out of range, E does nothing")


func _check_nearest() -> void:
	print("-- Several in range: the nearest")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var far := _add_interactable("Far", CENTRE + Vector2(0, -45))
	var near := _add_interactable("Near", CENTRE + Vector2(30, 0))
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Near", "the nearer one's prompt is shown", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(near[1].uses == 1 and far[1].uses == 0, "one press uses only the nearer one")
	(far[0] as Interactable).global_position = CENTRE + Vector2(-20, 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Far", "moved nearer, the other one is shown", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(near[1].uses == 1 and far[1].uses == 1, "and only it is used")


func _check_ties() -> void:
	print("-- Ties go to the one earlier in the scene tree")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var first := _add_interactable("First", CENTRE + Vector2(40, 0))
	var second := _add_interactable("Second", CENTRE + Vector2(-40, 0))
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: First", "at the same distance, the earlier one", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(first[1].uses == 1 and second[1].uses == 0, "one press, only the earlier one")
	_arena.move_child(second[0], 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Second", "moved earlier in the tree, the other one wins the tie", controller.get_prompt_text())
	# 0.3 px nearer is still a tie; 1 px nearer wins.
	(first[0] as Interactable).global_position = CENTRE + Vector2(39.7, 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Second", "0.3 px nearer is still a tie: the earlier one")
	(first[0] as Interactable).global_position = CENTRE + Vector2(39, 0)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: First", "1 px nearer wins")
	for i in 5:
		await wait_physics_frames(1)
		check(controller.get_prompt_text() == "E: First", "the choice is stable, tick %d" % i)


func _check_disabled_and_one_shot() -> void:
	print("-- Disabled and one_shot interactables are skipped")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var near := _add_interactable("Near", CENTRE + Vector2(20, 0))
	var other := _add_interactable("Other", CENTRE + Vector2(0, 40))
	(near[0] as Interactable).enabled = false
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Other", "a disabled one is skipped for one farther away", controller.get_prompt_text())
	check(not (near[0] as Interactable).interact(carl) and near[1].uses == 0, "interact() on a disabled one does nothing")
	await tap_key(KEY_E)
	check(near[1].uses == 0 and other[1].uses == 1, "E uses the enabled one")
	(other[0] as Interactable).enabled = false
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "", "none enabled: no prompt")
	await tap_key(KEY_E)
	check(near[1].uses == 0 and other[1].uses == 1, "and E does nothing")
	var once := _add_interactable("Once", CENTRE + Vector2(0, -20))
	(once[0] as Interactable).one_shot = true
	await wait_physics_frames(2)
	await tap_key(KEY_E)
	check(once[1].uses == 1 and not (once[0] as Interactable).enabled, "a one_shot one is used once, then turns itself off")
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "", "its prompt goes away")
	await tap_key(KEY_E)
	check(once[1].uses == 1 and not (once[0] as Interactable).interact(carl), "it can never be used again")


func _check_walls() -> void:
	print("-- Walls")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var behind := _add_interactable("Behind", CENTRE + Vector2(50, 0))
	var wall := new_wall(Rect2(CENTRE + Vector2(20, -30), Vector2(8, 60)))
	_arena.add_child(wall)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "", "a wall between Carl and it: no prompt")
	await tap_key(KEY_E)
	check(behind[1].uses == 0, "and it cannot be used through the wall")
	wall.free()
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "E: Behind", "the wall gone, it can be seen", controller.get_prompt_text())
	# A solid object's own body is not a wall between Carl and its Interactable.
	var body := new_wall(Rect2(CENTRE + Vector2(-60, -12), Vector2(24, 24)))
	_arena.add_child(body)
	var own := _add_interactable("Solid Thing", body.position, body)
	await wait_physics_frames(2)
	check(controller.find_interactable() == own[0] and controller.get_prompt_text() == "E: Solid Thing",
			"a solid object's own body does not hide its Interactable", controller.get_prompt_text())


func _check_held_and_echo() -> void:
	print("-- Held keys and key repeat")
	var carl := await _new_arena()
	var thing := _add_interactable("Thing", CENTRE + Vector2(30, 0))
	await wait_physics_frames(2)
	await hold_keys([KEY_E], 60)
	check(thing[1].uses == 1, "holding E for a second uses it once", str(thing[1].uses))
	send_key(KEY_E, true)
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	for i in 3:
		Input.parse_input_event(echo)
		Input.flush_buffered_events()
		await wait_physics_frames(2)
	send_key(KEY_E, false)
	check(thing[1].uses == 2, "a press followed by key repeats uses it once", str(thing[1].uses))
	check(carl.get_node("InteractionController").get_prompt_text() == "E: Thing", "the prompt stays")


func _check_rebinding() -> void:
	print("-- A rebound Interact key")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var thing := _add_interactable("Thing", CENTRE + Vector2(30, 0))
	await wait_physics_frames(2)
	check(settings_manager().set_binding(&"interact", KEY_Q) == "", "Interact moves to Q")
	check(controller.get_prompt_text() == "Q: Thing", "the prompt says Q at once", controller.get_prompt_text())
	await tap_key(KEY_E)
	check(thing[1].uses == 0, "E does nothing")
	await tap_key(KEY_Q)
	check(thing[1].uses == 1, "Q uses it")
	check(settings_manager().set_binding(&"interact", KEY_BRACKETLEFT) == "" and controller.get_prompt_text() == "BracketLeft: Thing",
			"any key name is shown as the key hints show it", controller.get_prompt_text())
	settings_manager().reset_to_defaults()
	check(controller.get_prompt_text() == "E: Thing", "Reset to Defaults: E again", controller.get_prompt_text())
	await tap_key(KEY_Q)
	await tap_key(KEY_E)
	check(thing[1].uses == 2, "Q does nothing, E works")


func _check_pause() -> void:
	print("-- A paused game")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var thing := _add_interactable("Thing", CENTRE + Vector2(30, 0))
	await wait_physics_frames(2)
	paused = true
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "", "paused: no prompt")
	await tap_key(KEY_E)
	check(thing[1].uses == 0, "paused: E does nothing")
	# Pressed while paused and still held on resuming: nothing.
	send_key(KEY_E, true)
	await wait_physics_frames(3)
	paused = false
	await wait_physics_frames(30)
	check(thing[1].uses == 0 and controller.get_prompt_text() == "E: Thing", "a key held through the resume uses nothing; the prompt is back")
	send_key(KEY_E, false)
	await wait_physics_frames(2)
	await tap_key(KEY_E)
	check(thing[1].uses == 1, "the next press works")


func _check_carl_down() -> void:
	print("-- Carl down")
	var carl := await _new_arena()
	var controller: InteractionController = carl.get_node("InteractionController")
	var thing := _add_interactable("Thing", CENTRE + Vector2(30, 0))
	await wait_physics_frames(2)
	carl.get_node("Hurtbox").take_hit(100)
	await wait_physics_frames(2)
	check(controller.get_prompt_text() == "" and controller.find_interactable() == null, "Carl down: no prompt, nothing to use")
	await tap_key(KEY_E)
	check(thing[1].uses == 0, "E does nothing")


## A fresh arena with Carl at CENTRE.
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


## An Interactable called `prompt_text` at `at` (a child of `parent`, the arena by default), and a
## Counter of its uses: [Interactable, Counter].
func _add_interactable(prompt_text: String, at: Vector2, parent: Node = null) -> Array:
	var thing := Node2D.new()
	thing.set_script(INTERACTABLE_SCRIPT)
	thing.name = prompt_text.to_pascal_case()
	thing.prompt_text = prompt_text
	(parent if parent != null else _arena).add_child(thing)
	thing.global_position = at
	var counter := Counter.new()
	thing.interacted.connect(counter.record)
	return [thing, counter]
