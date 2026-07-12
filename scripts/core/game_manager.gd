extends Node3D

const DifficultyProfiles := preload("res://scripts/core/difficulty_profiles.gd")

@export_range(0.1, 2.0, 0.05) var result_pause := 0.65
@export var player_hit_invulnerability := 0.25
@export_enum("EASY", "NORMAL", "HARD", "CHAOS") var difficulty_profile := "NORMAL"
@export_range(1, 100, 1) var player_actual_attack_damage := 22

@onready var run_manager: Node = $RunManager
@onready var encounter_manager: Node3D = $EncounterManager
@onready var player: CharacterBody3D = $Player
@onready var player_combat: Node = $Player/PlayerCombat
@onready var room: Node3D = $TestRoom
@onready var hud: CanvasLayer = $HUD
@onready var result_screen: CanvasLayer = $ResultScreen

var _focused_monster: Node
var _invulnerability_left := 0.0
var _resolving_door := false
var _debug_refresh_left := 0.0


func _ready() -> void:
	room.door_chosen.connect(_on_door_chosen)
	player.focus_changed.connect(hud.set_interaction_available)
	player_combat.monster_focused.connect(_on_monster_focused)
	player_combat.attack_started.connect(hud.show_attack_feedback)
	player_combat.attack_cooldown_changed.connect(hud.set_attack_cooldown)
	player_combat.hit_confirmed.connect(hud.show_hit_confirm)
	run_manager.room_changed.connect(hud.set_room)
	run_manager.health_changed.connect(_on_health_changed)
	run_manager.state_changed.connect(_on_state_changed)
	run_manager.choice_recorded.connect(_on_choice_recorded)
	run_manager.run_finished.connect(_on_run_finished)
	encounter_manager.setup(player, DifficultyProfiles.get_profile(difficulty_profile), difficulty_profile)
	player_combat.set_actual_attack_damage(player_actual_attack_damage)
	encounter_manager.encounter_started.connect(_on_encounter_started)
	encounter_manager.remaining_changed.connect(hud.set_remaining_monsters)
	encounter_manager.wave_changed.connect(hud.set_wave_status)
	encounter_manager.warning_requested.connect(hud.show_wave_warning)
	encounter_manager.encounter_completed.connect(_on_encounter_completed)
	encounter_manager.final_boss_defeated.connect(_on_final_boss_defeated)
	encounter_manager.player_hit_requested.connect(_on_player_hit_requested)
	result_screen.restart_requested.connect(_restart_run)
	run_manager.start_new_run()
	room.configure_room()
	player.teleport_to(room.get_spawn_transform())
	_setup_room_encounter()
	_refresh_debug()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_invulnerability_left = maxf(_invulnerability_left - delta, 0.0)
	_debug_refresh_left = maxf(_debug_refresh_left - delta, 0.0)
	_refresh_monster_ui()
	hud.set_behind_warning(encounter_manager.has_close_behind_threat(-player.global_basis.z))
	if _debug_refresh_left <= 0.0:
		_debug_refresh_left = 0.1
		_refresh_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_room"):
		_restart_run()
	elif event.is_action_pressed("toggle_debug"):
		hud.toggle_debug()
	elif event.is_action_pressed("debug_next_wave"):
		encounter_manager.skip_to_next_wave()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _on_door_chosen(door_state: Dictionary, selected_door: StaticBody3D) -> void:
	if encounter_manager.get_living_count() > 0 or not run_manager.begin_transition():
		return
	_set_player_control(false)
	room.set_doors_enabled(false)
	_refresh_debug()
	selected_door.play_open_animation()
	_resolving_door = true
	var record: Dictionary = run_manager.resolve_choice(door_state)
	_resolving_door = false
	if selected_door.has_method("play_choice_result_sound"):
		selected_door.call("play_choice_result_sound", bool(record["actual_safe"]))
	hud.show_message("안전한 길이었다." if record["actual_safe"] else "함정이었다. 체력이 감소했습니다.")
	await hud.play_choice_flash(bool(record["actual_safe"]))
	await get_tree().create_timer(result_pause).timeout
	await hud.fade_out()
	if run_manager.is_dead or run_manager.is_victory:
		_show_result()
		await hud.fade_in()
		return
	room.configure_room()
	player.teleport_to(room.get_spawn_transform())
	hud.show_message("다음 방으로 이동합니다.")
	run_manager.continue_after_transition()
	_set_player_control(true)
	_setup_room_encounter()
	_refresh_debug()
	await hud.fade_in()


func _setup_room_encounter() -> void:
	var has_encounter: bool = encounter_manager.start_room_encounter(run_manager.current_room, run_manager.current_seed)
	room.set_doors_enabled(not has_encounter and run_manager.current_room < 5)
	hud.set_remaining_monsters(encounter_manager.get_living_count())
	if has_encounter:
		hud.show_message("문이 잠겼다. 주변의 적을 처치해야 한다.")


func _on_encounter_started(_remaining: int) -> void:
	room.set_doors_enabled(false)
	_refresh_debug()


func _on_encounter_completed() -> void:
	room.set_doors_enabled(true)
	hud.show_message("적을 처치했다. 문 잠금이 풀렸다.")
	_refresh_debug()


func _on_final_boss_defeated() -> void:
	hud.show_message("마지막 추적자를 쓰러뜨렸다.")
	run_manager.complete_victory()


func _on_player_hit_requested(damage: int, direction: Vector3, impact_strength: float) -> void:
	if _invulnerability_left > 0.0 or run_manager.game_state != run_manager.STATE_PLAYING:
		return
	if run_manager.apply_combat_damage(damage):
		_invulnerability_left = player_hit_invulnerability
		player.apply_knockback(direction, impact_strength * 2.2)
		if player.has_method("play_hurt_sound"):
			player.call("play_hurt_sound")
		hud.play_damage_feedback(impact_strength)
		hud.show_message("몬스터에게 공격받았다.")
		_refresh_debug()


func _on_monster_focused(monster: Node) -> void:
	_focused_monster = monster
	_refresh_monster_ui()


func _refresh_monster_ui() -> void:
	if _focused_monster != null and is_instance_valid(_focused_monster):
		hud.set_monster_info(_focused_monster.get_display_data())
	else:
		hud.set_monster_info({})


func _on_health_changed(actual: int, displayed: int, maximum: int) -> void:
	hud.set_health(displayed, maximum, actual)
	_refresh_debug()


func _on_state_changed(_state: StringName) -> void:
	_refresh_debug()


func _on_choice_recorded(_record: Dictionary) -> void:
	_refresh_debug()


func _on_run_finished(_victory: bool, _summary: Dictionary) -> void:
	_set_player_control(false)
	room.set_doors_enabled(false)
	encounter_manager.stop_all()
	_refresh_debug()
	if not _resolving_door:
		_show_result()


func _show_result() -> void:
	result_screen.show_result(run_manager.is_victory, run_manager.get_summary())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_player_control(enabled: bool) -> void:
	player.set_movement_enabled(enabled)
	player_combat.set_combat_enabled(enabled)


func _refresh_debug() -> void:
	if not is_node_ready() or not room.is_node_ready():
		return
	var debug_monster: Node = encounter_manager.get_debug_monster(_focused_monster)
	var monster_data: Dictionary = debug_monster.get_debug_data() if debug_monster != null and is_instance_valid(debug_monster) else {}
	var wave_status: Dictionary = encounter_manager.get_wave_status()
	hud.set_debug_data({
		"state": run_manager.game_state, "room": run_manager.current_room, "total_rooms": run_manager.total_rooms,
		"seed": run_manager.current_seed, "actual_health": run_manager.actual_health,
		"displayed_health": run_manager.displayed_health, "health_is_lying": run_manager.is_health_display_lying(),
		"doors": room.get_debug_states(), "history": run_manager.choice_history,
		"monster": monster_data, "remaining_monsters": encounter_manager.get_living_count(),
		"weapon_cooldown": player_combat.get_cooldown_left(), "wave": wave_status,
		"monsters": encounter_manager.get_all_debug_monsters(),
	})


func _restart_run() -> void:
	get_tree().reload_current_scene()
