## Luchador base (jugador y CPU) sobre CharacterBody2D.
##
## Arquitectura:
## - El luchador NO decide qué hacer: lee un objeto `commands` cada frame.
##   * Si is_player = true, `commands` se llena desde el teclado/mando.
##   * Si no, lo llena un AIController hijo. Así jugador y CPU comparten 100% la lógica.
## - Máquina de estados simple (enum State) que corre en _physics_process.
## - Hitbox (Area2D, capa 3) golpea a Hurtbox (Area2D, capa 4) del rival.
## - El origen del nodo está en los PIES del personaje.
class_name Fighter
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal knocked_out(fighter: Fighter)
signal hit_landed(target: Fighter, blocked: bool, damage: int)
signal state_changed(new_state: State)

enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, BLOCK, HITSTUN, BLOCKSTUN, KO, VICTORY }


## Comandos de un frame. "Hold" = mantener; "one-shot" = recién presionado.
class Commands:
	var move_x: float = 0.0  # hold: -1 izquierda .. 1 derecha
	var crouch: bool = false  # hold
	var block: bool = false  # hold (además, mantener "atrás" también bloquea)
	var jump: bool = false  # one-shot
	var light: bool = false  # one-shot
	var heavy: bool = false  # one-shot

	func clear() -> void:
		move_x = 0.0
		crouch = false
		block = false
		jump = false
		light = false
		heavy = false


const GRAVITY := 1900.0
const MAX_FALL_SPEED := 1500.0
const GROUND_FRICTION := 2400.0
const BACKWALK_FACTOR := 0.75  # caminar hacia atrás es más lento
const INPUT_BUFFER_FRAMES := 6  # golpes presionados poco antes de poder actuar se guardan
const CROUCH_HURTBOX_RATIO := 0.62
const ATTACK_FRAME_RATE := 60.0  # los frames de AttackData están definidos a 60 fps
const GROUNDED_STATES: Array[State] = [State.IDLE, State.WALK, State.CROUCH, State.BLOCK]
## Animaciones opcionales y la que se usa si el personaje no la tiene dibujada.
## Si tampoco existe la de respaldo, se usa "idle".
const ANIM_FALLBACKS := {
	&"walk_back": &"walk",
	&"fall": &"jump",
	&"crouch_block": &"block",
	&"hit_hard": &"hit",
	&"hit_low": &"hit",
	&"hit_air": &"hit",
	&"crouch_hit": &"hit",
}
## Golpes con este hitstun o más usan la animación de golpe fuerte.
const HARD_HIT_STUN_FRAMES := 20
## Altura para la que están diseñadas las formas de fighter.tscn (cuerpo y hurtbox).
const BASE_BODY_HEIGHT := 140.0

@export var data: FighterData
@export var is_player: bool = true
## Prefijo de las acciones del InputMap (p1_left, p1_light...). Permite un futuro P2 local.
@export var input_prefix: String = "p1_"
## Muestra el rectángulo de la hitbox aunque el luchador tenga sprites (para ajustar balance).
@export var show_hitboxes: bool = false

var state: State = State.IDLE
var health: int = 100
var facing: int = 1  # 1 = mira a la derecha, -1 = a la izquierda
var opponent: Fighter
## El árbitro (FightArena) lo activa solo durante el round.
var controls_enabled: bool = false
var commands := Commands.new()

var _idle_commands := Commands.new()  # se usa cuando los controles están bloqueados
var _current_attack: AttackData
var _attack_frame: int = 0
var _attack_in_air: bool = false
var _attack_crouching: bool = false
var _air_attack_used: bool = false
var _hit_targets: Array[Fighter] = []
var _stun_frames: int = 0
var _buffered_attack: StringName = &""
var _buffer_frames: int = 0
var _flash_time: float = 0.0
var _stand_hurt_size: Vector2
var _stand_hurt_pos: Vector2
var _attack_has_animation: bool = false
var _hit_animation: StringName = &"hit"

@onready var _body: Node2D = $Body
@onready var _placeholder: ColorRect = $Body/Placeholder
@onready var _sprite: AnimatedSprite2D = $Body/Sprite
@onready var _attack_visual: ColorRect = $AttackVisual
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Los sub-recursos de una escena se COMPARTEN entre instancias: duplicamos las
	# formas para que agacharse o atacar no modifique también al rival.
	_hurtbox_shape.shape = _hurtbox_shape.shape.duplicate()
	_hitbox_shape.shape = _hitbox_shape.shape.duplicate()
	_body_shape.shape = _body_shape.shape.duplicate()
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	_sprite.frame_changed.connect(_anchor_sprite_to_feet)
	_sprite.animation_changed.connect(_anchor_sprite_to_feet)

	if data == null:
		push_warning("%s no tiene FighterData; usando valores por defecto." % name)
		data = FighterData.new()
	_apply_body_size()
	_stand_hurt_size = (_hurtbox_shape.shape as RectangleShape2D).size
	_stand_hurt_pos = _hurtbox_shape.position
	_apply_data()


func _physics_process(delta: float) -> void:
	if is_player and controls_enabled:
		_read_player_input()
	var cmd: Commands = commands if controls_enabled else _idle_commands

	_update_input_buffer(cmd)
	_update_facing()

	match state:
		State.IDLE, State.WALK, State.CROUCH, State.BLOCK:
			_process_grounded(cmd, delta)
		State.JUMP:
			_process_air()
		State.ATTACK:
			_process_attack(delta)
		State.HITSTUN, State.BLOCKSTUN:
			_process_stun(delta)
		State.KO, State.VICTORY:
			if is_on_floor():
				_apply_friction(delta)

	_apply_gravity(delta)
	move_and_slide()
	_consume_one_shots()
	_update_visuals(delta)


# --- API pública (la usan FightArena y AIController) --------------------------

## Coloca al luchador para un nuevo round con la vida llena.
func reset_for_round(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = data.max_health
	_cancel_attack()
	_stun_frames = 0
	_buffered_attack = &""
	_air_attack_used = false
	commands.clear()
	_change_state(State.IDLE)
	_update_facing(true)
	health_changed.emit(health, data.max_health)


## Recibe un golpe. Devuelve true si fue bloqueado.
func receive_hit(attack: AttackData, attacker: Fighter, damage: int) -> bool:
	if state == State.KO or state == State.VICTORY:
		return false

	var push_dir := signf(global_position.x - attacker.global_position.x)
	if push_dir == 0.0:
		push_dir = -float(facing)

	if _is_blocking(attack):
		_take_damage(attack.chip_damage)
		_flash(Color(0.55, 0.75, 1.0))
		if health <= 0:
			_knock_out(push_dir)
		else:
			_stun_frames = attack.blockstun_frames
			velocity.x = push_dir * attack.knockback.x * 0.6
			_change_state(State.BLOCKSTUN)
		return true

	_cancel_attack()  # un golpe interrumpe tu ataque
	_take_damage(damage)
	_flash(Color(1.0, 0.35, 0.35))
	_hit_animation = _pick_hit_animation(attack)
	_play_animation(_hit_animation, true)  # reinicia aunque ya estuviera aturdido
	if health <= 0:
		_knock_out(push_dir)
		return false

	_stun_frames = attack.hitstun_frames
	velocity.x = push_dir * attack.knockback.x
	if attack.knockback.y != 0.0:
		velocity.y = attack.knockback.y
	elif not is_on_floor():
		velocity.y = -220.0  # golpe en el aire: pequeño rebote
	_change_state(State.HITSTUN)
	return false


func set_victory() -> void:
	if state != State.KO:
		_cancel_attack()
		_change_state(State.VICTORY)


## Puede iniciar una acción nueva (no está atacando, aturdido ni en el aire).
func can_act() -> bool:
	return state in GROUNDED_STATES and is_on_floor()


## True durante startup/activos de un ataque (lo usa la IA para reaccionar).
func is_attacking() -> bool:
	return (
		state == State.ATTACK
		and _current_attack != null
		and _attack_frame <= _current_attack.startup_frames + _current_attack.active_frames
	)


func get_current_attack() -> AttackData:
	return _current_attack if state == State.ATTACK else null


func is_stunned() -> bool:
	return state in [State.HITSTUN, State.BLOCKSTUN, State.KO]


func is_crouching() -> bool:
	return state == State.CROUCH or (state == State.ATTACK and _attack_crouching)


# --- Entrada -----------------------------------------------------------------

func _read_player_input() -> void:
	var p := input_prefix
	commands.move_x = Input.get_axis(p + "left", p + "right")
	commands.crouch = Input.is_action_pressed(p + "down")
	commands.block = Input.is_action_pressed(p + "block")
	commands.jump = Input.is_action_just_pressed(p + "up")
	commands.light = Input.is_action_just_pressed(p + "light")
	commands.heavy = Input.is_action_just_pressed(p + "heavy")


## Guarda el último golpe presionado unos frames para que no se "pierda"
## si se presionó justo antes de terminar una recuperación.
func _update_input_buffer(cmd: Commands) -> void:
	if cmd.light:
		_buffered_attack = &"light"
		_buffer_frames = INPUT_BUFFER_FRAMES
	elif cmd.heavy:
		_buffered_attack = &"heavy"
		_buffer_frames = INPUT_BUFFER_FRAMES
	elif _buffer_frames > 0:
		_buffer_frames -= 1
	else:
		_buffered_attack = &""


func _take_buffered_attack() -> StringName:
	var kind := _buffered_attack
	_buffered_attack = &""
	_buffer_frames = 0
	return kind


func _consume_one_shots() -> void:
	commands.jump = false
	commands.light = false
	commands.heavy = false


# --- Estados -----------------------------------------------------------------

func _process_grounded(cmd: Commands, delta: float) -> void:
	if not is_on_floor():
		_change_state(State.JUMP)
		return

	var kind := _take_buffered_attack()
	if kind != &"":
		_start_attack(_pick_attack(kind, cmd.crouch, false), cmd.crouch)
		return

	if cmd.jump:
		velocity.y = data.jump_velocity
		velocity.x = signf(cmd.move_x) * data.walk_speed  # salto neutro / adelante / atrás
		_air_attack_used = false
		_change_state(State.JUMP)
		return

	if cmd.crouch:
		_apply_friction(delta)
		_change_state(State.CROUCH)
	elif cmd.block:
		_apply_friction(delta)
		_change_state(State.BLOCK)
	elif absf(cmd.move_x) > 0.1:
		var dir := signf(cmd.move_x)
		var speed_factor := BACKWALK_FACTOR if int(dir) != facing else 1.0
		velocity.x = dir * data.walk_speed * speed_factor
		_change_state(State.WALK)
	else:
		_apply_friction(delta)
		_change_state(State.IDLE)


func _process_air() -> void:
	if is_on_floor() and velocity.y >= 0.0:
		_change_state(State.IDLE)
		return
	var kind := _take_buffered_attack()
	if kind != &"" and not _air_attack_used:
		_air_attack_used = true
		_start_attack(data.air_attack, false)


func _process_attack(delta: float) -> void:
	var attack := _current_attack
	_attack_frame += 1

	if _attack_in_air:
		# Aterrizar cancela el ataque aéreo.
		if _attack_frame > 1 and is_on_floor() and velocity.y >= 0.0:
			_end_attack()
			return
	else:
		_apply_friction(delta)

	if _attack_frame == attack.startup_frames + 1:
		_set_hitbox_active(true)
	elif _attack_frame == attack.startup_frames + attack.active_frames + 1:
		_set_hitbox_active(false)

	if _attack_frame >= attack.total_frames():
		_end_attack()


func _process_stun(delta: float) -> void:
	if is_on_floor():
		_apply_friction(delta)
	_stun_frames -= 1
	if _stun_frames <= 0 and is_on_floor():
		_change_state(State.IDLE)


func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)


# --- Ataques -----------------------------------------------------------------

func _pick_attack(kind: StringName, crouching: bool, in_air: bool) -> AttackData:
	if in_air:
		return data.air_attack
	if crouching:
		return data.crouch_light_attack if kind == &"light" else data.crouch_heavy_attack
	return data.light_attack if kind == &"light" else data.heavy_attack


func _start_attack(attack: AttackData, crouching: bool) -> void:
	if attack == null:
		return
	_current_attack = attack
	_attack_frame = 0
	_attack_in_air = not is_on_floor()
	_attack_crouching = crouching
	_hit_targets.clear()

	# La hitbox se orienta según hacia dónde mira el luchador.
	var shape := _hitbox_shape.shape as RectangleShape2D
	shape.size = attack.hitbox_size
	_hitbox_shape.position = Vector2(attack.hitbox_offset.x * facing, attack.hitbox_offset.y)
	_change_state(State.ATTACK)
	_play_attack_animation(attack)


func _end_attack() -> void:
	var was_crouching := _attack_crouching
	_cancel_attack()
	if not is_on_floor():
		_change_state(State.JUMP)
	else:
		_change_state(State.CROUCH if was_crouching else State.IDLE)


func _cancel_attack() -> void:
	_set_hitbox_active(false)
	_current_attack = null
	_attack_frame = 0
	_attack_crouching = false


func _set_hitbox_active(active: bool) -> void:
	# set_deferred: no se pueden cambiar formas de colisión en medio de un paso de física.
	_hitbox_shape.set_deferred("disabled", not active)
	# El rectángulo solo se ve si no hay animación que represente el golpe (o en debug).
	_attack_visual.visible = active and (show_hitboxes or not _attack_has_animation)
	if active:
		var size := _current_attack.hitbox_size
		_attack_visual.size = size
		_attack_visual.position = _hitbox_shape.position - size / 2.0


func _on_hitbox_area_entered(area: Area2D) -> void:
	if state != State.ATTACK or _current_attack == null:
		return
	var target := area.get_parent() as Fighter
	if target == null or target == self or target in _hit_targets:
		return
	_hit_targets.append(target)  # cada ataque golpea una sola vez
	var damage := roundi(_current_attack.damage * data.damage_multiplier)
	var blocked := target.receive_hit(_current_attack, self, damage)
	hit_landed.emit(target, blocked, damage)


# --- Daño / bloqueo ----------------------------------------------------------

func _is_blocking(attack: AttackData) -> bool:
	if not is_on_floor():
		return false
	if not (state in GROUNDED_STATES or state == State.BLOCKSTUN):
		return false
	var cmd: Commands = commands if controls_enabled else _idle_commands
	var holding_back := cmd.move_x * facing < -0.1  # "atrás" = alejarse del rival
	if not (cmd.block or holding_back):
		return false
	var crouching := cmd.crouch or state == State.CROUCH
	match attack.height:
		AttackData.Height.LOW:
			return crouching
		AttackData.Height.OVERHEAD:
			return not crouching
		_:
			return true


func _take_damage(amount: int) -> void:
	if amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, data.max_health)


func _knock_out(push_dir: float) -> void:
	_cancel_attack()
	velocity = Vector2(push_dir * 260.0, -420.0)
	_change_state(State.KO)
	knocked_out.emit(self)


# --- Física ------------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)


func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)


## Mira siempre hacia el rival, pero solo cuando está en el suelo y libre.
func _update_facing(force: bool = false) -> void:
	if opponent == null:
		return
	if not force and not (state in GROUNDED_STATES and is_on_floor()):
		return
	var dx := opponent.global_position.x - global_position.x
	if absf(dx) > 4.0:
		facing = 1 if dx > 0.0 else -1


# --- Visuales ----------------------------------------------------------------

## Ajusta cuerpo, hurtbox y placeholder a la estatura del personaje (pies en el origen).
func _apply_body_size() -> void:
	var k := data.body_height / BASE_BODY_HEIGHT
	for cs: CollisionShape2D in [_body_shape, _hurtbox_shape]:
		var rect := cs.shape as RectangleShape2D
		rect.size *= k
		cs.position.y = -rect.size.y / 2.0
	_placeholder.offset_top = -data.body_height


func _apply_data() -> void:
	health = data.max_health
	_placeholder.color = data.placeholder_color
	var has_sprites := data.sprite_frames != null
	_sprite.visible = has_sprites
	_placeholder.visible = not has_sprites
	if has_sprites:
		_sprite.sprite_frames = data.sprite_frames
		_sprite.scale = Vector2.ONE * data.sprite_scale
		_sprite.flip_h = data.sprite_faces_left
		_sprite.play(&"idle" if data.sprite_frames.has_animation(&"idle") else data.sprite_frames.get_animation_names()[0])
	health_changed.emit(health, data.max_health)


func _update_visuals(delta: float) -> void:
	_body.scale.x = facing
	var crouched := is_crouching() or (state == State.BLOCKSTUN and commands.crouch)
	_set_crouch_hurtbox(crouched)

	if _placeholder.visible:
		# Placeholder: aplastar para agacharse, inclinar en KO.
		_body.scale.y = CROUCH_HURTBOX_RATIO if crouched else 1.0
		_body.rotation = deg_to_rad(-80.0 * facing) if state == State.KO else 0.0
	else:
		if state != State.ATTACK:  # los ataques se inician en _play_attack_animation
			_play_animation(_animation_for_state())
		# Sin animación "ko": inclinar el sprite para que se note la derrota.
		var tilt_ko := state == State.KO and not _sprite.sprite_frames.has_animation(&"ko")
		_body.rotation = deg_to_rad(-80.0 * facing) if tilt_ko else 0.0

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_body.modulate = Color.WHITE


func _set_crouch_hurtbox(crouched: bool) -> void:
	var shape := _hurtbox_shape.shape as RectangleShape2D
	var target_h := _stand_hurt_size.y * (CROUCH_HURTBOX_RATIO if crouched else 1.0)
	if is_equal_approx(shape.size.y, target_h):
		return
	shape.size.y = target_h
	# Mantener la base de la hurtbox en los pies.
	_hurtbox_shape.position.y = _stand_hurt_pos.y + (_stand_hurt_size.y - target_h) / 2.0


func _flash(color: Color) -> void:
	_body.modulate = color
	_flash_time = 0.12


func _animation_for_state() -> StringName:
	var cmd: Commands = commands if controls_enabled else _idle_commands
	match state:
		State.WALK:
			return &"walk_back" if velocity.x * facing < 0.0 else &"walk"
		State.CROUCH:
			# Agachado manteniendo bloqueo o "atrás" = guardia baja.
			var guarding := cmd.block or cmd.move_x * facing < -0.1
			return &"crouch_block" if guarding else &"crouch"
		State.JUMP:
			return &"fall" if velocity.y >= 0.0 else &"jump"
		State.ATTACK:
			return _current_attack.animation if _current_attack else &"idle"
		State.BLOCK:
			return &"block"
		State.BLOCKSTUN:
			return &"crouch_block" if cmd.crouch else &"block"
		State.HITSTUN:
			return _hit_animation
		State.KO:
			return &"ko"
		State.VICTORY:
			return &"victory"
		_:
			return &"idle"


## Elige la reacción según cómo y dónde recibe el golpe.
func _pick_hit_animation(attack: AttackData) -> StringName:
	if not is_on_floor():
		return &"hit_air"
	if is_crouching():
		return &"crouch_hit"
	if attack.height == AttackData.Height.LOW:
		return &"hit_low"
	if attack.hitstun_frames >= HARD_HIT_STUN_FRAMES:
		return &"hit_hard"
	return &"hit"


## El origen del luchador está en los pies: se sube el sprite media altura del frame
## actual para que su borde inferior quede siempre en el suelo.
func _anchor_sprite_to_feet() -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(_sprite.animation):
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex:
		_sprite.offset = Vector2(0.0, -tex.get_height() / 2.0)


## Reproduce una animación de estado (idle, walk, hit...). `restart` la fuerza desde el frame 0.
func _play_animation(anim: StringName, restart: bool = false) -> void:
	if not _sprite.visible or _sprite.sprite_frames == null:
		return
	var frames := _sprite.sprite_frames
	if not frames.has_animation(anim):
		anim = ANIM_FALLBACKS.get(anim, &"idle")  # aún no dibujada: usar la de respaldo
		if not frames.has_animation(anim):
			anim = &"idle"
			if not frames.has_animation(anim):
				return
	# Las animaciones sin loop (crouch, block, ko...) se quedan en su último frame:
	# no reiniciarlas solo porque terminaron.
	if _sprite.animation == anim and not restart:
		return
	var previous := String(_sprite.animation)
	_sprite.speed_scale = 1.0
	_sprite.stop()
	_sprite.play(anim)
	# Volver a "crouch" desde otra animación agachada (crouch_light, crouch_block...):
	# saltar la transición de agacharse, ya estaba abajo.
	if anim == &"crouch" and previous.begins_with("crouch"):
		_sprite.frame = frames.get_frame_count(anim) - 1


## Reproduce la animación del ataque ajustando su velocidad para que dure exactamente
## lo mismo que el ataque (startup + activos + recuperación). Así el artista dibuja
## los frames que quiera y la lógica de combate (AttackData) sigue mandando.
func _play_attack_animation(attack: AttackData) -> void:
	_attack_has_animation = false
	if not _sprite.visible or _sprite.sprite_frames == null:
		return
	var frames := _sprite.sprite_frames
	var anim := attack.animation
	if not frames.has_animation(anim):
		return
	_attack_has_animation = true
	var fps := frames.get_animation_speed(anim)
	var anim_seconds := 0.0
	for i in frames.get_frame_count(anim):
		anim_seconds += frames.get_frame_duration(anim, i) / fps
	var attack_seconds := attack.total_frames() / ATTACK_FRAME_RATE
	_sprite.stop()
	_sprite.play(anim)
	_sprite.speed_scale = anim_seconds / attack_seconds if attack_seconds > 0.0 else 1.0
