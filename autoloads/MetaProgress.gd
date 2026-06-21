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
# Run 42: emitted whenever the player swaps the equipped skin for a class, or
# a fresh skin becomes available (a class win bumps the per-class counter
# across an unlock threshold). MetaScreen rebuilds its SKINS tab on this.
signal skins_changed

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
# Run 42: per-class win counter — bumped on every win in `record_run_end`,
# distinct from `classes_cleared` (which is a one-time flag for the first
# class-win shard bonus). Drives the Skins unlock threshold (1 win → veteran
# skin, 3 wins → mastery skin). Keyed by class id, value int. Additive — a
# pre-Run-42 save loads with an empty dict and the dict back-fills as the
# player banks wins from then on.
var class_wins: Dictionary = {}
# Run 42: per-class chosen skin. Keyed by class id, value the skin id the
# player has equipped (one slot per class). Missing key → default skin via
# `Skins.default_for(class_id)`. Owned-ness is derived from `class_wins` +
# `Skins.is_unlocked`; there's no separate `owned_skins` field because
# skins auto-unlock on win-count and can't be sold back or hidden.
var equipped_skins: Dictionary = {}

# Run 41: persistent accessibility preferences.
# Runs 35/39/40 each reset their pause-menu toggle in `GameState.start_run()`
# for consistency with the per-run state, which forced a player who needs
# (e.g.) 1.5× text or the colorblind palette to re-toggle on every new run —
# real friction for the players these toggles exist to help. This dict is the
# persistent store; `GameState.start_run()` seeds the per-run fields from here
# (falling back to shipping defaults when MetaProgress isn't registered, i.e.
# `--script` test mode), and the toggle setters write back here so a flip
# survives the next class-pick. The pause menu still controls the live value
# via GameState — this only changes the seed source.
const ACCESS_PREF_KEYS: Array[String] = [
	"screen_shake",
	"damage_numbers",
	"colorblind",
	"text_size_scale",
]
var accessibility_prefs: Dictionary = _accessibility_prefs_defaults()


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
	## Run 43: `classes_won` is the count of distinct classes that have ever
	## banked a win — derived from `class_wins.size()` (Run 42's per-class
	## counter). Distinct from `total_wins` (which a player can rack up by
	## winning with the same class repeatedly); the 4th-slot milestone is
	## explicitly the "completionist" gate, so it must count classes, not runs.
	return {
		"best_floor": best_floor,
		"total_wins": total_wins,
		"bosses_slain": lifetime_bosses_slain,
		"classes_won": class_wins.size(),
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


# ── Run 41: persistent accessibility prefs ────────────────────────────────

static func _accessibility_prefs_defaults() -> Dictionary:
	## Shipping defaults — the values that ship in a fresh meta save. Kept as
	## a static helper so the field initializer, the `apply_snapshot` fill-in
	## path, and `reset_all` share the same source of truth.
	return {
		"screen_shake": true,
		"damage_numbers": true,
		"colorblind": false,
		"text_size_scale": 1.0,
	}


func get_access_pref(key: String, default_val: Variant) -> Variant:
	## Single read path for the seed step in `GameState.start_run()`. Returns
	## the caller's default on unknown keys so a future toggle being added to
	## the cycle button (or removed) degrades gracefully.
	if not ACCESS_PREF_KEYS.has(key):
		return default_val
	return accessibility_prefs.get(key, default_val)


func set_access_pref(key: String, value: Variant) -> bool:
	## Persist a single accessibility preference. Returns true on a real write.
	## Called by the GameState setters whenever the player flips a pause-menu
	## toggle, so the next run inherits the same setting. No-op + false for
	## unknown keys — defense in depth so a typo from a future toggle can't
	## quietly extend the dict with a key nothing else reads.
	if not ACCESS_PREF_KEYS.has(key):
		return false
	if accessibility_prefs.get(key, null) == value:
		return false
	accessibility_prefs[key] = value
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


# ── Run 42: alt-color class skins ─────────────────────────────────────────

func class_win_count(class_id: String) -> int:
	## Single read of the per-class lifetime win counter — the gate Skins
	## unlock against. Defaults to 0 for an unknown class id so the skin
	## tab can iterate every class without a separate has() check.
	if class_id == "":
		return 0
	return int(class_wins.get(class_id, 0))


func is_skin_unlocked(skin_id: String) -> bool:
	## Wraps `Skins.is_unlocked` against the live per-class counter so the
	## MetaScreen card render and the `equip_skin` gate read the same rule.
	## Unknown skin ids fall through to false (Skins itself fails closed).
	var cid: String = Skins.class_id_for(skin_id)
	if cid == "":
		return false
	return Skins.is_unlocked(skin_id, class_win_count(cid))


func equipped_skin_for(class_id: String) -> String:
	## Returns the skin id currently equipped for this class — the explicit
	## `equipped_skins[class_id]` if present and still unlocked, otherwise
	## the class's default. The "still unlocked" gate matters because a save
	## written when the player had an alt skin equipped could be loaded
	## after a `reset_all()` wiped their class_wins — falling through to
	## the default skin keeps the live render honest. Unknown class id
	## returns "" so BattleScene can branch on the empty string and skip
	## the tint write entirely.
	if class_id == "":
		return ""
	var raw: Variant = equipped_skins.get(class_id, null)
	if raw != null:
		var sid: String = String(raw)
		if sid != "" and is_skin_unlocked(sid):
			return sid
	return Skins.default_for(class_id)


func equipped_skin_tint(class_id: String) -> Color:
	## Convenience for BattleScene._build_encounter — single call returns the
	## live tint Color to assign to `_hero.tint`. Unknown class id → WHITE
	## (no tint), matching the Combatant default so the hero sprite renders
	## untinted instead of crashing.
	var sid: String = equipped_skin_for(class_id)
	return Skins.tint_for(sid)


func equip_skin(skin_id: String) -> bool:
	## Pick a skin for a class. Returns false on unknown skin id, locked
	## skin (player hasn't earned it yet), or no-op write (the skin is
	## already the equipped one for its class). Defense in depth: even if
	## the MetaScreen button is somehow clicked on a locked card, this
	## refuses the write so a hand-crafted call can't cheat unlocks.
	var cid: String = Skins.class_id_for(skin_id)
	if cid == "":
		return false
	if not is_skin_unlocked(skin_id):
		return false
	if equipped_skins.get(cid, "") == skin_id:
		return false
	equipped_skins[cid] = skin_id
	skins_changed.emit()
	save_to_disk()
	return true


func unequip_skin(class_id: String) -> bool:
	## Swap a class back to its default skin. Returns false when nothing
	## non-default was equipped (so the MetaScreen button on a default-equipped
	## card is a no-op rather than a fake save). Internally this clears the
	## `equipped_skins[class_id]` entry — the read path
	## (`equipped_skin_for`) falls through to the default.
	if class_id == "":
		return false
	if not equipped_skins.has(class_id):
		return false
	equipped_skins.erase(class_id)
	skins_changed.emit()
	save_to_disk()
	return true


func unlocked_skin_count() -> int:
	## How many skins are currently unlocked across all classes — used by the
	## MetaScreen SKINS tab header. Pure scan over Skins.DEFS so adding a new
	## skin auto-participates without code changes here.
	var total: int = 0
	for sid: String in Skins.all_ids():
		if is_skin_unlocked(sid):
			total += 1
	return total


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
			# Run 42: bump the per-class lifetime counter so Skins.is_unlocked
			# sees the new threshold immediately. The counter is additive —
			# `classes_cleared` is the first-win bonus gate, this is the
			# unlock ramp. Both stay live so the existing first-class-win
			# shard payout keeps working unchanged.
			class_wins[class_id] = int(class_wins.get(class_id, 0)) + 1
	# Run 38: bosses always add to the lifetime tally — even on a death-run
	# the kills already happened. Negative guard for defensive callers that
	# pass an unexpected -1.
	if bosses_slain > 0:
		lifetime_bosses_slain += bosses_slain
	if payout > 0:
		shards += payout
		shards_changed.emit(shards, payout)
	save_to_disk()
	# Run 42: a win can cross a skin's unlock threshold. Emit AFTER the save
	# so a MetaScreen listener that rebuilds on this signal sees the same
	# class_wins value that just got persisted. Cheap to emit even on a
	# death (the MetaScreen rebuild is a single grid repaint and no skin
	# state changed) so we don't bother gating on `won`.
	skins_changed.emit()
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
	# Run 41: deep-copy the prefs dict so a future caller mutating the
	# snapshot output can't bleed into live state.
	var ap_copy: Dictionary = accessibility_prefs.duplicate(true)
	# Run 42: per-class win counts + equipped skin per class. Both are
	# string-keyed dicts so JSON round-trips cleanly. Deep-copy not needed
	# because the values are primitive (int / String).
	var cw_copy: Dictionary = {}
	for k: Variant in class_wins.keys():
		cw_copy[String(k)] = int(class_wins[k])
	var es_copy: Dictionary = {}
	for k: Variant in equipped_skins.keys():
		es_copy[String(k)] = String(equipped_skins[k])
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
		# Run 41: persistent pause-menu accessibility toggles.
		"accessibility_prefs": ap_copy,
		# Run 42: per-class win counter + equipped skin per class.
		"class_wins": cw_copy,
		"equipped_skins": es_copy,
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
	# Run 43: class_wins also threads into the dynamic equip cap via
	# lifetime_stats().classes_won (the 4th-slot milestone). Loaded BEFORE the
	# equipped_perks trim for the same reason Run 39 moved lifetime_bosses_slain
	# up — otherwise a save with 4 equipped perks + an all-class clear would
	# silently trim back to 3. Negative count coercion mirrors the post-trim
	# Run-42 load below; we duplicate it here because the post-trim load gets
	# overwritten so the trim block needs a primed dict.
	class_wins = {}
	var raw_cw_early: Variant = data.get("class_wins", {})
	if raw_cw_early is Dictionary:
		var cw_early: Dictionary = raw_cw_early as Dictionary
		for k: Variant in cw_early.keys():
			var v: int = int(cw_early[k])
			if v < 0:
				v = 0
			class_wins[String(k)] = v
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
	# Run 41: accessibility prefs — start from defaults and overlay any keys
	# the save carries. Missing-key tolerance keeps pre-Run-41 saves loading
	# cleanly (purely additive — no SAVE_VERSION bump). Type coercion: bool()
	# on the on/off toggles so a stale int 0/1 still reads right; the text
	# scale is rebuilt as a float and snapped to a known option via the same
	# helper the GameState side uses, so a hand-edited save can't park the
	# cycle on an in-between value.
	accessibility_prefs = _accessibility_prefs_defaults()
	var raw_ap: Variant = data.get("accessibility_prefs", {})
	if raw_ap is Dictionary:
		var ap_dict: Dictionary = raw_ap as Dictionary
		if ap_dict.has("screen_shake"):
			accessibility_prefs["screen_shake"] = bool(ap_dict["screen_shake"])
		if ap_dict.has("damage_numbers"):
			accessibility_prefs["damage_numbers"] = bool(ap_dict["damage_numbers"])
		if ap_dict.has("colorblind"):
			accessibility_prefs["colorblind"] = bool(ap_dict["colorblind"])
		if ap_dict.has("text_size_scale"):
			var ts_raw: float = float(ap_dict["text_size_scale"])
			accessibility_prefs["text_size_scale"] = _snap_text_size_pref(ts_raw)
	# Run 42 + Run 43: `class_wins` is loaded earlier (before the equipped_perks
	# trim) so the Run-43 4th-slot milestone reads the post-load count when the
	# dynamic equip cap is computed. The block formerly here is intentionally
	# absent — the field is already populated above.
	# Equipped skins: drop entries whose skin_id isn't in Skins.DEFS (defense
	# against future skin removal) AND whose class_id no longer has that skin
	# unlocked (defense against a save where the player had an alt skin
	# equipped, then a `reset_all` wiped class_wins). A stale entry falls
	# through to the default via `equipped_skin_for` either way, but trimming
	# at load keeps the dict honest so the snapshot of the next save doesn't
	# round-trip phantom entries.
	equipped_skins = {}
	var raw_es: Variant = data.get("equipped_skins", {})
	if raw_es is Dictionary:
		var es_dict: Dictionary = raw_es as Dictionary
		for k: Variant in es_dict.keys():
			var cid_k: String = String(k)
			var sid: String = String(es_dict[k])
			if not Skins.DEFS.has(sid):
				continue
			if Skins.class_id_for(sid) != cid_k:
				continue
			# class_wins is loaded first (above), so is_skin_unlocked reads
			# the post-load value.
			if not Skins.is_unlocked(sid, class_win_count(cid_k)):
				continue
			equipped_skins[cid_k] = sid
	return true


func _snap_text_size_pref(scale: float) -> float:
	## Mirror GameState._nearest_text_size_option so a corrupted persistent
	## text-size pref collapses to a known cycle option. Local copy (rather
	## than calling into GameState) because MetaProgress is loaded first on
	## boot — touching the GameState autoload from `_ready -> load_from_disk
	## -> apply_snapshot` would risk a circular load order in test mode.
	var script: GDScript = load("res://autoloads/GameState.gd")
	var opts: Array = script.TEXT_SIZE_OPTIONS
	var default_v: float = script.TEXT_SIZE_DEFAULT
	if opts.is_empty():
		return default_v
	var best: float = float(opts[0])
	var best_diff: float = abs(scale - best)
	for opt: Variant in opts:
		var d: float = abs(scale - float(opt))
		if d < best_diff:
			best = float(opt)
			best_diff = d
	return best


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
	# Run 41: a reset wipes accessibility prefs back to the shipping defaults
	# alongside the wallet so the player's next run starts clean. A returning
	# player who liked their settings can re-toggle from the pause menu.
	accessibility_prefs = _accessibility_prefs_defaults()
	# Run 42: a reset wipes per-class wins + equipped skins. Without this the
	# player would keep their unlocked skin tints across a "reset progress",
	# which would look like the reset didn't reset.
	class_wins.clear()
	equipped_skins.clear()
	save_to_disk()
	shards_changed.emit(0, 0)
	perks_equipped_changed.emit(equipped_perks.duplicate())
	skins_changed.emit()
