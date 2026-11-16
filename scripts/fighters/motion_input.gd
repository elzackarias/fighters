## Historial de direcciones para detectar comandos de especiales (↓↘→, →↓↘...).
##
## Las direcciones se guardan en notación numérica de teclado, RELATIVAS a hacia dónde
## mira el luchador (6 = adelante, 4 = atrás, 2 = abajo, 3 = abajo-adelante...):
##
##     7 8 9
##     4 5 6
##     1 2 3
##
## Un comando se cumple si sus direcciones aparecen EN ORDEN dentro de la ventana de
## frames (pueden colarse otras direcciones entre medio). Así es tolerante con teclado.
class_name MotionInput
extends RefCounted

enum Motion {
	NONE,
	QCF,          ## ↓↘→  (cuarto de círculo adelante)
	QCB,          ## ↓↙←  (cuarto de círculo atrás)
	DP,           ## →↓↘  ("shoryuken")
	HCB,          ## →↘↓↙← (medio círculo atrás)
	DOUBLE_QCF,   ## ↓↘→↓↘→
	DOUBLE_QCB,   ## ↓↙←↓↙←
}

const SEQUENCES := {
	Motion.QCF: [2, 3, 6],
	Motion.QCB: [2, 1, 4],
	Motion.DP: [6, 2, 3],
	Motion.HCB: [6, 3, 2, 1, 4],
	Motion.DOUBLE_QCF: [2, 3, 6, 2, 3, 6],
	Motion.DOUBLE_QCB: [2, 1, 4, 2, 1, 4],
}
## Frames (a 60 fps) que tiene el jugador para completar cada comando.
const WINDOWS := {
	Motion.QCF: 15,
	Motion.QCB: 15,
	Motion.DP: 18,
	Motion.HCB: 24,
	Motion.DOUBLE_QCF: 32,
	Motion.DOUBLE_QCB: 32,
}
const HISTORY_FRAMES := 40
## Frames de tolerancia si se suelta la dirección justo antes de presionar el golpe.
const LAST_DIRECTION_GRACE := 3

## Cada entrada: [dirección, frame en que empezó].
var _history: Array = []
var _frame: int = 0


## Llamar una vez por frame de física con la entrada ya relativa al luchador.
## forward: 1 adelante, -1 atrás, 0 nada.
func push(forward: int, down: bool) -> void:
	_frame += 1
	var dir := direction_of(forward, down)
	if _history.is_empty() or _history[-1][0] != dir:
		_history.append([dir, _frame])
	# Descartar lo que ya no cabe en ninguna ventana (conservando la dirección actual).
	while _history.size() > 1 and _history[1][1] < _frame - HISTORY_FRAMES:
		_history.pop_front()


func clear() -> void:
	_history.clear()


func matches(motion: Motion) -> bool:
	if motion == Motion.NONE:
		return true
	var seq: Array = SEQUENCES[motion]
	var oldest_allowed: int = _frame - WINDOWS[motion]
	var i := seq.size() - 1
	# Se recorre el historial hacia atrás buscando la secuencia invertida.
	for k in range(_history.size() - 1, -1, -1):
		var entry: Array = _history[k]
		# Una dirección sigue "viva" hasta que empieza la siguiente.
		var ended: int = _frame if k == _history.size() - 1 else _history[k + 1][1] - 1
		if ended < oldest_allowed:
			return false
		if i == seq.size() - 1 and not _is_current_or_just_released(k):
			return false
		if entry[0] == seq[i]:
			i -= 1
			if i < 0:
				return true
	return false


## La última dirección de un comando debe seguir presionada, o haberse soltado
## (neutro) hace como mucho LAST_DIRECTION_GRACE frames. Si ya se pasó a otra dirección
## no cuenta: así →↓↘→ es ↓↘→ (resortera) y no →↓↘ (escobazos).
func _is_current_or_just_released(k: int) -> bool:
	var last := _history.size() - 1
	if k == last:
		return true
	return k == last - 1 and _history[last][0] == 5 and _history[last][1] >= _frame - LAST_DIRECTION_GRACE


static func direction_of(forward: int, down: bool) -> int:
	if down:
		return 2 + clampi(forward, -1, 1)  # 1, 2, 3
	return 5 + clampi(forward, -1, 1)  # 4, 5, 6
