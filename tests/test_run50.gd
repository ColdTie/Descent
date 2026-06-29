## Run 50 tests: per-unit hover tooltip — pure-data helper coverage.
##
## The visual side (HoverArea on each non-hero sprite + a follow-the-cursor
## PanelContainer on UILayer) lives in BattleScene and is covered by the
## visual smoke audit — it can't be exercised in `--script` headless mode
## without an autoload + scene tree. What IS testable in isolation is the
## new `StatusEffect.tooltip_lines(effects)` helper that the tooltip body
## consumes to render one line per stack-collapsed status effect. This is
## the contract the tooltip's text rendering depends on, so locking it
## down here protects every future status-effect addition from silently
## breaking the tooltip render.
##
## Coverage strategy mirrors Run 46/47/48/49: factory-shape happy paths,
## stack collapser behaviour, defensive cases (empty input, non-Dictionary
## entries, malformed dicts), and one-test-per-effect-type renderability
## so the per-id summarize() branches are all visited via the new helper.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun50


# ── Happy path: empty + single + multi ──────────────────────────────────

func test_tooltip_lines_empty_input_returns_empty_array() -> void:
	## A unit with no statuses yields an empty array — the caller renders
	## its own "(no active effects)" placeholder so the empty-state styling
	## stays scene-local (dim grey) rather than smearing into this helper.
	var lines: Array[String] = StatusEffect.tooltip_lines([])
	assert_eq(lines.size(), 0, "empty input -> empty array")


func test_tooltip_lines_single_burning_no_stack_suffix() -> void:
	## A lone effect renders just `summarize()` — no "(xN)" suffix because
	## the stack count is 1. This is the most common shape on the board:
	## a single DoT applied once.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.burning(3, 5)])
	assert_eq(lines.size(), 1, "one effect -> one line")
	assert_eq(lines[0], "Burning · 3t · 5/turn", "summarize verbatim")


func test_tooltip_lines_multiple_distinct_effects_keep_order() -> void:
	## Two distinct effects render as two separate lines in the order they
	## appear in the input. Stack() preserves first-appearance order so the
	## tooltip doesn't flicker between rebuilds.
	var lines: Array[String] = StatusEffect.tooltip_lines([
		StatusEffect.burning(3, 5),
		StatusEffect.poisoned(4, 3),
	])
	assert_eq(lines.size(), 2, "two distinct effects -> two lines")
	assert_eq(lines[0], "Burning · 3t · 5/turn", "burning first")
	assert_eq(lines[1], "Poisoned · 4t · 3/turn", "poisoned second")


# ── Stack collapser surfaces (xN) suffix when stacks > 1 ───────────────

func test_tooltip_lines_double_burning_collapses_with_stack_suffix() -> void:
	## Two burns of equal duration collapse to one line with the SUM of
	## damage_per_turn (mirroring the above-the-sprite [BRN] label) AND a
	## "(x2)" suffix so the player can tell at a glance how many times the
	## effect was applied.
	var lines: Array[String] = StatusEffect.tooltip_lines([
		StatusEffect.burning(3, 5),
		StatusEffect.burning(3, 5),
	])
	assert_eq(lines.size(), 1, "two burns collapse to one line")
	assert_eq(lines[0], "Burning · 3t · 10/turn (x2)",
		"summed dpt + (x2) suffix")


func test_tooltip_lines_triple_poison_max_duration_sum_dpt() -> void:
	## Three poison applications collapse to one line. Duration is MAX of
	## the three (4 wins over 2 and 3); damage_per_turn is the SUM (3+3+3
	## = 9). Suffix reads "(x3)".
	var lines: Array[String] = StatusEffect.tooltip_lines([
		StatusEffect.poisoned(2, 3),
		StatusEffect.poisoned(4, 3),
		StatusEffect.poisoned(3, 3),
	])
	assert_eq(lines.size(), 1, "three poisons collapse to one line")
	assert_eq(lines[0], "Poisoned · 4t · 9/turn (x3)",
		"max duration + summed dpt + (x3)")


func test_tooltip_lines_no_stack_suffix_when_distinct_ids() -> void:
	## Two different effect ids don't collapse — each renders its own line
	## with no "(xN)" suffix (stacks is 1 for each).
	var lines: Array[String] = StatusEffect.tooltip_lines([
		StatusEffect.burning(3, 5),
		StatusEffect.frozen(2),
	])
	assert_eq(lines.size(), 2, "distinct ids -> two separate lines")
	# Neither line should carry the (xN) suffix.
	for line: String in lines:
		assert_true(not line.contains("(x"), "no stack suffix on distinct ids")


# ── Per-effect-type render coverage (each summarize() branch lights up) ─

func test_tooltip_lines_frozen_carries_armor_and_skip_turn() -> void:
	## Frozen carries no DPT but a -2 armor mod AND skips_turn — the
	## tooltip surfaces both so the player understands why the target is
	## stuck.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.frozen(2)])
	assert_eq(lines.size(), 1, "frozen renders one line")
	assert_true(lines[0].begins_with("Frozen · 2t"),
		"line starts with display name + duration")
	assert_true(lines[0].contains("-2 armor"),
		"frozen surfaces -2 armor")
	assert_true(lines[0].contains("skip turn"),
		"frozen surfaces skip turn cost")


func test_tooltip_lines_fortified_carries_positive_armor() -> void:
	## Buff: +3 armor renders with a leading "+" so the player can tell
	## the difference from frozen's "-2 armor" at a glance.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.fortified(2, 3)])
	assert_eq(lines.size(), 1, "fortified one line")
	assert_true(lines[0].contains("+3 armor"),
		"positive armor mod uses leading +")


func test_tooltip_lines_mana_shield_carries_absorb_pool() -> void:
	## Mana Shield has no DPT (it's an absorb pool, not a per-turn
	## ticker). The summarize() branch surfaces the absorb-remaining
	## value instead.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.mana_shield(40, 10)])
	assert_eq(lines.size(), 1, "mana_shield one line")
	assert_true(lines[0].contains("40 absorb"),
		"absorb pool surfaced in tooltip")
	assert_true(not lines[0].contains("/turn"),
		"absorb pool is not a per-turn rate")


func test_tooltip_lines_vulnerable_carries_amp_percent() -> void:
	## Run 48 vulnerable: surfaces "+50% taken" so the tooltip tells
	## the player WHY the debuff matters (no DPT, no armor change).
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.vulnerable(2, 50)])
	assert_eq(lines.size(), 1, "vulnerable one line")
	assert_true(lines[0].contains("+50% taken"),
		"vulnerable surfaces amp percent")
	assert_true(not lines[0].contains("/turn"),
		"vulnerable has no /turn segment")


func test_tooltip_lines_stunned_carries_skip_turn() -> void:
	## Run 47 stun: carries skips_turn but no armor mod (distinct from
	## frozen). Tooltip surfaces "skip turn" so the player understands
	## the cost.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.stunned(1)])
	assert_eq(lines.size(), 1, "stunned one line")
	assert_true(lines[0].contains("skip turn"),
		"stunned surfaces skip turn")
	assert_true(not lines[0].contains("armor"),
		"stunned has no armor segment (unlike frozen)")


func test_tooltip_lines_regenerating_carries_positive_heal_per_turn() -> void:
	## Run 49 regenerating: surfaces "+6 HP/turn" as a distinct segment
	## from the DoT line above ("6/turn") so a player glancing at the
	## tooltip can't confuse a heal with a damage tick.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.regenerating(3, 6)])
	assert_eq(lines.size(), 1, "regenerating one line")
	assert_true(lines[0].contains("+6 HP/turn"),
		"regenerating surfaces heal rate")
	assert_true(not lines[0].contains("6/turn"),
		"heal rate is NOT formatted like a DoT")


func test_tooltip_lines_bleed_carries_dpt_at_apply_time() -> void:
	## Run 46 bleed: dpt is computed at apply-time from max_hp * pct. A
	## 200-HP target at 8% bleeds for 16/turn — the tooltip shows the
	## locked dpt, not the raw percent.
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.bleed(3, 200, 8)])
	assert_eq(lines.size(), 1, "bleed one line")
	assert_eq(lines[0], "Bleeding · 3t · 16/turn",
		"bleed shows locked dpt, not percent")


# ── Defensive cases — bad input doesn't crash the tooltip ───────────────

func test_tooltip_lines_non_dictionary_entries_dropped() -> void:
	## A malformed effect list (e.g. a hand-edited save where one entry
	## came back as a string) doesn't crash — stack() silently drops the
	## non-dict entries and tooltip_lines forwards the cleaned output.
	var lines: Array[String] = StatusEffect.tooltip_lines([
		"not a dict",
		StatusEffect.burning(3, 5),
		42,
		null,
	])
	assert_eq(lines.size(), 1, "only the one valid dict survives")
	assert_eq(lines[0], "Burning · 3t · 5/turn",
		"valid entry still renders correctly")


func test_tooltip_lines_empty_id_entries_dropped() -> void:
	## A dict with an empty id is also dropped by stack() — without an id
	## the engine has no way to apply the effect, so it shouldn't surface
	## in the tooltip either.
	var lines: Array[String] = StatusEffect.tooltip_lines([
		{"id": "", "name": "Mystery", "duration": 3},
		StatusEffect.burning(3, 5),
	])
	assert_eq(lines.size(), 1, "empty-id entry dropped, burn survives")
	assert_eq(lines[0], "Burning · 3t · 5/turn",
		"surviving entry renders")


func test_tooltip_lines_unknown_id_still_renders() -> void:
	## A future / unknown effect id (e.g. a save from a newer build) still
	## renders — summarize() / display_name() / short_code() all have
	## fallbacks for unknown ids so the tooltip never goes blank.
	var lines: Array[String] = StatusEffect.tooltip_lines([
		{"id": "future_buff", "name": "Future Buff", "duration": 4},
	])
	assert_eq(lines.size(), 1, "unknown id still renders one line")
	assert_true(lines[0].contains("Future Buff"),
		"display name surfaced via fallback")
	assert_true(lines[0].contains("4t"),
		"duration always carried regardless of id")


func test_tooltip_lines_zero_duration_still_renders() -> void:
	## A 0-turn effect (about to expire on next tick) still renders — the
	## tooltip is a snapshot of THIS turn, and "0t" is meaningful info
	## (the player can plan around the imminent expiry).
	var lines: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.burning(0, 5)])
	assert_eq(lines.size(), 1, "0-duration still surfaces")
	assert_true(lines[0].contains("0t"), "duration shows as 0t")


# ── Mixed stack regression: distinct buffs + a stacked DoT ─────────────

func test_tooltip_lines_mixed_stack_and_distinct_renders_correctly() -> void:
	## Realistic enemy mid-fight: stacked poison + a single burn + a
	## stunned. Stacks line gets the suffix, the singles don't, order is
	## preserved.
	var lines: Array[String] = StatusEffect.tooltip_lines([
		StatusEffect.poisoned(4, 3),
		StatusEffect.poisoned(4, 3),
		StatusEffect.burning(3, 5),
		StatusEffect.stunned(1),
	])
	assert_eq(lines.size(), 3, "two distinct + one stacked = 3 lines")
	assert_eq(lines[0], "Poisoned · 4t · 6/turn (x2)",
		"poison stacked with summed dpt")
	assert_eq(lines[1], "Burning · 3t · 5/turn",
		"burning lone, no suffix")
	assert_true(lines[2].begins_with("Stunned · 1t"),
		"stunned lone, no suffix")
	assert_true(not lines[1].contains("(x"),
		"single burn has no stack suffix")
	assert_true(not lines[2].contains("(x"),
		"single stun has no stack suffix")


func test_tooltip_lines_returns_typed_array_of_strings() -> void:
	## Lock the return type so a future caller doing
	## `for line: String in tooltip_lines(...)` doesn't break under a
	## refactor that returns Array[Variant].
	var lines: Array[String] = StatusEffect.tooltip_lines([])
	assert_true(lines is Array, "returns an Array")
	# Push a known-good entry through; if the inner type were wrong, the
	# typed iteration below would runtime-fail.
	var nonempty: Array[String] = StatusEffect.tooltip_lines(
		[StatusEffect.burning(3, 5)])
	for line: String in nonempty:
		assert_true(line.length() > 0, "each entry is a non-empty String")
