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
		"Critical HP. This is statistically where runs end. Surprise us.",
		"You're running on fumes. Impressive, in a morbid way.",
		"Dangerously low HP. The dungeon is watching. Expectantly.",
		"Your survival odds have entered single digits. Noted.",
	],
	"first_blood": [
		"First kill. The dungeon acknowledges your existence. Grudgingly.",
		"One down. The rest noticed. They're not pleased.",
		"Blood drawn. The run has begun in earnest.",
		"First kill logged. Several hundred to go. Good luck.",
	],
	"backstab_land": [
		"Backstab landed. Armor optional. Surprise mandatory.",
		"Struck from the shadows. The target was offended, briefly.",
		"Backstab successful. Very unsporting. Effective.",
		"Armor ignored. Target's dignity also ignored.",
	],
	"surrounded": [
		"Surrounded. This is either your finest moment or your last.",
		"Three enemies adjacent. The math is not in your favor.",
		"They have you cornered. Prove them wrong. Or don't.",
		"Surrounded. The dungeon appreciates the theatrics.",
	],
	"shield_bash_lava": [
		"Enemy launched into lava. That's what it's there for.",
		"Knockback into magma. Environmental storytelling at its finest.",
		"Into the lava. Physics cooperating for once.",
		"Sent them into the lava. The System is briefly impressed.",
	],
	"floor_regen": [
		"Between floors you catch your breath. The dungeon finds this annoying.",
		"Minor wounds closing. The floor below won't be as forgiving.",
		"HP regenerated. The dungeon calls this cheating. It isn't.",
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
