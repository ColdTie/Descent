## Weapon — data resource describing a weapon or consumable.
## Attach to Unit via @export var weapons: Array[Weapon].
##
## Property naming note: `weapon_name` avoids shadowing Object internals;
## `weapon_range` avoids shadowing the built-in range() function.
class_name Weapon
extends Resource

## Display name shown in the log.
@export var weapon_name: String = ""

## Attack reach in grid tiles (Chebyshev / king-move distance).
@export var weapon_range: int = 1

## Bonus added to the d20 to-hit roll.
@export var to_hit: int = 0

## Damage rolled on a hit, e.g. "1d6".  Empty for consumables.
@export var damage_dice: String = ""

## True → this item is consumed on use (e.g. Bandage).
@export var is_consumable: bool = false

## Dice rolled for healing when used as a consumable, e.g. "1d6".
@export var heal_dice: String = ""
