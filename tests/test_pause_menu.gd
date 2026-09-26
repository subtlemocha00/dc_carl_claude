extends "res://tests/support/game_test.gd"
## Phase 10 pause menu checks in the real levels, driven by key events through Godot's input
## pipeline:
## - every level (every registered floor: the Surface and Floors 1-7) has exactly one pause
##   menu: Escape opens it with Resume selected and pauses the game; Escape, or Enter on Resume,
##   closes it; Up/Down move the
##   selection (wrapping), and it is back on Resume each time it opens; pausing never saves;
## - while it is open Carl cannot move, turn, punch, fire the Slingshot, swing the Bat or drink a
##   potion; closing it with a key still held gives no free action;
## - it freezes Donut (following, Scratch and her recovery countdown), the Gelatinous Blob (moving,
##   touching), the Spitting Blob (moving, spitting), stones and globs in flight and a Bat push in
##   progress, and gameplay time itself (a node counting physics ticks stops). Afterwards each
##   carries on exactly where it was: the next scratch, touch and glob come exactly one cooldown
##   of play after the one before (no burst, no free attack), the push completes its 80 px, and
##   Donut gets up after exactly 6 s of play;
## - stairs and pickups cannot trigger while it is open (they do once it closes);
## - inventory vs pause: Space opens the action menu only when nothing is open, Escape closes the
##   action menu without opening the pause menu (also when held), Space and W/A/S/D do nothing to
##   the pause menu, and the two are never open together, even with keys in the same frame;
## - GAME OVER: Escape and Space open nothing, everything stays frozen, Enter still retries, and
##   the pause menu works again on the retried floor;
## - lifecycle fix: when the stairs report Carl and he is killed in the same physics tick, the
##   stairs' deferred level change no longer runs: GAME OVER stays up on the same floor, the save
##   keeps a loadable checkpoint, Enter retries, and the stairs then work as usual.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_pause_menu.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_5_PATH := "res://scenes/levels/floor_05.tscn"
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const PAUSED_TICKS := 180


## Counts physics ticks of play. It is an ordinary gameplay node in the level, so it stops
## whenever the rest of the level does.
class TickCounter extends Node:
	var ticks := 0

	func _physics_process(_delta: float) -> void:
		ticks += 1


var _counter: TickCounter


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	await _check_every_level()
	await _check_selection()
	await _check_carl_frozen()
	await _check_donut_and_blob_frozen()
	await _check_spitting_blob_and_glob_frozen()
	await _check_stone_frozen()
	await _check_knockback_frozen()
	await _check_donut_recovery_frozen()
	await _check_inventory_and_pause()
	await _check_game_over()
	await _check_stairs_and_pickups_frozen()
	await _check_stairs_and_death_in_one_tick()
	finish()


func _check_every_level() -> void:
	print("-- Every level has one pause menu")
	for floor_id: StringName in FloorRegistry.FLOORS:
		var path := FloorRegistry.get_scene_path(floor_id)
		game_state().start_new_run()
		if not await _load(path):
			return
		var floor_name := FloorRegistry.get_display_name(floor_id)
		var save_before := _save_text()
		var menus := current_scene.find_children("*", "CanvasLayer", true, false).filter(
				func(node: Node) -> bool: return node.get_script() == _pause_menu().get_script())
		check(menus.size() == 1 and menus[0] == current_scene.pause_menu, floor_name + ": exactly one pause menu")
		check(not _pause_menu().is_open() and not paused, floor_name + ": it starts closed")
		await tap_key(KEY_ESCAPE)
		check(_pause_menu().is_open() and _pause_menu().visible and paused, floor_name + ": Escape opens it and pauses the game")
		check(_rows() == ["> Resume", "   Settings", "   Return to Title", "   Quit Game"],
				floor_name + ": Resume, Settings (Phase 13), Return to Title, Quit Game, Resume selected", str(_rows()))
		check(root.gui_get_focus_owner() == null, floor_name + ": nothing in it has keyboard focus")
		var ticks := _counter.ticks
		await wait_physics_frames(30)
		check(_counter.ticks == ticks, floor_name + ": gameplay time stops")
		await tap_key(KEY_ESCAPE)
		check(not _pause_menu().is_open() and not paused, floor_name + ": Escape resumes")
		await tap_key(KEY_ESCAPE)
		await tap_key(KEY_ENTER)
		check(not _pause_menu().is_open() and not paused, floor_name + ": Enter on Resume resumes")
		await wait_physics_frames(5)
		check(_counter.ticks > ticks, floor_name + ": gameplay time runs again")
		check(_save_text() == save_before, floor_name + ": pausing and resuming never wrote the save")


func _check_selection() -> void:
	print("-- Selection")
	game_state().start_new_run()
	if not await _load(FLOOR_1_PATH):
		return
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	check(_rows() == ["   Resume", "> Settings", "   Return to Title", "   Quit Game"], "Down selects Settings", str(_rows()))
	await tap_key(KEY_DOWN)
	check(_rows() == ["   Resume", "   Settings", "> Return to Title", "   Quit Game"], "Down again selects Return to Title", str(_rows()))
	await tap_key(KEY_DOWN)
	check(_rows()[3] == "> Quit Game", "Down again selects Quit Game")
	await tap_key(KEY_DOWN)
	check(_rows()[0] == "> Resume", "Down from Quit Game wraps to Resume")
	await tap_key(KEY_UP)
	check(_rows()[3] == "> Quit Game", "Up from Resume wraps to Quit Game")
	await tap_key(KEY_ESCAPE)
	check(not _pause_menu().is_open(), "Escape resumes whatever is selected")
	await tap_key(KEY_ESCAPE)
	check(_rows()[0] == "> Resume" and _pause_menu().get_selected_option() == 0, "opened again, Resume is selected")
	await tap_key(KEY_ESCAPE)


func _check_carl_frozen() -> void:
	print("-- Carl cannot move or act while paused")
	if not await _load_floor_6_with_everything():
		return
	var carl := _carl()
	var counts := _count_carl_actions(carl)
	var state := game_state()
	var save_before := _save_text()
	await tap_key(KEY_ESCAPE)
	var position := carl.global_position
	var facing: Vector2 = carl.facing_direction
	for key: Key in [KEY_RIGHT, KEY_UP, KEY_LEFT, KEY_DOWN]:
		await hold_keys([key], 20)
	for key: Key in [KEY_D, KEY_W, KEY_S, KEY_A]:
		await hold_keys([key], 20)
	check(carl.global_position == position and carl.facing_direction == facing, "Carl cannot move or turn",
			"moved %s" % (carl.global_position - position))
	check(counts["fists"] == 0, "D (Fists) does not punch")
	check(counts["slingshot"] == 0, "W (Slingshot) fires no stone")
	check(counts["bat"] == 0, "S (Baseball Bat) does not swing")
	check(carl.health.current_health == 60 and state.inventory.get_quantity(POTION) == 2, "A (potion) drinks nothing",
			"HP %d, potions %d" % [carl.health.current_health, state.inventory.get_quantity(POTION)])
	check(state.action_slots.get_layout() == _full_layout(), "W/A/S/D change no slot")
	check(_pause_menu().is_open(), "the pause menu is still open")

	# A slot key held when the menu closes gives no free action; pressed again, it works.
	send_key(KEY_D, true)
	await wait_physics_frames(2)
	await tap_key(KEY_ESCAPE)
	await wait_seconds(0.5)
	check(not paused and counts["fists"] == 0, "D held while resuming does not punch")
	send_key(KEY_D, false)
	await wait_physics_frames(2)
	await tap_key(KEY_D)
	await tap_key(KEY_W)
	await tap_key(KEY_S)
	await tap_key(KEY_A)
	check(counts["fists"] == 1 and counts["slingshot"] == 1 and counts["bat"] == 1, "after resuming, D, W and S work",
			str(counts))
	check(carl.health.current_health == 90 and state.inventory.get_quantity(POTION) == 1, "after resuming, A drinks a potion")
	await hold_keys([KEY_RIGHT], 20)
	check(carl.global_position.x > position.x + 50.0, "after resuming, Carl walks again")
	check(_save_text() == save_before, "none of this wrote the save")


func _check_donut_and_blob_frozen() -> void:
	print("-- Donut, her Scratch and the Gelatinous Blob stop while paused")
	if not await _load_floor_6_with_everything():
		return
	var carl := _carl()
	var donut := _donut()
	carl.health.set_health(1000, 1000)
	# Donut follows Carl while he walks: pause her mid-stride.
	send_key(KEY_RIGHT, true)
	await wait_physics_frames(45)
	await tap_key(KEY_ESCAPE)
	send_key(KEY_RIGHT, false)
	var donut_position := donut.global_position
	await wait_physics_frames(PAUSED_TICKS)
	check(donut.global_position == donut_position, "Donut stops following while paused")
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(30)
	check(donut.global_position != donut_position, "Donut follows again afterwards")

	# The open-area blob touches Carl while Donut, beside it, scratches it.
	var blob: Enemy = current_scene.get_node("Actors/GelatinousBlob")
	blob.health.set_health(1000, 1000)
	carl.teleport_to(blob.global_position + Vector2(-27, 0))
	donut.global_position = blob.global_position + Vector2(0, 30)
	donut.reset_physics_interpolation()
	var scratch_ticks := _record_ticks(donut.scratch.performed)
	var touch_ticks := _record_ticks(blob.get_node("ContactAttack").performed)
	await wait_until(func() -> bool: return scratch_ticks.size() >= 2 and touch_ticks.size() >= 2, "a scratch and a touch", 300)
	await tap_key(KEY_ESCAPE)
	var carl_hp: int = carl.health.current_health
	var blob_hp: int = blob.health.current_health
	var positions := [carl.global_position, donut.global_position, blob.global_position]
	var scratches := scratch_ticks.size()
	var touches := touch_ticks.size()
	await wait_physics_frames(PAUSED_TICKS)
	check(scratch_ticks.size() == scratches and blob.health.current_health == blob_hp, "Donut does not scratch while paused")
	check(touch_ticks.size() == touches and carl.health.current_health == carl_hp, "the blob does not touch Carl while paused")
	check([carl.global_position, donut.global_position, blob.global_position] == positions, "nobody moves while paused")
	await tap_key(KEY_ESCAPE)
	await wait_until(func() -> bool: return scratch_ticks.size() > scratches and touch_ticks.size() > touches,
			"the next scratch and touch", 120)
	check(scratch_ticks[scratches] - scratch_ticks[scratches - 1] == 60,
			"the next scratch comes exactly 60 ticks of play after the last one (no free scratch)",
			"%d ticks" % (scratch_ticks[scratches] - scratch_ticks[scratches - 1]))
	check(touch_ticks[touches] - touch_ticks[touches - 1] == 48,
			"the next touch comes exactly 48 ticks of play after the last one (no free touch)",
			"%d ticks" % (touch_ticks[touches] - touch_ticks[touches - 1]))


func _check_spitting_blob_and_glob_frozen() -> void:
	print("-- The Spitting Blob and its globs stop while paused")
	if not await _load_floor_6_with_everything():
		return
	var carl := _carl()
	carl.health.set_health(1000, 1000)
	var spitter: Enemy = current_scene.get_node("Actors/SpittingBlob")
	# 226 px straight below it, in plain sight and inside its preferred distance, so it holds still.
	carl.teleport_to(spitter.global_position + Vector2(0, 226))
	_donut().global_position = carl.global_position + Vector2(40, 20)
	_donut().reset_physics_interpolation()
	var globs: Array[Projectile] = []
	var glob_ticks := []
	spitter.spit_launcher.fired.connect(func(glob: Projectile) -> void:
		globs.append(glob)
		glob_ticks.append(_counter.ticks))
	if not await wait_until(func() -> bool: return globs.size() == 1, "the first glob", 240):
		return
	await wait_physics_frames(15)
	var glob := globs[0]
	check(is_instance_valid(glob) and glob.get_distance_flown() > 30.0, "a glob is in flight")
	await tap_key(KEY_ESCAPE)
	var glob_position := glob.global_position
	var spitter_position := spitter.global_position
	var carl_hp: int = carl.health.current_health
	await wait_physics_frames(PAUSED_TICKS)
	check(is_instance_valid(glob) and glob.global_position == glob_position, "the glob in flight freezes")
	check(globs.size() == 1, "nothing is spat while paused (%d ticks, twice its cooldown)" % PAUSED_TICKS)
	check(spitter.global_position == spitter_position, "the Spitting Blob does not move")
	check(carl.health.current_health == carl_hp, "Carl is not hurt while paused")
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(3)
	check(not is_instance_valid(glob) or glob.global_position != glob_position, "the glob flies on after resuming")
	await wait_until(func() -> bool: return globs.size() >= 3, "two more globs", 240)
	check(glob_ticks.size() >= 3 and glob_ticks[1] - glob_ticks[0] == 90 and glob_ticks[2] - glob_ticks[1] == 90,
			"the next globs come exactly 90 ticks of play apart: no burst, no extra glob", str(glob_ticks))


func _check_stone_frozen() -> void:
	print("-- Carl's stones stop while paused")
	if not await _load_floor_6_with_everything():
		return
	var launcher: ProjectileLauncher = _carl().get_action_performer(SLINGSHOT)
	var stones: Array[Projectile] = []
	launcher.fired.connect(func(stone: Projectile) -> void: stones.append(stone))
	await hold_keys([KEY_RIGHT], 1)
	await tap_key(KEY_W)
	await wait_physics_frames(5)
	check(stones.size() == 1 and is_instance_valid(stones[0]), "W fires a stone")
	if stones.is_empty() or not is_instance_valid(stones[0]):
		return
	var stone := stones[0]
	await tap_key(KEY_ESCAPE)
	var stone_position := stone.global_position
	var flown := stone.get_distance_flown()
	await wait_physics_frames(PAUSED_TICKS)
	check(is_instance_valid(stone) and stone.global_position == stone_position and stone.get_distance_flown() == flown,
			"the stone in flight freezes")
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(3)
	check(is_instance_valid(stone) and stone.get_distance_flown() > flown, "it flies on after resuming")
	var stone_ref: WeakRef = weakref(stone)
	await wait_until(func() -> bool: return stone_ref.get_ref() == null, "the stone to finish its flight", 60)
	check(stones.size() == 1, "resuming fired no extra stone")


func _check_knockback_frozen() -> void:
	print("-- A Bat push stops while paused")
	if not await _load_floor_6_with_everything():
		return
	var carl := _carl()
	var blob: Enemy = current_scene.get_node("Actors/GelatinousBlob")
	blob.health.set_health(1000, 1000)
	carl.teleport_to(blob.global_position + Vector2(-100, 0))
	_donut().global_position = carl.global_position + Vector2(-40, -40)
	_donut().reset_physics_interpolation()
	await hold_keys([KEY_RIGHT], 1)
	if not await wait_until(func() -> bool: return carl.global_position.distance_to(blob.global_position) < 60.0,
			"the blob to come within the Bat's reach", 240):
		return
	var start := [Vector2.ZERO]
	var bat: MeleeAttack = carl.get_action_performer(BAT)
	var record_start := func(_direction: Vector2, hits: int) -> void:
		if hits > 0:
			start[0] = blob.global_position
	bat.performed.connect(record_start, CONNECT_ONE_SHOT)
	await tap_key(KEY_S)
	await wait_physics_frames(4)
	check(blob.is_knocked_back(), "the Bat knocks the blob back")
	await tap_key(KEY_ESCAPE)
	var blob_position := blob.global_position
	await wait_physics_frames(PAUSED_TICKS)
	check(blob.global_position == blob_position and blob.is_knocked_back(), "the push freezes, unfinished")
	await tap_key(KEY_ESCAPE)
	await wait_until(func() -> bool: return not blob.is_knocked_back(), "the push to finish", 60)
	check_near("after resuming, the push completes its 80 px", blob.global_position.x - start[0].x, 80.0, 1.0)


func _check_donut_recovery_frozen() -> void:
	print("-- Donut's recovery countdown stops while paused")
	if not await _load_floor_6_with_everything():
		return
	var donut := _donut()
	var without_pause := await _ticks_until_donut_gets_up(false)
	check(without_pause == 360, "without a pause she gets up after 360 ticks of play", str(without_pause))
	var with_pause := await _ticks_until_donut_gets_up(true)
	check(with_pause == 360, "with a %d-tick pause in the middle she still gets up after 360 ticks of play" % PAUSED_TICKS,
			str(with_pause))
	check(donut.health.current_health == 30, "she gets up with 30 HP")


## Downs Donut and returns how many ticks of play pass before she gets up. With `pause`, the
## pause menu is open for PAUSED_TICKS ticks in the middle, and her countdown must not move.
func _ticks_until_donut_gets_up(pause: bool) -> int:
	var donut := _donut()
	var downed_at := _counter.ticks
	donut.get_node("Hurtbox").take_hit(1000)
	if pause:
		await wait_physics_frames(100)
		await tap_key(KEY_ESCAPE)
		var time_left: float = donut.get_recovery_time_left()
		await wait_physics_frames(PAUSED_TICKS)
		check(donut.is_downed() and donut.get_recovery_time_left() == time_left, "her countdown holds while paused",
				"%.3f s left, was %.3f s" % [donut.get_recovery_time_left(), time_left])
		await tap_key(KEY_ESCAPE)
	await wait_until(func() -> bool: return not donut.is_downed(), "Donut to get up", 600)
	return _counter.ticks - downed_at


func _check_inventory_and_pause() -> void:
	print("-- Inventory and pause menu")
	game_state().start_new_run()
	if not await _load(FLOOR_1_PATH):
		return
	var menu := _menu()
	var pause := _pause_menu()
	await tap_key(KEY_SPACE)
	check(menu.is_open() and not pause.is_open() and paused, "Space opens the action menu when nothing is open")
	await tap_key(KEY_ESCAPE)
	check(not menu.is_open() and not pause.is_open() and not paused,
			"Escape closes the action menu, and the same key press does not open the pause menu")

	# Held Escape: its repeats must not open the pause menu once the action menu has closed.
	await tap_key(KEY_SPACE)
	send_key(KEY_ESCAPE, true)
	await wait_physics_frames(2)
	_send_echo(KEY_ESCAPE)
	await wait_physics_frames(2)
	send_key(KEY_ESCAPE, false)
	await wait_physics_frames(2)
	check(not menu.is_open() and not pause.is_open() and not paused, "a held Escape (with key repeat) only closes the action menu")

	await tap_key(KEY_SPACE)
	await tap_key(KEY_SPACE)
	check(not menu.is_open() and not paused, "Space still closes the action menu")

	await tap_key(KEY_ESCAPE)
	check(pause.is_open() and not menu.is_open(), "Escape opens the pause menu when nothing is open")
	var layout: Dictionary = game_state().action_slots.get_layout()
	await tap_key(KEY_SPACE)
	check(pause.is_open() and not menu.is_open() and paused, "Space does not open the action menu over the pause menu, nor close it")
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		await tap_key(key)
	check(pause.is_open() and not menu.is_open() and game_state().action_slots.get_layout() == layout,
			"W/A/S/D do nothing in the pause menu")
	await tap_key(KEY_ESCAPE)
	check(not pause.is_open() and not menu.is_open() and not paused, "Escape resumes")

	# Two keys in the same frame: whichever comes first opens its menu and the other is taken
	# by that menu, never both open.
	for keys: Array in [[KEY_SPACE, KEY_ESCAPE], [KEY_ESCAPE, KEY_SPACE], [KEY_ESCAPE, KEY_ESCAPE]]:
		for key: Key in keys:
			send_key(key, true)
		await wait_physics_frames(2)
		for key: Key in keys:
			send_key(key, false)
		await wait_physics_frames(2)
		var names := " + ".join(keys.map(func(key: Key) -> String: return OS.get_keycode_string(key)))
		check(not (menu.is_open() and pause.is_open()), names + " in one frame: never both menus open")
		check(paused == (menu.is_open() or pause.is_open()), names + ": the game is paused exactly when a menu is open")
		if menu.is_open():
			await tap_key(KEY_SPACE)
		if pause.is_open():
			await tap_key(KEY_ESCAPE)
	check(not paused, "back to play")


func _check_game_over() -> void:
	print("-- GAME OVER")
	game_state().start_new_run()
	if not await _load(FLOOR_1_PATH):
		return
	var carl := _carl()
	var game_over: Control = current_scene.get_node("HUD/%GameOverMessage")
	carl.health.take_damage(1000)
	await wait_physics_frames(2)
	check(paused and game_over.visible, "Carl is down: GAME OVER")
	var positions := _actor_positions()
	var ticks := _counter.ticks
	await tap_key(KEY_ESCAPE)
	check(not _pause_menu().is_open(), "Escape does not open the pause menu over GAME OVER")
	await tap_key(KEY_SPACE)
	check(not _menu().is_open(), "Space does not open the action menu over GAME OVER")
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(60)
	check(paused and game_over.visible and not _pause_menu().is_open() and not _menu().is_open(), "GAME OVER stays, alone")
	check(_actor_positions() == positions and _counter.ticks == ticks, "Donut and the enemies stay frozen")
	var level_id := current_scene.get_instance_id()
	await tap_key(KEY_ENTER)
	await wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != level_id,
			"the retried floor")
	await wait_physics_frames(3)
	check(not paused and _carl().health.current_health == 100, "Enter retries the floor as before")
	await tap_key(KEY_ESCAPE)
	check(_pause_menu().is_open() and paused, "after the retry, Escape opens the pause menu")
	await tap_key(KEY_ESCAPE)
	check(not paused, "and closes it")


func _check_stairs_and_pickups_frozen() -> void:
	print("-- Stairs and pickups do nothing while paused")
	game_state().start_new_run()
	if not await _load(FLOOR_5_PATH):
		return
	var carl := _carl()
	var pickup: Node2D = current_scene.get_node("Pickups/BaseballBat")
	await tap_key(KEY_ESCAPE)
	carl.teleport_to(pickup.global_position)
	await wait_physics_frames(60)
	check(is_instance_valid(pickup) and not game_state().inventory.has(BAT), "Carl standing on the Bat pickup does not collect it while paused")
	await tap_key(KEY_ESCAPE)
	await wait_physics_frames(3)
	check(not is_instance_valid(pickup) and game_state().inventory.has(BAT), "it is collected once the game runs again")

	var level := current_scene
	await tap_key(KEY_ESCAPE)
	carl.teleport_to(current_scene.get_node("Stairs").global_position)
	await wait_physics_frames(60)
	check(current_scene == level, "Carl standing on the stairs does not take them while paused")
	await tap_key(KEY_ESCAPE)
	check(await wait_for_scene(FLOOR_6_PATH), "they take him down once the game runs again")


func _check_stairs_and_death_in_one_tick() -> void:
	print("-- Carl reaches the stairs and dies in the same tick")
	var floor_2_path := "res://scenes/levels/floor_02.tscn"
	game_state().start_new_run()
	if not await _load(FLOOR_1_PATH):
		return
	var level := current_scene
	var entry_save := _save_text()
	# What the physics server does when Carl steps onto the stairs, then a hit that kills him, both
	# before the end of this physics step (where the stairs' deferred level change runs).
	level.get_node("Stairs").body_entered.emit(_carl())
	_carl().health.take_damage(1000)
	await wait_physics_frames(10)
	check(current_scene == level and paused and level.get_node("HUD/%GameOverMessage").visible,
			"GAME OVER stays up on Floor 1: the stairs do not open Floor 2 in a frozen game",
			"scene %s, paused %s" % [current_scene.scene_file_path, paused])
	check(_save_text() == entry_save and save_manager().load_checkpoint() != null,
			"the save is still the loadable Floor 1 checkpoint (no Floor 2 checkpoint with Carl at 0 HP)")
	var level_id := level.get_instance_id()
	await tap_key(KEY_ENTER)
	await wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != level_id, "the retried Floor 1")
	await wait_physics_frames(3)
	check(current_scene.scene_file_path == FLOOR_1_PATH and not paused and _carl().health.current_health == 100,
			"Enter retries Floor 1 as usual")
	# Control: the same signal alone, with Carl alive, takes him down to Floor 2.
	current_scene.get_node("Stairs").body_entered.emit(_carl())
	check(await wait_for_scene(floor_2_path), "the stairs work again: Floor 2")
	await wait_physics_frames(3)
	check(not paused and _carl().health.current_health == 100, "Floor 2 runs, Carl at 100 HP")


## Loads a level directly, with a TickCounter in it. Returns false (recording why) on failure.
func _load(path: String) -> bool:
	change_scene_to_file(path)
	if not await wait_for_scene(path):
		return false
	await wait_physics_frames(3)
	_counter = TickCounter.new()
	current_scene.add_child(_counter)
	return true


## Floor 6 with Carl at 60 / 100, the Slingshot on W, 2 potions on A, the Bat on S and Fists on D.
func _load_floor_6_with_everything() -> bool:
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 2)
	state.inventory.add(SLINGSHOT, 1)
	state.inventory.add(BAT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BAT, ActionSlots.SLOT_S)
	state.carl_health = 60
	return await _load(FLOOR_6_PATH)


func _full_layout() -> Dictionary:
	return {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_S: BAT, ActionSlots.SLOT_D: FISTS}


## Counts Carl's punches, stones and swings as they happen.
func _count_carl_actions(carl: Node) -> Dictionary:
	var counts := {"fists": 0, "slingshot": 0, "bat": 0}
	(carl.get_action_performer(FISTS) as MeleeAttack).performed.connect(
			func(_direction: Vector2, _hits: int) -> void: counts["fists"] += 1)
	(carl.get_action_performer(SLINGSHOT) as ProjectileLauncher).fired.connect(
			func(_stone: Projectile) -> void: counts["slingshot"] += 1)
	(carl.get_action_performer(BAT) as MeleeAttack).performed.connect(
			func(_direction: Vector2, _hits: int) -> void: counts["bat"] += 1)
	return counts


## The tick of play (TickCounter) of each time `performed` is emitted from now on.
func _record_ticks(performed: Signal) -> Array:
	var ticks := []
	performed.connect(func(_direction: Vector2, _hits: int) -> void: ticks.append(_counter.ticks))
	return ticks


func _actor_positions() -> Array:
	return current_scene.get_node("Actors").get_children().map(func(actor: Node2D) -> Vector2: return actor.global_position)


func _send_echo(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _pause_menu() -> CanvasLayer:
	return current_scene.get_node("PauseMenu")


func _menu() -> CanvasLayer:
	return current_scene.get_node("ActionMenu")


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _donut() -> CharacterBody2D:
	return current_scene.get_node("Actors/Donut")


## The texts of the pause menu's four rows (Settings since Phase 13).
func _rows() -> Array:
	return ["%ResumeRow", "%SettingsRow", "%ReturnToTitleRow", "%QuitRow"].map(
			func(row: String) -> String: return (_pause_menu().get_node(row) as Label).text)
