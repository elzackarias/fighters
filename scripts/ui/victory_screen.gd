## Pantalla de cierre: resumen de la partida + mensaje educativo.
extends Control

const EDUCATIONAL_MESSAGE := """Ganaste los tres combates... pero en la vecindad la verdadera victoria nunca fue a golpes.

Quico aprendió que compartir sus juguetes lo hace más feliz que presumirlos.
Don Ramón recordó que el respeto se gana con el ejemplo, no con gritos.
Ñoño descubrió que un buen amigo vale más que cualquier vacación.

Los problemas se resuelven hablando, pidiendo perdón y dando segundas oportunidades.
¡Eso sí es ser un campeón!"""

@onready var _stats_label: Label = $Margin/VBox/Stats
@onready var _message_label: Label = $Margin/VBox/Message
@onready var _menu_button: Button = $Margin/VBox/MenuButton


func _ready() -> void:
	_message_label.text = EDUCATIONAL_MESSAGE
	_stats_label.text = "Puntaje final: %d   ·   Rounds ganados: %d   ·   Rounds perdidos: %d" % [
		GameManager.score, GameManager.total_rounds_won, GameManager.total_rounds_lost
	]
	_menu_button.pressed.connect(GameManager.go_to_main_menu)
	_menu_button.grab_focus()
