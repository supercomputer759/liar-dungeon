class_name ItemDefinition
extends RefCounted

var item_id: StringName
var actual_name: String
var actual_description: String
var effect_type: StringName
var effect_amount: int
var maximum_stack: int
var rarity: StringName
var world_color: Color
var world_shape: StringName
var drop_weight: int

func _init(data: Dictionary) -> void:
	item_id = StringName(data["item_id"])
	actual_name = String(data["actual_name"])
	actual_description = String(data["actual_description"])
	effect_type = StringName(data["effect_type"])
	effect_amount = int(data["effect_amount"])
	maximum_stack = int(data["maximum_stack"])
	rarity = StringName(data["rarity"])
	world_color = data["world_color"] as Color
	world_shape = StringName(data["world_shape"])
	drop_weight = int(data["drop_weight"])
