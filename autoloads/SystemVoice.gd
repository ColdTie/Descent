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
		"Critical HP detected. The System recommends NOT dying.",
		"Below 20% HP. The dungeon can smell the desperation.",
		"You're at death's door. Don't knock.",
		"HP critical. The System's investment in you is nearly lost.",
	],
	"first_kill": [
		"First blood. There will be more. Probably.",
		"The kill counter opens. Statistically, you need to keep going.",
		"One down. The dungeon shrugs and dispatches reinforcements.",
		"Eliminated. Decent start. Don't get comfortable.",
	],
	"backstab_hit": [
		"Backstab — through the armor and into something soft.",
		"Struck from a blind angle. The armor meant nothing. As intended.",
		"Clean hit. The target didn't see it coming. Clearly.",
		"Ignore armor: activated. The System approves.",
	],
	"surrounded": [
		"You are encircled. Tactically, this is suboptimal.",
		"Multiple hostiles in melee range. The System suggests panic.",
		"Three or more enemies adjacent. Good luck with that.",
		"Surrounded. If you had a plan, now would be the time.",
	],
	"shield_bash_lava": [
		"Shield Bash into lava. The System rates this 9/10.",
		"Slam and burn. Efficient use of the environment.",
		"Sent flying into lava. The burns are complimentary.",
		"The lava does what the shield started. Beautiful.",
	],
	"war_cry": [
		"War Cry! The dungeon echoes with something resembling confidence.",
		"Battle fury engaged. Attack bonus applied. Make it count.",
		"Rallied. The System is cautiously optimistic.",
	],
	"chain_lightning": [
		"Lightning arcs. Electricity is an equal-opportunity weapon.",
		"Chain Lightning. The dungeon pays its electric bill in screams.",
		"Arcing through the horde. Physics cooperates, for once.",
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
