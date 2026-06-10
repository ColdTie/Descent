## Run 30 tests: multi-step sponsor story arcs.
##
## Validates that the new chain-step sponsors are wired correctly, that
## multi-step `requires_taken` gating works (Singularity only opens after
## the player has taken Cola AND Zero, not just Cola), and that the
## `chain_finale: true` flag is set on the trilogy capstone. Pure data —
## no autoload references, safe in --script mode.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun30


var SPONSORS: GDScript = load("res://src/data/Sponsors.gd")


# ── New ids exist ─────────────────────────────────────────────────────────────

func test_pool_has_new_run30_ids() -> void:
	## Run 30 added four chain-step sponsors. Lock the ids in so a future
	## refactor can't silently drop one and break the story arcs.
	var required: Array[String] = [
		"spectral_cola_zero",
		"spectral_cola_singularity",
		"bopca_executive_plan",
		"hyperion_megapack",
	]
	var seen: Dictionary = {}
	for o: Dictionary in SPONSORS.POOL:
		seen[String(o.get("id", ""))] = true
	for id: String in required:
		assert_true(seen.has(id), "POOL contains new Run-30 sponsor '%s'" % id)


# ── Chain wiring ──────────────────────────────────────────────────────────────

func test_spectral_zero_requires_spectral_cola() -> void:
	var z: Dictionary = SPONSORS.get_offer("spectral_cola_zero")
	assert_true(not z.is_empty(), "spectral_cola_zero exists")
	assert_eq(String(z.get("requires_taken", "")), "spectral_cola",
		"spectral_cola_zero.requires_taken points at spectral_cola")


func test_spectral_singularity_requires_spectral_zero() -> void:
	## Critical: Singularity's prereq is the MIDDLE step of the trilogy, not
	## the OG. Otherwise the chain collapses into a 2-step arc.
	var s: Dictionary = SPONSORS.get_offer("spectral_cola_singularity")
	assert_true(not s.is_empty(), "spectral_cola_singularity exists")
	assert_eq(String(s.get("requires_taken", "")), "spectral_cola_zero",
		"spectral_cola_singularity.requires_taken points at spectral_cola_zero")


func test_bopca_executive_requires_bopca_insurance() -> void:
	var e: Dictionary = SPONSORS.get_offer("bopca_executive_plan")
	assert_true(not e.is_empty(), "bopca_executive_plan exists")
	assert_eq(String(e.get("requires_taken", "")), "bopca_insurance",
		"bopca_executive_plan.requires_taken points at bopca_insurance")


func test_hyperion_megapack_requires_hyperion_drink() -> void:
	var m: Dictionary = SPONSORS.get_offer("hyperion_megapack")
	assert_true(not m.is_empty(), "hyperion_megapack exists")
	assert_eq(String(m.get("requires_taken", "")), "hyperion_drink",
		"hyperion_megapack.requires_taken points at hyperion_drink")


# ── Chain finale flag ────────────────────────────────────────────────────────

func test_singularity_is_chain_finale() -> void:
	## Only Singularity carries the finale flag — the 2-step arcs are NOT
	## trilogies and shouldn't get the trilogy-finale chrome / quip.
	var s: Dictionary = SPONSORS.get_offer("spectral_cola_singularity")
	assert_true(SPONSORS.is_chain_finale(s),
		"spectral_cola_singularity is a chain finale")


func test_non_finale_sponsors_are_not_finales() -> void:
	## Defensive: regular sponsors and 2-step capstones should NOT show up
	## as chain finales. Only the trilogy-capstone gets the badge.
	var ids: Array[String] = [
		"hyperion_drink",
		"big_mikes_meat",
		"big_mikes_return",
		"spectral_cola",
		"spectral_cola_zero",
		"bopca_insurance",
		"bopca_executive_plan",
		"hyperion_megapack",
		"godking_industries",
		"neo_blood_co",
	]
	for id: String in ids:
		var o: Dictionary = SPONSORS.get_offer(id)
		assert_true(not o.is_empty(), "sponsor '%s' exists" % id)
		assert_true(not SPONSORS.is_chain_finale(o),
			"sponsor '%s' is NOT a chain finale" % id)


func test_is_chain_finale_handles_empty_dict() -> void:
	## Defensive: a missing/empty offer dict must not crash the helper.
	assert_true(not SPONSORS.is_chain_finale({}),
		"is_chain_finale({}) returns false")


# ── Multi-step gating: eligible_pool ──────────────────────────────────────────

func test_singularity_hidden_with_only_cola_taken() -> void:
	## Player has taken Cola but not Zero — Singularity must still be hidden.
	## This is the core "chain unlocks step by step" guarantee.
	var elig: Array = SPONSORS.eligible_pool(["spectral_cola"])
	var has_singularity: bool = false
	for o: Dictionary in elig:
		if String(o.get("id", "")) == "spectral_cola_singularity":
			has_singularity = true
	assert_true(not has_singularity,
		"Singularity NOT eligible when only the OG cola has been taken")


func test_singularity_visible_after_full_chain() -> void:
	## Player has taken Cola AND Zero — Singularity is now eligible.
	var elig: Array = SPONSORS.eligible_pool(
		["spectral_cola", "spectral_cola_zero"])
	var has_singularity: bool = false
	for o: Dictionary in elig:
		if String(o.get("id", "")) == "spectral_cola_singularity":
			has_singularity = true
	assert_true(has_singularity,
		"Singularity IS eligible when both prior chain steps have been taken")


func test_zero_hidden_without_cola() -> void:
	## And Zero is gated by Cola — without Cola the middle step is also hidden.
	var elig: Array = SPONSORS.eligible_pool([])
	var has_zero: bool = false
	for o: Dictionary in elig:
		if String(o.get("id", "")) == "spectral_cola_zero":
			has_zero = true
	assert_true(not has_zero,
		"spectral_cola_zero NOT eligible when cola has not been taken")


func test_zero_visible_with_cola() -> void:
	var elig: Array = SPONSORS.eligible_pool(["spectral_cola"])
	var has_zero: bool = false
	for o: Dictionary in elig:
		if String(o.get("id", "")) == "spectral_cola_zero":
			has_zero = true
	assert_true(has_zero,
		"spectral_cola_zero IS eligible when cola has been taken")


func test_bopca_executive_gated_by_insurance() -> void:
	var without: Array = SPONSORS.eligible_pool([])
	var with_it: Array = SPONSORS.eligible_pool(["bopca_insurance"])
	var saw_without: bool = false
	var saw_with: bool = false
	for o: Dictionary in without:
		if String(o.get("id", "")) == "bopca_executive_plan":
			saw_without = true
	for o: Dictionary in with_it:
		if String(o.get("id", "")) == "bopca_executive_plan":
			saw_with = true
	assert_true(not saw_without,
		"bopca_executive_plan hidden without insurance prereq")
	assert_true(saw_with,
		"bopca_executive_plan visible with insurance prereq")


func test_hyperion_megapack_gated_by_hyperion_drink() -> void:
	var without: Array = SPONSORS.eligible_pool([])
	var with_it: Array = SPONSORS.eligible_pool(["hyperion_drink"])
	var saw_without: bool = false
	var saw_with: bool = false
	for o: Dictionary in without:
		if String(o.get("id", "")) == "hyperion_megapack":
			saw_without = true
	for o: Dictionary in with_it:
		if String(o.get("id", "")) == "hyperion_megapack":
			saw_with = true
	assert_true(not saw_without,
		"hyperion_megapack hidden without hyperion_drink prereq")
	assert_true(saw_with,
		"hyperion_megapack visible with hyperion_drink prereq")


# ── Multi-step gating: slate ─────────────────────────────────────────────────

func test_slate_never_offers_singularity_without_zero() -> void:
	## Across many random slates with high taken_count but only the OG cola
	## prereq, Singularity must never appear. Locks in the chain-step
	## guarantee at the slate level (not just eligible_pool).
	var rng := RandomNumberGenerator.new()
	for trial: int in range(80):
		rng.seed = 70_000 + trial
		var picks: Array = SPONSORS.slate(rng, 6, ["spectral_cola"])
		for o: Dictionary in picks:
			assert_true(
				String(o.get("id", "")) != "spectral_cola_singularity",
				"trial %d: singularity excluded when zero not taken" % trial)


func test_slate_can_offer_singularity_after_full_chain() -> void:
	## With the full chain satisfied AND high taken_count (high Legendary
	## weight), Singularity should land at least once across many trials.
	var rng := RandomNumberGenerator.new()
	var saw: bool = false
	for trial: int in range(200):
		rng.seed = 80_000 + trial
		var picks: Array = SPONSORS.slate(
			rng, 6, ["spectral_cola", "spectral_cola_zero"])
		for o: Dictionary in picks:
			if String(o.get("id", "")) == "spectral_cola_singularity":
				saw = true
				break
		if saw:
			break
	assert_true(saw,
		"Singularity appears at least once across 200 high-tier slates with full chain prereq")


# ── Effect schema for new sponsors ────────────────────────────────────────────

func test_new_sponsors_use_known_effect_keys() -> void:
	## Defensive: every effect key on the new sponsors must be one the
	## SponsorOffer.gd `_apply_effects()` handler knows about. Otherwise the
	## sponsor pays nothing on accept.
	var allowed: Dictionary = {
		"attack": true, "defense": true, "speed": true,
		"max_hp": true, "heal": true, "audience": true,
	}
	var new_ids: Array[String] = [
		"spectral_cola_zero", "spectral_cola_singularity",
		"bopca_executive_plan", "hyperion_megapack",
	]
	for id: String in new_ids:
		var o: Dictionary = SPONSORS.get_offer(id)
		var fx: Dictionary = o.get("effects", {})
		assert_true(not fx.is_empty(),
			"sponsor '%s' has a non-empty effects dict" % id)
		for k: String in fx:
			assert_true(allowed.has(k),
				"sponsor '%s' effect key '%s' is one _apply_effects() handles"
					% [id, k])


# ── End-to-end: simulated chain progression ──────────────────────────────────

func test_end_to_end_chain_progression() -> void:
	## Simulate a player walking the Spectral Cola trilogy. After each step
	## is taken, the next step should be eligible; after the finale, all
	## three are in the taken list and the finale-flag predicate fires.
	var taken: Array[String] = []
	# Step 0: only the OG Spectral Cola is eligible (zero+singularity gated).
	var elig0: Array = SPONSORS.eligible_pool(taken)
	var has_cola: bool = false
	var has_zero: bool = false
	for o: Dictionary in elig0:
		match String(o.get("id", "")):
			"spectral_cola":             has_cola = true
			"spectral_cola_zero":        has_zero = true
	assert_true(has_cola,  "step 0: spectral_cola eligible from start")
	assert_true(not has_zero, "step 0: spectral_cola_zero gated until cola taken")
	# Step 1: take Cola; Zero opens, Singularity still gated.
	taken.append("spectral_cola")
	var elig1: Array = SPONSORS.eligible_pool(taken)
	has_zero = false
	var has_sing: bool = false
	for o: Dictionary in elig1:
		match String(o.get("id", "")):
			"spectral_cola_zero":         has_zero = true
			"spectral_cola_singularity":  has_sing = true
	assert_true(has_zero,    "step 1: zero opens after cola taken")
	assert_true(not has_sing, "step 1: singularity still gated until zero taken")
	# Step 2: take Zero; Singularity opens.
	taken.append("spectral_cola_zero")
	var elig2: Array = SPONSORS.eligible_pool(taken)
	has_sing = false
	for o: Dictionary in elig2:
		if String(o.get("id", "")) == "spectral_cola_singularity":
			has_sing = true
	assert_true(has_sing, "step 2: singularity opens after zero taken")
	# Step 3: take Singularity; verify the finale predicate fires for it.
	var sing: Dictionary = SPONSORS.get_offer("spectral_cola_singularity")
	assert_true(SPONSORS.is_chain_finale(sing),
		"step 3: accepted card is the trilogy finale")
