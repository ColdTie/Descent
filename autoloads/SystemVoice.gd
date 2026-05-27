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
		"Below 20% HP. The System estimates a 94% probability of failure.",
		"Critical HP. Your body is filing a formal complaint.",
		"You are technically still alive. Technically.",
		"Low HP detected. Perhaps consider a less confrontational approach.",
		"You're running on spite and luck. The System is curious which runs out first.",
	],
	"surrounded": [
		"Three enemies. One of you. The System finds this mathematically interesting.",
		"Surrounded. Your tactical positioning is... creative.",
		"Encircled. The dungeon suggests staying away from corners.",
		"They've closed in. The System is mildly impressed you're still breathing.",
		"Multiple hostiles adjacent. This is precisely what happens without a plan.",
	],
	"near_lava": [
		"You are adjacent to lava. The System marks this as 'ill-advised'.",
		"Lava proximity detected. The smell is not tactical.",
		"You are one misstep from a slow, volcanic death. Thought you should know.",
		"Standing by lava. The dungeon appreciates your commitment to danger.",
	],
	"backstab_hit": [
		"Backstab. Effective. The dungeon disapproves of your methods. The System approves.",
		"They never saw it coming. Literally — that's how backstab works.",
		"Strike from shadow. Maximum damage. Minimum sportsmanship.",
		"Armor? Circumvented. Dignity? Also circumvented.",
	],
	"first_kill": [
		"First kill of the run. The dungeon has been warned.",
		"Blood drawn. The System updates your threat assessment upward.",
		"First blood. The dungeon's residents are reconsidering their career choices.",
		"Initial elimination confirmed. Off to a body-positive start.",
	],
	"push_hit": [
		"Sent flying. Newton's laws, applied violently.",
		"Pushed back. The enemy reevaluates their positioning.",
		"Flung. The shield has spoken.",
		"Impact registered. They are now somewhere else. Somewhere worse.",
		"Airborne. Briefly. The lava nearby has opinions about this.",
	],
	"between_floors": [
		"Brief respite. Your wounds close, slightly. The dungeon is not moved.",
		"Between floors, the dungeon reluctantly allows 8% healing. Don't get used to it.",
		"Small mercy. Small. The System insists this changes nothing.",
		"Partial recovery. The dungeon sighs and patches your worst wounds.",
	],
	"boss_encounter": [
		"Boss floor. The dungeon has been saving this one. You should be concerned.",
		"A named entity approaches. This is the part where statistics become irrelevant.",
		"Boss detected. The System advises against hope, as it tends to cause disappointment.",
		"Floor boss. Significantly harder than everything you've fought. You're welcome.",
		"This one has a title. In the dungeon hierarchy, titles mean pain for you.",
	],
	"boss_defeated": [
		"Boss eliminated. The dungeon registers this as a critical error.",
		"Named entity defeated. The System is revising your threat assessment. Significantly.",
		"Boss dead. This should not have happened. The System is impressed. Mildly.",
		"You killed the boss. The dungeon's middle management is now understaffed.",
		"Champion slain. The dungeon files a formal protest. You ignore it.",
	],
	"hero_pushed": [
		"You have been launched. Physics, applied against you.",
		"Shoved. Repositioned against your will. By a Golem.",
		"Involuntary tactical repositioning detected.",
		"You are now somewhere else. The Golem planned this.",
		"Pushed. The System notes your new proximity to hazards.",
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
