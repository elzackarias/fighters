## Ficha de un personaje: stats, apariencia y lista de ataques.
## Cada personaje vive en su carpeta: res://resources/fighters/<id>/
##   <id>.tres         -> este FighterData
##   <id>_frames.tres  -> SpriteFrames con TODAS sus animaciones
class_name FighterData
extends Resource

@export var display_name: String = "Luchador"
@export_multiline var intro_quote: String = ""

@export_group("Stats")
@export var max_health: int = 100
@export var walk_speed: float = 220.0
## Negativo = hacia arriba (eje Y de Godot apunta hacia abajo).
@export var jump_velocity: float = -640.0
@export var damage_multiplier: float = 1.0
## Estatura de pie en píxeles de mundo. Escala el cuerpo y la hurtbox
## (los niños ~125, un adulto ~165). Ajustar sprite_scale para que el dibujo coincida.
@export var body_height: float = 140.0

@export_group("Apariencia")
## Color del rectángulo provisional mientras no haya sprites.
@export var placeholder_color: Color = Color.WHITE
## Si se asigna, se usa en lugar del placeholder. Animaciones esperadas:
## idle, walk, crouch, jump, block, hit, ko, victory + las de cada AttackData.
## Opcionales (si faltan usan la indicada): walk_back→walk, fall→jump, crouch_block→block,
## hit_hard / hit_low / hit_air / crouch_hit→hit. Las que falten del todo usan "idle";
## un ataque sin animación muestra el rectángulo provisional.
@export var sprite_frames: SpriteFrames
## Escala del sprite. Las hitboxes asumen un luchador de ~140 px de alto.
@export var sprite_scale: float = 1.0
## Marcar si los dibujos de la hoja miran a la IZQUIERDA (el juego asume derecha).
@export var sprite_faces_left: bool = false

@export_group("Ataques")
@export var light_attack: AttackData
@export var heavy_attack: AttackData
@export var crouch_light_attack: AttackData
@export var crouch_heavy_attack: AttackData
@export var air_attack: AttackData

@export_group("Especiales")
## Especiales y súpers. El ORDEN es la prioridad cuando varios comandos coinciden:
## los más largos primero (↓↘→↓↘→ antes que ↓↘→; →↓↘ antes que ↓↘→).
@export var specials: Array[SpecialMoveData] = []
