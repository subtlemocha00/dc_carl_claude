extends "res://tests/support/game_test.gd"
## Phase 2 combat checks in an empty arena (no level): Health, Carl's Fists, the
## Gelatinous Blob's pursuit, contact damage and death, Carl's death, the HUD, and Donut
## staying out of combat.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_combat.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_health()
	await _check_fists()
	await _check_fists_cooldown()
	await _check_blob_pursuit()
	await _check_blob_blocked_by_wall()
	await _check_contact_damage_and_hud()
	await _check_blob_death()
	await _check_carl_death()
	finish()


func _check_health() -> void:
	print("-- Health")
	var health := Health.new()
	health.max_health = 30
	root.add_child(health)
	var died_count := [0]
	health.died.connect(func() -> void: died_count[0] += 1)
	check(health.current_health == 30, "Health starts at max_health")
	check(health.take_damage(10) == 10 and health.current_health == 20, "take_damage(10) removes 10")
	check(health.take_damage(50) == 20 and health.current_health == 0, "damage beyond what is left stops at 0")
	check(health.is_dead() and died_count[0] == 1, "died is emitted once at 0")
	check(health.take_damage(5) == 0 and health.current_health == 0 and died_count[0] == 1, "no damage after death")
	health.free()


func _check_fists() -> void:
	print("-- Carl's Fists (action slot W)")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var blob := _spawn_blob(Vector2(48, 0), carl, false)
	var blob_health: Health = blob.health
	var attacks := []
	carl.fists.performed.connect(func(direction: Vector2, hits: int) -> void: attacks.append([direction, hits]))
	await wait_physics_frames(2)

	await tap_key(KEY_W)
	check(attacks.size() == 1 and attacks[0][0] == Vector2.DOWN, "W attacks in the default facing (down)")
	check(blob_health.current_health == 30, "a blob to the right is not hit while Carl faces down")

	await wait_seconds(0.5)
	await tap_key(KEY_LEFT)
	await tap_key(KEY_W)
	check(blob_health.current_health == 30, "a blob to the right is not hit while Carl faces left")

	await wait_seconds(0.5)
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_W)
	check(blob_health.current_health == 20, "facing right, W hits the blob for 10", "blob HP %d" % blob_health.current_health)
	check(carl.health.current_health == 100, "Carl does not hit himself")

	# Donut standing between Carl and the blob neither blocks the punch nor gets hurt.
	var donut := _spawn_donut(Vector2(22, 0), carl)
	await wait_seconds(0.5)
	await tap_key(KEY_W)
	check(blob_health.current_health == 10, "Donut in the way does not block the punch", "blob HP %d" % blob_health.current_health)
	check(is_instance_valid(donut) and donut.get_node_or_null("Health") == null, "Donut has no Health, so she cannot be damaged")

	# A diagonal facing sends the punch diagonally.
	blob.global_position = carl.global_position + Vector2(34, -34)
	blob.reset_physics_interpolation()
	await wait_seconds(0.5)
	await hold_keys([KEY_UP, KEY_RIGHT], 1)
	await tap_key(KEY_W)
	check(blob_health.current_health == 0, "facing up-right, W hits a blob up-right", "blob HP %d" % blob_health.current_health)

	# A, S and D are empty action slots.
	var count_before := attacks.size()
	await wait_seconds(0.5)
	for key: Key in [KEY_A, KEY_S, KEY_D]:
		await tap_key(key)
	check(attacks.size() == count_before, "A, S and D do not attack")


func _check_fists_cooldown() -> void:
	print("-- Fists cooldown")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var blob := _spawn_blob(Vector2(45, 0), carl, false, 1000)
	var attack_ticks := []
	carl.fists.performed.connect(func(_direction: Vector2, _hits: int) -> void: attack_ticks.append(Engine.get_physics_frames()))
	await tap_key(KEY_RIGHT)
	await wait_seconds(0.5)
	attack_ticks.clear()

	await hold_keys([KEY_W], 90)  # 1.5 seconds
	var cooldown_ticks := roundi(carl.fists.cooldown * Engine.physics_ticks_per_second)
	var gaps := []
	for i in range(1, attack_ticks.size()):
		gaps.append(attack_ticks[i] - attack_ticks[i - 1])
	check(attack_ticks.size() == 4, "holding W for 1.5 s punches 4 times (cooldown 0.4 s)", "%d punches" % attack_ticks.size())
	check(gaps.all(func(gap: int) -> bool: return gap == cooldown_ticks), "punches are exactly one cooldown apart", "gaps %s ticks" % [gaps])
	check(blob.health.current_health == 1000 - 10 * attack_ticks.size(), "each punch dealt its damage once", "blob HP %d" % blob.health.current_health)


func _check_blob_pursuit() -> void:
	print("-- Blob detection and pursuit")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var blob := _spawn_blob(Vector2(300, 0), carl, true)
	await wait_physics_frames(2)

	var start := blob.global_position
	await wait_seconds(1.0)
	check(blob.global_position == start, "Carl 300 px away (detection range 220): the blob waits")

	carl.teleport_to(Vector2(100, 0))
	await wait_physics_frames(1)
	start = blob.global_position
	await wait_seconds(1.0)
	check_near("Carl 200 px away: the blob moves toward him at move_speed (px in 1 s)", start.x - blob.global_position.x, blob.move_speed, 0.5)

	carl.teleport_to(blob.global_position + Vector2(-300, 0))
	await wait_physics_frames(1)
	start = blob.global_position
	await wait_seconds(0.5)
	check(blob.global_position.x < start.x - 20.0, "once chasing, the blob keeps chasing at 300 px (chase range 320)")

	carl.teleport_to(blob.global_position + Vector2(-400, 0))
	await wait_physics_frames(2)
	start = blob.global_position
	await wait_seconds(0.5)
	check(blob.global_position == start, "Carl 400 px away: the blob gives up")

	carl.teleport_to(blob.global_position + Vector2(-150, 0))
	await wait_seconds(4.0)
	var gap := carl.global_position.distance_to(blob.global_position)
	check(gap >= 24.9 and gap < 27.0, "the blob stops against Carl's body instead of overlapping him", "centres %.1f px apart" % gap)


func _check_blob_blocked_by_wall() -> void:
	print("-- Blob and level collision")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var blob := _spawn_blob(Vector2(200, 0), carl, true)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1  # "world", like the wall tiles
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 400)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(100, 0)
	_arena.add_child(wall)
	await wait_seconds(3.0)
	check(blob.global_position.x >= 110.0 + 13.0 - 0.5, "a wall stops the chasing blob", "blob x %.1f, wall face 110" % blob.global_position.x)


func _check_contact_damage_and_hud() -> void:
	print("-- Blob contact damage, HUD, Donut")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_health(carl.health)
	var health_label: Label = hud.get_node("%HealthLabel")
	check(health_label.text == "HP: 100 / 100", "HUD shows full health", health_label.text)

	var hit_ticks := []
	var colors_on_hit := []
	carl.health.damaged.connect(func(_amount: int) -> void:
		hit_ticks.append(Engine.get_physics_frames())
		colors_on_hit.append(carl.modulate))
	var blob := _spawn_blob(Vector2(40, 0), carl, true)
	var donut := _spawn_donut(Vector2(40, 10), carl)
	await wait_seconds(2.0)
	# Put Donut right on top of the blob, next to Carl, and see what its touch reaches.
	donut.global_position = blob.global_position
	await wait_physics_frames(2)
	var blob_targets: Array = blob.contact_attack.find_targets(Vector2.ZERO)

	var interval_ticks := roundi(blob.contact_attack.cooldown * Engine.physics_ticks_per_second)
	var gaps := []
	for i in range(1, hit_ticks.size()):
		gaps.append(hit_ticks[i] - hit_ticks[i - 1])
	check(hit_ticks.size() == 3, "touching Carl for about 2 s hurts him 3 times (every 0.8 s)", "%d hits" % hit_ticks.size())
	check(gaps.all(func(gap: int) -> bool: return gap == interval_ticks), "contact hits are exactly one interval apart", "gaps %s ticks" % [gaps])
	check(carl.health.current_health == 70, "each contact hit removes 10 HP", "Carl HP %d" % carl.health.current_health)
	check(health_label.text == "HP: 70 / 100", "HUD updates after damage", health_label.text)
	check(colors_on_hit.size() > 0 and colors_on_hit[0] != Color.WHITE, "Carl flashes when hurt", str(colors_on_hit.slice(0, 1)))
	check(blob_targets.size() == 1 and blob_targets[0] == carl.get_node("Hurtbox"), "the blob's touch only finds Carl's Hurtbox, not Donut")
	check(is_instance_valid(donut), "Donut is unaffected by standing on the blob")


func _check_blob_death() -> void:
	print("-- Blob death")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var blob := _spawn_blob(Vector2(48, 0), carl, false)
	# A longer fade leaves time to check that the dead blob stays inactive.
	blob.death_fade_time = 2.0
	var died_count := [0]
	blob.health.died.connect(func() -> void: died_count[0] += 1)
	await tap_key(KEY_RIGHT)
	await hold_keys([KEY_W], 60)  # 3 punches: 30 HP gone
	await wait_physics_frames(2)
	check(blob.health.is_dead() and died_count[0] == 1, "3 punches kill the blob (30 HP), died emitted once")
	# Godot never lets a scale be exactly 0 (it keeps 0.00001), so compare against a tiny width.
	check(blob.get_node("%HealthBarFill").scale.x < 0.001, "the blob's health bar is empty")
	check(not blob.is_physics_processing(), "a dead blob stops acting")
	check(blob.get_node("CollisionShape2D").disabled, "a dead blob no longer blocks movement")

	# Put Carl right on the dead blob: it must neither move nor hurt him.
	var dead_position := blob.global_position
	carl.teleport_to(blob.global_position + Vector2(-26, 0))
	await wait_seconds(0.3)
	check(blob.global_position == dead_position and carl.health.current_health == 100, "a dead blob does not move or hurt Carl")
	await wait_seconds(0.5)  # let the Fists cool down
	await hold_keys([KEY_W], 2)
	check(died_count[0] == 1 and blob.health.current_health == 0, "punching a dead blob does nothing")
	await wait_seconds(1.5)
	check(not is_instance_valid(blob), "the dead blob fades out and is removed")


func _check_carl_death() -> void:
	print("-- Carl death")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_health(carl.health)
	var died_count := [0]
	carl.health.died.connect(func() -> void: died_count[0] += 1)
	carl.health.take_damage(95)
	var blob := _spawn_blob(Vector2(30, 0), carl, true)
	await wait_seconds(0.5)
	check(carl.health.is_dead() and died_count[0] == 1, "the blob's touch takes Carl from 5 HP to 0, died emitted once")
	check(hud.get_node("%HealthLabel").text == "HP: 0 / 100", "HUD shows 0 HP")
	check(hud.get_node("%GameOverMessage").visible, "HUD shows the game-over message")

	var attacks := [0]
	carl.fists.performed.connect(func(_direction: Vector2, _hits: int) -> void: attacks[0] += 1)
	var position_when_down := carl.global_position
	await hold_keys([KEY_LEFT], 30)
	await hold_keys([KEY_W], 30)
	check(carl.global_position == position_when_down and attacks[0] == 0, "a downed Carl cannot move or attack")
	await wait_seconds(1.0)
	check(died_count[0] == 1 and carl.health.current_health == 0, "the blob stops hurting a downed Carl")
	check(is_instance_valid(blob), "the blob is unaffected")


func _new_arena() -> void:
	if _arena != null:
		_arena.free()
	_arena = Node2D.new()
	root.add_child(_arena)


func _spawn_carl(at: Vector2) -> CharacterBody2D:
	var carl: CharacterBody2D = CARL_SCENE.instantiate()
	carl.position = at
	_arena.add_child(carl)
	return carl


func _spawn_donut(at: Vector2, carl: Node2D) -> CharacterBody2D:
	var donut: CharacterBody2D = DONUT_SCENE.instantiate()
	donut.follow_target = carl
	donut.position = at
	_arena.add_child(donut)
	return donut


## Spawns a blob hunting Carl. With `chases` false its detection range is 0, so it stays put.
func _spawn_blob(at: Vector2, carl: Node2D, chases: bool, max_health: int = 30) -> CharacterBody2D:
	var blob: CharacterBody2D = BLOB_SCENE.instantiate()
	blob.target = carl
	if not chases:
		blob.detection_range = 0.0
		blob.chase_range = 0.0
	blob.get_node("Health").max_health = max_health
	blob.position = at
	_arena.add_child(blob)
	return blob
