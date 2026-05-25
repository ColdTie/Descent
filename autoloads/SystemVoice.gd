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
	"hero_move": [
		"You moved. The dungeon was unimpressed.",
		"Tactical repositioning. Bold.",
		"Moving. The System approves of not standing in lava.",
		"Footwork noted. Barely.",
	],
	"lava_step": [
		"You stepped in lava. This was avoidable.",
		"Lava. Hot. Who knew.",
		"The floor is literally on fire. You walked on it anyway.",
	],
	"vanish": [
		"You disappear. The dungeon squints, confused.",
		"Gone from sight. Triple damage incoming. Try not to waste it.",
		"Vanished. The System recommends making this count.",
	],
	"taunt": [
		"You taunt the enemy horde. They are, in fact, taunted.",
		"Provocateur. Armor up.",
		"You invite their attention. And their wrath. +5 armor. Good luck.",
	],
	"fireball": [
		"Fire deployed. Effective, if imprecise.",
		"Combustion event detected. Multiple hostiles singed.",
		"Fireball. Classic. The System notes the scorched floor.",
	],
	"frost_nova": [
		"Temperature drop registered. Enemies frozen.",
		"Frost Nova. Everyone stops moving. Briefly.",
		"Ice applied to enemy surfaces. Tactical pause granted.",
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
