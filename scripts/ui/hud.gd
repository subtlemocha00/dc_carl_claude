extends CanvasLayer
## The in-game HUD: Carl's and Donut's hit points ("Carl HP: 80 / 100", "Donut HP: 40 / 60",
## or "Donut HP: 0 / 60 - DOWNED"), what each action slot holds (with the quantity of a carried
## item, for example "A: Potion x2"), and the GAME OVER screen. It sits on its own canvas layer,
## so it stays fixed on screen while the camera moves.
## Phase 13: each slot is labelled with the key that triggers it now, not its logical name: with
## the W slot rebound to Q it reads "Q: Slingshot". The hint names the current Inventory key
## ("Space: action menu"). Both refresh when a binding changes (ControlBindings.HINT_GROUP).
## It keeps running while the game is paused (process_mode Always), so the GAME OVER screen
## can react to Enter.

const DONUT_COLOR := Color(1.0, 0.8, 0.55)
const DONUT_DOWNED_COLOR := Color(1.0, 0.45, 0.4)

## Emitted when the player presses Enter on the GAME OVER screen.
signal retry_requested

var _action_slots: ActionSlots

@onready var health_label: Label = %HealthLabel
@onready var donut_health_label: Label = %DonutHealthLabel
@onready var action_slots_label: Label = %ActionSlotsLabel
@onready var menu_hint: Label = %MenuHint
@onready var game_over_message: Control = %GameOverMessage


func _ready() -> void:
	add_to_group(ControlBindings.HINT_GROUP)
	refresh_control_hints()


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


## Starts displaying Donut's hit points, and whether she is downed.
func show_donut_health(health: Health) -> void:
	health.health_changed.connect(_on_donut_health_changed)
	_on_donut_health_changed(health.current_health, health.max_health)


## Starts displaying what each action slot holds, and updates as soon as a slot or a quantity
## in `inventory` changes.
func show_action_slots(action_slots: ActionSlots, inventory: Inventory) -> void:
	_action_slots = action_slots
	action_slots.changed.connect(_on_action_slots_changed)
	inventory.changed.connect(_on_action_slots_changed)
	_on_action_slots_changed()


## Shows the current keys (SettingsManager calls this on the hint group after a binding changes).
func refresh_control_hints() -> void:
	menu_hint.text = "%s: action menu     Esc: pause" % ControlBindings.get_key_label(&"inventory_toggle")
	if _action_slots != null:
		_on_action_slots_changed()


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "Carl HP: %d / %d" % [current, maximum]


func _on_donut_health_changed(current: int, maximum: int) -> void:
	donut_health_label.text = "Donut HP: %d / %d%s" % [current, maximum, "  -  DOWNED" if current == 0 else ""]
	donut_health_label.add_theme_color_override(&"font_color", DONUT_DOWNED_COLOR if current == 0 else DONUT_COLOR)


func _on_action_slots_changed() -> void:
	var parts := PackedStringArray()
	for slot in ActionSlots.SLOTS:
		parts.append("%s: %s" % [ControlBindings.get_key_label(slot), _action_slots.get_display_name(slot, true)])
	action_slots_label.text = "   ".join(parts)


func _on_died() -> void:
	game_over_message.visible = true
