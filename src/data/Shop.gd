class_name Shop
## Run 21: between-floor merchant — DCC-style "the dungeon's storefront".
##
## Gold drops from kills, bosses, and floor clears (see GameState.award_gold
## callers in BattleScene). The Shop scene shows a random 4-item slate; the
## player may buy any items they can afford, then leave. Modeled on the
## SponsorOffer data shape so the UI code can mirror those patterns.
##
## Pure data + math: no autoload references, no Node ops. Safe in --script
## test mode.
##
## Run 25: Rarity tiers + reroll. Items now carry a `rarity` field
## (common/rare/legendary). Each slate slot rolls a rarity weighted by
## floor tier (deeper = more rare/legendary) before drawing a matching
## item — mirrors LootScreen's Run 24 pattern. A new `reroll_cost(reroll_n)`
## helper drives the shop's new REROLL button.

## How often the shop appears: every Nth floor *after* the loot pick. With
## the value 1 we surface a shop on every floor descent. Bumping this to 2
## or 3 thins out the interstitial cadence.
const SHOP_EVERY_N_FLOORS: int = 1

## Floors per run = 18. We don't want the shop on the very first floor since
## the player hasn't earned any gold yet — guarded in Main.gd by the
## `should_show_shop()` helper below.
const FIRST_SHOP_FLOOR: int = 1

## How many randomized item cards the shop offers per visit.
const SLATE_SIZE: int = 4

## Run 25: rarity tiers. Match LootScreen for visual + design consistency.
const RARITY_COMMON: String = "common"
const RARITY_RARE: String = "rare"
const RARITY_LEGENDARY: String = "legendary"

## Run 25: weighted rarity rolls per floor tier — tier 0 (floors 1-6) is
## mostly common, tier 2 (13-18) is mostly rare/legendary. Sums need not
## match across tiers; weights are normalized by `_pick_rarity_for_slot()`.
const RARITY_WEIGHTS_BY_TIER: Array[Dictionary] = [
	{RARITY_COMMON: 80, RARITY_RARE: 18, RARITY_LEGENDARY: 2},   # Floors 1-6
	{RARITY_COMMON: 55, RARITY_RARE: 35, RARITY_LEGENDARY: 10},  # Floors 7-12
	{RARITY_COMMON: 30, RARITY_RARE: 45, RARITY_LEGENDARY: 25},  # Floors 13-18
]

## Run 25: reroll economics. First reroll is cheap; cost climbs so a
## relentless reroller burns through gold fast. Linear so the math reads
## clearly: 25, 45, 65, 85, ...
const REROLL_BASE_COST: int = 25
const REROLL_STEP_COST: int = 20

## Run 31: "Merchant's Favor" — a once-per-run surprise event. When it fires,
## the visit's slate is guaranteed to contain a Legendary item, and that
## item is discounted by `FAVOR_DISCOUNT_PCT`. Chance is rolled per shop
## visit and scales with audience score (reality-show flavor: fan-favorite
## crawlers get the merchant's attention). Base chance is modest so it stays
## a delightful surprise; the cap prevents max-audience runs from making it
## near-certain. Flag lives on `GameState.merchant_favor_used` and is reset
## per run via `start_run()`.
const FAVOR_BASE_CHANCE: float = 0.18
const FAVOR_CHANCE_PER_100_AUDIENCE: float = 0.015
const FAVOR_CHANCE_CAP: float = 0.40
const FAVOR_DISCOUNT_PCT: float = 0.50


const INVENTORY: Array[Dictionary] = [
	{
		"id": "shop_field_kit",
		"name": "Field Medic Kit",
		"icon": "+",
		"color": Color(0.28, 0.86, 0.40),
		"cost": 40,
		"rarity": RARITY_COMMON,
		"desc": "Restore 40 HP. The dungeon's first-aid concession. Generously priced.",
		"effects": {"heal": 40},
	},
	{
		"id": "shop_blood_transfusion",
		"name": "Black-Market Transfusion",
		"icon": "HP",
		"color": Color(0.92, 0.32, 0.18),
		"cost": 90,
		"rarity": RARITY_COMMON,
		"desc": "+20 Max HP and heal 60. The provenance of the blood is not discussed.",
		"effects": {"max_hp": 20, "heal": 60},
	},
	{
		"id": "shop_sharpening_stone",
		"name": "Mystery Whetstone",
		"icon": "ATK",
		"color": Color(0.95, 0.55, 0.10),
		"cost": 75,
		"rarity": RARITY_COMMON,
		"desc": "+8 Attack. The merchant insists it sharpens fists too. He is lying about most things.",
		"effects": {"attack": 8},
	},
	{
		"id": "shop_plate_kit",
		"name": "Reinforced Plating",
		"icon": "DEF",
		"color": Color(0.45, 0.65, 1.00),
		"cost": 70,
		"rarity": RARITY_COMMON,
		"desc": "+3 Armor. Bolted to your existing armor. Removal not included.",
		"effects": {"defense": 3},
	},
	{
		"id": "shop_caffeine_pack",
		"name": "Quickdraw Stims",
		"icon": "SPD",
		"color": Color(0.96, 0.86, 0.20),
		"cost": 60,
		"rarity": RARITY_COMMON,
		"desc": "+3 Speed. The merchant assures you the side-effects clear before Floor 18.",
		"effects": {"speed": 3},
	},
	{
		"id": "shop_publicity_packet",
		"name": "Publicity Packet",
		"icon": "*",
		"color": Color(0.96, 0.78, 0.18),
		"cost": 50,
		"rarity": RARITY_COMMON,
		"desc": "+60 Audience favor. Pre-printed merchandise. The crowd does love a sellout.",
		"effects": {"audience": 60},
	},
	{
		"id": "shop_megaheal",
		"name": "Suspicious Healing Draught",
		"icon": "*",
		"color": Color(0.40, 0.92, 0.50),
		"cost": 120,
		"rarity": RARITY_RARE,
		"desc": "Restore 90 HP and +10 Max HP. Tastes like copper. The merchant won't say why.",
		"effects": {"heal": 90, "max_hp": 10},
	},
	{
		"id": "shop_combat_brew",
		"name": "Berserker's Brew",
		"icon": "ATK",
		"color": Color(0.78, 0.28, 0.18),
		"cost": 130,
		"rarity": RARITY_RARE,
		"desc": "+12 Attack, +2 Speed. The aftertaste lingers. So does the aggression.",
		"effects": {"attack": 12, "speed": 2},
	},
	{
		"id": "shop_tower_shield",
		"name": "Surplus Tower Shield",
		"icon": "DEF",
		"color": Color(0.55, 0.65, 0.95),
		"cost": 140,
		"rarity": RARITY_RARE,
		"desc": "+6 Armor, +25 Max HP. Heavy. Reassuringly so. The previous owner could not be reached for comment.",
		"effects": {"defense": 6, "max_hp": 25},
	},
	{
		"id": "shop_warpaint",
		"name": "Branded Warpaint",
		"icon": "*",
		"color": Color(0.95, 0.32, 0.62),
		"cost": 100,
		"rarity": RARITY_RARE,
		"desc": "+5 Attack, +5 Defense, +25 Audience. Sponsored by 'Nobody Important'.",
		"effects": {"attack": 5, "defense": 5, "audience": 25},
	},
	# Run 25: new RARE — Rogue/Arcanist-flavored speed + attack.
	{
		"id": "shop_seers_charm",
		"name": "Seer's Charm",
		"icon": "SPD",
		"color": Color(0.58, 0.88, 0.94),
		"cost": 115,
		"rarity": RARITY_RARE,
		"desc": "+6 Attack, +6 Speed. The eye on the pendant blinks. Pretend it didn't.",
		"effects": {"attack": 6, "speed": 6},
	},
	{
		"id": "shop_titan_tonic",
		"name": "Titan's Tonic",
		"icon": "HP",
		"color": Color(0.30, 0.84, 0.30),
		"cost": 180,
		"rarity": RARITY_LEGENDARY,
		"desc": "+40 Max HP and heal to full. The dungeon files an objection. Ignored.",
		"effects": {"max_hp": 40, "full_heal": 1},
	},
	# Run 25: new LEGENDARY items — gated by price + tier-weighted rarity rolls.
	{
		"id": "shop_phoenix_ampoule",
		"name": "Phoenix Ampoule",
		"icon": "+",
		"color": Color(1.00, 0.55, 0.10),
		"cost": 300,
		"rarity": RARITY_LEGENDARY,
		"desc": "+50 Max HP, heal to full, +30 Audience. Tastes faintly of ash and applause.",
		"effects": {"max_hp": 50, "full_heal": 1, "audience": 30},
	},
	{
		"id": "shop_god_blade",
		"name": "God-Tier Edge",
		"icon": "ATK",
		"color": Color(1.00, 0.78, 0.18),
		"cost": 280,
		"rarity": RARITY_LEGENDARY,
		"desc": "+20 Attack. The blade hums a copyright-infringing jingle. Refunds void.",
		"effects": {"attack": 20},
	},
	{
		"id": "shop_warden_scale",
		"name": "Warden's Scale",
		"icon": "DEF",
		"color": Color(0.55, 0.78, 1.00),
		"cost": 260,
		"rarity": RARITY_LEGENDARY,
		"desc": "+10 Armor, +40 Max HP. Scraped from a boss that doesn't need it anymore.",
		"effects": {"defense": 10, "max_hp": 40},
	},
]


static func _floor_tier(floor_num: int) -> int:
	## Floor tier: 0 = stone (1-6), 1 = obsidian (7-12), 2 = void (13-18).
	## Matches LootScreen + BattleScene tier math.
	return clamp((max(1, floor_num) - 1) / 6, 0, 2)


static func _pick_rarity_for_slot(rng: RandomNumberGenerator, floor_num: int) -> String:
	## Weighted pick of a rarity for one slate slot. Defensive fallback to
	## common if the weight table is empty.
	var weights: Dictionary = RARITY_WEIGHTS_BY_TIER[_floor_tier(floor_num)]
	var total: int = 0
	for r: String in weights:
		total += int(weights[r])
	if total <= 0:
		return RARITY_COMMON
	var roll: int = rng.randi_range(0, total - 1)
	var cum: int = 0
	for r: String in weights:
		cum += int(weights[r])
		if roll < cum:
			return r
	return RARITY_COMMON


static func _draw_item_of_rarity(rarity: String, exclude: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	## Return a random INVENTORY item of the given rarity that isn't in
	## `exclude`. Returns {} if the pool is empty — callers must fall back.
	var pool: Array[Dictionary] = []
	for it: Dictionary in INVENTORY:
		if String(it.get("rarity", RARITY_COMMON)) != rarity:
			continue
		if exclude.has(it.get("id", "")):
			continue
		pool.append(it)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


static func slate(rng: RandomNumberGenerator, floor_num: int = 1,
		locked: Array[Dictionary] = []) -> Array[Dictionary]:
	## Return SLATE_SIZE distinct items rolled with per-tier rarity weighting.
	## Caller-provided rng + floor_num keeps this deterministic in tests and
	## per-run seeds. Falls back through lower rarity tiers when a chosen
	## bucket is exhausted, so the slate is always full when possible.
	##
	## Run 26: `locked` lets the caller carry items forward through a reroll.
	## Locked items are placed at the START of the returned array and excluded
	## from fresh random draws (no duplicates). The Shop scene reorders them
	## back into their original slot positions before rendering.
	var picked_ids: Dictionary = {}
	var out: Array[Dictionary] = []
	for lk: Dictionary in locked:
		if out.size() >= SLATE_SIZE:
			break
		var lk_id: String = String(lk.get("id", ""))
		if lk_id == "" or picked_ids.has(lk_id):
			continue
		picked_ids[lk_id] = true
		out.append(lk)
	while out.size() < SLATE_SIZE:
		var target: String = _pick_rarity_for_slot(rng, floor_num)
		var item: Dictionary = _draw_item_of_rarity(target, picked_ids, rng)
		if item.is_empty():
			# Fall back through the other rarity buckets (legendary -> rare -> common).
			var fallbacks: Array[String] = [RARITY_LEGENDARY, RARITY_RARE, RARITY_COMMON]
			for fb: String in fallbacks:
				if fb == target:
					continue
				item = _draw_item_of_rarity(fb, picked_ids, rng)
				if not item.is_empty():
					break
		if item.is_empty():
			break  # inventory exhausted — return partial slate rather than loop forever
		picked_ids[item.get("id", "")] = true
		out.append(item)
	return out


static func get_item(id: String) -> Dictionary:
	for it: Dictionary in INVENTORY:
		if String(it.get("id", "")) == id:
			return it
	return {}


static func reroll_cost(reroll_n: int) -> int:
	## Run 25: nth reroll cost. n=0 -> 25, n=1 -> 45, n=2 -> 65, ...
	## Linear ramp keeps the math legible and the punishment proportional.
	if reroll_n < 0:
		reroll_n = 0
	return REROLL_BASE_COST + REROLL_STEP_COST * reroll_n


static func gold_for_kill(floor_num: int) -> int:
	## Base 10 plus a small per-floor scaling so later floors are richer to
	## offset the higher shop prices. Floor 1 = 12, Floor 18 = 46.
	return 10 + max(0, floor_num) * 2


static func gold_for_boss(floor_num: int) -> int:
	## Bosses are a real payday — comparable to a small shop item by Floor 6.
	return 50 + max(0, floor_num) * 5


static func gold_for_clear(floor_num: int) -> int:
	## End-of-floor completion bonus.
	return 20 + max(0, floor_num) * 3


static func favor_chance(audience_score: int) -> float:
	## Run 31: probability that the merchant takes a shine to the hero this
	## visit. Base + audience-scaled bonus, clamped at the run-wide cap.
	## Negative audience inputs are treated as zero (defensive — audience
	## never actually drops, but better than letting a stray sentinel value
	## produce a sub-base chance).
	var bonus: float = (max(0, audience_score) / 100.0) * FAVOR_CHANCE_PER_100_AUDIENCE
	return clamp(FAVOR_BASE_CHANCE + bonus, 0.0, FAVOR_CHANCE_CAP)


static func roll_merchant_favor(rng: RandomNumberGenerator, audience_score: int) -> bool:
	## Run 31: single probabilistic roll. Defensive null-rng case returns false
	## so a missing rng never accidentally activates the favor (which would
	## silently consume the once-per-run flag).
	if rng == null:
		return false
	return rng.randf() < favor_chance(audience_score)


static func discounted_cost(original: int) -> int:
	## Run 31: apply the favor discount, with a 1-gold floor so a future
	## low-cost Legendary can't round down to zero (defensive — every current
	## Legendary is well above the threshold, but invariant matters).
	if original <= 0:
		return 0
	return max(1, int(round(float(original) * (1.0 - FAVOR_DISCOUNT_PCT))))


static func cheapest_legendary(exclude: Dictionary = {}) -> Dictionary:
	## Run 31: pick the cheapest Legendary not already in `exclude` (keyed by
	## item id). Used by the Shop scene to *force* a Legendary into the slate
	## when favor rolls and the random slate didn't naturally surface one.
	## Returns {} when the Legendary pool is fully excluded.
	var best: Dictionary = {}
	var best_cost: int = 1 << 30
	for it: Dictionary in INVENTORY:
		if String(it.get("rarity", "")) != RARITY_LEGENDARY:
			continue
		if exclude.has(String(it.get("id", ""))):
			continue
		var c: int = int(it.get("cost", 1 << 30))
		if c < best_cost:
			best_cost = c
			best = it
	return best


## Run 33: loot-buyback pricing by rarity. Deliberately above the "value" of
## an equivalent shop item — you passed on it once; the merchant remembers.
const BUYBACK_COSTS: Dictionary = {
	RARITY_COMMON: 60,
	RARITY_RARE: 120,
	RARITY_LEGENDARY: 240,
}


static func buyback_cost(rarity: String) -> int:
	## Unknown rarity falls back to the Common price (defensive).
	return int(BUYBACK_COSTS.get(rarity, BUYBACK_COSTS[RARITY_COMMON]))


static func pick_buyback_candidate(slate: Array, chosen_id: String) -> Dictionary:
	## Run 33: from a loot slate, pick the card the merchant will offer to
	## "buy back" — the best item the player skipped. Highest rarity wins
	## (legendary > rare > common); ties go to the earlier slate position.
	## Skip-type items (Teleport Shard) are excluded — re-selling a floor skip
	## from the shop would mutate floor_num mid-interlude. Returns {} when
	## nothing qualifies.
	var rank: Dictionary = {RARITY_COMMON: 0, RARITY_RARE: 1, RARITY_LEGENDARY: 2}
	var best: Dictionary = {}
	var best_rank: int = -1
	for it_v: Variant in slate:
		if not (it_v is Dictionary):
			continue
		var it: Dictionary = it_v
		if String(it.get("id", "")) == chosen_id:
			continue
		if String(it.get("type", "")) == "skip":
			continue
		var r: int = int(rank.get(String(it.get("rarity", RARITY_COMMON)), 0))
		if r > best_rank:
			best_rank = r
			best = it
	return best


static func should_show_shop(floor_num: int, hero_gold: int) -> bool:
	## Suppress the shop on Floor 1 (no gold yet) and when the cadence rule
	## says skip. Cadence is `floor_num % SHOP_EVERY_N_FLOORS == 0`.
	## floor_num here is the floor the player JUST CLEARED (about to descend).
	if floor_num < FIRST_SHOP_FLOOR:
		return false
	if hero_gold <= 0:
		return false
	if SHOP_EVERY_N_FLOORS <= 1:
		return true
	return floor_num % SHOP_EVERY_N_FLOORS == 0
