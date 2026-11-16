## Datos de un ataque (golpe ligero, pesado, barrida, especial...).
## Se guarda como .tres en res://resources/attacks/ para ajustar balance sin tocar código.
## Los tiempos están en FRAMES de física (60 por segundo).
class_name AttackData
extends Resource

## Cómo debe bloquearse el ataque.
## MID: se bloquea de pie o agachado. LOW: solo agachado. OVERHEAD: solo de pie.
enum Height { MID, LOW, OVERHEAD }

@export var attack_name: String = "Golpe"
## Nombre de la animación en SpriteFrames (si el luchador tiene sprites).
@export var animation: StringName = &"light_punch"

@export_group("Daño")
## Daño de CADA golpe (un ataque de varios golpes hace damage × max_hits).
@export var damage: int = 5
## Daño que entra aunque el rival bloquee.
@export var chip_damage: int = 0
@export var height: Height = Height.MID

@export_group("Frames")
@export var startup_frames: int = 4
@export var active_frames: int = 3
@export var recovery_frames: int = 8
@export var hitstun_frames: int = 14
@export var blockstun_frames: int = 8

@export_group("Derribo y agarre")
## El golpe final derriba: el rival sale volando, cae, queda tirado y se levanta
## (invulnerable mientras tanto).
@export var knockdown: bool = false
## Agarre: no usa hitbox. Se intenta solo si el rival está a su alcance
## (hitbox_offset.x + hitbox_size.x / 2), lo sujeta durante el startup y en el
## primer frame activo le hace el daño. No se puede bloquear.
@export var is_throw: bool = false

@export_group("Varios golpes")
## Cuántas veces puede golpear durante sus frames activos.
@export var max_hits: int = 1
## Frames entre un golpe y el siguiente (si max_hits > 1).
@export var rehit_frames: int = 6

@export_group("Física")
## x = empuje horizontal, y = impulso vertical (negativo = lanza hacia arriba).
## En ataques de varios golpes se aplica solo en el ÚLTIMO; los demás empujan poco.
@export var knockback: Vector2 = Vector2(150, 0)
## Velocidad propia al iniciar el ataque (x hacia adelante, y negativo = sube).
## Sirve para deslices y saltos de los especiales.
@export var self_velocity: Vector2 = Vector2.ZERO
## Frames desde el inicio en los que el atacante no recibe daño (súpers, "shoryukens").
@export var invulnerable_frames: int = 0

@export_group("Hitbox")
## Posición del centro de la hitbox relativa a los pies, mirando a la DERECHA.
@export var hitbox_offset: Vector2 = Vector2(55, -100)
@export var hitbox_size: Vector2 = Vector2(60, 22)

@export_group("Proyectil")
## Si tiene textura, al terminar el startup se lanza un proyectil (en hitbox_offset)
## en lugar de activar la hitbox del cuerpo.
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 420.0
## Gravedad del proyectil (0 = recto). Útil para cosas que se lanzan en arco.
@export var projectile_gravity: float = 0.0
## Velocidad vertical inicial del proyectil (negativo = hacia arriba, positivo = abajo).
@export var projectile_rise: float = 0.0
@export var projectile_scale: float = 1.0
## Grados por segundo que gira (una torta que da vueltas).
@export var projectile_spin: float = 0.0
## Segundos antes de desaparecer si no golpea nada.
@export var projectile_lifetime: float = 2.0


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


func is_projectile() -> bool:
	return projectile_texture != null
