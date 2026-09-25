extends "res://tests/support/game_test.gd"
## Phase 8 Donut checks, in arenas without a level:
## - health: a new run gives her 60 / 60 (also after a run where she was hurt); her scene has a
##   Health (60) and a Hurtbox on player_hurtbox, and she is in the "party" group; an enemy's
##   touch takes 10; HP never goes below 0;
## - friendly fire: Carl's Fists and Slingshot stones never hurt her, and her Scratch never hurts
##   Carl or herself;
## - Scratch: 10 damage to one enemy (the nearest), about 42 px from her centre (an enemy 38 px
##   away is scratched, 46 px is not), at most once per 1.0 s (exactly 60 ticks apart), never
##   with no enemy near; she never walks toward an enemy, only after Carl;
## - downed at 0 HP: DOWNED label, greyed out and on her side, HUD "Donut HP: 0 / 60 - DOWNED";
##   she stops following and scratching; more hits do nothing;
## - recovery: after exactly 6 s (360 ticks) of play she gets up with 30 / 60 HP, looks normal
##   again, follows Carl and scratches again; the action menu and GAME OVER (the tree pause) stop
##   the countdown, and so does Carl being down.
## Enemies choosing (or dropping) Donut as a target are covered by test_party_targeting.gd.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_donut.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CARL_SCENE: PackedScene = preload("res://scenes/actors/carl.tscn")
const DONUT_SCENE: PackedScene = preload("res://scenes/actors/donut.tscn")
const BLOB_SCENE: PackedScene = preload("res://scenes/enemies/gelatinous_blob.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/action_menu.tscn")
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
## Canonical Phase 8 numbers.
const DONUT_MAX_HP := 60
const RECOVERY_HP := 30
const DOWN_TICKS := 360
const SCRATCH_DAMAGE := 10
const SCRATCH_TICKS := 60
const PLAYER_HURTBOX := 16
const ENEMY_HURTBOX := 32

var _arena: Node2D


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(Engine.physics_ticks_per_second == 60, "the physics tick rate is 60 (the tick counts below assume it)")
	_check_new_run_health()
	await _check_scene_and_enemy_damage()
	await _check_friendly_fire()
	await _check_scratch()
	await _check_scratch_range_and_one_target()
	await _check_donut_does_not_hunt()
	await _check_downed()
	await _check_recovery()
	await _check_recovery_pauses()
	finish()


func _check_new_run_health() -> void:
	print("-- A new run: Donut at 60 / 60")
	var state := game_state()
	state.start_new_run()
	check(state.donut_health == DONUT_MAX_HP and state.donut_max_health == DONUT_MAX_HP, "a new run gives Donut 60 / 60 HP")
	state.store_donut_health(0, DONUT_MAX_HP)
	state.record_floor_entry("res://scenes/levels/floor_05.tscn")
	state.start_new_run()
	check(state.donut_health == DONUT_MAX_HP and state.donut_max_health == DONUT_MAX_HP and state.floor_entry == null,
			"a new run after one where Donut was downed gives her 60 / 60 again, with nothing left of the old run")


func _check_scene_and_enemy_damage() -> void:
	print("-- Donut's Health and Hurtbox; an enemy's touch")
	_new_arena()
	var carl := _spawn_carl(Vector2(-300, 0))
	var donut := _spawn_donut(Vector2.ZERO, carl)
	var hurtbox: Hurtbox = donut.get_node("Hurtbox")
	check(donut.health.max_health == DONUT_MAX_HP and donut.health.current_health == DONUT_MAX_HP, "Donut has a Health: 60 / 60")
	check(hurtbox.health == donut.health and hurtbox.collision_layer == PLAYER_HURTBOX,
			"her Hurtbox passes hits to that Health and is on player_hurtbox (the player's side, like Carl's)")
	check(donut.is_in_group(&"party") and carl.is_in_group(&"party"), "Carl and Donut are both in the party group")
	check(donut.scratch.target_layers == ENEMY_HURTBOX and donut.scratch.damage == SCRATCH_DAMAGE and donut.scratch.max_targets == 1
			and is_equal_approx(donut.scratch.cooldown, 1.0), "her Scratch hits enemy_hurtbox only: 10 damage, one target, 1.0 s")

	# A blob (idle, so it stays put) right next to her: its touch takes 10 HP every 0.8 s.
	var blob := _spawn_blob(Vector2(24, 0))
	var hits := []
	donut.health.damaged.connect(func(amount: int) -> void: hits.append([Engine.get_physics_frames(), amount]))
	donut.set_physics_process(false)
	await wait_seconds(1.7)
	check(hits.size() == 3 and hits.all(func(hit: Array) -> bool: return hit[1] == 10) and hits[2][0] - hits[0][0] == 96,
			"an enemy's touch takes 10 HP from Donut every 0.8 s", str(hits))
	check(donut.health.current_health == 30, "60 - 3 x 10 = 30 HP left", str(donut.health.current_health))
	blob.free()
	check(donut.health.take_damage(1000) == 30 and donut.health.current_health == 0, "a big hit takes her to 0 HP, not below")
	check(donut.health.take_damage(10) == 0 and donut.health.current_health == 0, "nothing takes her below 0")


func _check_friendly_fire() -> void:
	print("-- Friendly fire: Carl never hurts Donut, and Scratch never hurts Carl or Donut")
	_new_arena()
	var carl := _spawn_carl(Vector2.ZERO)
	carl.collect_item(SLINGSHOT, 1)
	game_state().action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	var donut := _spawn_donut(Vector2(20, 0), carl)
	donut.set_physics_process(false)
	var punches := []
	(carl.get_action_performer(FISTS) as MeleeAttack).performed.connect(func(_d: Vector2, hit_count: int) -> void: punches.append(hit_count))
	await tap_key(KEY_RIGHT)
	await tap_key(KEY_D)
	check(punches == [0] and donut.health.current_health == DONUT_MAX_HP, "Carl punches Donut point-blank: nothing is hit, she keeps 60 HP")
	var stones := []
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	await tap_key(KEY_W)
	await wait_seconds(1.0)
	check(stones.size() == 1 and not is_instance_valid(stones[0]) and donut.health.current_health == DONUT_MAX_HP,
			"a Slingshot stone fired straight through her never hurts her")

	# Scratch: with Carl beside her and no enemy near, she never scratches.
	donut.set_physics_process(true)
	var scratches := []
	donut.scratch.performed.connect(func(_d: Vector2, hit_count: int) -> void: scratches.append(hit_count))
	await wait_seconds(2.0)
	check(scratches.is_empty() and carl.health.current_health == 100, "with only Carl beside her she never scratches (no enemy near)")
	var blob := _spawn_blob(donut.global_position + Vector2(0, 35), 1000)
	await wait_seconds(1.5)
	check(scratches.size() == 2 and scratches.all(func(hit_count: int) -> bool: return hit_count == 1)
			and blob.health.current_health == 980, "with an enemy near she scratches it, one hit per scratch", str(scratches))
	check(carl.health.current_health == 100 and donut.health.current_health == DONUT_MAX_HP,
			"her scratches never hurt Carl (next to her) or Donut herself")


func _check_scratch() -> void:
	print("-- Scratch: 10 damage, once per 1.0 s")
	_new_arena()
	var carl := _spawn_carl(Vector2(-300, 0))
	var donut := _spawn_donut(Vector2.ZERO, carl)
	var ticks := []
	donut.scratch.performed.connect(func(_d: Vector2, _hits: int) -> void: ticks.append(Engine.get_physics_frames()))
	await wait_seconds(1.0)
	check(ticks.is_empty(), "no enemy near: no scratch")
	var blob := _spawn_blob(Vector2(35, 0), 1000)
	var damage := []
	blob.health.damaged.connect(func(amount: int) -> void: damage.append(amount))
	await wait_physics_frames(3 * SCRATCH_TICKS + 3)
	var gaps := []
	for i in range(1, ticks.size()):
		gaps.append(ticks[i] - ticks[i - 1])
	check(ticks.size() == 4 and gaps.all(func(gap: int) -> bool: return gap == SCRATCH_TICKS),
			"an enemy staying near for 3 s is scratched 4 times, exactly 60 ticks (1.0 s) apart", "gaps %s" % [gaps])
	check(damage.size() == 4 and damage.all(func(amount: int) -> bool: return amount == SCRATCH_DAMAGE)
			and blob.health.current_health == 1000 - 40, "each scratch takes exactly 10 HP", str(damage))
	check(donut.health.current_health == DONUT_MAX_HP, "the blob 35 px away is not touching her, so she is unhurt")

	# A 30 HP blob dies after three scratches, and a dead blob is not scratched again.
	blob.free()
	var weak_blob := _spawn_blob(Vector2(35, 0))
	var weak_blob_hits := [0]
	var weak_blob_died := [false]
	weak_blob.health.damaged.connect(func(_amount: int) -> void: weak_blob_hits[0] += 1)
	weak_blob.health.died.connect(func() -> void: weak_blob_died[0] = true)
	var scratches_before := ticks.size()
	await wait_seconds(3.5)
	check(weak_blob_died[0] and weak_blob_hits[0] == 3 and ticks.size() - scratches_before == 3,
			"three scratches kill a 30 HP Gelatinous Blob; she does not scratch the dead one",
			"%d hits, %d scratches" % [weak_blob_hits[0], ticks.size() - scratches_before])


func _check_scratch_range_and_one_target() -> void:
	print("-- Scratch reaches about 42 px, and hits the nearest enemy only")
	_new_arena()
	var carl := _spawn_carl(Vector2(-300, 0))
	var donut := _spawn_donut(Vector2.ZERO, carl)
	var near_enough := _spawn_blob(Vector2(0, 38))
	var too_far := _spawn_blob(Vector2(0, -46))
	await wait_seconds(0.5)
	check(near_enough.health.current_health == 20 and too_far.health.current_health == 30,
			"an enemy 38 px from her centre is scratched, one 46 px away is not",
			"38 px: %d HP, 46 px: %d HP" % [near_enough.health.current_health, too_far.health.current_health])
	near_enough.free()
	too_far.free()

	var nearest := _spawn_blob(Vector2(34, 0))
	var second := _spawn_blob(Vector2(-39, 0))
	await wait_seconds(1.7)
	check(nearest.health.current_health == 10 and second.health.current_health == 30,
			"with two enemies in reach, each scratch hits only the nearest one",
			"nearest %d HP, other %d HP" % [nearest.health.current_health, second.health.current_health])
	check(donut.global_position == Vector2.ZERO, "she scratched from where she stood")


func _check_donut_does_not_hunt() -> void:
	print("-- Donut follows Carl; she never walks toward an enemy")
	if not await _new_navigation_arena():
		return
	var carl := _spawn_carl(Vector2(200, 320))
	var donut := _spawn_donut(Vector2(150, 320), carl)
	# An idle enemy 150 px from Donut, 200 px from Carl: out of Scratch reach.
	var blob := _spawn_blob(Vector2(150, 470))
	var scratches := [0]
	donut.scratch.performed.connect(func(_d: Vector2, _h: int) -> void: scratches[0] += 1)
	var closest_to_blob := INF
	for i in 120:
		await physics_frame
		closest_to_blob = minf(closest_to_blob, donut.global_position.distance_to(blob.global_position))
	check(closest_to_blob > 140.0 and scratches[0] == 0 and donut.global_position.distance_to(carl.global_position) < 61.0,
			"with Carl standing still she stays by him and never goes to the enemy", "closest %.0f px" % closest_to_blob)
	# Carl walks away from the enemy: she follows him, not it.
	await hold_keys([KEY_RIGHT], 90)
	await wait_seconds(1.5)
	check(donut.global_position.distance_to(carl.global_position) < 75.0 and donut.global_position.distance_to(blob.global_position) > 250.0,
			"when Carl walks off she follows him, away from the enemy",
			"%.0f px from Carl, %.0f px from the enemy" % [donut.global_position.distance_to(carl.global_position),
					donut.global_position.distance_to(blob.global_position)])


func _check_downed() -> void:
	print("-- Donut at 0 HP is downed")
	if not await _new_navigation_arena():
		return
	var carl := _spawn_carl(Vector2(200, 320))
	var donut := _spawn_donut(Vector2(150, 320), carl)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_donut_health(donut.health)
	var donut_label: Label = hud.get_node("%DonutHealthLabel")
	check(donut_label.text == "Donut HP: 60 / 60", "the HUD shows Donut's HP", donut_label.text)
	var normal_color := donut_label.get_theme_color(&"font_color")
	var died := [0]
	donut.health.died.connect(func() -> void: died[0] += 1)
	await wait_physics_frames(2)
	donut.get_node("Hurtbox").take_hit(45)
	check(donut_label.text == "Donut HP: 15 / 60", "the HUD follows her HP", donut_label.text)
	donut.get_node("Hurtbox").take_hit(40)
	check(donut.is_downed() and donut.health.current_health == 0 and died[0] == 1, "at 0 HP she is downed")
	check(donut_label.text == "Donut HP: 0 / 60  -  DOWNED" and donut_label.get_theme_color(&"font_color") != normal_color,
			"the HUD says DOWNED, in another colour", donut_label.text)
	check(donut.downed_label.visible and donut.downed_label.text == "DOWNED" and donut.look.modulate != Color.WHITE
			and is_equal_approx(donut.look.rotation, PI / 2.0), "she shows a DOWNED label, greyed out and lying on her side")
	check(not donut.get_node("Hurtbox").can_be_hit(), "her Hurtbox can no longer be hit")

	# She stays where she fell while Carl walks off, and does not scratch an enemy right beside her.
	var fell_at := donut.global_position
	var blob := _spawn_blob(fell_at + Vector2(0, 20))
	var scratches := [0]
	donut.scratch.performed.connect(func(_d: Vector2, _h: int) -> void: scratches[0] += 1)
	await hold_keys([KEY_RIGHT], 60)
	await wait_seconds(1.5)
	check(donut.global_position == fell_at and carl.global_position.distance_to(fell_at) > 150.0,
			"a downed Donut does not follow Carl", str(donut.global_position))
	check(scratches[0] == 0 and blob.health.current_health == 30, "a downed Donut does not scratch an enemy beside her")
	check(donut.health.current_health == 0 and died[0] == 1 and blob.contact_attack.find_targets(Vector2.ZERO).is_empty(),
			"the enemy's touch finds nothing to hurt: she stays at 0, downed once")
	check(not paused and carl.health.current_health == 100, "Donut being downed pauses nothing and does not hurt Carl")


func _check_recovery() -> void:
	print("-- Donut gets up after 6 s with 30 / 60 HP")
	if not await _new_navigation_arena():
		return
	var carl := _spawn_carl(Vector2(200, 320))
	var donut := _spawn_donut(Vector2(150, 320), carl)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	_arena.add_child(hud)
	hud.show_donut_health(donut.health)
	var revived := []
	donut.health.health_changed.connect(func(current: int, _maximum: int) -> void:
		if current > 0 and revived.is_empty():
			revived.append(Engine.get_physics_frames()))
	await wait_physics_frames(2)
	# Down her at the start of a tick (before any node has processed it), as the tick clock does.
	donut.get_node("Hurtbox").take_hit(60)
	var downed_at := Engine.get_physics_frames()
	# Carl walks away while she is down.
	await hold_keys([KEY_RIGHT], 60)
	await wait_physics_frames(DOWN_TICKS - 1 - 61)
	check(donut.is_downed() and revived.is_empty(), "359 ticks later she is still downed (no early recovery)")
	await wait_physics_frames(2)
	check(not revived.is_empty() and revived[0] - downed_at == DOWN_TICKS - 1 and not donut.is_downed(),
			"she gets up on her 360th downed tick: 6.0 s", "after %d ticks" % (revived[0] - downed_at if not revived.is_empty() else -1))
	check(donut.health.current_health == RECOVERY_HP and donut.health.max_health == DONUT_MAX_HP, "she gets up with exactly 30 / 60 HP")
	check(hud.get_node("%DonutHealthLabel").text == "Donut HP: 30 / 60", "the HUD shows 30 / 60 again")
	check(not donut.downed_label.visible and donut.look.modulate == Color.WHITE and donut.look.rotation == 0.0,
			"she looks normal again")
	check(donut.get_node("Hurtbox").can_be_hit(), "and can be hit again")
	var far := donut.global_position.distance_to(carl.global_position)
	await wait_seconds(2.0)
	check(far > 150.0 and donut.global_position.distance_to(carl.global_position) < 75.0,
			"she catches up with Carl, who walked on while she was down",
			"%.0f px -> %.0f px" % [far, donut.global_position.distance_to(carl.global_position)])
	var blob := _spawn_blob(donut.global_position + Vector2(0, 35))
	await wait_seconds(0.3)
	check(blob.health.current_health == 20, "she scratches again")


func _check_recovery_pauses() -> void:
	print("-- The recovery countdown stops for the menu, GAME OVER and a downed Carl")
	_new_arena()
	var carl := _spawn_carl(Vector2(-300, 0))
	var donut := _spawn_donut(Vector2.ZERO, carl)
	var menu: CanvasLayer = MENU_SCENE.instantiate()
	_arena.add_child(menu)
	menu.setup(game_state().inventory, game_state().action_slots)
	var revived := []
	donut.health.health_changed.connect(func(current: int, _maximum: int) -> void:
		if current > 0 and revived.is_empty():
			revived.append(Engine.get_physics_frames()))
	await wait_physics_frames(2)
	donut.get_node("Hurtbox").take_hit(60)
	var downed_at := Engine.get_physics_frames()
	await wait_physics_frames(100)
	menu.open()
	check(paused, "the action menu pauses the game")
	await wait_physics_frames(300)
	check(donut.is_downed() and is_equal_approx(donut.get_recovery_time_left(), (DOWN_TICKS - 100) / 60.0),
			"5 s with the menu open: the countdown has not moved", "%.2f s left" % donut.get_recovery_time_left())
	menu.close()
	await wait_physics_frames(DOWN_TICKS - 100 + 2)
	check(not revived.is_empty() and revived[0] - downed_at == DOWN_TICKS - 1 + 300,
			"she gets up after 6 s of play: the 5 s in the menu did not count", str(revived))

	# GAME OVER is the same tree pause; a downed Carl also holds her countdown.
	revived.clear()
	donut.get_node("Hurtbox").take_hit(60)
	await wait_physics_frames(60)
	paused = true
	await wait_physics_frames(DOWN_TICKS + 60)
	check(donut.is_downed(), "while the game is paused by GAME OVER she stays downed, however long")
	carl.health.take_damage(1000)
	paused = false
	await wait_physics_frames(DOWN_TICKS + 60)
	check(donut.is_downed() and revived.is_empty(), "and while Carl is down she does not get up, even unpaused")


## A plain arena (no navigation mesh: Donut stays where she is put).
func _new_arena() -> void:
	if _arena != null:
		_arena.free()
	paused = false
	game_state().start_new_run()
	_arena = Node2D.new()
	root.add_child(_arena)


## An arena with a navigation mesh (no walls), so Donut can follow Carl.
func _new_navigation_arena() -> bool:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	paused = false
	game_state().start_new_run()
	var no_walls: Array[Rect2] = []
	_arena = await build_navigation_arena(Vector2(960, 640), no_walls)
	return _arena != null


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


## A Gelatinous Blob that never moves or hunts (detection 0), so only its touch matters. Its HP
## is set before it enters the tree, where its Health starts at max_health.
func _spawn_blob(at: Vector2, max_health: int = 30) -> Enemy:
	var blob: Enemy = BLOB_SCENE.instantiate()
	blob.detection_range = 0.0
	blob.chase_range = 0.0
	blob.get_node("Health").max_health = max_health
	blob.position = at
	_arena.add_child(blob)
	return blob
