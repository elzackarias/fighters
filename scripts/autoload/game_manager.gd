## Autoload global "GameManager" (registrado en project.godot).
## Controla el flujo de pantallas, el progreso por los 3 niveles,
## los rounds ganados de la pelea actual y el puntaje total.
##
## Flujo: Menú -> Instrucciones -> Nivel 1 -> Nivel 2 -> Nivel 3 -> Pantalla de victoria
## (Nota: sin class_name a propósito; el nombre del autoload ya es global.)
extends Node

signal level_started(index: int, level: LevelData)
signal round_result_registered(result: RoundResult)
signal score_changed(score: int)

enum RoundResult { DRAW, PLAYER, ENEMY }
enum MatchState { IN_PROGRESS, PLAYER_WON, ENEMY_WON }

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const INSTRUCTIONS_SCENE := "res://scenes/ui/instructions.tscn"
const ARENA_SCENE := "res://scenes/levels/fight_arena.tscn"
const VICTORY_SCENE := "res://scenes/ui/victory_screen.tscn"
const PLAYER_FIGHTER := "res://resources/fighters/chavo/chavo.tres"
const LEVELS: Array[String] = [
	"res://resources/levels/level_1_patio.tres",
	"res://resources/levels/level_2_casa_ramon.tres",
	"res://resources/levels/level_3_acapulco.tres",
]
const FADE_TIME := 0.35

## Controles por defecto (teclado + mando). Se registran al iniciar si no existen
## en Proyecto > Configuración > Mapa de entrada, así puedes redefinirlos allí.
const DEFAULT_KEYS := {
	"p1_left": [KEY_A, KEY_LEFT],
	"p1_right": [KEY_D, KEY_RIGHT],
	"p1_up": [KEY_W, KEY_UP],
	"p1_down": [KEY_S, KEY_DOWN],
	"p1_light": [KEY_J, KEY_Z],
	"p1_heavy": [KEY_K, KEY_X],
	"p1_block": [KEY_L, KEY_C],
	"p1_special": [KEY_I, KEY_V],
	"pause": [KEY_ESCAPE, KEY_P],
}
const DEFAULT_PAD_BUTTONS := {
	"p1_left": [JOY_BUTTON_DPAD_LEFT],
	"p1_right": [JOY_BUTTON_DPAD_RIGHT],
	"p1_up": [JOY_BUTTON_DPAD_UP, JOY_BUTTON_A],
	"p1_down": [JOY_BUTTON_DPAD_DOWN],
	"p1_light": [JOY_BUTTON_X],
	"p1_heavy": [JOY_BUTTON_Y],
	"p1_block": [JOY_BUTTON_RIGHT_SHOULDER],
	"p1_special": [JOY_BUTTON_B],
	"pause": [JOY_BUTTON_START],
}

var current_level_index: int = 0
var round_number: int = 1
var player_round_wins: int = 0
var enemy_round_wins: int = 0
var score: int = 0
var levels_cleared: int = 0
var total_rounds_won: int = 0
var total_rounds_lost: int = 0

var _transitioning: bool = false
var _fade_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # las transiciones funcionan aunque haya pausa
	_register_default_inputs()
	_create_fade_layer()


# --- Navegación --------------------------------------------------------------

func start_new_game() -> void:
	current_level_index = 0
	score = 0
	levels_cleared = 0
	total_rounds_won = 0
	total_rounds_lost = 0
	score_changed.emit(score)
	_load_current_level()


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU_SCENE)


func go_to_instructions() -> void:
	change_scene(INSTRUCTIONS_SCENE)


func retry_level() -> void:
	_load_current_level()


## Lo llama FightArena cuando el jugador gana la pelea del nivel actual.
func complete_level() -> void:
	levels_cleared += 1
	if current_level_index + 1 < LEVELS.size():
		current_level_index += 1
		_load_current_level()
	else:
		change_scene(VICTORY_SCENE)


func is_last_level() -> bool:
	return current_level_index == LEVELS.size() - 1


# --- Datos del nivel ---------------------------------------------------------

func get_current_level() -> LevelData:
	return load(LEVELS[current_level_index]) as LevelData


func get_player_data() -> FighterData:
	return load(PLAYER_FIGHTER) as FighterData


# --- Rounds y puntaje --------------------------------------------------------

## Reinicia el conteo de rounds. FightArena lo llama al empezar cada pelea.
func begin_match() -> void:
	round_number = 1
	player_round_wins = 0
	enemy_round_wins = 0


func register_round_result(result: RoundResult) -> void:
	match result:
		RoundResult.PLAYER:
			player_round_wins += 1
			total_rounds_won += 1
		RoundResult.ENEMY:
			enemy_round_wins += 1
			total_rounds_lost += 1
	round_number += 1
	round_result_registered.emit(result)


func get_match_state() -> MatchState:
	var needed := get_current_level().rounds_to_win
	if player_round_wins >= needed:
		return MatchState.PLAYER_WON
	if enemy_round_wins >= needed:
		return MatchState.ENEMY_WON
	return MatchState.IN_PROGRESS


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


# --- Transiciones ------------------------------------------------------------

## Cambia de escena con fundido a negro.
func change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_TIME)
	await tween.finished

	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_TIME)
	await tween.finished
	_transitioning = false


func _load_current_level() -> void:
	level_started.emit(current_level_index, get_current_level())
	change_scene(ARENA_SCENE)


func _create_fade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)
	add_child(layer)


func _register_default_inputs() -> void:
	for action: String in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in DEFAULT_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button: JoyButton in DEFAULT_PAD_BUTTONS.get(action, []):
			var jev := InputEventJoypadButton.new()
			jev.button_index = button
			InputMap.action_add_event(action, jev)
	# Stick izquierdo para moverse.
	_add_axis("p1_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("p1_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("p1_down", JOY_AXIS_LEFT_Y, 1.0)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
