extends Label
## A Label that names the player's current keys (Phase 13), for signs such as "Arrow keys to
## move". `template` names controls in braces, "{move_up}/{move_left}/{move_down}/{move_right} to
## move", and each is replaced with the key bound to it now ("I/J/K/L to move").
## While every control the template names has its default key, `default_text` is shown instead
## when it is set, so a player who never changed a key sees the sign exactly as before.
## It refreshes when a binding changes (ControlBindings.HINT_GROUP).

@export_multiline var template: String = ""
@export_multiline var default_text: String = ""


func _ready() -> void:
	add_to_group(ControlBindings.HINT_GROUP)
	refresh_control_hints()


func refresh_control_hints() -> void:
	var all_default := true
	var filled := template
	for action in ControlBindings.ACTIONS:
		var placeholder := "{%s}" % action
		if not template.contains(placeholder):
			continue
		all_default = all_default and ControlBindings.get_key(action) == ControlBindings.DEFAULT_KEYS[action]
		filled = filled.replace(placeholder, ControlBindings.get_key_label(action))
	text = default_text if all_default and not default_text.is_empty() else filled
