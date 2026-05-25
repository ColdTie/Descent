extends Control
## YOU DIED screen — shown after the hero falls.
## Displays The System's closing comment and run summary.

signal restart_requested

@onready var _system_label: Label = $VBox/SystemLabel
@onready var _stats_label: Label = $VBox/StatsLabel
@onready var _restart_btn: Button = $VBox/RestartButton

func _ready() -> void:
	SystemVoice.line_spoken.connect(_on_system_line)
	SystemVoice.speak("death")
	_stats_label.text = _build_stats_text()
	_restart_btn.pressed.connect(func() -> void: restart_requested.emit())

func _on_system_line(text: String, _dur: float) -> void:
	_system_label.text = text

func _build_stats_text() -> String:
	var lines: Array[String] = []
	lines.append("Floor reached:   %d" % GameState.floor_num)
	lines.append("Enemies killed:  %d" % GameState.enemies_killed)
	lines.append("Level reached:   %d" % GameState.hero_level)
	lines.append("Class:           %s" % Classes.get_class_data(GameState.hero_class).get("display_name", GameState.hero_class))
	return "\n".join(lines)
