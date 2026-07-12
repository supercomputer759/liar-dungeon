class_name LootManager
extends Node3D

const PickupScene := preload("res://scenes/items/loot_pickup.tscn")
const Instance := preload("res://scripts/items/item_instance.gd")
const Database := preload("res://scripts/items/item_database.gd")
const PICKUP_STREAM := preload("res://assets/audio/ui/click.ogg")
signal message_requested(message: String)
var inventory: Node
var run_manager: Node
var _random := RandomNumberGenerator.new()
var _room_has_heal := false
var _room_guaranteed := false
var _pickup_audio: AudioStreamPlayer

func _ready() -> void:
	_pickup_audio = AudioStreamPlayer.new()
	_pickup_audio.stream = PICKUP_STREAM
	_pickup_audio.volume_db = -8.0
	add_child(_pickup_audio)

func setup(next_inventory: Node, next_run_manager: Node, seed_value: int) -> void:
	inventory = next_inventory
	run_manager = next_run_manager
	_random.seed = seed_value

func clear_room() -> void:
	for child in get_children(): child.queue_free()
	_room_has_heal = false
	_room_guaranteed = false

func on_monster_died(monster: Node) -> void:
	var chance := {&"HUNTER": 0.18, &"RUSHER": 0.30, &"BRUTE": 0.65, &"BOSS": 1.0}.get(monster.monster_role, 0.18)
	if _random.randf() < chance:
		spawn_item(monster.global_position, false)
	if monster.monster_role == &"BOSS": spawn_item(monster.global_position + Vector3(0.7, 0.0, 0.3), false)

func ensure_mercy_loot() -> void:
	if run_manager.actual_health <= roundi(run_manager.starting_health * 0.3) and not _room_has_heal and not _room_guaranteed:
		_room_guaranteed = true
		spawn_item(Vector3(0.0, 0.1, 0.0), true)

func spawn_item(position: Vector3, force_bandage: bool) -> void:
	var item_id: StringName = &"BANDAGE" if force_bandage else Database.get_random_item_id(_random, run_manager.actual_health <= roundi(run_manager.starting_health * 0.5))
	var pickup := PickupScene.instantiate() as StaticBody3D
	add_child(pickup)
	pickup.global_position = position + Vector3(0.0, 0.35, 0.0)
	pickup.setup(Instance.new(item_id, _random))
	pickup.pickup_requested.connect(_on_pickup_requested)
	if item_id == &"BANDAGE" or item_id == &"POTION": _room_has_heal = true

func _on_pickup_requested(pickup: StaticBody3D) -> void:
	if inventory.add_item(pickup.item):
		_pickup_audio.play()
		message_requested.emit("%s 획득" % pickup.item.displayed_name)
		pickup.queue_free()
	else:
		message_requested.emit("더 이상 아이템을 들 수 없습니다.")
