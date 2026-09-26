class_name ControlBindings
extends RefCounted
## The gameplay controls the player can rebind (Phase 13): which they are, their default keys,
## which keys they may use, and how a key is named on screen.
##
## A control is an InputMap action (move_up, action_w, inventory_toggle, ...). Gameplay code only
## ever asks for actions, never for keys, so rebinding a control changes which physical key
## triggers the action and nothing else. In particular an action slot (action_w, the "W slot")
## keeps what it holds when its key changes: slot contents are run state (GameState, the save),
## key bindings are application settings (SettingsManager, settings.json).
##
## The menus' own keys are not controls and never change: Up/Down (and Left/Right in questions)
## are the menu_* actions, Enter is ui_confirm_game and Escape is pause_back. Escape and Enter
## are therefore reserved: no control may use them, so every menu always stays usable.
##
## Everything here is static and reads the InputMap directly, so the HUD, the action menu and
## the signs can show the current keys without depending on the SettingsManager autoload.

## Nodes that show key names join this group and have a refresh_control_hints() method.
## SettingsManager calls it on the whole group whenever a binding changes.
const HINT_GROUP := &"control_hints"

## Every rebindable control, in the order the Settings screen lists them.
const ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"action_w", &"action_a", &"action_s", &"action_d",
	&"inventory_toggle",
]

## The name of each control on the Settings screen and in messages.
const DISPLAY_NAMES: Dictionary[StringName, String] = {
	&"move_up": "Move Up",
	&"move_down": "Move Down",
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	&"action_w": "Action Slot W",
	&"action_a": "Action Slot A",
	&"action_s": "Action Slot S",
	&"action_d": "Action Slot D",
	&"inventory_toggle": "Inventory",
}

## The canonical bindings, which Reset to Defaults restores. They are also the bindings in
## project.godot, so a game with no settings file behaves exactly as before Phase 13.
const DEFAULT_KEYS: Dictionary[StringName, Key] = {
	&"move_up": KEY_UP,
	&"move_down": KEY_DOWN,
	&"move_left": KEY_LEFT,
	&"move_right": KEY_RIGHT,
	&"action_w": KEY_W,
	&"action_a": KEY_A,
	&"action_s": KEY_S,
	&"action_d": KEY_D,
	&"inventory_toggle": KEY_SPACE,
}

## Keys that belong to the menus and pausing, never to a control.
const RESERVED_KEYS: Dictionary[Key, String] = {
	KEY_ESCAPE: "Escape is reserved for pausing and going back.",
	KEY_ENTER: "Enter is reserved for confirming in menus.",
	KEY_KP_ENTER: "Enter is reserved for confirming in menus.",
}

## Keys outside the printable range that a control may use. Everything else outside that range
## (modifiers such as Shift, Ctrl and Alt on their own, lock keys, function keys, media keys) is
## refused. Printable keys (letters, digits, Space and punctuation) are all allowed.
const EXTRA_ALLOWED_KEYS: Array[Key] = [
	KEY_TAB, KEY_BACKSPACE, KEY_INSERT, KEY_DELETE, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN,
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
	KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_ADD, KEY_KP_PERIOD,
]


static func get_display_name(action: StringName) -> String:
	return DISPLAY_NAMES.get(action, String(action))


## The key currently bound to `action` in the InputMap (its first keyboard event), or KEY_NONE.
static func get_key(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null:
			return get_event_key(key_event)
	return KEY_NONE


## The name of the key currently bound to `action`, as shown to the player ("W", "Space", "Up").
static func get_key_label(action: StringName) -> String:
	return get_key_name(get_key(action))


## The name of `key` as shown to the player and stored in settings.json: Godot's own key name,
## which does not depend on the keyboard layout ("Q", "1", "Space", "Up", "Tab", "Kp 1").
static func get_key_name(key: Key) -> String:
	return "?" if key == KEY_NONE else OS.get_keycode_string(key)


## The key named `key_name` (see get_key_name()), or KEY_NONE if there is no such key or the name
## is not exactly the one get_key_name() would give it.
static func get_key_from_name(key_name: String) -> Key:
	var key := OS.find_keycode_from_string(key_name)
	if key == KEY_NONE or OS.get_keycode_string(key) != key_name:
		return KEY_NONE
	return key


## The physical key of a key event (its position on the keyboard, as project.godot binds keys).
## Events made without one, such as some synthetic ones, fall back to their logical keycode.
static func get_event_key(event: InputEventKey) -> Key:
	if event.physical_keycode != KEY_NONE:
		return event.physical_keycode
	return event.keycode & KEY_CODE_MASK


## Why `key` cannot be bound to a control, or "" if it can.
static func get_key_problem(key: Key) -> String:
	if RESERVED_KEYS.has(key):
		return RESERVED_KEYS[key]
	if key == KEY_NONE:
		return "That key cannot be used for a control."
	var printable := key >= KEY_SPACE and key <= KEY_ASCIITILDE
	if (printable or key in EXTRA_ALLOWED_KEYS) and get_key_from_name(get_key_name(key)) == key:
		return ""
	return "%s cannot be used for a control." % get_key_name(key)
