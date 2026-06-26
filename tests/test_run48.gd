## Run 48 tests: Vulnerable status effect + Arcane Sunder ability.
##
## Vulnerable is the 9th status type (after Run 47's stun). It's the first
## debuff that AMPLIFIES incoming damage rather than dealing flat dpt,
## changing armor, or locking a turn — fills the "damage-amp" hole the
## status palette had after eight effects with no multiplier in either
## direction (vanished is the only mult, and it lives on the ATTACKER).
##
## Engine integration mirrors the attacker-side vanished scan from
## `_calculate_damage` — a single short loop over the TARGET's
## status_effects picks the MAX `damage_taken_mod` (so two stacks stay at
## the stronger of the two rather than compounding 1.5 × 1.5 → 2.25×), and
## the raw damage is multiplied before `max(1, raw)` floors the return.
##
## Arcane Sunder is the Arcanist's new class-unique unlock — the first
## card the Arcanist sees at level 2 (mirrors the Run-46 idiom that put
## eviscerate at the head of the rogue list and the Run-47 idiom for the
## brawler's concussive_slam). 12 base damage + 2-turn +50% reads as "the
## debuff is the point" — the player picks this card to amplify their
## follow-up fireball, not for the on-hit number.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun48


# ── StatusEffect.vulnerable factory ───────────────────────────────────────

func test_vulnerable_default_factory_shape() -> void:
	## Default 2-turn / +50% vulnerable. Fields: id="vulnerable", display
	## name "Vulnerable", duration=2, no DPT, no armor change,
	## damage_taken_pct=50, damage_taken_mod=1.5.
	var e: Dictionary = StatusEffect.vulnerable()
	assert_eq(String(e.get("id", "")), "vulnerable", "id is vulnerable")
	assert_eq(String(e.get("name", "")), "Vulnerable", "name is Vulnerable")
	assert_eq(int(e.get("duration", 0)), 2, "default 2 turns")
	assert_eq(int(e.get("damage_per_turn", 0)), 0, "no DPT")
	assert_eq(int(e.get("armor_mod", 0)), 0, "no armor change")
	assert_eq(int(e.get("damage_taken_pct", 0)), 50,
		"default amp is +50%")
	assert_true(abs(float(e.get("damage_taken_mod", 0.0)) - 1.5) < 0.001,
		"damage_taken_mod is 1.5 (= 1.0 + 50/100)")


func test_vulnerable_custom_amp_carries() -> void:
	## A future heavier ability could apply +100% (a 2x amp) — the factory
	## must scale linearly: pct=100 -> mod=2.0.
	var e: Dictionary = StatusEffect.vulnerable(3, 100)
	assert_eq(int(e.get("duration", 0)), 3, "custom duration carries")
	assert_eq(int(e.get("damage_taken_pct", 0)), 100, "custom amp carries")
	assert_true(abs(float(e.get("damage_taken_mod", 0.0)) - 2.0) < 0.001,
		"damage_taken_mod is 2.0 at +100%")


func test_vulnerable_negative_inputs_clamp() -> void:
	## Defensive: a save-corruption -1 amp would translate to a 0.99 mod
	## that HEALS the target on hit. Clamp the pct to 0 (mod stays at 1.0
	## = no-op) and the duration to 0.
	var e: Dictionary = StatusEffect.vulnerable(-1, -50)
	assert_eq(int(e.get("duration", 0)), 0,
		"negative duration clamps to 0")
	assert_eq(int(e.get("damage_taken_pct", 0)), 0,
		"negative amp clamps to 0%")
	assert_true(abs(float(e.get("damage_taken_mod", 0.0)) - 1.0) < 0.001,
		"clamped mod is 1.0 (no-op, can never reduce damage)")


func test_vulnerable_zero_amp_is_noop() -> void:
	## 0% amp is a valid edge case — the dict shape stays consistent
	## (factory returns a vulnerable with mod 1.0 that's effectively a
	## tracker for the duration). Engine path treats mod==1.0 as no-op
	## via the `if vuln_mod != 1.0` gate, so this matches.
	var e: Dictionary = StatusEffect.vulnerable(2, 0)
	assert_eq(int(e.get("damage_taken_pct", 0)), 0, "0% carries")
	assert_true(abs(float(e.get("damage_taken_mod", 0.0)) - 1.0) < 0.001,
		"0% amp is a literal 1.0 multiplier")


# ── HUD short_code / display_name / summarize ─────────────────────────────

func test_vulnerable_short_code() -> void:
	## The compact above-the-sprite label reads `[VLN 2]`. Short code via
	## the shared SHORT_CODES dict so a future rename only touches one
	## constant.
	var e: Dictionary = StatusEffect.vulnerable()
	assert_eq(StatusEffect.short_code(e), "VLN",
		"vulnerable short code is VLN")


func test_vulnerable_display_name() -> void:
	## Detail panel reads "Vulnerable" — matches the Run-35 idiom for the
	## other states (Burning / Frozen / Poisoned / Stunned).
	var e: Dictionary = StatusEffect.vulnerable()
	assert_eq(StatusEffect.display_name(e), "Vulnerable",
		"vulnerable display name is Vulnerable")


func test_vulnerable_summarize_includes_amp_pct() -> void:
	## Summary line carries duration + "+N% taken". Vulnerable has no DPT
	## and no armor mod, so without the amp segment the panel would read
	## "Vulnerable · 2t" and tell the player nothing about WHY they should
	## care.
	var e: Dictionary = StatusEffect.vulnerable(2, 50)
	var s: String = StatusEffect.summarize(e)
	assert_true(s.contains("Vulnerable"), "summary names the effect")
	assert_true(s.contains("2t"), "summary carries duration")
	assert_true(s.contains("+50%") and s.contains("taken"),
		"summary surfaces the +50%% taken amplifier")
	assert_true(not s.contains("/turn"),
		"no spurious dpt (the /turn suffix would be misleading)")
	assert_true(not s.contains("armor"),
		"no armor suffix (vulnerable doesn't change armor)")
	assert_true(not s.contains("skip turn"),
		"no skip-turn suffix (vulnerable doesn't lock a turn)")


func test_vulnerable_summarize_custom_amp() -> void:
	## A +100% summary line must carry "+100% taken" — not "+1% taken"
	## (a future formatting bug) or just "+100" (missing the % sign).
	var e: Dictionary = StatusEffect.vulnerable(2, 100)
	var s: String = StatusEffect.summarize(e)
	assert_true(s.contains("+100%"), "summary carries +100%%")
	assert_true(s.contains("taken"), "summary carries 'taken' label")


func test_vulnerable_stack_collapses_with_max_mod() -> void:
	## Two vulnerables on the same target collapse to one row. Duration
	## is the MAX of the group (matches the Run-35 stack() contract).
	## damage_taken_mod also takes the MAX — restacking does NOT snowball
	## (two +50% applications stay at 1.5×, not compound to 2.25×).
	var a: Dictionary = StatusEffect.vulnerable(2, 50)
	var b: Dictionary = StatusEffect.vulnerable(1, 30)
	var input_arr: Array = [a, b]
	var stacked: Array[Dictionary] = StatusEffect.stack(input_arr)
	assert_eq(stacked.size(), 1, "two vulnerables collapse to one row")
	assert_eq(int(stacked[0].get("stacks", 1)), 2, "stack count = 2")
	assert_eq(int(stacked[0].get("duration", 0)), 2,
		"duration is the longer of the two (2 vs 1)")
	assert_true(abs(float(stacked[0].get("damage_taken_mod", 0.0)) - 1.5) < 0.001,
		"damage_taken_mod is MAX (1.5 vs 1.3 -> 1.5)")
	assert_eq(int(stacked[0].get("damage_taken_pct", 0)), 50,
		"damage_taken_pct is MAX (50 vs 30 -> 50)")


func test_vulnerable_stack_weaker_then_stronger() -> void:
	## Order matters for the MAX collapser — weaker first, stronger
	## second. The collapse must still pick the stronger mod regardless
	## of which one was applied first.
	var a: Dictionary = StatusEffect.vulnerable(1, 25)
	var b: Dictionary = StatusEffect.vulnerable(3, 75)
	var input_arr: Array = [a, b]
	var stacked: Array[Dictionary] = StatusEffect.stack(input_arr)
	assert_eq(stacked.size(), 1, "two vulnerables collapse")
	assert_eq(int(stacked[0].get("duration", 0)), 3,
		"duration is the longer of the two (3 vs 1)")
	assert_eq(int(stacked[0].get("damage_taken_pct", 0)), 75,
		"pct is MAX even when applied second (75 vs 25 -> 75)")


# ── Arcane Sunder ability schema ──────────────────────────────────────────

func test_arcane_sunder_in_defs() -> void:
	## The ability must be registered for the Arcanist's class-unlock pool
	## to reference it, and for the BattleScene apply_vulnerable branch to
	## find its vuln_duration / vuln_pct fields.
	assert_true(Abilities.DATA.has("arcane_sunder"),
		"arcane_sunder is in Abilities.DATA")


func test_arcane_sunder_schema_shape() -> void:
	## Required fields for a status-applying single-enemy attack:
	## type=attack, target=single_enemy, range=2 (ranged — Arcanist),
	## base_damage>0, applies_vulnerable=true with vuln_duration + vuln_pct.
	var d: Dictionary = Abilities.DATA["arcane_sunder"]
	assert_eq(String(d.get("type", "")), "attack", "type is attack")
	assert_eq(String(d.get("target", "")), "single_enemy",
		"target is single_enemy")
	assert_eq(int(d.get("range", 0)), 2,
		"range 2 — Arcanist's standoff distance")
	assert_true(int(d.get("base_damage", 0)) > 0,
		"direct damage > 0")
	assert_true(bool(d.get("applies_vulnerable", false)),
		"applies_vulnerable flag present")
	assert_true(int(d.get("vuln_duration", 0)) > 0,
		"vuln_duration > 0")
	assert_true(int(d.get("vuln_pct", 0)) > 0,
		"vuln_pct > 0")


func test_arcane_sunder_in_arcanist_unlocks() -> void:
	## Arcanist's CLASS_UNLOCKS list must include arcane_sunder FIRST
	## (the class-unique unlock, mirroring the Run-21/46/47 idiom for the
	## other classes). mana_shield stays as the secondary class-unique
	## fallback, followed by the cross-class options.
	var script: GDScript = load("res://scenes/LevelUp.gd")
	var class_unlocks: Dictionary = script.CLASS_UNLOCKS
	var arc_unlocks: Array = class_unlocks.get("arcanist", [])
	assert_true(arc_unlocks.has("arcane_sunder"),
		"arcane_sunder in arcanist unlocks")
	assert_eq(String(arc_unlocks[0]), "arcane_sunder",
		"arcane_sunder is first — class-unique priority")
	assert_true(arc_unlocks.has("mana_shield"),
		"mana_shield kept as secondary class-unique fallback")
	assert_true(arc_unlocks.has("backstab"),
		"backstab kept as cross-class fallback")


func test_arcane_sunder_cost_and_charges() -> void:
	## Cost + charges keep arcane_sunder as a mid-cycle pick: 2 charges,
	## 3-turn cooldown, 50 xp. Matches the eviscerate / concussive_slam
	## tempo cost so the cross-class pool reads consistently. Direct
	## damage is deliberately modest (12) so the +50% amp is the headline.
	var d: Dictionary = Abilities.DATA["arcane_sunder"]
	assert_eq(int(d.get("max_charges", 0)), 2, "2 charges")
	assert_eq(int(d.get("cooldown_turns", 0)), 3, "3-turn cooldown")
	assert_eq(int(d.get("xp_cost", 0)), 50, "50 xp unlock cost")
	assert_true(int(d.get("base_damage", 0)) <= 18,
		"direct damage is modest (the debuff is the headline)")
	assert_eq(int(d.get("vuln_pct", 0)), 50,
		"default amp is +50%% (matches the Run-47 audit's roadmap spec)")
	assert_eq(int(d.get("vuln_duration", 0)), 2,
		"2-turn debuff window (covers one follow-up plus a same-turn AoE)")


# ── BattleEngine.calculate_damage integration ─────────────────────────────

func test_engine_no_vulnerable_no_amp() -> void:
	## A target without vulnerable on it sees the raw damage unchanged
	## (modulo the standard ±20% variance). Use a seeded RNG so the
	## comparison is stable.
	var engine: BattleEngine = BattleEngine.new()
	engine.rng.seed = 42
	var attacker: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	var target: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 100, 10)
	# basic_attack base_damage = 12. With variance 0.8-1.2 + atk_bonus 0,
	# the raw should land in [9, 14] (int truncation).
	var raw: int = engine._calculate_damage(attacker, target, "basic_attack")
	assert_true(raw >= 9 and raw <= 14,
		"no-vulnerable raw lands in the expected variance band")


func test_engine_vulnerable_amps_damage() -> void:
	## A target with the default +50% vulnerable on it sees the raw
	## damage multiplied by 1.5. Seeded RNG keeps the variance band
	## reproducible — we then compare the amp'd raw against the
	## unamped raw at the SAME RNG seed.
	var attacker: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	var unamped_target: Combatant = Combatant.new("t1", "Plain",
		Combatant.Faction.ENEMY, 100, 10)
	var amped_target: Combatant = Combatant.new("t2", "Sundered",
		Combatant.Faction.ENEMY, 100, 10)
	amped_target.apply_status(StatusEffect.vulnerable(2, 50))

	# Use a seeded engine so both calls roll the same variance.
	var engine_a: BattleEngine = BattleEngine.new()
	engine_a.rng.seed = 12345
	var raw_unamped: int = engine_a._calculate_damage(
		attacker, unamped_target, "basic_attack")
	var engine_b: BattleEngine = BattleEngine.new()
	engine_b.rng.seed = 12345
	var raw_amped: int = engine_b._calculate_damage(
		attacker, amped_target, "basic_attack")
	# Amped == int(unamped * 1.5) — but int truncation matters, so allow
	# ±1 (the multiply happens on the pre-floored int).
	var expected: int = int(float(raw_unamped) * 1.5)
	assert_true(raw_amped == expected or raw_amped == expected - 1
			or raw_amped == expected + 1,
		"+50%% vulnerable amps raw (got %d vs expected ~%d)" % [
			raw_amped, expected])
	assert_true(raw_amped > raw_unamped,
		"amped raw is strictly greater than unamped raw")


func test_engine_vulnerable_does_not_consume_on_hit() -> void:
	## Unlike vanished (which is consumed on first attack), vulnerable
	## persists for its full duration. Two _calculate_damage calls in a
	## row against the same target both see the amp.
	var attacker: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	var target: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 100, 10)
	target.apply_status(StatusEffect.vulnerable(3, 50))

	# Both calls share an engine so the rng advances, but the amp must
	# still apply on both — we assert the status list stays unchanged.
	var engine: BattleEngine = BattleEngine.new()
	engine.rng.seed = 42
	engine._calculate_damage(attacker, target, "basic_attack")
	assert_eq(target.status_effects.size(), 1,
		"vulnerable NOT consumed after first calculate")
	engine._calculate_damage(attacker, target, "basic_attack")
	assert_eq(target.status_effects.size(), 1,
		"vulnerable NOT consumed after second calculate")
	assert_eq(String(target.status_effects[0].get("id", "")), "vulnerable",
		"the surviving status is still the vulnerable one")


func test_engine_two_vulnerables_dont_compound() -> void:
	## Two raw +50% vulnerables on the same target give 1.5×, NOT 2.25×.
	## The engine path takes MAX over all vulnerable entries — the design
	## intent is that restacking refreshes the duration (via stack()) but
	## doesn't snowball the multiplier. This protects against degenerate
	## chains (sunder → sunder → sunder → fireball = 4x).
	var attacker: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	var double_target: Combatant = Combatant.new("t", "Double",
		Combatant.Faction.ENEMY, 100, 10)
	double_target.apply_status(StatusEffect.vulnerable(2, 50))
	double_target.apply_status(StatusEffect.vulnerable(2, 50))

	var single_target: Combatant = Combatant.new("s", "Single",
		Combatant.Faction.ENEMY, 100, 10)
	single_target.apply_status(StatusEffect.vulnerable(2, 50))

	var engine_a: BattleEngine = BattleEngine.new()
	engine_a.rng.seed = 99
	var double_raw: int = engine_a._calculate_damage(
		attacker, double_target, "basic_attack")
	var engine_b: BattleEngine = BattleEngine.new()
	engine_b.rng.seed = 99
	var single_raw: int = engine_b._calculate_damage(
		attacker, single_target, "basic_attack")
	assert_eq(double_raw, single_raw,
		"two stacks don't compound — same as one stack")


func test_engine_vulnerable_max_when_amps_differ() -> void:
	## A +50% AND a +100% stacked on the same target: the engine picks
	## MAX (the stronger amp), not sum (would be 2.5×) and not product
	## (would be 3.0×). Stronger debuff wins.
	var attacker: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	var both: Combatant = Combatant.new("t", "Both",
		Combatant.Faction.ENEMY, 100, 10)
	both.apply_status(StatusEffect.vulnerable(2, 50))
	both.apply_status(StatusEffect.vulnerable(2, 100))

	var only_100: Combatant = Combatant.new("s", "Only100",
		Combatant.Faction.ENEMY, 100, 10)
	only_100.apply_status(StatusEffect.vulnerable(2, 100))

	var engine_a: BattleEngine = BattleEngine.new()
	engine_a.rng.seed = 7
	var both_raw: int = engine_a._calculate_damage(
		attacker, both, "basic_attack")
	var engine_b: BattleEngine = BattleEngine.new()
	engine_b.rng.seed = 7
	var only_100_raw: int = engine_b._calculate_damage(
		attacker, only_100, "basic_attack")
	assert_eq(both_raw, only_100_raw,
		"50%% + 100%% stacked = same as 100%% alone (MAX wins)")


func test_engine_vulnerable_floors_at_minimum_one() -> void:
	## A 0%-amp vulnerable (mod = 1.0) is effectively a no-op. The
	## minimum 1 raw damage floor (`return max(1, raw)`) must still hold
	## — a target with a 0%-amp vulnerable doesn't suddenly take 0
	## damage from a tiny attack.
	var attacker: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	attacker.attack_bonus = -100  # force the variance to push raw toward 0
	var target: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 100, 10)
	target.apply_status(StatusEffect.vulnerable(2, 0))
	var engine: BattleEngine = BattleEngine.new()
	engine.rng.seed = 1
	var raw: int = engine._calculate_damage(attacker, target, "basic_attack")
	assert_true(raw >= 1,
		"minimum 1 raw damage floor holds even with 0%% amp")


# ── End-to-end via Combatant.tick_statuses ────────────────────────────────

func test_e2e_vulnerable_expires_after_duration() -> void:
	## Default 2-turn vulnerable should expire after exactly two ticks.
	## No HP damage during the lifetime of the effect (it only amplifies
	## INCOMING damage; the tick itself is silent).
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.vulnerable(2, 50))
	assert_eq(c.status_effects.size(), 1, "vulnerable applied")
	assert_eq(c.hp, 50, "no damage on apply")
	var dmg1: int = c.tick_statuses()
	assert_eq(dmg1, 0, "no damage from vulnerable tick 1")
	assert_eq(c.hp, 50, "HP unchanged after tick 1")
	assert_eq(c.status_effects.size(), 1, "still active after 1 tick")
	assert_eq(int(c.status_effects[0].get("duration", 0)), 1,
		"duration decremented to 1")
	var dmg2: int = c.tick_statuses()
	assert_eq(dmg2, 0, "no damage from vulnerable tick 2")
	assert_eq(c.status_effects.size(), 0,
		"vulnerable expired after the second tick")


func test_e2e_vulnerable_amps_perform_attack_through_armor() -> void:
	## Full end-to-end: hero perform_attack against a vulnerable target
	## deals strictly more damage than against a non-vulnerable target
	## with identical stats + armor + seed.
	var hero_a: Combatant = Combatant.new("ha", "HeroA",
		Combatant.Faction.HERO, 100, 10)
	var hero_b: Combatant = Combatant.new("hb", "HeroB",
		Combatant.Faction.HERO, 100, 10)
	var plain: Combatant = Combatant.new("t1", "Plain",
		Combatant.Faction.ENEMY, 200, 10)
	plain.armor = 0
	var sundered: Combatant = Combatant.new("t2", "Sundered",
		Combatant.Faction.ENEMY, 200, 10)
	sundered.armor = 0
	sundered.apply_status(StatusEffect.vulnerable(2, 50))

	var engine_a: BattleEngine = BattleEngine.new()
	engine_a.rng.seed = 2024
	engine_a.hero_crit_chance = 0.0  # rule out crits for the comparison
	engine_a.setup([hero_a, plain] as Array[Combatant])
	var dealt_plain: int = engine_a.perform_attack(hero_a, plain, "basic_attack")

	var engine_b: BattleEngine = BattleEngine.new()
	engine_b.rng.seed = 2024
	engine_b.hero_crit_chance = 0.0
	engine_b.setup([hero_b, sundered] as Array[Combatant])
	var dealt_sundered: int = engine_b.perform_attack(hero_b, sundered,
		"basic_attack")

	assert_true(dealt_sundered > dealt_plain,
		"vulnerable target takes strictly more damage (%d > %d)" % [
			dealt_sundered, dealt_plain])


func test_e2e_vulnerable_does_not_consume_mana_shield() -> void:
	## Vulnerable is a status, not damage — applying it must not drain
	## the target's Mana Shield (Run 21 absorb pool). Regression guard
	## mirrors the Run-47 stun guard: a defensive caller routing the
	## debuff through take_damage by mistake would silently eat shield
	## charges; routing through apply_status avoids that.
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.mana_shield(40, 10))
	c.apply_status(StatusEffect.vulnerable(2, 50))
	var shield_pool_pre: int = int(c.status_effects[0].get("absorb_remaining", 0))
	assert_eq(shield_pool_pre, 40,
		"mana shield untouched by vulnerable apply")


func test_e2e_vulnerable_two_attacks_in_window() -> void:
	## The Arcanist's burst pattern: apply vulnerable, then fire two
	## attacks within the 2-turn duration. Both must be amped (vulnerable
	## is NOT consumed on hit). After the 2nd tick the effect expires and
	## the third attack lands at base damage.
	var hero: Combatant = Combatant.new("h", "Hero",
		Combatant.Faction.HERO, 100, 10)
	var target: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 999, 10)
	target.armor = 0
	target.apply_status(StatusEffect.vulnerable(2, 100))
	# Two attacks while the debuff is live — both should be amped.
	var engine: BattleEngine = BattleEngine.new()
	engine.rng.seed = 17
	engine.hero_crit_chance = 0.0
	engine.setup([hero, target] as Array[Combatant])
	var hit1: int = engine.perform_attack(hero, target, "basic_attack")
	# Tick the status once between attacks (simulates a turn passing).
	target.tick_statuses()
	assert_eq(target.status_effects.size(), 1,
		"vulnerable survives one tick")
	var hit2: int = engine.perform_attack(hero, target, "basic_attack")
	# Tick the status a second time — expires.
	target.tick_statuses()
	assert_eq(target.status_effects.size(), 0,
		"vulnerable expires after the second tick")
	# Third attack lands at base damage (no vulnerable left).
	var hit3: int = engine.perform_attack(hero, target, "basic_attack")
	assert_true(hit1 > 0 and hit2 > 0 and hit3 > 0,
		"all three attacks land")
	# hit1 and hit2 should be in the amped range, hit3 in the plain range.
	# The variance band overlaps at the edges, but with +100% amp the
	# amped damage should typically be greater than the plain damage —
	# we assert the average rather than each individual hit to avoid
	# variance flakes.
	var amped_avg: float = float(hit1 + hit2) / 2.0
	assert_true(amped_avg > float(hit3),
		"avg amped damage (%.1f) > plain damage (%d)" % [
			amped_avg, hit3])


# ── Cross-effect isolation ────────────────────────────────────────────────

func test_vulnerable_does_not_skip_turn() -> void:
	## Regression guard: vulnerable does NOT carry skips_turn (unlike
	## frozen or stunned). A vulnerable enemy still gets their turn.
	var e: Dictionary = StatusEffect.vulnerable()
	assert_true(not bool(e.get("skips_turn", false)),
		"vulnerable does not lock a turn")


func test_vulnerable_does_not_register_as_frozen_or_stunned() -> void:
	## The Run-47 helpers (is_combatant_frozen / is_combatant_stunned)
	## must not cross-fire with vulnerable. A vulnerable enemy still
	## takes their AI turn — they just take more damage when hit.
	var engine: BattleEngine = BattleEngine.new()
	var c: Combatant = Combatant.new("t", "Target",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.vulnerable())
	assert_true(not engine.is_combatant_frozen(c),
		"vulnerable does not register as frozen")
	assert_true(not engine.is_combatant_stunned(c),
		"vulnerable does not register as stunned")
