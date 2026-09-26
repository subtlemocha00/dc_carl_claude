extends "res://tests/support/game_test.gd"
## Phase 12 Blast Bomb, area damage and loot drop checks in arenas (no level):
## - data: id blast_bomb, "Blast Bomb", a consumable with its own icon; its performer is a
##   ProjectileLauncher (1.0 s) throwing a Projectile (220 px/s, 240 px, no impact damage, stopped
##   by enemies and walls) whose DetonateOnStop makes one AreaDamage explosion (20 damage, 72 px,
##   enemy_hurtbox only, walls shield); it is in ActionRegistry;
## - inventory: a new run has none (even after a run that had some); counted, labelled "Blast Bomb
##   x2"; not assignable at 0; one slot at a time; the slot empties at 0 and it can be assigned
##   again after collecting more; snapshots;
## - throwing: the way Carl faces (four directions), from his centre; one per short press; each
##   throw spends exactly one; none at 0; one every 60 ticks while held, taps no faster;
## - flight and detonation: exactly 240 px in the open; stopped by a wall (never through it) and
##   by an enemy; exactly one explosion per bomb, where it stopped; a second detonate() does
##   nothing; the bomb never collects a pickup;
## - the explosion: exactly 20 to a Gelatinous Blob and to a Spitting Blob; two (and four) enemies
##   in one blast each lose 20 once; a second blast kills them; a Hurtbox overlapping the 72 px
##   circle is hit (centre 84 px away), one farther is not (centre 88 px); never Carl or Donut,
##   even at its centre; no knockback (nothing moves); the flash shows for 0.35 s, then goes;
## - wall shielding: an enemy 60 px away behind a wall takes nothing, the same enemy in the open
##   takes 20, and removing the wall lets the next blast through; a thrown bomb against a wall
##   spares the enemy behind it;
## - regressions: the Bat still hits for 20 and knocks back 80 px; stones still hit for 10;
## - pause: a tree pause (the menu, GAME OVER) freezes a bomb in flight and an explosion's flash;
##   no throw while the menu is open or Carl is down; closing the menu with the key held throws
##   nothing; no burst after a pause;
## - HUD and menu: "S: Blast Bomb x2", then x1, then "S: —"; the menu row follows;
## - loot drop: an enemy with a LootDrop (Blast Bomb x2) leaves a pickup where it dies, and its
##   death alone gives Carl nothing; Donut, another enemy, a stone and a bomb do not take it;
##   Carl walking over it gets exactly 2, once; two collectors: one; one drop per enemy even if
##   its death is announced twice; it works for a Spitting Blob and for a blob killed by a bomb.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_blast_bomb.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/enemies/spitting_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const STONE_SCENE: PackedScene = preload("res://scenes/projectiles/slingshot_stone.tscn")
const BOMB_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/blast_bomb.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/effects/blast_explosion.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const W := ActionSlots.SLOT_W
const A := ActionSlots.SLOT_A
const S := ActionSlots.SLOT_S
const D := ActionSlots.SLOT_D
## Canonical Phase 12 numbers.
const DAMAGE := 20
const RADIUS := 72.0
const SPEED := 220.0
const RANGE := 240.0
const COOLDOWN_TICKS := 60  # 1.0 s at 60 ticks per second
const FLASH_TICKS := 21  # 0.35 s
const BLOB_HURTBOX_RADIUS := 14.0

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_data()
	_check_inventory_and_slots()
	await _check_throw_directions()
	await _check_quantity_and_cooldown()
	await _check_range()
	await _check_wall_stops_the_bomb()
	await _check_enemy_stops_the_bomb()
	await _check_explosion_damage()
	await _check_explosion_reach()
	await _check_friends_never_hurt()
	await _check_no_knockback()
	await _check_wall_shielding()
	await _check_explosion_flash()
	await _check_pause_and_game_over()
	await _check_hud_and_menu()
	await _check_loot_drop()
	await _check_loot_drop_collectors()
	await _check_loot_drop_other_enemies()
	await _check_other_attacks_unchanged()
	finish()


func _check_data() -> void:
	print("-- The Blast Bomb's data")
	check(BOMB.id == &"blast_bomb" and BOMB.display_name == "Blast Bomb" and BOMB.get_short_name() == "Blast Bomb",
			"id 'blast_bomb', named 'Blast Bomb'")
	check(BOMB.consumable and BOMB.assignable, "a consumable (counted, used up) that can go in a slot")
	check(BOMB.icon != null and BOMB.icon != SLINGSHOT.icon and BOMB.icon != BAT.icon, "it has its own icon")
	check(ActionRegistry.find(&"blast_bomb") == BOMB, "ActionRegistry knows it by its id")
	var launcher := BOMB.performer_scene.instantiate() as ProjectileLauncher
	check(launcher != null, "its performer is a ProjectileLauncher, like the Slingshot")
	if launcher == null:
		return
	check(is_equal_approx(launcher.cooldown, 1.0), "cooldown 1.0 s", str(launcher.cooldown))
	var bomb := launcher.projectile_scene.instantiate() as Projectile
	check(bomb != null, "it throws a Projectile")
	if bomb != null:
		check(is_equal_approx(bomb.speed, SPEED) and is_equal_approx(bomb.max_distance, RANGE) and bomb.damage == 0
				and bomb.target_layers == 32 and bomb.blocking_layers == 1,
				"the bomb flies 220 px/s for at most 240 px, is stopped by enemies (enemy_hurtbox) and walls, and does no impact damage")
		var detonator := bomb.get_node_or_null("DetonateOnStop") as DetonateOnStop
		check(detonator != null, "it explodes when it stops (DetonateOnStop)")
		if detonator != null:
			var explosion := detonator.explosion_scene.instantiate() as AreaDamage
			check(explosion != null and explosion.damage == DAMAGE and is_equal_approx(explosion.radius, RADIUS)
					and explosion.target_layers == 32 and explosion.blocking_layers == 1,
					"its explosion is an AreaDamage: 20 damage, 72 px, enemy_hurtbox only, walls shield")
			if explosion != null:
				explosion.free()
		bomb.free()
	launcher.free()


func _check_inventory_and_slots() -> void:
	print("-- A finite, counted item")
	var state := game_state()
	state.inventory.add(BOMB, 3)
	state.action_slots.assign(BOMB, S)
	state.start_new_run()
	check(state.inventory.get_quantity(BOMB) == 0 and not state.inventory.has(BOMB) and state.action_slots.find_slot(BOMB) == &""
			and state.action_slots.get_action(D) == FISTS and state.action_slots.get_action(W) == null
			and state.action_slots.get_action(A) == null and state.action_slots.get_action(S) == null,
			"a new run has no Blast Bombs (even after a run that had 3 on S); W/A/S empty, D = Fists")

	var inventory := Inventory.new()
	inventory.reset([FISTS])
	var slots := ActionSlots.new(inventory)
	slots.assign(FISTS, D)
	var empty_snapshot := inventory.get_snapshot()
	check(not slots.assign(BOMB, S) and slots.get_action(S) == null, "with none, it cannot be put in a slot")
	inventory.add(BOMB, 2)
	check(inventory.get_quantity(BOMB) == 2 and inventory.has(BOMB), "collecting 2 gives exactly 2")
	check(inventory.get_label(BOMB) == "Blast Bomb x2" and inventory.get_label(BOMB, true) == "Blast Bomb x2",
			"labelled 'Blast Bomb x2'", inventory.get_label(BOMB))
	for slot: StringName in [W, A, S, D]:
		check(slots.assign(BOMB, slot) and slots.find_slot(BOMB) == slot and _slots_holding(slots, BOMB) == 1,
				"it can go on %s, and is in one slot only" % ActionSlots.KEY_LABELS[slot])
	slots.assign(FISTS, D)
	slots.assign(BOMB, S)
	check(slots.get_display_name(S, true) == "Blast Bomb x2", "slot S shows 'Blast Bomb x2'", slots.get_display_name(S, true))
	var two_snapshot := inventory.get_snapshot()
	check(two_snapshot["quantities"].get(BOMB.id) == 2, "a snapshot holds its quantity")
	check(not inventory.remove(BOMB, 3) and inventory.get_quantity(BOMB) == 2, "taking 3 of 2 fails and takes nothing")
	check(inventory.remove(BOMB, 1) and inventory.get_quantity(BOMB) == 1 and slots.get_action(S) == BOMB
			and slots.get_display_name(S, true) == "Blast Bomb x1", "using one leaves 1, still on S")
	check(inventory.remove(BOMB, 1) and inventory.get_quantity(BOMB) == 0 and not inventory.has(BOMB)
			and slots.get_action(S) == null and BOMB not in inventory.get_actions(),
			"using the last one leaves none: it leaves the inventory and S empties")
	check(not slots.assign(BOMB, S), "at 0 it cannot be assigned again")
	inventory.add(BOMB, 2)
	check(slots.assign(BOMB, S) and inventory.get_quantity(BOMB) == 2, "after collecting more it can be assigned again")
	inventory.restore_snapshot(empty_snapshot)
	check(not inventory.has(BOMB) and slots.get_action(S) == null, "restoring a snapshot without bombs takes them back; S empties")
	inventory.restore_snapshot(two_snapshot)
	inventory.restore_snapshot(two_snapshot)
	check(inventory.get_quantity(BOMB) == 2, "restoring a snapshot with 2, twice, gives 2 (never 4)")


func _check_throw_directions() -> void:
	print("-- Thrown the way Carl faces")
	var carl := _new_arena_with_bombs(4, S)
	var throws := _record_throws(carl)
	await wait_physics_frames(2)
	var expected_quantity := 4
	for step: Array in [[KEY_RIGHT, Vector2.RIGHT], [KEY_UP, Vector2.UP], [KEY_LEFT, Vector2.LEFT], [KEY_DOWN, Vector2.DOWN]]:
		await tap_key(step[0])
		var facing: Vector2 = step[1]
		var before := throws.size()
		await tap_key(KEY_S)
		expected_quantity -= 1
		check(throws.size() == before + 1, "facing %s, one tap of S throws one bomb" % facing, "%d thrown" % (throws.size() - before))
		if throws.size() == before + 1:
			var thrown: Dictionary = throws[-1]
			check(thrown["direction"].is_equal_approx(facing) and thrown["from"].distance_to(carl.global_position) < 0.5,
					"it leaves Carl's centre toward %s" % facing, "%s from %s" % [thrown["direction"], thrown["from"]])
		check(game_state().inventory.get_quantity(BOMB) == expected_quantity, "that throw spent exactly one: %d left" % expected_quantity,
				str(game_state().inventory.get_quantity(BOMB)))
		await wait_seconds(1.3)
	check(game_state().action_slots.get_action(S) == null and not game_state().inventory.has(BOMB),
			"after the fourth (last) bomb, S is empty")


func _check_quantity_and_cooldown() -> void:
	print("-- One bomb per press; one every 60 ticks (1.0 s) while held; none at 0")
	var carl := _new_arena_with_bombs(9, S)
	carl.facing_direction = Vector2.RIGHT
	var throws := _record_throws(carl)
	var inventory: Inventory = game_state().inventory
	await tap_key(KEY_S)
	check(throws.size() == 1 and inventory.get_quantity(BOMB) == 8, "a one-tick tap throws one and spends one (9 -> 8)",
			"%d thrown, %d left" % [throws.size(), inventory.get_quantity(BOMB)])
	await wait_seconds(1.2)
	await hold_keys([KEY_S], 10)
	check(throws.size() == 2 and inventory.get_quantity(BOMB) == 7, "a normal 10-tick press throws one (no double throw)",
			"%d thrown, %d left" % [throws.size(), inventory.get_quantity(BOMB)])
	await wait_seconds(1.2)
	throws.clear()
	await hold_keys([KEY_S], 125)
	var ticks := throws.map(func(thrown: Dictionary) -> int: return thrown["tick"])
	check(throws.size() == 3 and ticks[1] - ticks[0] == COOLDOWN_TICKS and ticks[2] - ticks[1] == COOLDOWN_TICKS,
			"holding S for 125 ticks throws at 0, 60 and 120", str(ticks.map(func(t: int) -> int: return t - ticks[0])))
	check(inventory.get_quantity(BOMB) == 4, "three throws spent exactly three (7 -> 4)", str(inventory.get_quantity(BOMB)))
	await wait_seconds(1.2)
	throws.clear()
	for tap in 5:
		await tap_key(KEY_S)
		await wait_physics_frames(8)
	check(throws.size() == 1 and inventory.get_quantity(BOMB) == 3, "tapping every 10 ticks cannot throw faster than the cooldown",
			"%d thrown" % throws.size())
	await wait_seconds(1.2)
	# A throw refused by the cooldown spends nothing, and the launcher is ready exactly 60 ticks
	# after a throw.
	throws.clear()
	var launcher := carl.get_action_performer(BOMB) as ProjectileLauncher
	await tap_key(KEY_S)
	await wait_physics_frames(30)
	await tap_key(KEY_S)
	check(throws.size() == 1 and inventory.get_quantity(BOMB) == 2, "a press half a second after a throw does nothing and spends nothing",
			"%d thrown, %d left" % [throws.size(), inventory.get_quantity(BOMB)])
	await wait_until(launcher.can_fire, "the launcher to be ready", 90)
	check(Engine.get_physics_frames() - throws[0]["tick"] == COOLDOWN_TICKS, "it is ready again exactly 60 ticks after the throw",
			str(Engine.get_physics_frames() - throws[0]["tick"]))
	await tap_key(KEY_S)
	check(throws.size() == 2 and inventory.get_quantity(BOMB) == 1, "then it throws again")
	await wait_seconds(1.2)
	await tap_key(KEY_S)
	check(throws.size() == 3 and inventory.get_quantity(BOMB) == 0 and game_state().action_slots.get_action(S) == null,
			"the last bomb: 0 left and S is empty")
	await wait_seconds(1.2)
	await hold_keys([KEY_S], 90)
	check(throws.size() == 3, "with none left, S throws nothing")


func _check_range() -> void:
	print("-- In the open it flies exactly 240 px, then explodes")
	var carl := _new_arena_with_bombs(1, S)
	carl.facing_direction = Vector2.RIGHT
	var throws := _record_throws(carl)
	await tap_key(KEY_S)
	if throws.size() != 1:
		check(false, "a bomb was thrown")
		return
	var thrown: Dictionary = throws[0]
	await wait_until(func() -> bool: return not thrown["stops"].is_empty(), "the bomb to stop", 120)
	if thrown["stops"].is_empty():
		return
	var stop: Dictionary = thrown["stops"][0]
	check(stop["collider"] == null, "it stopped by itself (nothing hit)")
	check_near("it stopped 240 px from Carl", stop["position"].x - carl.global_position.x, RANGE, 0.01)
	var flight_ticks: int = stop["tick"] - thrown["tick"]
	check(flight_ticks == 66, "240 px at 220 px/s: it flew for 66 ticks (1.1 s)", str(flight_ticks))
	check(thrown["explosions"].size() == 1 and thrown["explosions"][0]["position"].distance_to(stop["position"]) < 0.01,
			"it made exactly one explosion, where it stopped")
	await wait_physics_frames(2)
	check(not is_instance_valid(thrown["bomb"]), "the bomb is gone")
	await wait_seconds(1.0)
	check(thrown["stops"].size() == 1 and thrown["explosions"].size() == 1, "and it never explodes again")


func _check_wall_stops_the_bomb() -> void:
	print("-- A wall stops it; the blast stays on Carl's side")
	var carl := _new_arena_with_bombs(1, S)
	carl.facing_direction = Vector2.RIGHT
	# A wall from x = 150 to 182, and a blob just behind it: 52 px from the wall's face, which is
	# inside the blast's 72 px, but on the far side.
	_spawn_wall(Vector2(166, 0), Vector2(32, 200))
	var behind := _spawn_blob(Vector2(202, 0))
	var throws := _record_throws(carl)
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	if throws.size() != 1:
		check(false, "a bomb was thrown")
		return
	var thrown: Dictionary = throws[0]
	await wait_until(func() -> bool: return not thrown["stops"].is_empty(), "the bomb to stop", 120)
	if thrown["stops"].is_empty():
		return
	var stop: Dictionary = thrown["stops"][0]
	check(stop["collider"] is StaticBody2D and absf(stop["position"].x - 150.0) < 0.01,
			"it stopped at the wall's face (x = 150), never inside or past it", str(stop["position"]))
	check(thrown["explosions"].size() == 1 and thrown["explosions"][0]["position"].x < 150.0
			and thrown["explosions"][0]["position"].x > 145.0, "and exploded once, just in front of the wall",
			str(thrown["explosions"][0]["position"]) if not thrown["explosions"].is_empty() else "")
	check(behind.health.current_health == 30, "the blob behind the wall (52 px from the blast) is not hurt",
			"%d HP" % behind.health.current_health)


func _check_enemy_stops_the_bomb() -> void:
	print("-- An enemy stops it; the enemy it hit loses exactly 20, once")
	var carl := _new_arena_with_bombs(1, S)
	carl.facing_direction = Vector2.RIGHT
	var blob := _spawn_blob(Vector2(150, 0))
	var damage_taken := _record_damage(blob)
	var throws := _record_throws(carl)
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	if throws.size() != 1:
		check(false, "a bomb was thrown")
		return
	var thrown: Dictionary = throws[0]
	await wait_until(func() -> bool: return not thrown["stops"].is_empty(), "the bomb to stop", 120)
	if thrown["stops"].is_empty():
		return
	var stop: Dictionary = thrown["stops"][0]
	check(stop["collider"] == blob.get_node("Hurtbox") and absf(stop["position"].x - (150.0 - BLOB_HURTBOX_RADIUS)) < 0.01,
			"it stopped on the blob's Hurtbox", str(stop["position"]))
	check(thrown["explosions"].size() == 1 and thrown["explosions"][0]["targets"].size() == 1
			and thrown["explosions"][0]["targets"][0] == blob.get_node("Hurtbox"),
			"one explosion, which hit that blob")
	await wait_physics_frames(30)
	check(damage_taken == [DAMAGE] and blob.health.current_health == 10, "the blob lost exactly 20 (no extra impact damage)",
			str(damage_taken))
	var explosion := EXPLOSION_SCENE.instantiate() as AreaDamage
	_arena.add_child(explosion)
	explosion.global_position = blob.global_position
	check(explosion.detonate().size() == 1 and explosion.detonate().is_empty() and explosion.has_detonated(),
			"an explosion detonates once: calling detonate() again does nothing")
	check(damage_taken == [DAMAGE, 10], "(the first call hit it once more, the second not at all)", str(damage_taken))


func _check_explosion_damage() -> void:
	print("-- One explosion: 20 to every enemy in it, once each")
	_new_arena_with_bombs(0, S)
	var blob := _spawn_blob(Vector2(30, 0))
	var spitter := _spawn_spitter(Vector2(-30, 20))
	var blob_damage := _record_damage(blob)
	var spitter_damage := _record_damage(spitter)
	await wait_physics_frames(2)
	var targets := _explode_at(Vector2.ZERO)
	check(targets.size() == 2, "the explosion hits both enemies", str(targets.size()))
	check(blob_damage == [DAMAGE] and blob.health.current_health == 10, "the Gelatinous Blob loses exactly 20, once", str(blob_damage))
	check(spitter_damage == [DAMAGE] and spitter.health.current_health == 10, "the Spitting Blob loses exactly 20, once", str(spitter_damage))
	_explode_at(Vector2.ZERO)
	check(blob.health.is_dead() and spitter.health.is_dead() and blob_damage == [DAMAGE, 10] and spitter_damage == [DAMAGE, 10],
			"a second explosion kills both (each loses its last 10 HP)")
	await wait_physics_frames(2)
	check(_explode_at(Vector2.ZERO).is_empty(), "a dying enemy is not hit again")

	var crowd: Array[Enemy] = []
	for offset: Vector2 in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		crowd.append(_spawn_blob(Vector2(0, 200) + offset))
	await wait_physics_frames(2)
	check(_explode_at(Vector2(0, 200)).size() == 4 and crowd.all(func(e: Enemy) -> bool: return e.health.current_health == 10),
			"four blobs around one explosion each lose exactly 20")


func _check_explosion_reach() -> void:
	print("-- It reaches every Hurtbox that overlaps its 72 px circle")
	_new_arena_with_bombs(0, S)
	var reached := _spawn_blob(Vector2(84, 0))
	var beyond := _spawn_blob(Vector2(0, 88))
	await wait_physics_frames(2)
	_explode_at(Vector2.ZERO)
	check(reached.health.current_health == 10, "a blob whose centre is 84 px away (its Hurtbox overlaps the circle) is hit")
	check(beyond.health.current_health == 30, "a blob whose centre is 88 px away (its Hurtbox is outside) is not")


func _check_friends_never_hurt() -> void:
	print("-- Carl and Donut are never hurt by it")
	var carl := _new_arena_with_bombs(2, S)
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = Vector2(20, 20)
	_arena.add_child(donut)
	var blob := _spawn_blob(Vector2(-40, 0))
	await wait_physics_frames(3)
	var carl_position := carl.global_position
	var donut_position := donut.global_position
	_explode_at(carl.global_position)
	_explode_at(donut.global_position)
	await wait_physics_frames(10)
	check(carl.health.current_health == 100 and donut.health.current_health == 60,
			"an explosion at Carl's centre and one at Donut's: Carl 100, Donut 60", "%d, %d" % [carl.health.current_health, donut.health.current_health])
	check(carl.global_position == carl_position and donut.global_position == donut_position, "neither is moved")
	check(blob.health.current_health == 0 or blob.health.is_dead(), "(the blob next to Carl was hit by both and died)")

	# A thrown bomb against a wall right in front of them.
	carl.facing_direction = Vector2.RIGHT
	_spawn_wall(Vector2(66, 0), Vector2(32, 200))
	await wait_physics_frames(2)
	var throws := _record_throws(carl)
	await tap_key(KEY_S)
	await wait_seconds(0.5)
	check(throws.size() == 1 and not throws[0]["explosions"].is_empty(), "a bomb thrown at a wall 50 px away explodes there")
	check(carl.health.current_health == 100 and donut.health.current_health == 60 and carl.global_position == carl_position,
			"Carl and Donut, well inside the blast, are unhurt and unmoved")


func _check_no_knockback() -> void:
	print("-- The explosion knocks nothing back")
	_new_arena_with_bombs(0, S)
	var blob := _spawn_blob(Vector2(40, 0), 60)
	var spitter := _spawn_spitter(Vector2(-40, 0))
	await wait_physics_frames(2)
	var blob_position := blob.global_position
	var spitter_position := spitter.global_position
	_explode_at(Vector2.ZERO)
	check(not blob.is_knocked_back() and not spitter.is_knocked_back(), "no push starts")
	await wait_physics_frames(30)
	check(blob.global_position == blob_position and spitter.global_position == spitter_position,
			"30 ticks later neither enemy has moved")


func _check_wall_shielding() -> void:
	print("-- Walls shield enemies from the blast")
	_new_arena_with_bombs(0, S)
	# A thin wall between the explosion (origin) and a blob 60 px east: inside the 72 px circle.
	var wall := _spawn_wall(Vector2(32, 0), Vector2(16, 120))
	var shielded := _spawn_blob(Vector2(60, 0))
	var open := _spawn_blob(Vector2(0, 60))
	await wait_physics_frames(2)
	var targets := _explode_at(Vector2.ZERO)
	check(shielded.health.current_health == 30, "the blob 60 px away behind the wall takes nothing")
	check(open.health.current_health == 10 and targets.size() == 1 and targets[0] == open.get_node("Hurtbox"),
			"the blob 60 px away in the open, same explosion, takes 20")
	wall.queue_free()
	await wait_physics_frames(3)
	_explode_at(Vector2.ZERO)
	check(shielded.health.current_health == 10, "with the wall gone, the next explosion reaches it: 20")


func _check_explosion_flash() -> void:
	print("-- The explosion is shown briefly, then removed")
	_new_arena_with_bombs(0, S)
	var explosion := EXPLOSION_SCENE.instantiate() as AreaDamage
	_arena.add_child(explosion)
	explosion.detonate()
	check(explosion.is_inside_tree() and explosion.visible, "right after it goes off, it is drawn")
	await wait_physics_frames(FLASH_TICKS - 3)
	check(is_instance_valid(explosion), "it is still there after %d ticks" % (FLASH_TICKS - 3))
	await wait_physics_frames(6)
	check(not is_instance_valid(explosion), "and gone after 0.35 s")


func _check_pause_and_game_over() -> void:
	print("-- A pause freezes the bomb and the blast; no throw while paused or down")
	var carl := _new_arena_with_bombs(5, S)
	carl.facing_direction = Vector2.RIGHT
	var menu := _add_menu()
	var throws := _record_throws(carl)
	await tap_key(KEY_S)
	await wait_physics_frames(10)
	var bomb: Projectile = throws[0]["bomb"]
	var flown := bomb.get_distance_flown()
	paused = true
	var frozen_at := bomb.global_position
	await wait_physics_frames(90)
	check(is_instance_valid(bomb) and bomb.global_position == frozen_at and bomb.get_distance_flown() == flown,
			"1.5 s of tree pause (GAME OVER, the menus): the bomb hangs in the air")
	paused = false
	await wait_until(func() -> bool: return not throws[0]["stops"].is_empty(), "the bomb to land", 90)
	check_near("unpaused, it flies on and still lands 240 px away", throws[0]["stops"][0]["position"].x - carl.global_position.x, RANGE, 0.01)

	var explosion := EXPLOSION_SCENE.instantiate() as AreaDamage
	_arena.add_child(explosion)
	explosion.global_position = Vector2(0, 300)
	explosion.detonate()
	await wait_physics_frames(5)
	paused = true
	await wait_physics_frames(60)
	check(is_instance_valid(explosion), "an explosion's flash stays while paused (1 s)")
	paused = false
	await wait_physics_frames(FLASH_TICKS)
	check(not is_instance_valid(explosion), "and ends once play goes on")

	await wait_seconds(1.2)
	throws.clear()
	menu.open()
	await tap_key(KEY_DOWN)
	check(menu.get_selected_action() == BOMB, "the menu's selection is the Blast Bomb")
	await hold_keys([KEY_S], 90)
	check(throws.is_empty() and game_state().inventory.get_quantity(BOMB) == 4 and game_state().action_slots.get_action(S) == BOMB,
			"with the menu open, S throws nothing (it only keeps the bomb on S)")
	send_key(KEY_S, true)
	menu.close()
	await wait_physics_frames(90)
	check(throws.is_empty(), "closing the menu with S held throws nothing", "%d thrown" % throws.size())
	send_key(KEY_S, false)
	await wait_physics_frames(2)
	await hold_keys([KEY_S], 30)
	check(throws.size() == 1, "after the pause: exactly one throw, no burst", "%d thrown" % throws.size())

	await wait_seconds(1.2)
	throws.clear()
	carl.health.take_damage(1000)
	paused = true
	await hold_keys([KEY_S], 90)
	check(throws.is_empty() and game_state().inventory.get_quantity(BOMB) == 3, "at GAME OVER (Carl down, game frozen) S throws nothing")
	paused = false


func _check_hud_and_menu() -> void:
	print("-- HUD and menu")
	var carl := _new_arena_with_bombs(0, S)
	carl.facing_direction = Vector2.RIGHT
	var state := game_state()
	var menu := _add_menu()
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_action_slots(state.action_slots, state.inventory)
	var slot_bar: Label = hud.get_node("%ActionSlotsLabel")
	await tap_key(KEY_SPACE)
	check(not _rows(menu, "%ActionList").any(func(row: String) -> bool: return row.contains("Blast Bomb")), "with none, the menu has no bomb")
	await tap_key(KEY_SPACE)
	carl.collect_item(BOMB, 2)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)", "Blast Bomb x2   (no slot)"], "after collecting 2: 'Blast Bomb x2'",
			str(_rows(menu, "%ActionList")))
	await tap_key(KEY_DOWN)
	check(menu.get_node("%DetailsLabel").text == BOMB.description, "the menu describes it")
	await tap_key(KEY_S)
	check(_rows(menu, "%SlotList") == ["W   —", "A   —", "S   Blast Bomb x2", "D   Fists"], "S assigns it", str(_rows(menu, "%SlotList")))
	await tap_key(KEY_SPACE)
	check(slot_bar.text == "W: —   A: —   S: Blast Bomb x2   D: Fists", "the HUD: S: Blast Bomb x2", slot_bar.text)
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	check(slot_bar.text == "W: —   A: —   S: Blast Bomb x1   D: Fists", "after one throw: S: Blast Bomb x1", slot_bar.text)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["Fists   (on D)", "> Blast Bomb x1   (on S)"], "the menu: 'Blast Bomb x1 (on S)'",
			str(_rows(menu, "%ActionList")))
	await tap_key(KEY_SPACE)
	await wait_seconds(1.2)
	await tap_key(KEY_S)
	check(slot_bar.text == "W: —   A: —   S: —   D: Fists", "after the last throw: S: —", slot_bar.text)
	await tap_key(KEY_SPACE)
	check(_rows(menu, "%ActionList") == ["> Fists   (on D)"] and _rows(menu, "%SlotList")[2] == "S   —",
			"the menu no longer lists it, and S is empty", str(_rows(menu, "%ActionList")))
	await tap_key(KEY_SPACE)


func _check_loot_drop() -> void:
	print("-- A LootDrop leaves Blast Bomb x2 where its enemy dies")
	var carl := _new_arena_with_bombs(0, S)
	var inventory: Inventory = game_state().inventory
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	var blob := _spawn_blob(Vector2(200, 0), 30, false, true)
	var loot: LootDrop = blob.get_node("LootDrop")
	var drops := []
	loot.dropped.connect(func(pickup: ItemPickup) -> void: drops.append(pickup))
	await wait_physics_frames(2)
	check(loot.pickup == null and not loot.has_dropped() and _pickups().is_empty(), "while it lives, nothing is dropped")
	blob.death_fade_time = 3.0
	var died_at := blob.global_position
	blob.get_node("Hurtbox").take_hit(30)
	check(blob.health.is_dead() and changes[0] == 0 and inventory.get_quantity(BOMB) == 0,
			"its death gives Carl nothing by itself")
	await wait_physics_frames(2)
	var pickups := _pickups()
	check(pickups.size() == 1 and drops.size() == 1 and drops[0] == pickups[0] and loot.pickup == pickups[0],
			"one pickup appears", "%d pickups" % pickups.size())
	if pickups.size() != 1:
		return
	var pickup: ItemPickup = pickups[0]
	check(pickup.global_position == died_at, "exactly where the blob died", str(pickup.global_position))
	check(pickup.item == BOMB and pickup.quantity == 2 and pickup.get_node("Label").text == "Blast Bomb x2"
			and pickup.get_node("Marker/Icon").visible and pickup.get_node("Marker/Icon").texture == BOMB.icon,
			"it is an ordinary pickup: Blast Bomb x2, with the bomb icon", pickup.get_node("Label").text)
	check(pickup.get_parent() == blob.get_parent(), "it belongs to the level (the blob's parent), not to the blob")
	await wait_seconds(3.5)
	check(not is_instance_valid(blob) and is_instance_valid(pickup) and inventory.get_quantity(BOMB) == 0,
			"the blob fades away; the pickup stays, still not collected")

	# Donut, another enemy, a stone and a bomb over it take nothing.
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = pickup.position
	_arena.add_child(donut)
	var other := _spawn_blob(pickup.position + Vector2(0, 6))
	var spitter := _spawn_spitter(pickup.position + Vector2(0, -6))
	await wait_seconds(0.5)
	check(is_instance_valid(pickup) and inventory.get_quantity(BOMB) == 0 and changes[0] == 0,
			"Donut and two enemies standing on it do not take it")
	other.queue_free()
	spitter.queue_free()
	donut.queue_free()
	await wait_physics_frames(2)
	var stone := STONE_SCENE.instantiate() as Projectile
	_arena.add_child(stone)
	stone.launch(pickup.position + Vector2(-100, 0), Vector2.RIGHT)
	var bomb := BOMB_PROJECTILE_SCENE.instantiate() as Projectile
	_arena.add_child(bomb)
	bomb.launch(pickup.position + Vector2(0, 100), Vector2.UP)
	await wait_seconds(1.5)
	check(is_instance_valid(pickup) and inventory.get_quantity(BOMB) == 0 and changes[0] == 0,
			"a stone and a bomb flying over it do not take it either")
	await walk_carl_to(carl, pickup.position)
	check(inventory.get_quantity(BOMB) == 2 and changes[0] == 1, "Carl walking over it gets exactly 2", str(inventory.get_quantity(BOMB)))
	await wait_physics_frames(2)
	check(not is_instance_valid(pickup) and _pickups().is_empty(), "the pickup disappears")
	await hold_keys([KEY_LEFT], 30)
	await hold_keys([KEY_RIGHT], 30)
	check(inventory.get_quantity(BOMB) == 2 and changes[0] == 1, "walking over the spot again gives nothing more")


func _check_loot_drop_collectors() -> void:
	print("-- One drop, two collectors; one drop per enemy")
	var carl := _new_arena_with_bombs(0, S)
	var other_carl: CharacterBody2D = CARL_SCENE.instantiate()
	var other_inventory := Inventory.new()
	other_inventory.reset([FISTS])
	other_carl.inventory = other_inventory
	other_carl.position = Vector2(-60, 40)
	_arena.add_child(other_carl)
	var blob := _spawn_blob(Vector2(0, 80), 30, false, true)
	await wait_physics_frames(2)
	blob.get_node("Hurtbox").take_hit(30)
	await wait_physics_frames(2)
	var pickups := _pickups()
	if pickups.size() != 1:
		check(false, "a drop appeared")
		return
	carl.teleport_to(pickups[0].position + Vector2(-4, 0))
	other_carl.teleport_to(pickups[0].position + Vector2(4, 0))
	await wait_physics_frames(3)
	var total: int = game_state().inventory.get_quantity(BOMB) + other_inventory.get_quantity(BOMB)
	check(total == 2 and _pickups().is_empty(), "two collectors touching it at once: only 2 bombs in all", "%d" % total)
	other_carl.queue_free()

	var twice := _spawn_blob(Vector2(0, -120), 30, false, true)
	await wait_physics_frames(2)
	twice.get_node("Hurtbox").take_hit(30)
	# Announcing the death again (it cannot happen in the game) still drops only once.
	twice.health.died.emit()
	await wait_physics_frames(2)
	check(_pickups().size() == 1, "an enemy whose death is announced twice drops once", "%d pickups" % _pickups().size())


func _check_loot_drop_other_enemies() -> void:
	print("-- Any enemy can carry a drop; a blast kill drops it too")
	var carl := _new_arena_with_bombs(0, S)
	var spitter := _spawn_spitter(Vector2(200, 100), false, true)
	await wait_physics_frames(2)
	spitter.get_node("Hurtbox").take_hit(30)
	await wait_physics_frames(2)
	check(_pickups().size() == 1 and _pickups()[0].global_position == Vector2(200, 100), "a Spitting Blob with a LootDrop drops it")
	for pickup in _pickups():
		pickup.queue_free()
	await wait_physics_frames(2)

	var blob := _spawn_blob(Vector2(120, 0), 20, false, true)
	carl.collect_item(BOMB, 1)
	game_state().action_slots.assign(BOMB, S)
	carl.facing_direction = Vector2.RIGHT
	await wait_physics_frames(2)
	await tap_key(KEY_S)
	await wait_physics_frames(40)
	check(blob.health.is_dead() and _pickups().size() == 1 and game_state().inventory.get_quantity(BOMB) == 0,
			"a 20 HP blob killed by a thrown bomb drops Blast Bomb x2; Carl has none until he collects it")


func _check_other_attacks_unchanged() -> void:
	print("-- The Bat and the Slingshot are unchanged")
	var carl := _new_arena_with_bombs(0, S)
	carl.collect_item(BAT, 1)
	carl.collect_item(SLINGSHOT, 1)
	game_state().action_slots.assign(BAT, S)
	game_state().action_slots.assign(SLINGSHOT, W)
	carl.facing_direction = Vector2.RIGHT
	var blob := _spawn_blob(Vector2(50, 0), 60)
	var damage_taken := _record_damage(blob)
	await wait_physics_frames(2)
	var start := blob.global_position
	await tap_key(KEY_S)
	await wait_until(func() -> bool: return not blob.is_knocked_back(), "the push to end", 30)
	check(damage_taken == [20] and (blob.global_position - start).distance_to(Vector2(80, 0)) < 0.5,
			"the Bat: 20 damage and exactly 80 px of knockback", "%s, %s" % [damage_taken, blob.global_position - start])
	var pushed_to := blob.global_position
	await tap_key(KEY_W)
	await wait_physics_frames(30)
	check(damage_taken == [20, 10] and blob.global_position == pushed_to, "a stone: 10 damage, no push", str(damage_taken))


## Starts an empty arena and a new run with Carl at the origin, carrying `count` Blast Bombs in
## `slot` (Fists stay on D).
func _new_arena_with_bombs(count: int, slot: StringName) -> CharacterBody2D:
	var arena := Node2D.new()
	root.add_child(arena)
	if _arena != null:
		_arena.free()
	# An earlier check may have ended paused: never start the next one paused.
	paused = false
	_arena = arena
	var state := game_state()
	state.start_new_run()
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	_arena.add_child(carl)
	carl.inventory = state.inventory
	carl.action_slots = state.action_slots
	if count > 0:
		carl.collect_item(BOMB, count)
		state.action_slots.assign(BOMB, slot)
	return carl


## Records each bomb Carl throws: {tick, bomb, direction, from, stops: [{tick, position,
## collider}], explosions: [{position, targets}]}.
func _record_throws(carl: CharacterBody2D) -> Array:
	var throws := []
	var launcher := carl.get_action_performer(BOMB) as ProjectileLauncher
	if launcher == null:
		return throws
	launcher.fired.connect(func(bomb: Projectile) -> void:
		var thrown := {"tick": Engine.get_physics_frames(), "bomb": bomb, "direction": bomb.direction,
				"from": bomb.global_position, "stops": [], "explosions": []}
		bomb.stopped.connect(func(collider: Object) -> void:
			thrown["stops"].append({"tick": Engine.get_physics_frames(), "position": bomb.global_position, "collider": collider}))
		bomb.get_node("DetonateOnStop").exploded.connect(func(explosion: AreaDamage, targets: Array[Hurtbox]) -> void:
			thrown["explosions"].append({"position": explosion.global_position, "targets": targets}))
		throws.append(thrown))
	return throws


## An explosion (the Blast Bomb's) at `at`, detonated at once. Returns the Hurtboxes it hit.
func _explode_at(at: Vector2) -> Array[Hurtbox]:
	var explosion := EXPLOSION_SCENE.instantiate() as AreaDamage
	_arena.add_child(explosion)
	explosion.global_position = at
	return explosion.detonate()


func _record_damage(enemy: Enemy) -> Array:
	var taken := []
	enemy.health.damaged.connect(func(amount: int) -> void: taken.append(amount))
	return taken


## Every item pickup in the arena.
func _pickups() -> Array:
	return _arena.get_children().filter(func(node: Node) -> bool: return node is ItemPickup and not node.is_queued_for_deletion())


## Walks Carl in a straight line to `target`, like a player holding the arrow keys.
func walk_carl_to(carl: CharacterBody2D, target: Vector2) -> void:
	for i in 240:
		if carl.global_position.distance_to(target) <= 3.0:
			break
		steer(carl.global_position.direction_to(target))
		await physics_frame
	steer(Vector2.ZERO)
	await wait_physics_frames(2)


## A Gelatinous Blob. Unless `active`, it never moves. With `loot` it carries a LootDrop of
## Blast Bomb x2, like Floor 6's.
func _spawn_blob(at: Vector2, max_health: int = 30, active: bool = false, loot: bool = false) -> Enemy:
	var blob: Enemy = BLOB_SCENE.instantiate()
	if not active:
		blob.detection_range = 0.0
		blob.chase_range = 0.0
	blob.get_node("Health").max_health = max_health
	blob.position = at
	if loot:
		blob.add_child(_new_loot_drop())
	_arena.add_child(blob)
	return blob


## A Spitting Blob. Unless `active`, it never moves or spits.
func _spawn_spitter(at: Vector2, active: bool = false, loot: bool = false) -> Enemy:
	var spitter: Enemy = SPITTER_SCENE.instantiate()
	if not active:
		spitter.detection_range = 0.0
		spitter.chase_range = 0.0
	spitter.position = at
	if loot:
		spitter.add_child(_new_loot_drop())
	_arena.add_child(spitter)
	return spitter


func _new_loot_drop() -> LootDrop:
	var loot := LootDrop.new()
	loot.name = "LootDrop"
	loot.item = BOMB
	loot.quantity = 2
	return loot


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
