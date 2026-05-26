class_name EnemyDefs
## Procedural enemy definitions for each floor tier.

const ENEMIES: Array[Dictionary] = [
	{
		"id": "imp",
		"display_name": "Imp",
		"hp": 25,
		"armor": 0,
		"speed": 12,
		"abilities": ["enemy_claw"],
		"xp_reward": 20,
		"sprite_key": "imp",
		"min_floor": 1,
	},
	{
		"id": "goblin",
		"display_name": "Goblin Scout",
		"hp": 35,
		"armor": 1,
		"speed": 14,
		"abilities": ["enemy_claw", "enemy_bite"],
		"xp_reward": 25,
		"sprite_key": "goblin",
		"min_floor": 1,
	},
	{
		"id": "skeleton",
		"display_name": "Skeleton",
		"hp": 45,
		"armor": 3,
		"speed": 8,
		"abilities": ["enemy_claw"],
		"xp_reward": 30,
		"sprite_key": "skeleton",
		"min_floor": 2,
	},
	{
		"id": "demon_grunt",
		"display_name": "Demon Grunt",
		"hp": 60,
		"armor": 5,
		"speed": 10,
		"abilities": ["enemy_claw", "enemy_fireball"],
		"xp_reward": 45,
		"sprite_key": "demon",
		"min_floor": 3,
	},
	{
		"id": "lava_golem",
		"display_name": "Lava Golem",
		"hp": 90,
		"armor": 8,
		"speed": 5,
		"abilities": ["enemy_fireball"],
		"xp_reward": 60,
		"sprite_key": "golem",
		"min_floor": 4,
	},
]

static func get_enemies_for_floor(floor_num: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e: Dictionary in ENEMIES:
		if e["min_floor"] <= floor_num:
			result.append(e)
	if result.is_empty():
		result.append(ENEMIES[0])
	return result

static func make_combatant(enemy_def: Dictionary, position: Vector2i, rng: RandomNumberGenerator, floor_num: int = 1) -> Combatant:
	## floor_num scales HP (+15% per floor above 1) and attack_bonus (+2 per floor above 1).
	var floors_above_1: int = max(0, floor_num - 1)
	var hp_scale: float = 1.0 + float(floors_above_1) * 0.15
	var scaled_hp: int = int(float(enemy_def["hp"]) * hp_scale)
	var c := Combatant.new(
		enemy_def["id"] + "_" + str(rng.randi_range(1000, 9999)),
		enemy_def["display_name"],
		Combatant.Faction.ENEMY,
		scaled_hp,
		enemy_def["speed"]
	)
	c.armor = enemy_def.get("armor", 0)
	c.attack_bonus = floors_above_1 * 2  # +2 raw attack per floor above 1
	c.position = position
	# Must convert untyped Array from Dictionary to typed Array[String]
	var raw_abilities: Array = enemy_def.get("abilities", ["enemy_claw"])
	var typed_abilities: Array[String] = []
	for a: String in raw_abilities:
		typed_abilities.append(a)
	c.abilities = typed_abilities
	c.xp_reward = enemy_def.get("xp_reward", 20)
	c.sprite_key = enemy_def.get("sprite_key", "imp")
	return c
