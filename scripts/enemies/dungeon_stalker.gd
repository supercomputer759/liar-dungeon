extends CharacterBody3D

signal monster_died(monster: Node)
signal attack_landed(damage: int, direction: Vector3, impact_strength: float)
signal display_data_changed(monster: Node)
signal health_ratio_changed(monster: Node, ratio: float)

const LieProfileScript := preload("res://scripts/enemies/monster_lie_profile.gd")
const STATE_IDLE: StringName = &"IDLE"
const STATE_CHASE: StringName = &"CHASE"
const STATE_ATTACK_WINDUP: StringName = &"ATTACK_WINDUP"
const STATE_ATTACK: StringName = &"ATTACK"
const STATE_CHARGE_WINDUP: StringName = &"CHARGE_WINDUP"
const STATE_CHARGE: StringName = &"CHARGE"
const STATE_RECOVER: StringName = &"RECOVER"
const STATE_HURT: StringName = &"HURT"
const STATE_DEAD: StringName = &"DEAD"

@export_range(0.0, 1.0, 0.01) var name_lie_probability := 0.4
@export_range(0.0, 1.0, 0.01) var max_health_lie_probability := 0.55
@export_range(0.0, 1.0, 0.01) var health_lie_probability := 0.55
@export_range(0.0, 1.0, 0.01) var attack_lie_probability := 0.5
@export_range(0.0, 1.0, 0.01) var danger_lie_probability := 0.45

@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var left_arm: MeshInstance3D = $Visual/LeftArm
@onready var right_arm: MeshInstance3D = $Visual/RightArm
@onready var eyes: MeshInstance3D = $Visual/Eyes
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var nameplate: Label3D = $Nameplate

var monster_role: StringName = &"HUNTER"
var actual_max_health := 105
var actual_attack_damage := 22
var actual_danger_level := 2
var move_speed := 4.2
var detection_range := 18.0
var attack_range := 2.0
var attack_cooldown := 0.95
var attack_windup := 0.4
var hurt_duration := 0.18
var charge_speed := 8.0
var charge_windup := 0.55
var charge_recovery := 0.95
var ai_state: StringName = STATE_IDLE
var target: CharacterBody3D
var profile: RefCounted
var formation_index := 0

var _coordinator: Node
var _state_time := 0.0
var _cooldown_left := 0.0
var _hurt_direction := Vector3.ZERO
var _charge_direction := Vector3.ZERO
var _has_attack_slot := false
var _active := true
var _random := RandomNumberGenerator.new()
var _body_material := StandardMaterial3D.new()
var _eye_material := StandardMaterial3D.new()
var _base_body_color := Color(0.22, 0.25, 0.27)


func _ready() -> void:
	add_to_group("active_monsters")
	_body_material.roughness = 0.72
	body_mesh.material_override = _body_material
	_eye_material.emission_enabled = true
	_eye_material.emission = Color(1.0, 0.035, 0.01)
	eyes.material_override = _eye_material


func setup(player: CharacterBody3D, seed_value: int, role: StringName, multipliers: Dictionary, coordinator: Node, index := 0) -> void:
	target = player
	monster_role = role
	_coordinator = coordinator
	formation_index = index
	_random.seed = seed_value
	_apply_role_stats(role)
	actual_max_health = maxi(1, roundi(actual_max_health * float(multipliers.get("health", 1.0))))
	actual_attack_damage = maxi(1, roundi(actual_attack_damage * float(multipliers.get("damage", 1.0))))
	move_speed *= float(multipliers.get("speed", 1.0))
	profile = LieProfileScript.new()
	profile.configure({"name": _actual_role_name(), "max_health": actual_max_health, "attack_damage": actual_attack_damage, "danger_level": actual_danger_level}, {
		"name": name_lie_probability, "max_health": max_health_lie_probability, "health": health_lie_probability,
		"attack": attack_lie_probability, "danger": danger_lie_probability,
	}, seed_value)
	nameplate.text = profile.displayed_name
	_apply_role_visuals()
	visual.scale = Vector3.ZERO
	create_tween().set_trans(Tween.TRANS_BACK).tween_property(visual, "scale", _role_scale(), 0.3)
	display_data_changed.emit(self)


func _physics_process(delta: float) -> void:
	if not _active or target == null or not is_instance_valid(target):
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_state_time = maxf(_state_time - delta, 0.0)
	var offset := target.global_position - global_position
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	var distance := flat_offset.length()
	_update_state(distance, flat_offset)
	match ai_state:
		STATE_IDLE:
			_slow_horizontal(delta)
		STATE_CHASE:
			_chase(flat_offset, delta)
		STATE_ATTACK_WINDUP:
			_windup(flat_offset, delta)
		STATE_ATTACK:
			_perform_attack(distance, flat_offset)
		STATE_CHARGE_WINDUP:
			_charge_prepare(flat_offset, delta)
		STATE_CHARGE:
			_charge_move(distance)
		STATE_RECOVER:
			_slow_horizontal(delta)
		STATE_HURT:
			velocity.x = _hurt_direction.x * 1.6
			velocity.z = _hurt_direction.z * 1.6
	move_and_slide()
	_update_actual_health_clues(delta)


func take_damage(damage: int, hit_direction: Vector3) -> void:
	if not _active or profile == null:
		return
	profile.apply_actual_damage(damage)
	display_data_changed.emit(self)
	var ratio := float(profile.actual_health) / float(profile.actual_max_health)
	health_ratio_changed.emit(self, ratio)
	_hurt_direction = Vector3(hit_direction.x, 0.0, hit_direction.z).normalized()
	_flash_hit()
	if profile.actual_health <= 0:
		_die()
	else:
		_release_attack_slot()
		var resistance := 0.35 if monster_role == &"BRUTE" else 1.0
		_set_state(STATE_HURT, hurt_duration * resistance)


func set_ai_active(enabled: bool) -> void:
	_active = enabled and ai_state != STATE_DEAD
	if not _active:
		_release_attack_slot()
		velocity = Vector3.ZERO


func get_display_data() -> Dictionary:
	return profile.get_display_data() if profile != null else {}


func get_debug_data() -> Dictionary:
	var data: Dictionary = profile.get_debug_data() if profile != null else {}
	data["role"] = monster_role
	data["ai_state"] = ai_state
	data["distance"] = global_position.distance_to(target.global_position) if target != null and is_instance_valid(target) else -1.0
	data["cooldown"] = _cooldown_left
	data["speed"] = move_speed
	return data


func _apply_role_stats(role: StringName) -> void:
	match role:
		&"BRUTE", &"BOSS":
			actual_max_health = _random.randi_range(320, 400) if role == &"BOSS" else _random.randi_range(180, 240)
			actual_attack_damage = _random.randi_range(38, 48) if role == &"BOSS" else _random.randi_range(32, 42)
			move_speed = _random.randf_range(2.5, 3.0)
			attack_windup = _random.randf_range(0.65, 0.85)
			attack_cooldown = _random.randf_range(1.4, 1.8)
			hurt_duration = 0.14
			actual_danger_level = 4
		&"RUSHER":
			actual_max_health = _random.randi_range(70, 95)
			actual_attack_damage = _random.randi_range(25, 34)
			move_speed = _random.randf_range(3.2, 3.7)
			charge_speed = _random.randf_range(7.0, 9.0)
			attack_cooldown = 1.35
			hurt_duration = 0.16
			actual_danger_level = 3
		_:
			actual_max_health = _random.randi_range(90, 115)
			actual_attack_damage = _random.randi_range(20, 24)
			move_speed = _random.randf_range(4.0, 4.6)
			attack_cooldown = _random.randf_range(0.85, 1.0)
			attack_windup = _random.randf_range(0.32, 0.5)
			hurt_duration = _random.randf_range(0.12, 0.2)
			actual_danger_level = 2


func _update_state(distance: float, flat_offset: Vector3) -> void:
	if ai_state == STATE_DEAD:
		return
	if ai_state == STATE_HURT or ai_state == STATE_RECOVER:
		if _state_time <= 0.0:
			_set_state(STATE_CHASE)
		return
	if ai_state == STATE_ATTACK_WINDUP:
		if _state_time <= 0.0:
			_set_state(STATE_ATTACK)
		return
	if ai_state == STATE_CHARGE_WINDUP:
		if _state_time <= 0.0:
			_charge_direction = flat_offset.normalized()
			_set_state(STATE_CHARGE, 0.75)
		return
	if ai_state == STATE_CHARGE:
		if _state_time <= 0.0:
			_finish_charge()
		return
	if ai_state == STATE_ATTACK:
		return
	if distance <= attack_range and _cooldown_left <= 0.0:
		if _request_attack_slot(false):
			_set_state(STATE_ATTACK_WINDUP, attack_windup)
	elif monster_role == &"RUSHER" and distance <= 9.0 and distance >= 4.0 and _cooldown_left <= 0.0:
		if _request_attack_slot(true):
			_set_state(STATE_CHARGE_WINDUP, charge_windup)
	elif distance <= detection_range:
		_set_state(STATE_CHASE)
	else:
		_set_state(STATE_IDLE)


func _chase(flat_offset: Vector3, delta: float) -> void:
	if flat_offset.length_squared() < 0.01:
		return
	var direction := flat_offset.normalized()
	var side := Vector3(-direction.z, 0.0, direction.x)
	var side_sign := -1.0 if formation_index % 2 == 0 else 1.0
	direction = (direction + side * side_sign * 0.22 + _separation_vector() * 0.75).normalized()
	_face_target(flat_offset)
	var health_ratio := float(profile.actual_health) / float(profile.actual_max_health)
	var speed_factor := 0.7 if health_ratio <= 0.1 else 1.0
	velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_factor, 14.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_factor, 14.0 * delta)


func _separation_vector() -> Vector3:
	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("active_monsters"):
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.001 and distance < 1.35:
			separation += away.normalized() * (1.35 - distance)
	return separation


func _windup(flat_offset: Vector3, delta: float) -> void:
	_face_target(flat_offset)
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	var charge := 1.0 - _state_time / maxf(attack_windup, 0.01)
	var arm_angle := -1.65 if monster_role == &"BRUTE" or monster_role == &"BOSS" else -1.15
	left_arm.rotation.x = lerpf(0.0, arm_angle, charge)
	right_arm.rotation.x = left_arm.rotation.x
	_eye_material.emission_energy_multiplier = 1.5 + actual_attack_damage * 0.07


func _perform_attack(distance: float, flat_offset: Vector3) -> void:
	left_arm.rotation.x = 1.0
	right_arm.rotation.x = 1.0
	if distance <= attack_range + 0.15:
		attack_landed.emit(profile.actual_attack_damage, flat_offset.normalized(), 0.7 + profile.actual_attack_damage / 24.0)
	_cooldown_left = attack_cooldown
	_reset_attack_visuals()
	_release_attack_slot()
	_set_state(STATE_CHASE)


func _charge_prepare(flat_offset: Vector3, delta: float) -> void:
	_face_target(flat_offset)
	_slow_horizontal(delta)
	visual.rotation.x = lerpf(0.0, -0.32, 1.0 - _state_time / charge_windup)
	_eye_material.emission_energy_multiplier = 3.0


func _charge_move(distance: float) -> void:
	velocity.x = _charge_direction.x * charge_speed
	velocity.z = _charge_direction.z * charge_speed
	if distance <= attack_range:
		attack_landed.emit(profile.actual_attack_damage, _charge_direction, 1.55)
		_finish_charge()


func _finish_charge() -> void:
	velocity.x *= 0.2
	velocity.z *= 0.2
	_cooldown_left = attack_cooldown
	visual.rotation.x = 0.0
	_reset_attack_visuals()
	_release_attack_slot()
	_set_state(STATE_RECOVER, charge_recovery)


func _request_attack_slot(is_charge: bool) -> bool:
	if _has_attack_slot:
		return true
	if _coordinator == null or not _coordinator.has_method("request_attack_slot"):
		_has_attack_slot = true
		return true
	_has_attack_slot = bool(_coordinator.call("request_attack_slot", self, is_charge))
	return _has_attack_slot


func _release_attack_slot() -> void:
	if not _has_attack_slot:
		return
	_has_attack_slot = false
	if _coordinator != null and _coordinator.has_method("release_attack_slot"):
		_coordinator.call("release_attack_slot", self)


func _face_target(flat_offset: Vector3) -> void:
	if flat_offset.length_squared() > 0.001:
		look_at(global_position + flat_offset, Vector3.UP)


func _slow_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)


func _apply_role_visuals() -> void:
	match monster_role:
		&"BRUTE", &"BOSS":
			_base_body_color = Color(0.28, 0.19, 0.12)
		&"RUSHER":
			_base_body_color = Color(0.2, 0.08, 0.1)
		_:
			_base_body_color = Color(0.16, 0.24, 0.25)
	_body_material.albedo_color = _base_body_color
	_eye_material.albedo_color = Color(0.75, 0.02, 0.01)
	_eye_material.emission_energy_multiplier = 0.9 + actual_danger_level * 0.4


func _role_scale() -> Vector3:
	if monster_role == &"BOSS":
		return Vector3.ONE * 1.48
	if monster_role == &"BRUTE":
		return Vector3.ONE * _random.randf_range(1.25, 1.38)
	if monster_role == &"RUSHER":
		return Vector3(0.9, 1.04, 0.9)
	return Vector3.ONE


func _actual_role_name() -> String:
	match monster_role:
		&"BRUTE": return "중갑 파괴자"
		&"BOSS": return "심층 중갑 군주"
		&"RUSHER": return "돌진 사냥꾼"
		_: return "던전 추적자"


func _flash_hit() -> void:
	_body_material.emission_enabled = true
	_body_material.emission = Color(1.0, 0.65, 0.55)
	_body_material.emission_energy_multiplier = 2.5
	var tween := create_tween()
	tween.tween_interval(0.07)
	tween.tween_callback(func() -> void: _body_material.emission_enabled = false)


func _update_actual_health_clues(delta: float) -> void:
	if profile == null:
		return
	var ratio := float(profile.actual_health) / float(profile.actual_max_health)
	_body_material.albedo_color = _base_body_color.darkened(0.12 if ratio <= 0.7 else 0.0)
	if ratio <= 0.4 and not _body_material.emission_enabled:
		_body_material.emission_enabled = true
		_body_material.emission = Color(0.35, 0.0, 0.0)
		_body_material.emission_energy_multiplier = 0.4 + sin(Time.get_ticks_msec() * 0.012) * 0.12
	if ratio <= 0.2:
		visual.rotation.z = sin(Time.get_ticks_msec() * 0.018) * 0.045
		visual.position.y = sin(Time.get_ticks_msec() * 0.011) * 0.035
	else:
		visual.rotation.z = move_toward(visual.rotation.z, 0.0, delta)


func _reset_attack_visuals() -> void:
	left_arm.rotation.x = 0.0
	right_arm.rotation.x = 0.0
	_eye_material.emission_energy_multiplier = 0.9 + actual_danger_level * 0.4


func _set_state(next_state: StringName, duration := 0.0) -> void:
	ai_state = next_state
	_state_time = duration


func _die() -> void:
	_active = false
	ai_state = STATE_DEAD
	_release_attack_slot()
	velocity = Vector3.ZERO
	remove_from_group("active_monsters")
	collision_layer = 0
	collision_mask = 0
	collision_shape.set_deferred("disabled", true)
	monster_died.emit(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation:z", deg_to_rad(82.0), 0.5)
	tween.tween_property(visual, "scale", Vector3(1.05, 0.12, 1.05), 0.75)
	tween.tween_property(visual, "position:y", -0.7, 0.75)
	await tween.finished
	await get_tree().create_timer(0.2).timeout
	queue_free()
