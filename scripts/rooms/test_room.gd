extends Node3D

signal door_chosen(door_state: Dictionary, door: StaticBody3D)

@export_range(0.0, 1.0, 0.01) var lie_probability := 0.5

@onready var red_door: StaticBody3D = $RedDoor
@onready var blue_door: StaticBody3D = $BlueDoor
@onready var spawn_point: Marker3D = $SpawnPoint

var _debug_states: Array[Dictionary] = []


func _ready() -> void:
	red_door.interacted.connect(_on_door_interacted)
	blue_door.interacted.connect(_on_door_interacted)


func configure_room() -> void:
	var states := LieManager.create_binary_pair(lie_probability)
	red_door.configure(states[0])
	blue_door.configure(states[1])
	_debug_states = [red_door.get_debug_state(), blue_door.get_debug_state()]


func _on_door_interacted(door_state: Dictionary) -> void:
	var selected_door: StaticBody3D = red_door if String(door_state["id"]) == String(red_door.door_id) else blue_door
	door_chosen.emit(door_state, selected_door)


func set_doors_enabled(enabled: bool) -> void:
	red_door.set_interaction_enabled(enabled)
	blue_door.set_interaction_enabled(enabled)


func get_spawn_transform() -> Transform3D:
	return spawn_point.global_transform


func get_debug_states() -> Array[Dictionary]:
	return _debug_states

