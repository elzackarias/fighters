## Prueba de humo: la CPU controla también al jugador y se registran los eventos.
## Uso: godot --headless --path . res://tests/smoke_test.tscn
extends Node

var hits := 0
var blocks := 0

func _ready() -> void:
	# Sobrevivir a los cambios de escena: colgarse de la raíz con una escena "dummy".
	await get_tree().process_frame
	var tree := get_tree()
	var dummy := Node.new()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.root.add_child(dummy)
	tree.current_scene = dummy
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240  # mantiene 60 pasos por segundo de juego
	Engine.max_physics_steps_per_frame = 32
	GameManager.round_result_registered.connect(func(r): print("ROUND result=", r, " P=", GameManager.player_round_wins, " E=", GameManager.enemy_round_wins, " score=", GameManager.score))
	GameManager.level_started.connect(func(i, l): print("LEVEL STARTED ", i, " ", l.stage_name))
	get_tree().node_added.connect(_on_node_added)
	GameManager.start_new_game()
	await get_tree().create_timer(480.0).timeout
	print("anim_changes=", anim_changes, " hits=", hits, " blocks=", blocks, " levels_cleared=", GameManager.levels_cleared, " scene=", get_tree().current_scene.name if get_tree().current_scene else "null")
	for who in real_sprites:
		var prefix := who + ":"
		var keys := anims_seen.keys().filter(func(k): return k.begins_with(prefix))
		keys.sort()
		print("ANIMS[%s] " % who, ", ".join(keys.map(func(k): return "%s=%d" % [k.trim_prefix(prefix), anims_seen[k]])))
	get_tree().quit()

const ANIMS := [&"idle", &"walk", &"walk_back", &"crouch", &"jump", &"fall", &"block", &"crouch_block", &"hit", &"hit_hard", &"crouch_hit", &"ko", &"victory",
	&"light_punch", &"heavy_punch", &"crouch_light", &"crouch_heavy", &"air_kick"]
var anim_changes := 0
var anims_seen := {}
var real_sprites: Array[String] = []  # luchadores con sprites propios

## SpriteFrames falso (ícono de Godot) para ejercitar el camino de animaciones.
func _fake_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var tex: Texture2D = load("res://icon.svg")
	for a in ANIMS:
		sf.add_animation(a)
		sf.set_animation_speed(a, 12.0)
		sf.set_animation_loop(a, a in [&"idle", &"walk", &"crouch", &"block"])
		for i in 4:
			sf.add_frame(a, tex)
	return sf

func _on_node_added(n: Node) -> void:
	if n is Fighter:
		# Solo los personajes sin sprites propios reciben los falsos.
		var who: String = n.data.display_name
		if n.data.sprite_frames == null:
			var d: FighterData = n.data.duplicate()
			d.sprite_frames = _fake_frames()
			n.data = d
		elif not who in real_sprites:
			real_sprites.append(who)
		n.ready.connect(func():
			var spr: AnimatedSprite2D = n.get_node("Body/Sprite")
			spr.animation_changed.connect(func():
				anim_changes += 1
				var key := "%s:%s" % [who, spr.animation]
				anims_seen[key] = anims_seen.get(key, 0) + 1)
		, CONNECT_ONE_SHOT)
	if n is Fighter and n.name == "Player":
		n.ready.connect(func():
			var ai := AIController.new()
			ai.aggression = 0.95; ai.reaction_time = 0.15; ai.block_chance = 0.4
			n.add_child(ai)
			n.hit_landed.connect(func(t, b, d): if b: blocks += 1 else: hits += 1)
		, CONNECT_ONE_SHOT)
	elif n.name == "Message" and n is Label:
		pass
