## IA de los oponentes. Se agrega como HIJO de un Fighter y llena su `commands`
## cada frame, exactamente igual que haría un jugador con el teclado.
##
## Máquina de estados:
##   IDLE    -> espera (observa).
##   CHASE   -> perseguir: camina hacia el jugador; puede saltar encima.
##   ATTACK  -> elige un golpe según la distancia.
##   BLOCK   -> mantiene bloqueo (agachado si el golpe del rival es bajo).
##   RETREAT -> retrocede para recuperar espacio.
##
## La dificultad se controla con 3 números (vienen del LevelData de cada nivel):
## reaction_time, aggression y block_chance.
class_name AIController
extends Node

enum AIState { IDLE, CHASE, ATTACK, BLOCK, RETREAT }

## Segundos entre decisiones (menos = reacciona más rápido).
@export_range(0.05, 1.5) var reaction_time: float = 0.4
@export_range(0.0, 1.0) var aggression: float = 0.5
@export_range(0.0, 1.0) var block_chance: float = 0.3
## Distancia (px entre centros) a la que sus golpes conectan.
@export var attack_range: float = 105.0
## Más cerca que esto, puede decidir retroceder.
@export var comfort_range: float = 70.0
## Probabilidad por segundo de saltar hacia el jugador mientras persigue.
@export var jump_in_rate: float = 0.5

var state: AIState = AIState.IDLE
var fighter: Fighter

var _think_timer: float = 0.0
var _state_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fighter = get_parent() as Fighter
	if fighter == null:
		push_error("AIController debe ser hijo de un Fighter.")
		set_physics_process(false)
		return
	fighter.is_player = false
	_rng.randomize()


## Ajusta la dificultad con los valores del nivel.
func configure_from_level(level: LevelData) -> void:
	reaction_time = level.ai_reaction_time
	aggression = level.ai_aggression
	block_chance = level.ai_block_chance


func _physics_process(delta: float) -> void:
	var cmd: Fighter.Commands = fighter.commands
	# Los comandos "hold" se recalculan cada frame.
	cmd.move_x = 0.0
	cmd.crouch = false
	cmd.block = false

	var foe := fighter.opponent
	if not fighter.controls_enabled or foe == null:
		_change_state(AIState.IDLE)
		return

	var dx := foe.global_position.x - fighter.global_position.x
	var dist := absf(dx)
	var toward := signf(dx) if dx != 0.0 else float(fighter.facing)

	_think_timer -= delta
	_state_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = reaction_time * _rng.randf_range(0.7, 1.3)  # algo de variación humana
		_decide(foe, dist)

	_execute(cmd, foe, dist, toward, delta)


## Elige el siguiente estado según distancia y lo que hace el jugador.
func _decide(foe: Fighter, dist: float) -> void:
	if fighter.is_stunned():
		return

	var threatened := foe.is_attacking() and dist < attack_range * 1.6
	if threatened and _rng.randf() < block_chance:
		_change_state(AIState.BLOCK, 0.45)
	elif dist > attack_range:
		# Lejos: perseguir (más probable cuanto más agresivo).
		if _rng.randf() < 0.35 + aggression * 0.65:
			_change_state(AIState.CHASE, 1.2)
		else:
			_change_state(AIState.IDLE, 0.3)
	elif dist < comfort_range and _rng.randf() > aggression + 0.2:
		_change_state(AIState.RETREAT, 0.35)
	elif _rng.randf() < 0.35 + aggression * 0.65:
		_change_state(AIState.ATTACK)
	elif _rng.randf() < block_chance + 0.2:
		_change_state(AIState.BLOCK, 0.4)
	else:
		_change_state(AIState.RETREAT, 0.3)


## Traduce el estado actual en comandos del luchador.
func _execute(cmd: Fighter.Commands, foe: Fighter, dist: float, toward: float, delta: float) -> void:
	# En el aire tras un salto: patada aérea cuando esté cerca.
	if fighter.state == Fighter.State.JUMP and dist < attack_range * 1.1:
		cmd.heavy = true
		return

	match state:
		AIState.CHASE:
			cmd.move_x = toward
			if dist <= attack_range * 0.9:
				_change_state(AIState.ATTACK)
			elif (
				dist > attack_range * 1.5 and dist < attack_range * 2.5
				and fighter.can_act()
				and _rng.randf() < jump_in_rate * aggression * delta
			):
				cmd.jump = true
			elif _state_timer <= 0.0:
				_change_state(AIState.IDLE, 0.2)

		AIState.ATTACK:
			if fighter.can_act():
				_press_attack(cmd, dist)
				_change_state(AIState.IDLE, reaction_time)

		AIState.BLOCK:
			cmd.block = true
			var incoming := foe.get_current_attack()
			cmd.crouch = incoming != null and incoming.height == AttackData.Height.LOW
			if _state_timer <= 0.0:
				_change_state(AIState.IDLE)

		AIState.RETREAT:
			cmd.move_x = -toward
			if _state_timer <= 0.0:
				_change_state(AIState.IDLE)

		AIState.IDLE:
			pass


func _press_attack(cmd: Fighter.Commands, dist: float) -> void:
	if dist > attack_range * 0.85:
		cmd.heavy = true  # el pesado tiene más alcance
		return
	var roll := _rng.randf()
	if roll < 0.45:
		cmd.light = true
	elif roll < 0.7:
		cmd.heavy = true
	elif roll < 0.85:
		cmd.crouch = true
		cmd.light = true
	else:
		cmd.crouch = true  # barrida
		cmd.heavy = true


func _change_state(new_state: AIState, duration: float = 0.5) -> void:
	state = new_state
	_state_timer = duration
