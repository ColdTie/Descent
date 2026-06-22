class_name Skins
## Run 42: alt-color class skins — cosmetic unlocks tied to per-class wins.
##
## Each class ships with a default skin (always unlocked, equipped by default).
## Banking lifetime wins as that class unlocks two alt-color skins per class
## (1 win → "veteran" palette, 3 wins → "mastery" palette). The skin tints the
## live hero sprite via `Combatant.tint`, reusing the Run 32 enemy-variant
## plumbing (the same `sprite.self_modulate = c.tint` line in BattleScene
## paints both heroes and enemies).
##
## Pure data + tiny static helpers — zero Node dependency, fully testable
## headlessly. MetaProgress owns the equipped/owned state; this module owns
## DEFS, the unlock predicate, and the tint lookup.
##
## Tints are picked to read clearly against the cave's brown-orange floor
## palette and to stay distinguishable from each class's faction-ring color
## (which is a separate `_hero_class_color()` lookup in BattleScene).

# Skin requirement uses class_wins (a per-class lifetime counter MetaProgress
# bumps on every win). 0 = default skin, always unlocked. 1+ = milestone skin.
const DEFAULT_REQUIRES_CLASS_WINS: int = 0
const VETERAN_REQUIRES_CLASS_WINS: int = 1
const MASTERY_REQUIRES_CLASS_WINS: int = 3

const DEFS: Dictionary = {
	# ── Brawler ──────────────────────────────────────────────────────────
	"brawler_default": {
		"id": "brawler_default",
		"class_id": "brawler",
		"name": "Crimson Brute",
		"desc": "The Brawler's shipping look. Loud, red, unbothered.",
		"tint": Color(1.0, 1.0, 1.0),
		"requires_class_wins": DEFAULT_REQUIRES_CLASS_WINS,
	},
	"brawler_onyx": {
		"id": "brawler_onyx",
		"class_id": "brawler",
		"name": "Onyx Veteran",
		"desc": "A darkened palette earned by closing out a run as the Brawler.",
		"tint": Color(0.55, 0.55, 0.65),
		"requires_class_wins": VETERAN_REQUIRES_CLASS_WINS,
	},
	"brawler_gilded": {
		"id": "brawler_gilded",
		"class_id": "brawler",
		"name": "Gilded Champion",
		"desc": "Bronze-tinted ceremonial armor. Three Brawler clears earns the gilding.",
		"tint": Color(1.0, 0.82, 0.40),
		"requires_class_wins": MASTERY_REQUIRES_CLASS_WINS,
	},
	# ── Rogue ────────────────────────────────────────────────────────────
	"rogue_default": {
		"id": "rogue_default",
		"class_id": "rogue",
		"name": "Emerald Cutpurse",
		"desc": "The Rogue's shipping look. Quick, green, allegedly stealthy.",
		"tint": Color(1.0, 1.0, 1.0),
		"requires_class_wins": DEFAULT_REQUIRES_CLASS_WINS,
	},
	"rogue_shadow": {
		"id": "rogue_shadow",
		"class_id": "rogue",
		"name": "Shadow Walker",
		"desc": "Muted indigo — a Rogue who's left the cave alive once already.",
		"tint": Color(0.62, 0.58, 0.92),
		"requires_class_wins": VETERAN_REQUIRES_CLASS_WINS,
	},
	"rogue_crimson": {
		"id": "rogue_crimson",
		"class_id": "rogue",
		"name": "Crimson Blade",
		"desc": "Blood-red mastery palette. Earned across three Rogue runs.",
		"tint": Color(1.0, 0.42, 0.42),
		"requires_class_wins": MASTERY_REQUIRES_CLASS_WINS,
	},
	# ── Arcanist ─────────────────────────────────────────────────────────
	"arcanist_default": {
		"id": "arcanist_default",
		"class_id": "arcanist",
		"name": "Azure Adept",
		"desc": "The Arcanist's shipping look. Soft blue, very fragile.",
		"tint": Color(1.0, 1.0, 1.0),
		"requires_class_wins": DEFAULT_REQUIRES_CLASS_WINS,
	},
	"arcanist_frost": {
		"id": "arcanist_frost",
		"class_id": "arcanist",
		"name": "Frostbound Adept",
		"desc": "Pale ice-cyan robes for an Arcanist who's already cleared once.",
		"tint": Color(0.78, 0.95, 1.0),
		"requires_class_wins": VETERAN_REQUIRES_CLASS_WINS,
	},
	"arcanist_solar": {
		"id": "arcanist_solar",
		"class_id": "arcanist",
		"name": "Solar Archon",
		"desc": "Golden-orange ceremonial robes. Three Arcanist wins earns the sunburst.",
		"tint": Color(1.0, 0.80, 0.30),
		"requires_class_wins": MASTERY_REQUIRES_CLASS_WINS,
	},
}


static func get_skin(skin_id: String) -> Dictionary:
	return DEFS.get(skin_id, {})


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in DEFS.keys():
		ids.append(k)
	return ids


static func class_id_for(skin_id: String) -> String:
	## Returns the class_id this skin belongs to, or "" for unknown ids so
	## callers can branch on the empty string without a separate has() check.
	if not DEFS.has(skin_id):
		return ""
	return String(DEFS[skin_id].get("class_id", ""))


static func for_class(class_id: String) -> Array[String]:
	## Skins belonging to one class, in DEFS insertion order (default first,
	## then veteran, then mastery — matches the unlock ramp the MetaScreen
	## renders top-to-bottom).
	var out: Array[String] = []
	if class_id == "":
		return out
	for k: String in DEFS.keys():
		if String(DEFS[k].get("class_id", "")) == class_id:
			out.append(k)
	return out


static func tint_for(skin_id: String) -> Color:
	## Returns the skin's tint or WHITE for unknown ids — WHITE means "no
	## tint" in the Run-32 sprite pipeline (every paint path skips the
	## self_modulate write when c.tint == Color(1,1,1)), so an unknown id
	## degrades to a hero with no skin applied rather than a hard error.
	if not DEFS.has(skin_id):
		return Color(1.0, 1.0, 1.0)
	var raw: Variant = DEFS[skin_id].get("tint", Color(1.0, 1.0, 1.0))
	if raw is Color:
		return raw as Color
	return Color(1.0, 1.0, 1.0)


static func default_for(class_id: String) -> String:
	## The unlocked-by-default skin id for a class — used when nothing is
	## equipped (a brand-new player, or an unequip-back-to-default). Returns
	## "" for an unknown class so the caller can short-circuit on an empty
	## hero_class. The first matching id in DEFS insertion order wins, which
	## is also the natural reading order (default skin is the first card).
	if class_id == "":
		return ""
	for k: String in DEFS.keys():
		var d: Dictionary = DEFS[k]
		if String(d.get("class_id", "")) != class_id:
			continue
		if int(d.get("requires_class_wins", -1)) == DEFAULT_REQUIRES_CLASS_WINS:
			return k
	return ""


static func requires_wins(skin_id: String) -> int:
	## The class-win count required to unlock this skin. Unknown ids return a
	## sentinel > any real player count so they're treated as locked forever
	## — fail closed rather than silently unlock a typo'd id.
	if not DEFS.has(skin_id):
		return 9999
	return int(DEFS[skin_id].get("requires_class_wins", 0))


static func is_unlocked(skin_id: String, class_wins: int) -> bool:
	## True when the player has banked enough wins as the skin's class.
	## Default skins (`requires_class_wins == 0`) are always unlocked.
	## Defensive: a negative `class_wins` (a defensive caller passing -1
	## from a corrupted save) is clamped at 0, so even an absurd input can't
	## ever flip an unearned skin to unlocked.
	if not DEFS.has(skin_id):
		return false
	var need: int = int(DEFS[skin_id].get("requires_class_wins", 0))
	var have: int = max(0, class_wins)
	return have >= need


static func newly_unlocked_in_range(class_id: String, prev_class_wins: int,
		new_class_wins: int) -> Array[String]:
	## Run 44: returns the skin ids for `class_id` whose unlock threshold sits in
	## the half-open range `(prev_class_wins, new_class_wins]` — i.e. just got
	## unlocked by a win that bumped the counter. Empty when nothing crossed.
	## Negative counts are clamped at 0 so a corrupted prev value can't widen
	## the range upward. Unknown class id returns empty.
	## Used by the WinScreen banner: a player who clears as Brawler for the
	## first time gets a single "Onyx Veteran unlocked" toast; a Brawler hitting
	## their 3rd win sees the mastery skin pop.
	var out: Array[String] = []
	if class_id == "":
		return out
	var lo: int = max(0, prev_class_wins)
	var hi: int = max(0, new_class_wins)
	if hi <= lo:
		return out
	for sid: String in for_class(class_id):
		var need: int = requires_wins(sid)
		if need > lo and need <= hi:
			out.append(sid)
	return out


static func requirement_text(skin_id: String) -> String:
	## Human-readable unlock string for the MetaScreen LOCKED card. Returns
	## "" for the default skin (it has no lock) so the UI can branch on the
	## empty string without an extra has_milestone() call.
	if not DEFS.has(skin_id):
		return ""
	var need: int = int(DEFS[skin_id].get("requires_class_wins", 0))
	if need <= 0:
		return ""
	var cls_id: String = String(DEFS[skin_id].get("class_id", ""))
	var cls_name: String = cls_id.capitalize()
	if cls_id != "":
		var cls_data: Dictionary = Classes.get_class_data(cls_id)
		if not cls_data.is_empty():
			cls_name = String(cls_data.get("display_name", cls_name))
	if need == 1:
		return "Win a run as %s" % cls_name
	return "Win %d runs as %s" % [need, cls_name]
