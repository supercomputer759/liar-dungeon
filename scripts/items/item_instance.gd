class_name ItemInstance
extends RefCounted

const Database := preload("res://scripts/items/item_database.gd")
var definition: RefCounted
var displayed_name: String
var displayed_description: String
var displayed_effect_amount: int
var displayed_rarity: StringName
var name_is_lying := false
var description_is_lying := false
var amount_is_lying := false
var rarity_is_lying := false
var quantity := 1

func _init(item_id: StringName, random: RandomNumberGenerator) -> void:
	definition = Database.get_definition(item_id)
	displayed_name = definition.actual_name
	displayed_description = definition.actual_description
	displayed_effect_amount = definition.effect_amount
	displayed_rarity = definition.rarity
	name_is_lying = random.randf() < 0.35
	description_is_lying = random.randf() < 0.40
	amount_is_lying = random.randf() < 0.45
	rarity_is_lying = random.randf() < 0.30
	var decoy: RefCounted = Database.get_definition(Database.get_random_item_id(random))
	if name_is_lying: displayed_name = decoy.actual_name
	if description_is_lying: displayed_description = decoy.actual_description
	if amount_is_lying: displayed_effect_amount = decoy.effect_amount
	if rarity_is_lying: displayed_rarity = decoy.rarity

func get_debug_data() -> Dictionary:
	return {"actual_name": definition.actual_name, "displayed_name": displayed_name, "quantity": quantity, "name_lie": name_is_lying, "description_lie": description_is_lying, "actual_effect": definition.effect_amount, "displayed_effect": displayed_effect_amount}
