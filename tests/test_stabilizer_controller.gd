extends SceneTree

const StabilizerController = preload("res://scripts/stabilizer_controller.gd")

var failures: int = 0

func _init():
	var controller = StabilizerController.new(2.25, 1.05, 0.75, 0.68)
	var state: Dictionary = controller.states[0]
	state["out"] = 2.0
	state["down"] = 1.05
	state["contact"] = true
	controller.states[0] = state

	controller.update_selected(Vector2(-1.0, 0.0), 1.0)
	_expect_close(float(controller.states[0]["out"]), 2.0, "Retracting must be blocked during ground contact")
	controller.update_selected(Vector2(1.0, 0.0), 1.0)
	_expect_close(float(controller.states[0]["out"]), 2.0, "Extending must be blocked during ground contact")
	_expect(controller.lateral_locked(), "Ground contact must report a lateral interlock")

	controller.update_selected(Vector2(-1.0, -1.0), 1.0)
	_expect_close(float(controller.states[0]["out"]), 2.0, "Lateral motion stays blocked in the frame that lifts the jack")
	_expect(not bool(controller.states[0]["contact"]), "Lifting the jack must clear ground contact")
	controller.update_selected(Vector2(-1.0, 0.0), 1.0)
	_expect(float(controller.states[0]["out"]) < 2.0, "Retraction must work after ground contact is cleared")

	if failures == 0:
		print("Stabilizer controller tests passed")
		quit(0)
	else:
		push_error("%d stabilizer controller test(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _expect_close(actual: float, expected: float, message: String):
	_expect(is_equal_approx(actual, expected), "%s (actual %.3f, expected %.3f)" % [message, actual, expected])
