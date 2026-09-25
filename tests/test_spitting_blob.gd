extends "res://tests/support/game_test.gd"
## Phase 7 Spitting Blob and enemy projectile (spit glob) checks, in arenas without a level:
## - its numbers: 30 HP; detection 360 px, gives up beyond 480 px; keeps 180-280 px away; spits
##   at most 320 px far, every 1.5 s; the glob: 10 damage, 240 px/s, 384 px, hurts player_hurtbox
##   only, stopped by world; the scene has no touch attack;
## - it does nothing until Carl comes within 360 px, then closes in and spits once he is within
##   320 px; it holds at 280 px and backs away when he comes closer than 180 px;
## - touching it never hurts Carl: only its globs do;
## - line of sight: a wall between it and Carl stops it spitting (no glob is wasted on the wall);
##   as soon as Carl is in plain sight again it spits;
## - a glob hurts Carl exactly 10, once, and disappears; walls stop it (Carl behind one is safe);
##   it flies through Donut, other enemies, pickups and stairs without affecting them, never hurts
##   the blob that spat it, and disappears after 384 px (96 ticks);
## - cadence: one glob per shot, exactly 1.5 s (90 ticks) apart while Carl stays in sight, and no
##   burst when he comes back into sight after hiding;
## - Carl's weapons: each Slingshot stone takes exactly 10 of its 30 HP (three kill it, and a stone
##   still hits a Gelatinous Blob); Fists hit it only in the direction Carl faces;
## - the action menu: while it is open the blob and the Spitting Blob stand still, nothing is spat,
##   globs and stones in flight freeze; closing it resumes everything, with no free glob, no burst
##   of saved-up cooldown and no free stone.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_spitting_blob.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/enemies/spitting_blob.tscn")
const GLOB_SCENE: PackedScene = preload("res://scenes/projectiles/spit_glob.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/props/item_pickup.tscn")
const STAIRS_SCENE: PackedScene = preload("res://scenes/props/stairs.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
## Canonical Phase 7 numbers.
const MAX_HP := 30
const GLOB_DAMAGE := 10
const SPIT_COOLDOWN_TICKS := 90  # 1.5 s at 60 ticks per second
const GLOB_SPEED := 240.0
const GLOB_RANGE := 384.0
const PLAYER_HURTBOX := 16
const ENEMY_HURTBOX := 32

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_numbers()
	await _check_detection_and_distance()
	await _check_no_touch_damage()
	await _check_line_of_sight()
	await _check_glob_hits_carl_once()
	await _check_glob_and_walls()
	await _check_glob_leaves_others_alone()
	await _check_glob_range()
	await _check_cadence()
	await _check_carls_weapons()
	await _check_menu_pause()
	finish()


func _check_numbers() -> void:
	print("-- The Spitting Blob's numbers")
	var spitter: Enemy = SPITTER_SCENE.instantiate()
	var launcher: ProjectileLauncher = spitter.get_node("SpitLauncher")
	check((spitter.get_node("Health") as Health).max_health == MAX_HP, "30 HP")
	check(is_equal_approx(spitter.detection_range, 360.0) and is_equal_approx(spitter.chase_range, 480.0),
			"it notices Carl within 360 px and gives up beyond 480 px")
	check(is_equal_approx(spitter.preferred_min_distance, 180.0) and is_equal_approx(spitter.preferred_max_distance, 280.0)
			and is_equal_approx(spitter.max_firing_distance, 320.0), "it keeps 180-280 px away and spits up to 320 px")
	check(is_equal_approx(launcher.cooldown, 1.5) and launcher.projectile_scene == GLOB_SCENE, "it spits a spit glob every 1.5 s at most")
	check(spitter.find_children("*", "MeleeAttack", true, false).is_empty(), "it has no touch attack")
	check(spitter.collision_layer == 8 and spitter.get_node("Hurtbox").collision_layer == ENEMY_HURTBOX,
			"its body is on the enemy layer and its Hurtbox on enemy_hurtbox, like the Gelatinous Blob's")
	spitter.free()
	var glob: Projectile = GLOB_SCENE.instantiate()
	check(glob.damage == GLOB_DAMAGE and is_equal_approx(glob.speed, GLOB_SPEED) and is_equal_approx(glob.max_distance, GLOB_RANGE),
			"the glob: 10 damage, 240 px/s, 384 px")
	check(glob.target_layers == PLAYER_HURTBOX and glob.blocking_layers == 1, "it hurts player_hurtbox only and is stopped by world")
	glob.free()


func _check_detection_and_distance() -> void:
	print("-- It waits for Carl, closes in, spits within 320 px and keeps its distance")
	var carl := _new_arena_with_carl()
	carl.health.set_health(1000, 1000)
	var spitter := _spawn_spitter(Vector2(400, 0), carl, true)
	var shots := _record_shots(spitter)
	await wait_seconds(3.0)
	check(not spitter.is_active() and shots.is_empty() and spitter.global_position == Vector2(400, 0),
			"Carl 400 px away in plain sight: it does not notice him, move or spit")

	carl.teleport_to(Vector2(50, 0))
	await wait_physics_frames(2)
	check(spitter.is_active() and shots.is_empty(), "Carl 350 px away: it notices him, but he is too far to spit at")
	await wait_until(func() -> bool: return not shots.is_empty(), "the first glob", 120)
	var first_distance: float = shots[0]["distance"] if not shots.is_empty() else 0.0
	check(first_distance <= 320.0 and first_distance > 310.0, "it closes in and spits as soon as he is within 320 px",
			"spat from %.1f px" % first_distance)
	await wait_seconds(2.0)
	var held_at := spitter.global_position
	await wait_seconds(0.5)
	var distance := spitter.global_position.distance_to(carl.global_position)
	check(distance > 278.0 and distance <= 281.0 and spitter.global_position == held_at,
			"then it holds its position at about 280 px", "%.1f px" % distance)

	carl.teleport_to(spitter.global_position + Vector2(-100, 0))
	await wait_seconds(2.5)
	distance = spitter.global_position.distance_to(carl.global_position)
	check(distance >= 179.0 and distance < 200.0, "Carl 100 px away: it backs off to about 180 px", "%.1f px" % distance)

	carl.teleport_to(spitter.global_position + Vector2(-500, 0))
	await wait_physics_frames(2)
	var shots_before := shots.size()
	await wait_seconds(2.0)
	check(not spitter.is_active() and shots.size() == shots_before, "Carl 500 px away: it gives up and stops spitting")


func _check_no_touch_damage() -> void:
	print("-- Touching it never hurts Carl; only its globs do")
	var carl := _new_arena_with_carl()
	var spitter := _spawn_spitter(Vector2(26, 0), carl)
	spitter.max_firing_distance = 0.0  # it never spits
	await wait_seconds(3.0)
	check(carl.health.current_health == 100, "3 s pressed against a Spitting Blob that does not spit: Carl is unhurt",
			"HP %d" % carl.health.current_health)

	carl = _new_arena_with_carl()
	spitter = _spawn_spitter(Vector2(26, 0), carl)
	var hits := _record_hits(spitter, carl)
	var damage := []
	carl.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	await wait_seconds(3.2)
	check(damage.size() == 3 and hits[0] == 3 and damage.all(func(amount: int) -> bool: return amount == GLOB_DAMAGE),
			"pressed against one that spits: every 10 HP Carl loses is a glob that hit him (3 in 3 s)",
			"damage %s, globs on Carl %d" % [damage, hits[0]])


func _check_line_of_sight() -> void:
	print("-- Line of sight")
	var carl := _new_arena_with_carl()
	var wall := _add_wall(Rect2(100, -100, 20, 200))
	var spitter := _spawn_spitter(Vector2(250, 0), carl)
	var shots := _record_shots(spitter)
	var wall_hits := [0]
	# The wall is freed later on, so it is recognised by its id.
	var wall_id := wall.get_instance_id()
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void:
		glob.stopped.connect(func(collider: Object) -> void:
			if collider != null and collider.get_instance_id() == wall_id:
				wall_hits[0] += 1))
	await wait_seconds(4.0)
	check(spitter.is_active() and not spitter.has_line_of_sight_to(carl.global_position), "Carl 250 px away behind a wall: it sees the wall")
	check(shots.is_empty() and wall_hits[0] == 0, "in 4 s it spits nothing: no glob is wasted on the wall")

	carl.teleport_to(Vector2(60, 180))
	var moved_at := Engine.get_physics_frames()
	await wait_physics_frames(3)
	check(shots.size() == 1 and shots[0]["tick"] - moved_at <= 2, "once Carl steps out into plain sight, it spits at once")
	if shots.size() == 1:
		var aim: Vector2 = (shots[0]["glob"] as Projectile).direction if is_instance_valid(shots[0]["glob"]) else Vector2.ZERO
		check(aim.is_equal_approx(Vector2(250, 0).direction_to(Vector2(60, 180))), "straight at where he stands", str(aim))
	await wait_seconds(2.0)
	check(shots.size() == 2 and wall_hits[0] == 0, "and keeps spitting while he stays in sight", "%d globs" % shots.size())

	# Removing the cover works the same way as stepping out.
	carl.teleport_to(Vector2.ZERO)
	await wait_seconds(2.0)
	var shots_behind_wall := shots.size()
	wall.free()
	await wait_physics_frames(3)
	check(shots.size() == shots_behind_wall + 1, "with the wall gone, it spits again")


func _check_glob_hits_carl_once() -> void:
	print("-- A glob deals exactly 10 to Carl, once, and disappears")
	var carl := _new_arena_with_carl()
	var spitter := _spawn_spitter(Vector2(250, 0), carl)
	var shots := _record_shots(spitter)
	var damage := []
	carl.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	await wait_until(func() -> bool: return not shots.is_empty(), "the first glob")
	var glob: Projectile = shots[0]["glob"]
	var stops := []
	glob.stopped.connect(func(collider: Object) -> void: stops.append(collider))
	await wait_until(func() -> bool: return not damage.is_empty(), "the glob to reach Carl")
	check(damage == [GLOB_DAMAGE] and carl.health.current_health == 90, "the glob takes exactly 10 HP", str(damage))
	check(stops == [carl.get_node("Hurtbox")] and not is_instance_valid(glob), "it stops on Carl's Hurtbox and is gone at once")
	await wait_physics_frames(20)
	check(damage == [GLOB_DAMAGE] and shots.size() == 1, "it never hurts him a second time")


func _check_glob_and_walls() -> void:
	print("-- Walls stop globs")
	var carl := _new_arena_with_carl()
	var wall := _add_wall(Rect2(100, -100, 20, 200))
	carl.teleport_to(Vector2(160, 0))
	# Let the physics engine move Carl's Hurtbox before launching from where he stood.
	await wait_physics_frames(2)
	var glob := _launch_glob(Vector2.ZERO, Vector2.RIGHT)
	var stops := _record_stop(glob)
	await wait_seconds(1.0)
	check(stops.size() == 1 and stops[0][0] == wall and absf(stops[0][1].x - 100.0) < 0.5, "a glob stops at the wall's face", str(stops))
	check(carl.health.current_health == 100 and not is_instance_valid(glob), "Carl behind the wall is unhurt, and the glob is gone")

	# A real glob: the wall appears between Carl and a glob already in flight.
	carl = _new_arena_with_carl()
	var spitter := _spawn_spitter(Vector2(300, 0), carl)
	var shots := _record_shots(spitter)
	await wait_until(func() -> bool: return not shots.is_empty(), "a glob")
	stops = _record_stop(shots[0]["glob"])
	wall = _add_wall(Rect2(150, -100, 20, 200))
	await wait_seconds(1.0)
	check(stops.size() == 1 and stops[0][0] == wall and absf(stops[0][1].x - 170.0) < 0.5 and carl.health.current_health == 100,
			"a glob in flight toward Carl stops at a wall in between; he is unhurt", str(stops))


func _check_glob_leaves_others_alone() -> void:
	print("-- Globs fly past Donut, enemies, pickups and stairs")
	var carl := _new_arena_with_carl()
	# In the line of fire, from Carl outward: stairs, a pickup, another Spitting Blob (which never
	# notices Carl), a Gelatinous Blob (idle), Donut, then the Spitting Blob that spits.
	var stairs: Area2D = STAIRS_SCENE.instantiate()
	stairs.destination_scene_path = "res://scenes/levels/floor_01.tscn"
	stairs.position = Vector2(60, 0)
	_arena.add_child(stairs)
	var pickup: Area2D = PICKUP_SCENE.instantiate()
	pickup.item = POTION
	pickup.quantity = 2
	pickup.position = Vector2(110, 0)
	_arena.add_child(pickup)
	var other_spitter := _spawn_spitter(Vector2(160, 0), carl)
	other_spitter.detection_range = 0.0
	var blob: Enemy = BLOB_SCENE.instantiate()
	blob.target = carl
	blob.detection_range = 0.0
	blob.position = Vector2(215, 0)
	_arena.add_child(blob)
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = Vector2(270, 0)
	_arena.add_child(donut)
	donut.set_physics_process(false)
	var spitter := _spawn_spitter(Vector2(310, 0), carl)
	var shots := _record_shots(spitter)
	var scene_before := current_scene
	await wait_until(func() -> bool: return carl.health.current_health < 100, "the glob to reach Carl")
	await wait_physics_frames(2)
	check(shots.size() == 1 and carl.health.current_health == 90, "the glob flies past everything in between and hits Carl")
	check(blob.health.current_health == MAX_HP and other_spitter.health.current_health == MAX_HP,
			"it hurts neither the Gelatinous Blob nor another Spitting Blob in its way")
	check(spitter.health.current_health == MAX_HP, "nor the Spitting Blob that spat it")
	check(is_instance_valid(donut) and donut.get_node_or_null("Health") == null and donut.global_position == Vector2(270, 0),
			"Donut is unaffected: she has nothing it could damage")
	check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and game_state().inventory.get_quantity(POTION) == 0,
			"the pickup is not collected")
	check(current_scene == scene_before and not stairs._is_transitioning, "the stairs are not triggered")

	# Even a glob told to hurt enemies too never hurts the blob that spat it. It starts inside that
	# blob's own Hurtbox, so this is the only thing that saves it.
	var own_hits := [0]
	spitter.health.damaged.connect(func(_amount: int) -> void: own_hits[0] += 1)
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void: glob.target_layers = PLAYER_HURTBOX | ENEMY_HURTBOX,
			CONNECT_ONE_SHOT)
	await wait_until(func() -> bool: return shots.size() == 2, "the second glob", 120)
	await wait_seconds(1.0)
	check(shots.size() == 2 and not is_instance_valid(shots[1]["glob"]), "the second glob is gone")
	check(own_hits[0] == 0 and spitter.health.current_health == MAX_HP,
			"a glob that may hurt enemies still never hurts its own source")
	check(blob.health.current_health == MAX_HP - GLOB_DAMAGE and carl.health.current_health == 90,
			"(such a glob hits the first other enemy in its way: the target layers decide who is hurt)")


func _check_glob_range() -> void:
	print("-- A glob disappears after 384 px")
	_new_arena_with_carl()
	var glob := _launch_glob(Vector2(0, 300), Vector2.RIGHT)
	var stops := _record_stop(glob)
	var ticks := 1
	var x_at_tick := {}
	while is_instance_valid(glob) and ticks < 200:
		x_at_tick[ticks] = glob.global_position.x
		await physics_frame
		ticks += 1
	check(stops.size() == 1 and stops[0][0] == null and absf(stops[0][1].x - GLOB_RANGE) < 0.5,
			"with nothing in the way it stops by itself, 384 px away", str(stops))
	check(ticks == 97, "it flies for 96 ticks (1.6 s), then is removed", "%d ticks" % (ticks - 1))
	if x_at_tick.has(5) and x_at_tick.has(15):
		check_near("speed: pixels flown in 10 ticks (240 px/s = 4 px per tick)", x_at_tick[15] - x_at_tick[5], 40.0, 0.01)


func _check_cadence() -> void:
	print("-- One glob every 1.5 s")
	var carl := _new_arena_with_carl()
	carl.health.set_health(1000, 1000)
	var spitter := _spawn_spitter(Vector2(250, 0), carl)
	var shots := _record_shots(spitter)
	var globs_added := [0]
	_arena.child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			globs_added[0] += 1)
	await wait_seconds(6.1)
	var gaps := []
	for i in range(1, shots.size()):
		gaps.append(shots[i]["tick"] - shots[i - 1]["tick"])
	check(shots.size() == 5 and gaps.all(func(gap: int) -> bool: return gap == SPIT_COOLDOWN_TICKS),
			"6 s with Carl in sight: 5 globs, exactly 90 ticks apart", "%d globs, gaps %s" % [shots.size(), gaps])
	check(globs_added[0] == shots.size(), "each shot creates exactly one glob", "%d globs for %d shots" % [globs_added[0], shots.size()])
	check(carl.health.current_health == 1000 - GLOB_DAMAGE * 4, "each glob that arrived took 10 HP", "HP %d" % carl.health.current_health)

	# Hiding for a while never lets it save up shots.
	var wall := _add_wall(Rect2(100, -100, 20, 200))
	await wait_seconds(4.0)
	var shots_before := shots.size()
	wall.free()
	await wait_seconds(1.0)
	check(shots.size() == shots_before + 1, "after 4 s behind a wall, coming back into sight gives one glob, not a burst",
			"%d globs" % (shots.size() - shots_before))


func _check_carls_weapons() -> void:
	print("-- Carl's Slingshot and Fists against the Spitting Blob")
	var carl := _new_arena_with_carl()
	carl.collect_item(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	var spitter := _spawn_spitter(Vector2(150, 0), carl)
	spitter.max_firing_distance = 0.0
	spitter.death_fade_time = 3.0
	var damage := []
	spitter.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	var died := [0]
	spitter.health.died.connect(func() -> void: died[0] += 1)
	var stones := []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(fired_stone: Projectile) -> void: stones.append(fired_stone))
	await tap_key(KEY_RIGHT)
	for shot in 3:
		await tap_key(KEY_W)
		await wait_until(func() -> bool: return damage.size() > shot, "stone %d to hit" % (shot + 1), 60)
		check(damage.size() == shot + 1 and damage[shot] == 10 and spitter.health.current_health == MAX_HP - 10 * (shot + 1),
				"Slingshot stone %d takes exactly 10 HP" % (shot + 1), "HP %d" % spitter.health.current_health)
		await wait_seconds(0.6)
	check(stones.size() == 3 and spitter.health.is_dead() and died[0] == 1, "three stones kill the 30 HP Spitting Blob")
	check(carl.health.current_health == 100, "Carl is unhurt by his own stones")
	var blob: Enemy = BLOB_SCENE.instantiate()
	blob.target = carl
	blob.detection_range = 0.0
	blob.position = Vector2(150, 0)
	_arena.add_child(blob)
	await wait_seconds(0.6)
	await tap_key(KEY_W)
	await wait_seconds(0.5)
	check(blob.health.current_health == MAX_HP - 10, "a stone still takes 10 from a Gelatinous Blob")

	carl = _new_arena_with_carl()
	spitter = _spawn_spitter(Vector2(40, 0), carl)
	spitter.max_firing_distance = 0.0
	await tap_key(KEY_LEFT)
	await tap_key(KEY_D)
	check(spitter.health.current_health == MAX_HP, "Fists facing away miss it")
	await wait_seconds(0.5)
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_D)
	check(spitter.health.current_health == MAX_HP - 10, "Fists facing it take 10 HP", "HP %d" % spitter.health.current_health)


func _check_menu_pause() -> void:
	print("-- The action menu freezes enemies and everything in flight")
	var carl := _new_arena_with_carl()
	carl.health.set_health(1000, 1000)
	carl.collect_item(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	var menu: CanvasLayer = MENU_SCENE.instantiate()
	_arena.add_child(menu)
	menu.setup(game_state().inventory, game_state().action_slots)
	var blob: Enemy = BLOB_SCENE.instantiate()
	blob.target = carl
	blob.position = Vector2(-180, 100)
	blob.get_node("Health").max_health = 1000
	_arena.add_child(blob)
	var spitter := _spawn_spitter(Vector2(330, 0), carl, true)
	spitter.get_node("Health").max_health = 1000
	var shots := _record_shots(spitter)
	var stones := []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(fired_stone: Projectile) -> void: stones.append(fired_stone))
	await tap_key(KEY_RIGHT)
	# Wait for a glob in flight, then fire a stone and open the menu while both fly.
	await wait_until(func() -> bool: return not shots.is_empty(), "a glob")
	await wait_physics_frames(10)
	await tap_key(KEY_W)
	await wait_physics_frames(3)
	var glob: Projectile = shots[0]["glob"]
	var stone: Projectile = stones[0] if stones.size() == 1 else null
	if not is_instance_valid(glob) or stone == null or not is_instance_valid(stone):
		check(false, "a glob and a stone are in flight when the menu opens")
		return
	var last_shot_tick: int = shots[0]["tick"]
	await tap_key(KEY_SPACE)
	var opened_at := Engine.get_physics_frames()
	check(menu.is_open() and paused, "Space opens the menu and pauses the game")
	var frozen := [blob.global_position, spitter.global_position, glob.global_position, stone.global_position]
	var hp: int = carl.health.current_health
	check(blob.is_active() and spitter.is_active(), "both enemies were after Carl when the menu opened")
	# Select the Slingshot, so W in the menu keeps it on W (in the menu W only assigns).
	await tap_key(KEY_DOWN)
	await hold_keys([KEY_W], 20)
	await wait_seconds(3.0)
	check(blob.global_position == frozen[0], "the Gelatinous Blob stands still")
	check(spitter.global_position == frozen[1], "the Spitting Blob stands still")
	check(shots.size() == 1, "nothing is spat in 3 s, although its cooldown would have run out twice")
	check(is_instance_valid(glob) and glob.global_position == frozen[2], "the glob in flight freezes")
	check(is_instance_valid(stone) and stone.global_position == frozen[3] and stones.size() == 1,
			"the stone in flight freezes, and W in the menu fires nothing")
	check(carl.health.current_health == hp, "Carl takes no damage")
	check(game_state().action_slots.get_action(ActionSlots.SLOT_W) == SLINGSHOT, "the Slingshot is still on W")

	# Close with W held: no free stone.
	send_key(KEY_W, true)
	await wait_physics_frames(2)
	await tap_key(KEY_SPACE)
	var closed_at := Engine.get_physics_frames()
	check(not menu.is_open() and not paused, "Space closes the menu")
	await wait_until(func() -> bool: return shots.size() == 2, "the next glob", 120)
	send_key(KEY_W, false)
	await wait_physics_frames(2)
	check(stones.size() == 1, "W held while the menu closed fires no free stone")
	check(not is_instance_valid(glob) and not is_instance_valid(stone), "the glob and the stone flew on after the menu closed")
	check(blob.global_position != frozen[0] and spitter.global_position.distance_to(frozen[1]) > 1.0, "both enemies move again")
	if shots.size() == 2:
		# Only unpaused ticks count toward the cooldown: the ticks before the menu opened plus those
		# after it closed make exactly one cooldown. A shot saved up during the pause would come early.
		var running_ticks: int = (opened_at - last_shot_tick) + (shots[1]["tick"] - closed_at)
		check(absi(running_ticks - SPIT_COOLDOWN_TICKS) <= 1,
				"the next glob comes one full cooldown of running time after the last: no free glob on closing",
				"%d running ticks" % running_ticks)
	var count := shots.size()
	await wait_seconds(1.0)
	check(shots.size() == count, "and no burst follows")


## Starts an empty arena (no navigation mesh) and a new run, with Carl at the origin.
func _new_arena_with_carl() -> CharacterBody2D:
	if _arena != null:
		_arena.free()
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


## A Spitting Blob hunting Carl. Unless `moves` is true it stands still (move_speed 0).
func _spawn_spitter(at: Vector2, carl: Node2D, moves: bool = false) -> Enemy:
	var spitter: Enemy = SPITTER_SCENE.instantiate()
	spitter.target = carl
	if not moves:
		spitter.move_speed = 0.0
	spitter.position = at
	_arena.add_child(spitter)
	return spitter


## Records every glob `spitter` spits as {"glob", "tick", "distance" (to its target)}.
func _record_shots(spitter: Enemy) -> Array:
	var shots := []
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void:
		shots.append({"glob": glob, "tick": Engine.get_physics_frames(),
				"distance": spitter.global_position.distance_to(spitter.target.global_position)}))
	return shots


## Counts the globs of `spitter` that stop on Carl's Hurtbox. Returns [count].
func _record_hits(spitter: Enemy, carl: Node) -> Array:
	var hits := [0]
	var hurtbox := carl.get_node("Hurtbox")
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void:
		glob.stopped.connect(func(collider: Object) -> void:
			if collider == hurtbox:
				hits[0] += 1))
	return hits


## Records where `projectile` stops and what it hit, as [collider, position].
func _record_stop(projectile: Projectile) -> Array:
	var stops := []
	projectile.stopped.connect(func(collider: Object) -> void: stops.append([collider, projectile.global_position]))
	return stops


## A spit glob launched by hand from `from` toward `direction`.
func _launch_glob(from: Vector2, direction: Vector2) -> Projectile:
	var glob: Projectile = GLOB_SCENE.instantiate()
	_arena.add_child(glob)
	glob.launch(from, direction)
	return glob


func _add_wall(rect: Rect2) -> StaticBody2D:
	var wall := new_wall(rect)
	_arena.add_child(wall)
	return wall
