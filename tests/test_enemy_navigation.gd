extends "res://tests/support/game_test.gd"
## Phase 7 enemy navigation, in arenas with a real baked navigation mesh (like a level's):
## - the Gelatinous Blob still waits until Carl comes within 220 px, and gives up beyond 320 px;
## - with a wall straight between them, it follows a route around the wall: its own path bends
##   around the wall, it passes the wall's end, it never overlaps the wall, it keeps closing the
##   distance (no stall) and it reaches Carl and hurts him by touch as before;
## - with no way around (a wall across the whole arena) it goes as near as it can, stops there
##   without jittering, and never gets through;
## - the Spitting Blob, active but with Carl hidden behind a wall, never spits while he is hidden:
##   it walks around the wall without overlapping it, and spits once it can see him; every glob
##   reaches Carl, none hits the wall;
## - neither enemy notices or targets Donut.
## Navigation maps are rebuilt a few ticks after a change, so every arena waits until the map
## holds exactly its mesh (build_navigation_arena() in game_test.gd) before any enemy is added.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_enemy_navigation.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/enemies/spitting_blob.tscn")
const ARENA_SIZE := Vector2(960, 640)
## A wall between Carl (west) and the enemy (east), with room to walk around either end.
const WALL := Rect2(400, 160, 32, 320)
## Both enemies' bodies are circles of this radius.
const ENEMY_RADIUS := 13.0
## Two bodies touch when their centres are this close (enemy 13 + Carl 12, plus a little).
const TOUCHING := 26.0
## Routes keep 14 px from walls (the mesh's agent radius), so a route around the wall's end
## passes within this distance of the wall's sides.
const ROUTE_MARGIN := 16.0

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	await _check_blob_detection_and_give_up()
	await _check_blob_goes_around_a_wall()
	await _check_blob_with_no_way_around()
	await _check_spitter_goes_around_a_wall()
	await _check_enemies_ignore_donut()
	finish()


func _check_blob_detection_and_give_up() -> void:
	print("-- The blob notices Carl within 220 px and gives up beyond 320 px")
	if not await _new_arena([WALL]):
		return
	var carl := _spawn_carl(Vector2(300, 320))
	var blob := _spawn_enemy(BLOB_SCENE, Vector2(540, 320), carl)
	var start := blob.global_position
	await wait_seconds(1.0)
	check(not blob.is_active() and blob.global_position == start, "Carl 240 px away: the blob waits where it is")

	carl.teleport_to(Vector2(330, 320))
	await wait_physics_frames(2)
	check(blob.is_active(), "Carl 210 px away (behind the wall): the blob notices him")
	await wait_seconds(0.5)
	check(blob.global_position.distance_to(start) > 20.0, "and starts moving", str(blob.global_position))

	carl.teleport_to(Vector2(40, 600))
	await wait_physics_frames(2)
	var gave_up_at := blob.global_position
	await wait_seconds(0.5)
	check(not blob.is_active() and blob.global_position.distance_to(gave_up_at) < 0.01,
			"Carl more than 320 px away: the blob gives up and stops", "%.0f px away" % blob.global_position.distance_to(carl.global_position))


func _check_blob_goes_around_a_wall() -> void:
	print("-- The blob walks around a wall to reach Carl")
	if not await _new_arena([WALL]):
		return
	var carl := _spawn_carl(Vector2(330, 320))
	var blob := _spawn_enemy(BLOB_SCENE, Vector2(540, 320), carl)
	check(not _is_clear(blob.global_position, carl.global_position), "the straight line from the blob to Carl is blocked by the wall")
	var route := await navigation_route(blob.global_position, carl.global_position)
	check(route.size() >= 3 and _passes_wall_end(route), "the navigation route bends around the wall", str(route))
	var time_limit := route_length(route) / blob.move_speed + 2.0
	var damage_ticks := []
	carl.health.damaged.connect(func(_amount: int) -> void: damage_ticks.append(Engine.get_physics_frames()))

	var smallest_clearance := INF
	var passed_wall_end := false
	var stalled_windows := []
	var last_remaining := route_length(route)
	var own_path := PackedVector2Array()
	var ticks := 0
	while ticks < time_limit * Engine.physics_ticks_per_second:
		await physics_frame
		ticks += 1
		if ticks == 2:
			own_path = blob.navigation.get_current_navigation_path()
		smallest_clearance = minf(smallest_clearance, _distance_to_rect(blob.global_position, WALL) - ENEMY_RADIUS)
		passed_wall_end = passed_wall_end or _beside_wall_end(blob.global_position)
		if blob.global_position.distance_to(carl.global_position) <= TOUCHING:
			break
		if ticks % 30 == 0:
			# Every half second the route left to walk must be clearly shorter (55 px/s = 27.5 px).
			var remaining := route_length(NavigationServer2D.map_get_path(
					root.world_2d.navigation_map, blob.global_position, carl.global_position, true))
			if remaining > last_remaining - 15.0:
				stalled_windows.append("%.1f s: %.0f -> %.0f px" % [ticks / 60.0, last_remaining, remaining])
			last_remaining = remaining
	check(own_path.size() >= 3 and _passes_wall_end(own_path), "the blob's own navigation path goes around the wall", str(own_path))
	check(passed_wall_end, "the blob passes the end of the wall")
	check(smallest_clearance > -0.5, "the blob never overlaps the wall", "closest %.2f px from its face" % smallest_clearance)
	check(stalled_windows.is_empty(), "the blob never stalls: every half second it gets closer along the route", str(stalled_windows))
	check(blob.global_position.distance_to(carl.global_position) <= TOUCHING and blob.global_position.x < WALL.position.x,
			"the blob reaches Carl on the far side of the wall, within %.1f s" % time_limit, "%.1f s" % (ticks / 60.0))

	var hp_before: int = carl.health.current_health
	await wait_seconds(2.0)
	var gaps := []
	for i in range(1, damage_ticks.size()):
		gaps.append(damage_ticks[i] - damage_ticks[i - 1])
	check(hp_before - carl.health.current_health >= 20 and gaps.all(func(gap: int) -> bool: return gap == 48),
			"then its touch hurts Carl, 10 HP every 0.8 s as before", "HP %d, gaps %s" % [carl.health.current_health, gaps])


func _check_blob_with_no_way_around() -> void:
	print("-- No way around: the blob stops at the wall and never gets through")
	# The small pillar lets the arena check that the map is ready; the second wall cuts the arena in two.
	var splitter := Rect2(400, 0, 32, 640)
	if not await _new_arena([Rect2(700, 260, 32, 120), splitter]):
		return
	var carl := _spawn_carl(Vector2(300, 320))
	var blob := _spawn_enemy(BLOB_SCENE, Vector2(500, 320), carl)
	var smallest_clearance := INF
	for i in 4 * Engine.physics_ticks_per_second:
		await physics_frame
		smallest_clearance = minf(smallest_clearance, _distance_to_rect(blob.global_position, splitter) - ENEMY_RADIUS)
	var settled_at := blob.global_position
	var furthest_drift := 0.0
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		smallest_clearance = minf(smallest_clearance, _distance_to_rect(blob.global_position, splitter) - ENEMY_RADIUS)
		furthest_drift = maxf(furthest_drift, blob.global_position.distance_to(settled_at))
	check(blob.is_active() and blob.global_position.x > splitter.end.x and blob.global_position.x < splitter.end.x + 30.0,
			"the active blob goes as near as it can: next to the wall", str(blob.global_position))
	check(furthest_drift < 1.0, "it then stands still instead of jittering against the wall", "moved %.2f px in 1 s" % furthest_drift)
	check(smallest_clearance > -0.5 and carl.health.current_health == 100, "it never overlaps or passes the wall, and Carl is unhurt")


func _check_spitter_goes_around_a_wall() -> void:
	print("-- The Spitting Blob walks around a wall until it can see Carl, and only then spits")
	if not await _new_arena([WALL]):
		return
	var carl := _spawn_carl(Vector2(300, 320))
	carl.health.set_health(1000, 1000)
	var spitter := _spawn_enemy(SPITTER_SCENE, Vector2(620, 320), carl)
	var shots := []
	var stops := []
	(spitter.spit_launcher as ProjectileLauncher).fired.connect(func(glob: Projectile) -> void:
		shots.append([Engine.get_physics_frames(), spitter.has_line_of_sight_to(carl.global_position)])
		glob.stopped.connect(func(collider: Object) -> void: stops.append(collider)))
	var smallest_clearance := INF
	var passed_wall_end := false
	var first_sight_tick := -1
	for tick in 8 * Engine.physics_ticks_per_second:
		await physics_frame
		smallest_clearance = minf(smallest_clearance, _distance_to_rect(spitter.global_position, WALL) - ENEMY_RADIUS)
		passed_wall_end = passed_wall_end or _beside_wall_end(spitter.global_position)
		if first_sight_tick < 0 and spitter.has_line_of_sight_to(carl.global_position):
			first_sight_tick = tick
	check(spitter.is_active(), "Carl 320 px away: the Spitting Blob is active")
	check(passed_wall_end and first_sight_tick > 0, "it walks around the end of the wall until it can see Carl",
			"sight after %.1f s" % (first_sight_tick / 60.0))
	check(smallest_clearance > -0.5, "it never overlaps the wall", "closest %.2f px from its face" % smallest_clearance)
	check(shots.size() >= 2 and shots.all(func(shot: Array) -> bool: return shot[1]),
			"it spits only once it can see Carl (%d globs)" % shots.size(), str(shots))
	var carl_hurtbox := carl.get_node("Hurtbox")
	check(stops.size() >= 1 and stops.all(func(collider: Object) -> bool: return collider == carl_hurtbox),
			"every glob reaches Carl; none hits the wall", str(stops))


func _check_enemies_ignore_donut() -> void:
	print("-- Enemies ignore Donut")
	if not await _new_arena([WALL]):
		return
	var carl := _spawn_carl(Vector2(60, 60))
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.set_physics_process(false)
	donut.position = Vector2(700, 320)
	_arena.add_child(donut)
	var blob := _spawn_enemy(BLOB_SCENE, Vector2(730, 320), carl)
	var spitter := _spawn_enemy(SPITTER_SCENE, Vector2(700, 470), carl)
	var shots := [0]
	(spitter.spit_launcher as ProjectileLauncher).fired.connect(func(_glob: Projectile) -> void: shots[0] += 1)
	var blob_start := blob.global_position
	var spitter_start := spitter.global_position
	await wait_seconds(2.0)
	check(not blob.is_active() and blob.global_position == blob_start and blob.contact_attack.find_targets(Vector2.ZERO).is_empty(),
			"a blob next to Donut (Carl far away) stays idle, and its touch finds nothing to hurt")
	check(not spitter.is_active() and spitter.global_position == spitter_start and shots[0] == 0,
			"a Spitting Blob with Donut in plain sight (Carl far away) never spits")
	check(donut.get_node_or_null("Health") == null and donut.get_node_or_null("Hurtbox") == null,
			"Donut still has nothing enemies could damage")


## Replaces the current arena with a new one with a navigation mesh and `walls`.
func _new_arena(walls: Array[Rect2]) -> bool:
	if _arena != null:
		_arena.queue_free()
	game_state().start_new_run()
	_arena = await build_navigation_arena(ARENA_SIZE, walls)
	return _arena != null


func _spawn_carl(at: Vector2) -> CharacterBody2D:
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = at
	_arena.add_child(carl)
	return carl


func _spawn_enemy(scene: PackedScene, at: Vector2, carl: Node2D) -> Enemy:
	var enemy: Enemy = scene.instantiate()
	enemy.target = carl
	enemy.position = at
	_arena.add_child(enemy)
	return enemy


## True if no wall is on the straight line between the two points.
func _is_clear(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return root.world_2d.direct_space_state.intersect_ray(query).is_empty()


## True if some point of `route` lies beyond one end of WALL (where the way around is).
func _passes_wall_end(route: PackedVector2Array) -> bool:
	return Array(route).any(_beside_wall_end)


## True for a point next to the wall's x range but past its top or bottom end.
func _beside_wall_end(point: Vector2) -> bool:
	return point.x > WALL.position.x - ROUTE_MARGIN and point.x < WALL.end.x + ROUTE_MARGIN \
			and (point.y < WALL.position.y or point.y > WALL.end.y)


## Distance from `point` to the nearest point of `rect` (0 inside it).
func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position, rect.end))
