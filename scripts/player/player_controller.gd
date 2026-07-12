extends CharacterBody3D

signal focus_changed(is_interactable: bool)

const FOOTSTEP_STREAMS := [
	preload("res://assets/audio/player/footsteps/footstep_00.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_01.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_02.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_03.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_04.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_05.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_06.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_07.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_08.ogg"),
	preload("res://assets/audio/player/footsteps/footstep_09.ogg"),
]
const HURT_STREAM := preload("res://assets/audio/player/hurt.ogg")

@export var move_speed := 5.0
@export var sprint_multiplier := 1.45
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.002
@export var interaction_distance := 3.2
@export_range(0.1, 1.0, 0.01) var footstep_interval := 0.42
@export_range(0.05, 5.0, 0.05) var footstep_min_speed := 0.35
@export_range(-40.0, 10.0, 0.5) var footstep_volume_db := -15.0
@export_range(-40.0, 10.0, 0.5) var hurt_volume_db := -5.0

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var _movement_enabled := true
var _focused_object: Object
var _footstep_left := 0.0
var _footstep_audio: AudioStreamPlayer
var _hurt_audio: AudioStreamPlayer
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
	_footstep_audio = AudioStreamPlayer.new()
	_footstep_audio.name = "FootstepAudio"
	_footstep_audio.volume_db = footstep_volume_db
	add_child(_footstep_audio)
	_hurt_audio = AudioStreamPlayer.new()
	_hurt_audio.name = "HurtAudio"
	_hurt_audio.stream = HURT_STREAM
	_hurt_audio.volume_db = hurt_volume_db
	add_child(_hurt_audio)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _movement_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)
	elif event.is_action_pressed("interact") and _focused_object != null and _focused_object.has_method("interact"):
		_focused_object.call("interact")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _movement_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if _movement_enabled else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var current_speed := move_speed * sprint_multiplier if _movement_enabled and Input.is_action_pressed("sprint") else move_speed
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	_update_footsteps(horizontal_speed, delta)
	_update_focus()


func _update_focus() -> void:
	var next_object: Object = null
	if _movement_enabled and interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		if collider != null and collider.has_method("interact"):
			next_object = collider
	if next_object != _focused_object:
		_focused_object = next_object
		focus_changed.emit(_focused_object != null)


func teleport_to(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled and _focused_object != null:
		_focused_object = null
		focus_changed.emit(false)


func apply_knockback(direction: Vector3, strength: float) -> void:
	velocity.x += direction.x * strength
	velocity.z += direction.z * strength


func play_hurt_sound() -> void:
	_hurt_audio.pitch_scale = _random.randf_range(0.95, 1.05)
	_hurt_audio.volume_db = hurt_volume_db
	_hurt_audio.play()


func _update_footsteps(horizontal_speed: float, delta: float) -> void:
	_footstep_left = maxf(_footstep_left - delta, 0.0)
	if not _movement_enabled or horizontal_speed < footstep_min_speed or not is_on_floor():
		return
	if _footstep_left > 0.0:
		return
	_play_footstep(horizontal_speed)
	var speed_ratio := clampf(horizontal_speed / maxf(move_speed, 0.01), 0.8, sprint_multiplier)
	_footstep_left = footstep_interval / speed_ratio


func _play_footstep(current_speed: float) -> void:
	if FOOTSTEP_STREAMS.is_empty():
		return
	_footstep_audio.stream = FOOTSTEP_STREAMS[_random.randi_range(0, FOOTSTEP_STREAMS.size() - 1)]
	_footstep_audio.pitch_scale = _random.randf_range(0.92, 1.08)
	_footstep_audio.volume_db = footstep_volume_db + _random.randf_range(-1.0, 1.0) + (1.5 if current_speed > move_speed else 0.0)
	_footstep_audio.play()
