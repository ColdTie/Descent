class_name Perks
## Run 36: meta-progression starting perks.
##
## Each perk is a small starting-state modifier the player buys ONCE with
## shards (the meta currency earned across runs) and may optionally equip
## up to `MAX_EQUIPPED` of at the start of every future run. Effects are
## applied in `GameState.start_run` right after the class data is loaded
## so they stack on top of the class baseline.
##
## Perks are deliberately QoL or build-enabling rather than overwhelming
## power — they should change WHICH choices feel attractive, not make
## hard floors trivial. Each effect is reachable from a tooltip read so
## the player understands what they bought.
##
## Pure data + tiny apply helpers. Zero Node dependency — fully testable
## headlessly. The MetaProgress autoload owns ownership/equip state; this
## module owns DEFS and the apply logic.

const MAX_EQUIPPED: int = 2

const DEFS: Dictionary = {
	"seasoned": {
		"id": "seasoned",
		"name": "Seasoned",
		"desc": "Begin every run at hero level 2 with the XP already banked.",
		"cost": 25,
		"icon": "*",
	},
	"wealthy": {
		"id": "wealthy",
		"name": "Wealthy",
		"desc": "Start each run with 30 gold for the first merchant.",
		"cost": 20,
		"icon": "$",
	},
	"iron_blood": {
		"id": "iron_blood",
		"name": "Iron Blood",
		"desc": "Start each run with +15 max HP and the bonus already healed.",
		"cost": 30,
		"icon": "+",
	},
	"lucky_strike": {
		"id": "lucky_strike",
		"name": "Lucky Strike",
		"desc": "+1 to the base attack stat of every class.",
		"cost": 30,
		"icon": "X",
	},
	"merchant_ally": {
		"id": "merchant_ally",
		"name": "Merchant's Friend",
		"desc": "Shop and reroll prices reduced by 15%.",
		"cost": 45,
		"icon": "$",
	},
	"audience_darling": {
		"id": "audience_darling",
		"name": "Audience Darling",
		"desc": "Start each run with +50 audience score (sponsor offers come sooner).",
		"cost": 30,
		"icon": "*",
	},
	"hardened_traveler": {
		"id": "hardened_traveler",
		"name": "Hardened Traveler",
		"desc": "+1 defense / armor at the start of every run.",
		"cost": 40,
		"icon": "+",
	},
	"swift_boots": {
		"id": "swift_boots",
		"name": "Swift Boots",
		"desc": "+1 speed at the start of every run.",
		"cost": 35,
		"icon": ">",
	},
}


static func get_perk(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in DEFS.keys():
		ids.append(k)
	return ids


static func cost(id: String) -> int:
	## Defensive: an unknown id returns -1 so callers don't accidentally bill
	## the player 0 shards for a phantom purchase.
	if not DEFS.has(id):
		return -1
	return int(DEFS[id].get("cost", 0))


static func shop_discount_pct(equipped: Array) -> int:
	## Total shop discount percentage from equipped perks. Currently only
	## `merchant_ally` contributes (15%). Returns 0 when nothing relevant is
	## equipped. Pulled out so Shop.gd can apply it in one place without
	## checking individual perk ids.
	if equipped == null or equipped.is_empty():
		return 0
	var pct: int = 0
	for pid_v: Variant in equipped:
		var pid: String = String(pid_v)
		if pid == "merchant_ally":
			pct += 15
	return pct


static func apply_shop_discount(raw_cost: int, equipped: Array) -> int:
	## Apply `shop_discount_pct` to a raw cost. 1-gold floor so a future
	## low-cost item can't round to free. No-op when discount is zero.
	if raw_cost <= 0:
		return 0
	var pct: int = shop_discount_pct(equipped)
	if pct <= 0:
		return raw_cost
	var discounted: int = int(round(float(raw_cost) * (1.0 - float(pct) / 100.0)))
	return max(1, discounted)


static func apply_to_run(state: Object, equipped: Array) -> void:
	## Mutates a GameState-like object in-place to apply equipped perks.
	## Called from `GameState.start_run` after the class defaults have been
	## loaded so each perk stacks on top of the class baseline.
	##
	## `state` is typed as Object instead of GameState so the test suite can
	## pass a duck-typed stand-in without instantiating the autoload (which
	## would crash under `--script` mode without `/root/GameRng`).
	##
	## Each apply branch is small and self-contained; adding a perk only
	## requires a DEFS entry + one new `elif` here.
	if state == null or equipped == null or equipped.is_empty():
		return
	# `seasoned` is a no-op until the hero has earned the first level — to
	# keep run-start free from circular gain_xp signals we just bump level
	# directly. The player's first level-up screen still fires when they
	# next cross the XP threshold.
	for pid_v: Variant in equipped:
		var pid: String = String(pid_v)
		match pid:
			"seasoned":
				state.hero_level = max(state.hero_level, 2)
			"wealthy":
				state.hero_gold += 30
			"iron_blood":
				state.hero_max_hp += 15
				state.hero_hp = state.hero_max_hp
			"lucky_strike":
				var atk: int = int(state.hero_base_stats.get("attack", 0))
				state.hero_base_stats["attack"] = atk + 1
			"hardened_traveler":
				var def: int = int(state.hero_base_stats.get("defense", 0))
				state.hero_base_stats["defense"] = def + 1
			"swift_boots":
				var spd: int = int(state.hero_base_stats.get("speed", 0))
				state.hero_base_stats["speed"] = spd + 1
			"audience_darling":
				state.audience_score += 50
			# `merchant_ally` is a passive discount — handled by Shop via
			# `Perks.shop_discount_pct`, not by a state mutation.
			_:
				pass
