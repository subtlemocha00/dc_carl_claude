extends Enemy
## Gelatinous Blob (GAME_SPEC.md section 12): a slow, fairly tough enemy that hurts Carl by
## touching him. It waits until Carl comes within detection_range, then oozes after him along
## the level's navigation mesh, so a wall between them makes it go around instead of getting
## stuck behind it (Phase 7). It gives up when Carl gets farther away than chase_range.
## Hit flash, health bar and dying come from Enemy. While it is knocked back (Phase 9) it neither
## chases nor touches anyone (Enemy.update_knockback()).

@onready var contact_attack: MeleeAttack = $ContactAttack


func _physics_process(_delta: float) -> void:
	if update_knockback():
		return
	if update_activity():
		navigate_toward(target.global_position)
	else:
		stop_moving()
	# Touching Carl hurts him; the contact attack's cooldown limits how often.
	if contact_attack.can_attack() and not contact_attack.find_targets(Vector2.ZERO).is_empty():
		contact_attack.attack(Vector2.ZERO)
