## Configuración de un nivel: escenario, rival, reglas y dificultad de la IA.
## Un .tres por nivel en res://resources/levels/. El GameManager los recorre en orden.
class_name LevelData
extends Resource

@export var level_name: String = "Nivel 1"
@export var stage_name: String = "El Patio"
@export var opponent: FighterData

@export_group("Escenario")
## Fondo lejano (cielo). Fijo en pantalla, se escala para cubrir la ventana.
## Mientras sea null se usa background_color.
@export var background_texture: Texture2D
## Escenario con su propio piso. Vive en el mundo (se desplaza con la cámara)
## y se escala para cubrir todo el ancho del arena. Si es null se usa floor_color.
@export var stage_texture: Texture2D
## Fila (en píxeles de stage_texture) donde apoyan los pies los luchadores.
@export var stage_floor_y: float = 0.0
## Escala del escenario en el mundo. 0 = automático (cubre el ancho del arena).
## Si el escenario escalado queda más angosto que el arena, el arena (paredes y
## límites de la cámara) se encoge a su ancho, centrado.
@export var stage_scale: float = 0.0
@export var background_color: Color = Color(0.45, 0.65, 0.9)
@export var floor_color: Color = Color(0.55, 0.45, 0.35)
@export var music: AudioStream

@export_group("Reglas")
@export var rounds_to_win: int = 2
@export var round_time: int = 60

@export_group("IA")
## Segundos entre decisiones (menos = más difícil).
@export_range(0.05, 1.5) var ai_reaction_time: float = 0.4
## Probabilidad de elegir atacar/perseguir en vez de esperar.
@export_range(0.0, 1.0) var ai_aggression: float = 0.5
## Probabilidad de bloquear cuando el jugador ataca de cerca.
@export_range(0.0, 1.0) var ai_block_chance: float = 0.3
