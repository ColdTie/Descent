class_name Sponsors
## Run 20: DCC reality-show sponsor offers.
##
## In Dungeon Crawler Carl, weird alien corporations sponsor crawlers in
## exchange for advertising — they hand out gifts that are sometimes pure
## boons, sometimes trade-offs with strings attached. We surface this every
## time the player's audience favor crosses a threshold: a three-card
## "sponsor gift" pick screen, modelled on LootScreen / LevelUp.
##
## Pure data + math. No autoload references, no Node ops — safe to test in
## --script mode.

const SPONSOR_THRESHOLD: int = 200

const POOL: Array[Dictionary] = [
	{
		"id": "hyperion_drink",
		"sponsor": "Hyperion Drink-It-All",
		"icon": "✦",
		"name": "Sponsorship Hydration Pack",
		"color": Color(0.30, 0.78, 0.96),
		"desc": "+15 Max HP and heal 30. The label says \"REFRESHING\". It is lying.",
		"effects": {"max_hp": 15, "heal": 30},
	},
	{
		"id": "big_mikes_meat",
		"sponsor": "BIG MIKE'S MEAT EMPORIUM",
		"icon": "⚔",
		"name": "Endorsement Cleaver",
		"color": Color(0.92, 0.30, 0.18),
		"desc": "+12 Attack, -10 Max HP. Big Mike believes in confidence over caution.",
		"effects": {"attack": 12, "max_hp": -10},
	},
	{
		"id": "iron_tassel",
		"sponsor": "Iron Tassel Hardware",
		"icon": "🛡",
		"name": "Branded Plating",
		"color": Color(0.42, 0.68, 1.00),
		"desc": "+5 Armor. \"BRAND VISIBILITY\" is etched across your chest. Loudly.",
		"effects": {"defense": 5},
	},
	{
		"id": "spectral_cola",
		"sponsor": "Spectral Cola Corp.",
		"icon": "⚡",
		"name": "Spectral Sugar Rush",
		"color": Color(0.95, 0.78, 0.10),
		"desc": "+6 Speed and +6 Attack. The crash will come later. It always does.",
		"effects": {"attack": 6, "speed": 6},
	},
	{
		"id": "bopca_insurance",
		"sponsor": "Bopca Insurance & Mortuary",
		"icon": "❤",
		"name": "Pre-Paid Funeral Plan",
		"color": Color(0.28, 0.86, 0.40),
		"desc": "+30 Max HP. Bopca cares about your continued ad-impressions.",
		"effects": {"max_hp": 30, "heal": 30},
	},
	{
		"id": "gofundit",
		"sponsor": "GoFundIt Toaster Co.",
		"icon": "★",
		"name": "Toaster Endorsement Deal",
		"color": Color(0.96, 0.60, 0.18),
		"desc": "+75 Audience favor. No stats. Pure brand exposure. The crowd loves a sellout.",
		"effects": {"audience": 75},
	},
	{
		"id": "rays_pizza",
		"sponsor": "Ray's Pizza Tactics",
		"icon": "✚",
		"name": "Combat Slice",
		"color": Color(0.95, 0.40, 0.18),
		"desc": "Restore 60 HP now. Ray believes pizza solves most tactical problems.",
		"effects": {"heal": 60},
	},
	{
		"id": "quantec_pet",
		"sponsor": "QuanTec Pet Supplies",
		"icon": "✦",
		"name": "Princess Donut Endorsement",
		"color": Color(0.96, 0.72, 0.96),
		"desc": "+8 Attack, +20 Max HP. The cat insisted on signing this one personally.",
		"effects": {"attack": 8, "max_hp": 20, "heal": 20},
	},
	{
		"id": "rumnoir_rotgut",
		"sponsor": "RumNoir Rotgut Whiskey",
		"icon": "⚔",
		"name": "Liquid Courage",
		"color": Color(0.78, 0.42, 0.10),
		"desc": "+14 Attack, -3 Armor. The label warns of \"poor decision-making\". Accurate.",
		"effects": {"attack": 14, "defense": -3},
	},
	{
		"id": "exitpit_adv",
		"sponsor": "ExitPit Adventures, Ltd.",
		"icon": "🛡",
		"name": "Branded Tower Shield",
		"color": Color(0.62, 0.58, 1.00),
		"desc": "+7 Armor, -2 Speed. Heavy. Slow. Reassuringly thick.",
		"effects": {"defense": 7, "speed": -2},
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
