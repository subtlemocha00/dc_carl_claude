extends CanvasLayer
## The action menu (Carl's inventory), opened and closed with Space. While it is open the game
## is paused. It lists everything Carl has, with quantities for carried items (for example
## "Small Health Potion x2"), and the player chooses which action each W/A/S/D slot holds:
## - Up/Down select one of Carl's actions;
## - W, A, S or D puts the selected action in that slot (and takes it out of its old slot);
## - Space or Escape closes the menu, and the game carries on.
## The menu only shows the Inventory and edits the ActionSlots it is given. It has no gameplay
## rules and stores no quantities of its own.
##
## Input notes:
## - It keeps running while the game is paused (process_mode Always). It only opens while the
##   game is not already paused, so it never opens over the GAME OVER screen.
## - While open it takes every key press, so none of them reach the game. Carl also ignores
##   keys that are still held when the menu closes (see carl.gd).
## - Its rows are Labels, which never take keyboard focus. Godot's built-in ui_accept action
##   includes Space, but with nothing focused it cannot "press" anything in the menu.

const ROW_COLOR := Color(0.9, 0.91, 0.94)
const SELECTED_ROW_COLOR := Color(1.0, 0.86, 0.35)
const UNASSIGNABLE_ROW_COLOR := Color(0.55, 0.56, 0.6)
const ROW_FONT_SIZE := 18

var _inventory: Inventory
var _action_slots: ActionSlots
var _selected_index := 0
var _selected_row_style := StyleBoxFlat.new()

@onready var slot_list: VBoxContainer = %SlotList
@onready var action_list: VBoxContainer = %ActionList
@onready var details_label: Label = %DetailsLabel


func _ready() -> void:
	visible = false
	_selected_row_style.bg_color = Color(1, 1, 1, 0.14)
	_selected_row_style.set_content_margin_all(4)
	_selected_row_style.set_corner_radius_all(3)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed(&"inventory_toggle") and not get_tree().paused:
			get_viewport().set_input_as_handled()
			open()
		return

	# While open, the menu takes every key press, so none of them reach the game.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"inventory_toggle") or event.is_action_pressed(&"pause_back"):
		close()
	elif event.is_action_pressed(&"move_up", true):
		_select(_selected_index - 1)
	elif event.is_action_pressed(&"move_down", true):
		_select(_selected_index + 1)
	else:
		for slot in ActionSlots.SLOTS:
			if event.is_action_pressed(slot):
				_assign_selected_action(slot)


## Gives the menu Carl's inventory and the slots it edits. The level calls this.
func setup(inventory: Inventory, action_slots: ActionSlots) -> void:
	_inventory = inventory
	_action_slots = action_slots
	_inventory.changed.connect(_refresh)
	_action_slots.changed.connect(_refresh)


func is_open() -> bool:
	return visible


## The highlighted action, or null if Carl has none.
func get_selected_action() -> ActionDefinition:
	var actions := _inventory.get_actions()
	if actions.is_empty():
		return null
	return actions[mini(_selected_index, actions.size() - 1)]


## Pauses the game and shows the menu. Does nothing if the game is already paused.
func open() -> void:
	if is_open() or get_tree().paused:
		return
	get_tree().paused = true
	_select(_selected_index)
	visible = true


## Hides the menu and lets the game carry on.
func close() -> void:
	if not is_open():
		return
	visible = false
	get_tree().paused = false


func _select(index: int) -> void:
	_selected_index = clampi(index, 0, maxi(0, _inventory.get_actions().size() - 1))
	var action := get_selected_action()
	details_label.text = action.description if action != null else "Carl has no actions yet."
	_refresh()


func _assign_selected_action(slot: StringName) -> void:
	var action := get_selected_action()
	if action == null:
		return
	if _action_slots.assign(action, slot):
		details_label.text = "%s is now on %s." % [action.display_name, ActionSlots.KEY_LABELS[slot]]
	else:
		details_label.text = "%s cannot be put in a slot." % action.display_name


## Rewrites every row from the current slots, inventory and selection.
func _refresh() -> void:
	for i in ActionSlots.SLOTS.size():
		var slot := ActionSlots.SLOTS[i]
		var text := "%s   %s" % [ActionSlots.KEY_LABELS[slot], _action_slots.get_display_name(slot)]
		_update_row(_get_row(slot_list, i), text, ROW_COLOR, false)

	var actions := _inventory.get_actions()
	# The list can shrink (for example after a retry takes an item back).
	_selected_index = clampi(_selected_index, 0, maxi(0, actions.size() - 1))
	for i in actions.size():
		var action := actions[i]
		var slot := _action_slots.find_slot(action)
		var where := "on " + ActionSlots.KEY_LABELS[slot] if slot != &"" else "no slot"
		var is_selected := i == _selected_index
		var color := SELECTED_ROW_COLOR if is_selected else ROW_COLOR
		if not action.assignable:
			color = UNASSIGNABLE_ROW_COLOR
		var text := "%s%s   (%s)" % ["> " if is_selected else "", _inventory.get_label(action), where]
		_update_row(_get_row(action_list, i), text, color, is_selected)
	while action_list.get_child_count() > actions.size():
		var extra_row := action_list.get_child(action_list.get_child_count() - 1)
		action_list.remove_child(extra_row)
		extra_row.queue_free()


## Returns row `index` of `list`, adding Labels until it exists.
func _get_row(list: VBoxContainer, index: int) -> Label:
	while list.get_child_count() <= index:
		var row := Label.new()
		row.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
		list.add_child(row)
	return list.get_child(index) as Label


func _update_row(row: Label, text: String, color: Color, highlighted: bool) -> void:
	row.text = text
	row.add_theme_color_override(&"font_color", color)
	if highlighted:
		row.add_theme_stylebox_override(&"normal", _selected_row_style)
	else:
		row.remove_theme_stylebox_override(&"normal")
