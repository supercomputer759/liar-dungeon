extends Node

signal attack_started
signal attack_cooldown_changed(on_cooldown: bool)
signal monster_focused(monster: Node)
signal hit_confirmed

@export var inspect_range := 12.0
@export var monster_collision_mask := 4

@onready var camera: Camera3D = get_node("../Head/Camera3D") as Camera3D
@onready var weapon: Node3D = get_node("../Head/Camera3D/BasicMeleeWeapon") as Node3D

var combat_enabled := true
var _focused_monster: Node


func _ready() -> void:
	weapon.attack_started.connect(attack_started.emit)
	weapon.cooldown_changed.connect(attack_cooldown_changed.emit)
	weapon.hit_confirmed.connect(_on_hit_confirmed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and combat_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		weapon.try_attack()


func _physics_process(_delta: float) -> void:
	var next_monster: Node = null
	if combat_enabled:
		var from := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from + -camera.global_basis.z * inspect_range, monster_collision_mask)
		var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var collider := result["collider"] as Node
			if collider != null and collider.has_method("get_display_data"):
				next_monster = collider
	if next_monster != _focused_monster:
		_focused_monster = next_monster
		monster_focused.emit(_focused_monster)


func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled
	weapon.set_combat_enabled(enabled)
	if not enabled and _focused_monster != null:
		_focused_monster = null
		monster_focused.emit(null)


func get_focused_monster() -> Node:
	return _focused_monster


func get_cooldown_left() -> float:
	return weapon.get_cooldown_left()


func set_actual_attack_damage(damage: int) -> void:
	weapon.actual_attack_damage = maxi(damage, 1)


func _on_hit_confirmed(_target: Node) -> void:
	hit_confirmed.emit()
