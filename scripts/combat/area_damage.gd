class_name AreaDamage
extends Node2D
## Damage to every target inside a circle, once (Phase 12): the Blast Bomb's explosion
## (scenes/effects/blast_explosion.tscn). Whatever creates it places it, adds it to the level and
## calls detonate(). That one call:
## - finds every Hurtbox on `target_layers` that overlaps the circle of `radius` around this node
##   and can be hit (a dying enemy cannot), skipping any that belongs to `source`;
## - skips a Hurtbox hidden behind something on `blocking_layers` (walls): a ray from this node's
##   centre to the Hurtbox's centre must be clear, so a wall shields whoever stands behind it;
## - calls take_hit(damage) once on each one left, through the normal Hurtbox -> Health path;
## - shows a brief flash of the circle, then removes itself.
## A second detonate() does nothing, so one explosion can never hit anyone twice.
## Sides are Hurtbox layers, as for every attack: the Blast Bomb's explosion looks for
## enemy_hurtbox only, so it never hurts Carl or Donut (player_hurtbox), wherever they stand. It
## passes no Knockback: area damage and knockback are separate behaviours (see Knockback), and an
## explosion that should push would have to add that on purpose.
## Another area attack (a spell, an enemy's blast) is another scene with this node and its own
## numbers; nothing in here knows about bombs or enemy types.

## Emitted once, by detonate(), with every Hurtbox it damaged.
signal detonated(targets: Array[Hurtbox])

@export var damage: int = 20
## The radius of the circle (pixels). A Hurtbox is reached when its shape overlaps the circle, so
## a blob's 14 px Hurtbox is reached when its centre is up to radius + 14 px away.
@export var radius: float = 72.0
## Physics layers of the Hurtboxes it may damage (the side it hurts).
@export_flags_2d_physics var target_layers: int = 0
## Physics layers that shield a Hurtbox from it (walls are on "world"). 0 = nothing shields.
@export_flags_2d_physics var blocking_layers: int = 0
## Placeholder feedback: a filled circle the size of the area, fading out.
@export var flash_color: Color = Color(1.0, 0.55, 0.15, 0.45)
@export var ring_color: Color = Color(1.0, 0.9, 0.45, 0.9)
## How long the flash shows (seconds). It counts physics ticks, so it freezes while the game is
## paused, like everything else in play. The node removes itself when it ends.
@export var flash_duration: float = 0.35

## Who caused it (Carl, for his bomb). It never hurts a Hurtbox that belongs to its source.
var source: Node

var _detonated := false
var _flash_ticks_total := 0
var _flash_ticks_left := 0
var _hit_shape := CircleShape2D.new()


## Damages every target in the area once and starts the flash. Returns the Hurtboxes it damaged.
## Call it once the node is in the level and placed. Later calls do nothing and return [].
func detonate() -> Array[Hurtbox]:
	if _detonated:
		return []
	_detonated = true
	var targets := find_targets()
	for hurtbox in targets:
		hurtbox.take_hit(damage)
	_flash_ticks_total = maxi(1, roundi(flash_duration * Engine.physics_ticks_per_second))
	_flash_ticks_left = _flash_ticks_total
	queue_redraw()
	detonated.emit(targets)
	return targets


## True once detonate() has run.
func has_detonated() -> bool:
	return _detonated


## The Hurtboxes a detonation here would damage now, without damaging them (see the class
## description): each one at most once.
func find_targets() -> Array[Hurtbox]:
	_hit_shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _hit_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = target_layers
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var targets: Array[Hurtbox] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var hurtbox := result["collider"] as Hurtbox
		if hurtbox != null and hurtbox.can_be_hit() and hurtbox not in targets \
				and not _belongs_to_source(hurtbox) and not is_shielded(hurtbox):
			targets.append(hurtbox)
	return targets


## True if something on blocking_layers (a wall) lies between the centre of the area and the
## centre of `hurtbox`.
func is_shielded(hurtbox: Hurtbox) -> bool:
	if blocking_layers == 0:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, hurtbox.global_position, blocking_layers)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _belongs_to_source(hurtbox: Hurtbox) -> bool:
	return is_instance_valid(source) and source.is_ancestor_of(hurtbox)


func _physics_process(_delta: float) -> void:
	if _flash_ticks_left <= 0:
		return
	_flash_ticks_left -= 1
	queue_redraw()
	if _flash_ticks_left == 0:
		queue_free()


func _draw() -> void:
	if _flash_ticks_left <= 0:
		return
	var fade := float(_flash_ticks_left) / float(_flash_ticks_total)
	draw_circle(Vector2.ZERO, radius, Color(flash_color, flash_color.a * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(ring_color, ring_color.a * fade), 2.0)
	# A bright core, shrinking as it fades, so the centre of the blast is easy to see.
	draw_circle(Vector2.ZERO, radius * 0.35 * fade, Color(1.0, 0.95, 0.7, 0.8 * fade))
