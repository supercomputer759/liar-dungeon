extends Node3D

signal attack_started
signal cooldown_changed(on_cooldown: bool)
signal hit_confirmed(target: Node)

@export var actual_attack_damage := 22
@export var attack_range := 2.6
@export var attack_cooldown := 0.48
@export var collision_mask := 4

@onready var camera: Camera3D = get_parent() as Camera3D

var combat_enabled := true
var _cooldown_left := 0.0
var _rest_rotation := Vector3.ZERO


func _ready() -> void:
	_rest_rotation = rotation


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		if is_zero_approx(_cooldown_left):
			cooldown_changed.emit(false)


func try_attack() -> bool:
	if not combat_enabled or _cooldown_left > 0.0:
		return false
	_cooldown_left = attack_cooldown
	attack_started.emit()
	cooldown_changed.emit(true)
	_play_swing()
	var from := camera.global_position
	var to := from + -camera.global_basis.z * attack_range
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider := result["collider"] as Node
		if collider != null and collider.has_method("take_damage"):
			collider.call("take_damage", actual_attack_damage, -camera.global_basis.z)
			hit_confirmed.emit(collider)
	return true


func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled


func get_cooldown_left() -> float:
	return _cooldown_left


func _play_swing() -> void:
	# 칼을 뒤쪽 위로 당긴 뒤 카메라 앞쪽 아래로 내려친다.
	var windup_rotation := _rest_rotation + Vector3(deg_to_rad(-68.0), deg_to_rad(5.0), deg_to_rad(8.0))
	var slash_rotation := _rest_rotation + Vector3(deg_to_rad(62.0), deg_to_rad(-4.0), deg_to_rad(-8.0))
	rotation = windup_rotation
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation", slash_rotation, 0.14).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", _rest_rotation, 0.22).set_ease(Tween.EASE_OUT)
