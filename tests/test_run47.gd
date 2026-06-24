## Run 47 tests: Stun status effect + Concussive Slam ability.
##
## Stun is the 8th status type (after Run 46's bleed). It's `skips_turn:
## true` without an armor mod — distinct from `frozen` (which carries the
## same skip flag AND -2 armor) so a melee tempo strike can lock a turn
## without the ranged-spell softening side-effect. Engine integration
## piggybacks on the existing `enemy_ai_action` gate that already bailed
## out for frozen enemies: a parallel `is_combatant_stunned` helper joins
## the check via `or`, so a stunned enemy's AI turn is silently consumed.
##
## Concussive Slam is the Brawler's class-unique unlock — the first card
## the Brawler sees at level 2 (mirrors the Run-46 idiom that put
## eviscerate at the head of the rogue list). 14 base damage + 1-turn
## stun reads as "the stun is the point" — modest enough that the player
## picks it for the control effect, not the raw number.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun47


# ── StatusEffect.stunned factory ──────────────────────────────────────────

func test_stunned_default_factory_shape() -> void:
	## Default 1-turn stun. Fields: id="stunned", display name "Stunned",
	## skips_turn=true, no DPT or armor change (the skip IS the cost).
	var e: Dictionary = StatusEffect.stunned()
	assert_eq(String(e.get("id", "")), "stunned", "id is stunned")
	assert_eq(String(e.get("name", "")), "Stunned", "name is Stunned")
	assert_eq(int(e.get("duration", 0)), 1, "default 1 turn")
	assert_eq(int(e.get("damage_per_turn", 0)), 0, "no DPT")
	assert_eq(int(e.get("armor_mod", 0)), 0,
		"no armor change (distinct from frozen's -2)")
	assert_true(bool(e.get("skips_turn", false)),
		"skips_turn flag is the engine gate")


func test_stunned_custom_duration_carries() -> void:
	## A 2-turn stun (a future heavier ability) carries through the factory.
	var e: Dictionary = StatusEffect.stunned(2)
	assert_eq(int(e.get("duration", 0)), 2, "custom duration carries")


func test_stunned_negative_duration_clamps_to_zero() -> void:
	## Defensive: a caller passing -1 (hand-edited save corruption, etc.)
	## clamps to 0. A stun with negative duration would expire on the
	## NEXT tick anyway, but clamping keeps the dict shape predictable.
	var e: Dictionary = StatusEffect.stunned(-3)
	assert_eq(int(e.get("duration", 0)), 0,
		"negative duration clamps to 0")


func test_stunned_zero_duration_allowed() -> void:
	## 0 duration is a valid edge case — apply_status takes it, and the
	## next tick_statuses call expires it before the AI gate sees it.
	var e: Dictionary = StatusEffect.stunned(0)
	assert_eq(int(e.get("duration", 0)), 0, "0 duration carries")
	assert_true(bool(e.get("skips_turn", false)),
		"skip flag still present even with 0 duration")


# ── HUD short_code / display_name / summarize ─────────────────────────────

func test_stunned_short_code() -> void:
	## The compact above-the-sprite label reads `[STN 1]`. Short code via
	## the shared SHORT_CODES dict so a future rename only touches one
	## constant.
	var e: Dictionary = StatusEffect.stunned()
	assert_eq(StatusEffect.short_code(e), "STN",
		"stunned short code is STN")


func test_stunned_display_name() -> void:
	## Detail panel reads "Stunned" — past-tense participle matches the
	## Run-35 idiom for the other states (Burning / Frozen / Poisoned).
	var e: Dictionary = StatusEffect.stunned()
	assert_eq(StatusEffect.display_name(e), "Stunned",
		"stunned display name is Stunned")


func test_stunned_summarize_includes_skip_turn() -> void:
	## Summary line carries duration + "skip turn" — stun has no DPT and
	## no armor mod, so without the skip-turn segment the player couldn't
	## tell from the panel what the effect actually does.
	var e: Dictionary = StatusEffect.stunned(1)
	var s: String = StatusEffect.summarize(e)
	assert_true(s.contains("Stunned"), "summary names the effect")
	assert_true(s.contains("1t"), "summary carries duration")
	assert_true(s.contains("skip turn"),
		"summary surfaces the skip cost (no DPT/armor to display)")
	assert_true(not s.contains("/turn"),
		"no spurious dpt (the /turn suffix would be misleading)")


func test_stunned_summarize_no_armor_mod() -> void:
	## Stun (unlike frozen) does NOT carry an armor mod. The summary must
	## not show "armor" — a regression here would imply the factory leaked
	## a frozen-style debuff onto the stun payload.
	var e: Dictionary = StatusEffect.stunned(1)
	var s: String = StatusEffect.summarize(e)
	assert_true(not s.contains("armor"),
		"no armor suffix (stun is pure tempo, not softening)")


func test_stunned_stack_collapses_duplicates() -> void:
	## Two stuns on the same target collapse to one row. Duration is the
	## MAX of the group (matches the Run-35 stack() contract — re-stunning
	## doesn't chain into multi-turn lockdowns).
	var a: Dictionary = StatusEffect.stunned(1)
	var b: Dictionary = StatusEffect.stunned(2)
	var input_arr: Array = [a, b]
	var stacked: Array[Dictionary] = StatusEffect.stack(input_arr)
	assert_eq(stacked.size(), 1, "two stuns collapse to one row")
	assert_eq(int(stacked[0].get("stacks", 1)), 2, "stack count = 2")
	assert_eq(int(stacked[0].get("duration", 0)), 2,
		"duration is the longer of the two (1 vs 2)")
	assert_true(bool(stacked[0].get("skips_turn", false)),
		"skip flag survives the collapse")


# ── Concussive Slam ability schema ────────────────────────────────────────

func test_concussive_slam_in_defs() -> void:
	## The ability must be registered for the Brawler's class-unlock pool
	## to reference it, and for the BattleScene apply_stunned branch to
	## find its stun_duration field.
	assert_true(Abilities.DATA.has("concussive_slam"),
		"concussive_slam is in Abilities.DATA")


func test_concussive_slam_schema_shape() -> void:
	## Required fields for a status-applying single-enemy attack:
	## type=attack, target=single_enemy, range=1, base_damage>0,
	## applies_stunned=true with stun_duration.
	var d: Dictionary = Abilities.DATA["concussive_slam"]
	assert_eq(String(d.get("type", "")), "attack", "type is attack")
	assert_eq(String(d.get("target", "")), "single_enemy",
		"target is single_enemy")
	assert_eq(int(d.get("range", 0)), 1, "melee range")
	assert_true(int(d.get("base_damage", 0)) > 0,
		"direct damage > 0")
	assert_true(bool(d.get("applies_stunned", false)),
		"applies_stunned flag present")
	assert_true(int(d.get("stun_duration", 0)) > 0,
		"stun_duration > 0")


func test_concussive_slam_in_brawler_unlocks() -> void:
	## Brawler's CLASS_UNLOCKS list must include concussive_slam FIRST
	## (the class-unique unlock, mirroring the Run-21 / Run-46 idiom for
	## the other classes). shield_bash stays as the secondary fallback.
	var script: GDScript = load("res://scenes/LevelUp.gd")
	var class_unlocks: Dictionary = script.CLASS_UNLOCKS
	var brawler_unlocks: Array = class_unlocks.get("brawler", [])
	assert_true(brawler_unlocks.has("concussive_slam"),
		"concussive_slam in brawler unlocks")
	assert_eq(String(brawler_unlocks[0]), "concussive_slam",
		"concussive_slam is first — class-unique priority")
	assert_true(brawler_unlocks.has("shield_bash"),
		"shield_bash kept as secondary fallback")


func test_concussive_slam_cost_and_charges() -> void:
	## Cost + charges keep concussive_slam as a mid-cycle pick: 2 charges,
	## 3-turn cooldown, 50 xp. Matches the eviscerate tempo cost so the
	## cross-class pool reads consistently.
	var d: Dictionary = Abilities.DATA["concussive_slam"]
	assert_eq(int(d.get("max_charges", 0)), 2, "2 charges")
	assert_eq(int(d.get("cooldown_turns", 0)), 3, "3-turn cooldown")
	assert_eq(int(d.get("xp_cost", 0)), 50, "50 xp unlock cost")
	# Stun is the headline — direct damage is deliberately modest (14)
	# so the player picks the card for the control, not the number.
	assert_true(int(d.get("base_damage", 0)) <= 18,
		"direct damage is modest (stun is the headline)")


# ── BattleEngine integration ──────────────────────────────────────────────

func test_engine_is_combatant_stunned_helper() -> void:
	## Parallels is_combatant_frozen — single-pass scan of status_effects
	## for an entry with id="stunned". Returns true when the effect is on.
	var engine: BattleEngine = BattleEngine.new()
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	assert_true(not engine.is_combatant_stunned(c),
		"no statuses -> not stunned")
	c.apply_status(StatusEffect.stunned(1))
	assert_true(engine.is_combatant_stunned(c),
		"with stun -> reports stunned")


func test_engine_stun_does_not_register_as_frozen() -> void:
	## The two helpers must not cross-fire — a stunned target is not
	## frozen and vice versa. Keeps the HUD / quips / future cure-effects
	## able to address each effect distinctly.
	var engine: BattleEngine = BattleEngine.new()
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.stunned(1))
	assert_true(not engine.is_combatant_frozen(c),
		"stunned does not register as frozen")
	var c2: Combatant = Combatant.new("u", "Other",
		Combatant.Faction.ENEMY, 50, 10)
	c2.apply_status(StatusEffect.frozen(2))
	assert_true(not engine.is_combatant_stunned(c2),
		"frozen does not register as stunned")


# ── End-to-end via Combatant.tick_statuses ────────────────────────────────

func test_e2e_stun_expires_after_ticks() -> void:
	## Default 1-turn stun should expire after exactly one tick. The
	## engine's AI gate then sees a clean status list on the following
	## turn. No HP damage during the lifetime of the effect.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.stunned(1))
	assert_eq(c.status_effects.size(), 1, "stun applied")
	assert_eq(c.hp, 50, "no damage on apply")
	var dmg: int = c.tick_statuses()
	assert_eq(dmg, 0, "no damage from stun tick")
	assert_eq(c.hp, 50, "HP unchanged")
	assert_eq(c.status_effects.size(), 0,
		"stun expired after the single tick")


func test_e2e_stun_two_turn_persists() -> void:
	## A 2-turn stun (a future heavier ability) survives one tick and
	## expires on the second. Decrement happens in the tick loop, mirrors
	## the existing burning/frozen lifecycle.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.stunned(2))
	c.tick_statuses()
	assert_eq(c.status_effects.size(), 1,
		"2-turn stun survives the first tick")
	assert_eq(int(c.status_effects[0].get("duration", 0)), 1,
		"duration decremented to 1")
	c.tick_statuses()
	assert_eq(c.status_effects.size(), 0,
		"2-turn stun expires after the second tick")


func test_e2e_stun_does_not_consume_mana_shield() -> void:
	## Stun is a status, not damage — applying it must not drain the
	## target's Mana Shield (Run 21 absorb pool). Regression guard: a
	## defensive caller routing the stun through take_damage by mistake
	## would silently eat shield charges; routing through apply_status
	## avoids that.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.mana_shield(40, 10))
	c.apply_status(StatusEffect.stunned(1))
	# Both effects should be present pre-tick.
	var shield_pool_pre: int = int(c.status_effects[0].get("absorb_remaining", 0))
	assert_eq(shield_pool_pre, 40,
		"mana shield untouched by stun apply")
