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
	"hero_low_hp": [
		"Warning: Hero HP critical. The System notes your impending doom.",
		"Low HP detected. This would be a good time to panic.",
		"You're nearly dead. Statistically, this should already be over.",
		"Critical HP. The dungeon is holding its breath. Mockingly.",
		"Hemorrhaging. Impressive. Not in a good way.",
	],
	"first_kill": [
		"First blood. They won't be the last.",
		"Kill confirmed. You have the System's reluctant attention.",
		"One down. An embarrassing number to go.",
		"That one's dead. Others have noticed. Good luck.",
		"First fatality recorded. Yours eventually.",
	],
	"backstab_hit": [
		"Backstab! Armor is irrelevant when you attack the soft bits.",
		"Strike from shadow. The target did not appreciate the ambush.",
		"Backstab connected. The System approves, grudgingly.",
		"Cowardly and effective. The best kind of attack.",
	],
	"hero_near_lava": [
		"You're standing next to lava. This is your fault.",
		"Lava proximity detected. The System recommends moving. Immediately.",
		"Adjacent to lava. The dungeon admires your optimism.",
		"Heat damage is real. The System reminds you this was preventable.",
	],
	"hero_surrounded": [
		"Surrounded. This is either bravery or catastrophic positioning.",
		"Multiple hostiles in melee range. Statistical survival: low.",
		"They've got you surrounded. How efficient of them.",
		"Surrounded. The System recommends a different career path.",
		"Encircled. The dungeon applauds your tactical creativity. Sarcastically.",
	],
	"shield_bash": [
		"Shield Bash! Sent flying. Physics is your ally.",
		"Knocked back. Gravity and momentum work in your favor. For once.",
		"Bashed. They are now somewhere else. That's progress.",
		"Shield Bash connects. The enemy disagrees with their new position.",
	],
	"ability_unlock": [
		"New ability acquired. The dungeon is moderately concerned.",
		"Unlocked. What will you do with it? The System is mildly curious.",
		"Ability granted. Wield it well. Or at all. Set the bar low.",
		"You've learned something. The dungeon revises its survival estimate upward. Slightly.",
	],
	"between_floors": [
		"Resting. You've earned it. The dungeon finds this annoying.",
		"Brief respite. The wounds close slightly. The danger does not.",
		"Recovery phase. Enjoy it. The next floor is worse.",
		"Patching you up. The System's investment in your survival continues.",
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
