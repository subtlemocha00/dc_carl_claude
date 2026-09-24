extends Area2D
## An item lying in a level. Carl picks it up by walking over it: he gets `quantity` of `item`,
## and the pickup disappears. No key is needed.
## To place loot, add an item_pickup.tscn instance to a level and set `item` and `quantity`;
## no code changes. The collision mask only detects the "player" physics layer, so Donut and
## enemies walk over pickups without taking them.
## Nothing remembers a picked-up pickup. Retrying a floor loads the level again, so its
## pickups are back, and the retry also takes back what Carl picked up there.

@export var item: ActionDefinition
@export var quantity: int = 1

var _collected := false

@onready var label: Label = $Label
@onready var marker: Node2D = $Marker


func _ready() -> void:
	if item == null:
		push_error("ItemPickup '%s' has no item set." % get_path())
		return
	label.text = "%s x%d" % [item.get_short_name(), quantity]
	body_entered.connect(_on_body_entered)
	# Placeholder feedback: the marker bobs gently so the pickup stands out.
	var bob := create_tween().set_loops()
	bob.tween_property(marker, "position:y", -4.0, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(marker, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.has_method(&"collect_item"):
		return
	_collected = true
	body.collect_item(item, quantity)
	# Physics settings cannot change during the physics callback that reported the touch, so
	# detection stops at the end of the frame, when the pickup is also removed.
	set_deferred(&"monitoring", false)
	queue_free()
