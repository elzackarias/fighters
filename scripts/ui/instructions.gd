## Pantalla de instrucciones: controles y objetivo.
extends Control

@onready var _play_button: Button = $Margin/VBox/Buttons/PlayButton
@onready var _back_button: Button = $Margin/VBox/Buttons/BackButton


func _ready() -> void:
	_play_button.pressed.connect(GameManager.start_new_game)
	_back_button.pressed.connect(GameManager.go_to_main_menu)
	_play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_main_menu()
