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

	# índices en chavo.tres: 0 súper, 1 escobazos, 2 resortera, 3 torta
	await _place(p, e, 300.0)
	await _special(p, 2, false, [0.2, 0.35, 0.55])
	await _place(p, e, 100.0)
	await _special(p, 1, true, [0.15, 0.35, 0.55, 0.8])
	await _place(p, e, 140.0)
	p.power = 300
	await _special(p, 0, false, [0.05, 0.6, 0.8, 1.0])
	await _place(p, e, 260.0)
	p.commands.jump = true
	await tree.create_timer(0.15).timeout
	await _special(p, 3, false, [0.1, 0.3, 0.45])
	print("SAVED ", _shot, " capturas en ", _out)
	tree.quit()


func _place(p: Fighter, e: Fighter, distance: float) -> void:
	await get_tree().create_timer(0.8).timeout  # que termine lo anterior
	var y := p.global_position.y
	p.global_position = Vector2(e.global_position.x - distance, y)
	e.health = e.data.max_health
	await get_tree().create_timer(0.1).timeout


func _special(p: Fighter, index: int, heavy: bool, times: Array) -> void:
	p.commands.special = index
	p.commands.special_heavy = heavy
	var elapsed := 0.0
	for t: float in times:
		await get_tree().create_timer(t - elapsed).timeout
		elapsed = t
		_shot += 1
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [_out, _shot])
