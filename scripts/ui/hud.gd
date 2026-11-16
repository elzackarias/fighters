## HUD de combate: barras de vida dinámicas (con "daño fantasma" que baja con retraso),
## temporizador, marcadores de rounds ganados, mensajes centrales y pausa.
class_name FightHUD
extends CanvasLayer

const LOW_HEALTH_RATIO := 0.3

## FightArena lo activa solo durante el round.
var pause_allowed: bool = false

var _lag_tweens: Array[Tween] = [null, null]
## Barra de poder (bajo los nombres): se llena por barra y un número cuenta las guardadas.
var _power_bars: Array[ProgressBar] = []
var _power_labels: Array[Label] = []

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
	_build_power_bars()
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


## side: 0 = jugador, 1 = rival. per_bar = poder que llena una barra.
func set_power(side: int, current: int, maximum: int, per_bar: int) -> void:
	var bar := _power_bars[side]
	var stocks := current / per_bar
	var full := current >= maximum
	bar.max_value = per_bar
	bar.value = per_bar if full else current % per_bar
	_power_labels[side].text = "MAX" if full else str(stocks)
	var color := Color(1.0, 0.35, 0.2) if full else (Color(0.3, 0.85, 1.0) if stocks > 0 else Color(0.25, 0.55, 1.0))
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color
	_power_labels[side].modulate = color if stocks > 0 else Color(1, 1, 1, 0.6)


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


func _build_power_bars() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.12, 0.85)
	bg.set_border_width_all(2)
	bg.border_color = Color.WHITE
	for side in 2:
		var fill := StyleBoxFlat.new()  # una por lado: el color cambia según el poder
		fill.bg_color = Color(0.25, 0.55, 1.0)
		var bar := ProgressBar.new()
		bar.name = "P%dPower" % (side + 1)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		bar.size = Vector2(300, 16)
		bar.position = Vector2(40 if side == 0 else 940, 114)
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if side == 0 else ProgressBar.FILL_END_TO_BEGIN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Root.add_child(bar)
		_power_bars.append(bar)

		var label := Label.new()
		label.name = "P%dPowerStock" % (side + 1)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.size = Vector2(64, 34)
		label.position = Vector2(348 if side == 0 else 868, 104)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		label.text = "0"
		$Root.add_child(label)
		_power_labels.append(label)
		set_power(side, 0, 300, 100)

