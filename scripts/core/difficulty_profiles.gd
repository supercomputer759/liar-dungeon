extends RefCounted

const PROFILES := {
	"EASY": {"health": 0.78, "damage": 0.72, "speed": 0.9, "count": 0.7, "max_alive": 4, "attack_slots": 1},
	"NORMAL": {"health": 1.0, "damage": 1.0, "speed": 1.0, "count": 1.0, "max_alive": 6, "attack_slots": 2},
	"HARD": {"health": 1.18, "damage": 1.16, "speed": 1.08, "count": 1.2, "max_alive": 7, "attack_slots": 3},
	"CHAOS": {"health": 1.3, "damage": 1.28, "speed": 1.18, "count": 1.6, "max_alive": 9, "attack_slots": 4},
}


static func get_profile(profile_name: StringName) -> Dictionary:
	var key := String(profile_name).to_upper()
	return PROFILES.get(key, PROFILES["NORMAL"]).duplicate(true)
