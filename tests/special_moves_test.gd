## Prueba de especiales: dos luchadores reales sobre un piso, comandos tecleados frame a frame.
## Uso: godot --headless --path . -s res://tests/special_moves_test.gd
extends SceneTree

const FIGHTER_SCENE := preload("res://scenes/fighters/fighter.tscn")
const CHAVO := preload("res://resources/fighters/chavo/chavo.tres")
const QUICO := preload("res://resources/fighters/quico/quico.tres")
const DON_RAMON := preload("res://resources/fighters/don_ramon/don_ramon.tres")

var _failures := 0
var _world: Node2D
var chavo: Fighter
var rival: Fighter


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_resortera()
	await _test_escobazos()
	await _test_super()
	await _test_super_sin_poder()
	await _test_torta_aerea()
	await _test_cancel()
	await _test_animacion_faltante()
	await _test_boton_especial()
	await _test_derribo()
	await _test_golpazo()
	await _test_salto()
	await _test_supers_chapulin()
	await _test_botones_fase_b()
	await _test_azotes()
	await _test_bruja()
	await _test_cancelar_guardia()
	await _test_quico()
	print("special_moves_test: OK" if _failures == 0 else "special_moves_test: %d FALLAS" % _failures)
	quit(1 if _failures else 0)


# --- Casos -------------------------------------------------------------------

func _test_resortera() -> void:
	await _setup(260.0)
	await _qcf(false)
	_check("resortera inicia", chavo.get_current_attack() != null and chavo.get_current_attack().animation == &"slingshot")
	await _frames(20)
	_check("resortera lanza proyectil", _projectiles() == 1)
	await _frames(40)
	_check("la piedra pega (vida %d)" % rival.health, rival.health == rival.data.max_health - 7)
	_check("pegar da poder", chavo.power > 0)


func _test_escobazos() -> void:
	await _setup(90.0)
	# →↓↘ + pesado
	await _dirs([[1, false, 3], [0, true, 3], [1, true, 2]])
	chavo.commands.heavy = true
	await _frames(1)
	_check("escobazos inicia", chavo.get_current_attack() != null and chavo.get_current_attack().animation == &"broom_spin")
	await _frames(80)
	var lost := rival.data.max_health - rival.health
	_check("escobazos pega 4 veces (daño %d)" % lost, lost == 16)


func _test_super() -> void:
	await _setup(120.0)
	chavo.power = 100
	var started := [false]
	chavo.super_started.connect(func(_f): started[0] = true)
	await _double_qcf(false)
	_check("súper inicia", chavo.get_current_attack() != null and chavo.get_current_attack().animation == &"super_cheeks")
	_check("súper emite señal", started[0])
	_check("súper gasta la barra (poder %d)" % chavo.power, chavo.power == 0)
	await _frames(120)
	var lost := rival.data.max_health - rival.health
	_check("súper pega 3 trompadas (daño %d)" % lost, lost == 27)
	_check("súper no recarga barra (poder %d)" % chavo.power, chavo.power == 0)


func _test_super_sin_poder() -> void:
	await _setup(260.0)
	await _double_qcf(false)
	var attack := chavo.get_current_attack()
	_check("sin poder, ↓↘→↓↘→ hace resortera", attack != null and attack.animation == &"slingshot")


func _test_torta_aerea() -> void:
	await _setup(220.0)
	chavo.commands.jump = true
	await _frames(8)
	await _qcf(true)
	var attack := chavo.get_current_attack()
	_check("torta aérea inicia", attack != null and attack.animation == &"sandwich_air")
	await _frames(14)
	_check("torta lanza proyectil", _projectiles() == 1)


func _test_cancel() -> void:
	await _setup(70.0)
	chavo.commands.light = true
	await _frames(5)  # el golpe ligero conecta en su frame activo
	await _dirs([[0, true, 2], [1, true, 2], [1, false, 1]])
	chavo.commands.light = true
	await _frames(2)
	var attack := chavo.get_current_attack()
	_check("golpe ligero se cancela en resortera", attack != null and attack.animation == &"slingshot")


## Don Ramón no tiene animación de patada baja: debe agacharse, sin rectángulo amarillo.
func _test_animacion_faltante() -> void:
	await _setup(200.0)
	rival.data = DON_RAMON
	var sprite: AnimatedSprite2D = rival.get_node("Body/Sprite")
	sprite.sprite_frames = DON_RAMON.sprite_frames
	rival.commands.crouch = true
	rival.commands.light = true
	await _frames(6)  # ya en frames activos
	var visual: ColorRect = rival.get_node("AttackVisual")
	_check("ataque sin animación usa la de respaldo (%s)" % sprite.animation, sprite.animation == &"crouch")
	_check("sin rectángulo amarillo si hay sprites", not visual.visible)
	rival.commands.crouch = false


## Botón de especial: la dirección elige el especial, sin teclear comandos.
func _test_boton_especial() -> void:
	await _setup(260.0)
	await _button(0, false)
	_check("especial solo = resortera", _anim() == &"slingshot")

	await _setup(90.0)
	await _button(1, false)
	_check("→ + especial = escobazos", _anim() == &"broom_spin")

	await _setup(120.0)
	chavo.power = 100
	await _button(0, true)
	_check("↓ + especial = súper", _anim() == &"super_cheeks")
	_check("el súper con botón gasta la barra", chavo.power == 0)

	await _setup(260.0)
	await _button(0, true)
	_check("↓ + especial sin barra = resortera", _anim() == &"slingshot")

	await _setup(220.0)
	chavo.commands.jump = true
	await _frames(8)
	await _button(1, false)
	_check("especial en el aire = torta (con cualquier dirección)", _anim() == &"sandwich_air")

	# Don Ramón no tiene especiales: el botón no debe sacar un golpe normal.
	await _setup(260.0)
	rival.data = DON_RAMON
	rival.commands.special_button = true
	await _frames(2)
	_check("sin especiales, el botón no hace un golpe normal", rival.get_current_attack() == null)


func _button(forward: int, down: bool) -> void:
	chavo.commands.move_x = float(forward)
	chavo.commands.crouch = down
	await _step()
	chavo.commands.move_x = float(forward)
	chavo.commands.crouch = down
	chavo.commands.special_button = true
	await _step()
	chavo.commands.move_x = 0.0
	chavo.commands.crouch = false


func _anim() -> StringName:
	var attack := chavo.get_current_attack()
	return attack.animation if attack else &""


## El último golpe de los escobazos derriba: vuela, queda tirado (invulnerable) y se levanta.
func _test_derribo() -> void:
	await _setup(90.0)
	await _dirs([[1, false, 3], [0, true, 3], [1, true, 2]])
	chavo.commands.light = true
	var seen_down := false
	var seen_invulnerable := false
	for i in 220:
		await _step()
		if rival.is_knocked_down():
			seen_down = true
			seen_invulnerable = seen_invulnerable or rival.is_invulnerable()
		elif seen_down:
			break
	_check("escobazos derriba al rival", seen_down)
	_check("tirado es invulnerable", seen_invulnerable)
	_check("se levanta y vuelve a estar libre", rival.state == Fighter.State.IDLE)


## → + pesado pegado al rival = Golpazo (agarre que no se bloquea y derriba).
func _test_golpazo() -> void:
	await _setup(62.0)
	rival.commands.block = true  # aunque bloquee
	chavo.commands.move_x = 1.0
	chavo.commands.heavy = true
	await _step()
	chavo.commands.move_x = 0.0
	_check("→ + pesado cerca = golpazo", _anim() == &"golpazo")
	_check("el rival queda agarrado", rival.state == Fighter.State.THROWN)
	await _frames(50)
	_check("el golpazo pega aunque bloquee (vida %d)" % rival.health, rival.health == rival.data.max_health - 12)
	_check("el golpazo derriba", rival.is_knocked_down())

	await _setup(160.0)
	chavo.commands.move_x = 1.0
	chavo.commands.heavy = true
	await _step()
	chavo.commands.move_x = 0.0
	_check("→ + pesado lejos = golpe pesado normal", _anim() == &"heavy_punch")


## ↓↙← + golpe: salta hacia adelante, pega y cae.
func _test_salto() -> void:
	await _setup(130.0)
	await _dirs([[0, true, 2], [-1, true, 2], [-1, false, 1]])
	chavo.commands.light = true
	await _step()
	_check("↓↙← + golpe = salto de lucha libre", _anim() == &"wrestling_jump")
	await _frames(12)
	_check("el salto despega del piso", not chavo.is_on_floor())
	await _frames(90)
	var lost := rival.data.max_health - rival.health
	_check("el salto pega (daño %d)" % lost, lost >= 6)
	_check("Chavo vuelve al piso", chavo.is_on_floor())


## ↓↘→↓↘→ + pesado con 2 barras = Super Chipote; con ligero, las trompadas.
## ↓↙←↓↙← + golpe = Combo del Chapulín.
func _test_supers_chapulin() -> void:
	await _setup(150.0)
	chavo.power = 200
	await _double_qcf(true)
	_check("↓↘→↓↘→ + pesado con 2 barras = super chipote", _anim() == &"super_chipote")
	_check("el chipote gasta 2 barras (poder %d)" % chavo.power, chavo.power == 0)
	await _frames(110)
	var lost := rival.data.max_health - rival.health
	_check("el chipote pega 30 (daño %d)" % lost, lost == 30)

	await _setup(150.0)
	chavo.power = 200
	await _double_qcf(false)
	_check("↓↘→↓↘→ + ligero = trompadas aunque haya 2 barras", _anim() == &"super_cheeks")

	await _setup(100.0)
	chavo.power = 100
	await _dirs([[0, true, 2], [-1, true, 2], [-1, false, 2], [0, true, 2], [-1, true, 2], [-1, false, 1]])
	chavo.commands.light = true
	await _step()
	_check("↓↙←↓↙← + golpe = combo del chapulín", _anim() == &"chapulin_combo")
	await _frames(130)
	lost = rival.data.max_health - rival.health
	_check("el combo del chapulín pega 5 veces (daño %d)" % lost, lost == 25)
	_check("el combo termina derribando", rival.is_knocked_down() or rival.state == Fighter.State.IDLE)


func _test_botones_fase_b() -> void:
	await _setup(130.0)
	await _button(-1, false)
	_check("← + especial = salto", _anim() == &"wrestling_jump")

	await _setup(150.0)
	chavo.power = 200
	await _button(1, true)
	_check("↘ + especial con 2 barras = chipote", _anim() == &"super_chipote")

	await _setup(150.0)
	chavo.power = 100
	await _button(1, true)
	_check("↘ + especial con 1 barra = trompadas", _anim() == &"super_cheeks")

	await _setup(150.0)
	chavo.power = 100
	await _button(-1, true)
	_check("↙ + especial = combo del chapulín", _anim() == &"chapulin_combo")


## →↘↓↙← + golpe pegado al rival = Azotes (agarre de comando: 4 golpes, derriba).
## Lejos, el agarre falla. Atrás + pesado pegado también hace los azotes.
func _test_azotes() -> void:
	await _setup(62.0)
	rival.commands.block = true
	await _dirs([[1, false, 2], [1, true, 2], [0, true, 2], [-1, true, 2], [-1, false, 1]])
	chavo.commands.light = true
	await _step()
	_check("→↘↓↙← + golpe cerca = azotes", _anim() == &"azotes")
	_check("los azotes agarran", rival.state == Fighter.State.THROWN)
	await _frames(90)
	var lost := rival.data.max_health - rival.health
	_check("los azotes pegan 4 veces aunque bloquee (daño %d)" % lost, lost == 20)
	_check("los azotes derriban", rival.is_knocked_down())

	await _setup(170.0)
	await _dirs([[1, false, 2], [1, true, 2], [0, true, 2], [-1, true, 2], [-1, false, 1]])
	chavo.commands.light = true
	await _step()
	_check("lejos, los azotes fallan", _anim() == &"azotes_whiff")
	await _frames(40)
	_check("el fallo no hace daño", rival.health == rival.data.max_health)

	await _setup(62.0)
	chavo.commands.move_x = -1.0
	chavo.commands.heavy = true
	await _step()
	await _step()
	chavo.commands.move_x = 0.0
	_check("atrás + pesado cerca = azotes", _anim() == &"azotes")


## ↓↙←↓↙← + pesado con 2 barras = Bruja del 71: rayos, transformación y explosión.
func _test_bruja() -> void:
	await _setup(260.0)
	chavo.power = 200
	await _double_qcb(true)
	_check("↓↙←↓↙← + pesado con 2 barras = bruja", _anim() == &"garrotera")
	var seen_disguise := false
	for i in 230:
		await _step()
		seen_disguise = seen_disguise or rival._disguise != null
	var lost := rival.data.max_health - rival.health
	_check("la bruja transforma al rival", seen_disguise)
	_check("rayos + explosión hacen 30 (daño %d)" % lost, lost == 30)
	_check("el rival vuelve a la normalidad", rival._disguise == null)

	await _setup(260.0)
	chavo.power = 200
	rival.commands.block = true
	await _double_qcb(true)
	await _frames(90)
	lost = rival.data.max_health - rival.health
	_check("si bloquea el primer rayo, solo recibe chip (daño %d)" % lost, lost == 2)
	_check("si lo bloquean, Chavo sale de la garrotera", chavo.state != Fighter.State.ATTACK)

	await _setup(150.0)
	chavo.power = 200
	await _double_qcb(false)
	_check("↓↙←↓↙← + ligero = combo del chapulín", _anim() == &"chapulin_combo")

	await _setup(260.0)
	chavo.power = 200
	await _button(-1, true)
	_check("↙ + especial con 2 barras = bruja", _anim() == &"garrotera")


## Especial mientras bloquea un golpe = rodada hacia atrás (1 barra, invulnerable).
func _test_cancelar_guardia() -> void:
	await _setup(75.0)
	chavo.power = 100
	chavo.commands.block = true
	rival.commands.heavy = true
	var x_before := chavo.global_position.x
	for i in 30:
		chavo.commands.block = true
		await _step()
		if chavo.state == Fighter.State.BLOCKSTUN:
			break
	_check("Chavo bloquea el golpe", chavo.state == Fighter.State.BLOCKSTUN)
	chavo.commands.special_button = true
	await _step()
	chavo.commands.block = false
	_check("especial en guardia = rodada", _anim() == &"guard_roll")
	_check("la rodada gasta 1 barra (poder %d)" % chavo.power, chavo.power < 100)
	_check("la rodada es invulnerable", chavo.is_invulnerable())
	await _frames(20)
	_check("la rodada va hacia atrás", chavo.global_position.x < x_before - 40.0)

	await _setup(75.0)
	chavo.commands.block = true
	rival.commands.heavy = true
	for i in 30:
		chavo.commands.block = true
		await _step()
		if chavo.state == Fighter.State.BLOCKSTUN:
			break
	chavo.commands.special_button = true
	await _step()
	_check("sin barra no hay rodada", _anim() != &"guard_roll")
	chavo.commands.block = false


func _double_qcb(heavy: bool) -> void:
	await _dirs([[0, true, 2], [-1, true, 2], [-1, false, 2], [0, true, 2], [-1, true, 2], [-1, false, 1]])
	if heavy:
		chavo.commands.heavy = true
	else:
		chavo.commands.light = true
	await _step()


## Especiales de Quico (los usa la IA con commands.special).
## Índices en quico.tres: 0 pelotota, 1 yo-yo, 2 yo-yo aéreo, 3 pelota, 4 pelota aérea.
func _test_quico() -> void:
	await _setup(480.0)
	rival.commands.special = 3
	await _step()
	_check("quico: pelota", _rival_anim() == &"ball_1")
	var bounced := false
	var last_vy := 0.0
	for i in 200:
		await _step()
		for n in _world.get_children():
			if n is Projectile:
				if last_vy > 0.0 and n.velocity.y < 0.0:
					bounced = true
				last_vy = n.velocity.y
	_check("la pelota rebota", bounced)
	_check("la pelota pega a Chavo (vida %d)" % chavo.health, chavo.health == chavo.data.max_health - _q(6))

	await _setup(100.0)
	rival.commands.special = 1
	await _step()
	_check("quico: yo-yo", _rival_anim() == &"yoyo")
	await _frames(90)
	var lost := chavo.data.max_health - chavo.health
	_check("el yo-yo pega 5 veces (daño %d)" % lost, lost == 5 * _q(3))

	await _setup(260.0)
	rival.power = 100
	rival.commands.special = 0
	await _step()
	_check("quico: pelotota (súper)", _rival_anim() == &"ball_3")
	_check("la pelotota gasta 1 barra", rival.power == 0)
	var seen_down := false
	for i in 160:
		await _step()
		seen_down = seen_down or chavo.is_knocked_down()
	lost = chavo.data.max_health - chavo.health
	_check("la pelotota pega 22 y derriba (daño %d)" % lost, lost == _q(22) and seen_down)

	# Quico derribado usa su propia animación de levantarse.
	await _setup(90.0)
	await _dirs([[1, false, 3], [0, true, 3], [1, true, 2]])
	chavo.commands.light = true
	var seen_getup := false
	var sprite: AnimatedSprite2D = rival.get_node("Body/Sprite")
	for i in 220:
		await _step()
		seen_getup = seen_getup or sprite.animation == &"get_up"
	_check("quico se levanta con su animación get_up", seen_getup)


## Daño de Quico con su multiplicador.
func _q(damage: int) -> int:
	return roundi(damage * QUICO.damage_multiplier)


func _rival_anim() -> StringName:
	var attack := rival.get_current_attack()
	return attack.animation if attack else &""


# --- Utilidades --------------------------------------------------------------

func _setup(distance: float) -> void:
	if _world:
		_world.queue_free()
		await process_frame
	_world = Node2D.new()
	root.add_child(_world)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 100)
	shape.shape = rect
	shape.position = Vector2(0, 50)
	floor_body.add_child(shape)
	_world.add_child(floor_body)

	chavo = FIGHTER_SCENE.instantiate()
	chavo.data = CHAVO
	rival = FIGHTER_SCENE.instantiate()
	rival.data = QUICO
	for f: Fighter in [chavo, rival]:
		f.is_player = false
		_world.add_child(f)
	chavo.opponent = rival
	rival.opponent = chavo
	chavo.reset_for_round(Vector2(0, -1))
	rival.reset_for_round(Vector2(distance, -1))
	chavo.controls_enabled = true
	rival.controls_enabled = true
	await _frames(10)  # que caigan al piso


func _frames(n: int) -> void:
	for i in n:
		await _step()


## Un frame de física + la separación entre luchadores que hace FightArena.
func _step() -> void:
	await physics_frame
	if chavo == null or rival == null:
		return
	var dx := rival.global_position.x - chavo.global_position.x
	if absf(dx) < 60.0:
		var dir := signf(dx) if dx != 0.0 else 1.0
		var push := (60.0 - absf(dx)) * 0.5
		chavo.global_position.x -= dir * push
		rival.global_position.x += dir * push


## steps: [[adelante, abajo, frames], ...] (relativo a Chavo, que mira a la derecha)
func _dirs(steps: Array) -> void:
	for s in steps:
		for i in s[2]:
			chavo.commands.move_x = float(s[0])
			chavo.commands.crouch = s[1]
			await _step()
	chavo.commands.move_x = 0.0
	chavo.commands.crouch = false


func _qcf(heavy: bool) -> void:
	await _dirs([[0, true, 2], [1, true, 2], [1, false, 1]])
	chavo.commands.move_x = 1.0
	if heavy:
		chavo.commands.heavy = true
	else:
		chavo.commands.light = true
	await _frames(1)
	chavo.commands.move_x = 0.0


func _double_qcf(heavy: bool) -> void:
	await _dirs([[0, true, 2], [1, true, 2], [1, false, 2]])
	await _qcf(heavy)


func _projectiles() -> int:
	return _world.get_children().filter(func(n): return n is Projectile).size()


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		print("FALLA: ", label)
	else:
		print("ok: ", label)
