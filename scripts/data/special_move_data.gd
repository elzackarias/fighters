## Un movimiento especial o súper: qué comando lo activa y qué ataque ejecuta.
## Se guarda como .tres en res://resources/specials/ y se lista en FighterData.specials
## (el orden de la lista es la prioridad: poner primero los comandos más largos).
class_name SpecialMoveData
extends Resource

enum Context { GROUND, AIR, ANY }
## Atajo con el botón de especial: qué dirección se mantiene al presionarlo.
## NONE = solo con el comando. NEUTRAL también es el respaldo si ninguna otra coincide.
## Las diagonales usan DOWN como respaldo; todas usan NEUTRAL al final.
enum ButtonInput { NONE, NEUTRAL, FORWARD, DOWN, BACK, DOWN_FORWARD, DOWN_BACK }

@export var move_name: String = "Especial"
@export var motion: MotionInput.Motion = MotionInput.Motion.QCF
@export var context: Context = Context.GROUND
## Atajo con el botón de especial (además del comando). Usa siempre la variante ligera.
@export var button_input: ButtonInput = ButtonInput.NONE
## Con el comando, solo sale con golpe pesado (distingue dos súpers del mismo comando).
@export var require_heavy: bool = false
## Poder que consume (1 barra = Fighter.POWER_PER_BAR). 0 = especial normal.
@export var power_cost: int = 0
## Ataque con golpe ligero y con golpe pesado. Si falta uno, se usa el otro.
@export var light_attack: AttackData
@export var heavy_attack: AttackData


func attack_for(heavy: bool) -> AttackData:
	if heavy:
		return heavy_attack if heavy_attack else light_attack
	return light_attack if light_attack else heavy_attack


func is_super() -> bool:
	return power_cost > 0


func fits_context(in_air: bool) -> bool:
	match context:
		Context.GROUND:
			return not in_air
		Context.AIR:
			return in_air
		_:
			return true
