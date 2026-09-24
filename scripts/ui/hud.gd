extends CanvasLayer
## Minimal Phase 2 HUD: Carl's hit points, and a game-over message while he is down.
## It sits on its own canvas layer, so it stays fixed on screen while the camera moves.

@onready var health_label: Label = %HealthLabel
@onready var game_over_message: Control = %GameOverMessage


## Starts displaying `health`. The level calls this once its actors are ready.
func show_health(health: Health) -> void:
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)
	game_over_message.visible = health.is_dead()


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP: %d / %d" % [current, maximum]


func _on_died() -> void:
	game_over_message.visible = true
