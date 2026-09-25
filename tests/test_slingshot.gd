extends "res://tests/support/game_test.gd"
## Phase 6 Slingshot checks in an empty arena (no level):
## - the three kinds of things Carl can have: innate Fists, the owned (reusable) Slingshot,
##   counted Small Health Potions; a new run owns no Slingshot; finding it owns it exactly once;
## - slots: the Slingshot can only be assigned once owned, moves between W/A/S/D, sits in one
##   slot, and shares the slots with Fists and the potion; taking it back empties its slot;
## - the pickup: labelled "Slingshot" (no quantity) with its own icon; only Carl collects it,
##   once; Donut and enemies cannot;
## - shooting: a stone flies the way Carl faces (right, up, left, down); empty slots do nothing;
##   exactly 10 damage per hit, three hits kill a 30 HP blob; the stone disappears on the hit,
##   never hits two enemies, stops at a wall (nothing behind it is hit), flies through a dying
##   enemy, and disappears after 320 px; it never hurts Carl or Donut (who has a Hurtbox since
##   Phase 8), collects no pickups and triggers no stairs;
## - cooldown: one shot per short press, one every 0.6 s (36 ticks) while held, quick taps
##   cannot fire faster, and moving the Slingshot to another key keeps its cooldown;
## - the action menu: while it is open nothing fires and stones in flight freeze; closing it
##   with a key still held fires nothing; a key released inside the menu is not stuck;
## - HUD and menu: "Slingshot" without a quantity next to "Potion x2"; shooting changes neither
##   the inventory nor the HUD, and the potion still works as before.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_slingshot.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/props/item_pickup.tscn")
const STAIRS_SCENE: PackedScene = preload("res://scenes/props/stairs.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const S := ActionSlots.SLOT_S
const D := ActionSlots.SLOT_D
## Canonical Phase 6 numbers.
const DAMAGE := 10
const COOLDOWN_TICKS := 36  # 0.6 s at 60 ticks per second
const RANGE := 320.0
const SPEED := 480.0

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_ownership_model()
	_check_slot_assignment()
	await _check_pickup()
	await _check_pickup_taken_once()
	await _check_firing_directions()
	await _check_damage_and_kill()
	await _check_projectile_collisions()
	await _check_range()
	await _check_friends_and_props_unaffected()
	await _check_cooldown()
	await _check_menu_pause()
	await _check_hud_and_menu()
	finish()


func _check_ownership_model() -> void:
	print("-- Innate Fists, the owned Slingshot, counted potions")
	var state := game_state()
	# Leave a run that owned the Slingshot behind: a new run must not inherit it.
	state.inventory.add(SLINGSHOT, 1)
	state.action_slots.assign(SLINGSHOT, W)
	state.start_new_run()
	var inventory: Inventory = state.inventory
	check(not inventory.has(SLINGSHOT) and state.action_slots.find_slot(SLINGSHOT) == &"",
			"a new run does not own the Slingshot, and no slot holds it")
	check(inventory.is_innate(FISTS) and inventory.has(FISTS) and inventory.get_quantity(FISTS) == 0,
			"Fists are innate: always there, with no quantity")
	check(SLINGSHOT.id == &"slingshot" and SLINGSHOT.display_name == "Slingshot" and SLINGSHOT.assignable
			and not SLINGSHOT.consumable and SLINGSHOT.performer_scene != null and SLINGSHOT.icon != null,
			"the Slingshot: id 'slingshot', assignable, not consumable, with a performer and an icon")
	check(POTION.consumable and not FISTS.consumable, "the potion is still the consumable")
	var launcher := SLINGSHOT.performer_scene.instantiate() as ProjectileLauncher
	var stone := launcher.projectile_scene.instantiate() as Projectile if launcher != null else null
	check(launcher != null and is_equal_approx(launcher.cooldown, 0.6) and stone != null and stone.damage == DAMAGE
			and is_equal_approx(stone.speed, SPEED) and is_equal_approx(stone.max_distance, RANGE)
			and stone.target_layers == 32 and stone.blocking_layers == 1,
			"its launcher: 0.6 s cooldown; its stone: 10 damage, 480 px/s, 320 px, hits enemy_hurtbox, stopped by world")
	if launcher != null:
		launcher.free()
	if stone != null:
		stone.free()

	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	var empty_snapshot := inventory.get_snapshot()
	inventory.add(SLINGSHOT, 1)
	check(inventory.has(SLINGSHOT) and inventory.get_quantity(SLINGSHOT) == 0 and changes[0] == 1,
			"finding the Slingshot owns it; it has no quantity")
	var snapshot := inventory.get_snapshot()
	check(snapshot["items"].has(SLINGSHOT.id) and not snapshot["quantities"].has(SLINGSHOT.id),
			"it is kept as an owned item, never as a quantity")
	inventory.add(SLINGSHOT, 1)
	inventory.add(SLINGSHOT, 3)
	check(changes[0] == 1 and inventory.get_actions().count(SLINGSHOT) == 1,
			"finding it again changes nothing: it is owned once", "%d changes" % changes[0])
	check(not inventory.remove(SLINGSHOT, 1) and inventory.has(SLINGSHOT) and changes[0] == 1,
			"it cannot be used up or removed like a consumable")
	inventory.add(POTION, 2)
	check(inventory.get_quantity(POTION) == 2 and inventory.remove(POTION, 1) and inventory.get_quantity(POTION) == 1,
			"potions are still counted and used one at a time")
	check(inventory.get_label(SLINGSHOT) == "Slingshot" and inventory.get_label(SLINGSHOT, true) == "Slingshot"
			and inventory.get_label(FISTS) == "Fists" and inventory.get_label(POTION) == "Small Health Potion x1",
			"labels: no quantity for the Slingshot or Fists, a quantity for the potion",
			"%s / %s / %s" % [inventory.get_label(SLINGSHOT), inventory.get_label(FISTS), inventory.get_label(POTION)])
	check(inventory.get_actions() == [FISTS, SLINGSHOT, POTION], "Carl's list: innate first, then items in the order found")
	inventory.restore_snapshot(empty_snapshot)
	check(not inventory.has(SLINGSHOT) and inventory.get_actions() == [FISTS],
			"restoring an earlier snapshot takes the Slingshot back")
	inventory.restore_snapshot(snapshot)
	inventory.restore_snapshot(snapshot)
	check(inventory.has(SLINGSHOT) and inventory.get_actions().count(SLINGSHOT) == 1,
			"restoring a snapshot that has it, twice, owns it exactly once")
	state.start_new_run()
	check(not inventory.has(SLINGSHOT), "a new run clears it again")


func _check_slot_assignment() -> void:
	print("-- Slots and the Slingshot")
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	var slots := ActionSlots.new(inventory)
	slots.assign(FISTS, D)
	var entry_snapshot := inventory.get_snapshot()
	check(not slots.assign(SLINGSHOT, W) and slots.get_action(W) == null, "the Slingshot cannot be assigned before Carl owns it")
	inventory.add(SLINGSHOT, 1)
	check(slots.assign(SLINGSHOT, W) and slots.get_action(W) == SLINGSHOT, "once owned, it can go on W")
	for slot: StringName in [A, S, W]:
		slots.assign(SLINGSHOT, slot)
		check(slots.find_slot(SLINGSHOT) == slot and _slots_holding(slots, SLINGSHOT) == 1 and slots.get_action(D) == FISTS,
				"it moves to %s and is in one slot only, next to Fists on D" % ActionSlots.KEY_LABELS[slot])
	slots.assign(SLINGSHOT, D)
	check(slots.get_action(D) == SLINGSHOT and slots.find_slot(FISTS) == &"" and _slots_holding(slots, SLINGSHOT) == 1,
			"it can go on D too (Fists, replaced, lose their slot as always)")
	slots.assign(FISTS, D)
	slots.assign(SLINGSHOT, W)
	inventory.add(POTION, 1)
	slots.assign(POTION, A)
	check(slots.get_action(W) == SLINGSHOT and slots.get_action(A) == POTION and slots.get_action(S) == null
			and slots.get_action(D) == FISTS, "W = Slingshot, A = potion, S empty, D = Fists at the same time")
	check(slots.get_display_name(W, true) == "Slingshot" and slots.get_display_name(A, true) == "Potion x1",
			"slot names: 'Slingshot' without a quantity, 'Potion x1' with one")
	inventory.restore_snapshot(entry_snapshot)
	check(slots.get_action(W) == null and slots.get_action(D) == FISTS,
			"when a retry takes the Slingshot back, its slot empties and Fists stay")


func _check_pickup() -> void:
	print("-- The Slingshot pickup")
	var carl := _new_arena_with_carl()
	var inventory: Inventory = game_state().inventory
	var pickup := _spawn_pickup(SLINGSHOT, Vector2(80, 0))
	var potion_pickup := _spawn_pickup(POTION, Vector2(0, 200), 2)
	check(pickup.get_node("Label").text == "Slingshot", "it is labelled 'Slingshot', with no quantity", pickup.get_node("Label").text)
	check(pickup.get_node("Marker/Icon").visible and pickup.get_node("Marker/Icon").texture == SLINGSHOT.icon
			and not pickup.get_node("Marker/DefaultGem").visible, "it shows the Slingshot icon instead of the gem")
	check(potion_pickup.get_node("Label").text == "Potion x2" and potion_pickup.get_node("Marker/DefaultGem").visible
			and not potion_pickup.get_node("Marker/Icon").visible, "a potion pickup still shows 'Potion x2' and the pink gem")
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)

	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = pickup.position
	_arena.add_child(donut)
	var blob := _spawn_blob(pickup.position + Vector2(0, 6))
	await wait_seconds(0.5)
	check(is_instance_valid(pickup) and not inventory.has(SLINGSHOT) and changes[0] == 0,
			"Donut and an enemy standing on it do not take it")
	blob.queue_free()
	await wait_physics_frames(2)

	await hold_keys([KEY_RIGHT], 40)
	check(inventory.has(SLINGSHOT) and changes[0] == 1, "Carl walking over it owns the Slingshot")
	await wait_physics_frames(2)
	check(not is_instance_valid(pickup), "the pickup disappears")
	await hold_keys([KEY_LEFT], 40)
	await hold_keys([KEY_RIGHT], 40)
	check(changes[0] == 1 and inventory.get_actions().count(SLINGSHOT) == 1, "walking over the spot again gives nothing more")


func _check_pickup_taken_once() -> void:
	print("-- One Slingshot pickup, two collectors, and a second pickup")
	var carl := _new_arena_with_carl()
	var other_carl: CharacterBody2D = CARL_SCENE.instantiate()
	var other_inventory := Inventory.new()
	other_inventory.reset([FISTS])
	other_carl.inventory = other_inventory
	other_carl.position = Vector2(-60, 40)
	_arena.add_child(other_carl)
	var pickup := _spawn_pickup(SLINGSHOT, Vector2(0, 60))
	await wait_physics_frames(2)
	carl.teleport_to(pickup.position + Vector2(-4, 0))
	other_carl.teleport_to(pickup.position + Vector2(4, 0))
	await wait_physics_frames(3)
	var owners := [game_state().inventory.has(SLINGSHOT), other_inventory.has(SLINGSHOT)].count(true)
	check(owners == 1 and not is_instance_valid(pickup), "two collectors touching it at once: only one gets it", "%d owners" % owners)
	# A second Slingshot pickup for someone who already owns one still gives only one.
	other_carl.queue_free()
	var inventory: Inventory = game_state().inventory
	inventory.add(SLINGSHOT, 1)
	var second := _spawn_pickup(SLINGSHOT, carl.position + Vector2(0, 50))
	await wait_physics_frames(2)
	carl.teleport_to(second.position)
	await wait_physics_frames(3)
	check(inventory.get_actions().count(SLINGSHOT) == 1, "collecting a second Slingshot never makes two")


func _check_firing_directions() -> void:
	print("-- The stone flies the way Carl faces")
	var carl := _new_arena_with_slingshot_on_w()
	var fired := _record_shots(carl)
	await wait_physics_frames(2)
	for step: Array in [[KEY_RIGHT, Vector2.RIGHT], [KEY_UP, Vector2.UP], [KEY_LEFT, Vector2.LEFT], [KEY_DOWN, Vector2.DOWN]]:
		await tap_key(step[0])
		var shots_before := fired.size()
		var carl_position := carl.global_position
		await tap_key(KEY_W)
		check(fired.size() == shots_before + 1, "one tap of W fires one stone")
		if fired.size() == shots_before + 1:
			var stone: Projectile = fired[-1]
			var launched_at: Vector2 = stone.get_meta(&"launched_at")
			await wait_physics_frames(5)
			var moved := stone.global_position - launched_at
			check(stone.direction == step[1] and moved.normalized().is_equal_approx(step[1]) and moved.length() > 30.0,
					"facing %s, the stone flies %s" % [step[1], step[1]], "moved %s" % moved)
			check(launched_at.distance_to(carl_position) < 4.0, "the stone is launched from Carl", str(launched_at - carl_position))
		await wait_seconds(0.7)

	print("-- Empty slots do nothing")
	var shots_before_empty_slots := fired.size()
	await hold_keys([KEY_A], 30)
	await hold_keys([KEY_S], 30)
	check(fired.size() == shots_before_empty_slots and _projectiles().is_empty(), "A and S (empty) fire nothing")


func _check_damage_and_kill() -> void:
	print("-- 10 damage per hit; three hits kill a Gelatinous Blob")
	var carl := _new_arena_with_slingshot_on_w()
	var blob := _spawn_blob(Vector2(150, 0))
	# A longer fade keeps the dead blob around long enough to check it.
	blob.death_fade_time = 3.0
	check(blob.health.max_health == 30 and blob.health.current_health == 30, "the blob has its usual 30 HP")
	var damage_taken := []
	blob.health.damaged.connect(func(amount: int) -> void: damage_taken.append(amount))
	var died := [0]
	blob.health.died.connect(func() -> void: died[0] += 1)
	var fired := _record_shots(carl)
	await tap_key(KEY_RIGHT)
	for shot in 3:
		await tap_key(KEY_W)
		if fired.size() != shot + 1:
			check(false, "shot %d was fired" % (shot + 1))
			return
		var stone: Projectile = fired[shot]
		var stops := _record_stop(stone)
		# Wait until the blob is hit, then check the stone at that very moment.
		for i in 60:
			if damage_taken.size() > shot:
				break
			await physics_frame
		check(damage_taken.size() == shot + 1 and damage_taken[shot] == DAMAGE, "hit %d deals exactly 10" % (shot + 1), str(damage_taken))
		# The damage became visible at the start of the tick after the hit: by then the stone
		# must already be gone.
		check(stops.size() == 1 and stops[0][0] == blob.get_node("Hurtbox") and not is_instance_valid(stone),
				"hit %d: the stone stops on the blob's Hurtbox and is gone at once" % (shot + 1))
		await wait_seconds(0.6)
	check(blob.health.is_dead() and died[0] == 1 and damage_taken == [DAMAGE, DAMAGE, DAMAGE],
			"three hits kill the 30 HP blob (died once)", str(damage_taken))
	check(carl.health.current_health == 100, "Carl is unhurt")


func _check_projectile_collisions() -> void:
	print("-- One target per stone; walls stop it")
	var carl := _new_arena_with_slingshot_on_w()
	var fired := _record_shots(carl)
	var near_blob := _spawn_blob(Vector2(100, 0))
	var far_blob := _spawn_blob(Vector2(140, 0))
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_W)
	await wait_seconds(0.5)
	check(near_blob.health.current_health == 20 and far_blob.health.current_health == 30 and _projectiles().is_empty(),
			"two blobs in a row: only the first is hit, and the stone is gone",
			"%d / %d HP" % [near_blob.health.current_health, far_blob.health.current_health])

	# A dying enemy (fading out) is flown through; the live one behind it is hit.
	near_blob.death_fade_time = 3.0
	near_blob.health.take_damage(100)
	await wait_seconds(0.6)
	await tap_key(KEY_W)
	await wait_seconds(0.5)
	check(is_instance_valid(near_blob) and far_blob.health.current_health == 20,
			"a stone flies through a dying blob and hits the live one behind it", "%d HP" % far_blob.health.current_health)

	# An enemy that moves onto a stone in flight (as a chasing blob does) is still hit, even
	# though the stone's next step then starts inside its Hurtbox.
	carl = _new_arena_with_slingshot_on_w()
	fired = _record_shots(carl)
	var moving_blob := _spawn_blob(Vector2(0, 150))
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_W)
	await wait_physics_frames(2)
	if fired.size() == 1 and is_instance_valid(fired[0]):
		moving_blob.global_position = (fired[0] as Projectile).global_position + Vector2(5, 0)
		moving_blob.reset_physics_interpolation()
	await wait_seconds(0.8)
	check(fired.size() == 1 and moving_blob.health.current_health == 20,
			"a blob that moves onto a flying stone is hit", "blob HP %d" % moving_blob.health.current_health)

	carl = _new_arena_with_slingshot_on_w()
	fired = _record_shots(carl)
	var wall := _spawn_wall(Vector2(100, 0), Vector2(20, 200))
	var blob_behind := _spawn_blob(Vector2(160, 0))
	await tap_key(KEY_RIGHT)
	var face_x := wall.global_position.x - 10.0
	await tap_key(KEY_W)
	if fired.size() != 1:
		check(false, "a stone was fired at the wall")
		return
	var stops := _record_stop(fired[0])
	await wait_seconds(1.0)
	check(stops.size() == 1 and stops[0][0] == wall and absf(stops[0][1].x - face_x) < 0.5,
			"the stone stops at the wall's face", str(stops))
	check(blob_behind.health.current_health == 30 and _projectiles().is_empty(), "the blob behind the wall is not hit")


func _check_range() -> void:
	print("-- The stone disappears after 320 px")
	var carl := _new_arena_with_slingshot_on_w()
	var fired := _record_shots(carl)
	await tap_key(KEY_RIGHT)
	var start_x := carl.global_position.x
	await tap_key(KEY_W)
	if fired.size() != 1:
		check(false, "a stone was fired")
		return
	var stone: Projectile = fired[0]
	var stops := _record_stop(stone)
	# The stone already flew its first step in the tick it was fired.
	var ticks := 1
	var x_at_tick := {}
	while is_instance_valid(stone) and ticks < 120:
		x_at_tick[ticks] = stone.global_position.x
		await physics_frame
		ticks += 1
	check(stops.size() == 1 and stops[0][0] == null, "with nothing in the way it stops by itself")
	check(stops.size() == 1 and absf(stops[0][1].x - start_x - RANGE) < 0.5, "it stops 320 px from Carl",
			str(stops[0][1].x - start_x) if stops.size() == 1 else "")
	check(ticks == 40, "it flies for 40 ticks (2/3 s), then is removed", "%d ticks" % ticks)
	if x_at_tick.has(5) and x_at_tick.has(15):
		check_near("speed: pixels flown in 10 ticks (480 px/s = 8 px per tick)", x_at_tick[15] - x_at_tick[5], 80.0, 0.01)


func _check_friends_and_props_unaffected() -> void:
	print("-- Carl, Donut, pickups and stairs are left alone")
	var carl := _new_arena_with_slingshot_on_w()
	var fired := _record_shots(carl)
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = Vector2(50, 0)
	_arena.add_child(donut)
	# Another player (standing in for Carl's own Hurtbox layer) in the line of fire.
	var other_carl: CharacterBody2D = CARL_SCENE.instantiate()
	other_carl.position = Vector2(100, 0)
	_arena.add_child(other_carl)
	other_carl.set_physics_process(false)
	var pickup := _spawn_pickup(POTION, Vector2(150, 0), 2)
	var stairs: Area2D = STAIRS_SCENE.instantiate()
	stairs.destination_scene_path = "res://scenes/levels/floor_01.tscn"
	stairs.position = Vector2(210, 0)
	_arena.add_child(stairs)
	var blob := _spawn_blob(Vector2(275, 0))
	var scene_before := current_scene
	await wait_physics_frames(3)

	await tap_key(KEY_RIGHT)
	await tap_key(KEY_W)
	await wait_seconds(1.0)
	check(fired.size() == 1 and blob.health.current_health == 20,
			"the stone flies past Donut, a player, a pickup and stairs and hits the blob behind them",
			"blob HP %d" % blob.health.current_health)
	check(carl.health.current_health == 100 and other_carl.health.current_health == 100, "it never hurts Carl (player_hurtbox)")
	# Since Phase 8 Donut has a Hurtbox (on player_hurtbox, like Carl's) right in the line of fire.
	check(donut.get_node_or_null("Hurtbox") != null and donut.health.current_health == 60 and donut.health.max_health == 60,
			"it never hurts Donut either: she keeps 60 / 60 HP", "Donut HP %d" % donut.health.current_health)
	check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and game_state().inventory.get_quantity(POTION) == 0,
			"the pickup is not collected")
	check(current_scene == scene_before and not stairs._is_transitioning, "the stairs are not triggered")

	# Point blank: the blob pressed against Carl is still hit.
	carl.teleport_to(blob.global_position + Vector2(-26, 0))
	await wait_seconds(0.6)
	await tap_key(KEY_W)
	await wait_physics_frames(3)
	check(blob.health.current_health == 10, "a blob right against Carl is hit", "blob HP %d" % blob.health.current_health)


func _check_cooldown() -> void:
	print("-- Cooldown: 0.6 s")
	var carl := _new_arena_with_slingshot_on_w()
	var fire_ticks := []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(
			func(_stone: Projectile) -> void: fire_ticks.append(Engine.get_physics_frames()))
	await tap_key(KEY_RIGHT)
	# A quick human key press lasts about a tenth of a second: 6 physics ticks.
	await hold_keys([KEY_W], 6)
	check(fire_ticks.size() == 1, "a short press fires exactly one stone", "%d stones" % fire_ticks.size())
	await wait_seconds(0.7)

	fire_ticks.clear()
	await hold_keys([KEY_W], 90)  # 1.5 seconds
	var gaps := []
	for i in range(1, fire_ticks.size()):
		gaps.append(fire_ticks[i] - fire_ticks[i - 1])
	check(fire_ticks.size() == 3 and gaps.all(func(gap: int) -> bool: return gap == COOLDOWN_TICKS),
			"holding W for 1.5 s fires 3 stones, exactly 0.6 s (36 ticks) apart", "%d stones, gaps %s" % [fire_ticks.size(), gaps])
	await wait_seconds(0.7)

	fire_ticks.clear()
	for i in 5:
		await tap_key(KEY_W)
		await wait_physics_frames(3)
	check(fire_ticks.size() == 1, "five quick taps within 0.4 s fire only once", "%d stones" % fire_ticks.size())
	await wait_seconds(0.7)

	fire_ticks.clear()
	await tap_key(KEY_W)
	game_state().action_slots.assign(SLINGSHOT, A)
	await hold_keys([KEY_A], 10)
	check(fire_ticks.size() == 1, "moving the Slingshot to A right after a shot does not skip its cooldown")
	await wait_seconds(0.6)
	await tap_key(KEY_A)
	check(fire_ticks.size() == 2, "after the cooldown, A fires")
	check(game_state().inventory.has(SLINGSHOT) and game_state().inventory.get_actions() == [FISTS, SLINGSHOT],
			"after all those shots Carl still owns the Slingshot: nothing is used up")


func _check_menu_pause() -> void:
	print("-- The action menu pauses shooting")
	var carl := _new_arena_with_slingshot_on_w()
	var menu := _add_menu()
	var fired := _record_shots(carl)
	var blob := _spawn_blob(Vector2(250, 0), 1000)
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_W)
	await wait_physics_frames(3)
	var stone: Projectile = fired[0] if fired.size() == 1 else null
	await tap_key(KEY_SPACE)
	check(menu.is_open() and paused, "Space opens the menu")
	if stone == null or not is_instance_valid(stone):
		check(false, "a stone was in flight when the menu opened")
		return
	var frozen_at := stone.global_position
	# Select the Slingshot, so pressing W in the menu keeps it on W instead of moving Fists there.
	await tap_key(KEY_DOWN)
	await hold_keys([KEY_W], 20)
	await wait_seconds(0.5)
	var still_frozen := is_instance_valid(stone) and stone.global_position == frozen_at
	check(still_frozen and blob.health.current_health == 1000, "a stone in flight freezes while the menu is open",
			str(stone.global_position - frozen_at) if is_instance_valid(stone) else "the stone flew on and is gone")
	check(fired.size() == 1 and game_state().action_slots.get_action(W) == SLINGSHOT, "W in the menu fires nothing")
	await tap_key(KEY_SPACE)
	await wait_seconds(0.5)
	check(not paused and blob.health.current_health == 990 and not is_instance_valid(stone),
			"after closing, the stone flies on and hits")

	# A slot key held when the menu closes fires nothing until it is pressed again.
	await wait_seconds(0.7)
	await tap_key(KEY_SPACE)
	send_key(KEY_W, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	await wait_seconds(0.8)
	check(fired.size() == 1 and not paused, "W held while the menu closes gives no free shot")
	send_key(KEY_W, false)
	await wait_physics_frames(2)
	await tap_key(KEY_W)
	check(fired.size() == 2, "pressing W again afterwards fires normally")

	# W held while firing, the menu opened and closed with W released inside: not stuck.
	await wait_seconds(0.7)
	send_key(KEY_W, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	send_key(KEY_W, false)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	await wait_seconds(1.5)
	check(fired.size() == 3, "a key released inside the menu does not keep firing", "%d stones" % fired.size())

	# Opening and closing alone never fires.
	await tap_key(KEY_SPACE)
	await tap_key(KEY_ESCAPE)
	await wait_seconds(0.8)
	check(fired.size() == 3, "opening and closing the menu never fires")


func _check_hud_and_menu() -> void:
	print("-- HUD and menu")
	var carl := _new_arena_with_carl()
	var state := game_state()
	var menu := _add_menu()
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_action_slots(state.action_slots, state.inventory)
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)"], "before the pickup the menu lists only Fists", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_SPACE)

	carl.collect_item(SLINGSHOT, 1)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)", "Slingshot   (no slot)"],
			"after the pickup the menu lists 'Slingshot', with no quantity", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_DOWN)
	check(menu.get_node("%DetailsLabel").text == SLINGSHOT.description, "the menu describes the Slingshot")
	await tap_key(KEY_W)
	check(_rows(menu, "%ActionList") == ["Fists   (on D)", "> Slingshot   (on W)"]
			and _rows(menu, "%SlotList") == ["W   Slingshot", "A   —", "S   —", "D   Fists"],
			"W assigns it", "%s %s" % [_rows(menu, "%ActionList"), _rows(menu, "%SlotList")])
	check(slot_bar.text == "W: Slingshot   A: —   S: —   D: Fists", "the HUD shows W: Slingshot", slot_bar.text)
	await tap_key(KEY_SPACE)

	carl.collect_item(POTION, 2)
	await tap_key(KEY_SPACE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_A)
	check(_rows(menu, "%ActionList") == ["Fists   (on D)", "Slingshot   (on W)", "> Small Health Potion x2   (on A)"],
			"Fists, the Slingshot and the potion each have a slot", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_SPACE)
	check(slot_bar.text == "W: Slingshot   A: Potion x2   S: —   D: Fists", "the HUD: W: Slingshot   A: Potion x2", slot_bar.text)

	var changes := [0]
	state.inventory.changed.connect(func() -> void: changes[0] += 1)
	await tap_key(KEY_RIGHT)
	await hold_keys([KEY_W], 80)
	await wait_seconds(0.8)
	check(changes[0] == 0 and state.inventory.has(SLINGSHOT) and state.inventory.get_actions() == [FISTS, SLINGSHOT, POTION],
			"three shots change nothing in the inventory")
	check(slot_bar.text == "W: Slingshot   A: Potion x2   S: —   D: Fists", "the HUD is unchanged after shooting", slot_bar.text)

	carl.health.take_damage(40)
	await tap_key(KEY_A)
	check(carl.health.current_health == 90 and state.inventory.get_quantity(POTION) == 1,
			"the potion on A still heals 30 and uses one", "HP %d" % carl.health.current_health)
	check(slot_bar.text == "W: Slingshot   A: Potion x1   S: —   D: Fists", "the HUD shows Potion x1, Slingshot unchanged", slot_bar.text)


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


## As _new_arena_with_carl(), with the Slingshot owned and on W (Fists stay on D).
func _new_arena_with_slingshot_on_w() -> CharacterBody2D:
	var carl := _new_arena_with_carl()
	carl.collect_item(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, W)
	return carl


## Collects every stone Carl's Slingshot fires (with its launch position in the "launched_at"
## meta). Returns the array it fills.
func _record_shots(carl: Node) -> Array:
	var fired := []
	var launcher: ProjectileLauncher = carl.get_action_performer(SLINGSHOT)
	launcher.fired.connect(func(stone: Projectile) -> void:
		stone.set_meta(&"launched_at", stone.global_position)
		fired.append(stone))
	return fired


## Records where `stone` stops and what it hit, as [collider, position]. Returns the array it fills.
func _record_stop(stone: Projectile) -> Array:
	var stops := []
	stone.stopped.connect(func(collider: Object) -> void: stops.append([collider, stone.global_position]))
	return stops


func _projectiles() -> Array:
	return _arena.get_children().filter(func(node: Node) -> bool: return node is Projectile and not node.is_queued_for_deletion())


## A blob that never moves (its detection range is 0).
func _spawn_blob(at: Vector2, max_health: int = 30) -> CharacterBody2D:
	var blob: CharacterBody2D = BLOB_SCENE.instantiate()
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	blob.get_node("Health").max_health = max_health
	blob.position = at
	_arena.add_child(blob)
	return blob


## A solid block on the "world" layer, like a wall tile.
func _spawn_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	wall.position = at
	_arena.add_child(wall)
	return wall


func _spawn_pickup(item: ActionDefinition, at: Vector2, quantity: int = 1) -> Area2D:
	var pickup: Area2D = PICKUP_SCENE.instantiate()
	pickup.item = item
	pickup.quantity = quantity
	pickup.position = at
	_arena.add_child(pickup)
	return pickup


func _add_menu() -> CanvasLayer:
	var menu: CanvasLayer = MENU_SCENE.instantiate()
	_arena.add_child(menu)
	menu.setup(game_state().inventory, game_state().action_slots)
	return menu


func _slots_holding(slots: ActionSlots, action: ActionDefinition) -> int:
	return ActionSlots.SLOTS.filter(func(slot: StringName) -> bool:
		var held := slots.get_action(slot)
		return held != null and held.id == action.id).size()


## The texts of the rows in one of the menu's lists.
func _rows(menu: CanvasLayer, list_path: String) -> Array:
	return menu.get_node(list_path).get_children().map(func(row: Label) -> String: return row.text)
