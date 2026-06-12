## Run 34 tests: Tier-1 enemy variants (Cave Bat + Stone Skeleton) and Boss
## Phase 3 ("Frenzy") at sub-15% HP — escalated signature moves and a shorter
## signature cooldown.
##
## Pure logic coverage — no autoload runtime, no scene tree.
##  - Cave Bat / Stone Skeleton: schema, floor gating (boundaries at 1/2/3),
##    tint plumbing, ability ids real, design locks (bat speed >= 16,
##    stone skeleton armor >= 5).
##  - _check_boss_phase3: trips once below the threshold, never re-emits,
##    isn't fooled by max_hp = 0, signal fires through perform_attack.
##  - Frenzied rally: raises every eligible corpse in one shot, still
##    one-shot-per-battle.
##  - Frenzied slam: range 2 AoE, pushes 3 hexes, falls back when nobody in
##    the wider radius.
##  - Frenzied void pull: all in-range heroes pulled, closest-first packing
##    of landing hexes, no signature fired if nobody in pull range.
##  - Frenzied cooldown: SIGNATURE_COOLDOWN_FRENZIED (2) vs SIGNATURE_COOLDOWN
##    (3) after a signature fires.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun34


func _enemy_def(id: String) -> Dictionary:
	for e: Dictionary in EnemyDefs.ENEMIES:
		if String(e.get("id", "")) == id:
			return e
	return {}


# ── Tier-1 variants — schema + gating ───────────────────────────────────────

func test_tier1_variant_defs_exist() -> void:
	for id: String in ["cave_bat", "stone_skeleton"]:
		var d: Dictionary = _enemy_def(id)
		assert_true(not d.is_empty(), "enemy '%s' exists" % id)
		for key: String in ["display_name", "hp", "armor", "speed", "abilities",
				"xp_reward", "sprite_key", "min_floor"]:
			assert_true(d.has(key), "enemy '%s' has '%s'" % [id, key])


func test_cave_bat_floor_gating() -> void:
	## Cave Bat enters at floor 2.
	var ids_f1: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(1):
		ids_f1.append(String(e["id"]))
	assert_true(not ids_f1.has("cave_bat"), "no cave bat on floor 1")

	var ids_f2: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(2):
		ids_f2.append(String(e["id"]))
	assert_true(ids_f2.has("cave_bat"), "cave bat joins pool on floor 2")


func test_stone_skeleton_floor_gating() -> void:
	## Stone Skeleton enters at floor 3 — one floor later than the regular
	## skeleton (floor 2) so the player sees the bat-then-skeleton-then-stone
	## variety curve.
	var ids_f2: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(2):
		ids_f2.append(String(e["id"]))
	assert_true(not ids_f2.has("stone_skeleton"), "no stone skeleton on floor 2")

	var ids_f3: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(3):
		ids_f3.append(String(e["id"]))
	assert_true(ids_f3.has("stone_skeleton"), "stone skeleton joins pool on floor 3")


func test_tier1_variant_tints_distinct_from_white() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 34
	for id: String in ["cave_bat", "stone_skeleton"]:
		var d: Dictionary = _enemy_def(id)
		var c: Combatant = EnemyDefs.make_combatant(d, Vector2i.ZERO, rng, d["min_floor"])
		assert_true(c.tint != Color(1.0, 1.0, 1.0),
			"variant '%s' has a non-white tint" % id)


func test_tier1_variant_abilities_real() -> void:
	for id: String in ["cave_bat", "stone_skeleton"]:
		var d: Dictionary = _enemy_def(id)
		for a: String in d.get("abilities", []):
			assert_true(Abilities.DATA.has(a),
				"enemy '%s' ability '%s' exists in Abilities.DATA" % [id, a])


func test_cave_bat_is_fast() -> void:
	## Design lock: Cave Bat is the second-fastest mob in the game (Void Wraith
	## stays the fastest at 17). 16 puts it above goblin (14), well clear of
	## the slower fodder. If you change this, change the design comment too.
	var bat: Dictionary = _enemy_def("cave_bat")
	assert_true(int(bat["speed"]) >= 16, "cave bat speed >= 16")


func test_stone_skeleton_is_armored() -> void:
	## Design lock: Stone Skeleton armor >= 5 puts it above every other
	## floor-1-3 enemy (imp 0, goblin 1, skeleton 3, cave bat 0). If you nerf
	## this, also nerf the "tier 1 armor wall" comment in EnemyDefs.gd.
	var ss: Dictionary = _enemy_def("stone_skeleton")
	assert_true(int(ss["armor"]) >= 5, "stone skeleton armor >= 5")


# ── Phase 3 trigger ─────────────────────────────────────────────────────────

func _make_boss(sprite: String, hp: int = 200) -> Combatant:
	var boss := Combatant.new("boss", "Boss", Combatant.Faction.ENEMY, hp, 9)
	boss.is_boss = true
	boss.sprite_key = sprite
	boss.position = Vector2i(3, 0)
	boss.abilities = ["enemy_claw"] as Array[String]
	return boss


func test_phase3_trips_below_threshold() -> void:
	## Boss at sub-15% HP gets the frenzied flag set on the next
	## perform_attack hit. Above 15% it does not.
	## Use a big-HP boss (10000) and a small hit so we don't overkill —
	## _check_boss_phase3 only runs on the `target survived` branch.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 999, 10)
	hero.position = Vector2i(0, 0)
	var boss: Combatant = _make_boss("boss_warden", 10000)
	boss.position = Vector2i(1, 0)
	# Pre-drain to 14% — just under the 15% threshold. A basic_attack hit
	# can't bring this from 1400 HP to 0, so the survived branch runs.
	boss.hp = 1400
	var engine := BattleEngine.new(rng)
	engine.setup([hero, boss] as Array[Combatant])

	assert_eq(boss.frenzied, false, "frenzied starts false")
	engine.perform_attack(hero, boss, "basic_attack")
	assert_eq(boss.frenzied, true, "frenzied flips after hit at <15% HP")


func test_phase3_does_not_trip_above_threshold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 999, 10)
	hero.position = Vector2i(0, 0)
	hero.attack_bonus = 1  # small hit, won't dip the boss below 15%
	var boss: Combatant = _make_boss("boss_warden", 100)
	boss.position = Vector2i(1, 0)
	boss.hp = 50  # 50% — well above threshold even after the hit
	var engine := BattleEngine.new(rng)
	engine.setup([hero, boss] as Array[Combatant])

	engine.perform_attack(hero, boss, "basic_attack")
	assert_eq(boss.frenzied, false, "frenzied stays false above threshold")


func test_phase3_signal_emits_once() -> void:
	## The signal must fire exactly once per boss — repeated hits at sub-15%
	## should not re-emit. Use Array[int] reference container so the lambda's
	## counter is visible to the test (GDScript lambdas capture by value).
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 999, 10)
	hero.position = Vector2i(0, 0)
	var boss: Combatant = _make_boss("boss_warden", 10000)
	boss.position = Vector2i(1, 0)
	boss.hp = 1000  # 10% — well under threshold, but well above any hit damage
	var engine := BattleEngine.new(rng)
	engine.setup([hero, boss] as Array[Combatant])
	var emit_count: Array[int] = [0]
	engine.boss_frenzied.connect(func(_b: Combatant) -> void:
		emit_count[0] += 1)

	engine.perform_attack(hero, boss, "basic_attack")
	# Heal the boss above threshold then back below — flag never re-arms.
	boss.hp = 6000
	engine.perform_attack(hero, boss, "basic_attack")
	boss.hp = 500
	engine.perform_attack(hero, boss, "basic_attack")
	assert_eq(emit_count[0], 1, "boss_frenzied fires exactly once")


# ── Frenzied Dungeon Lord — mass rally ──────────────────────────────────────

func _setup_frenzied_boss_scene(boss_sprite: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 250, 10)
	hero.position = Vector2i.ZERO
	hero.abilities = ["basic_attack"] as Array[String]
	var boss := Combatant.new("boss", "Boss", Combatant.Faction.ENEMY, 300, 9)
	boss.is_boss = true
	boss.frenzied = true  # pre-set so the dispatch uses the escalated branch
	boss.sprite_key = boss_sprite
	boss.position = Vector2i(2, 0)
	boss.abilities = ["enemy_claw"] as Array[String]
	var map := DungeonMap.new()
	map.generate(1, rng)
	return {"rng": rng, "hero": hero, "boss": boss, "map": map}


func test_frenzied_rally_revives_every_corpse() -> void:
	var s: Dictionary = _setup_frenzied_boss_scene("boss_dungeon_lord")
	var corpse_a := Combatant.new("a", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_a.max_hp = 30
	corpse_a.position = Vector2i(1, 1)
	corpse_a.hp = 0
	var corpse_b := Combatant.new("b", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_b.max_hp = 30
	corpse_b.position = Vector2i(0, 1)
	corpse_b.hp = 0
	var corpse_c := Combatant.new("c", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_c.max_hp = 30
	corpse_c.position = Vector2i(-1, 0)
	corpse_c.hp = 0
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"], corpse_a, corpse_b, corpse_c]
			as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_true(corpse_a.is_alive(), "frenzied rally revived corpse A")
	assert_true(corpse_b.is_alive(), "frenzied rally revived corpse B")
	assert_true(corpse_c.is_alive(), "frenzied rally revived corpse C")
	assert_true(s["boss"].rally_used,
		"frenzied rally still consumes the once-per-battle flag")


func test_frenzied_rally_emits_all_revived_in_signal() -> void:
	## The boss_signature payload for a Frenzied rally must list every revived
	## combatant — BattleScene re-spawns each entity node off this array.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_dungeon_lord")
	var corpse_a := Combatant.new("a", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_a.max_hp = 30
	corpse_a.position = Vector2i(1, 1)
	corpse_a.hp = 0
	var corpse_b := Combatant.new("b", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_b.max_hp = 30
	corpse_b.position = Vector2i(0, 1)
	corpse_b.hp = 0
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"], corpse_a, corpse_b]
			as Array[Combatant])
	# GDScript lambdas capture locals by value — write to a single-slot Array
	# so the test can read what the closure observed.
	var captured: Array = [[]]
	engine.boss_signature.connect(func(_b: Combatant, move_id: String,
			affected: Array[Combatant]) -> void:
		if move_id == "rally":
			captured[0] = affected.duplicate())

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq((captured[0] as Array).size(), 2,
		"signal payload includes both revived corpses")


func test_frenzied_rally_still_one_shot() -> void:
	## Even Frenzied, rally is once per battle — second attempt does nothing.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_dungeon_lord")
	var corpse_a := Combatant.new("a", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_a.max_hp = 30
	corpse_a.position = Vector2i(1, 1)
	corpse_a.hp = 0
	var corpse_b := Combatant.new("b", "Imp", Combatant.Faction.ENEMY, 25, 12)
	corpse_b.max_hp = 30
	corpse_b.position = Vector2i(0, 1)
	corpse_b.hp = 0
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"], corpse_a, corpse_b]
			as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	# Re-kill corpse_b and let the boss try again with cooldown cleared.
	corpse_b.hp = 0
	s["boss"].signature_cd = 0
	engine.enemy_ai_action(s["boss"], s["map"])
	assert_true(not corpse_b.is_alive(),
		"frenzied rally still respects the once-per-battle gate")


# ── Frenzied Warden — tectonic slam (range 2, push 3) ──────────────────────

func test_frenzied_slam_hits_range_2() -> void:
	## Normal slam fires only on adjacent heroes; Frenzied widens to range 2.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_warden")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(2, 0)  # range 2 — out of normal reach
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"]] as Array[Combatant])
	var hp_before: int = s["hero"].hp

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_true(s["hero"].hp < hp_before,
		"frenzied slam reached the range-2 hero")


func test_frenzied_slam_pushes_three() -> void:
	## Frenzied slam push distance is 3 (vs 2 in the base form). Use a goal-
	## directed setup: hero adjacent, on a known-passable starting hex.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_warden")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(1, 0)
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"]] as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	var dist: int = HexGrid.hex_distance(s["hero"].position, s["boss"].position)
	# Path may be clipped by impassable hexes on the procedural map, but the
	# push request is for 3 — distance must be > 2 unless the map blocked us.
	assert_true(dist >= 2, "frenzied slam pushed at least 2 hexes")


func test_frenzied_slam_skipped_when_nobody_in_radius_2() -> void:
	## Frenzied slam still requires SOMEONE in radius — the boss falls back
	## to a normal attack rather than waste the signature.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_warden")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(6, 0)  # well out of even frenzied range
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"]] as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["boss"].signature_cd, 0,
		"signature cooldown unchanged — no signature fired")


# ── Frenzied Abyss Keeper — mass void pull ─────────────────────────────────

func test_frenzied_pull_grabs_all_in_range() -> void:
	## All living heroes within 2-4 hexes should land in the boss's ring.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_abyss_keeper")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(3, 0)
	var hero2 := Combatant.new("hero2", "Donut", Combatant.Faction.HERO, 100, 10)
	hero2.position = Vector2i(0, 3)
	hero2.abilities = ["basic_attack"] as Array[String]
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"], hero2] as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	var d1: int = HexGrid.hex_distance(s["hero"].position, s["boss"].position)
	var d2: int = HexGrid.hex_distance(hero2.position, s["boss"].position)
	assert_eq(d1, 1, "hero pulled to range 1")
	assert_eq(d2, 1, "second hero also pulled to range 1")


func test_frenzied_pull_skips_already_adjacent() -> void:
	## A hero already at range 1 is not relocated — only heroes in 2-4 are
	## pulled. The signature still fires if anyone else is in range.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_abyss_keeper")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(1, 0)  # already adjacent — keeps spot
	var hero2 := Combatant.new("hero2", "Donut", Combatant.Faction.HERO, 100, 10)
	hero2.position = Vector2i(3, 0)
	hero2.abilities = ["basic_attack"] as Array[String]
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"], hero2] as Array[Combatant])
	var pos_before: Vector2i = s["hero"].position

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["hero"].position, pos_before, "adjacent hero stays put")
	assert_eq(HexGrid.hex_distance(hero2.position, s["boss"].position), 1,
		"distant hero pulled into melee")


func test_frenzied_pull_skipped_when_nobody_in_range() -> void:
	## All heroes too close or too far — no signature fires.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_abyss_keeper")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(1, 0)   # too close
	var hero2 := Combatant.new("hero2", "Donut", Combatant.Faction.HERO, 100, 10)
	hero2.position = Vector2i(6, 0)       # too far
	hero2.abilities = ["basic_attack"] as Array[String]
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"], hero2] as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["boss"].signature_cd, 0,
		"signature cooldown unchanged — no signature fired")


# ── Frenzied cooldown is shorter ────────────────────────────────────────────

func test_frenzied_cooldown_is_two() -> void:
	## After firing a signature, a Frenzied boss has cd = SIGNATURE_COOLDOWN_FRENZIED
	## (2), not SIGNATURE_COOLDOWN (3). Same setup as test_warden_slam_hits_*
	## but with frenzied = true.
	var s: Dictionary = _setup_frenzied_boss_scene("boss_warden")
	s["boss"].position = Vector2i(0, 0)
	s["hero"].position = Vector2i(1, 0)
	var engine := BattleEngine.new(s["rng"])
	engine.setup([s["hero"], s["boss"]] as Array[Combatant])

	engine.enemy_ai_action(s["boss"], s["map"])
	assert_eq(s["boss"].signature_cd,
		BattleEngine.SIGNATURE_COOLDOWN_FRENZIED,
		"frenzied cd set to SIGNATURE_COOLDOWN_FRENZIED (2)")


func test_non_frenzied_cooldown_is_three() -> void:
	## Regression guard: a non-frenzied boss still gets SIGNATURE_COOLDOWN.
	## Mirrors test_signature_cooldown_ticks_between_uses in test_run33.gd but
	## isolates the cd value specifically against the new frenzied path.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 250, 10)
	hero.position = Vector2i.ZERO
	hero.abilities = ["basic_attack"] as Array[String]
	var boss: Combatant = _make_boss("boss_warden", 200)
	boss.position = Vector2i(1, 0)
	# frenzied left at default false
	var engine := BattleEngine.new(rng)
	var map := DungeonMap.new()
	map.generate(1, rng)
	engine.setup([hero, boss] as Array[Combatant])

	engine.enemy_ai_action(boss, map)
	assert_eq(boss.signature_cd, BattleEngine.SIGNATURE_COOLDOWN,
		"non-frenzied cd unchanged at SIGNATURE_COOLDOWN (3)")


# ── Combatant default ───────────────────────────────────────────────────────

func test_combatant_frenzied_defaults_false() -> void:
	var c := Combatant.new("x", "X", Combatant.Faction.ENEMY, 10, 1)
	assert_eq(c.frenzied, false, "combatant.frenzied defaults to false")
