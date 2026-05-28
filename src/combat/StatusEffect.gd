class_name StatusEffect
## Helpers for creating status effect dictionaries

static func burning(duration: int = 3, dpt: int = 5) -> Dictionary:
	return {"id": "burning", "name": "Burning", "duration": duration, "damage_per_turn": dpt, "armor_mod": 0}

static func frozen(duration: int = 2) -> Dictionary:
	return {"id": "frozen", "name": "Frozen", "duration": duration, "damage_per_turn": 0, "armor_mod": -2, "skips_turn": true}

static func vanished(multiplier: float = 3.0) -> Dictionary:
	return {"id": "vanished", "name": "Vanished", "duration": 1, "damage_per_turn": 0, "armor_mod": 0, "damage_multiplier": multiplier}

static func fortified(duration: int = 2, armor_bonus: int = 3) -> Dictionary:
	return {"id": "fortified", "name": "Fortified", "duration": duration, "damage_per_turn": 0, "armor_mod": armor_bonus}

static func poisoned(duration: int = 4, dpt: int = 3) -> Dictionary:
	return {"id": "poisoned", "name": "Poisoned", "duration": duration, "damage_per_turn": dpt, "armor_mod": 0}

static func rallied(duration: int = 3, attack_mod: int = 8) -> Dictionary:
	## War Cry buff: boosts outgoing damage via attack_mod field for N turns.
	return {"id": "rallied", "name": "Rallied", "duration": duration, "damage_per_turn": 0, "armor_mod": 0, "attack_mod": attack_mod}
