class_name PlayerItemState
extends Node

signal changed
const MAX_ATTACK_BONUS := 10
const MAX_GUARD_CHARGES := 4
var current_attack_bonus := 0
var guard_charges := 0
var guard_reduction_ratio := 0.30

func reset_room() -> void:
	current_attack_bonus = 0
	guard_charges = 0
	changed.emit()

func add_attack_bonus(amount: int) -> bool:
	if current_attack_bonus >= MAX_ATTACK_BONUS: return false
	current_attack_bonus = mini(current_attack_bonus + amount, MAX_ATTACK_BONUS)
	changed.emit()
	return true

func add_guard_charges(amount: int) -> bool:
	if guard_charges >= MAX_GUARD_CHARGES: return false
	guard_charges = mini(guard_charges + amount, MAX_GUARD_CHARGES)
	changed.emit()
	return true

func reduce_monster_damage(damage: int) -> Dictionary:
	var result := {"raw": damage, "final": damage, "guarded": false}
	if guard_charges > 0:
		guard_charges -= 1
		result["final"] = maxi(1, roundi(float(damage) * (1.0 - guard_reduction_ratio)))
		result["guarded"] = true
		changed.emit()
	return result
