## Menú principal.
extends Control

@onready var _play_button: Button = $Center/VBox/PlayButton
@onready var _instructions_button: Button = $Center/VBox/InstructionsButton
@onready var _quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	_play_button.pressed.connect(GameManager.start_new_game)
	_instructions_button.pressed.connect(GameManager.go_to_instructions)
	_quit_button.pressed.connect(get_tree().quit)
	if OS.has_feature("web"):
		_quit_button.hide()  # en navegador no se puede cerrar la app
	_play_button.grab_focus()  # navegable con teclado / mando
