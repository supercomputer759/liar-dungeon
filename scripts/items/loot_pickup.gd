class_name LootPickup
extends StaticBody3D

signal pickup_requested(pickup: LootPickup)
var item: RefCounted
@onready var visual: MeshInstance3D = $Visual
@onready var label: Label3D = $Label3D

func setup(instance: RefCounted) -> void:
	item = instance
	label.text = item.displayed_name
	var material := StandardMaterial3D.new()
	material.albedo_color = item.definition.world_color
	material.emission_enabled = true
	material.emission = item.definition.world_color
	material.emission_energy_multiplier = 0.35
	visual.material_override = material
	if item.definition.world_shape == &"SPHERE": visual.mesh = SphereMesh.new()
	elif item.definition.world_shape == &"CYLINDER": visual.mesh = CylinderMesh.new()

func interact() -> void:
	pickup_requested.emit(self)

func _process(delta: float) -> void:
	visual.rotate_y(delta * 1.4)
	visual.position.y = 0.22 + sin(Time.get_ticks_msec() * 0.004) * 0.08
