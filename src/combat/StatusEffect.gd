class_name StatusEffect
## Helpers for creating status effect dictionaries

static func burning(duration: int = 3, dpt: int = 5) -> Dictionary:
	return {"id": "burning", "name": "Burning", "duration": duration, "damage_per_turn": dpt, "armor_mod": 0}

static func frozen(duration: int = 2) -> Dictionary:
	return {"id": "frozen", "name": "Frozen", "duration": duration, "damage_per_turn": 0, "armor_mod": -2, "skips_turn": true}

static func vanished(multiplier: float = 3.0) -> Dictionary:
	return {"id": "vanished", "name": "Vanished", "duration": 3, "damage_per_turn": 0, "armor_mod": 0, "damage_multiplier": multiplier}

static func fortified(duration: int = 2, armor_bonus: int = 3) -> Dictionary:
	return {"id": "fortified", "name": "Fortified", "duration": duration, "damage_per_turn": 0, "armor_mod": armor_bonus}

static func poisoned(duration: int = 4, dpt: int = 3) -> Dictionary:
	return {"id": "poisoned", "name": "Poisoned", "duration": duration, "damage_per_turn": dpt, "armor_mod": 0}

## Run 21: Arcanist barrier. Holds a damage pool; Combatant.take_damage() drains
## it BEFORE armor is applied (and before HP). When the pool hits 0 the effect
## expires immediately. Long nominal duration is intentional — it only ends
## when consumed or, defensively, after `duration` of the caster's turns.
static func mana_shield(absorb: int = 40, duration: int = 10) -> Dictionary:
	return {"id": "mana_shield", "name": "Mana Shield", "duration": duration,
		"damage_per_turn": 0, "armor_mod": 0, "absorb_remaining": absorb,
		"absorb_max": absorb}
