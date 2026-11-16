## Captura fotogramas de cada especial de Chavo en la arena real (revisión visual).
## Uso: godot --path . res://tests/special_capture.tscn -- <carpeta_salida>
extends Node

var _out := "user://"
var _shot := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	await get_tree().process_frame
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	GameManager.current_level_index = 0
	tree.change_scene_to_file("res://scenes/levels/fight_arena.tscn")
	await tree.create_timer(2.6).timeout
	var arena := tree.current_scene
	var p: Fighter = arena.player
	var e: Fighter = arena.enemy
	p.is_player = false
	e.controls_enabled = false  # rival quieto

	# índices en chavo.tres: 0 chipote, 1 cachetes, 2 bruja, 3 chapulín, 4 escobazos,
	# 5 azotes, 6 salto, 7 resortera, 8 torta
	await _place(p, e, 300.0)
	await _special(p, 7, false, [0.2, 0.35, 0.55])
	await _place(p, e, 100.0)
	await _special(p, 4, true, [0.15, 0.35, 0.55, 0.8])
	await _place(p, e, 140.0)
	p.power = 300
	await _special(p, 1, false, [0.05, 0.6, 0.8, 1.0])
	await _place(p, e, 260.0)
	p.commands.jump = true
	await tree.create_timer(0.15).timeout
	await _special(p, 8, false, [0.1, 0.3, 0.45])
	await _place(p, e, 130.0)
	await _special(p, 6, false, [0.2, 0.45, 0.75, 1.1])
	await _place(p, e, 62.0)
	await _throw(p, [0.3, 0.75, 1.0, 1.6])
	await _place(p, e, 150.0)
	p.power = 300
	await _special(p, 0, false, [0.6, 1.3, 1.45, 1.75])
	await _place(p, e, 100.0)
	p.power = 300
	await _special(p, 3, false, [0.5, 0.9, 1.3, 1.8])
	await _place(p, e, 200.0)
	p.power = 300
	await _special(p, 2, false, [0.3, 0.9, 1.2, 1.6, 2.2, 2.9])
	await _place(p, e, 62.0)
	await _special(p, 5, false, [0.3, 0.6, 1.0, 1.4])
	print("SAVED ", _shot, " capturas en ", _out)
	tree.quit()


func _place(p: Fighter, e: Fighter, distance: float) -> void:
	await get_tree().create_timer(2.4).timeout  # que termine lo anterior (y se levante)
	var y := p.global_position.y
	p.global_position = Vector2(e.global_position.x - distance, y)
	e.health = e.data.max_health
	await get_tree().create_timer(0.1).timeout


func _throw(p: Fighter, times: Array) -> void:
	# Mantener → unos frames: physics_frame se emite ANTES de que el luchador procese el
	# frame, así que soltarlo enseguida haría que lea el pesado sin la dirección.
	p.commands.move_x = 1.0
	p.commands.heavy = true
	for i in 3:
		await get_tree().physics_frame
	p.commands.move_x = 0.0
	await _shots(times)


func _shots(times: Array) -> void:
	var elapsed := 0.0
	for t: float in times:
		await get_tree().create_timer(t - elapsed).timeout
		elapsed = t
		_shot += 1
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [_out, _shot])


func _special(p: Fighter, index: int, heavy: bool, times: Array) -> void:
	p.commands.special = index
	p.commands.special_heavy = heavy
	var elapsed := 0.0
	for t: float in times:
		await get_tree().create_timer(t - elapsed).timeout
		elapsed = t
		_shot += 1
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [_out, _shot])
