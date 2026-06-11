extends Node
## Central run state: current floor, hero stats, run seed, etc.

signal floor_changed(floor_num: int)
signal hero_died
signal run_started

var run_seed: int = 0
var floor_num: int = 0
var hero_class: String = ""
var hero_hp: int = 0
var hero_max_hp: int = 0
var hero_xp: int = 0
var hero_level: int = 1
var hero_gold: int = 0
var hero_abilities: Array[String] = []
var hero_base_stats: Dictionary = {}

# Run statistics — for end-of-run score and summary screens
var total_kills: int = 0
var bosses_slain: int = 0

# Run 19: Audience score — DCC reality-show layer. Showy plays earn points
# (crits, lava kills, low-HP wins, achievements). `audience_score_floor` is the
# tally for the current floor; `audience_score` is the run total.
var audience_score: int = 0
var audience_score_floor: int = 0
# Run 19: lava-push kill counter for the "Lava Lord" achievement (run-wide).
var lava_push_kills: int = 0

# Run 19: signal fired whenever audience score changes — drives the HUD blip.
signal audience_gained(amount: int, reason: String)

# Run 20: DCC reality-show layer extension —
# `sponsor_offers_taken` counts sponsor pop-ups consumed; combined with
# `Sponsors.SPONSOR_THRESHOLD` it gates the next offer.
# `patch_notes_seen` tracks which tier-transition patch screens have already
# played (floors 7, 13). Both reset per run.
var sponsor_offers_taken: int = 0
var patch_notes_seen: Array[int] = []

# Run 29: per-id record of sponsors the player has accepted this run. Drives
# the story-arc gating in `Sponsors.slate()` (a "BIG MIKE'S RETURN" card only
# appears once the player has taken `big_mikes_meat`). `sponsor_offers_taken`
# stays as the count used by `sponsors_owed()` — the two are kept in sync,
# but the id-list is the source of truth for prereqs.
var sponsor_offers_taken_ids: Array[String] = []

# Run 21: gold economy. Earned from kills/bosses/floor clears, spent at the
# between-floor Shop. `shop_visits` tracks how many shops have appeared this
# run; the HUD widget animates briefly on every gain.
signal gold_gained(amount: int, reason: String)
signal gold_spent(amount: int, item_id: String)
var shop_visits: int = 0

# Run 31: once-per-run "Merchant's Favor" — a surprise Legendary discount.
# Flips true the first time a shop visit rolls favor (see Shop.roll_merchant_favor).
# Reset by `start_run()` and snapshotted so resume preserves whether the favor
# has already fired for this run.
var merchant_favor_used: bool = false

# Run 27: inventory tracking — ids of shop items the hero currently owns.
# Drives the stats + items HUD panel; recorded by Shop on purchase.
var hero_inventory: Array[String] = []
signal inventory_changed

# Run 27: per-run battle animation speed multiplier. 1.0 = default,
# 1.5 = quick, 2.0 = blitz. All BattleScene inter-action waits and key
# movement tweens divide their durations by this value. Persists across
# floors within a run; reset on `start_run()`.
var battle_speed: float = 1.0

const XP_PER_LEVEL: int = 100
const TOTAL_FLOORS: int = 18

# Run 28: save / resume. A run snapshot is written every time the player drops
# into a fresh floor (a stable checkpoint — combat hasn't started yet) and
# cleared on death / win. Resume restarts the saved floor at full snapshotted
# state. JSON because the web export's `user://` is IndexedDB, and JSON
# round-trips cleanly without touching Godot resource imports.
const SAVE_PATH: String = "user://descent_save.json"
const SAVE_VERSION: int = 1

func start_run(class_id: String, seed_val: int = -1) -> void:
	if seed_val < 0:
		seed_val = randi()
	run_seed = seed_val
	# Duck-typed autoload lookup so this script still compiles under
	# `--script` test mode where autoloads aren't registered (matches the
	# pattern used in Achievements.gd).
	var gr: Node = get_node_or_null("/root/GameRng")
	if gr != null:
		gr.call("reseed", seed_val)
	floor_num = 0
	hero_class = class_id
	hero_xp = 0
	hero_level = 1
	hero_gold = 0
	total_kills = 0
	bosses_slain = 0
	audience_score = 0
	audience_score_floor = 0
	lava_push_kills = 0
	sponsor_offers_taken = 0
	sponsor_offers_taken_ids.clear()
	patch_notes_seen.clear()
	shop_visits = 0
	hero_inventory.clear()
	battle_speed = 1.0
	merchant_favor_used = false
	var cls_data: Dictionary = Classes.get_class_data(class_id)
	hero_max_hp = cls_data.get("hp", 100)
	hero_hp = hero_max_hp
	hero_abilities.clear()
	var raw_abilities: Array = cls_data.get("abilities", [])
	for a: String in raw_abilities:
		hero_abilities.append(a)
	hero_base_stats = cls_data.get("stats", {}).duplicate()
	run_started.emit()

func descend() -> void:
	floor_num += 1
	audience_score_floor = 0
	floor_changed.emit(floor_num)


func award_audience(amount: int, reason: String = "") -> void:
	## Add audience favor — emits a signal so HUD widgets can react.
	## Pure addition; never negative.
	if amount <= 0:
		return
	audience_score += amount
	audience_score_floor += amount
	audience_gained.emit(amount, reason)


func award_gold(amount: int, reason: String = "") -> void:
	## Run 21: add gold and notify HUD widgets. Negative amounts are ignored;
	## use spend_gold() for purchases so the signal split stays clean.
	if amount <= 0:
		return
	hero_gold += amount
	gold_gained.emit(amount, reason)


func spend_gold(amount: int, item_id: String = "") -> bool:
	## Deduct gold for a purchase. Returns false if the hero can't afford it;
	## the caller (Shop) is responsible for gating the button before calling.
	if amount <= 0 or hero_gold < amount:
		return false
	hero_gold -= amount
	gold_spent.emit(amount, item_id)
	return true

func record_purchase(item_id: String) -> void:
	## Run 27: track a shop purchase in the hero's inventory list so the HUD
	## panel can render owned items. Pure list append + signal — no item
	## effects (those still flow through Shop._apply_effects).
	if item_id == "":
		return
	hero_inventory.append(item_id)
	inventory_changed.emit()


func set_battle_speed(mult: float) -> void:
	## Run 27: clamp + apply the per-run animation-speed multiplier.
	## Pause menu calls this; BattleScene reads it through `_dur()`.
	battle_speed = clamp(mult, 0.5, 3.0)


func gain_xp(amount: int) -> bool:
	hero_xp += amount
	if hero_xp >= hero_level * XP_PER_LEVEL:
		hero_xp -= hero_level * XP_PER_LEVEL
		hero_level += 1
		return true  # leveled up
	return false

func take_damage(amount: int) -> void:
	hero_hp = max(0, hero_hp - amount)
	if hero_hp <= 0:
		hero_died.emit()

func heal(amount: int) -> void:
	hero_hp = min(hero_max_hp, hero_hp + amount)

func regen_between_floors() -> int:
	var regen: int = max(5, hero_max_hp / 10)
	var old_hp: int = hero_hp
	hero_hp = min(hero_max_hp, hero_hp + regen)
	return hero_hp - old_hp

func run_score() -> int:
	## Composite end-of-run score: depth dominates, with bonuses for kills,
	## bosses, level, audience favor (Run 19), and hoarded gold (Run 21 —
	## ×1 so it's a real but secondary contributor; spending is still optimal).
	return floor_num * 1000 + total_kills * 25 + bosses_slain * 250 \
		+ hero_level * 100 + audience_score * 2 + hero_gold * 1


# ── Run 28: Save / Resume ──────────────────────────────────────────────────

func snapshot() -> Dictionary:
	## Pure: serialize current run-relevant state into a JSON-safe Dictionary.
	## No file I/O; tests use this directly. Achievement state is also folded
	## in by the caller (Main.gd) before persistence, since Achievements is a
	## separate autoload.
	var inv_copy: Array = []
	for s: String in hero_inventory:
		inv_copy.append(s)
	var ab_copy: Array = []
	for s: String in hero_abilities:
		ab_copy.append(s)
	var pn_copy: Array = []
	for n: int in patch_notes_seen:
		pn_copy.append(n)
	var sp_ids_copy: Array = []
	for s: String in sponsor_offers_taken_ids:
		sp_ids_copy.append(s)
	return {
		"version": SAVE_VERSION,
		"run_seed": run_seed,
		"floor_num": floor_num,
		"hero_class": hero_class,
		"hero_hp": hero_hp,
		"hero_max_hp": hero_max_hp,
		"hero_xp": hero_xp,
		"hero_level": hero_level,
		"hero_gold": hero_gold,
		"hero_abilities": ab_copy,
		"hero_base_stats": hero_base_stats.duplicate(true),
		"hero_inventory": inv_copy,
		"battle_speed": battle_speed,
		"total_kills": total_kills,
		"bosses_slain": bosses_slain,
		"audience_score": audience_score,
		"lava_push_kills": lava_push_kills,
		"sponsor_offers_taken": sponsor_offers_taken,
		"sponsor_offers_taken_ids": sp_ids_copy,
		"patch_notes_seen": pn_copy,
		"shop_visits": shop_visits,
		"merchant_favor_used": merchant_favor_used,
	}


func apply_snapshot(data: Dictionary) -> bool:
	## Pure: restore state from a snapshot Dictionary. Returns false on
	## malformed input (missing hero_class is the canonical "not a real save"
	## marker). Defensive int() casts because JSON round-trips numbers as
	## floats — assigning a float to a `: int` field would silently truncate
	## but coercing first keeps the types honest for downstream callers.
	if data == null or data.is_empty():
		return false
	var cls: String = String(data.get("hero_class", ""))
	if cls == "":
		return false
	run_seed = int(data.get("run_seed", 0))
	floor_num = int(data.get("floor_num", 1))
	hero_class = cls
	hero_hp = int(data.get("hero_hp", 0))
	hero_max_hp = int(data.get("hero_max_hp", 0))
	hero_xp = int(data.get("hero_xp", 0))
	hero_level = int(data.get("hero_level", 1))
	hero_gold = int(data.get("hero_gold", 0))
	battle_speed = float(data.get("battle_speed", 1.0))
	total_kills = int(data.get("total_kills", 0))
	bosses_slain = int(data.get("bosses_slain", 0))
	audience_score = int(data.get("audience_score", 0))
	audience_score_floor = 0
	lava_push_kills = int(data.get("lava_push_kills", 0))
	sponsor_offers_taken = int(data.get("sponsor_offers_taken", 0))
	shop_visits = int(data.get("shop_visits", 0))
	# Run 31: defaults to false for pre-Run-31 saves so older snapshots load
	# cleanly without a SAVE_VERSION bump (purely additive field).
	merchant_favor_used = bool(data.get("merchant_favor_used", false))
	hero_abilities.clear()
	for a: Variant in data.get("hero_abilities", []):
		hero_abilities.append(String(a))
	hero_inventory.clear()
	for it: Variant in data.get("hero_inventory", []):
		hero_inventory.append(String(it))
	patch_notes_seen.clear()
	for n: Variant in data.get("patch_notes_seen", []):
		patch_notes_seen.append(int(n))
	# Run 29: id-list defaults to [] for pre-Run-29 saves so older save files
	# still load cleanly (no SAVE_VERSION bump needed).
	sponsor_offers_taken_ids.clear()
	for s: Variant in data.get("sponsor_offers_taken_ids", []):
		sponsor_offers_taken_ids.append(String(s))
	# hero_base_stats: JSON parses numbers as floats; rebuild as ints since
	# downstream combat math treats them as integer attack/defense/speed.
	hero_base_stats = {}
	var raw_stats: Dictionary = data.get("hero_base_stats", {})
	for k: Variant in raw_stats.keys():
		hero_base_stats[String(k)] = int(raw_stats[k])
	return true


func write_save_to_disk(extra: Dictionary = {}) -> bool:
	## Persist current run + caller-supplied extras (e.g. achievement state).
	## Returns false on I/O failure; the caller treats that as best-effort and
	## continues — losing a save shouldn't break the game.
	var data: Dictionary = snapshot()
	for k: Variant in extra.keys():
		data[String(k)] = extra[k]
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func read_save_from_disk() -> Dictionary:
	## Returns the parsed save dict, or {} if no save / unreadable / malformed.
	## Defensive: a corrupted file shouldn't surface "CONTINUE" on the title.
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed as Dictionary
	# Version gate: if a future format ever breaks compat, refuse the load
	# rather than half-apply it.
	if int(d.get("version", 0)) != SAVE_VERSION:
		return {}
	if String(d.get("hero_class", "")) == "":
		return {}
	return d


func has_save_on_disk() -> bool:
	return not read_save_from_disk().is_empty()


func clear_save_on_disk() -> void:
	## Idempotent — safe to call when no file exists.
	if not FileAccess.file_exists(SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# globalize_path doesn't resolve user:// on web; try the protocol path too.
	if FileAccess.file_exists(SAVE_PATH):
		var da: DirAccess = DirAccess.open("user://")
		if da != null:
			da.remove("descent_save.json")
