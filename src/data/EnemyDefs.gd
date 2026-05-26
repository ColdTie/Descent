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
	## Scale enemy stats by floor. Each floor above min_floor adds HP, attack, and XP.
	var min_f: int = enemy_def.get("min_floor", 1)
	var scale: int = max(0, floor_num - min_f)  # floors above first appearance

	var base_hp: int = enemy_def["hp"]
	var scaled_hp: int = base_hp + scale * 10  # +10 HP per floor above min

	var c := Combatant.new(
		enemy_def["id"] + "_" + str(rng.randi_range(1000, 9999)),
		enemy_def["display_name"],
		Combatant.Faction.ENEMY,
		scaled_hp,
		enemy_def["speed"]
	)
	c.armor = enemy_def.get("armor", 0) + scale / 2  # slight armor scaling
	c.attack_bonus = scale * 2  # +2 flat attack per floor above min
	c.position = position
	# Must convert untyped Array from Dictionary to typed Array[String]
	var raw_abilities: Array = enemy_def.get("abilities", ["enemy_claw"])
	var typed_abilities: Array[String] = []
	for a: String in raw_abilities:
		typed_abilities.append(a)
	c.abilities = typed_abilities
	c.xp_reward = enemy_def.get("xp_reward", 20) + scale * 5  # more XP for tougher enemies
	c.sprite_key = enemy_def.get("sprite_key", "imp")
	return c
