## Main — entry point scene script.
## In later milestones this will instantiate BattleScene.
extends Control


func _ready() -> void:
	System.announce(&"battle_start", {})
	print("DESCENT: Main scene ready. GameRng seed = %d" % GameRng.DEFAULT_SEED)
