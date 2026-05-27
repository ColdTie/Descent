class_name Classes
## Static data for player classes.

const DATA: Dictionary = {
	"brawler": {
		"id": "brawler",
		"display_name": "Brawler",
		"description": "A melee tank. High HP, heavy hits, no subtlety whatsoever.",
		"hp": 150,
		"stats": {"attack": 15, "defense": 5, "speed": 8},
		"abilities": ["basic_attack", "power_strike", "taunt", "shield_bash"],
		"icon_color": Color(0.8, 0.2, 0.2),
	},
	"rogue": {
		"id": "rogue",
		"display_name": "Rogue",
		"description": "Fast and lethal. Glass cannon who hits first and hard.",
		"hp": 100,
		"stats": {"attack": 20, "defense": 2, "speed": 15},
		"abilities": ["basic_attack", "backstab", "vanish"],
		"icon_color": Color(0.2, 0.8, 0.4),
	},
	"arcanist": {
		"id": "arcanist",
		"display_name": "Arcanist",
		"description": "Elemental devastation. Fragile but can hit multiple enemies at once.",
		"hp": 80,
		"stats": {"attack": 25, "defense": 0, "speed": 10},
		"abilities": ["basic_attack", "fireball", "frost_nova"],
		"icon_color": Color(0.3, 0.4, 1.0),
	},
}

static func get_class_data(id: String) -> Dictionary:
	return DATA.get(id, {})

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in DATA.keys():
		ids.append(k)
	return ids
