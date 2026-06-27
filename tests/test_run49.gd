## Run 49 tests: Regenerating status effect + Iron Resolve ability.
##
## Regenerating is the 10th status type (after Run 48's vulnerable). It's the
## first POSITIVE per-turn ticker — every prior DoT (burning / poisoned /
## bleed) subtracts HP at tick time; regenerating adds HP. The only nearby
## prior art is mana_shield (Run 21), but that's an absorb pool consumed
## BEFORE armor, not a heal applied AT tick. Filling this gap also fills
## the Brawler's missing sustain niche: their pre-49 kit (basic_attack /
## power_strike / taunt / shield_bash / concussive_slam) was all damage or
## tempo with no way to recover mid-battle.
##
## Engine integration: a new `heal_per_turn` field on the status dict.
## `Combatant.tick_statuses` reads it after the existing damage_per_turn
## drain and calls `heal()` on the carrier — so a hero stacking burning AND
## regenerating still pays the burn damage first (a "your HoT didn't save
## you" beat consistent with how poison-then-heal plays in other tactical
## roguelikes), and `heal()` clamps to max_hp so the tick can't overheal.
##
## Iron Resolve is the Brawler's NEW class-unique unlock — slots into the
## CLASS_UNLOCKS list AFTER the Run-47 flagship (concussive_slam) and BEFORE
## the older shield_bash pushback. The Brawler now has TWO class-unique
## picks (tempo + sustain), closing the "only damage cards" gap the unlock
## list had through Run 47.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun49


# ── StatusEffect.regenerating factory ─────────────────────────────────────

func test_regenerating_default_factory_shape() -> void:
	## Default 3-turn / +6 hpt regen. Fields: id="regenerating", display
	## name "Regenerating", duration=3, no DPT, no armor change,
	## heal_per_turn=6 (the new field).
	var e: Dictionary = StatusEffect.regenerating()
	assert_eq(String(e.get("id", "")), "regenerating", "id is regenerating")
	assert_eq(String(e.get("name", "")), "Regenerating", "name is Regenerating")
	assert_eq(int(e.get("duration", 0)), 3, "default 3 turns")
	assert_eq(int(e.get("damage_per_turn", 0)), 0, "no DPT")
	assert_eq(int(e.get("armor_mod", 0)), 0, "no armor change")
	assert_eq(int(e.get("heal_per_turn", 0)), 6,
		"default heal is 6 HP/turn")


func test_regenerating_custom_hpt_carries() -> void:
	## A future heavier ability (or a save-loaded buff) could carry 12/turn.
	## Factory accepts arbitrary positive hpt without re-clamping it.
	var e: Dictionary = StatusEffect.regenerating(5, 12)
	assert_eq(int(e.get("duration", 0)), 5, "custom duration carries")
	assert_eq(int(e.get("heal_per_turn", 0)), 12, "custom hpt carries")


func test_regenerating_negative_inputs_clamp() -> void:
	## Defensive: a save-corruption -8 hpt would secretly DRAIN HP if the
	## tick code blindly called `heal(hpt)`. Clamp the hpt to 0 (a no-op
	## tick) and the duration to 0. The dict shape stays predictable so
	## the HUD doesn't crash on a hand-edited save.
	var e: Dictionary = StatusEffect.regenerating(-2, -8)
	assert_eq(int(e.get("duration", 0)), 0,
		"negative duration clamps to 0")
	assert_eq(int(e.get("heal_per_turn", 0)), 0,
		"negative hpt clamps to 0 (can never drain HP)")


func test_regenerating_zero_hpt_allowed() -> void:
	## 0 hpt is a valid edge case — the dict shape stays consistent (a
	## regenerating with 0/turn is a no-op tracker for the duration). The
	## tick code's `if hpt > 0` gate handles this without calling heal.
	var e: Dictionary = StatusEffect.regenerating(2, 0)
	assert_eq(int(e.get("heal_per_turn", 0)), 0, "0 hpt carries")
	assert_eq(int(e.get("duration", 0)), 2, "duration unchanged")


# ── HUD short_code / display_name / summarize ─────────────────────────────

func test_regenerating_short_code() -> void:
	## The compact above-the-sprite label reads `[REG 3]`. Short code via
	## the shared SHORT_CODES dict so a future rename only touches one
	## constant.
	var e: Dictionary = StatusEffect.regenerating()
	assert_eq(StatusEffect.short_code(e), "REG",
		"regenerating short code is REG")


func test_regenerating_display_name() -> void:
	## Detail panel reads "Regenerating" — present participle matches the
	## Run-35 idiom for the other states (Burning / Bleeding).
	var e: Dictionary = StatusEffect.regenerating()
	assert_eq(StatusEffect.display_name(e), "Regenerating",
		"regenerating display name is Regenerating")


func test_regenerating_summarize_includes_hpt() -> void:
	## Summary line carries duration + "+N HP/turn". Regenerating has no
	## DPT and no armor mod, so without the heal segment the panel would
	## read "Regenerating · 3t" and tell the player nothing about how much
	## the buff is actually healing per tick.
	var e: Dictionary = StatusEffect.regenerating(3, 6)
	var s: String = StatusEffect.summarize(e)
	assert_true(s.contains("Regenerating"), "summary names the effect")
	assert_true(s.contains("3t"), "summary carries duration")
	assert_true(s.contains("+6") and s.contains("HP/turn"),
		"summary surfaces +N HP/turn heal rate")
	assert_true(not s.contains("armor"),
		"no armor suffix (regenerating doesn't change armor)")
	assert_true(not s.contains("skip turn"),
		"no skip-turn suffix (regenerating doesn't lock a turn)")
	assert_true(not s.contains("taken"),
		"no damage-taken suffix (regenerating isn't a vulnerable)")


func test_regenerating_summarize_custom_hpt() -> void:
	## A +12 summary line must carry "+12 HP/turn" — not just "+12" (missing
	## the unit) or "+1 HP/turn" (a future formatting bug).
	var e: Dictionary = StatusEffect.regenerating(2, 12)
	var s: String = StatusEffect.summarize(e)
	assert_true(s.contains("+12") and s.contains("HP/turn"),
		"summary carries +12 HP/turn")


func test_regenerating_summarize_zero_hpt_omits_heal_line() -> void:
	## A 0-hpt regen (edge case) shouldn't render "+0 HP/turn" — the
	## summarize gate is `hpt > 0` so the segment is dropped entirely.
	var e: Dictionary = StatusEffect.regenerating(2, 0)
	var s: String = StatusEffect.summarize(e)
	assert_true(not s.contains("HP/turn"),
		"0 hpt does not render the heal-rate segment")


# ── Stack collapse ────────────────────────────────────────────────────────

func test_regenerating_stack_sums_hpt() -> void:
	## Two regenerating buffs on the same carrier collapse to one row.
	## heal_per_turn SUMS (mirrors the existing damage_per_turn summer for
	## DoTs) — re-applying mid-buff doubles the per-tick heal, matching
	## the "stacking the buff is good" expectation from poison_blade's
	## DoT compounding. Duration takes MAX so a refresh-late doesn't
	## shorten the window.
	var a: Dictionary = StatusEffect.regenerating(3, 6)
	var b: Dictionary = StatusEffect.regenerating(2, 4)
	var input_arr: Array = [a, b]
	var stacked: Array[Dictionary] = StatusEffect.stack(input_arr)
	assert_eq(stacked.size(), 1, "two regenerates collapse to one row")
	assert_eq(int(stacked[0].get("stacks", 1)), 2, "stack count = 2")
	assert_eq(int(stacked[0].get("duration", 0)), 3,
		"duration is the longer of the two (3 vs 2)")
	assert_eq(int(stacked[0].get("heal_per_turn", 0)), 10,
		"heal_per_turn SUMS (6 + 4 = 10)")


func test_regenerating_stack_duration_max_when_second_is_longer() -> void:
	## A refresh-late application (shorter first, longer second) still
	## takes MAX on duration — the player's "I refreshed before the buff
	## ended" expectation holds even when the original was about to expire.
	var a: Dictionary = StatusEffect.regenerating(1, 6)
	var b: Dictionary = StatusEffect.regenerating(4, 6)
	var input_arr: Array = [a, b]
	var stacked: Array[Dictionary] = StatusEffect.stack(input_arr)
	assert_eq(stacked.size(), 1, "collapse")
	assert_eq(int(stacked[0].get("duration", 0)), 4,
		"duration is the longer one even when applied second")
	assert_eq(int(stacked[0].get("heal_per_turn", 0)), 12,
		"hpt still sums (6 + 6 = 12)")


# ── Iron Resolve ability schema ───────────────────────────────────────────

func test_iron_resolve_in_defs() -> void:
	## The ability must be registered for the Brawler's class-unlock pool
	## to reference it, and for BattleScene's _do_hero_self_ability match
	## arm to find its regen_duration / regen_hpt fields.
	assert_true(Abilities.DATA.has("iron_resolve"),
		"iron_resolve is in Abilities.DATA")


func test_iron_resolve_schema_shape() -> void:
	## Required fields for a status-applying self-target buff: type=buff,
	## target=self, range=0, base_damage=0 (no direct hit — it's a self
	## buff), applies_regenerating=true with regen_duration + regen_hpt.
	var d: Dictionary = Abilities.DATA["iron_resolve"]
	assert_eq(String(d.get("type", "")), "buff", "type is buff")
	assert_eq(String(d.get("target", "")), "self", "target is self")
	assert_eq(int(d.get("range", -1)), 0, "range 0 — self only")
	assert_eq(int(d.get("base_damage", -1)), 0,
		"no direct damage (it's a self buff)")
	assert_true(bool(d.get("applies_regenerating", false)),
		"applies_regenerating flag present")
	assert_true(int(d.get("regen_duration", 0)) > 0,
		"regen_duration > 0")
	assert_true(int(d.get("regen_hpt", 0)) > 0,
		"regen_hpt > 0")


func test_iron_resolve_in_brawler_unlocks() -> void:
	## Brawler's CLASS_UNLOCKS list must include iron_resolve. Order: the
	## Run-47 flagship `concussive_slam` stays at index 0 (the class-unique
	## stun), `iron_resolve` slots in at index 1 (the second class-unique
	## pick, sustain flavor), and `shield_bash` stays as the older fallback.
	## A fresh Brawler at level 2 still sees concussive_slam first; a
	## Brawler who already owns it sees iron_resolve next.
	var script: GDScript = load("res://scenes/LevelUp.gd")
	var class_unlocks: Dictionary = script.CLASS_UNLOCKS
	var br_unlocks: Array = class_unlocks.get("brawler", [])
	assert_true(br_unlocks.has("iron_resolve"),
		"iron_resolve in brawler unlocks")
	assert_eq(String(br_unlocks[0]), "concussive_slam",
		"concussive_slam stays first (Run-47 flagship)")
	assert_true(br_unlocks.find("iron_resolve") < br_unlocks.find("shield_bash"),
		"iron_resolve sits ahead of shield_bash")
	assert_true(br_unlocks.has("shield_bash"),
		"shield_bash kept as older fallback")


func test_iron_resolve_cost_and_charges() -> void:
	## Cost + charges keep iron_resolve as a defensive self-buff: 2 charges,
	## 4-turn cooldown, 50 xp. Matches mana_shield's "defensive self-buff"
	## tempo so the cross-class self-buff pool reads consistently. Default
	## hpt = 8 (3-turn buff = 24 total — meaningful sustain without
	## trivializing late-game floor damage).
	var d: Dictionary = Abilities.DATA["iron_resolve"]
	assert_eq(int(d.get("max_charges", 0)), 2, "2 charges")
	assert_eq(int(d.get("cooldown_turns", 0)), 4, "4-turn cooldown")
	assert_eq(int(d.get("xp_cost", 0)), 50, "50 xp unlock cost")
	assert_eq(int(d.get("regen_hpt", 0)), 8,
		"default hpt = 8 (3-turn buff = 24 total HP)")
	assert_eq(int(d.get("regen_duration", 0)), 3,
		"3-turn buff window (covers a multi-hit engagement)")


# ── Combatant.tick_statuses heal-per-turn behavior ────────────────────────

func test_tick_regenerating_heals_wounded_carrier() -> void:
	## Carrier at 30/100 HP with default 6/turn regen. After one tick,
	## HP should be 36 — the heal lands via Combatant.heal which clamps
	## to max_hp - hp (no overheal pool).
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 30
	c.apply_status(StatusEffect.regenerating(3, 6))
	var dmg: int = c.tick_statuses()
	assert_eq(dmg, 0, "no damage from regenerating tick")
	assert_eq(c.hp, 36, "carrier healed by 6 (30 -> 36)")
	assert_eq(c.status_effects.size(), 1,
		"regen survives one tick (3 -> 2 duration)")
	assert_eq(int(c.status_effects[0].get("duration", 0)), 2,
		"duration decremented to 2")


func test_tick_regenerating_does_not_overheal() -> void:
	## A full-HP carrier wastes the tick — Combatant.heal clamps to
	## max_hp - hp, so the tick is silently absorbed. HP stays at max.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	# c.hp == max_hp == 100 by default
	c.apply_status(StatusEffect.regenerating(3, 6))
	var dmg: int = c.tick_statuses()
	assert_eq(dmg, 0, "no damage from tick")
	assert_eq(c.hp, 100, "HP stays at max (no overheal pool)")
	assert_eq(c.status_effects.size(), 1, "regen still active")


func test_tick_regenerating_partial_heal_at_max_boundary() -> void:
	## Carrier at 97/100 with 6/turn regen heals exactly 3 (not 6) on the
	## tick — `heal()` returns min(amount, max_hp - hp). The status itself
	## doesn't know it was partially absorbed; the next tick (still at
	## 100/100) is silently wasted.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 97
	c.apply_status(StatusEffect.regenerating(3, 6))
	c.tick_statuses()
	assert_eq(c.hp, 100, "carrier capped at max (97 + 6 clamped to 100)")


func test_tick_regenerating_expires_after_duration() -> void:
	## Default 3-turn regen expires after exactly three ticks. HP totals
	## the full 18 (3 × 6) when the carrier was wounded enough to absorb
	## every tick.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 10  # plenty of room to soak the full heal
	c.apply_status(StatusEffect.regenerating(3, 6))
	c.tick_statuses()
	assert_eq(c.hp, 16, "tick 1: 10 -> 16")
	assert_eq(c.status_effects.size(), 1, "still active after tick 1")
	c.tick_statuses()
	assert_eq(c.hp, 22, "tick 2: 16 -> 22")
	assert_eq(c.status_effects.size(), 1, "still active after tick 2")
	c.tick_statuses()
	assert_eq(c.hp, 28, "tick 3: 22 -> 28 (full 18 healed)")
	assert_eq(c.status_effects.size(), 0,
		"regen expired after the third tick")


func test_tick_regenerating_does_not_revive_dead_carrier() -> void:
	## Regression guard: a carrier killed by a DoT in the same tick must
	## NOT be revived by the regen tick that follows. The `is_alive()`
	## gate in tick_statuses skips the heal when HP hit 0. Locks the
	## "your HoT didn't save you" beat: a burn that finishes you off
	## doesn't let the regen tick paper it over.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 4
	c.apply_status(StatusEffect.burning(3, 10))  # ticks 10/turn — kills
	c.apply_status(StatusEffect.regenerating(3, 6))
	c.tick_statuses()
	assert_eq(c.hp, 0, "carrier killed by burn tick (4 - 10 = 0)")
	assert_true(not c.is_alive(),
		"carrier is dead — regen MUST NOT revive them")


func test_tick_regenerating_dot_first_heal_second() -> void:
	## Order matters: when a carrier has burning AND regenerating, the
	## burn drain happens BEFORE the regen heal. A wounded carrier with
	## both takes the full burn damage then gets the regen tick.
	## tick_statuses return value carries the DoT (not net) so existing
	## callers (BattleScene damage numbers, boss-phase triggers) still
	## see the raw damage figure.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 50
	c.apply_status(StatusEffect.burning(3, 8))      # ticks 8/turn
	c.apply_status(StatusEffect.regenerating(3, 5)) # heals 5/turn
	var dmg: int = c.tick_statuses()
	assert_eq(dmg, 8, "return value is the burn damage (not net)")
	assert_eq(c.hp, 47, "net: 50 - 8 + 5 = 47")
	assert_eq(c.status_effects.size(), 2,
		"both statuses survive the tick")


func test_tick_regenerating_zero_hpt_is_noop() -> void:
	## A 0-hpt regen ticks silently — no heal, no damage, duration still
	## ticks down. The `if hpt > 0` gate in tick_statuses skips the heal
	## call entirely.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 50
	c.apply_status(StatusEffect.regenerating(2, 0))
	c.tick_statuses()
	assert_eq(c.hp, 50, "no heal applied with 0 hpt")
	assert_eq(c.status_effects.size(), 1, "still active after tick 1")


func test_tick_regenerating_stacked_heals_combined() -> void:
	## Two regen buffs on the same carrier (the stack() collapser sums
	## heal_per_turn for the HUD; the tick code reads each status
	## independently and SUMS the heals across multiple regenerating
	## entries. With 6/turn + 4/turn, a wounded carrier gets 10 net
	## per tick.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 40
	c.apply_status(StatusEffect.regenerating(2, 6))
	c.apply_status(StatusEffect.regenerating(2, 4))
	c.tick_statuses()
	assert_eq(c.hp, 50, "two regens heal 10 combined (6 + 4)")


# ── End-to-end via Combatant ──────────────────────────────────────────────

func test_e2e_iron_resolve_payload_via_factory() -> void:
	## Wire-up check: apply the regenerating status that the Iron Resolve
	## ability would create at battle time. Carrier wounded to 40/100,
	## apply 3-turn / 8-hpt regen, tick three times — final HP is 64
	## (40 + 3 × 8) and the buff has expired.
	var c: Combatant = Combatant.new("c", "Brawler",
		Combatant.Faction.HERO, 100, 10)
	c.hp = 40
	var d: Dictionary = Abilities.DATA["iron_resolve"]
	c.apply_status(StatusEffect.regenerating(
		int(d.get("regen_duration", 3)),
		int(d.get("regen_hpt", 8))))
	for i in range(3):
		c.tick_statuses()
	assert_eq(c.hp, 64, "iron_resolve heals 24 over 3 turns (40 -> 64)")
	assert_eq(c.status_effects.size(), 0,
		"regenerating expired after 3 ticks")


func test_e2e_iron_resolve_does_not_consume_mana_shield() -> void:
	## Regression guard: applying regenerating must NOT drain the carrier's
	## Mana Shield (Run 21 absorb pool). Mirrors the Run-47/48 stun/vuln
	## guards — a defensive caller routing the buff through take_damage by
	## mistake would silently eat shield charges. Routing through
	## apply_status avoids that.
	var c: Combatant = Combatant.new("c", "Carrier",
		Combatant.Faction.HERO, 100, 10)
	c.apply_status(StatusEffect.mana_shield(40, 10))
	c.apply_status(StatusEffect.regenerating(3, 8))
	# mana_shield landed first, regenerating second — the shield is at index 0.
	var shield_pool: int = int(c.status_effects[0].get("absorb_remaining", 0))
	assert_eq(shield_pool, 40,
		"mana shield untouched by regenerating apply")


# ── Cross-effect isolation ────────────────────────────────────────────────

func test_regenerating_does_not_skip_turn() -> void:
	## Regression guard: regenerating does NOT carry skips_turn (unlike
	## frozen or stunned). A regenerating hero still gets their turn.
	var e: Dictionary = StatusEffect.regenerating()
	assert_true(not bool(e.get("skips_turn", false)),
		"regenerating does not lock a turn")


func test_regenerating_does_not_register_as_frozen_or_stunned() -> void:
	## The Run-47 helpers (is_combatant_frozen / is_combatant_stunned) must
	## not cross-fire with regenerating. A regenerating carrier still gets
	## their AI turn (relevant if a future buff-stealing enemy ability
	## lands regen on an enemy).
	var engine: BattleEngine = BattleEngine.new()
	var c: Combatant = Combatant.new("t", "Carrier",
		Combatant.Faction.ENEMY, 50, 10)
	c.apply_status(StatusEffect.regenerating())
	assert_true(not engine.is_combatant_frozen(c),
		"regenerating does not register as frozen")
	assert_true(not engine.is_combatant_stunned(c),
		"regenerating does not register as stunned")


func test_regenerating_does_not_amp_taken_damage() -> void:
	## Regression guard: regenerating must NOT carry damage_taken_mod
	## (vulnerable's Run-48 field). A heal-over-time that secretly amped
	## incoming damage would be a debuff in disguise.
	var e: Dictionary = StatusEffect.regenerating()
	assert_eq(float(e.get("damage_taken_mod", 1.0)), 1.0,
		"regenerating does not amp damage taken")
	assert_eq(int(e.get("damage_taken_pct", 0)), 0,
		"no damage_taken_pct on regenerating")
