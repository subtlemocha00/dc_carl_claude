class_name ItemPickup
extends Area2D
## An item lying in a level. Carl picks it up by walking over it: he gets `quantity` of `item`,
## and the pickup disappears. No key is needed.
## - A consumable gives `quantity` more (label "Potion x2").
## - A reusable item gives ownership (label "Slingshot"; `quantity` just stays 1). Owning it
##   twice is impossible: the Inventory ignores a second one.
## To place loot, add an item_pickup.tscn instance to a level and set `item` and `quantity`;
## no code changes. An item with an icon shows it; others show the default pink gem. The
## collision mask only detects the "player" physics layer, so Donut, enemies and projectiles
## pass over pickups without taking them.
## Nothing remembers a picked-up pickup. Retrying a floor loads the level again, so its
## pickups are back, and the retry also takes back what Carl picked up there.
## Pickups can also be made while the game runs (Phase 12): a LootDrop creates one where its
## enemy died. Set `item` and `quantity` before adding it to the level; it then works exactly like
## a placed one.

@export var item: ActionDefinition
@export var quantity: int = 1

var _collected := false

@onready var label: Label = $Label
@onready var marker: Node2D = $Marker
@onready var default_gem: Node2D = $Marker/DefaultGem
@onready var icon: Sprite2D = $Marker/Icon


func _ready() -> void:
	if item == null:
		push_error("ItemPickup '%s' has no item set." % get_path())
		return
	label.text = item.get_label(quantity, true)
	icon.texture = item.icon
	icon.visible = item.icon != null
	default_gem.visible = item.icon == null
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
