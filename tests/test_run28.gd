## Run 28 tests: save / resume — GameState snapshot ↔ apply_snapshot roundtrip,
## defensive cases for malformed inputs, JSON safety, and version gating.
##
## Per the project test rule, the actual autoload runtime isn't exercised — we
## instantiate the GameState script directly and verify the pure
## (snapshot, apply_snapshot) data contract. File-I/O wrappers
## (write_save_to_disk / read_save_from_disk / clear_save_on_disk) are smoke-
## tested using a fresh user:// path; Godot's test environment supports
## user:// even in --script mode.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun28


var GS_SCRIPT: GDScript = load("res://autoloads/GameState.gd")


# ── Helper ───────────────────────────────────────────────────────────────────

func _make_state() -> Node:
	## Fresh GameState instance with deterministic values set on every field
	## the snapshot is expected to capture.
	var gs: Node = GS_SCRIPT.new()
	gs.run_seed = 12345
	gs.floor_num = 7
	gs.hero_class = "rogue"
	gs.hero_hp = 42
	gs.hero_max_hp = 100
	gs.hero_xp = 73
	gs.hero_level = 4
	gs.hero_gold = 215
	gs.battle_speed = 1.5
	gs.total_kills = 27
	gs.bosses_slain = 1
	gs.audience_score = 480
	gs.lava_push_kills = 2
	gs.sponsor_offers_taken = 1
	gs.shop_visits = 3
	var abilities: Array[String] = ["basic_attack", "backstab", "vanish"]
	gs.hero_abilities = abilities
	var inv: Array[String] = ["shop_field_kit", "shop_field_kit", "shop_sharpening_stone"]
	gs.hero_inventory = inv
	var pn: Array[int] = [7]
	gs.patch_notes_seen = pn
	gs.hero_base_stats = {"attack": 20, "defense": 2, "speed": 15}
	return gs


# ── Snapshot contract ────────────────────────────────────────────────────────

func test_snapshot_contains_version_and_class() -> void:
	var gs: Node = _make_state()
	var snap: Dictionary = gs.snapshot()
	assert_eq(int(snap.get("version", -1)), int(GS_SCRIPT.SAVE_VERSION),
		"snapshot stamps the current SAVE_VERSION")
	assert_eq(String(snap.get("hero_class", "")), "rogue",
		"snapshot carries hero_class")
	gs.queue_free()


func test_snapshot_preserves_all_scalar_fields() -> void:
	var gs: Node = _make_state()
	var s: Dictionary = gs.snapshot()
	assert_eq(int(s.get("run_seed", 0)),              12345, "run_seed")
	assert_eq(int(s.get("floor_num", 0)),             7,     "floor_num")
	assert_eq(int(s.get("hero_hp", 0)),               42,    "hero_hp")
	assert_eq(int(s.get("hero_max_hp", 0)),           100,   "hero_max_hp")
	assert_eq(int(s.get("hero_xp", 0)),               73,    "hero_xp")
	assert_eq(int(s.get("hero_level", 0)),            4,     "hero_level")
	assert_eq(int(s.get("hero_gold", 0)),             215,   "hero_gold")
	assert_eq(int(s.get("total_kills", 0)),           27,    "total_kills")
	assert_eq(int(s.get("bosses_slain", 0)),          1,     "bosses_slain")
	assert_eq(int(s.get("audience_score", 0)),        480,   "audience_score")
	assert_eq(int(s.get("lava_push_kills", 0)),       2,     "lava_push_kills")
	assert_eq(int(s.get("sponsor_offers_taken", 0)),  1,     "sponsor_offers_taken")
	assert_eq(int(s.get("shop_visits", 0)),           3,     "shop_visits")
	gs.queue_free()


func test_snapshot_preserves_array_fields() -> void:
	var gs: Node = _make_state()
	var s: Dictionary = gs.snapshot()
	var ab: Array = s.get("hero_abilities", [])
	assert_eq(ab.size(), 3, "hero_abilities size")
	assert_eq(String(ab[1]), "backstab", "hero_abilities[1] == 'backstab'")
	var inv: Array = s.get("hero_inventory", [])
	assert_eq(inv.size(), 3, "hero_inventory size (duplicates preserved)")
	assert_eq(String(inv[0]), "shop_field_kit", "hero_inventory[0]")
	var pn: Array = s.get("patch_notes_seen", [])
	assert_eq(pn.size(), 1, "patch_notes_seen size")
	assert_eq(int(pn[0]), 7, "patch_notes_seen[0]")
	gs.queue_free()


func test_snapshot_arrays_are_independent_copies() -> void:
	## Mutating the snapshot's arrays must not leak back into GameState
	## (otherwise a save partway through could be silently corrupted by the
	## next gameplay tick).
	var gs: Node = _make_state()
	var s: Dictionary = gs.snapshot()
	(s["hero_inventory"] as Array).clear()
	(s["hero_abilities"] as Array).clear()
	assert_eq((gs.hero_inventory as Array).size(), 3,
		"snapshot inventory clear didn't mutate source")
	assert_eq((gs.hero_abilities as Array).size(), 3,
		"snapshot abilities clear didn't mutate source")
	gs.queue_free()


# ── Roundtrip ────────────────────────────────────────────────────────────────

func test_snapshot_roundtrip_restores_every_field() -> void:
	var src: Node = _make_state()
	var snap: Dictionary = src.snapshot()
	var dst: Node = GS_SCRIPT.new()
	var ok: bool = dst.apply_snapshot(snap)
	assert_true(ok, "apply_snapshot returns true on a valid snapshot")
	assert_eq(int(dst.run_seed), 12345,                "run_seed restored")
	assert_eq(int(dst.floor_num), 7,                   "floor_num restored")
	assert_eq(String(dst.hero_class), "rogue",         "hero_class restored")
	assert_eq(int(dst.hero_hp), 42,                    "hero_hp restored")
	assert_eq(int(dst.hero_max_hp), 100,               "hero_max_hp restored")
	assert_eq(int(dst.hero_xp), 73,                    "hero_xp restored")
	assert_eq(int(dst.hero_level), 4,                  "hero_level restored")
	assert_eq(int(dst.hero_gold), 215,                 "hero_gold restored")
	assert_eq(float(dst.battle_speed), 1.5,            "battle_speed restored")
	assert_eq(int(dst.total_kills), 27,                "total_kills restored")
	assert_eq(int(dst.audience_score), 480,            "audience_score restored")
	assert_eq(int(dst.shop_visits), 3,                 "shop_visits restored")
	assert_eq((dst.hero_abilities as Array).size(), 3, "hero_abilities length")
	assert_eq((dst.hero_inventory as Array).size(), 3, "hero_inventory length")
	assert_eq((dst.patch_notes_seen as Array).size(), 1, "patch_notes_seen length")
	assert_eq(int((dst.hero_base_stats as Dictionary).get("attack", 0)), 20,
		"hero_base_stats.attack restored as int")
	assert_eq(int((dst.hero_base_stats as Dictionary).get("speed", 0)),  15,
		"hero_base_stats.speed restored as int")
	src.queue_free()
	dst.queue_free()


func test_apply_snapshot_resets_audience_score_floor() -> void:
	## audience_score_floor is per-floor — resuming should zero it so the
	## floor-clear bonus calc doesn't double-count points from before the save.
	var dst: Node = GS_SCRIPT.new()
	dst.audience_score_floor = 99
	var snap: Dictionary = _make_state().snapshot()
	dst.apply_snapshot(snap)
	assert_eq(int(dst.audience_score_floor), 0,
		"apply_snapshot clears per-floor audience tally")
	dst.queue_free()


# ── JSON safety ─────────────────────────────────────────────────────────────

func test_snapshot_is_json_safe() -> void:
	## The save lives on `user://` as JSON; the snapshot must serialize and
	## parse back to a Dictionary without losing structure.
	var src: Node = _make_state()
	var s: Dictionary = src.snapshot()
	var raw: String = JSON.stringify(s)
	assert_true(raw.length() > 0, "JSON.stringify produced output")
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary, "JSON.parse_string returned a Dictionary")
	var dst: Node = GS_SCRIPT.new()
	assert_true(dst.apply_snapshot(parsed as Dictionary),
		"apply_snapshot accepts the JSON-roundtripped dict")
	assert_eq(int(dst.floor_num), 7,
		"floor_num survives JSON roundtrip (float→int coercion)")
	assert_eq(int(dst.hero_hp), 42,
		"hero_hp survives JSON roundtrip")
	src.queue_free()
	dst.queue_free()


# ── Defensive: malformed input ───────────────────────────────────────────────

func test_apply_snapshot_rejects_empty_dict() -> void:
	var dst: Node = GS_SCRIPT.new()
	assert_eq(dst.apply_snapshot({}), false,
		"empty dict treated as 'no save'")
	dst.queue_free()


func test_apply_snapshot_rejects_missing_class() -> void:
	var dst: Node = GS_SCRIPT.new()
	var bad: Dictionary = {"version": 1, "floor_num": 5, "hero_hp": 50}
	assert_eq(dst.apply_snapshot(bad), false,
		"missing hero_class treated as 'no save'")
	dst.queue_free()


func test_apply_snapshot_rejects_blank_class_string() -> void:
	var dst: Node = GS_SCRIPT.new()
	var bad: Dictionary = {"version": 1, "hero_class": "", "floor_num": 5}
	assert_eq(dst.apply_snapshot(bad), false,
		"empty-string hero_class treated as 'no save'")
	dst.queue_free()


func test_apply_snapshot_tolerates_missing_optional_fields() -> void:
	## A minimal valid snapshot (just hero_class + version) should restore
	## without crashing; missing fields default to safe zero/empty values.
	var dst: Node = GS_SCRIPT.new()
	var minimal: Dictionary = {
		"version": GS_SCRIPT.SAVE_VERSION,
		"hero_class": "brawler",
	}
	assert_true(dst.apply_snapshot(minimal),
		"minimal valid snapshot accepted")
	assert_eq(String(dst.hero_class), "brawler", "hero_class restored")
	assert_eq(int(dst.floor_num), 1, "floor_num defaults to 1")
	assert_eq(int(dst.hero_level), 1, "hero_level defaults to 1")
	assert_eq((dst.hero_abilities as Array).size(), 0,
		"hero_abilities defaults to empty when missing")
	dst.queue_free()


# ── File I/O smoke ──────────────────────────────────────────────────────────

func test_disk_roundtrip_via_file_io() -> void:
	## End-to-end: write_save_to_disk → read_save_from_disk gets the same dict
	## back and apply_snapshot rehydrates a clean GameState.
	var src: Node = _make_state()
	src.clear_save_on_disk()
	assert_eq(src.has_save_on_disk(), false,
		"clear_save_on_disk leaves no file")
	var wrote: bool = src.write_save_to_disk({"unlocked_achievements": ["first_blood"]})
	assert_true(wrote, "write_save_to_disk reports success")
	assert_eq(src.has_save_on_disk(), true,
		"file present after write")
	var data: Dictionary = src.read_save_from_disk()
	assert_true(not data.is_empty(), "read_save_from_disk returns non-empty")
	assert_eq(int(data.get("floor_num", 0)), 7,
		"floor_num survives disk roundtrip")
	var ach: Array = data.get("unlocked_achievements", [])
	assert_eq(ach.size(), 1,
		"extra dict (achievements) is included in saved payload")
	assert_eq(String(ach[0]), "first_blood",
		"achievement id preserved through disk roundtrip")
	# Cleanup so a follow-up test run starts from a clean slate.
	src.clear_save_on_disk()
	assert_eq(src.has_save_on_disk(), false,
		"clear_save_on_disk removes the file")
	src.queue_free()


func test_read_save_returns_empty_when_no_file() -> void:
	var gs: Node = _make_state()
	gs.clear_save_on_disk()
	var data: Dictionary = gs.read_save_from_disk()
	assert_eq(data.is_empty(), true,
		"read_save_from_disk returns {} when no save file exists")
	gs.queue_free()


func test_version_gate_rejects_mismatched_save() -> void:
	## If the SAVE_VERSION ever bumps, an old file shouldn't half-restore —
	## read_save_from_disk should treat it as "no save" so the title doesn't
	## offer CONTINUE on incompatible data.
	var gs: Node = _make_state()
	gs.clear_save_on_disk()
	var f: FileAccess = FileAccess.open(GS_SCRIPT.SAVE_PATH, FileAccess.WRITE)
	assert_true(f != null, "FileAccess.open succeeded for write")
	var bad: Dictionary = {
		"version": int(GS_SCRIPT.SAVE_VERSION) + 99,
		"hero_class": "rogue",
		"floor_num": 5,
	}
	f.store_string(JSON.stringify(bad))
	f.close()
	var data: Dictionary = gs.read_save_from_disk()
	assert_eq(data.is_empty(), true,
		"mismatched SAVE_VERSION treated as 'no save'")
	gs.clear_save_on_disk()
	gs.queue_free()
