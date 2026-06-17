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

## Run 39: third perk slot unlocks after the player's first lifetime win.
## `MAX_EQUIPPED` stays at 2 as the base cap (used by older tests / fallbacks
## when no stats are available), and `max_equipped(stats)` is the dynamic
## helper every live UI / engine path uses. Kept as constants rather than
## hardcoded so a future bump (5th slot after a hard-mode clear, etc.) is
## one-line addition here + one match arm in `max_equipped`.
const WIN_BONUS_SLOTS: int = 1
const MILESTONE_THIRD_SLOT_WINS: int = 1


static func max_equipped(stats: Variant) -> int:
	## Returns the active equip-cap given lifetime stats. Defaults to the base
	## cap when `stats` is null / not a Dictionary / missing total_wins — fail
	## closed so a hand-crafted call without context can't open a slot that
	## the player hasn't earned.
	var base: int = MAX_EQUIPPED
	if stats == null or not (stats is Dictionary):
		return base
	var wins: int = int((stats as Dictionary).get("total_wins", 0))
	if wins >= MILESTONE_THIRD_SLOT_WINS:
		return base + WIN_BONUS_SLOTS
	return base


static func third_slot_unlocked(stats: Variant) -> bool:
	## Tiny convenience predicate used by the MetaScreen to render the
	## "3RD SLOT UNLOCKED" banner without duplicating the cap math.
	return max_equipped(stats) > MAX_EQUIPPED

## Run 38: milestone-gated perk requirements.
## Each entry maps `requires.type` to a check against the player's
## MetaProgress lifetime stats. Supported types:
##   - "best_floor"          — player's deepest floor reached (lifetime)
##   - "total_wins"          — full clears banked (lifetime)
##   - "bosses_slain"        — bosses killed across all runs (lifetime)
## The numeric `count` is the threshold the stat must equal or exceed.
## Perks without a `requires` field are unlocked by default — backward
## compatible with the Run-36 entries below.

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
	# Run 38: milestone-gated perks. These force the player to engage with
	# the run loop before they're available — a depth check, a boss kill
	# count, a first clear — so the meta wallet grows alongside genuine
	# progression instead of just paying out across deaths.
	"deep_diver": {
		"id": "deep_diver",
		"name": "Deep Diver",
		"desc": "Start each run with +20 max HP (healed). The depths recognize the depths.",
		"cost": 50,
		"icon": "+",
		"requires": {"type": "best_floor", "count": 9},
	},
	"bossbane": {
		"id": "bossbane",
		"name": "Bossbane",
		"desc": "+2 attack at run start. Three bosses ago, that was a vague threat.",
		"cost": 55,
		"icon": "X",
		"requires": {"type": "bosses_slain", "count": 3},
	},
	"steady_step": {
		"id": "steady_step",
		"name": "Steady Step",
		"desc": "+5 max HP and +1 speed. Small numbers, compound.",
		"cost": 40,
		"icon": ">",
	},
	"war_veteran": {
		"id": "war_veteran",
		"name": "War Veteran",
		"desc": "Begin every run at hero level 3 with the XP banked. Replaces Seasoned if both equipped.",
		"cost": 65,
		"icon": "*",
		"requires": {"type": "total_wins", "count": 1},
	},
	"champions_bond": {
		"id": "champions_bond",
		"name": "Champion's Bond",
		"desc": "+15 max HP, +1 attack, +1 defense, +25 gold. The dungeon's least subtle bribe.",
		"cost": 80,
		"icon": "*",
		"requires": {"type": "total_wins", "count": 1},
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


## Run 38: milestone gating helpers. Pure-data; the MetaProgress autoload
## passes its own stats through `lifetime_stats` so this module stays
## Node-free and testable headlessly.

static func requirement(id: String) -> Dictionary:
	## Returns the perk's `requires` clause (`{type, count}`) or `{}` when
	## the perk has no milestone gate. Unknown ids also return `{}` so
	## callers treat them as "no gate" rather than crashing.
	if not DEFS.has(id):
		return {}
	var p: Dictionary = DEFS[id]
	var r: Variant = p.get("requires", null)
	if r == null or not (r is Dictionary):
		return {}
	return r as Dictionary


static func has_milestone(id: String) -> bool:
	return not requirement(id).is_empty()


static func is_milestone_unlocked(id: String, stats: Variant) -> bool:
	## True when the perk is either unlocked-by-default (no `requires`) or
	## the supplied lifetime `stats` dict meets the threshold. `stats` keys
	## map to requirement types (best_floor / total_wins / bosses_slain).
	## Defensive: `stats` is typed Variant so callers can pass null without
	## a hard parse error, and unknown requirement types return false so a
	## future stat type can't accidentally bypass the gate by going missing
	## from the caller — fail closed, never open.
	var req: Dictionary = requirement(id)
	if req.is_empty():
		return true
	if stats == null or not (stats is Dictionary):
		return false
	var sd: Dictionary = stats as Dictionary
	var rtype: String = String(req.get("type", ""))
	var rcount: int = int(req.get("count", 0))
	if rtype == "" or rcount <= 0:
		return true
	var actual: int = int(sd.get(rtype, 0))
	return actual >= rcount


static func requirement_text(id: String) -> String:
	## Human-readable requirement string ("Reach floor 9 (lifetime)") for
	## the MetaScreen LOCKED-by-milestone card. Returns "" when the perk
	## has no gate so the caller can branch on the empty string without an
	## extra has_milestone() call.
	var req: Dictionary = requirement(id)
	if req.is_empty():
		return ""
	var rtype: String = String(req.get("type", ""))
	var rcount: int = int(req.get("count", 0))
	match rtype:
		"best_floor":
			return "Reach floor %d in any run" % rcount
		"total_wins":
			if rcount == 1:
				return "Win a run (any class)"
			return "Win %d runs" % rcount
		"bosses_slain":
			return "Slay %d bosses (lifetime)" % rcount
		_:
			return "Locked"


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
			# Run 38 milestone-gated perks. Each one is a small stacking
			# bonus that compounds on top of the Run-36 baseline perks; the
			# milestone gate is what keeps the early loadout from sweeping
			# every category at once.
			"deep_diver":
				state.hero_max_hp += 20
				state.hero_hp = state.hero_max_hp
			"bossbane":
				var b_atk: int = int(state.hero_base_stats.get("attack", 0))
				state.hero_base_stats["attack"] = b_atk + 2
			"steady_step":
				state.hero_max_hp += 5
				state.hero_hp = state.hero_max_hp
				var s_spd: int = int(state.hero_base_stats.get("speed", 0))
				state.hero_base_stats["speed"] = s_spd + 1
			"war_veteran":
				state.hero_level = max(state.hero_level, 3)
			"champions_bond":
				state.hero_max_hp += 15
				state.hero_hp = state.hero_max_hp
				var c_atk: int = int(state.hero_base_stats.get("attack", 0))
				state.hero_base_stats["attack"] = c_atk + 1
				var c_def: int = int(state.hero_base_stats.get("defense", 0))
				state.hero_base_stats["defense"] = c_def + 1
				state.hero_gold += 25
			# `merchant_ally` is a passive discount — handled by Shop via
			# `Perks.shop_discount_pct`, not by a state mutation.
			_:
				pass
