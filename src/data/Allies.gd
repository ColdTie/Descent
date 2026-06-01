class_name Allies
## Floor-specific NPC allies that join Carl for one battle.
## Pure data + factory — no Node dependency, headless-testable.
##
## On certain floors, Carl finds survivors who help in the fight. They are
## HERO-faction Combatants distinct from the player hero (`_hero == Carl`):
## - They take their own turn in the BattleEngine turn order
## - BattleScene's ally-AI loop drives them (move toward nearest enemy + attack)
## - Their death does NOT end the run (only Carl's death does)
## - They are not persisted between floors; each ally floor spawns them fresh

## Map of floor_num → list of ally definitions to spawn on that floor.
## Keys are floor numbers; values are arrays of ally def dictionaries.
const ALLIES_BY_FLOOR: Dictionary = {
	3: [
		{
			"id": "marcus",
			"display_name": "Marcus the Steadfast",
			"hp": 70,
			"speed": 11,
			"armor": 3,
			"attack_bonus": 4,
			"abilities": ["basic_attack"],
			"sprite_key": "ally_marcus",
			"glow_color": Color(0.95, 0.78, 0.18, 0.42),  # gold knight aura
		},
		{
			"id": "lina",
			"display_name": "Lina Hexweaver",
			"hp": 55,
			"speed": 13,
			"armor": 0,
			"attack_bonus": 6,
			"abilities": ["basic_attack"],
			"sprite_key": "ally_lina",
			"glow_color": Color(0.55, 0.85, 0.78, 0.42),  # arcane teal aura
		},
	],
}


static func get_allies_for_floor(floor_num: int) -> Array[Dictionary]:
	## Returns the typed list of ally definitions for `floor_num`,
	## or an empty array if no allies are scheduled.
	var result: Array[Dictionary] = []
	var pool: Array = ALLIES_BY_FLOOR.get(floor_num, [])
	for d: Dictionary in pool:
		result.append(d)
	return result


static func has_allies_on_floor(floor_num: int) -> bool:
	return not get_allies_for_floor(floor_num).is_empty()


static func make_ally(def: Dictionary, position: Vector2i, rng: RandomNumberGenerator) -> Combatant:
	## Build an ally Combatant from a definition + map position.
	## Ally ID is suffixed with a random tag so multiple allies don't collide
	## with each other or with any prior IDs in the same run.
	var c := Combatant.new(
		"ally_" + def["id"] + "_" + str(rng.randi_range(1000, 9999)),
		def["display_name"],
		Combatant.Faction.HERO,
		def["hp"],
		def.get("speed", 10)
	)
	c.armor = def.get("armor", 0)
	c.attack_bonus = def.get("attack_bonus", 0)
	c.position = position
	var raw: Array = def.get("abilities", ["basic_attack"])
	var typed: Array[String] = []
	for a: String in raw:
		typed.append(a)
	c.abilities = typed
	c.sprite_key = def.get("sprite_key", "ally_marcus")
	return c
