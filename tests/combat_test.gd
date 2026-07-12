extends SceneTree

const MonsterScene := preload("res://scenes/enemies/dungeon_stalker.tscn")
const EncounterScript := preload("res://scripts/rooms/encounter_manager.gd")
const WeaponScene := preload("res://scenes/weapons/basic_melee_weapon.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var normal := {"health": 1.0, "damage": 1.0, "speed": 1.0, "count": 1.0, "max_alive": 6, "attack_slots": 2}
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	world.add_child(player)
	var monster := MonsterScene.instantiate() as CharacterBody3D
	world.add_child(monster)
	monster.setup(player, 12345, &"HUNTER", normal, null)
	assert(monster.profile.actual_health >= 90 and monster.profile.actual_health <= 115)
	var hunter_start_health: int = monster.profile.actual_health
	var initial_displayed: int = monster.profile.displayed_health
	monster.take_damage(25, Vector3.FORWARD)
	assert(monster.profile.actual_health == hunter_start_health - 25)
	assert(monster.profile.displayed_health >= 0)
	assert(monster.profile.displayed_health <= monster.profile.displayed_max_health)
	assert(monster.profile.displayed_health != initial_displayed or not monster.profile.health_is_lying)
	monster.take_damage(25, Vector3.FORWARD)
	assert(monster.profile.actual_health == hunter_start_health - 50)
	var died_count: Array[int] = [0]
	monster.monster_died.connect(func(_dead_monster: Node) -> void: died_count[0] += 1)
	monster.take_damage(999, Vector3.FORWARD)
	assert(monster.profile.actual_health == 0)
	assert(monster.ai_state == monster.STATE_DEAD)
	assert(died_count[0] == 1)
	monster.take_damage(25, Vector3.FORWARD)
	assert(died_count[0] == 1)

	var boss := MonsterScene.instantiate() as CharacterBody3D
	world.add_child(boss)
	boss.setup(player, 54321, &"BOSS", normal, null)
	assert(boss.profile.actual_max_health >= 320 and boss.profile.actual_max_health <= 400)
	assert(boss.profile.actual_attack_damage >= 38 and boss.profile.actual_attack_damage <= 48)
	assert(boss.profile.displayed_max_health >= 1)
	assert(boss.profile.displayed_health >= 0 and boss.profile.displayed_health <= boss.profile.displayed_max_health)

	var camera := Camera3D.new()
	camera.position = Vector3(4.0, 1.5, 0.0)
	world.add_child(camera)
	var weapon := WeaponScene.instantiate() as Node3D
	camera.add_child(weapon)
	var ray_target := MonsterScene.instantiate() as CharacterBody3D
	ray_target.position = Vector3(4.0, 0.0, -2.0)
	world.add_child(ray_target)
	ray_target.setup(player, 777, &"RUSHER", normal, null)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await physics_frame
	await physics_frame
	assert(weapon.try_attack())
	var ray_health_after_hit: int = ray_target.profile.actual_max_health - 22
	assert(ray_target.profile.actual_health == ray_health_after_hit)
	assert(not weapon.try_attack())
	assert(ray_target.profile.actual_health == ray_health_after_hit)
	weapon._cooldown_left = 0.0
	ray_target.position.z = -5.0
	await physics_frame
	assert(weapon.try_attack())
	assert(ray_target.profile.actual_health == ray_health_after_hit)

	var encounter := EncounterScript.new() as Node3D
	world.add_child(encounter)
	encounter.setup(player, normal, &"NORMAL")
	assert(not encounter.start_room_encounter(1, 100))
	assert(encounter.get_living_count() == 0)
	assert(encounter.start_room_encounter(2, 100))
	encounter._process(2.0)
	for _step in 3:
		encounter._process(1.0)
	assert(encounter.get_living_count() == 3)
	assert(encounter.get_pending_count() == 0)
	var spawned_positions: Array[Vector3] = []
	for spawned in encounter._living_monsters:
		spawned_positions.append(spawned.position)
	assert(spawned_positions[0] != spawned_positions[1])
	assert(spawned_positions[1] != spawned_positions[2])
	var holders: Array[Node] = encounter._living_monsters
	assert(encounter.request_attack_slot(holders[0], false))
	assert(encounter.request_attack_slot(holders[1], false))
	assert(not encounter.request_attack_slot(holders[2], false))
	encounter.release_attack_slot(holders[0])
	assert(encounter.request_attack_slot(holders[2], false))
	encounter.clear_encounter()
	assert(encounter.get_living_count() == 0)
	print("COMBAT_TEST_OK")
	quit(0)
