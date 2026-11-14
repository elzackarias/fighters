## Captura la arena de un nivel para revisar visualmente.
## Uso: godot --path . res://tests/screenshot.tscn -- <nivel 0..2> <ruta_png>
extends Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level := int(args[0]) if args.size() > 0 else 0
	var out := args[1] if args.size() > 1 else "user://arena.png"
	await get_tree().process_frame
	# Sobrevivir al cambio de escena colgándose de la raíz.
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	GameManager.current_level_index = level
	get_tree().change_scene_to_file("res://scenes/levels/fight_arena.tscn")
	await get_tree().create_timer(2.6).timeout  # pasar "Round 1" / "¡A pelear!"
	var arena := get_tree().current_scene
	var p: Fighter = arena.player
	p.is_player = false
	# Golpe del jugador hacia el rival para ver también una animación de ataque.
	pass  # sin golpe: postura neutral para comparar estaturas
	await get_tree().create_timer(0.12).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("SAVED ", out)
	get_tree().quit()
