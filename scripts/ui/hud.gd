extends CanvasLayer

const WAVE_WARNING_STREAM := preload("res://assets/audio/ui/warning.ogg")

@onready var interaction_label: Label = $InteractionLabel
@onready var health_label: Label = $HealthLabel
@onready var room_label: Label = $RoomLabel
@onready var message_label: Label = $MessageLabel
@onready var crosshair: Label = $Crosshair
@onready var hit_marker: Label = $HitMarker
@onready var monster_panel: PanelContainer = $MonsterPanel
@onready var monster_label: Label = $MonsterPanel/Margin/MonsterInfo
@onready var remaining_label: Label = $RemainingMonsters
@onready var wave_label: Label = $WaveLabel
@onready var behind_warning: Label = $BehindWarning
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel
@onready var vignette: ColorRect = $Effects/Vignette
@onready var flash: ColorRect = $Effects/Flash
@onready var fade: ColorRect = $Effects/Fade
@onready var message_timer: Timer = $MessageTimer

var _actual_health := 100
var _maximum_health := 100
var _effect_time := 0.0
var _warning_audio: AudioStreamPlayer


func _ready() -> void:
	interaction_label.visible = false
	debug_panel.visible = false
	message_label.visible = false
	hit_marker.visible = false
	monster_panel.visible = false
	wave_label.visible = false
	behind_warning.visible = false
	flash.modulate.a = 0.0
	fade.modulate.a = 0.0
	_warning_audio = AudioStreamPlayer.new()
	_warning_audio.stream = WAVE_WARNING_STREAM
	_warning_audio.volume_db = -5.0
	add_child(_warning_audio)
	message_timer.timeout.connect(_on_message_timer_timeout)


func _process(delta: float) -> void:
	_effect_time += delta
	var ratio := float(_actual_health) / float(maxi(_maximum_health, 1))
	var base_strength := 0.0
	if ratio <= 0.2:
		base_strength = 0.52 + sin(_effect_time * 2.2) * 0.07
	elif ratio <= 0.35:
		base_strength = 0.38 + maxf(sin(_effect_time * 5.0), 0.0) * 0.09
	elif ratio <= 0.6:
		base_strength = 0.2
	vignette.modulate.a = base_strength
	if ratio <= 0.2:
		var breath := sin(_effect_time * 1.8) * 2.0
		vignette.position = Vector2(breath, -breath * 0.5)
	else:
		vignette.position = Vector2.ZERO


func set_interaction_available(available: bool) -> void:
	interaction_label.visible = available


func set_health(displayed: int, maximum: int, actual: int) -> void:
	health_label.text = "HP  %d / %d" % [displayed, maximum]
	_actual_health = actual
	_maximum_health = maximum


func set_room(current: int, total: int) -> void:
	room_label.text = "ROOM  %d / %d" % [current, total]


func set_remaining_monsters(remaining: int) -> void:
	remaining_label.text = "남은 몬스터  %d" % remaining
	remaining_label.visible = remaining > 0


func set_wave_status(current: int, total: int, pending: int) -> void:
	wave_label.visible = total > 0
	wave_label.text = "WAVE %d / %d   ·   생성 대기 %d" % [current, total, pending]


func set_behind_warning(visible_warning: bool) -> void:
	behind_warning.visible = visible_warning


func set_monster_info(data: Dictionary) -> void:
	monster_panel.visible = not data.is_empty()
	if data.is_empty():
		return
	monster_label.text = "%s\nHP %d / %d   ·   공격력 %d   ·   위험도: %s" % [
		data["name"], data["health"], data["max_health"], data["attack_damage"], data["danger"]
	]


func show_attack_feedback() -> void:
	crosshair.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(crosshair, "scale", Vector2(1.45, 1.45), 0.06)
	tween.tween_property(crosshair, "scale", Vector2.ONE, 0.12)


func set_attack_cooldown(on_cooldown: bool) -> void:
	crosshair.modulate = Color(0.55, 0.58, 0.62) if on_cooldown else Color.WHITE


func show_hit_confirm() -> void:
	hit_marker.visible = true
	hit_marker.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(hit_marker, "modulate:a", 0.0, 0.2)
	await tween.finished
	hit_marker.visible = false


func show_message(message: String) -> void:
	message_label.text = message
	message_label.visible = true
	message_timer.start()


func show_wave_warning(message: String) -> void:
	show_message(message)
	_warning_audio.play()
	flash.color = Color(0.9, 0.02, 0.01, 1.0)
	flash.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.24, 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.42)


func play_choice_flash(is_safe: bool) -> void:
	flash.color = Color(0.82, 1.0, 0.88, 1.0) if is_safe else Color(0.9, 0.04, 0.02, 1.0)
	flash.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.52 if not is_safe else 0.3, 0.08)
	tween.tween_property(flash, "modulate:a", 0.0, 0.38)
	await tween.finished


func play_damage_feedback(impact_strength: float) -> void:
	flash.color = Color(0.95, 0.015, 0.0, 1.0)
	flash.modulate.a = 0.62
	var shake := clampf(impact_strength * 3.0, 2.0, 6.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_property($Effects, "position", Vector2(shake, -shake), 0.05)
	tween.chain().tween_property($Effects, "position", Vector2(-shake * 0.5, shake * 0.5), 0.05)
	tween.chain().tween_property($Effects, "position", Vector2.ZERO, 0.08)


func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.3)
	await tween.finished


func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.35)
	await tween.finished


func toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible


func set_debug_data(data: Dictionary) -> void:
	var lines: PackedStringArray = [
		"[개발자 디버그]",
		"상태: %s | 방: %d / %d | 시드: %d" % [data["state"], data["room"], data["total_rooms"], data["seed"]],
		"실제 HP: %d | 표시 HP: %d | 체력 거짓말: %s" % [data["actual_health"], data["displayed_health"], _bool_text(data["health_is_lying"])],
	]
	for door_state in data["doors"]:
		lines.append("%s | 실제 안전: %s | 표시 안전: %s | 거짓말: %s" % [
			door_state["id"], _bool_text(door_state["actual_safe"]), _bool_text(door_state["displayed_safe"]), _bool_text(door_state["is_lying"])
		])
	var history: Array = data["history"]
	lines.append("최근 선택:")
	if history.is_empty():
		lines.append("  아직 선택하지 않음")
	else:
		for index in range(maxi(0, history.size() - 3), history.size()):
			var record: Dictionary = history[index]
			lines.append("  R%d %s | %s | 피해 %d | 실제/표시 %d/%d" % [
				record["room_number"], record["chosen_door_id"], "안전" if record["actual_safe"] else "함정",
				record["damage_taken"], record["actual_health_after"], record["displayed_health_after"]
			])
	lines.append("전투 | 생존 몬스터: %d | 무기 쿨다운: %.2f" % [data["remaining_monsters"], data["weapon_cooldown"]])
	var monster: Dictionary = data["monster"]
	if monster.is_empty():
		lines.append("몬스터: 없음")
	else:
		lines.append("몬스터 상태: %s | 거리: %.2fm | 공격 쿨다운: %.2f" % [monster["ai_state"], monster["distance"], monster["cooldown"]])
		lines.append("이름 실제/표시: %s / %s | 거짓말: %s" % [monster["actual_name"], monster["displayed_name"], _bool_text(monster["name_lie"])])
		lines.append("HP 실제: %d/%d | 표시: %d/%d | 거짓말: %s" % [monster["actual_health"], monster["actual_max_health"], monster["displayed_health"], monster["displayed_max_health"], _bool_text(monster["health_lie"])])
		lines.append("공격 실제/표시: %d/%d | 거짓말: %s" % [monster["actual_attack"], monster["displayed_attack"], _bool_text(monster["attack_lie"])])
		lines.append("위험 실제/표시: %s/%s | 거짓말: %s" % [monster["actual_danger"], monster["displayed_danger"], _bool_text(monster["danger_lie"])])
	var wave: Dictionary = data["wave"]
	lines.append("웨이브: %d/%d | 생성 대기: %d | 공격 토큰: %d/%d" % [wave["current"], wave["total"], wave["pending"], wave["attack_used"], wave["attack_max"]])
	lines.append("난이도: %s | HP x%.2f | 공격 x%.2f | 속도 x%.2f" % [wave["difficulty"], wave["health_multiplier"], wave["damage_multiplier"], wave["speed_multiplier"]])
	var all_monsters: Array = data["monsters"]
	for index in mini(all_monsters.size(), 6):
		var entry: Dictionary = all_monsters[index]
		lines.append("  #%d %s | %s | 실제 HP %d/%d | 공격 %d | 속도 %.2f" % [index + 1, entry["role"], entry["ai_state"], entry["actual_health"], entry["actual_max_health"], entry["actual_attack"], entry["speed"]])
	debug_label.text = "\n".join(lines)


func _bool_text(value: bool) -> String:
	return "예" if value else "아니오"


func _on_message_timer_timeout() -> void:
	message_label.visible = false
