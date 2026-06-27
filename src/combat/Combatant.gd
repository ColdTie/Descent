class_name Combatant
## Pure data class representing one fighter in a battle.
## No Node inheritance — fully serializable, testable headlessly.

enum Faction { HERO, ENEMY }

var id: String = ""
var display_name: String = ""
var faction: Faction = Faction.ENEMY
var hp: int = 0
var max_hp: int = 0
var armor: int = 0
var speed: int = 0  # higher = acts earlier in turn order
var position: Vector2i = Vector2i.ZERO  # hex grid coords (q, r)
var status_effects: Array[Dictionary] = []
var abilities: Array[String] = []
var xp_reward: int = 0
var sprite_key: String = ""  # references which placeholder sprite to use
var attack_bonus: int = 0    # flat bonus added to all outgoing damage
var is_boss: bool = false
var is_enraged: bool = false
# Run 32: optional sprite tint — lets enemy *variants* (Void Wraith, Bone
# Colossus) reuse an existing sprite with a distinct palette. WHITE = no tint.
var tint: Color = Color(1.0, 1.0, 1.0)

# Run 33: boss signature-move state. `signature_cd` counts the boss's own
# turns until the next signature is available (0 = ready); `rally_used`
# makes the Dungeon Lord's resurrection a once-per-battle event.
var signature_cd: int = 0
var rally_used: bool = false
# Run 34: Phase 3 ("Frenzied") flag. Trips once the boss drops below
# PHASE_3_HP_THRESHOLD HP, and from then on each signature escalates:
# Dungeon Lord rallies *every* corpse, Warden slam radius grows, Keeper
# pulls every hero in range. Cooldown also shortens — see BattleEngine.
var frenzied: bool = false

func _init(p_id: String, p_name: String, p_faction: Faction, p_hp: int, p_speed: int = 10) -> void:
	id = p_id
	display_name = p_name
	faction = p_faction
	max_hp = p_hp
	hp = p_hp
	speed = p_speed

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int, ignore_armor: bool = false) -> int:
	## Returns actual damage dealt.
	## ignore_armor=true bypasses armor reduction (for backstab, env damage, etc.)
	## Run 21: a mana_shield status absorbs damage BEFORE armor, before HP. When
	## the shield's pool drains, the status expires immediately and any leftover
	## damage falls through to armor/HP as normal.
	var remaining: int = _consume_mana_shield(amount)
	if remaining <= 0:
		return 0
	var mitigated: int
	if ignore_armor:
		mitigated = remaining
	else:
		mitigated = max(0, remaining - armor)
	hp = max(0, hp - mitigated)
	return mitigated


func _consume_mana_shield(incoming: int) -> int:
	## Drain the shield pool first; return any leftover damage.
	if incoming <= 0:
		return incoming
	for i: int in range(status_effects.size()):
		var eff: Dictionary = status_effects[i]
		if eff.get("id", "") != "mana_shield":
			continue
		var pool: int = int(eff.get("absorb_remaining", 0))
		if pool <= 0:
			status_effects.remove_at(i)
			return incoming
		if incoming <= pool:
			eff["absorb_remaining"] = pool - incoming
			if eff["absorb_remaining"] <= 0:
				status_effects.remove_at(i)
			return 0
		# Pool exhausted; let the overflow continue to armor/HP and drop status.
		status_effects.remove_at(i)
		return incoming - pool
	return incoming

func heal(amount: int) -> int:
	var actual: int = min(amount, max_hp - hp)
	hp += actual
	return actual

func apply_status(effect: Dictionary) -> void:
	# effect: {id, name, duration, damage_per_turn, armor_mod}
	status_effects.append(effect)

func tick_statuses() -> int:
	## Applies per-turn effects, returns total damage taken.
	## Run 49: a `heal_per_turn` field on a status (Regenerating today, any
	## future HoT tomorrow) heals the carrier via `heal()` after the DoT
	## drain has resolved. Order matters: DoT first so a carrier on the
	## brink can still die to burning even if a regen tick would have
	## papered it over — that keeps the "your HoT didn't save you" beat
	## consistent with how poison-then-heal plays in every other tactical
	## roguelike. `heal()` clamps to `max_hp`, so a full-HP carrier wastes
	## the tick (no overheal pool). Return value stays as total damage
	## taken (NOT net) so existing callers (BattleScene damage numbers,
	## boss-phase triggers) don't have to know about heals.
	var total_dmg: int = 0
	var remaining: Array[Dictionary] = []
	for eff in status_effects:
		if eff.has("damage_per_turn"):
			var dmg: int = eff["damage_per_turn"]
			hp = max(0, hp - dmg)
			total_dmg += dmg
		if eff.has("heal_per_turn") and is_alive():
			var hpt: int = int(eff["heal_per_turn"])
			if hpt > 0:
				heal(hpt)
		eff["duration"] -= 1
		if eff["duration"] > 0:
			remaining.append(eff)
	status_effects = remaining
	return total_dmg

func get_effective_armor() -> int:
	var bonus: int = 0
	for eff in status_effects:
		bonus += eff.get("armor_mod", 0)
	return armor + bonus

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"faction": faction,
		"hp": hp,
		"max_hp": max_hp,
		"armor": armor,
		"speed": speed,
		"position": {"q": position.x, "r": position.y},
		"status_effects": status_effects.duplicate(true),
		"abilities": abilities.duplicate(),
		"xp_reward": xp_reward,
	}
