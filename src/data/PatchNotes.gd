class_name PatchNotes
## Run 20: DCC reality-show "patch notes" between dungeon tiers.
##
## The System hot-patches the dungeon mid-run, like an unstable game live
## service. We show its mocking dev-blog at tier transitions: floors 7 and 13.
## Pure flavor — the difficulty curve underneath is what it always was — but
## framed as if the System just shipped a balance patch.
##
## Pure data, no autoload references. Safe in --script tests.

## Map: floor the player is ENTERING -> patch payload.
## When `Main` is about to descend, it checks `notes_for(target_floor)`. If
## non-empty and not yet in `GameState.patch_notes_seen`, the patch screen
## plays before the actual floor change.
const NOTES: Dictionary = {
	7: {
		"version": "v1.7  —  Obsidian Cycle",
		"subtitle": "The dungeon thanks you for your continued participation.",
		"lines": [
			"+ Enemies above Floor 6 have been retired. Their assets are now allocated downward.",
			"- Retired: Cave Bats, Stone Skeletons. Their tier was unprofitable. They thank you.",
			"+ NEW: Void Wraiths deployed. Fast. Ranged. Upset about something.",
			"+ NEW: Plague Goblins added to the Floor 8+ roster. Poison damage included.",
			"+ Skeletal Warriors on Floor 10+ unlock Bone Volley. Working as intended.",
			"+ The Warden gains a signature ground slam. Adjacency strongly discouraged.",
			"+ Below 15% HP, the Warden enters Frenzy: slam radius widens. Be elsewhere.",
			"+ Lava ambient temperature normalized. (No, it is not cooler.)",
			"+ Audience favor multiplier set to x1.0 for the Obsidian tier. Earn it.",
			"- Removed: \"Compassion\" subroutine. It was unused.",
			"# Known issue: hero remains alive. Patching in progress.",
		],
		"closing": "Please direct all complaints to the dungeon's complaint department. It does not exist.",
	},
	13: {
		"version": "v1.13  —  Void Cycle",
		"subtitle": "The dungeon's management requests a brief moment of your time.",
		"lines": [
			"+ Demon Hellfire AoE now deployed on Floor 13+. Floor flammability: updated.",
			"+ NEW: Bone Colossus units online. Slow. Inevitable. Door-shaped.",
			"+ NEW: Ember Imps released. Small. Numerous. Flammable in both directions.",
			"+ The Abyss Keeper unlocks Void Pull. Distance was a phase.",
			"+ The Dungeon Lord may now reanimate one fallen minion. Per encounter.",
			"+ Boss Phase 3 ('Frenzy') active dungeon-wide at sub-15% HP. Signatures escalate.",
			"+ Frenzied Dungeon Lord raises every corpse at once. Storage was overflowing.",
			"+ Frenzied Abyss Keeper folds every hero in range. Compression for efficiency.",
			"+ Void-tier monster stipend increased. They are paid in your HP.",
			"+ Boss enrage threshold confirmed at 30%. Working as intended. Still.",
			"+ Reality-show audience favor multiplier increased to x1.2 for the Void tier.",
			"- Removed: \"Mercy\" routine. It was untested.",
			"- Removed: hope. Backup unavailable.",
			"# Known issue: hero has reached Floor 13. Investigating.",
		],
		"closing": "The dungeon appreciates your engagement metrics. The dungeon will now resume murdering you.",
	},
}


static func has_notes_for(floor_num: int) -> bool:
	return NOTES.has(floor_num)


static func notes_for(floor_num: int) -> Dictionary:
	return NOTES.get(floor_num, {})


static func all_floors() -> Array:
	return NOTES.keys()
