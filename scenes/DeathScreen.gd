extends Control
## YOU DIED screen — shown when the hero falls in battle.

signal restart_requested

const QUIPS: Array[String] = [
	"You have died. This is embarrassing for both of us.",
	"Dead. The dungeon expresses its condolences insincerely.",
	"And there it is. The floor claims another hero.",
	"Game over, Hero. The System was rooting for you. Mostly.",
	"Statistical outcome confirmed: death.",
	"You died on floor %d. The System predicted this.",
	"The dungeon wins. Again. As it usually does.",
	"Your survival probability was always low. Now it is zero.",
]

@onready var _system_label:  Label  = $VBox/SystemLabel
@onready var _stats_label:   Label  = $VBox/StatsLabel
@onready var _restart_btn:   Button = $VBox/RestartButton

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_system_label.text = _get_quip()
	_stats_label.text  = _format_stats()
	_restart_btn.pressed.connect(_on_restart)
	# Fade in
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)

func _get_quip() -> String:
	var idx: int = _rng.randi_range(0, QUIPS.size() - 1)
	var q: String = QUIPS[idx]
	if q.count("%d") > 0:
		q = q % GameState.floor_num
	return q

func _format_stats() -> String:
	var text: String = "Floor Reached:    %d\n" % GameState.floor_num
	text += "Enemies Defeated: %d\n" % GameState.enemies_killed
	text += "Final Level:      %d\n" % GameState.hero_level
	text += "Class:            %s"   % GameState.hero_class.capitalize()
	return text

func _on_restart() -> void:
	restart_requested.emit()

func _input(event: InputEvent) -> void:
	# Allow pressing Enter/Space to restart
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
			_on_restart()
