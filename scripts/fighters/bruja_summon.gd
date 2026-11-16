## La Bruja del 71 (súper de Chavo). Aparece detrás de quien la invoca, lanza rayos
## sobre el rival esté donde esté y, si el primero pega, lo convierte en mula o en
## Rubia Margot; luego explota y lo devuelve a la normalidad con un último golpe.
## Si el primer rayo es bloqueado (o el rival es invulnerable), se va y el súper termina.
##
## La crea Fighter._spawn_summon() con un AttackData cuyo `summon` es esta escena:
## attack.damage es el daño de CADA rayo; final_damage, el de la explosión.
extends Node2D

const BRUJA_FRAMES := preload("res://resources/fighters/chavo/bruja_frames.tres")

## Línea de tiempo en frames de juego (60 por segundo) desde que aparece.
@export var laugh_at: int = 24
@export var cast_at: int = 44
@export var first_bolt_at: int = 52
@export var bolt_count: int = 4
@export var bolt_interval: int = 9
@export var transform_hold: int = 66  # frames que dura transformado
@export var final_damage: int = 14
@export var witch_scale: float = 1.3

var _owner: Fighter
var _target: Fighter
var _attack: AttackData
var _frame: int = 0
var _bolts_done: int = 0
var _transform_at: int = -1
var _explode_at: int = -1
var _finished: bool = false
var _witch: AnimatedSprite2D


func setup(owner_fighter: Fighter, attack: AttackData) -> void:
	_owner = owner_fighter
	_target = owner_fighter.opponent
	_attack = attack
	var side := owner_fighter.facing
	global_position = owner_fighter.global_position + Vector2(-side * 105.0, -175.0)
	_witch = AnimatedSprite2D.new()
	_witch.sprite_frames = BRUJA_FRAMES
	_witch.scale = Vector2(witch_scale * side, witch_scale)  # el dibujo mira a la derecha
	add_child(_witch)
	_witch.play(&"appear")
	_puff(global_position + Vector2(0, 60))


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	if not is_instance_valid(_owner) or not is_instance_valid(_target):
		_vanish()
		return
	if _owner.freeze_frames > 0:
		return  # respeta la pantalla de súper
	_frame += 1

	if _frame == laugh_at:
		_witch.play(&"laugh")
	elif _frame == cast_at:
		_witch.play(&"cast")

	if _bolts_done < bolt_count and _frame == first_bolt_at + _bolts_done * bolt_interval:
		_bolt()
	if _frame == _transform_at:
		_transform()
	if _frame == _explode_at:
		_explode()


func _bolt() -> void:
	_bolts_done += 1
	var first := _bolts_done == 1
	_draw_lightning(_target.global_position + Vector2(0, -_target.data.body_height * 0.5))
	if first and (_target.is_invulnerable() or _target.state == Fighter.State.KO):
		_fail()
		return
	var damage := roundi(_attack.damage * _owner.data.damage_multiplier)
	var blocked := _target.receive_hit(_attack, _owner, damage, _target.global_position.x, false)
	_owner.notify_hit(_target, blocked, damage)
	if blocked:
		_fail()
		return
	if _target.health <= 0:
		_leave()  # K.O. con los rayos: sin transformación
		return
	_target.hold(bolt_interval * 2 + transform_hold + 30)
	if _bolts_done == bolt_count:
		_transform_at = _frame + 10


func _transform() -> void:
	if _target.state != Fighter.State.THROWN:
		_leave()
		return
	_puff(_target.global_position)
	var form := &"mula" if randf() < 0.5 else &"margot"
	_target.set_disguise(BRUJA_FRAMES, form)
	_target.hold(transform_hold + 20)
	_explode_at = _frame + transform_hold
	_witch.play(&"leave")


func _explode() -> void:
	_puff(_target.global_position)
	_target.clear_disguise()
	if _target.state == Fighter.State.THROWN:
		var damage := roundi(final_damage * _owner.data.damage_multiplier)
		var blocked := _target.receive_hit(_attack, _owner, damage, _target.global_position.x, true)
		_owner.notify_hit(_target, blocked, damage)
	_vanish()


## El hechizo no entró: la Bruja se va y Chavo sale de la garrotera.
func _fail() -> void:
	_owner.cut_attack_short()
	_leave()


func _leave() -> void:
	_bolts_done = bolt_count
	_witch.play(&"leave")
	get_tree().create_timer(0.3, false).timeout.connect(_vanish)


func _vanish() -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_target):
		_target.clear_disguise()
	_puff(global_position + Vector2(0, 60))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## Rayo en zigzag desde arriba de la pantalla hasta `to`.
func _draw_lightning(to: Vector2) -> void:
	var bolt := Line2D.new()
	bolt.width = 7.0
	bolt.default_color = Color(1.0, 1.0, 0.75)
	bolt.top_level = true  # coordenadas de mundo, no relativas a la Bruja
	var top := to + Vector2(randf_range(-40, 40), -520)
	var steps := 9
	for i in steps + 1:
		var t := float(i) / steps
		var p := top.lerp(to, t)
		if i > 0 and i < steps:
			p.x += randf_range(-28, 28)
		bolt.add_point(p)
	var glow := bolt.duplicate() as Line2D
	glow.width = 18.0
	glow.default_color = Color(0.7, 0.9, 1.0, 0.45)
	add_child(glow)
	add_child(bolt)
	for line: Line2D in [glow, bolt]:
		var tw := line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.18)
		tw.tween_callback(line.queue_free)


## Humo verde de aparición/transformación.
func _puff(at: Vector2) -> void:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = BRUJA_FRAMES
	fx.position = at + Vector2(0, -40)
	fx.scale = Vector2.ONE * 1.4
	fx.add_to_group(&"round_fx")
	get_parent().add_child(fx)  # no depende de la Bruja: termina aunque ella se vaya
	fx.play(&"puff")
	fx.animation_finished.connect(fx.queue_free)
