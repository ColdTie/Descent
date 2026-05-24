## System — the in-fiction narrator autoload.
## announce() pushes a canned line to the combat log.
## Signature is stable: the body can later call the Anthropic API
## without changing any call sites.
extends Node

# ---------------------------------------------------------------------------
# Canned lines per event.  {token} placeholders are replaced from ctx.
# ---------------------------------------------------------------------------
const _LINES: Dictionary = {
	"battle_start": [
		"Initiating encounter. Try not to embarrass yourself, Carl.",
		"ENCOUNTER INITIATED. The System is watching. As always.",
		"New dungeon room detected. Threat level: definitely above Carl's pay grade.",
	],
	"hit": [
		"{attacker} hits {defender} for {damage} damage!",
		"{attacker} connects — {damage} damage to {defender}.",
		"Direct hit. {defender} takes {damage} from {attacker}.",
	],
	"miss": [
		"{attacker} swings at {defender} and misses.",
		"{attacker}'s attack goes wide. {defender} is unimpressed.",
		"Miss. The System notes {attacker} should probably practice more.",
	],
	"kill": [
		"{defender} has been eliminated. The System marks it in the ledger.",
		"{defender} is dead. One fewer problem for Carl.",
		"Hostile down. {defender} will not be getting back up.",
	],
	"carl_hurt": [
		"Carl takes {damage} damage! {hp} HP remaining.",
		"Ouch — Carl is down to {hp} HP. Concerning.",
		"Carl absorbs {damage} damage. The System suggests a bandage. {hp} HP left.",
	],
	"victory": [
		"VICTORY! All hostiles eliminated. The System is mildly impressed, Carl.",
		"Encounter complete. You survived. Barely, but survived.",
		"All enemies dead. The System awards Carl... modest respect.",
	],
	"defeat": [
		"DEFEAT. Carl has been slain. The System is unsurprised.",
		"Carl has died. Perhaps the boxers and bathrobe were not optimal armor.",
		"You are dead, Carl. Better luck next floor. Oh wait.",
	],
}

# ---------------------------------------------------------------------------
# Log panel reference (set by BattleScene once the UI is ready)
# ---------------------------------------------------------------------------
var _log_lines: Array[String] = []
var _log_label: RichTextLabel = null


## Called by BattleScene to wire up the UI label.
func set_log_label(label: RichTextLabel) -> void:
	_log_label = label
	# Flush any buffered lines accumulated before the UI was ready.
	for line: String in _log_lines:
		_append_to_label(line)
	_log_lines.clear()


## Push a narration line for [param event] with context [param ctx].
## ctx keys match the {token} placeholders in _LINES.
func announce(event: StringName, ctx: Dictionary) -> void:
	var pool: Array = _LINES.get(String(event), ["[SYSTEM] Unknown event: %s" % event])
	# Use GameRng so line selection is deterministic under the same seed.
	var idx: int = GameRng.roll(pool.size()) - 1
	var line: String = pool[idx]
	# Substitute context tokens.
	for key: String in ctx:
		line = line.replace("{%s}" % key, str(ctx[key]))
	var formatted: String = "[The System] " + line
	print(formatted)
	if _log_label:
		_append_to_label(formatted)
	else:
		_log_lines.append(formatted)


func _append_to_label(line: String) -> void:
	if _log_label == null:
		return
	_log_label.append_text(line + "\n")
