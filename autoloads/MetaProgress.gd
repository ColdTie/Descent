extends Node
## Run 36: persistent meta-progression across runs.
##
## Tracks SHARDS (a soft currency earned per run from floors / bosses / wins),
## OWNED_PERKS (purchased with shards from the MetaScreen), and EQUIPPED_PERKS
## (the subset active at the start of the next run — capped at Perks.MAX_EQUIPPED).
##
## Distinct from GameState's per-run save:
##  - GameState.SAVE_PATH (descent_save.json) is wiped on death / win / new run.
##  - MetaProgress.SAVE_PATH (descent_meta.json) survives all of those — it's
##    the loop-closer the Run 28 save was prep work for.
##
## File I/O matches GameState's pattern (FileAccess + JSON + best-effort) so the
## web `user://` IndexedDB path behaves identically. Versioned for forward
## compat; the apply path defaults missing fields to safe values so adding a
## perk or stat later won't reject older meta saves.

signal shards_changed(total: int, delta: int)
signal perk_unlocked(id: String)
signal perks_equipped_changed(equipped: Array)

const SAVE_PATH: String = "user://descent_meta.json"
const SAVE_VERSION: int = 1

# Per-run reward formula constants — kept here (not in GameState) so the loop
# math lives next to the persistence code. Tuned so a typical death at floor
# 5-7 pays ~10 shards (one cheap perk every 2-3 runs) and a full clear pays
# ~60 shards (a full perk per win).
const SHARDS_PER_FLOOR: int = 1
const SHARDS_PER_BOSS: int = 4
const SHARDS_PER_WIN: int = 25
const SHARDS_PER_FIRST_CLASS_WIN: int = 10  # one-time bonus per class
# Run 37: one-time bonus for the very first time an achievement is unlocked
# across the player's entire meta lifetime. Repeat unlocks (achievement gets
# re-earned on a later run) pay nothing — the audience-score per-run reward
# still fires every time via Achievements.unlock.
const SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK: int = 5

var shards: int = 0
var owned_perks: Array[String] = []
var equipped_perks: Array[String] = []
var total_runs: int = 0
var total_wins: int = 0
var best_floor: int = 0
var best_score: int = 0
# `classes_cleared` tracks which class ids have ever won a run (for the
# first-class-win shard bonus). Keyed by class id, value true.
var classes_cleared: Dictionary = {}
# Run 37: tracks every achievement id ever unlocked across all runs. Keyed by
# achievement id, value true. Used both for the lifetime-bonus payout gate
# (each id pays once) AND for the MetaScreen achievements gallery.
var lifetime_achievements: Dictionary = {}
# Run 38: lifetime boss kill counter — survives runs so the bossbane milestone
# perk can gate behind the player's actual boss-killing history rather than a
# per-run reset. GameState.bosses_slain still tracks the in-run count; this
# adds across run_end calls.
var lifetime_bosses_slain: int = 0


func _ready() -> void:
	## Load on boot so the title screen can show CONTINUE-like cues for
	## meta progress (shard balance) before any scene queries us.
	load_from_disk()


# ── Currency ──────────────────────────────────────────────────────────────

func award_shards(amount: int) -> int:
	## Pure: add to the wallet, emit, return the new total. Negative / zero
	## amounts are ignored so callers don't need to gate on >0 themselves.
	if amount <= 0:
		return shards
	shards += amount
	shards_changed.emit(shards, amount)
	return shards


func spend_shards(amount: int) -> bool:
	## Deduct or refuse. Returns false on insufficient funds so the caller
	## (purchase flow) can keep the UI in a sane state without optimistic
	## writes.
	if amount <= 0 or shards < amount:
		return false
	shards -= amount
	shards_changed.emit(shards, -amount)
	return true


# ── Perks ─────────────────────────────────────────────────────────────────

func is_owned(perk_id: String) -> bool:
	return owned_perks.has(perk_id)


func is_equipped(perk_id: String) -> bool:
	return equipped_perks.has(perk_id)


func lifetime_stats() -> Dictionary:
	## Run 38: snapshot of the lifetime stats Perks milestone gating reads.
	## Pulled out so a future requirement type adds in one place (this map
	## + a Perks.requirement_text branch + a Perks.is_milestone_unlocked
	## case).
	return {
		"best_floor": best_floor,
		"total_wins": total_wins,
		"bosses_slain": lifetime_bosses_slain,
	}


func is_perk_milestone_unlocked(perk_id: String) -> bool:
	## Run 38: gate that BOTH the purchase path AND the MetaScreen card
	## render use, so the lock state is consistent. Perks without a
	## `requires` clause always pass this check.
	return Perks.is_milestone_unlocked(perk_id, lifetime_stats())


func purchase_perk(perk_id: String) -> bool:
	## Buy a perk with shards. Returns false on unknown id / already owned /
	## insufficient funds / milestone locked. On success the perk is added
	## to `owned_perks` but NOT auto-equipped — the player picks the
	## loadout separately so buying a 3rd perk doesn't silently displace
	## one of their actives.
	var cost: int = Perks.cost(perk_id)
	if cost < 0:
		return false
	if owned_perks.has(perk_id):
		return false
	# Run 38: defense in depth — even if the UI passes the click through, a
	# milestone-locked perk refuses at the wallet layer so a hand-crafted
	# call can't bypass the gate.
	if not is_perk_milestone_unlocked(perk_id):
		return false
	if not spend_shards(cost):
		return false
	owned_perks.append(perk_id)
	perk_unlocked.emit(perk_id)
	save_to_disk()
	return true


func equip_cap() -> int:
	## Run 39: single read of the dynamic equip cap. Pulled out so the
	## MetaScreen UI and the equip_perk gate (below) read the same value.
	## A future cap bump only edits Perks.max_equipped.
	return Perks.max_equipped(lifetime_stats())


func equip_perk(perk_id: String) -> bool:
	## Add an owned perk to the active loadout. Returns false on unknown id,
	## unowned perk, already equipped, or loadout full. The cap is dynamic
	## (Run 39: 2 by default, 3 after the first lifetime win) and consulted
	## here so callers don't have to mirror the rule.
	if not owned_perks.has(perk_id):
		return false
	if equipped_perks.has(perk_id):
		return false
	if equipped_perks.size() >= equip_cap():
		return false
	equipped_perks.append(perk_id)
	perks_equipped_changed.emit(equipped_perks.duplicate())
	save_to_disk()
	return true


## Run 37: Achievement → shards loop.

func is_achievement_unlocked_lifetime(id: String) -> bool:
	return lifetime_achievements.get(id, false)


func total_achievements_unlocked_lifetime() -> int:
	return lifetime_achievements.size()


func award_for_achievement(id: String) -> int:
	## Pay the lifetime-first bonus for an achievement unlock. Returns the
	## shard amount awarded (0 if blank id, already lifetime-unlocked, or
	## already paid out). Persists immediately so a crash before run-end
	## doesn't lose the lifetime mark.
	##
	## Achievements.unlock calls this every time a NEW per-run unlock fires;
	## the lifetime mark is the gate that keeps the payout one-time.
	if id == null or id == "":
		return 0
	if lifetime_achievements.has(id):
		return 0
	lifetime_achievements[id] = true
	var payout: int = SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK
	if payout > 0:
		shards += payout
		shards_changed.emit(shards, payout)
	save_to_disk()
	return payout


func unequip_perk(perk_id: String) -> bool:
	var idx: int = equipped_perks.find(perk_id)
	if idx < 0:
		return false
	equipped_perks.remove_at(idx)
	perks_equipped_changed.emit(equipped_perks.duplicate())
	save_to_disk()
	return true


# ── Run-end shard math ────────────────────────────────────────────────────

func shards_for_run(floor_num: int, bosses_slain: int, won: bool,
		class_id: String = "") -> int:
	## Pure math — no state mutation. Called by `record_run_end` and exposed
	## separately so the post-run UI can show the breakdown before the
	## wallet actually updates.
	var total: int = floor_num * SHARDS_PER_FLOOR + bosses_slain * SHARDS_PER_BOSS
	if won:
		total += SHARDS_PER_WIN
		if class_id != "" and not classes_cleared.has(class_id):
			total += SHARDS_PER_FIRST_CLASS_WIN
	return total


func record_run_end(floor_num: int, bosses_slain: int, won: bool,
		score: int = 0, class_id: String = "") -> int:
	## End-of-run hook: pay shards, bump lifetime stats, and persist. Returns
	## the shard amount awarded so callers (Win/Death screens) can display it.
	## Order matters here:
	##  1. Compute payout BEFORE marking `classes_cleared` so the
	##     first-class-win bonus reads correctly on the run that earns it.
	##  2. Bump stats, then mark the class cleared.
	##  3. Award shards (emits signal AFTER stats update so the HUD sees
	##     consistent values).
	##  4. Single save_to_disk at the end so we only write once per run.
	var payout: int = shards_for_run(floor_num, bosses_slain, won, class_id)
	total_runs += 1
	if floor_num > best_floor:
		best_floor = floor_num
	if score > best_score:
		best_score = score
	if won:
		total_wins += 1
		if class_id != "":
			classes_cleared[class_id] = true
	# Run 38: bosses always add to the lifetime tally — even on a death-run
	# the kills already happened. Negative guard for defensive callers that
	# pass an unexpected -1.
	if bosses_slain > 0:
		lifetime_bosses_slain += bosses_slain
	if payout > 0:
		shards += payout
		shards_changed.emit(shards, payout)
	save_to_disk()
	return payout


# ── Persistence ───────────────────────────────────────────────────────────

func snapshot() -> Dictionary:
	var owned_copy: Array = []
	for s: String in owned_perks:
		owned_copy.append(s)
	var eq_copy: Array = []
	for s: String in equipped_perks:
		eq_copy.append(s)
	var cc_copy: Dictionary = {}
	for k: Variant in classes_cleared.keys():
		cc_copy[String(k)] = bool(classes_cleared[k])
	# Run 37: lifetime achievement record, persisted alongside the wallet.
	var la_copy: Dictionary = {}
	for k: Variant in lifetime_achievements.keys():
		la_copy[String(k)] = bool(lifetime_achievements[k])
	return {
		"version": SAVE_VERSION,
		"shards": shards,
		"owned_perks": owned_copy,
		"equipped_perks": eq_copy,
		"total_runs": total_runs,
		"total_wins": total_wins,
		"best_floor": best_floor,
		"best_score": best_score,
		"classes_cleared": cc_copy,
		"lifetime_achievements": la_copy,
		# Run 38: cumulative boss kill counter.
		"lifetime_bosses_slain": lifetime_bosses_slain,
	}


func apply_snapshot(data: Dictionary) -> bool:
	## Restore state. Defensive: missing fields default to safe zero/empty
	## values so a future SAVE_VERSION rev can drop or rename fields without
	## blowing away the player's wallet. Returns false only on completely
	## bogus input (null / empty) — every other case is recoverable.
	if data == null or data.is_empty():
		return false
	shards = int(data.get("shards", 0))
	owned_perks.clear()
	for v: Variant in data.get("owned_perks", []):
		owned_perks.append(String(v))
	# Run 39: load lifetime stats BEFORE trimming equipped, because the
	# equip cap is now dynamic (`Perks.max_equipped(lifetime_stats())`) — a
	# save with 3 equipped perks + a banked win should restore all 3, not
	# get silently trimmed to 2 because we read the cap before total_wins.
	total_runs = int(data.get("total_runs", 0))
	total_wins = int(data.get("total_wins", 0))
	best_floor = int(data.get("best_floor", 0))
	best_score = int(data.get("best_score", 0))
	# Run 38: pre-Run-38 saves don't carry this — default to 0 so the
	# Bossbane gate is closed for legacy saves until the next boss kill,
	# matching the post-Run-38 baseline. Loaded here (out of original Run-38
	# order) so `lifetime_stats()` returns the post-load value when the
	# dynamic equip cap is computed below.
	lifetime_bosses_slain = int(data.get("lifetime_bosses_slain", 0))
	equipped_perks.clear()
	# Defensive equip cap: trim if a save somehow contains more than the
	# active dynamic cap (a save written when the player had 3 slots, then
	# the metaprogress was reset, would otherwise restore a 3-slot loadout
	# the player no longer qualifies for).
	var dyn_cap: int = Perks.max_equipped(lifetime_stats())
	for v: Variant in data.get("equipped_perks", []):
		if equipped_perks.size() >= dyn_cap:
			break
		equipped_perks.append(String(v))
	# Trim equipped to only those still owned in case a perk was removed
	# from DEFS or the save dict is partially corrupt.
	var filtered: Array[String] = []
	for s: String in equipped_perks:
		if owned_perks.has(s) and Perks.DEFS.has(s):
			filtered.append(s)
	equipped_perks = filtered
	classes_cleared = {}
	var raw_cc: Dictionary = data.get("classes_cleared", {})
	for k: Variant in raw_cc.keys():
		classes_cleared[String(k)] = bool(raw_cc[k])
	# Run 37: tolerate older saves (pre-Run-37) that don't carry this field —
	# default to empty so the next achievement unlock still pays out.
	lifetime_achievements = {}
	var raw_la: Dictionary = data.get("lifetime_achievements", {})
	for k: Variant in raw_la.keys():
		lifetime_achievements[String(k)] = bool(raw_la[k])
	# (lifetime_bosses_slain is loaded earlier in this function — see the
	#  Run 39 reorder comment near the top.)
	return true


func save_to_disk() -> bool:
	## Test isolation: bare `.new()` instances (the test suite's fresh-meta
	## pattern) are NOT in the scene tree — skip disk I/O so a unit test of
	## purchase/equip can't leak shards into the real user save. The
	## autoload at runtime is always in the tree, so the live game saves
	## normally.
	if not is_inside_tree():
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(snapshot()))
	f.close()
	return true


func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed as Dictionary
	# Version gate: if a future format ever breaks compat we'd refuse here.
	# Right now SAVE_VERSION is 1 and every field is optional in apply, so a
	# mismatch is rejected to avoid silent half-applies.
	if int(d.get("version", 0)) != SAVE_VERSION:
		return false
	return apply_snapshot(d)


func reset_all() -> void:
	## Wipe everything (dev / "reset progress" button). Persists immediately.
	shards = 0
	owned_perks.clear()
	equipped_perks.clear()
	total_runs = 0
	total_wins = 0
	best_floor = 0
	best_score = 0
	classes_cleared.clear()
	lifetime_achievements.clear()
	lifetime_bosses_slain = 0
	save_to_disk()
	shards_changed.emit(0, 0)
	perks_equipped_changed.emit(equipped_perks.duplicate())
