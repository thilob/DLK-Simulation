"""Create a detailed editable DLK blockout matching the Godot primitives."""

from pathlib import Path
import math
import bpy
from mathutils import Vector

OUTPUT = Path(__file__).resolve().parent / "dlk_vehicle.blend"
LADDER_LENGTH = 7.4


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for item in list(bpy.data.collections):
        bpy.data.collections.remove(item)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def collection(name, parent):
    result = bpy.data.collections.new(name)
    parent.children.link(result)
    return result


def move_to(obj, target):
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    target.objects.link(obj)


def material(name, color, metallic=0.0, roughness=0.62):
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1.0)
    result.metallic = metallic
    result.roughness = roughness
    return result


def gv(value):
    """Godot X/Y/Z (Y up, -Z forward) to Blender X/Y/Z."""
    return (value[0], -value[2], value[1])


def empty(name, target, parent=None, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.28
    obj.location = gv(location)
    target.objects.link(obj)
    obj.parent = parent
    return obj


def box(name, target, size, location, mat, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    obj.location = gv(location)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move_to(obj, target)
    obj.parent = parent
    return obj


def cylinder(name, target, radius, height, location, mat, parent=None, axis="Y"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=height)
    obj = bpy.context.object
    obj.name = name
    obj.location = gv(location)
    if axis == "X":
        obj.rotation_euler[1] = math.pi / 2
    elif axis == "Z":
        obj.rotation_euler[0] = math.pi / 2
    obj.data.materials.append(mat)
    move_to(obj, target)
    obj.parent = parent
    return obj


def bar(name, target, start, end, thickness, mat, parent):
    a, b = Vector(gv(start)), Vector(gv(end))
    direction = b - a
    obj = cylinder(name, target, thickness / 2, direction.length, (0, 0, 0), mat, parent)
    obj.location = (a + b) * 0.5
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")


def build_body(master, root, m):
    group = collection("VehicleBody", master)
    body = empty("VehicleBody", group, root)
    parts = [
        ("Frame", (2.35, .42, 9.5), (0, .78, .05), "dark"),
        ("LowerBody", (2.48, .72, 9.75), (0, 1.15, .05), "red"),
        ("EquipmentBody", (2.45, 1.45, 4.75), (0, 2.02, 2), "red"),
        ("Cab", (2.45, 1.75, 2.65), (0, 2.05, -3.42), "red"),
        ("CabRoof", (2.46, .16, 2.58), (0, 2.99, -3.42), "dark_red"),
        ("Windshield", (2.02, .82, .06), (0, 2.42, -4.77), "glass"),
        ("FrontBumper", (2.42, .28, .26), (0, .85, -4.96), "dark"),
        ("RearBumper", (2.42, .28, .26), (0, .85, 4.95), "dark"),
        ("FrontLadderCradle", (1.18, .18, .28), (0, 3.16, -2.70), "dark"),
        ("FrontCradlePad", (.92, .08, .34), (0, 3.29, -2.70), "pad"),
        ("RearLadderCradle", (1.20, .18, .30), (0, 3.14, 1.55), "dark"),
    ]
    for name, size, pos, mat in parts:
        box(name, group, size, pos, m[mat], body)
    for side_name, side in (("Left", -1), ("Right", 1)):
        for index, z in enumerate((.55, 2, 3.45), 1):
            box(f"Shutter{side_name}{index}", group, (.035, 1.05, 1.18), (side * 1.235, 2.02, z), m["silver"], body)
        box(f"ReflectiveStripe{side_name}", group, (.04, .13, 8.6), (side * 1.255, 1.38, .25), m["yellow"], body)
    for axle, z in (("Front", -3.15), ("Rear", 2.75)):
        for side_name, x in (("Left", -1.28), ("Right", 1.28)):
            cylinder(f"Wheel{axle}{side_name}", group, .56, .34, (x, .62, z), m["rubber"], body, "X")
            cylinder(f"Hub{axle}{side_name}", group, .24, .355, (x, .62, z), m["silver"], body, "X")
    for side_name, x in (("Left", -.72), ("Right", .72)):
        cylinder(f"BlueBeacon{side_name}", group, .12, .16, (x, 3.13, -3.45), m["blue"], body)


def build_supports(master, root, m):
    group = collection("Stabilizers", master)
    positions = ((-1.18, .83, -1.55), (1.18, .83, -1.55), (-1.18, .83, 2.65), (1.18, .83, 2.65))
    for index, pos in enumerate(positions, 1):
        side = -1 if index % 2 else 1
        support = empty(f"Support{index}", group, root, pos)
        housing, beam = empty("Housing", group, support), empty("Beam", group, support)
        jack, foot = empty("Jack", group, support), empty("Foot", group, support)
        box("HousingMesh", group, (.48, .42, .58), (side * .12, 0, 0), m["dark"], housing)
        box("BeamMesh", group, (.72, .26, .34), (side * .32, 0, 0), m["silver"], beam)
        box("JackMesh", group, (.22, .50, .22), (side * .48, -.25, 0), m["yellow"], jack)
        box("FootMesh", group, (.62, .10, .62), (side * .48, -.55, 0), m["dark"], foot)


def build_turntable(master, root, m):
    group = collection("TurntableVisual", master)
    turntable = empty("Turntable", group, root, (0, 3.02, 2.45))
    cylinder("TurntableRing", group, 1.03, .30, (0, 0, 0), m["dark"], turntable)
    box("TurntablePlatform", group, (2.20, .16, 1.80), (0, .20, 0), m["dark"], turntable)
    operator = empty("OperatorStation", group, turntable)
    for name, size, pos, mat in (
        ("OperatorSeatBase", (.58, .14, .58), (.90, .46, .15), "dark"),
        ("OperatorSeatBack", (.58, .66, .14), (.90, .78, .38), "dark"),
        ("ControlConsole", (.78, .50, .42), (.86, .72, -.46), "console"),
        ("ConsoleDisplay", (.48, .23, .025), (.86, .84, -.685), "display"),
        ("ConsoleLip", (.80, .08, .34), (.86, .51, -.47), "dark"),
    ):
        box(name, group, size, pos, m[mat], operator)
    for index, offset in enumerate((-.20, .20), 1):
        cylinder(f"JoystickBase{index}", group, .085, .08, (.86 + offset, .99, -.48), m["dark"], operator)
        cylinder(f"JoystickStick{index}", group, .025, .25, (.86 + offset, 1.13, -.48), m["pad"], operator)
        cylinder(f"JoystickGrip{index}", group, .055, .10, (.86 + offset, 1.27, -.48), m["dark"], operator)
    for index, offset in enumerate((-.22, 0, .22), 1):
        cylinder(f"IndicatorLamp{index}", group, .025, .035, (.86 + offset, .93, -.69), m["yellow"], operator)
    return empty("ElevationPivot", group, turntable, (0, .38, -.05))


def build_ladder(master, pivot, m):
    group = collection("LadderStages", master)
    ladder_root = empty("LadderRoot", group, pivot)
    for index in range(4):
        stage = empty(f"LadderStage{index + 1}", group, ladder_root)
        width = .96 - index * .105
        rail_y = .22 + index * .030
        height = .34 - index * .025
        for suffix, x in (("L", -width / 2), ("R", width / 2)):
            box(f"TopRail{suffix}", group, (.080, .095, LADDER_LENGTH), (x, rail_y + height / 2, -LADDER_LENGTH / 2), m["silver"], stage)
            box(f"BottomRail{suffix}", group, (.070, .075, LADDER_LENGTH), (x, rail_y - height / 2, -LADDER_LENGTH / 2), m["silver"], stage)
        for rung in range(16):
            box(f"Rung{rung + 1:02d}", group, (width, .050, .060), (0, rail_y, -.30 - rung * .43), m["silver"], stage)
        for brace in range(7):
            z0, z1 = -.25 - brace * .92, -1.11 - brace * .92
            for suffix, side in (("L", -1), ("R", 1)):
                x = side * width / 2
                a, b = (x, rail_y - height / 2, z0), (x, rail_y + height / 2, z1)
                if brace % 2:
                    a, b = (x, rail_y + height / 2, z0), (x, rail_y - height / 2, z1)
                bar(f"Brace{suffix}{brace + 1:02d}", group, a, b, .045, m["silver"], stage)
    basket = empty("RescueBasket", group, ladder_root)
    box("BasketFloor", group, (1.30, .12, .95), (0, 0, -.42), m["silver"], basket)
    for side_name, x in (("Left", -.60), ("Right", .60)):
        box(f"BasketPost{side_name}", group, (.07, 1.15, .07), (x, .57, -.42), m["silver"], basket)
        box(f"BasketSideRail{side_name}", group, (.07, .07, .88), (x, 1.05, -.43), m["silver"], basket)
    for edge_name, z in (("Front", -.02), ("Rear", -.84)):
        box(f"BasketUpperRail{edge_name}", group, (1.30, .07, .07), (0, 1.05, z), m["silver"], basket)
        box(f"BasketMidRail{edge_name}", group, (1.30, .055, .055), (0, .62, z), m["silver"], basket)
    empty("BasketCameraMarker", group, basket, (0, 1.42, -.08))
    empty("BasketApproachPoint", group, basket, (0, .72, -.94))


def build_template():
    clear_scene()
    master = collection("DLK_Vehicle", bpy.context.scene.collection)
    root = empty("DLK_Vehicle", master)
    m = {
        "red": material("FireRed", (.78, .015, .02), .08, .35),
        "dark_red": material("DarkRed", (.54, .01, .015), .08, .38),
        "silver": material("Aluminium", (.70, .72, .74), .72, .28),
        "dark": material("DarkMetal", (.055, .06, .065), .35, .46),
        "glass": material("CabGlass", (.08, .19, .27), .05, .18),
        "yellow": material("SafetyYellow", (.95, .72, .04), .05, .42),
        "blue": material("BeaconBlue", (.03, .18, .95), .05, .18),
        "rubber": material("Rubber", (.035, .035, .035), 0, .86),
        "pad": material("DarkPlastic", (.16, .16, .17), 0, .65),
        "console": material("Console", (.11, .115, .12), .15, .54),
        "display": material("Display", (.05, .32, .22), 0, .22),
    }
    build_body(master, root, m)
    build_supports(master, root, m)
    build_ladder(master, build_turntable(master, root, m), m)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT), compress=True)
    print(f"Saved detailed Blender model: {OUTPUT}")
    bpy.ops.wm.quit_blender()


if __name__ == "__main__":
    build_template()
