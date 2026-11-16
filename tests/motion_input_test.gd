## Prueba del detector de comandos (MotionInput).
## Uso: godot --headless --path . -s res://tests/motion_input_test.gd
extends SceneTree

var _failures := 0


func _init() -> void:
	var M := MotionInput.Motion

	# ↓↘→ limpio.
	_check("QCF limpio", _feed([[0, true, 3], [1, true, 3], [1, false, 2]]), M.QCF, true)
	# Sin la diagonal no cuenta (evita especiales al agacharse y caminar).
	_check("QCF sin diagonal", _feed([[0, true, 4], [1, false, 2]]), M.QCF, false)
	# Demasiado lento: fuera de la ventana de 15 frames (cuenta desde que se suelta ↓).
	_check("QCF lento", _feed([[0, true, 3], [1, true, 16], [1, false, 2]]), M.QCF, false)
	# Mantener agachado mucho y luego ↓↘→ rápido sí vale.
	_check("QCF desde agachado", _feed([[0, true, 30], [1, true, 3], [1, false, 2]]), M.QCF, true)
	# Al revés no es QCF, es QCB.
	var qcb := _feed([[0, true, 3], [-1, true, 3], [-1, false, 2]])
	_check("QCB", qcb, M.QCB, true)
	_check("QCB no es QCF", qcb, M.QCF, false)
	# →↓↘
	_check("DP", _feed([[1, false, 3], [0, true, 3], [1, true, 2]]), M.DP, true)
	# Caminar adelante + ↓↘→ y presionar tarde: QCF sí, DP no.
	var walk_qcf := _feed([[1, false, 10], [0, true, 3], [1, true, 3], [1, false, 6]])
	_check("caminar+QCF es QCF", walk_qcf, M.QCF, true)
	_check("caminar+QCF no es DP", walk_qcf, M.DP, false)
	# Terminar en ↘ y soltar justo antes del golpe sigue valiendo.
	_check("DP soltando", _feed([[1, false, 3], [0, true, 3], [1, true, 2], [0, false, 2]]), M.DP, true)
	# Pasarse a → al final: es ↓↘→, no →↓↘ (aunque sea rápido).
	var fast := _feed([[1, false, 3], [0, true, 2], [1, true, 2], [1, false, 1]])
	_check("→↓↘→ rápido es QCF", fast, M.QCF, true)
	_check("→↓↘→ rápido no es DP", fast, M.DP, false)
	# Doble ↓↘→
	var dq := _feed([[0, true, 3], [1, true, 3], [1, false, 3], [0, true, 3], [1, true, 3], [1, false, 2]])
	_check("doble QCF", dq, M.DOUBLE_QCF, true)
	_check("doble QCF incluye QCF", dq, M.QCF, true)
	_check("QCF simple no es doble", _feed([[0, true, 3], [1, true, 3], [1, false, 2]]), M.DOUBLE_QCF, false)
	# Ruido entre medio (soltar abajo un frame) se tolera.
	_check("QCF con ruido", _feed([[0, true, 2], [0, false, 1], [0, true, 1], [1, true, 3], [1, false, 2]]), M.QCF, true)
	# Medio círculo atrás →↘↓↙←
	_check("HCB", _feed([[1, false, 2], [1, true, 2], [0, true, 2], [-1, true, 2], [-1, false, 2]]), M.HCB, true)

	if _failures == 0:
		print("motion_input_test: OK")
	else:
		print("motion_input_test: %d FALLAS" % _failures)
	quit(1 if _failures else 0)


## steps: [[forward, down, frames], ...]
func _feed(steps: Array) -> MotionInput:
	var m := MotionInput.new()
	for s in steps:
		for i in s[2]:
			m.push(s[0], s[1])
	return m


func _check(label: String, m: MotionInput, motion: int, expected: bool) -> void:
	var got := m.matches(motion)
	if got != expected:
		_failures += 1
		print("FALLA: %s (esperado %s, obtuvo %s)" % [label, expected, got])
