class_name StatusEffect
## Helpers for creating status effect dictionaries.
## All effects: {id, name, duration, damage_per_turn, armor_mod, ...optional flags}

static func burning(duration: int = 3, dpt: int = 5) -> Dictionary:
	return {
		"id": "burning", "name": "Burning",
		"duration": duration, "damage_per_turn": dpt, "armor_mod": 0,
	}

static func frozen(duration: int = 2) -> Dictionary:
	## skip_turn: true means the combatant's turn is skipped while this is active.
	return {
		"id": "frozen", "name": "Frozen",
		"duration": duration, "damage_per_turn": 0, "armor_mod": 0,
		"skip_turn": true,
	}

static func fortified(duration: int = 3, armor_bonus: int = 5) -> Dictionary:
	return {
		"id": "fortified", "name": "Fortified",
		"duration": duration, "damage_per_turn": 0, "armor_mod": armor_bonus,
	}

static func poisoned(duration: int = 4, dpt: int = 3) -> Dictionary:
	return {
		"id": "poisoned", "name": "Poisoned",
		"duration": duration, "damage_per_turn": dpt, "armor_mod": 0,
	}

static func vanished() -> Dictionary:
	## Grants 3× damage on next attack, consumed on first hit.
	return {
		"id": "vanished", "name": "Vanished",
		"duration": 10, "damage_per_turn": 0, "armor_mod": 0,
		"damage_multiplier": 3.0, "consume_on_hit": true,
	}
