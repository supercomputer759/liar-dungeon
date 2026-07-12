extends RefCounted

const PROFILES := {
	"EASY": {"health": 0.72, "damage": 0.55, "speed": 0.88, "count": 0.65, "max_alive": 3, "attack_slots": 1},
	"NORMAL": {"health": 0.90, "damage": 0.72, "speed": 0.95, "count": 0.85, "max_alive": 5, "attack_slots": 2},
	"HARD": {"health": 1.05, "damage": 1.0, "speed": 1.05, "count": 1.1, "max_alive": 7, "attack_slots": 3},
	"CHAOS": {"health": 1.3, "damage": 1.28, "speed": 1.18, "count": 1.6, "max_alive": 9, "attack_slots": 4},
}


static func get_profile(profile_name: StringName) -> Dictionary:
	var key := String(profile_name).to_upper()
	return PROFILES.get(key, PROFILES["NORMAL"]).duplicate(true)
