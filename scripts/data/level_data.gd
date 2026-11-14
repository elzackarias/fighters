## Configuración de un nivel: escenario, rival, reglas y dificultad de la IA.
## Un .tres por nivel en res://resources/levels/. El GameManager los recorre en orden.
class_name LevelData
extends Resource

@export var level_name: String = "Nivel 1"
@export var stage_name: String = "El Patio"
@export var opponent: FighterData

@export_group("Escenario")
## Fondo final. Mientras sea null se usan los colores provisionales.
@export var background_texture: Texture2D
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
