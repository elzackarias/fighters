## Proyectil (piedra de la resortera, torta de jamón...).
## Lo crea Fighter con un AttackData que tenga projectile_texture. Usa las mismas
## capas que la hitbox de un luchador: capa 3 (hitbox), detecta la capa 4 (hurtbox).
class_name Projectile
extends Area2D

var attack: AttackData
var owner_fighter: Fighter
var velocity: Vector2 = Vector2.ZERO

var _life: float = 0.0
var _sprite: Sprite2D
var _done: bool = false


## Prepara el proyectil antes de agregarlo al árbol.
func setup(p_attack: AttackData, p_owner: Fighter, dir: int) -> void:
	attack = p_attack
	owner_fighter = p_owner
	velocity = Vector2(attack.projectile_speed * dir, attack.projectile_rise)
	_life = attack.projectile_lifetime

	collision_layer = 1 << 2  # capa 3: hitbox
	collision_mask = 1 << 3  # capa 4: hurtbox
	monitorable = false

	var shape := RectangleShape2D.new()
	shape.size = attack.hitbox_size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	_sprite = Sprite2D.new()
	_sprite.texture = attack.projectile_texture
	_sprite.scale = Vector2(attack.projectile_scale * dir, attack.projectile_scale)
	add_child(_sprite)

	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _done:
		return
	velocity.y += attack.projectile_gravity * delta
	position += velocity * delta
	_sprite.rotation += deg_to_rad(attack.projectile_spin) * delta * signf(velocity.x)
	_life -= delta
	# Desaparece al acabarse el tiempo o al tocar el suelo (si cae en arco).
	if _life <= 0.0 or (attack.projectile_gravity > 0.0 and global_position.y >= _floor_y()):
		_vanish()


func _on_area_entered(area: Area2D) -> void:
	if _done:
		return
	var target := area.get_parent() as Fighter
	if target == null or target == owner_fighter or not is_instance_valid(owner_fighter):
		return
	if target.is_invulnerable():
		return  # lo atraviesa
	_done = true
	var damage := roundi(attack.damage * owner_fighter.data.damage_multiplier)
	var blocked := target.receive_hit(attack, owner_fighter, damage, global_position.x)
	owner_fighter.notify_hit(target, blocked, damage)
	_vanish()


func _vanish() -> void:
	_done = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)


func _floor_y() -> float:
	# Los luchadores tienen el origen en los pies: el piso está a su altura cuando pisan.
	return owner_fighter.ground_y if is_instance_valid(owner_fighter) else INF
