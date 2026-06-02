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


const INVENTORY: Array[Dictionary] = [
	{
		"id": "shop_field_kit",
		"name": "Field Medic Kit",
		"icon": "✚",
		"color": Color(0.28, 0.86, 0.40),
		"cost": 40,
		"desc": "Restore 40 HP. The dungeon's first-aid concession. Generously priced.",
		"effects": {"heal": 40},
	},
	{
		"id": "shop_blood_transfusion",
		"name": "Black-Market Transfusion",
		"icon": "❤",
		"color": Color(0.92, 0.32, 0.18),
		"cost": 90,
		"desc": "+20 Max HP and heal 60. The provenance of the blood is not discussed.",
		"effects": {"max_hp": 20, "heal": 60},
	},
	{
		"id": "shop_sharpening_stone",
		"name": "Mystery Whetstone",
		"icon": "⚔",
		"color": Color(0.95, 0.55, 0.10),
		"cost": 75,
		"desc": "+8 Attack. The merchant insists it sharpens fists too. He is lying about most things.",
		"effects": {"attack": 8},
	},
	{
		"id": "shop_plate_kit",
		"name": "Reinforced Plating",
		"icon": "🛡",
		"color": Color(0.45, 0.65, 1.00),
		"cost": 70,
		"desc": "+3 Armor. Bolted to your existing armor. Removal not included.",
		"effects": {"defense": 3},
	},
	{
		"id": "shop_caffeine_pack",
		"name": "Quickdraw Stims",
		"icon": "⚡",
		"color": Color(0.96, 0.86, 0.20),
		"cost": 60,
		"desc": "+3 Speed. The merchant assures you the side-effects clear before Floor 18.",
		"effects": {"speed": 3},
	},
	{
		"id": "shop_megaheal",
		"name": "Suspicious Healing Draught",
		"icon": "✦",
		"color": Color(0.40, 0.92, 0.50),
		"cost": 120,
		"desc": "Restore 90 HP and +10 Max HP. Tastes like copper. The merchant won't say why.",
		"effects": {"heal": 90, "max_hp": 10},
	},
	{
		"id": "shop_combat_brew",
		"name": "Berserker's Brew",
		"icon": "⚔",
		"color": Color(0.78, 0.28, 0.18),
		"cost": 130,
		"desc": "+12 Attack, +2 Speed. The aftertaste lingers. So does the aggression.",
		"effects": {"attack": 12, "speed": 2},
	},
	{
		"id": "shop_tower_shield",
		"name": "Surplus Tower Shield",
		"icon": "🛡",
		"color": Color(0.55, 0.65, 0.95),
		"cost": 140,
		"desc": "+6 Armor, +25 Max HP. Heavy. Reassuringly so. The previous owner could not be reached for comment.",
		"effects": {"defense": 6, "max_hp": 25},
	},
	{
		"id": "shop_publicity_packet",
		"name": "Publicity Packet",
		"icon": "★",
		"color": Color(0.96, 0.78, 0.18),
		"cost": 50,
		"desc": "+60 Audience favor. Pre-printed merchandise. The crowd does love a sellout.",
		"effects": {"audience": 60},
	},
	{
		"id": "shop_titan_tonic",
		"name": "Titan's Tonic",
		"icon": "❤",
		"color": Color(0.30, 0.84, 0.30),
		"cost": 180,
		"desc": "+40 Max HP and heal to full. The dungeon files an objection. Ignored.",
		"effects": {"max_hp": 40, "full_heal": 1},
	},
	{
		"id": "shop_warpaint",
		"name": "Branded Warpaint",
		"icon": "✦",
		"color": Color(0.95, 0.32, 0.62),
		"cost": 100,
		"desc": "+5 Attack, +5 Defense, +25 Audience. Sponsored by 'Nobody Important'.",
		"effects": {"attack": 5, "defense": 5, "audience": 25},
	},
]


static func slate(rng: RandomNumberGenerator) -> Array[Dictionary]:
	## Return SLATE_SIZE distinct items chosen randomly from the inventory.
	## Caller-provided rng keeps this deterministic in tests / per-run seeds.
	var pool: Array[Dictionary] = INVENTORY.duplicate()
	# Fisher-Yates shuffle via rng — Array.shuffle uses the global seed, which
	# breaks determinism for the per-run rng pattern used elsewhere.
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[Dictionary] = []
	for k: int in range(min(SLATE_SIZE, pool.size())):
		out.append(pool[k])
	return out


static func get_item(id: String) -> Dictionary:
	for it: Dictionary in INVENTORY:
		if String(it.get("id", "")) == id:
			return it
	return {}


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
