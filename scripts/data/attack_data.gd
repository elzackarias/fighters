## Datos de un ataque (golpe ligero, pesado, barrida...).
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

@export_group("Física")
## x = empuje horizontal, y = impulso vertical (negativo = lanza hacia arriba).
@export var knockback: Vector2 = Vector2(150, 0)

@export_group("Hitbox")
## Posición del centro de la hitbox relativa a los pies, mirando a la DERECHA.
@export var hitbox_offset: Vector2 = Vector2(55, -100)
@export var hitbox_size: Vector2 = Vector2(60, 22)


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames
