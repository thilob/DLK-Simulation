class_name DLKStabilizerController
extends RefCounted

# State and interlock logic for the four independent stabilizers. Visual nodes
# remain in main.gd; this controller deliberately knows nothing about the scene.
const SUPPORT_COUNT = 4

var max_out: float = 2.25
var max_down: float = 1.05
var speed: float = 0.75
var deploy_threshold: float = 0.68
var selected: int = 0
var states: Array = []

func _init(p_max_out: float = 2.25, p_max_down: float = 1.05, p_speed: float = 0.75, p_deploy_threshold: float = 0.68):
	max_out = p_max_out
	max_down = p_max_down
	speed = p_speed
	deploy_threshold = p_deploy_threshold
	reset()

func reset():
	selected = 0
	states.clear()
	for _index in range(SUPPORT_COUNT):
		states.append({"out": 0.0, "down": 0.0, "contact": false})

func select(index: int):
	selected = clampi(index, 0, SUPPORT_COUNT - 1)

func update_selected(axis: Vector2, delta: float):
	var state: Dictionary = states[selected]
	var had_ground_contact: bool = bool(state["contact"])
	var lateral: float = float(state["out"])
	var vertical: float = float(state["down"])

	# The lateral beam is mechanically interlocked while the foot carries load.
	# The operator must lift the jack clear of the ground first; on the following
	# physics frame the beam can be retracted or extended again.
	if not had_ground_contact:
		lateral = clamp(lateral + axis.x * speed * delta, 0.0, max_out)

	# A jack may only be lowered after adequate lateral deployment. Retraction is
	# always allowed so the operator can recover from a partial deployment.
	if lateral > max_out * deploy_threshold or axis.y < 0.0:
		vertical = clamp(vertical + axis.y * speed * delta, 0.0, max_down)

	state["out"] = lateral
	state["down"] = vertical
	state["contact"] = vertical >= max_down * 0.97 and lateral >= max_out * deploy_threshold
	states[selected] = state

func lateral_locked(index: int = -1) -> bool:
	var checked_index: int = selected if index < 0 else clampi(index, 0, SUPPORT_COUNT - 1)
	return bool(states[checked_index]["contact"])

func all_grounded() -> bool:
	for state in states:
		if not bool(state["contact"]):
			return false
	return true
