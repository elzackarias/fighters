## HUD de combate: barras de vida dinámicas (con "daño fantasma" que baja con retraso),
## temporizador, marcadores de rounds ganados, mensajes centrales y pausa.
class_name FightHUD
extends CanvasLayer

const LOW_HEALTH_RATIO := 0.3

## FightArena lo activa solo durante el round.
var pause_allowed: bool = false

var _lag_tweens: Array[Tween] = [null, null]

@onready var _names: Array[Label] = [$Root/P1Name, $Root/P2Name]
@onready var _bars: Array[ProgressBar] = [$Root/P1Health, $Root/P2Health]
@onready var _lag_bars: Array[ProgressBar] = [$Root/P1HealthLag, $Root/P2HealthLag]
@onready var _wins: Array[Label] = [$Root/P1Wins, $Root/P2Wins]
@onready var _timer_label: Label = $Root/Timer
@onready var _level_label: Label = $Root/LevelLabel
@onready var _message: Label = $Root/Message
@onready var _score_label: Label = $Root/Score
@onready var _pause_panel: Control = $Root/PausePanel


func _ready() -> void:
	_message.hide()
	_pause_panel.hide()
	GameManager.score_changed.connect(_on_score_changed)
	_on_score_changed(GameManager.score)


func setup(player_name: String, enemy_name: String, level: LevelData, level_index: int) -> void:
	_names[0].text = player_name
	_names[1].text = enemy_name
	_level_label.text = "Nivel %d · %s" % [level_index + 1, level.stage_name]
	set_round_wins(0, 0, level.rounds_to_win)


## side: 0 = jugador (izquierda), 1 = rival (derecha).
func set_health(side: int, current: int, maximum: int) -> void:
	var bar := _bars[side]
	var lag := _lag_bars[side]
	bar.max_value = maximum
	lag.max_value = maximum
	bar.value = current
	bar.modulate = Color(1, 0.45, 0.45) if float(current) / maximum <= LOW_HEALTH_RATIO else Color.WHITE

	if _lag_tweens[side]:
		_lag_tweens[side].kill()
	if current >= lag.value:
		lag.value = current  # curación / reinicio de round
	else:
		var tw := create_tween()
		tw.tween_interval(0.35)
		tw.tween_property(lag, "value", float(current), 0.45).set_ease(Tween.EASE_OUT)
		_lag_tweens[side] = tw


func set_time(seconds: float) -> void:
	var s := ceili(seconds)
	_timer_label.text = str(s)
	_timer_label.modulate = Color(1, 0.4, 0.4) if s <= 10 else Color.WHITE


func set_round_wins(player_wins: int, enemy_wins: int, needed: int) -> void:
	_wins[0].text = _pips(player_wins, needed)
	_wins[1].text = _pips(enemy_wins, needed)


## Muestra un texto grande en el centro durante `duration` segundos (usar con await).
func show_message(text: String, duration: float) -> void:
	_message.text = text
	_message.show()
	_message.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(_message, "scale", Vector2.ONE, 0.2)
	# process_always = false: el temporizador se detiene si el juego está en pausa.
	await get_tree().create_timer(duration, false).timeout
	_message.hide()


func show_defeat_prompt() -> void:
	_message.text = "Derrota\n[Enter] Reintentar   [Esc] Menú"
	_message.show()


func _unhandled_input(event: InputEvent) -> void:
	if pause_allowed and event.is_action_pressed("pause"):
		var paused := not get_tree().paused
		get_tree().paused = paused
		_pause_panel.visible = paused
		get_viewport().set_input_as_handled()


func _on_score_changed(value: int) -> void:
	_score_label.text = "Puntos: %d" % value


func _pips(wins: int, needed: int) -> String:
	return "●".repeat(wins) + "○".repeat(maxi(needed - wins, 0))
