extends RefCounted

const DISPLAY_NAMES: PackedStringArray = [
	"연약한 던전 벌레", "평범한 경비병", "무해한 주민", "굶주린 포식자", "절대 죽지 않는 자", "훈련용 허수아비"
]
const DANGER_NAMES: PackedStringArray = ["무해함", "낮음", "보통", "위험", "치명적"]

var actual_name := "던전 추적자"
var displayed_name := "던전 추적자"
var actual_max_health := 75
var displayed_max_health := 75
var actual_health := 75
var displayed_health := 75
var actual_attack_damage := 18
var displayed_attack_damage := 18
var actual_danger_level := 2
var displayed_danger_level := 2
var name_is_lying := false
var max_health_is_lying := false
var health_is_lying := false
var attack_is_lying := false
var danger_is_lying := false
var _random := RandomNumberGenerator.new()


func configure(actual_data: Dictionary, probabilities: Dictionary, seed_value: int) -> void:
	_random.seed = seed_value
	actual_name = String(actual_data["name"])
	actual_max_health = int(actual_data["max_health"])
	actual_health = actual_max_health
	actual_attack_damage = int(actual_data["attack_damage"])
	actual_danger_level = clampi(int(actual_data["danger_level"]), 0, DANGER_NAMES.size() - 1)
	name_is_lying = _roll(float(probabilities["name"]))
	displayed_name = DISPLAY_NAMES[_random.randi_range(0, DISPLAY_NAMES.size() - 1)] if name_is_lying else actual_name
	max_health_is_lying = _roll(float(probabilities["max_health"]))
	displayed_max_health = maxi(1, actual_max_health + _signed_offset(maxi(15, actual_max_health))) if max_health_is_lying else actual_max_health
	health_is_lying = _roll(float(probabilities["health"]))
	displayed_health = clampi(actual_health + _signed_offset(maxi(12, actual_max_health / 2)), 0, displayed_max_health) if health_is_lying else mini(actual_health, displayed_max_health)
	attack_is_lying = _roll(float(probabilities["attack"]))
	displayed_attack_damage = maxi(1, actual_attack_damage + _signed_offset(maxi(6, actual_attack_damage))) if attack_is_lying else actual_attack_damage
	danger_is_lying = _roll(float(probabilities["danger"]))
	displayed_danger_level = _random.randi_range(0, DANGER_NAMES.size() - 1) if danger_is_lying else actual_danger_level


func apply_actual_damage(damage: int) -> void:
	actual_health = maxi(actual_health - maxi(damage, 0), 0)
	if health_is_lying:
		if _random.randf() < 0.08 and actual_health > 0:
			displayed_health = mini(displayed_health + _random.randi_range(1, 5), displayed_max_health)
		else:
			var shown_damage := maxi(1, roundi(float(damage) * _random.randf_range(0.5, 1.45)))
			displayed_health = maxi(displayed_health - shown_damage, 0)
	else:
		displayed_health = clampi(actual_health, 0, displayed_max_health)


func get_display_data() -> Dictionary:
	return {
		"name": displayed_name,
		"health": displayed_health,
		"max_health": displayed_max_health,
		"attack_damage": displayed_attack_damage,
		"danger": DANGER_NAMES[displayed_danger_level],
	}


func get_debug_data() -> Dictionary:
	return {
		"actual_name": actual_name, "displayed_name": displayed_name,
		"actual_health": actual_health, "actual_max_health": actual_max_health,
		"displayed_health": displayed_health, "displayed_max_health": displayed_max_health,
		"actual_attack": actual_attack_damage, "displayed_attack": displayed_attack_damage,
		"actual_danger": DANGER_NAMES[actual_danger_level], "displayed_danger": DANGER_NAMES[displayed_danger_level],
		"name_lie": name_is_lying, "health_lie": health_is_lying or max_health_is_lying,
		"attack_lie": attack_is_lying, "danger_lie": danger_is_lying,
	}


func _roll(probability: float) -> bool:
	return _random.randf() < clampf(probability, 0.0, 1.0)


func _signed_offset(maximum: int) -> int:
	var value := _random.randi_range(1, maximum)
	return value if _random.randi_range(0, 1) == 1 else -value
