class_name BossDefs
## Boss enemy definitions — appear every 5 floors.
## Bosses are named, scaled entities with unique abilities and much higher HP/armor.

const BOSSES: Array[Dictionary] = [
	{
		"id": "stone_herald",
		"display_name": "Stone Herald",
		"title": "THE STONE HERALD",
		"flavor": "An ancient guardian carved from the dungeon itself. It has been waiting for you specifically.",
		"hp": 280,
		"armor": 12,
		"speed": 7,
		"abilities": ["enemy_claw", "enemy_shove", "boss_slam"],
		"xp_reward": 200,
		"sprite_key": "boss",
		"glyph": "★",
	},
	{
		"id": "wrathful_champion",
		"display_name": "Wrathful Champion",
		"title": "THE WRATHFUL CHAMPION",
		"flavor": "A fallen hero, now corrupted. It remembers what it was. This makes it angrier.",
		"hp": 320,
		"armor": 8,
		"speed": 12,
		"abilities": ["enemy_claw", "enemy_bite", "boss_cleave", "enemy_shove"],
		"xp_reward": 250,
		"sprite_key": "boss",
		"glyph": "☠",
	},
	{
		"id": "demon_overlord",
		"display_name": "Demon Overlord",
		"title": "THE DEMON OVERLORD",
		"flavor": "Upper management. You've been a productivity drain on this dungeon.",
		"hp": 380,
		"armor": 10,
		"speed": 9,
		"abilities": ["enemy_fireball", "boss_inferno", "enemy_shove", "enemy_claw"],
		"xp_reward": 300,
		"sprite_key": "boss",
		"glyph": "👑",
	},
]

static func get_boss_for_floor(floor_num: int) -> Dictionary:
	## Cycle through bosses every 5 floors (floor 5 = index 0, floor 10 = index 1, etc.).
	var tier: int = max(0, (floor_num / 5) - 1)
	var idx: int = tier % BOSSES.size()
	return BOSSES[idx]

static func make_boss(floor_num: int, spawn_pos: Vector2i, rng: RandomNumberGenerator) -> Combatant:
	## Create a boss Combatant. Scales with tier (each 5 floors above the first boss).
	## Tier 0 = floor 5, tier 1 = floor 10, tier 2 = floor 15, etc.
	var def: Dictionary = get_boss_for_floor(floor_num)
	var tier: int = max(0, (floor_num / 5) - 1)

	# HP scaling: +50% per tier above 0
	var hp_scale: float = 1.0 + float(tier) * 0.5
	var scaled_hp: int = int(float(def["hp"]) * hp_scale)
	# Armor scaling: +2 per tier
	var scaled_armor: int = def["armor"] + tier * 2
	# XP bonus: +50 per tier
	var scaled_xp: int = def["xp_reward"] + tier * 50

	var c := Combatant.new(
		def["id"] + "_floor" + str(floor_num),
		def["display_name"],
		Combatant.Faction.ENEMY,
		scaled_hp,
		def["speed"]
	)
	c.armor = scaled_armor
	c.position = spawn_pos
	c.xp_reward = scaled_xp
	c.sprite_key = def.get("sprite_key", "boss")

	# Must convert untyped Array to typed Array[String]
	var raw_abilities: Array = def.get("abilities", ["enemy_claw"])
	var typed_abilities: Array[String] = []
	for a: String in raw_abilities:
		typed_abilities.append(a)
	c.abilities = typed_abilities

	return c

static func is_boss_floor(floor_num: int) -> bool:
	return floor_num > 0 and floor_num % 5 == 0
