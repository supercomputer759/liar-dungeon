extends CanvasLayer

signal restart_requested

@onready var background: ColorRect = $Background
@onready var title_label: Label = $Background/Center/Panel/Margin/Content/Title
@onready var summary_label: Label = $Background/Center/Panel/Margin/Content/Summary
@onready var history_label: Label = $Background/Center/Panel/Margin/Content/History
@onready var restart_button: Button = $Background/Center/Panel/Margin/Content/RestartButton


func _ready() -> void:
	background.visible = false
	restart_button.pressed.connect(_request_restart)


func _unhandled_input(event: InputEvent) -> void:
	if background.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_request_restart()
		get_viewport().set_input_as_handled()


func show_result(victory: bool, summary: Dictionary) -> void:
	background.visible = true
	title_label.text = "던전을 탈출했습니다." if victory else "당신은 죽었습니다."
	title_label.modulate = Color(0.62, 1.0, 0.75) if victory else Color(1.0, 0.35, 0.3)
	if victory:
		summary_label.text = "통과한 방: %d\n실제 남은 체력: %d\n마지막 표시 체력: %d" % [summary["cleared_rooms"], summary["actual_health"], summary["displayed_health"]]
	else:
		summary_label.text = "도달한 방: %d\n마지막 실제 체력: %d\n마지막 표시 체력: %d" % [summary["reached_room"], summary["actual_health"], summary["displayed_health"]]
	var lines: PackedStringArray = ["선택 기록"]
	for record in summary["history"]:
		lines.append("ROOM %d · %s · %s · 피해 %d · HP %d (표시 %d)" % [
			record["room_number"], record["chosen_door_id"], "안전" if record["actual_safe"] else "함정",
			record["damage_taken"], record["actual_health_after"], record["displayed_health_after"]
		])
	history_label.text = "\n".join(lines)
	restart_button.grab_focus()


func hide_result() -> void:
	background.visible = false


func _request_restart() -> void:
	restart_requested.emit()
