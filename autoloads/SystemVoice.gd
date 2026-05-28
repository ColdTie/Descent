extends Node
## The System: dry, mocking commentary in the DCC style.
## Each category has a pool; we cycle with RNG to avoid repeats.

signal line_spoken(text: String, duration: float)

const LINES: Dictionary = {
	"hit": [
		"Oh, that definitely left a mark.",
		"Efficient. Brutally so.",
		"The enemy bleeds. How quaint.",
		"You're getting blood on the floor. That's MY floor.",
		"Ouch. For them.",
	],
	"kill": [
		"Another one. Keep it up, Hero.",
		"That creature has been permanently retired.",
		"Eliminated. The dungeon notes your progress with mild irritation.",
		"You have, once again, defied probability.",
		"One less monster. One million to go. Good luck.",
	],
	"level_up": [
		"Level up. Try not to get overconfident. It's embarrassing when you die.",
		"You've grown. The dungeon has noticed. It's not pleased.",
		"New level. Same odds of survival. Congratulations, I suppose.",
		"Ding. Your statistical life expectancy increased by 0.3%. You're welcome.",
	],
	"player_hit": [
		"That's going to bruise.",
		"Pain is just the dungeon saying hello.",
		"You've been damaged. Continuing to bleed is suboptimal.",
		"Ow. The System suggests you consider ducking.",
	],
	"death": [
		"And there it is. The floor claims another hero.",
		"Dead. The dungeon expresses its condolences insincerely.",
		"Game over, Hero. The System was rooting for you. Mostly.",
		"You have died. This is embarrassing for both of us.",
	],
	"floor_enter": [
		"Floor %d. Things are getting worse. As expected.",
		"Welcome to Floor %d. Abandon hope, et cetera.",
		"Descending to Floor %d. The air smells of sulfur and bad decisions.",
		"Floor %d. Statistically, you shouldn't be here. Yet here you are.",
	],
	"loot": [
		"Choose your reward. Choose wisely. Or don't. It's your funeral.",
		"Loot detected. The System recommends the one that keeps you alive longest.",
		"Spoils of victory. Take something. The dungeon won't wait.",
	],
	"class_select": [
		"Select your class, Hero. This determines how you die.",
		"Choose your doomed archetype.",
		"Pick wisely. Or don't. You'll probably die anyway.",
	],
	"low_hp": [
		"Below 20%% HP. The System is hesitantly impressed you're still breathing.",
		"That's not a lot of blood left, Hero. Conserve it.",
		"Critical HP. This is where runs typically end. Statistically speaking.",
		"You appear to be mostly dead. Carry on.",
	],
	"surrounded": [
		"You are surrounded. The dungeon appreciates the dramatic irony.",
		"Multiple hostiles adjacent. The System suggests panic.",
		"They've formed a circle. How neighborly.",
		"Cornered. Out of options. Just like the tutorial warned.",
	],
	"backstab_hit": [
		"Backstab connected. Armor circumvented. The System approves, reluctantly.",
		"Clean kill from the shadows. Professionally done.",
		"Armor ignored. Target perforated. The rogue way.",
		"Hit them where they weren't looking. Cowardly. Effective.",
	],
	"first_kill": [
		"First blood of the run. The dungeon has noted your presence.",
		"One down. The remaining enemies have been informed.",
		"A kill. The run begins in earnest.",
		"That creature is no longer a problem. Others remain.",
	],
	"push_into_lava": [
		"Into the lava. That's what it's there for.",
		"Environmental hazard weaponized. The System is impressed.",
		"You pushed them in. They did not enjoy this.",
		"The lava closes over them. Efficient. Brutal. Correct.",
	],
	"push_blocked": [
		"Push blocked. They hit a wall. Still counts as a bad day for them.",
		"Nowhere to fly. The dungeon walls had opinions.",
		"Blocked. They stay upright. Unfortunate.",
	],
	"lava_adjacent": [
		"You're standing next to lava. On purpose, presumably.",
		"The heat is tactical. Or suicidal. Hard to say.",
		"Lava adjacent. The System recommends not staying there.",
	],
	"unlock_ability": [
		"New ability acquired. The dungeon updates its threat assessment.",
		"You've learned something. Probably too late, but still.",
		"Ability unlocked. Your odds of survival increase marginally.",
	],
	"floor_regen": [
		"Between floors, your wounds close. Slightly. Don't get used to it.",
		"Passive regeneration applied. The System acknowledges your persistence.",
	],
}

var _last_indices: Dictionary = {}

func speak(category: String, format_args: Array = []) -> void:
	var pool: Array = LINES.get(category, ["..."])
	var last: int = _last_indices.get(category, -1)
	var idx: int = GameRng.randi_range(0, pool.size() - 1)
	# Avoid immediate repeat
	if pool.size() > 1 and idx == last:
		idx = (idx + 1) % pool.size()
	_last_indices[category] = idx
	var text: String = pool[idx]
	if not format_args.is_empty():
		text = text % format_args
	line_spoken.emit(text, 3.0)

func speak_direct(text: String, duration: float = 3.0) -> void:
	line_spoken.emit(text, duration)
