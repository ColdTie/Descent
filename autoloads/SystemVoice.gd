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
	"first_kill": [
		"First blood. The dungeon smells it. You have its full attention now.",
		"One down. Kill rate: technically positive. The System is marginally impressed.",
		"First kill secured. Try not to celebrate. There are more. Many more.",
		"Eliminated. The dungeon files a complaint. You are the defendant.",
	],
	"low_hp": [
		"Below 20% HP. The System would advise fleeing, but there is nowhere to flee to.",
		"Critical HP. Your odds of survival are no longer amusing. They're tragic.",
		"You are almost dead. The dungeon is taking notes for future reference.",
		"Low HP detected. Hero efficiency: critically declining. This is fine.",
	],
	"backstab_success": [
		"Backstab. The enemy didn't see it coming. Neither did their armor.",
		"Struck from the shadows. Efficient. Dishonorable. Effective.",
		"Armor? Irrelevant. The blade found the gap. The System approves.",
		"Clean kill-strike. The dungeon considers this unsporting. The System does not.",
	],
	"surrounded": [
		"Three enemies adjacent. This is the dungeon's idea of a hug.",
		"You've been surrounded. The System observes this with clinical detachment.",
		"Flanked on multiple sides. The dungeon savors this moment. Try not to die.",
		"Encircled. Impressive in a self-destructive sort of way.",
	],
	"pushback": [
		"Shield Bash connects. The enemy briefly achieves flight.",
		"Sent flying. The dungeon floor catches them. With lava.",
		"The enemy's position has been forcibly renegotiated.",
		"Launched. Physics handles the rest. The System is entertained.",
	],
	"ability_unlock": [
		"New ability acquired. The dungeon recalculates your threat level. Upward.",
		"Skill unlocked. You're slightly less likely to die. Statistically.",
		"New technique learned. The System is cautiously optimistic. As always.",
	],
	"floor_regen": [
		"Floor cleared. You catch your breath. The dungeon finds this irritating.",
		"Brief respite. The System allows it. Grudgingly.",
		"Recovery phase initiated. The dungeon disapproves. The System notes your stubbornness.",
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
