class_name StatusEffect
## Helpers for creating status effect dictionaries

static func burning(duration: int = 3, dpt: int = 5) -> Dictionary:
	return {"id": "burning", "name": "Burning", "duration": duration, "damage_per_turn": dpt, "armor_mod": 0}

static func frozen(duration: int = 2) -> Dictionary:
	return {"id": "frozen", "name": "Frozen", "duration": duration, "damage_per_turn": 0, "armor_mod": -2, "skips_turn": true}

static func vanished(multiplier: float = 3.0) -> Dictionary:
	return {"id": "vanished", "name": "Vanished", "duration": 3, "damage_per_turn": 0, "armor_mod": 0, "damage_multiplier": multiplier}

static func fortified(duration: int = 2, armor_bonus: int = 3) -> Dictionary:
	return {"id": "fortified", "name": "Fortified", "duration": duration, "damage_per_turn": 0, "armor_mod": armor_bonus}

static func poisoned(duration: int = 4, dpt: int = 3) -> Dictionary:
	return {"id": "poisoned", "name": "Poisoned", "duration": duration, "damage_per_turn": dpt, "armor_mod": 0}

## Run 46: percent-of-max-HP DoT. Distinct from `burning`/`poisoned` (flat
## per-tick) — bleed scales with the target's hit-point pool, so it punishes
## tanky enemies (a 200-HP boss bleeds for 16/turn at the default 8%) while
## staying mostly-flavor on a 10-HP rat (floor of 1 per turn). The dpt is
## computed at apply-time so it reads the target's max_hp once and locks the
## tick math — a future Boss Phase 3 max_hp grant doesn't retroactively
## accelerate an in-flight bleed. Bypasses armor via `tick_statuses`'s direct
## HP drain (same path burning/poisoned use today).
##
## Stacks with itself: two 8% applications run as 16% per turn (the existing
## `stack()` summer sums `damage_per_turn`, so the player's "stack bleed"
## strategy compounds the way the HUD shows it).
##
## Floor of 1 per turn even when `target_max_hp * pct_per_turn / 100` rounds
## to 0 — a bleed that ticks for 0 damage is just a typo. Negative inputs
## clamp to 0 / 1 so a defensive caller can't accidentally over-damage.
static func bleed(duration: int = 3, target_max_hp: int = 0, pct_per_turn: int = 8) -> Dictionary:
	var dur: int = max(0, duration)
	var max_hp_clamped: int = max(0, target_max_hp)
	var pct: int = max(0, pct_per_turn)
	var dpt: int = max(1, int(max_hp_clamped * pct / 100))
	return {"id": "bleed", "name": "Bleeding", "duration": dur,
		"damage_per_turn": dpt, "armor_mod": 0,
		"bleed_pct": pct}

## Run 21: Arcanist barrier. Holds a damage pool; Combatant.take_damage() drains
## it BEFORE armor is applied (and before HP). When the pool hits 0 the effect
## expires immediately. Long nominal duration is intentional — it only ends
## when consumed or, defensively, after `duration` of the caster's turns.
static func mana_shield(absorb: int = 40, duration: int = 10) -> Dictionary:
	return {"id": "mana_shield", "name": "Mana Shield", "duration": duration,
		"damage_per_turn": 0, "armor_mod": 0, "absorb_remaining": absorb,
		"absorb_max": absorb}

# ── Run 35: HUD-friendly summary + stacking ──────────────────────────────────
#
# Single source of truth for how each effect renders. BattleScene's compact
# above-the-sprite label uses `short_code()`; the new hero status detail panel
# uses `display_name()` + `summarize()`. Stacking collapses duplicates so a
# poison applied twice reads `Poisoned x2` instead of two separate rows that
# can never tell the player how many turns are actually left.

const SHORT_CODES: Dictionary = {
	"burning": "BRN",
	"frozen": "FRZ",
	"poisoned": "PSN",
	"fortified": "DEF",
	"vanished": "HID",
	"mana_shield": "SHD",
	"bleed": "BLD",
}

const DISPLAY_NAMES: Dictionary = {
	"burning": "Burning",
	"frozen": "Frozen",
	"poisoned": "Poisoned",
	"fortified": "Fortified",
	"vanished": "Vanished",
	"mana_shield": "Mana Shield",
	"bleed": "Bleeding",
}

static func short_code(eff: Dictionary) -> String:
	## Three-letter HUD code. Falls back to the id (upper-cased, truncated)
	## so a future effect renders something instead of a blank bracket.
	var id: String = String(eff.get("id", ""))
	if SHORT_CODES.has(id):
		return String(SHORT_CODES[id])
	return id.substr(0, 3).to_upper() if id != "" else "???"

static func display_name(eff: Dictionary) -> String:
	## Long-form name for the detail panel. Falls back to the dict's
	## "name" field, then to a title-cased id.
	var id: String = String(eff.get("id", ""))
	if DISPLAY_NAMES.has(id):
		return String(DISPLAY_NAMES[id])
	var nm: String = String(eff.get("name", ""))
	if nm != "":
		return nm
	return id.capitalize() if id != "" else "Unknown"

static func summarize(eff: Dictionary) -> String:
	## Detail-panel line. Always carries duration in turns; appends DPT
	## or armor mod when non-zero so the player can see what the effect
	## is actually doing this turn. Mana Shield gets the absorb pool
	## instead of a DPT (which is always 0 by definition).
	var dur: int = int(eff.get("duration", 0))
	var parts: Array[String] = [display_name(eff), "%dt" % dur]
	var id: String = String(eff.get("id", ""))
	if id == "mana_shield":
		parts.append("%d absorb" % int(eff.get("absorb_remaining", 0)))
	else:
		var dpt: int = int(eff.get("damage_per_turn", 0))
		if dpt > 0:
			parts.append("%d/turn" % dpt)
		var armor_mod: int = int(eff.get("armor_mod", 0))
		if armor_mod > 0:
			parts.append("+%d armor" % armor_mod)
		elif armor_mod < 0:
			parts.append("%d armor" % armor_mod)
	return " · ".join(parts)

static func stack(effects: Array) -> Array[Dictionary]:
	## Collapse duplicates by id into one row each. `stacks` is the count;
	## `duration` is the LONGEST of the group (the player cares when the
	## debuff stops applying, and the last application sets the floor);
	## `damage_per_turn` SUMS (poison_blade re-applied twice ticks for the
	## combined DPT — that's how `tick_statuses` already pays out). Order
	## of first appearance is preserved so the HUD doesn't flicker.
	var out: Array[Dictionary] = []
	var index_by_id: Dictionary = {}
	for raw: Variant in effects:
		if not (raw is Dictionary):
			continue
		var eff: Dictionary = raw as Dictionary
		var id: String = String(eff.get("id", ""))
		if id == "":
			continue
		if index_by_id.has(id):
			var idx: int = int(index_by_id[id])
			var existing: Dictionary = out[idx]
			existing["stacks"] = int(existing.get("stacks", 1)) + 1
			existing["duration"] = max(int(existing.get("duration", 0)),
				int(eff.get("duration", 0)))
			existing["damage_per_turn"] = int(existing.get("damage_per_turn", 0)) \
				+ int(eff.get("damage_per_turn", 0))
			existing["armor_mod"] = int(existing.get("armor_mod", 0)) \
				+ int(eff.get("armor_mod", 0))
			if eff.has("absorb_remaining"):
				existing["absorb_remaining"] = int(existing.get("absorb_remaining", 0)) \
					+ int(eff.get("absorb_remaining", 0))
			out[idx] = existing
		else:
			var copy: Dictionary = eff.duplicate(true)
			copy["stacks"] = 1
			out.append(copy)
			index_by_id[id] = out.size() - 1
	return out
