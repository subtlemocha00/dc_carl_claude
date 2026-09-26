extends "res://tests/support/game_test.gd"
## Phase 9 Baseball Bat and knockback checks in arenas (no level):
## - ownership: a new run owns no Bat; its data (id baseball_bat, reusable, icon, a MeleeAttack
##   with 20 damage, 0.75 s, 28 px circle 36 px ahead = 64 px reach, walls block it, 80 px of
##   knockback in 0.3 s); owned once, never used up, labelled "Baseball Bat" with no quantity;
##   snapshots; a new run clears it;
## - slots: not assignable before it is owned; then on any of W/A/S/D, one slot at a time, next to
##   Fists, the Slingshot and the potion; taking it back (a retry) empties its slot;
## - the pickup: "Baseball Bat" with its icon; Donut and an enemy standing on it do not take it;
##   Carl walking over it owns it once; one pickup never gives it twice, even to two collectors;
## - the swing: the way Carl faces (right, up, left, down), never behind him; exactly 20 damage,
##   two hits kill a 30 HP blob, which dies normally and is not pushed by the killing hit; one
##   swing per short press, one every 45 ticks while held, taps cannot swing faster; never hurts
##   Carl or Donut; never through a wall;
## - knockback: away from Carl, visible at once, exactly 80 px unobstructed in 18 ticks, even for
##   an enemy that is chasing Carl (pursuit does not fight it); stopped by a wall without
##   overlapping or crossing it; it always ends; afterwards a Gelatinous Blob walks back to Carl
##   along the navigation mesh and touches him, and a Spitting Blob moves and spits again;
## - the Spitting Blob: not moving by itself and not spitting while pushed; its next glob comes
##   exactly one cooldown after the previous one (no burst, no extra glob, no reset);
## - death: an enemy killed while being pushed stops at once and never moves or attacks again;
## - regressions: Fists (10, 0.4 s, no knockback), Slingshot stones (10, no knockback), Donut's
##   Scratch (10, 1.0 s, no knockback) and spit globs (10) are unchanged; enemy touches never
##   push Carl; Carl and Donut have no KnockbackReceiver;
## - pause: the menu blocks swings, freezes a push in progress (which then finishes the same
##   80 px), and closing it with S held gives no free swing; the enemy chases again afterwards.
##   A tree pause (what GAME OVER uses) freezes a push too;
## - HUD and menu: "S: Baseball Bat" and "Baseball Bat   (on S)", unchanged by swinging.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_baseball_bat.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/enemies/spitting_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/props/item_pickup.tscn")
const GLOB_SCENE: PackedScene = preload("res://scenes/projectiles/spit_glob.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const S := ActionSlots.SLOT_S
const D := ActionSlots.SLOT_D
## Canonical Phase 9 numbers.
const DAMAGE := 20
const COOLDOWN_TICKS := 45  # 0.75 s at 60 ticks per second
const KNOCKBACK_DISTANCE := 80.0
const KNOCKBACK_TICKS := 18  # 0.3 s
const SPIT_COOLDOWN_TICKS := 90

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_ownership_model()
	_check_slot_assignment()
	await _check_pickup()
	await _check_pickup_taken_once()
	await _check_swing_directions()
	await _check_damage_kill_and_death()
	await _check_cooldown()
	await _check_friends_unhurt()
	await _check_walls_block_the_swing()
	await _check_knockback_unobstructed()
	await _check_knockback_against_a_wall()
	await _check_death_during_knockback()
	await _check_blob_resumes_navigation()
	await _check_spitting_blob()
	await _check_spitting_blob_resumes_navigation()
	await _check_other_attacks_unchanged()
	await _check_menu_and_game_over_pause()
	await _check_hud_and_menu()
	finish()


func _check_ownership_model() -> void:
	print("-- The Baseball Bat: an owned, reusable item")
	var state := game_state()
	# Leave a run that owned the Bat behind: a new run must not inherit it.
	state.inventory.add(BAT, 1)
	state.action_slots.assign(BAT, S)
	state.start_new_run()
	var inventory: Inventory = state.inventory
	check(not inventory.has(BAT) and state.action_slots.find_slot(BAT) == &"" and state.action_slots.get_action(D) == FISTS,
			"a new run does not own the Bat and no slot holds it; D = Fists")
	check(BAT.id == &"baseball_bat" and BAT.display_name == "Baseball Bat" and BAT.get_short_name() == "Baseball Bat"
			and BAT.assignable and not BAT.consumable and BAT.icon != null and BAT.icon != SLINGSHOT.icon,
			"its data: id 'baseball_bat', 'Baseball Bat', assignable, not consumable, with its own icon")
	var swing := BAT.performer_scene.instantiate() as MeleeAttack
	check(swing != null, "its performer is a MeleeAttack, like Fists")
	if swing != null:
		check(swing.damage == DAMAGE and is_equal_approx(swing.cooldown, 0.75) and is_equal_approx(swing.reach, 36.0)
				and is_equal_approx(swing.hit_radius, 28.0) and is_equal_approx(swing.reach + swing.hit_radius, 64.0)
				and swing.target_layers == 32 and swing.blocking_layers == 1 and swing.max_targets == 0,
				"20 damage, 0.75 s, a 28 px circle 36 px ahead (reaching 64 px), enemy_hurtbox only, blocked by world")
		check(is_equal_approx(swing.knockback_distance, KNOCKBACK_DISTANCE) and is_equal_approx(swing.knockback_duration, 0.3),
				"it knocks back 80 px over 0.3 s")
		swing.free()

	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	var empty_snapshot := inventory.get_snapshot()
	inventory.add(BAT, 1)
	check(inventory.has(BAT) and inventory.get_quantity(BAT) == 0 and changes[0] == 1, "finding it owns it, with no quantity")
	inventory.add(BAT, 1)
	inventory.add(BAT, 5)
	check(changes[0] == 1 and inventory.get_actions().count(BAT) == 1, "finding it again changes nothing")
	check(not inventory.remove(BAT, 1) and inventory.has(BAT), "it can never be used up or removed like a consumable")
	var snapshot := inventory.get_snapshot()
	check(snapshot["items"].has(BAT.id) and not snapshot["quantities"].has(BAT.id), "a snapshot keeps it as owned, never as a quantity")
	check(inventory.get_label(BAT) == "Baseball Bat" and inventory.get_label(BAT, true) == "Baseball Bat",
			"its label is 'Baseball Bat', never 'Baseball Bat x1'", inventory.get_label(BAT))
	inventory.add(SLINGSHOT, 1)
	inventory.add(POTION, 1)
	check(inventory.get_actions() == [FISTS, BAT, SLINGSHOT, POTION], "Carl's list: Fists, then items in the order found")
	inventory.restore_snapshot(empty_snapshot)
	check(not inventory.has(BAT), "restoring an earlier snapshot takes it back")
	inventory.restore_snapshot(snapshot)
	inventory.restore_snapshot(snapshot)
	check(inventory.get_actions().count(BAT) == 1, "restoring a snapshot that has it, twice, owns it once")
	state.start_new_run()
	check(not inventory.has(BAT), "a new run clears it again")


func _check_slot_assignment() -> void:
	print("-- Slots and the Bat")
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	var slots := ActionSlots.new(inventory)
	slots.assign(FISTS, D)
	var entry_snapshot := inventory.get_snapshot()
	check(not slots.assign(BAT, S) and slots.get_action(S) == null, "the Bat cannot be assigned before Carl owns it")
	inventory.add(BAT, 1)
	for slot: StringName in [W, A, S, D]:
		check(slots.assign(BAT, slot) and slots.find_slot(BAT) == slot and _slots_holding(slots, BAT) == 1,
				"once owned it can go on %s, and is in one slot only" % ActionSlots.SLOT_NAMES[slot])
	slots.assign(FISTS, D)
	inventory.add(SLINGSHOT, 1)
	inventory.add(POTION, 1)
	slots.assign(SLINGSHOT, W)
	slots.assign(POTION, A)
	slots.assign(BAT, S)
	check(slots.get_action(W) == SLINGSHOT and slots.get_action(A) == POTION and slots.get_action(S) == BAT and slots.get_action(D) == FISTS,
			"W = Slingshot, A = potion, S = Baseball Bat, D = Fists at the same time")
	check(slots.get_display_name(S, true) == "Baseball Bat" and slots.get_display_name(A, true) == "Potion x1",
			"slot names: 'Baseball Bat' without a quantity")
	slots.assign(BAT, W)
	check(slots.get_action(W) == BAT and slots.get_action(S) == null and slots.find_slot(SLINGSHOT) == &"",
			"moving it to W empties S (and W's Slingshot loses its slot, as always)")
	inventory.restore_snapshot(entry_snapshot)
	check(slots.find_slot(BAT) == &"" and slots.get_action(W) == null and slots.get_action(D) == FISTS,
			"when a retry takes the Bat back, its slot empties and Fists stay")


func _check_pickup() -> void:
	print("-- The Baseball Bat pickup")
	var carl := _new_arena_with_carl()
	var inventory: Inventory = game_state().inventory
	var pickup := _spawn_pickup(BAT, Vector2(80, 0))
	check(pickup.get_node("Label").text == "Baseball Bat", "it is labelled 'Baseball Bat', with no quantity", pickup.get_node("Label").text)
	check(pickup.get_node("Marker/Icon").visible and pickup.get_node("Marker/Icon").texture == BAT.icon
			and not pickup.get_node("Marker/DefaultGem").visible, "it shows the Bat icon, not the gem or the Slingshot")
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = pickup.position
	_arena.add_child(donut)
	var blob := _spawn_blob(pickup.position + Vector2(0, 6))
	var spitter := _spawn_spitter(pickup.position + Vector2(0, -6))
	await wait_seconds(0.5)
	check(is_instance_valid(pickup) and not inventory.has(BAT) and changes[0] == 0,
			"Donut and two enemies standing on it do not take it")
	blob.queue_free()
	spitter.queue_free()
	await wait_physics_frames(2)
	await hold_keys([KEY_RIGHT], 40)
	check(inventory.has(BAT) and changes[0] == 1, "Carl walking over it owns the Bat")
	await wait_physics_frames(2)
	check(not is_instance_valid(pickup), "the pickup disappears")
	await hold_keys([KEY_LEFT], 40)
	await hold_keys([KEY_RIGHT], 40)
	check(changes[0] == 1 and inventory.get_actions().count(BAT) == 1, "walking over the spot again gives nothing more")


func _check_pickup_taken_once() -> void:
	print("-- One Bat pickup, two collectors")
	var carl := _new_arena_with_carl()
	var other_carl: CharacterBody2D = CARL_SCENE.instantiate()
	var other_inventory := Inventory.new()
	other_inventory.reset([FISTS])
	other_carl.inventory = other_inventory
	other_carl.position = Vector2(-60, 40)
	_arena.add_child(other_carl)
	var pickup := _spawn_pickup(BAT, Vector2(0, 60))
	await wait_physics_frames(2)
	carl.teleport_to(pickup.position + Vector2(-4, 0))
	other_carl.teleport_to(pickup.position + Vector2(4, 0))
	await wait_physics_frames(3)
	var owners := [game_state().inventory.has(BAT), other_inventory.has(BAT)].count(true)
	check(owners == 1 and not is_instance_valid(pickup), "two collectors touching it at once: only one gets it", "%d owners" % owners)
	other_carl.queue_free()
	var inventory: Inventory = game_state().inventory
	inventory.add(BAT, 1)
	var second := _spawn_pickup(BAT, carl.position + Vector2(0, 50))
	await wait_physics_frames(2)
	carl.teleport_to(second.position)
	await wait_physics_frames(3)
	check(inventory.get_actions().count(BAT) == 1, "a second Bat pickup never makes two")


func _check_swing_directions() -> void:
	print("-- The Bat swings the way Carl faces, never behind him")
	var carl := _new_arena_with_bat_on_s()
	var swings := _record_swings(carl)
	await wait_physics_frames(2)
	for step: Array in [[KEY_RIGHT, Vector2.RIGHT], [KEY_UP, Vector2.UP], [KEY_LEFT, Vector2.LEFT], [KEY_DOWN, Vector2.DOWN]]:
		await tap_key(step[0])
		var facing: Vector2 = step[1]
		var in_front := _spawn_blob(carl.global_position + facing * 50.0)
		var behind := _spawn_blob(carl.global_position - facing * 30.0)
		var beside := _spawn_blob(carl.global_position + facing.orthogonal() * 30.0)
		await wait_physics_frames(2)
		var before := swings.size()
		await tap_key(KEY_S)
		check(swings.size() == before + 1 and swings[-1] == [facing, 1], "facing %s, one tap of S swings once that way and hits one enemy" % facing,
				str(swings.slice(before)))
		check(in_front.health.current_health == 10, "the enemy in front loses 20", "%d HP" % in_front.health.current_health)
		check(behind.health.current_health == 30 and beside.health.current_health == 30, "the enemies behind and beside Carl are not hit")
		for blob in [in_front, behind, beside]:
			blob.queue_free()
		await wait_seconds(0.8)

	print("-- Empty slots do nothing")
	var before_empty := swings.size()
	await hold_keys([KEY_W], 30)
	await hold_keys([KEY_A], 30)
	check(swings.size() == before_empty, "W and A (empty) swing nothing")


func _check_damage_kill_and_death() -> void:
	print("-- 20 damage per hit; two hits kill a blob, which dies normally")
	var carl := _new_arena_with_bat_on_s()
	var blob := _spawn_blob(Vector2(50, 0))
	blob.death_fade_time = 3.0
	var damage_taken := []
	blob.health.damaged.connect(func(amount: int) -> void: damage_taken.append(amount))
	var died := [0]
	blob.health.died.connect(func() -> void: died[0] += 1)
	carl.facing_direction = Vector2.RIGHT
	await tap_key(KEY_S)
	check(damage_taken == [DAMAGE] and blob.health.current_health == 10, "the first hit deals exactly 20", str(damage_taken))
	await wait_seconds(1.0)
	# Knocked back 80 px; bring it within reach again for the second hit.
	blob.global_position = Vector2(50, 0)
	blob.reset_physics_interpolation()
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	var killed_at := blob.global_position
	check(damage_taken == [DAMAGE, 10] and blob.health.is_dead() and died[0] == 1,
			"the second hit kills it (only its last 10 HP could go; it died once)", str(damage_taken))
	await wait_seconds(0.5)
	check(is_instance_valid(blob) and blob.global_position == killed_at and not blob.is_knocked_back(),
			"the killing hit does not push it: death comes first")
	check(not blob.is_physics_processing() and blob.body_shape.disabled and blob.modulate.a < 1.0,
			"it dies as usual: it stops, stops blocking and fades")
	await wait_seconds(3.0)
	check(not is_instance_valid(blob), "and it is removed")
	check(carl.health.current_health == 100, "Carl is unhurt")


func _check_cooldown() -> void:
	print("-- One swing per press; one every 45 ticks (0.75 s) while held")
	var carl := _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var swings := _record_swing_ticks(carl)
	await tap_key(KEY_S)
	check(swings.size() == 1, "a one-tick tap swings once", str(swings.size()))
	await wait_seconds(1.0)
	await hold_keys([KEY_S], 10)
	check(swings.size() == 2, "a normal 10-tick press swings once (no duplicate swing)", str(swings.size()))
	await wait_seconds(1.0)
	swings.clear()
	await hold_keys([KEY_S], 100)
	check(swings.size() == 3 and swings[1] - swings[0] == COOLDOWN_TICKS and swings[2] - swings[1] == COOLDOWN_TICKS,
			"holding S for 100 ticks swings at 0, 45 and 90", str(swings))
	await wait_seconds(1.0)
	swings.clear()
	for tap in 4:
		await tap_key(KEY_S)
		await wait_physics_frames(8)
	check(swings.size() == 1, "tapping every 10 ticks cannot swing faster than the cooldown", str(swings.size()))
	await wait_seconds(1.0)
	# Moving the Bat to another key keeps its cooldown.
	swings.clear()
	await tap_key(KEY_S)
	game_state().action_slots.assign(BAT, W)
	await tap_key(KEY_W)
	check(swings.size() == 1, "moving it to W right after a swing does not reset its cooldown")


func _check_friends_unhurt() -> void:
	print("-- The Bat never hurts Carl or Donut")
	var carl := _new_arena_with_bat_on_s()
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = Vector2(40, 0)
	_arena.add_child(donut)
	# Sturdy enough to survive Donut's scratches too.
	var blob := _spawn_blob(Vector2(60, 10), 200)
	# Its own touch would hurt Donut, standing beside it; only the Bat is being checked here.
	blob.contact_attack.target_layers = 0
	var blob_damage := []
	blob.health.damaged.connect(func(amount: int) -> void: blob_damage.append(amount))
	await wait_physics_frames(3)
	var donut_position := donut.global_position
	carl.facing_direction = Vector2.RIGHT
	var swings := _record_swings(carl)
	await tap_key(KEY_S)
	await wait_seconds(0.5)
	check(swings.size() == 1 and swings[0][1] == 1 and blob_damage.count(DAMAGE) == 1,
			"the swing through Donut hits only the blob beside her", "%s %s" % [swings, blob_damage])
	check(donut.health.current_health == 60 and carl.health.current_health == 100, "Donut (in the swing) and Carl keep all their HP")
	check(donut.global_position.distance_to(donut_position) < 0.5, "Donut is not knocked back")
	check(donut.get_node("Hurtbox").knockback_receiver == null and carl.get_node("Hurtbox").knockback_receiver == null
			and donut.get_node_or_null("KnockbackReceiver") == null and carl.get_node_or_null("KnockbackReceiver") == null,
			"neither Carl nor Donut can be knocked back at all (no KnockbackReceiver)")


func _check_walls_block_the_swing() -> void:
	print("-- The Bat never hits through a wall")
	var carl := _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	# A thin wall 30-38 px in front of Carl; a blob 60 px away is inside the swing's reach.
	_spawn_wall(Vector2(34, 0), Vector2(8, 200))
	var behind_wall := _spawn_blob(Vector2(60, 0))
	await wait_physics_frames(2)
	var swings := _record_swings(carl)
	await tap_key(KEY_S)
	check(swings.size() == 1 and swings[0][1] == 0 and behind_wall.health.current_health == 30,
			"a blob behind a thin wall, within reach, is not hit", str(swings))
	# The same swing with no wall hits it.
	carl = _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var in_the_open := _spawn_blob(Vector2(60, 0))
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	check(in_the_open.health.current_health == 10, "without the wall the same blob is hit")


func _check_knockback_unobstructed() -> void:
	print("-- Knockback: away from Carl, exactly 80 px in 18 ticks")
	for facing: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		var carl := _new_arena_with_bat_on_s()
		carl.facing_direction = facing
		var blob := _spawn_blob(facing * 50.0)
		await wait_physics_frames(2)
		var start := blob.global_position
		send_key(KEY_S, true)
		await wait_physics_frames(4)
		send_key(KEY_S, false)
		var early := blob.global_position - start
		check(blob.is_knocked_back() and early.length() > 20.0 and early.normalized().is_equal_approx(facing),
				"facing %s: the blob is visibly pushed away from Carl at once" % facing, "%s after 3 ticks" % early)
		await wait_until(func() -> bool: return not blob.is_knocked_back(), "the push to end", 30)
		var pushed := blob.global_position - start
		check(pushed.distance_to(facing * KNOCKBACK_DISTANCE) < 0.5, "it ends 80 px away from where it was hit", str(pushed))
		await wait_physics_frames(30)
		check(blob.global_position.distance_to(start + pushed) < 0.01 and blob.velocity == Vector2.ZERO,
				"then it stays there (this blob does not chase): no drift, no leftover velocity")

	print("-- The push takes 18 ticks, and a chasing blob does not fight it")
	var carl := _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var chaser := _spawn_blob(Vector2(60, 0), 30, true)
	await wait_physics_frames(2)
	check(chaser.is_active() and chaser.target == carl, "the blob is chasing Carl")
	var start := chaser.global_position
	send_key(KEY_S, true)
	var push_ticks := await _count_push_ticks(chaser)
	send_key(KEY_S, false)
	var pushed := chaser.global_position - start
	check(push_ticks == KNOCKBACK_TICKS, "the push lasts exactly 18 ticks (0.3 s)", "%d ticks" % push_ticks)
	check(pushed.distance_to(Vector2(KNOCKBACK_DISTANCE, 0)) < 0.5,
			"a blob chasing Carl is still pushed the full 80 px: its pursuit does not fight the push", str(pushed))
	await wait_physics_frames(30)
	check(chaser.global_position.x < start.x + KNOCKBACK_DISTANCE - 20.0, "afterwards it comes back at Carl",
			"x %.1f" % chaser.global_position.x)


func _check_knockback_against_a_wall() -> void:
	print("-- Knockback stops at a wall")
	var carl := _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	# Wall face at x = 90: 40 px behind a blob 50 px away (13 px body).
	var wall := _spawn_wall(Vector2(110, 0), Vector2(40, 300))
	var blob := _spawn_blob(Vector2(50, 0))
	await wait_physics_frames(2)
	var farthest := [-INF]
	var track := func() -> void: farthest[0] = maxf(farthest[0], blob.global_position.x)
	physics_frame.connect(track)
	await tap_key(KEY_S)
	await wait_seconds(0.6)
	physics_frame.disconnect(track)
	var face_x := wall.global_position.x - 20.0
	check(blob.health.current_health == 10 and not blob.is_knocked_back(), "the hit landed and the push is over")
	check(farthest[0] <= face_x - 13.0 + 0.5, "the blob never overlaps the wall", "farthest x %.2f, wall face %.1f" % [farthest[0], face_x])
	check(blob.global_position.x > face_x - 13.0 - 2.0, "it stops right against the wall (less than 80 px)", "x %.2f" % blob.global_position.x)
	check(absf(blob.global_position.y) < 0.5, "it is not deflected sideways by a wall it hits square on")
	# A wall only 10 px thick is not crossed either.
	carl = _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var thin_wall := _spawn_wall(Vector2(95, 0), Vector2(10, 300))
	var thin_blob := _spawn_blob(Vector2(50, 0))
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	await wait_seconds(0.6)
	check(thin_blob.health.current_health == 10 and thin_blob.global_position.x < thin_wall.global_position.x - 5.0 - 12.5,
			"a thin wall stops it too: it never ends up on the far side", "x %.2f" % thin_blob.global_position.x)


func _check_death_during_knockback() -> void:
	print("-- An enemy killed while being pushed stays dead")
	var carl := _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var blob := _spawn_blob(Vector2(50, 0), 30, true)
	blob.death_fade_time = 2.0
	await wait_physics_frames(2)
	send_key(KEY_S, true)
	await wait_physics_frames(5)
	send_key(KEY_S, false)
	check(blob.is_knocked_back() and blob.health.current_health == 10, "it is being pushed")
	blob.get_node("Hurtbox").take_hit(10)
	var died_at := blob.global_position
	check(blob.health.is_dead() and not blob.is_knocked_back(), "killed mid-push, the push ends at once")
	await wait_seconds(1.0)
	check(blob.global_position == died_at and blob.target == null and not blob.is_physics_processing(),
			"it never moves or chases again")
	check(carl.health.current_health == 100, "and never touches Carl")


func _check_blob_resumes_navigation() -> void:
	print("-- After a push, a Gelatinous Blob navigates back to Carl")
	# A real navigation mesh, with a wall 45 px behind the blob.
	var arena := await build_navigation_arena(Vector2(800, 400), [Rect2(330, 100, 40, 200)])
	if arena == null:
		return
	_use_arena(arena)
	var carl := _add_carl(Vector2(200, 200), true)
	carl.facing_direction = Vector2.RIGHT
	var blob := _spawn_blob(Vector2(260, 200), 30, true)
	await wait_physics_frames(10)
	check(blob.target == carl, "the blob chases Carl")
	var touches := []
	carl.health.damaged.connect(func(amount: int) -> void: touches.append(amount))
	await wait_until(func() -> bool: return blob.global_position.distance_to(carl.global_position) < 55.0, "the blob to come within reach", 120)
	send_key(KEY_S, true)
	await physics_frame
	send_key(KEY_S, false)
	var farthest := [0.0]
	await wait_until(func() -> bool:
		farthest[0] = maxf(farthest[0], blob.global_position.x)
		return not blob.is_knocked_back(), "the push to end", 30)
	check(blob.health.current_health == 10 and farthest[0] <= 330.0 - 13.0 + 0.5, "pushed toward the wall, it stops against it",
			"farthest x %.2f" % farthest[0])
	var landed := blob.global_position
	await wait_physics_frames(20)
	check(blob.global_position.x < landed.x - 10.0 and blob.target == carl, "then it moves back toward Carl",
			"x %.1f -> %.1f" % [landed.x, blob.global_position.x])
	var path: PackedVector2Array = blob.navigation.get_current_navigation_path()
	check(not path.is_empty() and path[path.size() - 1].distance_to(carl.global_position) < 20.0,
			"its navigation has a fresh path that ends at Carl", str(path))
	await wait_until(func() -> bool: return not touches.is_empty(), "the blob to touch Carl", 180)
	check(touches == [10], "it reaches Carl and its touch takes 10 again", str(touches))
	check(not blob.is_knocked_back(), "it is not stuck in a push")


func _check_spitting_blob() -> void:
	print("-- The Spitting Blob: no spitting and no walking while pushed, no burst after")
	var carl := _new_arena_with_bat_on_s()
	carl.health.set_health(1000, 1000)
	carl.facing_direction = Vector2.RIGHT
	var spitter := _spawn_spitter(Vector2(52, 0), true)
	var spits := []
	spitter.spit_launcher.fired.connect(func(_glob: Projectile) -> void: spits.append(Engine.get_physics_frames()))
	await wait_until(func() -> bool: return not spits.is_empty(), "the first glob", 10)
	await wait_physics_frames(3)
	check(spitter.global_position.x > 52.5 and spitter.global_position.x < 60.0, "it spits at once and backs off (too close)")
	var start := spitter.global_position
	var hit_at := Engine.get_physics_frames() + 1
	send_key(KEY_S, true)
	var push_ticks := await _count_push_ticks(spitter)
	send_key(KEY_S, false)
	var pushed := spitter.global_position - start
	var push_ended_at := Engine.get_physics_frames()
	check(spitter.health.current_health == 10, "the Bat hit it for 20")
	check(push_ticks == KNOCKBACK_TICKS and spits.size() == 1 and spits.all(func(tick: int) -> bool: return tick < hit_at or tick > push_ended_at),
			"it spits nothing during the 18 ticks of the push", "%d ticks, spits %s, push %d-%d" % [push_ticks, spits, hit_at, push_ended_at])
	check(pushed.distance_to(Vector2(KNOCKBACK_DISTANCE, 0)) < 0.5,
			"it moves exactly the 80 px of the push: its own retreat neither fights nor adds to it", str(pushed))
	var landed := spitter.global_position
	await wait_physics_frames(10)
	check(spitter.global_position.x > landed.x + 5.0, "afterwards it backs away again at its own pace (Carl is within 180 px)",
			"%.1f -> %.1f" % [landed.x, spitter.global_position.x])
	await wait_until(func() -> bool: return spits.size() >= 3, "two more globs", 300)
	check(spits.size() >= 3 and spits[1] - spits[0] == SPIT_COOLDOWN_TICKS and spits[2] - spits[1] == SPIT_COOLDOWN_TICKS,
			"its next globs come exactly 90 ticks apart, the first one 90 ticks after the glob before the hit: no burst, no extra glob, no reset",
			"%s (hit at %d)" % [spits, hit_at])


func _check_spitting_blob_resumes_navigation() -> void:
	print("-- After a push, a Spitting Blob navigates and spits again")
	var arena := await build_navigation_arena(Vector2(900, 400), [Rect2(420, 60, 40, 180)])
	if arena == null:
		return
	_use_arena(arena)
	var carl := _add_carl(Vector2(200, 300), true)
	carl.health.set_health(1000, 1000)
	carl.facing_direction = Vector2.RIGHT
	var spitter := _spawn_spitter(Vector2(252, 300), true)
	var spits := []
	spitter.spit_launcher.fired.connect(func(_glob: Projectile) -> void: spits.append(Engine.get_physics_frames()))
	await wait_physics_frames(3)
	send_key(KEY_S, true)
	await physics_frame
	send_key(KEY_S, false)
	await wait_until(func() -> bool: return not spitter.is_knocked_back(), "the push to end", 30)
	check(spitter.health.current_health == 10, "the Bat hit it")
	var landed := spitter.global_position
	await wait_until(func() -> bool: return spitter.global_position.distance_to(carl.global_position) >= 179.0,
			"it to back off to 180 px", 240)
	check(spitter.global_position.distance_to(landed) > 20.0 and not spitter.navigation.get_current_navigation_path().is_empty(),
			"it moves again along the navigation mesh, back to its preferred distance",
			"%.0f px from Carl" % spitter.global_position.distance_to(carl.global_position))
	var spits_before := spits.size()
	await wait_until(func() -> bool: return spits.size() > spits_before, "it to spit again", 100)
	check(spits.size() == spits_before + 1, "and it spits at Carl again")


func _check_other_attacks_unchanged() -> void:
	print("-- Fists, stones, Scratch and globs are unchanged and never knock back")
	var fists := FISTS.performer_scene.instantiate() as MeleeAttack
	check(fists.damage == 10 and is_equal_approx(fists.reach, 24.0) and is_equal_approx(fists.hit_radius, 18.0)
			and is_equal_approx(fists.cooldown, 0.4) and fists.knockback_distance == 0.0 and fists.blocking_layers == 0
			and fists.get_knockback(Vector2.RIGHT) == null, "Fists: 10 damage, 24 px, 18 px circle, 0.4 s, no knockback")
	fists.free()
	var launcher := SLINGSHOT.performer_scene.instantiate() as ProjectileLauncher
	var stone := launcher.projectile_scene.instantiate() as Projectile
	check(is_equal_approx(launcher.cooldown, 0.6) and stone.damage == 10 and is_equal_approx(stone.speed, 480.0)
			and is_equal_approx(stone.max_distance, 320.0), "the Slingshot: 0.6 s; its stone 10 damage, 480 px/s, 320 px")
	launcher.free()
	stone.free()
	var glob := GLOB_SCENE.instantiate() as Projectile
	check(glob.damage == 10 and is_equal_approx(glob.speed, 240.0) and is_equal_approx(glob.max_distance, 384.0) and glob.target_layers == 16,
			"spit globs: 10 damage, 240 px/s, 384 px, player_hurtbox")
	glob.free()

	# Fists on D, the Slingshot on W: hits land, nothing moves.
	var carl := _new_arena_with_bat_on_s()
	carl.collect_item(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, W)
	carl.facing_direction = Vector2.RIGHT
	var blob := _spawn_blob(Vector2(40, 0))
	await wait_physics_frames(2)
	var start := blob.global_position
	await tap_key(KEY_D)
	await wait_physics_frames(20)
	check(blob.health.current_health == 20 and blob.global_position == start and not blob.is_knocked_back(),
			"a punch takes 10 and does not push the blob")
	await tap_key(KEY_W)
	await wait_physics_frames(20)
	check(blob.health.current_health == 10 and blob.global_position == start and not blob.is_knocked_back(),
			"a stone takes 10 and does not push the blob")

	# Donut's Scratch.
	carl = _new_arena_with_bat_on_s()
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = Vector2(0, 40)
	_arena.add_child(donut)
	check(donut.scratch.damage == 10 and is_equal_approx(donut.scratch.cooldown, 1.0) and donut.scratch.knockback_distance == 0.0,
			"Scratch: 10 damage, 1.0 s, no knockback")
	var scratch_ticks := []
	donut.scratch.performed.connect(func(_d: Vector2, _hits: int) -> void: scratch_ticks.append(Engine.get_physics_frames()))
	var scratched := _spawn_blob(Vector2(0, 76), 60)
	var scratched_start := scratched.global_position
	await wait_physics_frames(130)
	check(scratch_ticks.size() >= 2 and scratch_ticks[1] - scratch_ticks[0] == 60 and scratched.health.current_health == 60 - 10 * scratch_ticks.size(),
			"Donut scratches it for 10 once a second", "%s, %d HP" % [scratch_ticks, scratched.health.current_health])
	check(scratched.global_position == scratched_start and not scratched.is_knocked_back(), "Scratch does not push it")

	# An enemy touch never pushes Carl.
	carl = _new_arena_with_bat_on_s()
	var toucher := _spawn_blob(Vector2(26, 0))
	await wait_physics_frames(3)
	var carl_start := carl.global_position
	await wait_physics_frames(60)
	check(carl.health.current_health < 100 and carl.global_position == carl_start, "a blob's touch hurts Carl but never pushes him")
	toucher.queue_free()


func _check_menu_and_game_over_pause() -> void:
	print("-- The menu blocks swings and freezes a push")
	var carl := _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var menu := _add_menu()
	var blob := _spawn_blob(Vector2(50, 0), 60, true)
	await wait_physics_frames(2)
	var swings := _record_swings(carl)
	menu.open()
	# In the menu S assigns the selected action to S: select the Bat, so S just keeps it there.
	await tap_key(KEY_DOWN)
	check(menu.get_selected_action() == BAT, "the menu's selection is the Bat")
	await hold_keys([KEY_S], 60)
	check(swings.is_empty() and blob.health.current_health == 60 and game_state().action_slots.get_action(S) == BAT,
			"with the menu open, S swings nothing (the Bat stays on S)")
	menu.close()
	await wait_physics_frames(5)
	var start := blob.global_position
	send_key(KEY_S, true)
	await wait_physics_frames(6)
	check(swings.size() == 1 and blob.is_knocked_back(), "a swing starts a push")
	# The menu opens while S is still held (the menu only reacts to presses, not to a held key).
	menu.open()
	var frozen_at := blob.global_position
	await wait_physics_frames(60)
	check(paused and blob.global_position == frozen_at and blob.is_knocked_back(), "1 s of menu: the push is frozen where it was")
	menu.close()
	await wait_physics_frames(40)
	check(swings.size() == 1, "closing the menu with S still held gives no free swing", "%d swings" % swings.size())
	send_key(KEY_S, false)
	check(not blob.is_knocked_back(), "after the menu the push finished")
	var total := [blob.global_position.x - start.x]
	check(total[0] < KNOCKBACK_DISTANCE + 0.5, "and it never went beyond its 80 px", "%.2f px" % total[0])
	await wait_physics_frames(30)
	check(blob.global_position.x < start.x + KNOCKBACK_DISTANCE - 10.0, "then the blob chases Carl again")

	print("-- A tree pause (GAME OVER) freezes a push")
	carl = _new_arena_with_bat_on_s()
	carl.facing_direction = Vector2.RIGHT
	var paused_blob := _spawn_blob(Vector2(50, 0))
	await wait_physics_frames(2)
	var paused_start := paused_blob.global_position
	send_key(KEY_S, true)
	await wait_physics_frames(6)
	send_key(KEY_S, false)
	paused = true
	var paused_at := paused_blob.global_position
	await wait_physics_frames(90)
	check(paused_blob.global_position == paused_at and paused_blob.is_knocked_back(), "1.5 s paused: the push is frozen")
	paused = false
	await wait_until(func() -> bool: return not paused_blob.is_knocked_back(), "the push to end", 30)
	check((paused_blob.global_position - paused_start).distance_to(Vector2(KNOCKBACK_DISTANCE, 0)) < 0.5,
			"unpaused, it finishes the same 80 px push")


func _check_hud_and_menu() -> void:
	print("-- HUD and menu")
	var carl := _new_arena_with_carl()
	var state := game_state()
	var menu := _add_menu()
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_action_slots(state.action_slots, state.inventory)
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	carl.collect_item(SLINGSHOT, 1)
	carl.collect_item(POTION, 1)
	state.action_slots.assign(SLINGSHOT, W)
	state.action_slots.assign(POTION, A)
	await tap_key(KEY_SPACE)
	check(not _rows(menu, "%ActionList").any(func(row: String) -> bool: return row.contains("Baseball Bat")),
			"before the pickup the menu has no Bat")
	await tap_key(KEY_SPACE)
	carl.collect_item(BAT, 1)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)", "Slingshot   (on W)", "Small Health Potion x1   (on A)", "Baseball Bat   (no slot)"],
			"after the pickup the menu lists 'Baseball Bat', with no quantity", str(_rows(menu, "%ActionList")))
	for i in 3:
		await tap_key(KEY_DOWN)
	check(menu.get_node("%DetailsLabel").text == BAT.description, "the menu describes the Bat")
	await tap_key(KEY_S)
	check(_rows(menu, "%SlotList") == ["W   Slingshot", "A   Small Health Potion x1", "S   Baseball Bat", "D   Fists"]
			and _rows(menu, "%ActionList")[3] == "> Baseball Bat   (on S)", "S assigns it", str(_rows(menu, "%SlotList")))
	await tap_key(KEY_SPACE)
	check(slot_bar.text == "W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists", "the HUD: S: Baseball Bat", slot_bar.text)
	var changes := [0]
	state.inventory.changed.connect(func() -> void: changes[0] += 1)
	await tap_key(KEY_RIGHT)
	await hold_keys([KEY_S], 100)
	check(changes[0] == 0 and state.inventory.has(BAT) and slot_bar.text == "W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists",
			"swinging changes neither the inventory nor the HUD")


## Starts an empty arena and a new run, with Carl at the origin using the run's state.
func _new_arena_with_carl() -> CharacterBody2D:
	var arena := Node2D.new()
	root.add_child(arena)
	_use_arena(arena)
	game_state().start_new_run()
	return _add_carl(Vector2.ZERO, false)


## As _new_arena_with_carl(), with the Bat owned and on S (Fists stay on D).
func _new_arena_with_bat_on_s() -> CharacterBody2D:
	var carl := _new_arena_with_carl()
	carl.collect_item(BAT, 1)
	game_state().action_slots.assign(BAT, S)
	return carl


## Makes `arena` the current arena, removing the previous one.
func _use_arena(arena: Node2D) -> void:
	if _arena != null and _arena != arena:
		_arena.free()
	# An earlier check may have ended paused: never start the next one paused.
	paused = false
	_arena = arena


## Adds Carl at `at`, using the run's state. With `bat` he also owns the Bat, on S.
func _add_carl(at: Vector2, bat: bool) -> CharacterBody2D:
	var state := game_state()
	if bat:
		state.start_new_run()
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = at
	_arena.add_child(carl)
	carl.inventory = state.inventory
	carl.action_slots = state.action_slots
	if bat:
		carl.collect_item(BAT, 1)
		state.action_slots.assign(BAT, S)
	return carl


## Waits while `enemy` is being pushed, and returns in how many physics ticks the push moved it.
func _count_push_ticks(enemy: Enemy) -> int:
	var moved := 0
	var last := enemy.global_position
	for i in 120:
		await physics_frame
		if enemy.global_position != last:
			moved += 1
		last = enemy.global_position
		if i > 1 and not enemy.is_knocked_back():
			break
	return moved


## Records each swing of Carl's Bat as [direction, hit count]. Returns the array it fills.
func _record_swings(carl: Node) -> Array:
	var swings := []
	var swing: MeleeAttack = carl.get_action_performer(BAT)
	swing.performed.connect(func(direction: Vector2, hits: int) -> void: swings.append([direction, hits]))
	return swings


## Records the physics frame of each swing of Carl's Bat. Returns the array it fills.
func _record_swing_ticks(carl: Node) -> Array:
	var ticks := []
	var swing: MeleeAttack = carl.get_action_performer(BAT)
	swing.performed.connect(func(_direction: Vector2, _hits: int) -> void: ticks.append(Engine.get_physics_frames()))
	return ticks


## A Gelatinous Blob. Unless `active`, it never moves by itself (its detection range is 0).
func _spawn_blob(at: Vector2, max_health: int = 30, active: bool = false) -> Enemy:
	var blob: Enemy = BLOB_SCENE.instantiate()
	if not active:
		blob.detection_range = 0.0
		blob.chase_range = 0.0
	blob.get_node("Health").max_health = max_health
	blob.position = at
	_arena.add_child(blob)
	return blob


## A Spitting Blob. Unless `active`, it never moves or spits.
func _spawn_spitter(at: Vector2, active: bool = false) -> Enemy:
	var spitter: Enemy = SPITTER_SCENE.instantiate()
	if not active:
		spitter.detection_range = 0.0
		spitter.chase_range = 0.0
	spitter.position = at
	_arena.add_child(spitter)
	return spitter


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
