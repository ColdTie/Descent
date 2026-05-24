## BattleScene — root script for the combat encounter.
## Owns Grid, TurnManager, UnitsContainer, and UI.
## Populated incrementally across milestones.
extends Node2D

@onready var grid: Grid = $Grid
@onready var units_container: Node2D = $UnitsContainer


func _ready() -> void:
	System.announce(&"battle_start", {})
