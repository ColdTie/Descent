class_name EnemyDefs
## Procedural enemy definitions for each floor tier.
## Enemy HP and armor scale with floor_num for progressive difficulty.

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

const BOSSES: Array[Dictionary] = [
	{
		"id": "dungeon_lord",
		"display_name": "Dungeon Lord",
		"hp": 120,
		"armor": 4,
		"speed": 9,
		"abilities": ["enemy_claw", "enemy_fireball"],
		"xp_reward": 150,
		"sprite_key": "boss_dungeon_lord",
		"min_floor": 1,
		"max_floor": 6,
	},
	{
		"id": "the_warden",
		"display_name": "The Warden",
		"hp": 200,
		"armor": 7,
		"speed": 7,
		"abilities": ["enemy_fireball", "enemy_claw", "enemy_bite"],
		"xp_reward": 250,
		"sprite_key": "boss_warden",
		"min_floor": 7,
		"max_floor": 12,
	},
	{
		"id": "abyss_keeper",
		"display_name": "Abyss Keeper",
		"hp": 320,
		"armor": 12,
		"speed": 8,
		"abilities": ["enemy_fireball", "enemy_claw", "enemy_bite"],
		"xp_reward": 400,
		"sprite_key": "boss_abyss_keeper",
		"min_floor": 13,
		"max_floor": 18,
	},
]

## Bosses appear on milestone floors only (every 3rd: 3, 6, 9, 12, 15, 18).
## Regular floors are normal enemy waves — this makes boss floors feel special
## instead of every floor having a "boss" (the old behaviour).
const BOSS_FLOOR_INTERVAL: int = 3

static func is_boss_floor(floor_num: int) -> bool:
	return floor_num > 0 and floor_num % BOSS_FLOOR_INTERVAL == 0

static func get_boss_for_floor(floor_num: int) -> Dictionary:
	for boss: Dictionary in BOSSES:
		if floor_num >= boss["min_floor"] and floor_num <= boss["max_floor"]:
			return boss
	return BOSSES[0]

static func make_boss(floor_num: int, position: Vector2i, rng: RandomNumberGenerator) -> Combatant:
	var boss_def: Dictionary = get_boss_for_floor(floor_num)
	## Bosses scale more aggressively than regular enemies
	var hp_scale: float = 1.0 + float(max(0, floor_num - 1)) * 0.30
	var scaled_hp: int = int(float(boss_def["hp"]) * hp_scale)
	var armor_bonus: int = max(0, (floor_num - 1) / 2)

	var c := Combatant.new(
		"boss_" + str(floor_num) + "_" + str(rng.randi_range(1000, 9999)),
		boss_def["display_name"],
		Combatant.Faction.ENEMY,
		scaled_hp,
		boss_def["speed"]
	)
	c.armor = boss_def.get("armor", 0) + armor_bonus
	c.position = position
	var raw_abilities: Array = boss_def.get("abilities", ["enemy_claw"])
	var typed_abilities: Array[String] = []
	for a: String in raw_abilities:
		typed_abilities.append(a)
	c.abilities = typed_abilities
	c.xp_reward = boss_def.get("xp_reward", 150)
	c.sprite_key = boss_def.get("sprite_key", "boss_dungeon_lord")
	c.is_boss = true
	return c

static func get_enemies_for_floor(floor_num: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e: Dictionary in ENEMIES:
		if e["min_floor"] <= floor_num:
			result.append(e)
	if result.is_empty():
		result.append(ENEMIES[0])
	return result

static func make_combatant(enemy_def: Dictionary, position: Vector2i, rng: RandomNumberGenerator, floor_num: int = 1) -> Combatant:
	## Create a Combatant from an enemy definition.
	## HP and armor scale with floor_num: +20% HP and +1 armor per floor above 1.
	var hp_scale: float = 1.0 + float(max(0, floor_num - 1)) * 0.20
	var scaled_hp: int = int(float(enemy_def["hp"]) * hp_scale)
	var base_armor: int = enemy_def.get("armor", 0)
	var floor_armor_bonus: int = max(0, (floor_num - 1) / 2)  # +1 armor every 2 floors

	var c := Combatant.new(
		enemy_def["id"] + "_" + str(rng.randi_range(1000, 9999)),
		enemy_def["display_name"],
		Combatant.Faction.ENEMY,
		scaled_hp,
		enemy_def["speed"]
	)
	c.armor = base_armor + floor_armor_bonus
	c.position = position
	# Must convert untyped Array from Dictionary to typed Array[String]
	var raw_abilities: Array = enemy_def.get("abilities", ["enemy_claw"])
	var typed_abilities: Array[String] = []
	for a: String in raw_abilities:
		typed_abilities.append(a)
	# Conditional ability unlocks based on floor depth
	var enemy_id: String = enemy_def.get("id", "")
	if enemy_id == "skeleton" and floor_num >= 10 and not typed_abilities.has("bone_volley"):
		typed_abilities.append("bone_volley")
	if enemy_id == "demon_grunt" and floor_num >= 13 and not typed_abilities.has("hellfire_aoe"):
		typed_abilities.append("hellfire_aoe")
	c.abilities = typed_abilities
	c.xp_reward = enemy_def.get("xp_reward", 20)
	c.sprite_key = enemy_def.get("sprite_key", "imp")
	return c
