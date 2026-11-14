## Escena de combate reutilizada por los 3 niveles ("árbitro").
## Lee el LevelData actual del GameManager, prepara escenario y luchadores,
## y controla: temporizador del round, KO, conteo de victorias y puntaje.
extends Node2D

const FIGHTER_SCENE := preload("res://scenes/fighters/fighter.tscn")
const MIN_SEPARATION := 60.0  # los luchadores no se atraviesan
const STAGE_LEFT := 60.0
const STAGE_RIGHT := 1220.0
## Cámara estilo Street Fighter: zoom fijo (en la escena) y sigue el punto medio
## entre los luchadores. Así se ven grandes sin tocar hitboxes ni velocidades.
const CAMERA_SCREEN_MARGIN := 45.0  # distancia mínima (mundo) de un luchador al borde visible

const SCORE_PER_DAMAGE := 10
const SCORE_ROUND_WIN := 1000
const SCORE_PER_SECOND_LEFT := 50
const SCORE_PERFECT := 2000

enum Phase { INTRO, FIGHTING, ROUND_OVER, MATCH_OVER }

var level: LevelData
var player: Fighter
var enemy: Fighter
var phase: Phase = Phase.INTRO
var time_left: float = 0.0
var _awaiting_retry: bool = false

@onready var _background: ColorRect = $Backdrop/Background
@onready var _background_sprite: Sprite2D = $Backdrop/BackgroundSprite
@onready var _stage_label: Label = $Backdrop/StageLabel
@onready var _camera: Camera2D = $Camera
@onready var _floor_visual: ColorRect = $Floor/Visual
@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _enemy_spawn: Marker2D = $EnemySpawn
@onready var _fighters_root: Node2D = $Fighters
@onready var _music: AudioStreamPlayer = $Music
@onready var _hud: FightHUD = $HUD


func _ready() -> void:
	level = GameManager.get_current_level()
	GameManager.begin_match()
	_setup_stage()
	_spawn_fighters()
	_hud.setup(player.data.display_name, enemy.data.display_name, level, GameManager.current_level_index)
	_start_round()


func _physics_process(delta: float) -> void:
	if phase == Phase.FIGHTING:
		time_left = maxf(time_left - delta, 0.0)
		_hud.set_time(time_left)
		if time_left <= 0.0:
			_end_round_by_time()
	_keep_fighters_apart()
	_keep_fighters_on_screen()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_retry:
		return
	if event.is_action_pressed("ui_accept"):
		_awaiting_retry = false
		GameManager.retry_level()
	elif event.is_action_pressed("ui_cancel"):
		_awaiting_retry = false
		GameManager.go_to_main_menu()


# --- Preparación -------------------------------------------------------------

func _setup_stage() -> void:
	_background.color = level.background_color
	_floor_visual.color = level.floor_color
	_stage_label.text = level.stage_name.to_upper()
	if level.background_texture:
		_background_sprite.texture = level.background_texture
		_stage_label.hide()
	if level.music:
		_music.stream = level.music
		_music.play()


func _spawn_fighters() -> void:
	player = FIGHTER_SCENE.instantiate()
	player.name = "Player"
	player.data = GameManager.get_player_data()
	player.is_player = true

	enemy = FIGHTER_SCENE.instantiate()
	enemy.name = "Enemy"
	enemy.data = level.opponent
	enemy.is_player = false

	_fighters_root.add_child(player)
	_fighters_root.add_child(enemy)

	var ai := AIController.new()
	ai.name = "AIController"
	ai.configure_from_level(level)
	enemy.add_child(ai)

	player.opponent = enemy
	enemy.opponent = player

	player.health_changed.connect(func(cur: int, mx: int) -> void: _hud.set_health(0, cur, mx))
	enemy.health_changed.connect(func(cur: int, mx: int) -> void: _hud.set_health(1, cur, mx))
	player.knocked_out.connect(_on_fighter_knocked_out)
	enemy.knocked_out.connect(_on_fighter_knocked_out)
	player.hit_landed.connect(_on_player_hit_landed)


# --- Flujo del round ---------------------------------------------------------

func _start_round() -> void:
	phase = Phase.INTRO
	time_left = level.round_time
	_set_controls(false)
	player.reset_for_round(_player_spawn.global_position)
	enemy.reset_for_round(_enemy_spawn.global_position)
	_update_camera()
	_camera.reset_smoothing()  # sin barrido desde la posición del round anterior
	_hud.set_time(time_left)
	_hud.set_round_wins(GameManager.player_round_wins, GameManager.enemy_round_wins, level.rounds_to_win)

	await _hud.show_message("Round %d" % GameManager.round_number, 1.2)
	await _hud.show_message("¡A pelear!", 0.7)
	if not is_inside_tree():
		return
	phase = Phase.FIGHTING
	_hud.pause_allowed = true
	_set_controls(true)


func _on_fighter_knocked_out(loser: Fighter) -> void:
	if phase != Phase.FIGHTING:
		return
	_finish_round(enemy if loser == player else player, "¡K.O.!")


func _end_round_by_time() -> void:
	var p_ratio := float(player.health) / player.data.max_health
	var e_ratio := float(enemy.health) / enemy.data.max_health
	var winner: Fighter = null
	if p_ratio > e_ratio:
		winner = player
	elif e_ratio > p_ratio:
		winner = enemy
	_finish_round(winner, "¡Tiempo!")


func _finish_round(winner: Fighter, reason: String) -> void:
	phase = Phase.ROUND_OVER
	_hud.pause_allowed = false
	_set_controls(false)

	var result := GameManager.RoundResult.DRAW
	if winner == player:
		result = GameManager.RoundResult.PLAYER
		GameManager.add_score(SCORE_ROUND_WIN + int(time_left) * SCORE_PER_SECOND_LEFT)
		if player.health == player.data.max_health:
			GameManager.add_score(SCORE_PERFECT)
	elif winner == enemy:
		result = GameManager.RoundResult.ENEMY
	GameManager.register_round_result(result)
	if winner:
		winner.set_victory()
	_hud.set_round_wins(GameManager.player_round_wins, GameManager.enemy_round_wins, level.rounds_to_win)

	await _hud.show_message(reason, 1.4)
	var announce := "¡Empate!" if winner == null else "¡Gana %s!" % winner.data.display_name
	await _hud.show_message(announce, 1.4)
	if not is_inside_tree():
		return

	match GameManager.get_match_state():
		GameManager.MatchState.PLAYER_WON:
			phase = Phase.MATCH_OVER
			var msg := "¡Ganaste la vecindad!" if GameManager.is_last_level() else "¡Nivel superado!"
			await _hud.show_message(msg, 1.8)
			GameManager.complete_level()
		GameManager.MatchState.ENEMY_WON:
			phase = Phase.MATCH_OVER
			_hud.show_defeat_prompt()
			_awaiting_retry = true
		_:
			_start_round()


# --- Utilidades --------------------------------------------------------------

func _set_controls(enabled: bool) -> void:
	player.controls_enabled = enabled
	enemy.controls_enabled = enabled


func _on_player_hit_landed(_target: Fighter, blocked: bool, damage: int) -> void:
	if not blocked:
		GameManager.add_score(damage * SCORE_PER_DAMAGE)


## "Pushbox" simple: evita que los luchadores se superpongan.
func _keep_fighters_apart() -> void:
	if player == null or enemy == null:
		return
	var dx := enemy.global_position.x - player.global_position.x
	var dy := absf(enemy.global_position.y - player.global_position.y)
	if absf(dx) >= MIN_SEPARATION or dy > 120.0:
		return
	var dir := signf(dx) if dx != 0.0 else float(player.facing)
	var push := (MIN_SEPARATION - absf(dx)) * 0.5
	player.global_position.x = clampf(player.global_position.x - dir * push, STAGE_LEFT, STAGE_RIGHT)
	enemy.global_position.x = clampf(enemy.global_position.x + dir * push, STAGE_LEFT, STAGE_RIGHT)


# --- Cámara ------------------------------------------------------------------

## Ancho del mundo que se ve en pantalla (depende del zoom y del tamaño de ventana).
func _visible_world_width() -> float:
	return get_viewport_rect().size.x / _camera.zoom.x


func _update_camera() -> void:
	if player == null or enemy == null:
		return
	_camera.position.x = (player.global_position.x + enemy.global_position.x) * 0.5


## Como en SF: los luchadores no pueden separarse más que el ancho de la pantalla.
## Se frena al que se está alejando; si ambos (o ninguno) se alejan, se reparte.
func _keep_fighters_on_screen() -> void:
	if player == null or enemy == null:
		return
	var max_separation := _visible_world_width() - CAMERA_SCREEN_MARGIN * 2.0
	var dx := enemy.global_position.x - player.global_position.x
	var excess := absf(dx) - max_separation
	if excess <= 0.0:
		return
	var dir := signf(dx)  # +1 si el enemigo está a la derecha
	var player_away := player.velocity.x * -dir > 0.0
	var enemy_away := enemy.velocity.x * dir > 0.0
	var player_share := 0.5
	if player_away and not enemy_away:
		player_share = 1.0
	elif enemy_away and not player_away:
		player_share = 0.0
	player.global_position.x += dir * excess * player_share
	enemy.global_position.x -= dir * excess * (1.0 - player_share)
	if player_away:
		player.velocity.x = 0.0
	if enemy_away:
		enemy.velocity.x = 0.0
