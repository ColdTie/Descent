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

## Run 48: vulnerable — debuff that AMPLIFIES incoming damage. Distinct from
## the existing six debuffs because it doesn't deal damage, doesn't change
## armor, and doesn't lock a turn — it makes the next strike (or chain of
## strikes within `duration`) cost the target more. Pairs naturally with the
## Arcanist's burst pattern: frost_nova (lock down) → arcane_sunder (apply
## vulnerable) → fireball (lands at +50%) → fireball (still +50% while the
## status persists).
##
## `damage_taken_mod` is a float multiplier on RAW damage, read inside
## `BattleEngine._calculate_damage` against the target's status list. Floored
## by `max(1, raw)` at the return so a 0-damage hit can't sneak past — same
## guarantee the existing vanished multiplier carries.
##
## Engine integration is a target-side mirror of the attacker-side vanished
## scan: one short loop, MAX of any present `damage_taken_mod` (so two
## stacks don't multiply to 2.25× — restacking refreshes the duration via
## `stack()` MAX but does not snowball the multiplier).
##
## Default amp = +50% (matches the design note in the Run-47 audit's "Up
## Next" item #3). Default duration = 2 turns so a single sunder leaves
## room for one big follow-up plus a same-turn AoE without becoming a
## perma-debuff. The factory clamps negative inputs (a hand-edited save
## can't park a -50% mod that would heal the target on hit; min cap is 1.0).
static func vulnerable(duration: int = 2, amp_pct: int = 50) -> Dictionary:
	var dur: int = max(0, duration)
	var pct: int = max(0, amp_pct)
	return {"id": "vulnerable", "name": "Vulnerable", "duration": dur,
		"damage_per_turn": 0, "armor_mod": 0,
		"damage_taken_pct": pct,
		"damage_taken_mod": 1.0 + float(pct) / 100.0}

## Run 47: stun = skip the next turn. Mirrors `frozen`'s `skips_turn: true`
## payload but without the armor debuff — frozen is a ranged-spell control
## that locks the target down AND softens them up; stun is a melee impact
## that only steals tempo. Default 1-turn duration so a single Concussive
## Slam reads as "they lose one action," matching the player's expectation
## from the Brawler shield_bash idiom. The engine integration is zero-edit:
## `is_combatant_stunned` parallels `is_combatant_frozen`, and the AI gate
## checks both.
##
## Stacks with itself via the existing `stack()` collapser (the `duration`
## summer takes MAX), so re-stunning a target that's already stunned does
## NOT chain into multi-turn lockdowns — the longer of the two durations
## wins. That keeps stun from spiraling into a perma-CC strategy.
static func stunned(duration: int = 1) -> Dictionary:
	var dur: int = max(0, duration)
	return {"id": "stunned", "name": "Stunned", "duration": dur,
		"damage_per_turn": 0, "armor_mod": 0, "skips_turn": true}

## Run 21: Arcanist barrier. Holds a damage pool; Combatant.take_damage() drains
## it BEFORE armor is applied (and before HP). When the pool hits 0 the effect
## expires immediately. Long nominal duration is intentional — it only ends
## when consumed or, defensively, after `duration` of the caster's turns.
static func mana_shield(absorb: int = 40, duration: int = 10) -> Dictionary:
	return {"id": "mana_shield", "name": "Mana Shield", "duration": duration,
		"damage_per_turn": 0, "armor_mod": 0, "absorb_remaining": absorb,
		"absorb_max": absorb}

## Run 49: regenerating — the 10th status effect, and the first POSITIVE
## per-turn ticker. Distinct from `mana_shield` (an absorb pool consumed BEFORE
## armor, not a heal) and from every existing DoT (which subtract HP). Heals
## the carrier for `hpt` each turn via `Combatant.tick_statuses`, capped by
## `max_hp` so a wounded carrier patches up but a full-HP carrier wastes the
## tick (the `heal()` helper already clamps to `max_hp - hp`).
##
## Fills the Brawler's missing sustain niche — their existing kit (taunt /
## shield_bash / concussive_slam / power_strike / basic_attack) is all damage
## or tempo, with no way to recover HP mid-battle. Iron Resolve (the new
## ability) wraps regenerating into a 3-turn self-buff so the Brawler can
## wade into a swarm and patch up without leaving the engagement.
##
## Stacks with itself via the existing `stack()` summer (heal_per_turn sums
## like damage_per_turn does) — re-applying mid-buff doubles the per-tick
## heal for the longer of the two durations. That mirrors poison-blade's
## DoT compounding and keeps the player's "stack the buff" expectation
## consistent across positive and negative tickers.
##
## Defensive: negative duration clamps to 0, negative hpt clamps to 0 (a
## hand-edited save can't park a -8/turn regen that would secretly drain
## HP — the negative would silently invert the heal). Stored as
## `heal_per_turn` rather than a negative `damage_per_turn` precisely so
## the engine integration stays additive (no risk of a future code path
## reading damage_per_turn and accidentally clipping the heal through
## armor or status arithmetic).
static func regenerating(duration: int = 3, hpt: int = 6) -> Dictionary:
	var dur: int = max(0, duration)
	var heal_amt: int = max(0, hpt)
	return {"id": "regenerating", "name": "Regenerating", "duration": dur,
		"damage_per_turn": 0, "armor_mod": 0,
		"heal_per_turn": heal_amt}

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
	"stunned": "STN",
	"vulnerable": "VLN",
	"regenerating": "REG",
}

const DISPLAY_NAMES: Dictionary = {
	"burning": "Burning",
	"frozen": "Frozen",
	"poisoned": "Poisoned",
	"fortified": "Fortified",
	"vanished": "Vanished",
	"mana_shield": "Mana Shield",
	"bleed": "Bleeding",
	"stunned": "Stunned",
	"vulnerable": "Vulnerable",
	"regenerating": "Regenerating",
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
		# Run 47: stun (and any future skips_turn effect) carries no dpt
		# and no armor mod, so without this surface the summary would
		# read "Stunned · 1t" — accurate but the player can't tell what
		# the effect does. The "skip turn" segment makes the cost legible.
		if bool(eff.get("skips_turn", false)):
			parts.append("skip turn")
		# Run 48: vulnerable carries no dpt and no armor mod either; surface
		# the amp percent so the detail panel reads "Vulnerable · 2t · +50%
		# taken" instead of the inscrutable "Vulnerable · 2t". The pct is
		# read from `damage_taken_pct` (the integer field stashed at
		# apply-time) so the line stays clean whatever rounding the
		# multiplier would imply.
		var taken_pct: int = int(eff.get("damage_taken_pct", 0))
		if taken_pct > 0:
			parts.append("+%d%% taken" % taken_pct)
		# Run 49: regenerating — surface the per-turn heal so the detail
		# panel reads "Regenerating · 3t · +6 HP/turn" instead of the
		# inscrutable "Regenerating · 3t". Separate "+/turn" suffix from
		# the DoT line above ("6/turn") so the player can't confuse a
		# heal with a tick of damage.
		var hpt: int = int(eff.get("heal_per_turn", 0))
		if hpt > 0:
			parts.append("+%d HP/turn" % hpt)
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
			# Run 48: vulnerable doesn't sum or snowball — re-applying refreshes
			# the duration (via the MAX above) and the multiplier picks the
			# stronger of the two stacks. Two +50% stacks stay at 1.5× rather
			# than compounding to 2.25×. damage_taken_pct mirrors for the HUD.
			if eff.has("damage_taken_mod"):
				existing["damage_taken_mod"] = max(
					float(existing.get("damage_taken_mod", 1.0)),
					float(eff.get("damage_taken_mod", 1.0)))
			if eff.has("damage_taken_pct"):
				existing["damage_taken_pct"] = max(
					int(existing.get("damage_taken_pct", 0)),
					int(eff.get("damage_taken_pct", 0)))
			# Run 49: regenerating SUMS heal_per_turn (mirroring the existing
			# damage_per_turn summer). Re-applying mid-buff doubles the
			# per-tick heal — consistent with how poison_blade's DoT
			# compounds, and the player's expectation that "stacking the
			# buff is good." The duration MAX above means the longer of
			# the two stacks wins, so a refresh-late doesn't shorten the
			# window.
			if eff.has("heal_per_turn"):
				existing["heal_per_turn"] = int(existing.get("heal_per_turn", 0)) \
					+ int(eff.get("heal_per_turn", 0))
			out[idx] = existing
		else:
			var copy: Dictionary = eff.duplicate(true)
			copy["stacks"] = 1
			out.append(copy)
			index_by_id[id] = out.size() - 1
	return out
