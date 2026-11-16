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
