## Run 33 tests: boss signature moves + new enemy variants + loot buyback.
##
## Pure logic coverage — no autoload runtime, no scene tree.
##  - Plague Goblin / Ember Imp: schema, floor gating, status application
##    through perform_attack (faction-gated so hero abilities don't double-stack).
##  - Boss signatures (rally / slam / pull): each fires via _try_boss_signature
##    only when conditions allow, marks state correctly, and respects cooldown.
##  - Shop.pick_buyback_candidate + buyback_cost + GameState snapshot fields.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun33


var GAMESTATE: GDScript = load("res://autoloads/GameState.gd")
var SHOP: GDScript = load("res://src/data/Shop.gd")


func _enemy_def(id: String) -> Dictionary:
	for e: Dictionary in EnemyDefs.ENEMIES:
		if String(e.get("id", "")) == id:
			return e
	return {}


# ── New enemy variants — schema + gating ────────────────────────────────────

func test_new_variant_defs_exist() -> void:
	for id: String in ["plague_goblin", "ember_imp"]:
		var d: Dictionary = _enemy_def(id)
		assert_true(not d.is_empty(), "enemy '%s' exists" % id)
		for key: String in ["display_name", "hp", "armor", "speed", "abilities",
				"xp_reward", "sprite_key", "min_floor"]:
			assert_true(d.has(key), "enemy '%s' has '%s'" % [id, key])


func test_variant_floor_gating() -> void:
	## plague_goblin enters at 8; ember_imp at 13.
	var ids_f7: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(7):
		ids_f7.append(String(e["id"]))
	assert_true(not ids_f7.has("plague_goblin"), "no plague goblin on floor 7")
	assert_true(not ids_f7.has("ember_imp"), "no ember imp on floor 7")

	var ids_f8: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(8):
		ids_f8.append(String(e["id"]))
	assert_true(ids_f8.has("plague_goblin"), "plague goblin joins pool on floor 8")
	assert_true(not ids_f8.has("ember_imp"), "ember imp still gated at floor 8")

	var ids_f13: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(13):
		ids_f13.append(String(e["id"]))
	assert_true(ids_f13.has("ember_imp"), "ember imp joins pool on floor 13")


func test_variant_tints_distinct_from_white() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var goblin_def: Dictionary = _enemy_def("plague_goblin")
	var goblin: Combatant = EnemyDefs.make_combatant(goblin_def, Vector2i.ZERO, rng, 8)
	assert_true(goblin.tint != Color(1.0, 1.0, 1.0), "plague goblin has a non-white tint")

	var imp_def: Dictionary = _enemy_def("ember_imp")
	var imp: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 13)
	assert_true(imp.tint != Color(1.0, 1.0, 1.0), "ember imp has a non-white tint")


func test_variant_abilities_real() -> void:
	for id: String in ["plague_goblin", "ember_imp"]:
		var d: Dictionary = _enemy_def(id)
		for a: String in d.get("abilities", []):
			assert_true(Abilities.DATA.has(a),
				"enemy '%s' ability '%s' exists in Abilities.DATA" % [id, a])


# ── Status-application from enemy attacks (the actual mechanic) ─────────────

func test_plague_bite_applies_poison_to_hero() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var goblin := Combatant.new("g1", "Plague Goblin", Combatant.Faction.ENEMY, 40, 14)
	var engine := BattleEngine.new(rng)
	var roster: Array[Combatant] = [hero, goblin]
	engine.setup(roster)

	engine.perform_attack(goblin, hero, "plague_bite")
	var found_poison: bool = false
	for eff: Dictionary in hero.status_effects:
		if eff.get("id", "") == "poisoned":
			found_poison = true
			break
	assert_true(found_poison, "plague bite applied poisoned status")


func test_ember_claw_applies_burning_to_hero() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var imp := Combatant.new("i1", "Ember Imp", Combatant.Faction.ENEMY, 35, 13)
	var engine := BattleEngine.new(rng)
	var roster: Array[Combatant] = [hero, imp]
	engine.setup(roster)

	engine.perform_attack(imp, hero, "ember_claw")
	var found_burn: bool = false
	for eff: Dictionary in hero.status_effects:
		if eff.get("id", "") == "burning":
			found_burn = true
			break
	assert_true(found_burn, "ember claw applied burning status")


func test_hero_attack_does_not_double_apply_status() -> void:
	## Regression: BattleScene applies hero-side status (poison_blade etc.)
	## itself. perform_attack must NOT also apply it — the faction guard in
	## Run 33's perform_attack is the line that prevents the double stack.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var dummy := Combatant.new("d1", "Dummy", Combatant.Faction.ENEMY, 100, 5)
	var engine := BattleEngine.new(rng)
	var roster: Array[Combatant] = [hero, dummy]
	engine.setup(roster)

	# poison_blade has applies_poisoned: true — if perform_attack applied it
	# regardless of faction, the dummy would have a poisoned status here.
	engine.perform_attack(hero, dummy, "poison_blade")
	for eff: Dictionary in dummy.status_effects:
		assert_true(eff.get("id", "") != "poisoned",
			"hero-side poison_blade did NOT apply via perform_attack")


# ── Boss signature move: Dungeon Lord rally ─────────────────────────────────

func _setup_boss_scene(boss_sprite: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 250, 10)
	hero.position = Vector2i.ZERO
	hero.abilities = ["basic_attack"] as Array[String]
	var boss := Combatant.new("boss", "Boss", Combatant.Faction.ENEMY, 300, 9)
	boss.is_boss = true
	boss.sprite_key = boss_sprite
	boss.position = Vector2i(2, 0)
	boss.abilities = ["enemy_claw"] as Array[String]
	var map := DungeonMap.new()
	map.generate(1, rng)
	return {"rng": rng, "hero": hero, "boss": boss, "map": map}


func test_dungeon_lord_rally_revives_corpse() -> void:
	var s: Dictionary = _setup_boss_scene("boss_dungeon_lord")
	var corpse := Combatant.new("c1", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse.max_hp = 30
	corpse.position = Vector2i(1, 1)
	corpse.hp = 0  # dead
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"], corpse]
	engine.setup(roster)

	# Drive the boss turn directly.
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_true(corpse.is_alive(), "rally brought the dead imp back to life")
	assert_true(s["boss"].rally_used, "rally consumed the once-per-battle flag")
	assert_true(s["boss"].signature_cd > 0, "signature is on cooldown after firing")


func test_dungeon_lord_rally_only_once() -> void:
	var s: Dictionary = _setup_boss_scene("boss_dungeon_lord")
	var corpse_a := Combatant.new("a", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_a.max_hp = 30
	corpse_a.position = Vector2i(1, 1)
	corpse_a.hp = 0
	var corpse_b := Combatant.new("b", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_b.max_hp = 30
	corpse_b.position = Vector2i(0, 1)
	corpse_b.hp = 0
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"], corpse_a, corpse_b]
	engine.setup(roster)

	# Burn the boss's signature on corpse A.
	engine.enemy_ai_action(s["boss"], s["map"])
	# Skip cooldown so the signature is technically off-cd.
	s["boss"].signature_cd = 0
	engine.enemy_ai_action(s["boss"], s["map"])
	# corpse_b must still be dead — rally_used gates the second attempt.
	assert_true(not corpse_b.is_alive(), "second corpse stayed dead — rally is one-shot")


func test_rally_skipped_when_no_corpses() -> void:
	## With no eligible corpses, the boss falls through to its normal attack.
	var s: Dictionary = _setup_boss_scene("boss_dungeon_lord")
	# Put boss adjacent to hero so the normal attack lands.
	s["boss"].position = Vector2i(1, 0)
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"]]
	engine.setup(roster)

	var hp_before: int = s["hero"].hp
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_true(s["hero"].hp < hp_before, "fallback attack still landed")
	assert_true(not s["boss"].rally_used, "rally NOT consumed when no corpses")


# ── Boss signature move: Warden ground slam ─────────────────────────────────

func test_warden_slam_hits_adjacent_and_pushes() -> void:
	var s: Dictionary = _setup_boss_scene("boss_warden")
	s["boss"].position = Vector2i(1, 0)  # adjacent to hero
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"]]
	engine.setup(roster)

	var hp_before: int = s["hero"].hp
	var pos_before: Vector2i = s["hero"].position
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_true(s["hero"].hp < hp_before, "slam dealt damage")
	assert_true(s["hero"].position != pos_before, "hero was pushed by the slam")


func test_warden_slam_not_used_when_no_one_adjacent() -> void:
	var s: Dictionary = _setup_boss_scene("boss_warden")
	s["boss"].position = Vector2i(5, 0)  # far away
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"]]
	engine.setup(roster)

	# Run several turns; the boss should advance toward hero, not waste a slam.
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["boss"].signature_cd, 0,
		"signature not consumed when no hero in melee")


# ── Boss signature move: Abyss Keeper void pull ─────────────────────────────

func test_abyss_keeper_pulls_distant_hero_into_melee() -> void:
	var s: Dictionary = _setup_boss_scene("boss_abyss_keeper")
	s["boss"].position = Vector2i(3, 0)  # 3 hexes away — within pull range 2-4
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"]]
	engine.setup(roster)

	engine.enemy_ai_action(s["boss"], s["map"])
	var dist_after: int = HexGrid.hex_distance(s["hero"].position, s["boss"].position)
	assert_eq(dist_after, 1, "pulled hero is now adjacent to the boss")


func test_abyss_keeper_pull_skipped_when_already_adjacent() -> void:
	var s: Dictionary = _setup_boss_scene("boss_abyss_keeper")
	s["boss"].position = Vector2i(1, 0)  # already adjacent
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"]]
	engine.setup(roster)

	var pos_before: Vector2i = s["hero"].position
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["hero"].position, pos_before,
		"adjacent hero not pulled (range guard)")


# ── Signature cooldown ──────────────────────────────────────────────────────

func test_signature_cooldown_ticks_between_uses() -> void:
	var s: Dictionary = _setup_boss_scene("boss_warden")
	s["boss"].position = Vector2i(1, 0)
	var engine := BattleEngine.new(s["rng"])
	var roster: Array[Combatant] = [s["hero"], s["boss"]]
	engine.setup(roster)

	# Fire signature; cd should be SIGNATURE_COOLDOWN.
	engine.enemy_ai_action(s["boss"], s["map"])
	var cd_after_use: int = s["boss"].signature_cd
	assert_eq(cd_after_use, BattleEngine.SIGNATURE_COOLDOWN,
		"cd set to SIGNATURE_COOLDOWN after firing")

	# Next boss turn should tick cd down without firing the signature again.
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["boss"].signature_cd, cd_after_use - 1, "cd ticked down by 1")


# ── Loot buyback ────────────────────────────────────────────────────────────

func test_buyback_candidate_picks_highest_rarity_skipped() -> void:
	var slate: Array = [
		{"id": "a", "rarity": "common", "type": "stat"},
		{"id": "b", "rarity": "legendary", "type": "heal"},
		{"id": "c", "rarity": "rare", "type": "stat"},
	]
	var pick: Dictionary = SHOP.pick_buyback_candidate(slate, "a")
	assert_eq(String(pick.get("id", "")), "b",
		"legendary skipped beats rare skipped")


func test_buyback_candidate_excludes_chosen() -> void:
	var slate: Array = [
		{"id": "a", "rarity": "legendary", "type": "stat"},
		{"id": "b", "rarity": "rare", "type": "stat"},
	]
	var pick: Dictionary = SHOP.pick_buyback_candidate(slate, "a")
	assert_eq(String(pick.get("id", "")), "b",
		"chosen card not picked as the skipped one")


func test_buyback_candidate_excludes_skip_type() -> void:
	## Floor-skip items would mutate floor_num if reapplied — exclude.
	var slate: Array = [
		{"id": "skip", "rarity": "legendary", "type": "skip"},
		{"id": "ok", "rarity": "rare", "type": "stat"},
	]
	var pick: Dictionary = SHOP.pick_buyback_candidate(slate, "ok")
	assert_eq(String(pick.get("id", "")), "",
		"skip-type item excluded from buyback (returns {})")


func test_buyback_candidate_empty_when_only_chosen() -> void:
	var slate: Array = [{"id": "a", "rarity": "common", "type": "stat"}]
	var pick: Dictionary = SHOP.pick_buyback_candidate(slate, "a")
	assert_true(pick.is_empty(),
		"only-card-in-slate-is-chosen returns empty dict")


func test_buyback_costs_climb_with_rarity() -> void:
	var c: int = SHOP.buyback_cost("common")
	var r: int = SHOP.buyback_cost("rare")
	var l: int = SHOP.buyback_cost("legendary")
	assert_gt(r, c, "rare buyback costs more than common")
	assert_gt(l, r, "legendary buyback costs more than rare")


func test_buyback_cost_unknown_rarity_falls_back() -> void:
	var fb: int = SHOP.buyback_cost("nonsense")
	assert_eq(fb, SHOP.buyback_cost("common"),
		"unknown rarity falls back to common cost")


func test_gamestate_buyback_fields_default() -> void:
	var gs: Node = GAMESTATE.new()
	assert_true(gs.last_skipped_loot.is_empty(),
		"last_skipped_loot defaults to {}")
	assert_eq(gs.loot_buyback_used, false,
		"loot_buyback_used defaults to false")
	gs.queue_free()


func test_gamestate_buyback_fields_snapshot_roundtrip() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_class = "brawler"
	gs.last_skipped_loot = {"id": "phoenix_feather", "rarity": "legendary"}
	gs.loot_buyback_used = true
	var raw: String = JSON.stringify(gs.snapshot())
	var parsed: Variant = JSON.parse_string(raw)
	var gs2: Node = GAMESTATE.new()
	gs2.apply_snapshot(parsed as Dictionary)
	assert_eq(String((gs2.last_skipped_loot as Dictionary).get("id", "")),
		"phoenix_feather", "skipped loot id roundtripped")
	assert_eq(gs2.loot_buyback_used, true, "buyback-used flag roundtripped")
	gs.queue_free()
	gs2.queue_free()


func test_gamestate_buyback_pre_run33_save_default() -> void:
	var gs: Node = GAMESTATE.new()
	gs.last_skipped_loot = {"stale": true}
	gs.loot_buyback_used = true
	var fake: Dictionary = {
		"version": GAMESTATE.SAVE_VERSION,
		"hero_class": "brawler",
	}
	gs.apply_snapshot(fake)
	assert_true(gs.last_skipped_loot.is_empty(),
		"missing skipped-loot defaults to {}")
	assert_eq(gs.loot_buyback_used, false,
		"missing buyback flag defaults to false")
	gs.queue_free()


func test_start_run_resets_buyback() -> void:
	var gs: Node = GAMESTATE.new()
	gs.last_skipped_loot = {"id": "stale"}
	gs.loot_buyback_used = true
	gs.start_run("brawler", 1)
	assert_true(gs.last_skipped_loot.is_empty(), "start_run clears skipped loot")
	assert_eq(gs.loot_buyback_used, false, "start_run resets buyback flag")
	gs.queue_free()
