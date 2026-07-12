extends SceneTree

const RunManagerScript := preload("res://scripts/core/run_manager.gd")
const LieManagerScript := preload("res://scripts/core/lie_manager.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var lie_manager: Node = LieManagerScript.new()
	lie_manager.name = "LieManager"
	root.add_child(lie_manager)
	var manager: Node = RunManagerScript.new()
	root.add_child(manager)
	manager.debug_fixed_seed = 424242
	manager.health_lie_probability = 1.0
	manager.start_new_run()
	for room_number in range(1, 6):
		assert(manager.begin_transition())
		var record: Dictionary = manager.resolve_choice(_door_state(true, room_number))
		assert(record["room_number"] == room_number)
		assert(record.has_all(["chosen_door_id", "actual_safe", "displayed_safe", "door_was_lying", "damage_taken", "actual_health_after", "displayed_health_after"]))
		if room_number < 5:
			assert(not manager.is_victory)
			manager.continue_after_transition()
	assert(manager.is_victory)
	assert(manager.choice_history.size() == 5)

	manager.minimum_trap_damage = 35
	manager.maximum_trap_damage = 35
	manager.start_new_run()
	for room_number in range(1, 4):
		assert(manager.begin_transition())
		manager.resolve_choice(_door_state(false, room_number))
		assert(manager.displayed_health >= 0 and manager.displayed_health <= manager.starting_health)
		if manager.actual_health > 0:
			assert(not manager.is_dead)
			manager.continue_after_transition()
	assert(manager.actual_health == 0)
	assert(manager.is_dead)
	assert(manager.choice_history.size() == 3)
	print("RUN_MANAGER_TEST_OK")
	quit(0)


func _door_state(actual_safe: bool, index: int) -> Dictionary:
	return {
		"id": "테스트 문 %d" % index,
		"actual_safe": actual_safe,
		"displayed_safe": not actual_safe,
		"is_lying": true,
	}
