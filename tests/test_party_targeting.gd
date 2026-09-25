extends "res://tests/support/game_test.gd"
## Phase 8 enemy targeting between Carl and Donut, in arenas without a level (no navigation
## mesh: enemies move straight, Donut stays where she is put):
## - acquiring: an enemy picks Carl or Donut, whichever valid party member is nearest within its
##   detection range, and nobody when both are farther;
## - no flip-flopping: once it has a target it keeps it while that target stays valid and within
##   chase range, even when the other member is (or keeps becoming) a little closer; it only
##   picks again when the target leaves chase range or is downed;
## - a downed Donut is no longer a valid target: the enemy drops her at once and picks Carl if he
##   is within detection range (or nobody); when she gets up it can pick her again;
## - the Gelatinous Blob chases Donut and its touch takes exactly 10 from her every 0.8 s; each
##   touch hurts one party member only, the nearest, even when it touches both;
## - the Spitting Blob picks Donut, spits only when it can see her (a wall blocks the shot and its
##   view; removing the wall lets it spit at once), keeps its 180-280 px distance from her as from
##   Carl, and stops spitting at her once she is downed; it still spits at Carl as before;
## - globs: 10 damage to Donut or to Carl, only the first party member in the way (the one in
##   front shields the other), once, then gone; a downed Donut does not stop a glob; enemies in
##   the way are never hurt.
## The Blob going around walls to reach Donut is covered by test_enemy_navigation.gd.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_party_targeting.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/enemies/spitting_blob.tscn")
const DOWN_TICKS := 360
const SPIT_TICKS := 90

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	await _check_acquisition()
	await _check_no_flip_flop()
	await _check_downed_donut_is_dropped()
	await _check_recovered_donut_is_picked_again()
	await _check_blob_against_donut()
	await _check_one_touch_one_member()
	await _check_spitter_against_donut()
	await _check_spitter_range_with_donut()
	await _check_globs_hit_the_first_member()
	finish()


func _check_acquisition() -> void:
	print("-- An enemy picks the nearest party member within its detection range")
	var cases := [
		# [Carl's position, Donut's position, expected target, label]
		[Vector2(200, 0), Vector2(600, 0), "Carl", "only Carl within 220 px: it picks Carl"],
		[Vector2(600, 0), Vector2(200, 0), "Donut", "only Donut within 220 px: it picks Donut"],
		[Vector2(-190, 0), Vector2(150, 0), "Donut", "both within 220 px, Donut nearer (150 vs 190): it picks Donut"],
		[Vector2(150, 0), Vector2(-190, 0), "Carl", "both within 220 px, Carl nearer (150 vs 190): it picks Carl"],
		[Vector2(260, 0), Vector2(-240, 0), "", "both farther than 220 px: it picks nobody"],
	]
	for case: Array in cases:
		_new_arena()
		var carl := _spawn_carl(case[0])
		var donut := _spawn_donut(case[1], carl)
		var blob := _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
		blob.move_speed = 0.0
		await wait_physics_frames(2)
		var expected: Node2D = {"Carl": carl, "Donut": donut}.get(case[2])
		check(blob.target == expected and blob.is_active() == (expected != null), case[3],
				String(blob.target.name) if blob.target != null else "nobody")


func _check_no_flip_flop() -> void:
	print("-- Once it has a target, it keeps it")
	_new_arena()
	var carl := _spawn_carl(Vector2(-110, 0))
	var donut := _spawn_donut(Vector2(100, 0), carl)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
	blob.move_speed = 0.0
	await wait_physics_frames(2)
	check(blob.target == donut, "Donut (100 px) is nearer than Carl (110 px): it picks Donut")
	# Carl now keeps stepping 1 px nearer and farther than Donut, every tick, for 2 s.
	var targets := {}
	for i in 120:
		carl.global_position = Vector2(-99.0 if i % 2 == 0 else -101.0, 0)
		await physics_frame
		targets[blob.target] = true
	check(targets.keys() == [donut], "Carl alternating 1 px nearer and farther for 2 s: it stays on Donut every tick",
			str(targets.keys()))
	carl.global_position = Vector2(-40, 0)
	await wait_seconds(0.5)
	check(blob.target == donut, "even with Carl much nearer (40 px) it keeps Donut while she stays within 320 px")
	donut.global_position = Vector2(400, 0)
	await wait_physics_frames(2)
	check(blob.target == carl, "when Donut is farther than its chase range (320 px) it drops her and picks Carl")


func _check_downed_donut_is_dropped() -> void:
	print("-- A downed Donut is dropped at once")
	_new_arena()
	var carl := _spawn_carl(Vector2(-150, 0))
	var donut := _spawn_donut(Vector2(100, 0), carl)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
	blob.move_speed = 0.0
	await wait_physics_frames(2)
	check(blob.target == donut and blob.is_valid_target(donut), "it is after Donut")
	donut.get_node("Hurtbox").take_hit(60)
	check(donut.is_downed() and not blob.is_valid_target(donut), "downed, Donut is no longer a valid target")
	await wait_physics_frames(1)
	check(blob.target == carl, "on the next tick it drops her and picks Carl (150 px away)")
	for i in 120:
		await physics_frame
		if blob.target == donut:
			break
	check(blob.target == carl, "and never goes back to the downed Donut")

	_new_arena()
	carl = _spawn_carl(Vector2(-300, 0))
	donut = _spawn_donut(Vector2(100, 0), carl)
	blob = _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
	blob.move_speed = 0.0
	await wait_physics_frames(2)
	donut.get_node("Hurtbox").take_hit(60)
	await wait_physics_frames(1)
	check(blob.target == null and not blob.is_active(), "with Carl out of range (300 px) it drops her and goes idle")


func _check_recovered_donut_is_picked_again() -> void:
	print("-- When Donut gets up, she can be picked again")
	_new_arena()
	var carl := _spawn_carl(Vector2(-300, 0))
	var donut := _spawn_donut(Vector2(100, 0), carl)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
	blob.move_speed = 0.0
	await wait_physics_frames(2)
	donut.get_node("Hurtbox").take_hit(60)
	await wait_physics_frames(DOWN_TICKS - 5)
	check(donut.is_downed() and blob.target == null, "while she is downed it stays idle")
	await wait_physics_frames(10)
	check(not donut.is_downed() and donut.health.current_health == 30 and blob.target == donut,
			"when she gets up (30 / 60) it picks her again")


func _check_blob_against_donut() -> void:
	print("-- The Gelatinous Blob chases Donut and its touch takes 10 every 0.8 s")
	_new_arena()
	var carl := _spawn_carl(Vector2(-500, 0))
	var donut := _spawn_donut(Vector2(150, 0), carl)
	# Kept still, so she does not scratch the blob back; her own fighting is in test_donut.gd.
	donut.set_physics_process(false)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
	var hits := []
	donut.health.damaged.connect(func(amount: int) -> void: hits.append([Engine.get_physics_frames(), amount]))
	await wait_physics_frames(2)
	var start := blob.global_position
	await wait_seconds(1.0)
	check(blob.target == donut and blob.global_position.x - start.x > 50.0, "it goes for Donut at its usual speed",
			"moved %.1f px in 1 s" % (blob.global_position.x - start.x))
	await wait_until(func() -> bool: return not hits.is_empty(), "the blob to reach Donut", 180)
	await wait_seconds(1.7)
	var gaps := []
	for i in range(1, hits.size()):
		gaps.append(hits[i][0] - hits[i - 1][0])
	check(hits.size() == 3 and hits.all(func(hit: Array) -> bool: return hit[1] == 10) and gaps.all(func(gap: int) -> bool: return gap == 48),
			"its touch takes exactly 10 from Donut every 0.8 s", str(hits))
	check(carl.health.current_health == 100, "Carl, far away, is unhurt")


func _check_one_touch_one_member() -> void:
	print("-- Each touch hurts one party member: the nearest")
	_new_arena()
	var carl := _spawn_carl(Vector2(26, 0))
	var donut := _spawn_donut(Vector2(-22, 0), carl)
	donut.set_physics_process(false)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2.ZERO)
	blob.move_speed = 0.0
	var carl_hits := [0]
	var donut_hits := [0]
	carl.health.damaged.connect(func(_a: int) -> void: carl_hits[0] += 1)
	donut.health.damaged.connect(func(_a: int) -> void: donut_hits[0] += 1)
	await wait_seconds(1.7)
	check(donut_hits[0] == 3 and carl_hits[0] == 0,
			"touching both, each touch hurts only the nearer one (Donut, 22 px; Carl 26 px)", "Donut %d hits, Carl %d" % [donut_hits[0], carl_hits[0]])
	donut.global_position = Vector2(-200, 0)
	await wait_seconds(0.9)
	check(carl_hits[0] == 1 and carl.health.current_health == 90, "with Donut gone, the next touch hurts Carl, 10 as always")


func _check_spitter_against_donut() -> void:
	print("-- The Spitting Blob picks Donut and needs to see her")
	_new_arena()
	var carl := _spawn_carl(Vector2(-700, 0))
	var donut := _spawn_donut(Vector2(250, 0), carl)
	donut.set_physics_process(false)
	donut.health.set_health(1000, 1000)
	var spitter := _spawn_enemy(SPITTER_SCENE, Vector2.ZERO)
	spitter.move_speed = 0.0
	var shots := _record_shots(spitter)
	var wall := new_wall(Rect2(120, -60, 16, 120))
	_arena.add_child(wall)
	await wait_seconds(3.0)
	check(spitter.target == donut and not spitter.has_line_of_sight_to(donut.global_position),
			"Carl far away: it picks Donut (250 px), who is hidden behind a wall")
	check(shots.is_empty() and donut.health.current_health == 1000, "for 3 s it spits nothing at her through the wall")
	wall.free()
	await wait_physics_frames(2)
	check(shots.size() == 1 and shots[0]["target"] == donut, "once the wall is gone it spits at her at once")
	await wait_until(func() -> bool: return donut.health.current_health < 1000, "the glob to reach Donut", 120)
	await wait_physics_frames(1)
	check(donut.health.current_health == 990 and not is_instance_valid(shots[0]["glob"]), "the glob takes exactly 10 from her and is gone")
	await wait_physics_frames(SPIT_TICKS)
	check(shots.size() == 2 and shots[1]["tick"] - shots[0]["tick"] == SPIT_TICKS, "the next glob comes exactly 1.5 s later")

	# A glob already flying at her stops at a wall put in its way.
	await wait_until(func() -> bool: return shots.size() == 3, "a third glob", 120)
	var hp_before: int = donut.health.current_health
	var blocking := new_wall(Rect2(200, -60, 16, 120))
	_arena.add_child(blocking)
	var stopped_on := []
	(shots[2]["glob"] as Projectile).stopped.connect(func(collider: Object) -> void: stopped_on.append(collider))
	await wait_seconds(1.0)
	check(stopped_on == [blocking] and donut.health.current_health == hp_before, "a wall stops a glob flying at Donut; she is unhurt")
	blocking.free()

	# Downed, she is dropped: no more globs at her.
	donut.health.set_health(10, 60)
	await wait_until(func() -> bool: return donut.is_downed(), "a glob to down Donut", 400)
	var shots_when_downed := shots.size()
	await wait_physics_frames(2)
	check(spitter.target == null, "once she is downed it drops her (Carl is far away)")
	await wait_seconds(3.0)
	check(shots.size() == shots_when_downed, "and spits nothing more at her")

	_new_arena()
	carl = _spawn_carl(Vector2(250, 0))
	spitter = _spawn_enemy(SPITTER_SCENE, Vector2.ZERO)
	spitter.move_speed = 0.0
	shots = _record_shots(spitter)
	await wait_until(func() -> bool: return carl.health.current_health < 100, "a glob to reach Carl", 180)
	check(spitter.target == carl and shots.size() == 1 and carl.health.current_health == 90,
			"with Carl the only one near, it picks him and its glob takes 10 from him, as before")


func _check_spitter_range_with_donut() -> void:
	print("-- It keeps 180-280 px from Donut, as from Carl")
	_new_arena()
	var carl := _spawn_carl(Vector2(-900, 0))
	var donut := _spawn_donut(Vector2(340, 0), carl)
	donut.set_physics_process(false)
	donut.health.set_health(1000, 1000)
	var spitter := _spawn_enemy(SPITTER_SCENE, Vector2.ZERO)
	await wait_seconds(4.0)
	var distance := spitter.global_position.distance_to(donut.global_position)
	check(spitter.target == donut and distance <= 280.5 and distance > 270.0, "Donut 340 px away: it closes in to 280 px and holds",
			"%.1f px" % distance)
	donut.global_position = spitter.global_position + Vector2(150, 0)
	await wait_seconds(2.0)
	distance = spitter.global_position.distance_to(donut.global_position)
	check(spitter.target == donut and distance >= 179.5 and distance < 200.0, "Donut 150 px away: it backs off to 180 px",
			"%.1f px" % distance)
	check(donut.health.current_health < 1000, "and it spat at her meanwhile")


func _check_globs_hit_the_first_member() -> void:
	print("-- A glob hits only the first party member in its way, once")
	_new_arena()
	var carl := _spawn_carl(Vector2(200, 0))
	var donut := _spawn_donut(Vector2(240, 0), carl)
	donut.set_physics_process(false)
	var spitter := _spawn_enemy(SPITTER_SCENE, Vector2.ZERO)
	spitter.move_speed = 0.0
	var shots := _record_shots(spitter)
	await wait_until(func() -> bool: return carl.health.current_health < 100, "the glob to reach Carl", 180)
	await wait_seconds(0.5)
	check(shots.size() == 1 and shots[0]["target"] == carl and carl.health.current_health == 90 and donut.health.current_health == 60,
			"Carl in front (200 px), Donut behind (240 px): the glob takes 10 from Carl only; he shields her")
	check(not is_instance_valid(shots[0]["glob"]), "the glob is gone after its one hit")

	_new_arena()
	carl = _spawn_carl(Vector2(240, 0))
	donut = _spawn_donut(Vector2(200, 0), carl)
	donut.set_physics_process(false)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2(120, 0))
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	spitter = _spawn_enemy(SPITTER_SCENE, Vector2.ZERO)
	spitter.move_speed = 0.0
	shots = _record_shots(spitter)
	await wait_until(func() -> bool: return donut.health.current_health < 60, "the glob to reach Donut", 180)
	await wait_seconds(0.5)
	check(shots.size() == 1 and shots[0]["target"] == donut and donut.health.current_health == 50 and carl.health.current_health == 100,
			"Donut in front, Carl behind: the glob takes 10 from Donut only")
	check(blob.health.current_health == 30, "the Gelatinous Blob it flew past is unhurt")

	# A downed Donut in the way does not stop a glob: it flies on to Carl.
	donut.get_node("Hurtbox").take_hit(50)
	await wait_until(func() -> bool: return carl.health.current_health < 100, "a glob to fly past the downed Donut to Carl", 200)
	await wait_physics_frames(1)
	check(carl.health.current_health == 90 and donut.health.current_health == 0,
			"a glob flies past the downed Donut and takes 10 from Carl behind her")


func _new_arena() -> void:
	if _arena != null:
		_arena.free()
	game_state().start_new_run()
	_arena = Node2D.new()
	root.add_child(_arena)


func _spawn_carl(at: Vector2) -> CharacterBody2D:
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = at
	_arena.add_child(carl)
	carl.inventory = game_state().inventory
	carl.action_slots = game_state().action_slots
	return carl


func _spawn_donut(at: Vector2, carl: Node2D) -> CharacterBody2D:
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = at
	_arena.add_child(donut)
	return donut


## An enemy in the arena. It finds its target (Carl or Donut) by itself.
func _spawn_enemy(scene: PackedScene, at: Vector2) -> Enemy:
	var enemy: Enemy = scene.instantiate()
	enemy.position = at
	_arena.add_child(enemy)
	return enemy


## Records every glob `spitter` spits as {"glob", "tick", "target" (its target when it spat)}.
func _record_shots(spitter: Enemy) -> Array:
	var shots := []
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void:
		shots.append({"glob": glob, "tick": Engine.get_physics_frames(), "target": spitter.target}))
	return shots
