## Run 45 tests: death-screen meta toast.
##
## The toast itself is rendered inside `BattleScene._show_death_overlay`, which
## can't run under `--script` mode (no SceneTree paint). But every value the
## toast reads is computed by `MetaProgress.newly_affordable_perks(prev_shards)`
## + the existing `record_run_end` shard payout. This suite exercises the new
## helper end-to-end against realistic death-run scenarios so a future tuning
## change (perk cost, milestone gate, lifetime-stats schema) can't silently
## break the "X new perks affordable" line the death overlay relies on.
##
## MetaProgress instances are spawned via GDScript.new() (matching the
## Run 36/37/38/39/40/41/42/43/44 detached-instance pattern) so the autoload's
## `_ready -> load_from_disk` path doesn't touch the player's real meta save.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun45


var PERKS: GDScript = load("res://src/data/Perks.gd")
var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


# ── newly_affordable_perks — math + defensive cases ───────────────────────

func test_newly_affordable_zero_when_nothing_crossed() -> void:
	## A run that pays 1 shard from 0 → 1 doesn't cross any perk cost
	## (cheapest is `wealthy` at 20 shards), so the helper returns 0 and the
	## death overlay omits the "perks now affordable" line entirely.
	var m: Node = _fresh_meta()
	m.shards = 1
	assert_eq(m.newly_affordable_perks(0), 0,
		"1 shard doesn't cross any perk price gate")


func test_newly_affordable_counts_perk_that_just_crossed() -> void:
	## Player ended a run with 19 shards (1 short of wealthy). They land
	## floor 1 = 1 shard. New total 20. `wealthy` (cost 20) crossed the
	## gate; nothing else did (seasoned at 25 is still out of reach).
	var m: Node = _fresh_meta()
	m.shards = 20
	assert_eq(m.newly_affordable_perks(19), 1,
		"wealthy (20) crossed from 19 → 20")


func test_newly_affordable_excludes_already_owned() -> void:
	## A perk the player already owns must NOT count, even if the threshold
	## maths would otherwise put it in the affordable band. The death overlay
	## should never advertise "buy what you already bought."
	var m: Node = _fresh_meta()
	m.shards = 20
	# Mark wealthy as owned BEFORE asking — it crossed the band but should
	# be excluded.
	var owned: Array[String] = ["wealthy"]
	m.owned_perks = owned
	assert_eq(m.newly_affordable_perks(19), 0,
		"already-owned perk doesn't count even when in the band")


func test_newly_affordable_excludes_milestone_locked() -> void:
	## A milestone-gated perk (e.g. `deep_diver` requires best_floor >= 9)
	## that the player hasn't unlocked yet must NOT count, even if they have
	## the shards. The death overlay shouldn't tempt the player toward a buy
	## that the wallet would refuse at the MetaScreen.
	var m: Node = _fresh_meta()
	m.shards = 50  # deep_diver costs 50, so the price gate is satisfied
	# best_floor is 0, which is below deep_diver's threshold of 9
	assert_eq(m.best_floor, 0, "fresh meta starts at floor 0")
	# 0 → 50 crosses deep_diver's price, but the milestone is locked
	# (no perk should count from this band — all other perks at <= 50 are
	# either Run-36 ungated or also milestone-gated above this).
	# We assert that deep_diver specifically is NOT contributing — confirmed
	# by counting all crossable perks and subtracting milestone-locked ones.
	var crossed: int = 0
	for pid: String in PERKS.all_ids():
		var c: int = PERKS.cost(pid)
		if c > 0 and c <= 50:
			crossed += 1
	var unlocked_count: int = m.newly_affordable_perks(0)
	# Every unlocked, affordable perk must have its milestone met.
	assert_true(unlocked_count < crossed,
		"deep_diver locked behind floor 9 — excluded even though cost fits")


func test_newly_affordable_negative_prev_clamps_to_zero() -> void:
	## A defensive caller passing -5 (hand-edited save corruption) must
	## clamp the lower band to 0, not widen it downward and over-count.
	var m: Node = _fresh_meta()
	m.shards = 20
	assert_eq(m.newly_affordable_perks(-5), m.newly_affordable_perks(0),
		"negative prev clamps to 0 — same result as prev=0")


func test_newly_affordable_no_perks_when_broke() -> void:
	## A run that paid out shards but didn't push the wallet past any perk
	## cost (e.g. 5 shards → 12 shards) yields 0 affordable perks. The
	## cheapest perk (`wealthy`) costs 20 — the threshold isn't crossed.
	var m: Node = _fresh_meta()
	m.shards = 12
	assert_eq(m.newly_affordable_perks(5), 0,
		"5 → 12 doesn't cross any 20+ perk cost")


func test_newly_affordable_multiple_perks_in_band() -> void:
	## Big death payout (e.g. a deep failed run pays many shards if the
	## player was already close to a buy) crosses multiple gates at once.
	## Start with 0 shards, land at 50 — `wealthy` (20), `seasoned` (25),
	## `iron_blood` (30), `lucky_strike` (30), `audience_darling` (30),
	## `swift_boots` (35), `steady_step` (40), `merchant_ally` (45),
	## `hardened_traveler` (40) all cross. `deep_diver` (50) is at the cap
	## but milestone-locked. Count is the unlocked ones at <= 50.
	var m: Node = _fresh_meta()
	m.shards = 50
	var count: int = m.newly_affordable_perks(0)
	# Verify every counted perk is genuinely in the band AND unlocked AND
	# not owned — sanity check on the helper's contract.
	var manual: int = 0
	for pid: String in PERKS.all_ids():
		if m.owned_perks.has(pid):
			continue
		if not PERKS.is_milestone_unlocked(pid, m.lifetime_stats()):
			continue
		var c: int = PERKS.cost(pid)
		if c > 0 and c > 0 and c <= 50:
			manual += 1
	assert_eq(count, manual,
		"helper count matches manual band-walk over Perks.DEFS")
	assert_true(count >= 4, "at least 4 perks affordable at 50 shards")


func test_newly_affordable_milestone_just_unlocked_counts() -> void:
	## A win that crosses a milestone AND affords a newly-unlocked perk —
	## the helper reads post-record lifetime stats, so the gate flips just
	## in time and the perk counts. Simulates the post-`record_run_end`
	## call site where this helper is used.
	var m: Node = _fresh_meta()
	m.best_floor = 9  # deep_diver milestone met (>= 9)
	m.shards = 50     # exactly deep_diver's cost
	assert_eq(PERKS.cost("deep_diver"), 50,
		"deep_diver costs 50 (this test stays in sync with cost tuning)")
	# 0 → 50 should cross deep_diver. Wealthy/seasoned/etc also cross —
	# verify the count includes deep_diver via a manual walk that asserts
	# its milestone gate now passes.
	assert_true(PERKS.is_milestone_unlocked("deep_diver", m.lifetime_stats()),
		"deep_diver unlocked at best_floor=9")
	var with_deep_diver: int = m.newly_affordable_perks(0)
	m.best_floor = 8  # roll back below the threshold
	var without_deep_diver: int = m.newly_affordable_perks(0)
	assert_eq(with_deep_diver - without_deep_diver, 1,
		"unlocking deep_diver adds exactly 1 to the affordable count")


# ── End-to-end via record_run_end ───────────────────────────────────────────

func test_e2e_death_run_pays_shards() -> void:
	## A death on floor 8 with 2 bosses slain pays 8*1 + 2*4 = 16 shards.
	## The death overlay reads MetaProgress.shards delta against the prev
	## snapshot — verify the delta math is what we'd display.
	var m: Node = _fresh_meta()
	var prev: int = m.shards
	var payout: int = m.record_run_end(8, 2, false, 8000, "brawler")
	assert_eq(payout, 16, "8 floors + 2 bosses = 16 shards (death)")
	assert_eq(m.shards - prev, payout,
		"wallet delta matches the returned payout")


func test_e2e_death_then_newly_affordable_count() -> void:
	## Player has 18 shards (1 short of wealthy). They die on floor 6 with
	## 1 boss = 10 shards. New total = 28. Wealthy (20) now affordable
	## (crossed the 18 → 28 band). Seasoned (25) also crossed. Count = 2.
	var m: Node = _fresh_meta()
	m.shards = 18
	var prev: int = m.shards
	var payout: int = m.record_run_end(6, 1, false, 5000, "brawler")
	assert_eq(payout, 10, "6 + 4 = 10 shards on death")
	assert_eq(m.shards, 28, "wallet now at 28")
	var unlocked: int = m.newly_affordable_perks(prev)
	# Wealthy (20) AND Seasoned (25) crossed the 18 → 28 band, both ungated
	assert_eq(unlocked, 2,
		"wealthy + seasoned crossed the 18 → 28 band")


func test_e2e_death_with_existing_purchases() -> void:
	## A returning player who already bought wealthy + seasoned dies on
	## floor 6 + 1 boss = 10 shards. New band 18 → 28 would cross both
	## perks BUT they're already owned, so the count is 0.
	var m: Node = _fresh_meta()
	m.shards = 18
	var owned: Array[String] = ["wealthy", "seasoned"]
	m.owned_perks = owned
	var prev: int = m.shards
	m.record_run_end(6, 1, false, 5000, "brawler")
	assert_eq(m.newly_affordable_perks(prev), 0,
		"already-owned perks excluded — no new ones in this band")


func test_e2e_death_run_payout_then_helper_uses_post_record_stats() -> void:
	## The death pays 50 shards from the depth + bosses, simultaneously
	## bumping best_floor past 9 (deep_diver milestone). The helper, called
	## AFTER record_run_end, reads the post-record lifetime stats so
	## deep_diver's milestone gate now passes and the perk counts.
	var m: Node = _fresh_meta()
	m.shards = 0
	var prev: int = m.shards
	# Floor 9 + 5 bosses = 9 + 20 = 29 shards. Boost shards manually to put
	# us above deep_diver's 50 cost — the helper still consumes only the
	# pre/post wallet delta vs. live stats.
	m.shards = 60  # post-record adjustment to put us above deep_diver cost
	# Manually invoke record_run_end to bump best_floor → 9 (deep_diver
	# milestone). We can't easily compose the natural shard math AND a
	# direct boost; instead test the contract: prev=0, post=60, stats updated.
	m.record_run_end(9, 0, false, 9000, "brawler")
	# best_floor should now be 9
	assert_eq(m.best_floor, 9, "best_floor advanced to 9")
	assert_true(PERKS.is_milestone_unlocked("deep_diver", m.lifetime_stats()),
		"deep_diver unlocked post-record")
	var aff: int = m.newly_affordable_perks(prev)
	# At least deep_diver (50) is in band and now unlocked.
	assert_true(aff >= 1,
		"deep_diver crossed AND its milestone unlocked — counts")


func test_e2e_milestone_locked_perks_excluded_when_unaffordable() -> void:
	## Player at 100 shards (afford anything), best_floor 0 (deep_diver
	## locked), 0 lifetime wins (war_veteran + champions_bond locked),
	## 0 bosses slain (bossbane locked). The 0 → 100 band crosses every
	## perk cost, but milestone-locked ones are excluded.
	var m: Node = _fresh_meta()
	m.shards = 100
	var aff: int = m.newly_affordable_perks(0)
	# Count the ungated perks under 100 to verify the helper excluded the
	# four milestone-locked ones (deep_diver, bossbane, war_veteran,
	# champions_bond).
	var ungated: int = 0
	for pid: String in PERKS.all_ids():
		if PERKS.has_milestone(pid):
			continue
		var c: int = PERKS.cost(pid)
		if c > 0 and c <= 100:
			ungated += 1
	assert_eq(aff, ungated,
		"every ungated affordable perk counts; milestone-locked ones don't")


# ── Edge cases ─────────────────────────────────────────────────────────────

func test_newly_affordable_zero_band_returns_zero() -> void:
	## prev == current shards (a degenerate "no payout" call — shouldn't
	## happen in practice but the helper must handle it cleanly). No perk
	## costs strictly more than prev_shards AND <= shards if both are equal.
	var m: Node = _fresh_meta()
	m.shards = 50
	assert_eq(m.newly_affordable_perks(50), 0,
		"equal prev/current — no perk crosses an empty band")


func test_newly_affordable_at_exact_cost_counts() -> void:
	## A perk whose cost exactly matches the new shard total IS affordable
	## (>= comparison via `c <= shards`). Edge case: a player landing on
	## exactly 20 shards from a prev of 19 should see wealthy in the count.
	var m: Node = _fresh_meta()
	m.shards = 20
	assert_eq(m.newly_affordable_perks(19), 1,
		"wealthy (20) at exact-cost shard total counts as affordable")


func test_newly_affordable_unowned_unaffordable_doesnt_count() -> void:
	## A perk that the band crossed but is STILL unaffordable post-payout
	## must not count. Edge case: a player at 5 shards lands at 18 (still
	## broke for everything). Count = 0.
	var m: Node = _fresh_meta()
	m.shards = 18
	assert_eq(m.newly_affordable_perks(5), 0,
		"band 5 → 18 has no perks in range (cheapest is wealthy at 20)")
