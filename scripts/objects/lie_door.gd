extends StaticBody3D

signal interacted(door_state: Dictionary)

@export var door_id: StringName = &"door"
@export_range(0.0, 1.0, 0.01) var clue_strength := 0.28
@export var base_color := Color(0.65, 0.08, 0.08)

@onready var door_mesh: MeshInstance3D = $DoorMesh
@onready var sign_label: Label3D = $SignLabel
@onready var stain: MeshInstance3D = $DangerStain
@onready var clue_light: OmniLight3D = $ClueLight

var actual_safe := false
var displayed_safe := false
var is_lying := false
var _flicker_time := 0.0
var _interaction_enabled := true
var _closed_rotation_y := 0.0


func _ready() -> void:
	_apply_base_material()
	_closed_rotation_y = rotation.y


func configure(state: Dictionary) -> void:
	_interaction_enabled = true
	rotation.y = _closed_rotation_y
	actual_safe = bool(state["actual_value"])
	displayed_safe = bool(state["displayed_value"])
	is_lying = bool(state["is_lying"])
	sign_label.text = "이 문은 안전합니다." if displayed_safe else "이 문은 위험합니다."
	stain.visible = not actual_safe
	clue_light.visible = not actual_safe
	if not actual_safe:
		var stain_material := stain.get_active_material(0) as StandardMaterial3D
		if stain_material != null:
			stain_material.albedo_color.a = clue_strength
		clue_light.light_energy = clue_strength * 0.65


func interact() -> void:
	if not _interaction_enabled:
		return
	_interaction_enabled = false
	interacted.emit(get_debug_state())


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled


func play_open_animation() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", _closed_rotation_y + deg_to_rad(82.0), 0.45)
	await tween.finished


func get_debug_state() -> Dictionary:
	return {
		"id": String(door_id),
		"actual_safe": actual_safe,
		"displayed_safe": displayed_safe,
		"is_lying": is_lying,
	}


func _process(delta: float) -> void:
	if actual_safe or not clue_light.visible:
		return
	_flicker_time += delta
	clue_light.light_energy = clue_strength * (0.54 + sin(_flicker_time * 8.0) * 0.06)


func _apply_base_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.metallic = 0.18
	material.roughness = 0.58
	door_mesh.material_override = material
