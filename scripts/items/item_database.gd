class_name ItemDatabase
extends RefCounted

const Definition := preload("res://scripts/items/item_definition.gd")

static func get_definition(item_id: StringName) -> RefCounted:
	return Definition.new(_data(item_id))

static func get_random_item_id(random: RandomNumberGenerator, heal_bias := false) -> StringName:
	var weights := {&"BANDAGE": 45, &"POTION": 15, &"WHETSTONE": 22, &"GUARD_TALISMAN": 18}
	if heal_bias:
		weights[&"BANDAGE"] = 75
		weights[&"POTION"] = 35
	var total := 0
	for value in weights.values(): total += int(value)
	var roll := random.randi_range(1, total)
	for item_id in weights:
		roll -= int(weights[item_id])
		if roll <= 0: return item_id
	return &"BANDAGE"

static func _data(item_id: StringName) -> Dictionary:
	match item_id:
		&"POTION": return {"item_id": item_id, "actual_name": "큰 회복 물약", "actual_description": "실제 체력을 40 회복합니다.", "effect_type": &"HEAL", "effect_amount": 40, "maximum_stack": 2, "rarity": &"RARE", "world_color": Color(0.95, 0.22, 0.35), "world_shape": &"SPHERE", "drop_weight": 15}
		&"WHETSTONE": return {"item_id": item_id, "actual_name": "날카로운 숫돌", "actual_description": "이 방 동안 실제 공격력이 5 증가합니다.", "effect_type": &"ATTACK", "effect_amount": 5, "maximum_stack": 2, "rarity": &"UNCOMMON", "world_color": Color(0.68, 0.72, 0.76), "world_shape": &"BOX", "drop_weight": 22}
		&"GUARD_TALISMAN": return {"item_id": item_id, "actual_name": "수호 부적", "actual_description": "다음 2회 몬스터 피해를 30% 줄입니다.", "effect_type": &"GUARD", "effect_amount": 2, "maximum_stack": 2, "rarity": &"UNCOMMON", "world_color": Color(0.18, 0.88, 0.68), "world_shape": &"CYLINDER", "drop_weight": 18}
		_: return {"item_id": &"BANDAGE", "actual_name": "붕대", "actual_description": "실제 체력을 20 회복합니다.", "effect_type": &"HEAL", "effect_amount": 20, "maximum_stack": 3, "rarity": &"COMMON", "world_color": Color(0.9, 0.9, 0.78), "world_shape": &"BOX", "drop_weight": 45}
