extends Node3D

signal encounter_started(remaining: int)
signal remaining_changed(remaining: int)
signal wave_changed(current_wave: int, total_waves: int, pending: int)
signal warning_requested(message: String)
signal encounter_completed
signal final_boss_defeated
signal player_hit_requested(damage: int, direction: Vector3, impact_strength: float)
signal monster_defeated(monster: Node)

const MonsterScene := preload("res://scenes/enemies/dungeon_stalker.tscn")
const ROOM_WAVES := {
	2: [{"HUNTER": 3}],
	3: [{"HUNTER": 2, "RUSHER": 1}, {"HUNTER": 2}],
	4: [{"HUNTER": 3, "RUSHER": 1}, {"HUNTER": 2, "BRUTE": 1}],
	5: [{"HUNTER": 2, "RUSHER": 2}, {"BOSS": 1, "HUNTER": 2}],
}
const ROOM_MAX_ALIVE := {2: 3, 3: 4, 4: 6, 5: 6}
const SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-5.2, 0.05, -5.8), Vector3(5.2, 0.05, -5.8),
	Vector3(-5.4, 0.05, -1.8), Vector3(5.4, 0.05, -1.8),
	Vector3(-3.2, 0.05, -7.4), Vector3(3.2, 0.05, -7.4),
]

@export_range(0.1, 1.0, 0.05) var spawn_interval := 0.32
@export_range(0.8, 1.5, 0.1) var wave_warning_time := 1.0
@export_range(1.0, 3.0, 0.1) var between_wave_delay := 1.5

var _player: CharacterBody3D
var _difficulty: Dictionary = {}
var _difficulty_name: StringName = &"NORMAL"
var _living_monsters: Array[Node] = []
var _pending_roles: Array[StringName] = []
var _attack_slot_holders: Array[Node] = []
var _rusher_slot_holder: Node
var _waves: Array = []
var _current_room := 0
var _current_wave := 0
var _max_alive := 0
var _run_seed := 0
var _spawn_counter := 0
var _last_spawn_index := -1
var _phase_timer := 0.0
var _spawn_timer := 0.0
var _encounter_active := false
var _waiting_to_start_wave := false
var _boss_reinforcement_used := false
var _random := RandomNumberGenerator.new()
var _spawn_positions: Array[Vector3] = []


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			_spawn_positions.append((child as Marker3D).position)
	if _spawn_positions.is_empty():
		_spawn_positions.assign(SPAWN_POSITIONS)


func setup(player: CharacterBody3D, difficulty: Dictionary = {}, profile_name: StringName = &"NORMAL") -> void:
	_player = player
	_difficulty = difficulty if not difficulty.is_empty() else {"health": 1.0, "damage": 1.0, "speed": 1.0, "count": 1.0, "max_alive": 6, "attack_slots": 2}
	_difficulty_name = profile_name


func _process(delta: float) -> void:
	if not _encounter_active:
		return
	_phase_timer = maxf(_phase_timer - delta, 0.0)
	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if _waiting_to_start_wave and _phase_timer <= 0.0:
		_begin_next_wave()
	elif not _pending_roles.is_empty() and _spawn_timer <= 0.0 and _living_monsters.size() < _max_alive:
		_spawn_next_pending()
	elif not _waiting_to_start_wave and _pending_roles.is_empty() and _living_monsters.is_empty():
		if _current_wave < _waves.size():
			_schedule_next_wave(between_wave_delay)
		else:
			_finish_encounter()


func start_room_encounter(room_number: int, run_seed: int) -> bool:
	clear_encounter()
	if not ROOM_WAVES.has(room_number):
		remaining_changed.emit(0)
		wave_changed.emit(0, 0, 0)
		return false
	_current_room = room_number
	_run_seed = run_seed
	_random.seed = run_seed + room_number * 7919
	_waves = ROOM_WAVES[room_number].duplicate(true)
	_max_alive = mini(int(ROOM_MAX_ALIVE[room_number]), int(_difficulty.get("max_alive", 6)))
	_current_wave = 0
	_encounter_active = true
	_boss_reinforcement_used = false
	encounter_started.emit(0)
	_schedule_next_wave(wave_warning_time)
	return true


func request_attack_slot(monster: Node, is_charge: bool) -> bool:
	_cleanup_slots()
	if is_charge and _rusher_slot_holder != null and is_instance_valid(_rusher_slot_holder):
		return false
	var limit := 3 if _current_room == 5 else int(_difficulty.get("attack_slots", 2))
	if _attack_slot_holders.size() >= limit:
		return false
	_attack_slot_holders.append(monster)
	if is_charge:
		_rusher_slot_holder = monster
	return true


func release_attack_slot(monster: Node) -> void:
	_attack_slot_holders.erase(monster)
	if _rusher_slot_holder == monster:
		_rusher_slot_holder = null


func get_living_count() -> int:
	return _living_monsters.size()


func get_pending_count() -> int:
	return _pending_roles.size()


func get_wave_status() -> Dictionary:
	return {
		"current": _current_wave, "total": _waves.size(), "pending": _pending_roles.size(),
		"attack_used": _attack_slot_holders.size(), "attack_max": 3 if _current_room == 5 else int(_difficulty.get("attack_slots", 2)),
		"difficulty": _difficulty_name, "health_multiplier": _difficulty.get("health", 1.0),
		"damage_multiplier": _difficulty.get("damage", 1.0), "speed_multiplier": _difficulty.get("speed", 1.0),
	}


func get_all_debug_monsters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for monster in _living_monsters:
		if is_instance_valid(monster):
			result.append(monster.get_debug_data())
	return result


func has_close_behind_threat(player_forward: Vector3) -> bool:
	for monster in _living_monsters:
		if not is_instance_valid(monster):
			continue
		var to_monster: Vector3 = monster.global_position - _player.global_position
		to_monster.y = 0.0
		if to_monster.length() < 4.0 and to_monster.normalized().dot(player_forward.normalized()) < -0.35:
			return true
	return false


func get_debug_monster(preferred: Node = null) -> Node:
	if preferred != null and is_instance_valid(preferred) and preferred in _living_monsters:
		return preferred
	var closest: Node = null
	var closest_distance := INF
	for monster in _living_monsters:
		if is_instance_valid(monster):
			var distance: float = monster.global_position.distance_to(_player.global_position)
			if distance < closest_distance:
				closest = monster
				closest_distance = distance
	return closest


func stop_all() -> void:
	_encounter_active = false
	_pending_roles.clear()
	for monster in _living_monsters:
		if is_instance_valid(monster):
			monster.set_ai_active(false)
	_attack_slot_holders.clear()
	_rusher_slot_holder = null


func clear_encounter() -> void:
	_encounter_active = false
	_pending_roles.clear()
	for monster in _living_monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	_living_monsters.clear()
	_attack_slot_holders.clear()
	_rusher_slot_holder = null
	_current_wave = 0
	_waves = []


func skip_to_next_wave() -> void:
	if _encounter_active and _waiting_to_start_wave:
		_phase_timer = 0.0


func _schedule_next_wave(delay: float) -> void:
	_waiting_to_start_wave = true
	_phase_timer = delay
	warning_requested.emit("무언가 다가옵니다." if _current_wave == 0 else "발소리가 늘어납니다.")
	wave_changed.emit(_current_wave, _waves.size(), _pending_roles.size())


func _begin_next_wave() -> void:
	_waiting_to_start_wave = false
	_current_wave += 1
	var wave: Dictionary = _waves[_current_wave - 1]
	_pending_roles.clear()
	for role_name in wave:
		var base_count := int(wave[role_name])
		var scaled_count := maxi(1, roundi(base_count * float(_difficulty.get("count", 1.0))))
		for _index in scaled_count:
			_pending_roles.append(StringName(role_name))
	_shuffle_pending_roles()
	_spawn_timer = 0.0
	wave_changed.emit(_current_wave, _waves.size(), _pending_roles.size())


func _spawn_next_pending() -> void:
	var role: StringName = _pending_roles.pop_front()
	_spawn_counter += 1
	var monster := MonsterScene.instantiate() as CharacterBody3D
	add_child(monster)
	monster.position = _choose_spawn_position()
	monster.setup(_player, _run_seed + _current_room * 1009 + _spawn_counter * 37, role, _difficulty, self, _spawn_counter)
	monster.monster_died.connect(_on_monster_died)
	monster.attack_landed.connect(player_hit_requested.emit)
	monster.health_ratio_changed.connect(_on_monster_health_ratio_changed)
	_living_monsters.append(monster)
	_spawn_timer = spawn_interval
	remaining_changed.emit(_living_monsters.size())
	wave_changed.emit(_current_wave, _waves.size(), _pending_roles.size())


func _choose_spawn_position() -> Vector3:
	var candidates: Array[int] = []
	for index in _spawn_positions.size():
		if index != _last_spawn_index and _spawn_positions[index].distance_to(_player.position) >= 7.0:
			candidates.append(index)
	if candidates.is_empty():
		candidates.append((_last_spawn_index + 1) % _spawn_positions.size())
	var chosen: int = candidates[(_spawn_counter * 3 + _current_wave) % candidates.size()]
	_last_spawn_index = chosen
	return _spawn_positions[chosen]


func _on_monster_health_ratio_changed(monster: Node, ratio: float) -> void:
	if _current_room == 5 and not _boss_reinforcement_used and monster.monster_role == &"BOSS" and ratio <= 0.55:
		_boss_reinforcement_used = true
		_pending_roles.append(&"HUNTER")
		_pending_roles.append(&"HUNTER")
		warning_requested.emit("더 많은 발소리가 가까워집니다.")
		wave_changed.emit(_current_wave, _waves.size(), _pending_roles.size())


func _on_monster_died(monster: Node) -> void:
	monster_defeated.emit(monster)
	release_attack_slot(monster)
	_living_monsters.erase(monster)
	remaining_changed.emit(_living_monsters.size())
	if _living_monsters.size() == 1 and _pending_roles.is_empty():
		warning_requested.emit("마지막 한 마리가 남았습니다.")


func _finish_encounter() -> void:
	_encounter_active = false
	wave_changed.emit(_waves.size(), _waves.size(), 0)
	if _current_room == 5:
		final_boss_defeated.emit()
	else:
		encounter_completed.emit()


func _cleanup_slots() -> void:
	for index in range(_attack_slot_holders.size() - 1, -1, -1):
		if not is_instance_valid(_attack_slot_holders[index]):
			_attack_slot_holders.remove_at(index)
	if _rusher_slot_holder != null and not is_instance_valid(_rusher_slot_holder):
		_rusher_slot_holder = null


func _shuffle_pending_roles() -> void:
	for index in range(_pending_roles.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := _pending_roles[index]
		_pending_roles[index] = _pending_roles[swap_index]
		_pending_roles[swap_index] = temporary
