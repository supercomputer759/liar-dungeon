extends CharacterBody3D

signal focus_changed(is_interactable: bool)

@export var move_speed := 5.0
@export var sprint_multiplier := 1.45
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.002
@export var interaction_distance := 3.2

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var _movement_enabled := true
var _focused_object: Object


func _ready() -> void:
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)


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
