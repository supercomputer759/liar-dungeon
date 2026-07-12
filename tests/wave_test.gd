extends SceneTree

const EncounterScript := preload("res://scripts/rooms/encounter_manager.gd")

var _normal := {"health": 1.0, "damage": 1.0, "speed": 1.0, "count": 1.0, "max_alive": 6, "attack_slots": 2}
var _world: Node3D
var _player: CharacterBody3D
var _encounter: Node3D


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_player = CharacterBody3D.new()
	_player.position = Vector3(0, 0, 4.5)
	_world.add_child(_player)
	_encounter = EncounterScript.new() as Node3D
	_world.add_child(_encounter)
	_encounter.setup(_player, _normal, &"NORMAL")

	assert(_encounter.start_room_encounter(3, 303))
	_spawn_current_wave(3)
	assert(_role_count(&"HUNTER") == 2)
	assert(_role_count(&"RUSHER") == 1)
	_kill_all()
	_start_following_wave(2)
	assert(_role_count(&"HUNTER") == 2)
	assert(_encounter.get_wave_status()["current"] == 2)

	_encounter.clear_encounter()
	assert(_encounter.start_room_encounter(4, 404))
	_spawn_current_wave(4)
	assert(_role_count(&"HUNTER") == 3)
	assert(_role_count(&"RUSHER") == 1)
	_kill_all()
	_start_following_wave(3)
	assert(_role_count(&"HUNTER") == 2)
	assert(_role_count(&"BRUTE") == 1)
	assert(_encounter.get_living_count() <= 6)

	_encounter.clear_encounter()
	assert(_encounter.start_room_encounter(5, 505))
	_spawn_current_wave(4)
	assert(_role_count(&"HUNTER") == 2)
	assert(_role_count(&"RUSHER") == 2)
	_kill_all()
	_start_following_wave(3)
	assert(_role_count(&"BOSS") == 1)
	assert(_role_count(&"HUNTER") == 2)
	var boss: Node = _find_role(&"BOSS")
	var reinforcement_damage: int = ceili(boss.profile.actual_max_health * 0.46)
	boss.take_damage(reinforcement_damage, Vector3.FORWARD)
	assert(_encounter.get_pending_count() == 2)
	_encounter._process(1.0)
	_encounter._process(1.0)
	assert(_encounter.get_living_count() == 5)
	assert(_encounter.get_living_count() <= 6)

	var rushers: Array[Node] = []
	for monster in _encounter._living_monsters:
		if monster.monster_role == &"HUNTER":
			rushers.append(monster)
	assert(_encounter.request_attack_slot(rushers[0], true))
	assert(not _encounter.request_attack_slot(rushers[1], true))
	print("WAVE_TEST_OK")
	quit(0)


func _spawn_current_wave(count: int) -> void:
	_encounter._process(2.0)
	for _index in count:
		_encounter._process(1.0)


func _start_following_wave(count: int) -> void:
	_encounter._process(0.0)
	_encounter._process(2.0)
	for _index in count:
		_encounter._process(1.0)


func _kill_all() -> void:
	var snapshot: Array = _encounter._living_monsters.duplicate()
	for monster in snapshot:
		monster.take_damage(9999, Vector3.FORWARD)
	assert(_encounter.get_living_count() == 0)


func _role_count(role: StringName) -> int:
	var count := 0
	for monster in _encounter._living_monsters:
		if monster.monster_role == role:
			count += 1
	return count


func _find_role(role: StringName) -> Node:
	for monster in _encounter._living_monsters:
		if monster.monster_role == role:
			return monster
	return null
