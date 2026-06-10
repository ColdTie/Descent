class_name Sponsors
## Run 20: DCC reality-show sponsor offers.
## Run 29: rarity tiers + threshold-weighted slate + multi-offer story arcs.
## Run 30: multi-step chains — Spectral Cola trilogy + Bopca Executive plan
## + Hyperion Megapack. A sponsor can mark `chain_finale: true` so the screen
## treats it as the capstone of its arc (special badge + finale quip).
##
## In Dungeon Crawler Carl, weird alien corporations sponsor crawlers in
## exchange for advertising — they hand out gifts that are sometimes pure
## boons, sometimes trade-offs with strings attached. We surface this every
## time the player's audience favor crosses a threshold: a three-card
## "sponsor gift" pick screen, modelled on LootScreen / LevelUp.
##
## Run 29: as the player takes more sponsors, the slate tilts toward
## rarer offers (mirroring Loot/Shop's depth-tiered rarity). A handful of
## sponsors are "return engagements" — they only appear if the player
## previously took a setup sponsor (`requires_taken`). This threads the
## DCC reality-show conceit across multiple offers instead of a flat pool.
##
## Run 30: chains can be more than two steps. Spectral Cola is a 3-step
## trilogy (cola → zero → singularity). The middle step's `requires_taken`
## is the OG sponsor; the finale's `requires_taken` is the middle step,
## so the chain unlocks step by step as the player engages with the brand.
##
## Pure data + math. No autoload references, no Node ops — safe to test in
## --script mode.

const SPONSOR_THRESHOLD: int = 200
const SLATE_SIZE: int = 3

# Rarity tiers — mirror LootScreen / Shop. Drives draw weighting, card border
# color, and the "legendary" entry flash + audio sting in SponsorOffer.gd.
const RARITY_COMMON: String = "common"
const RARITY_RARE: String = "rare"
const RARITY_LEGENDARY: String = "legendary"

const RARITY_COLORS: Dictionary = {
	RARITY_COMMON:    Color(0.72, 0.72, 0.74),
	RARITY_RARE:      Color(0.42, 0.72, 1.00),
	RARITY_LEGENDARY: Color(1.00, 0.55, 0.10),
}

const RARITY_LABELS: Dictionary = {
	RARITY_COMMON:    "COMMON",
	RARITY_RARE:      "RARE",
	RARITY_LEGENDARY: "LEGENDARY",
}

# Weighting by how many sponsors the player has already taken. As taken_count
# rises, Common shrinks and Legendary climbs — same monotonic shape as Loot's
# floor-tier table, but keyed off the player's audience-show progression
# instead of dungeon depth. Four buckets so a single-sponsor run still sees
# distinct weighting from a five-sponsor run.
const RARITY_WEIGHTS_BY_TAKEN: Array[Dictionary] = [
	{RARITY_COMMON: 70, RARITY_RARE: 27, RARITY_LEGENDARY: 3},   # taken 0
	{RARITY_COMMON: 55, RARITY_RARE: 37, RARITY_LEGENDARY: 8},   # taken 1-2
	{RARITY_COMMON: 38, RARITY_RARE: 45, RARITY_LEGENDARY: 17},  # taken 3-4
	{RARITY_COMMON: 22, RARITY_RARE: 48, RARITY_LEGENDARY: 30},  # taken 5+
]


static func taken_tier(taken_count: int) -> int:
	## 4-bucket mapping from running sponsor count to weight-table index.
	if taken_count <= 0:
		return 0
	if taken_count <= 2:
		return 1
	if taken_count <= 4:
		return 2
	return 3


const POOL: Array[Dictionary] = [
	{
		"id": "hyperion_drink",
		"sponsor": "Hyperion Drink-It-All",
		"icon": "*",
		"name": "Sponsorship Hydration Pack",
		"color": Color(0.30, 0.78, 0.96),
		"rarity": RARITY_COMMON,
		"desc": "+15 Max HP and heal 30. The label says \"REFRESHING\". It is lying.",
		"effects": {"max_hp": 15, "heal": 30},
	},
	{
		"id": "big_mikes_meat",
		"sponsor": "BIG MIKE'S MEAT EMPORIUM",
		"icon": "ATK",
		"name": "Endorsement Cleaver",
		"color": Color(0.92, 0.30, 0.18),
		"rarity": RARITY_RARE,
		"desc": "+12 Attack, -10 Max HP. Big Mike believes in confidence over caution.",
		"effects": {"attack": 12, "max_hp": -10},
	},
	{
		"id": "iron_tassel",
		"sponsor": "Iron Tassel Hardware",
		"icon": "DEF",
		"name": "Branded Plating",
		"color": Color(0.42, 0.68, 1.00),
		"rarity": RARITY_COMMON,
		"desc": "+5 Armor. \"BRAND VISIBILITY\" is etched across your chest. Loudly.",
		"effects": {"defense": 5},
	},
	{
		"id": "spectral_cola",
		"sponsor": "Spectral Cola Corp.",
		"icon": "SPD",
		"name": "Spectral Sugar Rush",
		"color": Color(0.95, 0.78, 0.10),
		"rarity": RARITY_RARE,
		"desc": "+6 Speed and +6 Attack. The crash will come later. It always does.",
		"effects": {"attack": 6, "speed": 6},
	},
	{
		"id": "bopca_insurance",
		"sponsor": "Bopca Insurance & Mortuary",
		"icon": "HP",
		"name": "Pre-Paid Funeral Plan",
		"color": Color(0.28, 0.86, 0.40),
		"rarity": RARITY_RARE,
		"desc": "+30 Max HP. Bopca cares about your continued ad-impressions.",
		"effects": {"max_hp": 30, "heal": 30},
	},
	{
		"id": "gofundit",
		"sponsor": "GoFundIt Toaster Co.",
		"icon": "*",
		"name": "Toaster Endorsement Deal",
		"color": Color(0.96, 0.60, 0.18),
		"rarity": RARITY_COMMON,
		"desc": "+75 Audience favor. No stats. Pure brand exposure. The crowd loves a sellout.",
		"effects": {"audience": 75},
	},
	{
		"id": "rays_pizza",
		"sponsor": "Ray's Pizza Tactics",
		"icon": "+",
		"name": "Combat Slice",
		"color": Color(0.95, 0.40, 0.18),
		"rarity": RARITY_COMMON,
		"desc": "Restore 60 HP now. Ray believes pizza solves most tactical problems.",
		"effects": {"heal": 60},
	},
	{
		"id": "quantec_pet",
		"sponsor": "QuanTec Pet Supplies",
		"icon": "*",
		"name": "Princess Donut Endorsement",
		"color": Color(0.96, 0.72, 0.96),
		"rarity": RARITY_RARE,
		"desc": "+8 Attack, +20 Max HP. The cat insisted on signing this one personally.",
		"effects": {"attack": 8, "max_hp": 20, "heal": 20},
	},
	{
		"id": "rumnoir_rotgut",
		"sponsor": "RumNoir Rotgut Whiskey",
		"icon": "ATK",
		"name": "Liquid Courage",
		"color": Color(0.78, 0.42, 0.10),
		"rarity": RARITY_RARE,
		"desc": "+14 Attack, -3 Armor. The label warns of \"poor decision-making\". Accurate.",
		"effects": {"attack": 14, "defense": -3},
	},
	{
		"id": "exitpit_adv",
		"sponsor": "ExitPit Adventures, Ltd.",
		"icon": "DEF",
		"name": "Branded Tower Shield",
		"color": Color(0.62, 0.58, 1.00),
		"rarity": RARITY_RARE,
		"desc": "+7 Armor, -2 Speed. Heavy. Slow. Reassuringly thick.",
		"effects": {"defense": 7, "speed": -2},
	},
	# ── Run 29 additions ───────────────────────────────────────────────────
	{
		"id": "tiny_carl_plush",
		"sponsor": "Tiny Carl Plush Co.",
		"icon": "*",
		"name": "Tiny Carl Plushie Endorsement",
		"color": Color(0.95, 0.86, 0.62),
		"rarity": RARITY_COMMON,
		"desc": "+8 Max HP and +40 Audience favor. The plushie looks like you. Almost.",
		"effects": {"max_hp": 8, "heal": 8, "audience": 40},
	},
	{
		"id": "big_mikes_return",
		"sponsor": "BIG MIKE'S RETURN ENGAGEMENT",
		"icon": "ATK",
		"name": "Premium Endorsement Cleaver",
		"color": Color(1.00, 0.40, 0.22),
		"rarity": RARITY_LEGENDARY,
		"requires_taken": "big_mikes_meat",
		"desc": "+15 Attack and heal 40. Big Mike never forgets a loyal endorser. The meat is fresher this time. Allegedly.",
		"effects": {"attack": 15, "heal": 40},
	},
	{
		"id": "godking_industries",
		"sponsor": "GODKING INDUSTRIES, FOREVER",
		"icon": "*",
		"name": "Sovereign Brand Coronation",
		"color": Color(1.00, 0.84, 0.18),
		"rarity": RARITY_LEGENDARY,
		"desc": "+10 Attack, +3 Armor, +20 Max HP, full heal. Brand sovereignty, sealed in flesh.",
		"effects": {"attack": 10, "defense": 3, "max_hp": 20, "heal": 999},
	},
	{
		"id": "neo_blood_co",
		"sponsor": "Neo Blood Co. Transfusion Bar",
		"icon": "HP",
		"name": "Premium Transfusion Loyalty Plan",
		"color": Color(0.86, 0.18, 0.30),
		"rarity": RARITY_LEGENDARY,
		"desc": "+40 Max HP, +5 Attack, -2 Speed. The bag is warm. The Crown of Blood approves.",
		"effects": {"max_hp": 40, "heal": 40, "attack": 5, "speed": -2},
	},
	# ── Run 30 additions — multi-step story arcs ──────────────────────────────
	# Spectral Cola Trilogy: spectral_cola → spectral_cola_zero → singularity.
	# Each step's `requires_taken` is the previous step, so the chain unlocks
	# only as the player engages with the brand across multiple offers. The
	# capstone carries `chain_finale: true` so the screen treats it as the
	# trilogy payoff (special badge + finale quip).
	{
		"id": "spectral_cola_zero",
		"sponsor": "Spectral Cola Zero",
		"icon": "SPD",
		"name": "Zero-Sugar Sequel Deal",
		"color": Color(0.85, 0.85, 0.95),
		"rarity": RARITY_RARE,
		"requires_taken": "spectral_cola",
		"desc": "+5 Speed, +5 Attack, +10 Max HP. The bottle is matte black. The branding swears it's healthier. The audience does not care.",
		"effects": {"attack": 5, "speed": 5, "max_hp": 10},
	},
	{
		"id": "spectral_cola_singularity",
		"sponsor": "SPECTRAL COLA SINGULARITY",
		"icon": "SPD",
		"name": "The Cola Singularity",
		"color": Color(1.00, 0.10, 0.55),
		"rarity": RARITY_LEGENDARY,
		"requires_taken": "spectral_cola_zero",
		"chain_finale": true,
		"desc": "+12 Attack, +6 Speed, +30 Max HP, heal 30, +50 Audience. The trilogy concludes. The product transcends carbonation. So do you.",
		"effects": {"attack": 12, "speed": 6, "max_hp": 30, "heal": 30, "audience": 50},
	},
	# Bopca Insurance saga: insurance → executive plan. Two-step Legendary
	# upgrade — the executive package is what insurance was always going to be
	# once the actuaries finished their pitch.
	{
		"id": "bopca_executive_plan",
		"sponsor": "Bopca Executive Plan",
		"icon": "DEF",
		"name": "Platinum Underwriter Package",
		"color": Color(0.20, 0.92, 0.55),
		"rarity": RARITY_LEGENDARY,
		"requires_taken": "bopca_insurance",
		"desc": "+50 Max HP, +4 Armor, full heal. The actuaries have reviewed your file. They approve. Reluctantly.",
		"effects": {"max_hp": 50, "defense": 4, "heal": 999},
	},
	# Hyperion Drink — the easy-mode early-game arc. Common setup, Rare payoff.
	# Lower stakes than the Cola trilogy; designed so a fresh-run player has at
	# least one arc they can plausibly complete inside a single descent.
	{
		"id": "hyperion_megapack",
		"sponsor": "Hyperion Drink-It-All Mega Pack",
		"icon": "HP",
		"name": "Bulk Hydration Endorsement",
		"color": Color(0.20, 0.86, 1.00),
		"rarity": RARITY_RARE,
		"requires_taken": "hyperion_drink",
		"desc": "+20 Max HP, heal 60, +2 Speed. The case is industrial-sized. The audience approves of bulk endorsements.",
		"effects": {"max_hp": 20, "heal": 60, "speed": 2},
	},
]


static func sponsors_owed(audience: int, taken: int) -> int:
	## How many sponsor pop-ups the player is currently owed.
	## Resets to zero if `taken` already meets the threshold count.
	if audience <= 0:
		return 0
	var earned: int = int(audience) / SPONSOR_THRESHOLD
	return max(0, earned - taken)


static func get_offer(id: String) -> Dictionary:
	for o: Dictionary in POOL:
		if String(o.get("id", "")) == id:
			return o
	return {}


static func is_chain_finale(offer: Dictionary) -> bool:
	## Run 30: convenience predicate. A chain finale is the capstone of a
	## multi-step story arc; the screen shows a special badge and the System
	## fires a dedicated quip on accept.
	return bool(offer.get("chain_finale", false))


static func eligible_pool(taken_ids: Array) -> Array[Dictionary]:
	## Run 29: filter the pool by sponsor story prerequisites. A sponsor with
	## `requires_taken: "id"` only appears once the player has accepted that
	## setup sponsor. Pure — no autoload deps, no Node ops.
	var out: Array[Dictionary] = []
	var taken_set: Dictionary = {}
	for s: Variant in taken_ids:
		taken_set[String(s)] = true
	for o: Dictionary in POOL:
		var prereq: String = String(o.get("requires_taken", ""))
		if prereq != "" and not taken_set.has(prereq):
			continue
		out.append(o)
	return out


static func _pick_rarity(rng: RandomNumberGenerator,
		weights: Dictionary) -> String:
	## Weighted single-rarity pick. Degenerate "all weights zero" guard
	## returns Common so a future bad table can't crash the screen.
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


static func _draw_of_rarity(rarity: String, pool: Array[Dictionary],
		exclude: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bucket: Array[Dictionary] = []
	for o: Dictionary in pool:
		if String(o.get("rarity", RARITY_COMMON)) != rarity:
			continue
		if exclude.has(String(o.get("id", ""))):
			continue
		bucket.append(o)
	if bucket.is_empty():
		return {}
	return bucket[rng.randi_range(0, bucket.size() - 1)]


static func slate(rng: RandomNumberGenerator, taken_count: int = 0,
		taken_ids: Array = []) -> Array[Dictionary]:
	## Run 29: build a 3-card sponsor slate. Each slot rolls a rarity weighted
	## by `taken_count`, then draws a sponsor of that rarity that hasn't been
	## placed on this slate yet. Falls through to the other rarities (highest
	## first) if the chosen bucket is exhausted — so a thin Common pool can't
	## downgrade a Legendary slot. Sponsors whose `requires_taken` prereq
	## isn't in `taken_ids` are removed up-front via `eligible_pool()`.
	var picked: Array[Dictionary] = []
	if rng == null:
		return picked
	var pool: Array[Dictionary] = eligible_pool(taken_ids)
	if pool.is_empty():
		return picked
	var tier: int = taken_tier(taken_count)
	var weights: Dictionary = RARITY_WEIGHTS_BY_TAKEN[tier]
	var exclude: Dictionary = {}
	for _slot: int in range(SLATE_SIZE):
		var target: String = _pick_rarity(rng, weights)
		var drawn: Dictionary = _draw_of_rarity(target, pool, exclude, rng)
		if drawn.is_empty():
			# Walk fallbacks from rarest down so a depleted Common doesn't
			# silently swap into a Legendary slot.
			for fallback: String in [RARITY_LEGENDARY, RARITY_RARE, RARITY_COMMON]:
				if fallback == target:
					continue
				drawn = _draw_of_rarity(fallback, pool, exclude, rng)
				if not drawn.is_empty():
					break
		if drawn.is_empty():
			continue
		exclude[String(drawn.get("id", ""))] = true
		picked.append(drawn)
	return picked
