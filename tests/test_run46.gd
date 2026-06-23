## Run 46 tests: Bleed status effect + Eviscerate ability.
##
## Bleed is the 7th status type. Distinct from burning/poisoned: its
## per-tick damage scales with the target's max_hp (8% by default), so it
## punishes tanky enemies while staying mostly-flavor on chaff. The dpt
## is computed at apply-time (the StatusEffect factory reads target.max_hp
## once) so a future Boss-Phase-2 max_hp grant can't retroactively scale
## an in-flight bleed. This suite exercises the factory + HUD helpers +
## the Eviscerate ability schema.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun46


# ── StatusEffect.bleed factory ────────────────────────────────────────────

func test_bleed_default_factory_shape() -> void:
	## Default invocation locks in: 3 turns, 8% of target max HP, id="bleed",
	## display name "Bleeding", armor_mod 0 (bypasses via tick_statuses path).
	var e: Dictionary = StatusEffect.bleed(3, 100, 8)
	assert_eq(String(e.get("id", "")), "bleed", "id is bleed")
	assert_eq(String(e.get("name", "")), "Bleeding", "name is Bleeding")
	assert_eq(int(e.get("duration", 0)), 3, "duration carries through")
	assert_eq(int(e.get("damage_per_turn", 0)), 8,
		"100 max_hp * 8% = 8 dpt")
	assert_eq(int(e.get("armor_mod", 0)), 0, "no armor change")
	assert_eq(int(e.get("bleed_pct", 0)), 8, "bleed_pct stored for HUD")


func test_bleed_dpt_scales_with_max_hp() -> void:
	## 8% of 200-HP boss = 16/turn (the tanky-target premium); 8% of a 30-HP
	## goblin = 2/turn. The percent stays the same; the absolute dpt scales.
	var boss: Dictionary = StatusEffect.bleed(3, 200, 8)
	var goblin: Dictionary = StatusEffect.bleed(3, 30, 8)
	assert_eq(int(boss.get("damage_per_turn", 0)), 16, "200 * 8% = 16")
	assert_eq(int(goblin.get("damage_per_turn", 0)), 2, "30 * 8% = 2")


func test_bleed_dpt_floor_of_one() -> void:
	## A 5-HP rat hit by an 8% bleed would mathematically tick for 0
	## (5 * 8 / 100 = 0). The factory floors at 1 so the effect always has
	## a non-zero footprint — a bleed that ticks for 0 is just a typo.
	var rat: Dictionary = StatusEffect.bleed(3, 5, 8)
	assert_eq(int(rat.get("damage_per_turn", 0)), 1,
		"floor of 1 even when pct rounds to 0")


func test_bleed_dpt_clamps_negative_inputs() -> void:
	## Defensive: negative max_hp / pct from a hand-crafted caller must clamp
	## to safe values. Negative max_hp → 0 → floored to 1. Negative pct → 0
	## → same. Neither should produce a healing-bleed dpt.
	var neg_hp: Dictionary = StatusEffect.bleed(3, -50, 8)
	var neg_pct: Dictionary = StatusEffect.bleed(3, 100, -10)
	assert_eq(int(neg_hp.get("damage_per_turn", 0)), 1,
		"negative max_hp clamps then floors to 1")
	assert_eq(int(neg_pct.get("damage_per_turn", 0)), 1,
		"negative pct clamps then floors to 1")


func test_bleed_zero_duration_allowed() -> void:
	## 0 duration is a valid edge case (the effect dies on the next tick,
	## but apply_status takes it). Just verify the factory doesn't crash
	## and the field carries through.
	var e: Dictionary = StatusEffect.bleed(0, 100, 8)
	assert_eq(int(e.get("duration", 0)), 0, "0 duration carries")


func test_bleed_negative_duration_clamps_to_zero() -> void:
	## A caller passing -1 (defensive, hand-edited save corruption, etc.)
	## must clamp to 0 — bleeding for negative turns isn't a meaningful state.
	var e: Dictionary = StatusEffect.bleed(-1, 100, 8)
	assert_eq(int(e.get("duration", 0)), 0,
		"negative duration clamps to 0")


# ── HUD short_code / display_name / summarize ─────────────────────────────

func test_bleed_short_code() -> void:
	## The compact above-the-sprite label reads `[BLD 3]` (or `[BLD 3 x2]`
	## when stacked). Short code via the shared SHORT_CODES dict so a future
	## rename only touches one constant.
	var e: Dictionary = StatusEffect.bleed(3, 100, 8)
	assert_eq(StatusEffect.short_code(e), "BLD",
		"bleed short code is BLD")


func test_bleed_display_name() -> void:
	## Detail panel reads "Bleeding" — uppercased word used as a noun
	## (matches the Run-35 idiom for the other DoTs).
	var e: Dictionary = StatusEffect.bleed(3, 100, 8)
	assert_eq(StatusEffect.display_name(e), "Bleeding",
		"bleed display name is Bleeding")


func test_bleed_summarize_includes_dpt() -> void:
	## Summary line carries duration + dpt — the format is
	## "Bleeding · 3t · 8/turn" via the existing summarize() builder, so
	## bleed inherits the same layout as poisoned/burning without new code
	## in StatusEffect.summarize itself.
	var e: Dictionary = StatusEffect.bleed(3, 100, 8)
	var s: String = StatusEffect.summarize(e)
	assert_true(s.contains("Bleeding"), "summary names the effect")
	assert_true(s.contains("3t"), "summary carries duration")
	assert_true(s.contains("8/turn"), "summary carries dpt")


func test_bleed_stack_sums_dpt() -> void:
	## Two bleeds on the same target collapse to one row with summed dpt
	## (matches the Run-35 stack() contract for damage_per_turn). Player who
	## eviscerates twice in three turns gets a 16% bleed stack.
	var a: Dictionary = StatusEffect.bleed(3, 100, 8)
	var b: Dictionary = StatusEffect.bleed(2, 100, 8)
	var input_arr: Array = [a, b]
	var stacked: Array[Dictionary] = StatusEffect.stack(input_arr)
	assert_eq(stacked.size(), 1, "two bleeds collapse to one row")
	assert_eq(int(stacked[0].get("damage_per_turn", 0)), 16,
		"dpt sums (8 + 8)")
	assert_eq(int(stacked[0].get("stacks", 1)), 2, "stack count = 2")
	assert_eq(int(stacked[0].get("duration", 0)), 3,
		"duration is the longer of the two (3 vs 2)")


# ── Eviscerate ability schema ─────────────────────────────────────────────

func test_eviscerate_in_defs() -> void:
	## The ability must be registered for the Rogue's class-unlock pool to
	## reference it, and for the BattleScene apply_bleed branch to find its
	## bleed_duration / bleed_pct fields.
	assert_true(Abilities.DATA.has("eviscerate"),
		"eviscerate is in Abilities.DATA")


func test_eviscerate_schema_shape() -> void:
	## Required fields for a status-applying single-enemy attack:
	## type=attack, target=single_enemy, range=1, base_damage>0,
	## applies_bleed=true with both bleed_duration and bleed_pct.
	var d: Dictionary = Abilities.DATA["eviscerate"]
	assert_eq(String(d.get("type", "")), "attack", "type is attack")
	assert_eq(String(d.get("target", "")), "single_enemy",
		"target is single_enemy")
	assert_eq(int(d.get("range", 0)), 1, "melee range")
	assert_true(int(d.get("base_damage", 0)) > 0, "direct damage > 0")
	assert_true(bool(d.get("applies_bleed", false)),
		"applies_bleed flag present")
	assert_true(int(d.get("bleed_duration", 0)) > 0,
		"bleed_duration > 0")
	assert_true(int(d.get("bleed_pct", 0)) > 0,
		"bleed_pct > 0")


func test_eviscerate_in_rogue_unlocks() -> void:
	## Rogue's CLASS_UNLOCKS list must include eviscerate FIRST (the
	## class-unique unlock, mirroring the Run-21 arcanist mana_shield idiom).
	var script: GDScript = load("res://scenes/LevelUp.gd")
	var class_unlocks: Dictionary = script.CLASS_UNLOCKS
	var rogue_unlocks: Array = class_unlocks.get("rogue", [])
	assert_true(rogue_unlocks.has("eviscerate"),
		"eviscerate in rogue unlocks")
	assert_eq(String(rogue_unlocks[0]), "eviscerate",
		"eviscerate is first in the list — class-unique priority")


func test_eviscerate_cost_and_charges() -> void:
	## Cost + charges keep eviscerate as a mid-cycle pick: 2 charges,
	## 3-turn cooldown, 50 xp. Verifies the tuning doesn't drift.
	var d: Dictionary = Abilities.DATA["eviscerate"]
	assert_eq(int(d.get("max_charges", 0)), 2, "2 charges")
	assert_eq(int(d.get("cooldown_turns", 0)), 3, "3-turn cooldown")
	assert_eq(int(d.get("xp_cost", 0)), 50, "50 xp unlock cost")


# ── End-to-end via Combatant.tick_statuses ────────────────────────────────

func test_e2e_bleed_ticks_damage() -> void:
	## Apply bleed via the factory, tick once, verify HP dropped by the
	## computed dpt. Uses Combatant directly (zero Node dependency) so the
	## tick path matches what BattleEngine.advance_turn calls in live combat.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.bleed(3, c.max_hp, 8))
	assert_eq(c.hp, 100, "pre-tick HP")
	var dmg: int = c.tick_statuses()
	assert_eq(dmg, 8, "first tick deals 8 (100 * 8%)")
	assert_eq(c.hp, 92, "HP drops by 8")


func test_e2e_bleed_full_duration_three_ticks() -> void:
	## Default 3-turn bleed should deal 3 ticks worth of damage and then
	## expire. After 3 ticks the effect leaves status_effects.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 200, 10)
	c.apply_status(StatusEffect.bleed(3, c.max_hp, 8))
	c.tick_statuses()  # 184
	c.tick_statuses()  # 168
	c.tick_statuses()  # 152
	assert_eq(c.hp, 200 - 3 * 16, "3 ticks at 16 each = 48 total")
	assert_eq(c.status_effects.size(), 0, "bleed expired after 3 ticks")


func test_e2e_bleed_bypasses_armor() -> void:
	## DoT path in tick_statuses subtracts directly from hp (no armor
	## check), so a heavily-armored target still takes full bleed damage.
	## Critical for the "Eviscerate punishes tanky armor builds" premise.
	var c: Combatant = Combatant.new("t", "Tank",
		Combatant.Faction.ENEMY, 100, 10)
	c.armor = 10
	c.apply_status(StatusEffect.bleed(3, c.max_hp, 8))
	c.tick_statuses()
	assert_eq(c.hp, 92,
		"bleed bypasses armor (10) — same as poisoned/burning")


func test_e2e_bleed_dpt_locked_at_apply_not_tick() -> void:
	## A boss that gains max_hp mid-bleed (Run 15 enrage grants) does NOT
	## see the bleed dpt scale up to the new max — the factory reads
	## max_hp once and locks the math. This protects the design intent
	## (bleed is committed at strike time).
	var c: Combatant = Combatant.new("t", "Boss",
		Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.bleed(3, c.max_hp, 8))
	# Simulate a Phase 2 enrage that doubles max_hp.
	c.max_hp = 200
	c.hp = 200
	c.tick_statuses()
	# Tick should still be 8 (locked at apply, not 16 from the new max).
	assert_eq(c.hp, 192,
		"bleed dpt locked at apply — not rescaled to new max_hp")


func test_e2e_bleed_stacks_compound_damage() -> void:
	## Two bleeds in flight on the same target — tick_statuses ticks them
	## independently, so the per-turn damage is the sum. Combined with the
	## stack() HUD collapse this gives the player a coherent "stack bleed"
	## strategy that reads honestly on the status row.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 200, 10)
	c.apply_status(StatusEffect.bleed(3, c.max_hp, 8))
	c.apply_status(StatusEffect.bleed(3, c.max_hp, 8))
	c.tick_statuses()
	# 2 stacks at 16/turn each = 32 total
	assert_eq(c.hp, 200 - 32,
		"two bleeds tick independently — combined 32/turn")
