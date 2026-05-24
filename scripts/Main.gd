## Main — entry point.  Loads and starts the BattleScene.
extends Node

const BattleSceneScene: PackedScene = preload("res://scenes/BattleScene.tscn")


func _ready() -> void:
	print("DESCENT: Main ready — loading BattleScene")
	var battle: Node = BattleSceneScene.instantiate()
	add_child(battle)
