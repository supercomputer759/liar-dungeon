extends Node

signal run_started
signal state_changed(state: StringName)
signal room_changed(current_room: int, total_rooms: int)
signal health_changed(actual_health: int, displayed_health: int, maximum_health: int)
signal choice_recorded(record: Dictionary)
signal run_finished(victory: bool, summary: Dictionary)

const STATE_PLAYING: StringName = &"PLAYING"
const STATE_TRANSITION: StringName = &"TRANSITION"
const STATE_DEAD: StringName = &"DEAD"
const STATE_VICTORY: StringName = &"VICTORY"

@export var total_rooms := 5
@export var starting_health := 100
@export var minimum_trap_damage := 15
@export var maximum_trap_damage := 35
@export_range(0.0, 1.0, 0.01) var health_lie_probability := 0.5
@export_range(0, 50, 1) var max_health_display_offset := 18
@export_range(1, 30, 1) var max_display_change_per_event := 16
## 0이면 매 판 새 시드, 0보다 크면 동일한 판을 재현한다.
@export var debug_fixed_seed: int = 0

var current_room := 1
var current_seed := 0
var actual_health := 100
var displayed_health := 100
var is_victory := false
var is_dead := false
var game_state: StringName = STATE_TRANSITION
var choice_history: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()


func start_new_run() -> void:
	current_seed = debug_fixed_seed if debug_fixed_seed > 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	_random.seed = current_seed
	_get_lie_manager().set_seed(current_seed)
	current_room = 1
	actual_health = starting_health
	displayed_health = starting_health
	is_victory = false
	is_dead = false
	choice_history.clear()
	_update_displayed_health(true)
	_set_state(STATE_PLAYING)
	run_started.emit()
	room_changed.emit(current_room, total_rooms)
	health_changed.emit(actual_health, displayed_health, starting_health)


func begin_transition() -> bool:
	if game_state != STATE_PLAYING:
		return false
	_set_state(STATE_TRANSITION)
	return true


func resolve_choice(door_state: Dictionary) -> Dictionary:
	var actual_safe := bool(door_state["actual_safe"])
	var damage_taken := 0
	if not actual_safe:
		damage_taken = _random.randi_range(minimum_trap_damage, maximum_trap_damage)
		actual_health = maxi(actual_health - damage_taken, 0)
	_update_displayed_health(false)
	var record := {
		"room_number": current_room,
		"chosen_door_id": String(door_state["id"]),
		"actual_safe": actual_safe,
		"displayed_safe": bool(door_state["displayed_safe"]),
		"door_was_lying": bool(door_state["is_lying"]),
		"damage_taken": damage_taken,
		"actual_health_after": actual_health,
		"displayed_health_after": displayed_health,
	}
	choice_history.append(record)
	choice_recorded.emit(record)
	health_changed.emit(actual_health, displayed_health, starting_health)
	if actual_health <= 0:
		is_dead = true
		_set_state(STATE_DEAD)
		run_finished.emit(false, get_summary())
	elif current_room >= total_rooms:
		is_victory = true
		_set_state(STATE_VICTORY)
		run_finished.emit(true, get_summary())
	else:
		current_room += 1
		room_changed.emit(current_room, total_rooms)
	return record


func continue_after_transition() -> void:
	if not is_dead and not is_victory:
		_update_displayed_health(false)
		health_changed.emit(actual_health, displayed_health, starting_health)
		_set_state(STATE_PLAYING)


func apply_combat_damage(damage: int) -> bool:
	if game_state != STATE_PLAYING or is_dead or is_victory:
		return false
	actual_health = maxi(actual_health - maxi(damage, 0), 0)
	_update_displayed_health(false)
	health_changed.emit(actual_health, displayed_health, starting_health)
	if actual_health <= 0:
		is_dead = true
		_set_state(STATE_DEAD)
		run_finished.emit(false, get_summary())
	return true


func complete_victory() -> void:
	if is_dead or is_victory:
		return
	is_victory = true
	_set_state(STATE_VICTORY)
	run_finished.emit(true, get_summary())


func is_health_display_lying() -> bool:
	return displayed_health != actual_health


func get_summary() -> Dictionary:
	return {
		"victory": is_victory,
		"reached_room": current_room,
		"cleared_rooms": current_room if is_victory else choice_history.size(),
		"actual_health": actual_health,
		"displayed_health": displayed_health,
		"history": choice_history.duplicate(true),
	}


func _update_displayed_health(initial_update: bool) -> void:
	var lie: Dictionary = _get_lie_manager().create_displayed_integer(actual_health, health_lie_probability, max_health_display_offset)
	var target := clampi(int(lie["displayed_value"]), 0, starting_health)
	if initial_update:
		displayed_health = target
	else:
		displayed_health = clampi(target, displayed_health - max_display_change_per_event, displayed_health + max_display_change_per_event)
		displayed_health = clampi(displayed_health, 0, starting_health)


func _set_state(next_state: StringName) -> void:
	game_state = next_state
	state_changed.emit(game_state)


func _get_lie_manager() -> Node:
	return get_node("/root/LieManager")
