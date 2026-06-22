## Run 44 tests: skin + perk-slot unlock toasts on the WinScreen.
##
## The scene wiring itself can't run under `--script` mode (no autoloads,
## no SceneTree paint), but every input to the WinScreen toast — the pre/post
## delta the Main.gd hook computes — is pure data. This suite exercises both
## helpers (`Skins.newly_unlocked_in_range`, `Perks.slots_gained`) end-to-end
## through realistic play scenarios so a future refactor can't quietly break
## the win-side discoverability the milestone unlocks rely on.
##
## MetaProgress instances are spawned via GDScript.new() (matching the
## Run 36/37/38/39/40/41/42/43 detached-instance pattern) so the autoload's
## `_ready -> load_from_disk` path doesn't touch the player's real meta save.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun44


var PERKS: GDScript = load("res://src/data/Perks.gd")
var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


# ── Skins.newly_unlocked_in_range — the skin half of the toast ─────────────

func test_skins_newly_unlocked_first_brawler_win() -> void:
	## Going from 0 → 1 class wins unlocks the veteran skin (threshold = 1).
	## The default skin (threshold = 0) should NOT appear — it was already
	## unlocked at win 0, so the threshold is not strictly above prev.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("brawler", 0, 1)
	assert_eq(unlocked.size(), 1, "first brawler win unlocks exactly one skin")
	assert_true(unlocked.has("brawler_onyx"), "brawler_onyx threshold = 1")


func test_skins_newly_unlocked_mastery_skin_at_third_win() -> void:
	## Going from 2 → 3 unlocks the mastery skin (threshold = 3). Veteran
	## was already unlocked at win 1, so it doesn't reappear in the delta.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("rogue", 2, 3)
	assert_eq(unlocked.size(), 1, "3rd rogue win unlocks one skin")
	assert_true(unlocked.has("rogue_crimson"), "rogue_crimson threshold = 3")


func test_skins_newly_unlocked_between_two_thresholds() -> void:
	## A jump from 0 → 3 (pathological — record_run_end only bumps by 1, but
	## the helper has no callsite-shape coupling) unlocks BOTH veteran and
	## mastery. This is the property the helper is designed around — any
	## future "double win" event would correctly fire both toasts.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("arcanist", 0, 3)
	assert_eq(unlocked.size(), 2, "0 → 3 jump unlocks both alts")
	assert_true(unlocked.has("arcanist_frost"), "veteran in delta")
	assert_true(unlocked.has("arcanist_solar"), "mastery in delta")


func test_skins_newly_unlocked_no_change_returns_empty() -> void:
	## A win that doesn't cross any threshold (e.g. 2nd win for a class that
	## already cleared once but not yet three times) returns no toasts.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("brawler", 1, 2)
	assert_eq(unlocked.size(), 0, "1 → 2 crosses no skin threshold")


func test_skins_newly_unlocked_equal_bounds_returns_empty() -> void:
	## prev == new is a degenerate range (no win happened) — must return
	## empty rather than re-toasting an already-unlocked skin.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("brawler", 3, 3)
	assert_eq(unlocked.size(), 0, "no win → no toast even at thresholds")


func test_skins_newly_unlocked_backwards_returns_empty() -> void:
	## A backwards range (new < prev, only possible via a corrupted save)
	## must return empty — the helper never toasts un-unlocks.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("brawler", 3, 0)
	assert_eq(unlocked.size(), 0, "backwards range → empty")


func test_skins_newly_unlocked_negative_clamps_to_zero() -> void:
	## A negative prev (defensive against a hand-edited save) clamps to 0 so
	## the toast still fires correctly on the first win.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("brawler", -5, 1)
	assert_eq(unlocked.size(), 1, "negative prev clamps to 0, win 1 still toasts")
	assert_true(unlocked.has("brawler_onyx"), "brawler_onyx in delta")


func test_skins_newly_unlocked_empty_class_id_returns_empty() -> void:
	## Empty class id (e.g. `_record_meta_end` called before hero_class was
	## set — shouldn't happen but the helper fails closed) returns empty.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("", 0, 3)
	assert_eq(unlocked.size(), 0, "empty class id → empty delta")


func test_skins_newly_unlocked_unknown_class_returns_empty() -> void:
	## Unknown class id has no skins in `for_class`, so the iteration is
	## empty regardless of the win range.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("ranger", 0, 3)
	assert_eq(unlocked.size(), 0, "unknown class → empty delta")


func test_skins_newly_unlocked_class_isolation() -> void:
	## Bumping brawler wins does NOT surface rogue or arcanist skins — the
	## per-class wallet is the correct boundary.
	var unlocked: Array[String] = Skins.newly_unlocked_in_range("brawler", 0, 3)
	for sid: String in unlocked:
		assert_eq(Skins.class_id_for(sid), "brawler",
			"every unlocked skin belongs to brawler: %s" % sid)


# ── Perks.slots_gained — the perk-slot half of the toast ──────────────────

func test_perks_slots_gained_first_win_unlocks_third_slot() -> void:
	## Pre-stats: 0 wins / 0 classes_won → cap 2.
	## Post-stats: 1 win / 1 class_won → cap 3 (3rd slot milestone).
	## Delta = 1.
	var prev: Dictionary = {"total_wins": 0, "classes_won": 0}
	var new: Dictionary = {"total_wins": 1, "classes_won": 1}
	assert_eq(PERKS.slots_gained(prev, new), 1,
		"first win unlocks 1 slot (the 3rd)")


func test_perks_slots_gained_third_class_win_unlocks_fourth_slot() -> void:
	## Pre-stats: 2 wins / 2 classes_won → cap 3.
	## Post-stats: 3 wins / 3 classes_won → cap 4 (4th slot milestone).
	## Delta = 1.
	var prev: Dictionary = {"total_wins": 2, "classes_won": 2}
	var new: Dictionary = {"total_wins": 3, "classes_won": 3}
	assert_eq(PERKS.slots_gained(prev, new), 1,
		"third distinct class clear unlocks 1 slot (the 4th)")


func test_perks_slots_gained_repeat_class_win_zero() -> void:
	## Pre-stats: 1 win / 1 class_won → cap 3.
	## Post-stats: 2 wins / 1 class_won (same-class repeat) → cap 3.
	## Delta = 0 (4th-slot milestone needs distinct classes).
	var prev: Dictionary = {"total_wins": 1, "classes_won": 1}
	var new: Dictionary = {"total_wins": 2, "classes_won": 1}
	assert_eq(PERKS.slots_gained(prev, new), 0,
		"same-class repeat doesn't add a slot")


func test_perks_slots_gained_second_distinct_class_zero() -> void:
	## Pre-stats: 1 win / 1 class_won → cap 3.
	## Post-stats: 2 wins / 2 classes_won → cap 3 (still below the 4th-slot
	## threshold of 3 distinct classes).
	## Delta = 0.
	var prev: Dictionary = {"total_wins": 1, "classes_won": 1}
	var new: Dictionary = {"total_wins": 2, "classes_won": 2}
	assert_eq(PERKS.slots_gained(prev, new), 0,
		"2nd distinct class — still 1 short of 4th slot")


func test_perks_slots_gained_zero_change_when_capped() -> void:
	## Player past every milestone → no further bumps; delta = 0.
	var prev: Dictionary = {"total_wins": 99, "classes_won": 3}
	var new: Dictionary = {"total_wins": 100, "classes_won": 3}
	assert_eq(PERKS.slots_gained(prev, new), 0,
		"win past the 4th slot → no further bump")


func test_perks_slots_gained_negative_clamps_to_zero() -> void:
	## A backwards delta (shouldn't happen — purely defensive against a
	## corrupted save) clamps to 0. Never claim an unlock that didn't occur.
	var prev: Dictionary = {"total_wins": 3, "classes_won": 3}
	var new: Dictionary = {"total_wins": 0, "classes_won": 0}
	assert_eq(PERKS.slots_gained(prev, new), 0,
		"backwards delta clamps to 0")


func test_perks_slots_gained_null_or_bad_input_safe() -> void:
	## Both args are typed Variant — passing null reads as the base cap on
	## both sides, so delta = 0. Defense in depth for a hand-crafted call.
	assert_eq(PERKS.slots_gained(null, null), 0, "null/null → 0")
	assert_eq(PERKS.slots_gained({}, {}), 0, "empty/empty → 0")
	assert_eq(PERKS.slots_gained("garbage", 7), 0, "bad types → 0")


func test_perks_slots_gained_jump_from_zero_to_full_clear() -> void:
	## A first-ever-player end-of-rainbow path: prev = no wins, no classes;
	## new = a single jump to fully unlocked. Tests both milestone bumps
	## contribute additively (matches the Run-43 composability test).
	var prev: Dictionary = {"total_wins": 0, "classes_won": 0}
	var new: Dictionary = {"total_wins": 3, "classes_won": 3}
	assert_eq(PERKS.slots_gained(prev, new),
		PERKS.WIN_BONUS_SLOTS + PERKS.FOURTH_SLOT_BONUS_SLOTS,
		"both milestones fire → +2 slots")


# ── End-to-end: MetaProgress record_run_end ↔ deltas ────────────────────────

func test_e2e_first_win_unlocks_skin_and_slot() -> void:
	## Walks the exact path Main.gd takes: snapshot pre, record_run_end,
	## snapshot post, compute deltas. A first-ever clear as the brawler
	## should produce one skin toast AND one slot toast.
	var mp: Node = _fresh_meta()
	var prev_wins: int = mp.class_win_count("brawler")
	var prev_stats: Dictionary = mp.lifetime_stats()
	# Win as brawler: floor 18, 6 bosses, won=true.
	mp.record_run_end(18, 6, true, 50000, "brawler")
	var new_wins: int = mp.class_win_count("brawler")
	var new_stats: Dictionary = mp.lifetime_stats()
	var skins: Array[String] = Skins.newly_unlocked_in_range("brawler",
		prev_wins, new_wins)
	var slot_delta: int = PERKS.slots_gained(prev_stats, new_stats)
	assert_eq(skins.size(), 1, "first brawler win toasts one skin")
	assert_true(skins.has("brawler_onyx"), "brawler_onyx is the unlock")
	assert_eq(slot_delta, 1, "first ever win also unlocks the 3rd slot")


func test_e2e_second_class_win_skin_only() -> void:
	## A player who already cleared brawler wins their first rogue run: a
	## skin toast fires (rogue_onyx), but the slot already unlocked on the
	## brawler win so the slot delta is 0.
	var mp: Node = _fresh_meta()
	mp.record_run_end(18, 6, true, 50000, "brawler")
	var prev_wins: int = mp.class_win_count("rogue")
	var prev_stats: Dictionary = mp.lifetime_stats()
	mp.record_run_end(18, 6, true, 50000, "rogue")
	var new_wins: int = mp.class_win_count("rogue")
	var new_stats: Dictionary = mp.lifetime_stats()
	var skins: Array[String] = Skins.newly_unlocked_in_range("rogue",
		prev_wins, new_wins)
	var slot_delta: int = PERKS.slots_gained(prev_stats, new_stats)
	assert_eq(skins.size(), 1, "first rogue win toasts one skin")
	assert_true(skins.has("rogue_shadow"), "rogue veteran is the unlock")
	assert_eq(slot_delta, 0, "3rd slot already unlocked from brawler clear")


func test_e2e_third_class_win_unlocks_fourth_slot() -> void:
	## All-classes-clear milestone: brawler + rogue cleared, then a first
	## arcanist clear unlocks both an arcanist skin AND the 4th perk slot.
	var mp: Node = _fresh_meta()
	mp.record_run_end(18, 6, true, 50000, "brawler")
	mp.record_run_end(18, 6, true, 50000, "rogue")
	var prev_wins: int = mp.class_win_count("arcanist")
	var prev_stats: Dictionary = mp.lifetime_stats()
	mp.record_run_end(18, 6, true, 50000, "arcanist")
	var new_wins: int = mp.class_win_count("arcanist")
	var new_stats: Dictionary = mp.lifetime_stats()
	var skins: Array[String] = Skins.newly_unlocked_in_range("arcanist",
		prev_wins, new_wins)
	var slot_delta: int = PERKS.slots_gained(prev_stats, new_stats)
	assert_eq(skins.size(), 1, "first arcanist win toasts one skin")
	assert_true(skins.has("arcanist_frost"), "arcanist veteran is the unlock")
	assert_eq(slot_delta, 1, "third distinct class unlocks the 4th slot")


func test_e2e_mastery_skin_on_third_brawler_win() -> void:
	## A grinder path: three brawler wins. Each crosses a milestone, but
	## only the 3rd surfaces the mastery skin. The slot toast fires on the
	## FIRST win (3rd slot) and never again — slot_delta is 0 on the 2nd
	## and 3rd wins.
	var mp: Node = _fresh_meta()
	# First win: skin + slot
	var pre_w1: int = mp.class_win_count("brawler")
	var pre_s1: Dictionary = mp.lifetime_stats()
	mp.record_run_end(18, 6, true, 50000, "brawler")
	assert_eq(PERKS.slots_gained(pre_s1, mp.lifetime_stats()), 1,
		"win 1 unlocks the 3rd slot")
	assert_true(Skins.newly_unlocked_in_range("brawler", pre_w1,
		mp.class_win_count("brawler")).has("brawler_onyx"),
		"win 1 unlocks the onyx skin")
	# Second win: no skin, no slot
	var pre_w2: int = mp.class_win_count("brawler")
	var pre_s2: Dictionary = mp.lifetime_stats()
	mp.record_run_end(18, 6, true, 50000, "brawler")
	assert_eq(PERKS.slots_gained(pre_s2, mp.lifetime_stats()), 0,
		"win 2 — no further slot")
	assert_eq(Skins.newly_unlocked_in_range("brawler", pre_w2,
		mp.class_win_count("brawler")).size(), 0, "win 2 — no skin toast")
	# Third win: mastery skin, no slot
	var pre_w3: int = mp.class_win_count("brawler")
	var pre_s3: Dictionary = mp.lifetime_stats()
	mp.record_run_end(18, 6, true, 50000, "brawler")
	assert_eq(PERKS.slots_gained(pre_s3, mp.lifetime_stats()), 0,
		"win 3 — no further slot (mastery is skin-only)")
	var w3_skins: Array[String] = Skins.newly_unlocked_in_range("brawler",
		pre_w3, mp.class_win_count("brawler"))
	assert_eq(w3_skins.size(), 1, "win 3 unlocks exactly one skin")
	assert_true(w3_skins.has("brawler_gilded"), "win 3 surfaces the mastery")


func test_e2e_loss_run_no_toasts() -> void:
	## A death-run with bosses slain (so lifetime_bosses_slain bumps) still
	## yields zero skin/slot deltas — these unlocks gate exclusively on wins.
	var mp: Node = _fresh_meta()
	var prev_wins: int = mp.class_win_count("brawler")
	var prev_stats: Dictionary = mp.lifetime_stats()
	mp.record_run_end(12, 4, false, 12000, "brawler")
	var new_wins: int = mp.class_win_count("brawler")
	var new_stats: Dictionary = mp.lifetime_stats()
	assert_eq(Skins.newly_unlocked_in_range("brawler", prev_wins, new_wins).size(),
		0, "loss → no skin toast")
	assert_eq(PERKS.slots_gained(prev_stats, new_stats), 0,
		"loss → no slot toast")
