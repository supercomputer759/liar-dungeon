extends Node

## 실제 상태와 플레이어에게 표시할 상태를 독립적으로 생성한다.
var current_seed: int = 0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	set_seed(int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec())


func set_seed(seed_value: int) -> void:
	current_seed = seed_value
	_random.seed = current_seed


func create_lie_state(actual_value: bool, lie_probability: float) -> Dictionary:
	var safe_probability := clampf(lie_probability, 0.0, 1.0)
	var is_lying := _random.randf() < safe_probability
	return {
		"actual_value": actual_value,
		"displayed_value": actual_value != is_lying,
		"is_lying": is_lying,
	}


func create_binary_pair(lie_probability: float) -> Array[Dictionary]:
	var first_is_safe := _random.randi_range(0, 1) == 0
	return [
		create_lie_state(first_is_safe, lie_probability),
		create_lie_state(not first_is_safe, lie_probability),
	]


func create_displayed_integer(actual_value: int, lie_probability: float, max_offset: int) -> Dictionary:
	var is_lying := _random.randf() < clampf(lie_probability, 0.0, 1.0)
	var displayed_value := actual_value
	if is_lying and max_offset > 0:
		var offset := _random.randi_range(1, max_offset)
		if _random.randi_range(0, 1) == 0:
			offset = -offset
		displayed_value += offset
	return {
		"actual_value": actual_value,
		"displayed_value": displayed_value,
		"is_lying": displayed_value != actual_value,
	}
