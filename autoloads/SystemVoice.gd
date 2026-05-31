extends Node
## The System: dry, mocking commentary in the DCC style.
## Each category has a pool; we cycle with RNG to avoid repeats.
## Call speak() to emit a signal (shown in UI). Call pick() to get a string
## for caller-side formatting before passing to speak_direct().

signal line_spoken(text: String, duration: float)

const LINES: Dictionary = {

	# ── Combat: hitting an enemy ───────────────────────────────────────────────
	"hit": [
		"Hit confirmed. The dungeon takes note.",
		"Direct contact. Their structural integrity disagrees with your fist.",
		"Damage applied. The target files a complaint. The complaint is ignored.",
		"You hit something. Progress.",
		"The enemy bleeds. Standard dungeon procedure.",
		"Solid contact. The dungeon didn't recruit these things for their durability.",
		"Force applied. Results: promising.",
		"That's going to leave a mark. Several.",
		"Impact registered. Keep it up.",
		"The monster is reconsidering its career choices.",
		"Violence delivered. The System notes this with something approaching approval.",
		"Efficient. Brutally so.",
		"The enemy reports significant pain. It will not be filing a grievance.",
		"Hit. The dungeon twitches. You should find this encouraging.",
		"Good. Don't stop.",
	],

	# ── Combat: killing an enemy ───────────────────────────────────────────────
	"kill": [
		"Eliminated. The dungeon files a formal complaint. You are the subject.",
		"Dead. Impressively so. They don't always stay that way.",
		"The creature has concluded its participation in this encounter.",
		"Another casualty added to the ledger. The dungeon's ledger is very long.",
		"Terminated. The dungeon's HR department is short one employee.",
		"Kill confirmed. The remaining enemies received a notification.",
		"One fewer thing trying to murder you. Marginal improvement.",
		"Corpse created. Moving on. There are more.",
		"They're dead. Don't get sentimental. The dungeon has reserves.",
		"Neutralized. The dungeon recalibrates. You have approximately four seconds.",
		"Dead. As intended. Well, your intention. Not theirs.",
		"Statistical survival projection: slightly improved. Don't celebrate yet.",
		"That creature will no longer be a problem. A replacement is being sourced.",
		"Kill recorded. The dungeon is annoyed. You should find this encouraging.",
		"Eliminated. One less. Many more to go. The math is not in your favor.",
	],

	# ── Combat: first kill of an encounter ────────────────────────────────────
	"first_kill": [
		"First blood. The others are aware.",
		"Initial target down. The floor's remaining residents received a notification.",
		"First kill confirmed. The dungeon sharpens its response.",
		"One down. The dungeon adjusts. So should you.",
		"First elimination this floor. The System notes your opening performance.",
	],

	# ── Boss encounters ────────────────────────────────────────────────────────
	"boss_encounter": [
		"Boss-class entity detected. Adjust your expectations accordingly.",
		"Warning: high-value threat identified. This one was specifically designed for you.",
		"A named entity approaches. This is rarely good news. It is never good news.",
		"The dungeon has deployed a significant asset. Alarm is appropriate.",
		"Boss-tier threat active. The System recommends a strategy. Any strategy.",
		"Elite target confirmed. More HP. More armor. More anger. Proceed carefully.",
		"The dungeon sends its regards. Also its most dangerous employee.",
		"High-value combatant identified. The floor escalates. So should you.",
		"This one is different. It knows what it's doing. Probably more than you do.",
		"Boss detected. The dungeon is paying full attention now.",
		"Significant threat engaged. The System would say 'good luck' but that phrase is not in its vocabulary.",
		"A dungeon commander enters. This encounter has been elevated to Priority Status.",
	],

	"boss_killed": [
		"Floor commander eliminated. The dungeon is furious. This is now your problem.",
		"Boss down. The floors below received a memo. They are not pleased.",
		"High-value target neutralized. The dungeon revises its threat assessment. Upward.",
		"Named entity eliminated. The dungeon does not forget this.",
		"Commander destroyed. Impressive. The dungeon's quarterly review will reflect this.",
		"You killed the boss. The dungeon considers this a personal affront.",
		"Dominant creature defeated. New dominant creature being sourced from lower floors.",
		"Floor boss terminated. The System is impressed. The dungeon is not. Both matter.",
		"Boss eliminated. Well done, Hero. The dungeon will not let this stand.",
		"That was the floor boss. You killed it. The dungeon's management requests a meeting. You are not invited.",
	],

	# ── Hero takes damage ──────────────────────────────────────────────────────
	"player_hit": [
		"You've taken damage. The System recommends taking less of that.",
		"HP reduced. This is the expected outcome of standing in front of things that hate you.",
		"That hurt. The dungeon sends its regards.",
		"Damage received. The System observed this happening.",
		"You've been struck. This is not ideal.",
		"Pain inflicted. The monster seems pleased with itself. Don't let it win.",
		"HP decreasing. This is trending in the wrong direction.",
		"That's going to bruise. Several of those will be fatal.",
		"You were hit. The dungeon expresses satisfaction. Ignore it.",
		"Structural integrity compromised. Improve your positioning.",
		"The floor hurts back. This is a recurring theme.",
		"Ow. The System's medical advice: stop being in the way of things.",
		"Damage received. The dungeon considers this a partial victory. Do not give it the rest.",
		"You've been wounded. The System notes this. The dungeon celebrates. One of these reactions is appropriate.",
		"HP declining. The dungeon finds this trajectory encouraging. Be aware.",
	],

	# ── Critical HP ────────────────────────────────────────────────────────────
	"near_death": [
		"Critical HP alert. You are, technically speaking, almost dead.",
		"Your health is at a concerning level. The System is watching with great interest.",
		"Warning: life expectancy severely degraded. Immediate tactical reassessment advised.",
		"You are nearly dead. This is not an exaggeration. This is a status report.",
		"HP critical. The dungeon senses an opportunity. Do not give it one.",
		"Low HP detected. The System advises you to not get hit again. At all.",
		"You are held together by statistical improbability. This is not a compliment.",
		"Critical health. One more mistake may resolve this run permanently.",
		"The line between living and dead is very thin right now. Stay on your side of it.",
		"Severe HP depletion detected. The dungeon is getting excited. That is bad for you.",
		"Nearly dead. Not dead yet. The System genuinely prefers the second state. Mostly.",
		"Alert: you are one solid hit away from a very different kind of floor clear.",
	],

	# ── Hero death ─────────────────────────────────────────────────────────────
	"death": [
		"Dead. The dungeon updates its kill count. The number is very large.",
		"You have died. The System will not say it didn't see this coming.",
		"Hero down. The dungeon thanks you for your participation and your corpse.",
		"Eliminated. The run ends here. Your statistical contribution has been recorded.",
		"Death confirmed. This was always the most likely outcome. The dungeon is thorough.",
		"The hero falls. The System observes one second of silence. Time's up.",
		"You are dead. This is not a recoverable state. This is just a state.",
		"Fatal damage received. The dungeon considers this encounter a success. You should not.",
		"Dead. The dungeon doesn't gloat. It doesn't need to. It has an excellent track record.",
		"You've perished. The dungeon files this under 'expected results.'",
		"The run concludes. The dungeon was, statistically, always going to win this one.",
		"Hero terminated. The System pauses briefly. Something almost like respect. Almost.",
		"Dead. The dungeon notes your floor reached. It has seen higher. It has seen much lower.",
		"Failure state reached. The dungeon remains standing. As it does. As it will.",
		"You have died. This is embarrassing for both of us.",
	],

	# ── Floor entry (use %d for floor number) ──────────────────────────────────
	"floor_enter": [
		"Floor %d. Things are getting worse. As expected.",
		"Welcome to Floor %d. Abandon hope, et cetera. The dungeon means it.",
		"Descending to Floor %d. The air smells of sulfur and your bad decisions.",
		"Floor %d. Statistically, you should not be here. And yet.",
		"Floor %d. The monsters here are better-funded than the ones above.",
		"Floor %d active. The dungeon has noted your progress. It is not pleased.",
		"You've reached Floor %d. The dungeon is preparing a formal response.",
		"Floor %d. The dungeon's hospitality worsens with depth. This is intentional.",
		"Notification: you are on Floor %d. The dungeon would prefer you weren't.",
		"Floor %d. The deeper you go, the less funny this becomes. For you.",
		"Floor %d confirmed. Previous hero survival rate at this depth: insufficient to mention.",
		"Floor %d. The dungeon's patience wears thin here. So does the rock.",
		"Floor %d. You have no business being this deep. Here you are anyway.",
		"Floor %d. The dungeon has upgraded its personnel. Adjust accordingly.",
		"Entering Floor %d. The System suggests caution. The System always suggests caution. You rarely listen.",
		"Floor %d. Something worse waits at the bottom. It has been waiting a long time.",
		"Floor %d. The dungeon recalibrates for your current level. It has more room to work with than you do.",
		"Welcome to Floor %d, Hero. The dungeon prepared something special for you. You will not enjoy it.",
	],

	# ── Level up ───────────────────────────────────────────────────────────────
	"level_up": [
		"Level up. Try not to get overconfident. It's embarrassing when you die right after.",
		"You've grown stronger. The dungeon has been informed. It is adjusting.",
		"New level. Same dungeon. The odds remain unfavorable. Congratulations, I suppose.",
		"Ding. Your statistical life expectancy increased by a measurable fraction. You're welcome.",
		"Level gained. The monsters on lower floors just got a memo.",
		"You've leveled. The dungeon sharpens its response accordingly.",
		"Level increase registered. The System updates your file. The file grows heavier.",
		"Leveled. You're stronger. The dungeon is already compensating. As it does.",
		"Another level. The System acknowledges your progress with the bare minimum of enthusiasm.",
		"Level up. Statistically, you are slightly less dead than you were. Marginally.",
		"Your stats have increased. This is good. It is also not enough. Keep going.",
		"Level up. The dungeon finds this irritating. You should find that encouraging.",
	],

	# ── Loot selection ─────────────────────────────────────────────────────────
	"loot": [
		"Choose one. The others are forfeit. The dungeon is contractually obligated to offer this. It resents the clause.",
		"Post-battle compensation. One item. Make it count.",
		"Rewards available. The System suggests the option that maximizes your survival coefficient.",
		"Select quickly. The dungeon's generosity has an expiration time.",
		"Loot dispensed. The dungeon assures you these are all equally useful. The dungeon is lying.",
		"Spoils of the floor. Take one. Then descend. Nothing gets friendlier from here.",
		"One item from three options. The dungeon thinks you'll pick wrong. Prove it incorrect.",
		"Post-combat dispensary active. One choice. No refunds. No exchanges. No complaints.",
		"Select your upgrade, Hero. Choose as though your life depends on it. It does.",
		"Floor loot unlocked. The dungeon hates this part. Take full advantage.",
		"Reward time. The System recommends analyzing each option carefully. You will not. Choose.",
		"Compensation offered for services rendered — specifically, not dying. Pick wisely.",
	],

	# ── Class selection screen ─────────────────────────────────────────────────
	"class_select": [
		"Select your class. This determines how you die. Choose deliberately.",
		"Choose your archetype. The dungeon is evaluating which one it prefers to kill.",
		"Class selection required. The System knows which is optimal. It won't say.",
		"Three classes. Three different paths to the bottom. All of them dangerous.",
		"Pick a class. The dungeon has contingency plans for all of them.",
		"Your class determines your abilities. Your abilities determine your floor reached. Choose carefully.",
		"Select. The dungeon is waiting. It has been waiting for participants for some time.",
		"Choose your role. This is permanent. Much like your eventual death. Though hopefully not yet.",
		"Your chosen class shapes this run. The dungeon has read the specifications. It is prepared.",
		"Three options. One decision. No take-backs. The System observes your process with interest.",
	],

	# ── After selecting a class (use %s for class name) ────────────────────────
	"class_chosen": [
		"You've chosen %s. Bold. Probably foolish. Let's find out.",
		"%s selected. The dungeon has updated its threat assessment for your kit. Proceed.",
		"So. %s. The System has seen this before. It ends various ways.",
		"%s. The dungeon makes a note. It does not seem worried. This is concerning.",
		"You've committed to %s. The dungeon acknowledges this. It is not impressed. Yet.",
		"%s confirmed. Let's see how far you get. The System is watching.",
	],

	# ── Hero movement ──────────────────────────────────────────────────────────
	"move": [
		"Tactical repositioning. The System is cautiously optimistic.",
		"You move. The dungeon shrugs.",
		"New position acquired. Try not to die there either.",
		"Repositioned. The dungeon recalculates its angles.",
		"Movement confirmed. The dungeon adjusts.",
		"Position changed. Whether this is an improvement remains to be seen.",
		"You've moved. The dungeon is aware.",
		"Tactical advance. Or retreat. The System isn't judging. Much.",
	],

	# ── Ability: fireball (no count — miss) ───────────────────────────────────
	"ability_fireball_miss": [
		"Fireball detonates. Impressively. On nothing.",
		"The fireball found no targets. The dungeon is briefly amused.",
		"Combustion applied to empty air. Expensive. Ineffective. Try again.",
		"Fireball confirms: there is no one there. The dungeon files this under 'wasted potential.'",
	],

	# ── Ability: fireball (with count, use %d for targets) ────────────────────
	"ability_fireball_hit": [
		"Fireball! %d target(s) caught in the blast. The dungeon notes your lack of restraint.",
		"Combustion delivered to %d target(s) simultaneously. Physics cooperates.",
		"%d target(s) ignited. The dungeon finds this excessive. That's the point.",
		"Fireball confirmed: %d target(s) in the burn radius. Clean.",
	],

	# ── Ability: frost nova (miss) ─────────────────────────────────────────────
	"ability_frost_miss": [
		"Frost Nova fires into empty space. The dungeon sighs.",
		"Nothing frozen. The cold was wasted. The dungeon registers zero sympathy.",
		"Frost Nova detonates on vacant hexes. The floor is briefly chilly. That's all.",
		"The cryogenic field found no targets. This was suboptimal.",
	],

	# ── Ability: frost nova (with count, use %d for frozen) ───────────────────
	"ability_frost_hit": [
		"Frost Nova! %d enemy(ies) frozen. Cold comfort. Make it count.",
		"Cryogenic field locks down %d target(s). The window is open. Use it.",
		"%d enemy(ies) immobilized. They thaw. They remember this. Move fast.",
		"Frozen solid: %d target(s). Temporarily. Strike now or regret it.",
	],

	# ── Ability: taunt ─────────────────────────────────────────────────────────
	"ability_taunt": [
		"Taunted. You now have everyone's attention. This was the plan. Hopefully.",
		"All aggression redirected to you. You asked for this. Quite literally.",
		"Every hostile in range wants you specifically dead. This is called leadership.",
		"You've made yourself the target. The System applauds your confidence. It does not share it.",
		"Taunt successful. All eyes on you. The armor better hold.",
		"Attention acquired. All of it. The dungeon's personnel converge. Be ready.",
	],

	# ── Ability: vanish ────────────────────────────────────────────────────────
	"ability_vanish": [
		"Vanished. The dungeon's targeting algorithms are briefly confused.",
		"Invisible. Or near enough. Strike fast. The effect is temporary.",
		"Gone. For now. The dungeon hates this ability. Use it well.",
		"Concealment active. What you do next matters considerably.",
		"You've disappeared. The enemies are looking. They won't find you. For now.",
		"Stealth engaged. The dungeon cannot see you. Mostly. Be efficient.",
	],

	# ── Ability: backstab ──────────────────────────────────────────────────────
	"ability_backstab": [
		"Backstab executed. Armor bypassed. Damage maximized. Ethics: unaddressed.",
		"Critical strike from concealment. They did not see it coming. Literally.",
		"Backstab confirmed. Full damage, no reduction. Efficient.",
		"You stabbed them in the back. The dungeon finds this unsportsmanlike. Do it again.",
		"Stealth attack landed. The enemy is reconsidering its positioning. Too late.",
		"Critical hit from the shadows. Clean, lethal, efficient. Three words the dungeon reserves for you.",
	],

	# ── Ability on cooldown ────────────────────────────────────────────────────
	"ability_cooldown": [
		"Ability on cooldown. Patience is also a skill. A less exciting one.",
		"Not available yet. The dungeon does not accept requests to accelerate recharge.",
		"Cooldown in progress. Choose a different approach.",
		"That ability needs more time. Work with what you have.",
		"Unavailable. The System suggests the abilities that are currently functional.",
		"On cooldown. The dungeon is not sympathetic to your scheduling preferences.",
		"Recharging. Pick something else. The dungeon won't wait.",
	],

	# ── Out of range ───────────────────────────────────────────────────────────
	"out_of_range": [
		"Target is outside ability range. Close the distance first.",
		"Out of range. Physics persist even in the dungeon.",
		"Not in range. Move closer or select a different ability.",
		"Distance exceeds reach. The dungeon will not make an exception.",
		"Too far. Abilities have limits. So does patience.",
		"Range check failed. The System suggests moving before attacking.",
	],

	# ── Victory screen quips ───────────────────────────────────────────────────
	"victory": [
		"Floor cleared. The dungeon is mildly impressed. That's as good as it gets.",
		"All hostiles eliminated. The System awards a grudging nod.",
		"You survived. Statistically, this was improbable. Don't read too much into it.",
		"Victory. The dungeon recalibrates. You should be concerned about what that means.",
		"Floor complete. Something worse waits below. You knew this.",
		"Enemies defeated. You remain alive. For now. The dungeon is adjusting.",
		"All threats neutralized. The System records this in your file. The entry is brief.",
		"Floor cleared. The dungeon takes notes. It is a thorough note-taker.",
		"Survival confirmed. The dungeon notes your continued existence with something approaching irritation.",
		"You've cleared this floor. The dungeon concedes the point. It does not concede the war.",
		"Encounter complete. XP awarded. The dungeon does not award participation trophies. You earned this.",
		"Good work, Hero. The System almost means that. Almost.",
		"Floor clear. You are still alive. The dungeon finds this statistically inconvenient.",
		"All threats down. The floor is yours. The next floor is not. Proceed accordingly.",
		"Cleared. The dungeon sharpens its next floor in response. This is a compliment. Accept it.",
	],

	# ── Ability: shield_bash ──────────────────────────────────────────────────
	"shield_bash": [
		"Shield Bash. They went somewhere else entirely.",
		"You launched them. Physics confirmed. Results pending.",
		"Tactical repositioning of an enemy. Without asking their opinion.",
		"The enemy is now somewhere it did not plan to be. This is your doing.",
		"Bash confirmed. They traveled. Involuntarily.",
		"Full contact. They've been reassigned to a different hex.",
		"Shield impact: successful. Trajectory: not their choice.",
	],

	# ── Pushed into lava ──────────────────────────────────────────────────────
	"pushed_into_lava": [
		"Launched directly into lava. The dungeon finds this satisfying. The creature does not.",
		"Physics and fire collaborate on a kill. Efficient.",
		"They landed in lava. This was not their plan. It was yours. Well done.",
		"Lava contact confirmed. The dungeon revises its deployment strategy.",
		"Into the lava. The System approves of this outcome with unusual enthusiasm.",
		"The lava was waiting. You provided the delivery. Functional teamwork.",
	],

	# ── Hero surrounded (3+ enemies adjacent) ────────────────────────────────
	"surrounded": [
		"You are surrounded. This is suboptimal. The dungeon's positioning is deliberate.",
		"Multiple threats at close range. Tactically, you should not be here.",
		"Surrounded. The dungeon considers this a personal success.",
		"You are encircled. The System notes this with something that may be concern.",
		"Three or more enemies at range zero. The dungeon calls this 'working as intended.'",
		"Surrounded. Retreat was an option earlier. It is less of one now.",
		"Threat envelope: all sides. The dungeon's personnel have you where they want you.",
		"Encirclement confirmed. The System wishes you a statistically unlikely survival.",
	],

	# ── Hero takes damage (triggered in combat, not every hit) ────────────────
	"took_hit_comment": [
		"You took damage. The dungeon considers this progress.",
		"HP reduced. You should be lower on the priority list now. You aren't.",
		"That landed. The dungeon registers satisfaction. Deny it that.",
		"Structural integrity declining. The monsters are cooperating today.",
		"They hit you. This is one of the less ideal scenarios. Do better.",
		"Hit confirmed. The dungeon's morale is improving. Yours should not be.",
	],

	# ── Win screen (cleared all 18 floors) ────────────────────────────────────
	"win": [
		"Floor 18 cleared. The System is surprised. Don't let it go to your head.",
		"You've reached the bottom. Somehow. Against all statistical projections.",
		"Run complete. The dungeon concedes. You are, marginally, impressive.",
		"18 floors. All hostiles dead. The System has no further commentary at this time.",
		"You won. The dungeon did not anticipate this outcome. Neither did the System, frankly.",
		"All 18 floors cleared. The dungeon would like you to know it was not trying its hardest. This is a lie.",
		"Complete. You descended all the way down. The dungeon is furious. That is an achievement.",
		"Run concluded. Hero victorious. Probability: low. Outcome: somehow this.",
		"You cleared the dungeon. The System is processing. This takes longer than expected.",
		"18 floors. You are, by any reasonable metric, an anomaly. The dungeon files this under: unacceptable.",
		"Congratulations, Hero. The dungeon will be making significant changes before the next run.",
		"You survived the descent. All of it. The System's records indicate this is rare. The System's records are an understatement.",
	],
}

var _last_indices: Dictionary = {}


func speak(category: String, format_args: Array = []) -> void:
	var text: String = pick(category)
	if not format_args.is_empty():
		text = text % format_args
	line_spoken.emit(text, 3.2)


func pick(category: String) -> String:
	## Return a random line from a category without emitting a signal.
	## Useful when the caller needs to format the string before display.
	var pool: Array = LINES.get(category, ["..."])
	var last: int = _last_indices.get(category, -1)
	var idx: int = GameRng.randi_range(0, pool.size() - 1)
	if pool.size() > 1 and idx == last:
		idx = (idx + 1) % pool.size()
	_last_indices[category] = idx
	return pool[idx]


func speak_direct(text: String, duration: float = 3.2) -> void:
	line_spoken.emit(text, duration)
