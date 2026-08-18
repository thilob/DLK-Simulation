class_name DLKInputAdapter
extends RefCounted

# Hardware-neutral input layer.
# Keyboard actions yield -1/0/+1. Joystick axes yield continuous values.
# The response curve gives fine control around center while preserving full speed.
const RESPONSE_EXPONENT = 1.65
const EXTRA_DEADZONE = 0.06

func _shape_axis(value):
    var v = float(value)
    if abs(v) <= EXTRA_DEADZONE:
        return 0.0
    var normalized = (abs(v) - EXTRA_DEADZONE) / (1.0 - EXTRA_DEADZONE)
    normalized = clamp(normalized, 0.0, 1.0)
    return sign(v) * pow(normalized, RESPONSE_EXPONENT)

func ladder_commands():
    return {
        "slew": _shape_axis(Input.get_axis("turn_left", "turn_right")),
        "elevate": _shape_axis(Input.get_axis("lower_ladder", "raise_ladder")),
        "extend": _shape_axis(Input.get_axis("retract_ladder", "extend_ladder"))
    }

func support_axis():
    return Vector2(
        _shape_axis(Input.get_axis("support_in", "support_out")),
        _shape_axis(Input.get_axis("support_up", "support_down"))
    )
