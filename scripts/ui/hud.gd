extends CanvasLayer
## The in-game HUD: Carl's hit points, what each W/A/S/D action slot holds (with the quantity
## of a carried item, for example "A: Potion x2"), and the GAME OVER screen. It sits on its own
## canvas layer, so it stays fixed on screen while the camera moves.
## It keeps running while the game is paused (process_mode Always), so the GAME OVER screen
## can react to Enter.

## Emitted when the player presses Enter on the GAME OVER screen.
signal retry_requested

var _action_slots: ActionSlots

@onready var health_label: Label = %HealthLabel
@onready var action_slots_label: Label = %ActionSlotsLabel
@onready var game_over_message: Control = %GameOverMessage


func _unhandled_input(event: InputEvent) -> void:
	if game_over_message.visible and event.is_action_pressed(&"ui_confirm_game"):
		get_viewport().set_input_as_handled()
		retry_requested.emit()


## Starts displaying `health`. The level calls this once its actors are ready.
func show_health(health: Health) -> void:
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)
	game_over_message.visible = health.is_dead()


## Starts displaying what each action slot holds, and updates as soon as a slot or a quantity
## in `inventory` changes.
func show_action_slots(action_slots: ActionSlots, inventory: Inventory) -> void:
	_action_slots = action_slots
	action_slots.changed.connect(_on_action_slots_changed)
	inventory.changed.connect(_on_action_slots_changed)
	_on_action_slots_changed()


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP: %d / %d" % [current, maximum]


func _on_action_slots_changed() -> void:
	var parts := PackedStringArray()
	for slot in ActionSlots.SLOTS:
		parts.append("%s: %s" % [ActionSlots.KEY_LABELS[slot], _action_slots.get_display_name(slot, true)])
	action_slots_label.text = "   ".join(parts)


func _on_died() -> void:
	game_over_message.visible = true
