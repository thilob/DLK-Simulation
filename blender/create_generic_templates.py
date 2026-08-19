"""Create editable Blender blockouts for reusable procedural scenery assets."""

from pathlib import Path
import math

import bpy
from mathutils import Vector


OUTPUT_DIR = Path(__file__).resolve().parent


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def material(name, color, metallic=0.0, roughness=0.62):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.metallic = metallic
    mat.roughness = roughness
    return mat


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def move_to_collection(obj, target):
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    target.objects.link(obj)


def box(target, name, size, location, mat):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return obj


def cylinder(target, name, radius, depth, location, mat, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return obj


def sphere(target, name, radius, location, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, target)
    return obj


def bar_between(target, name, start, end, radius, mat):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    obj = cylinder(target, name, radius, direction.length, (start_v + end_v) * 0.5, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def empty(target, name, location):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.35
    obj.location = location
    target.objects.link(obj)
    return obj


def save(filename):
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / filename), compress=True)
    print(f"Saved {filename}")


def create_training_building():
    reset_scene()
    root = collection("TrainingBuilding")
    wall = material("Wall", (0.74, 0.69, 0.61))
    roof = material("Roof", (0.24, 0.14, 0.10))
    glass = material("Glass", (0.08, 0.22, 0.31), roughness=0.25)
    frame = material("WindowFrame", (0.88, 0.88, 0.84), metallic=0.15)
    total_height = 11.4
    box(root, "BuildingVisual", (12.0, 8.0, total_height), (0, 0, total_height / 2), wall)
    box(root, "RoofSlab", (12.55, 8.55, 0.28), (0, 0, total_height + 0.12), roof)
    for floor_index in range(4):
        z = 1.85 + floor_index * 2.75
        for column in range(5):
            x = -4.45 + column * 2.22
            box(root, f"Window_{floor_index}_{column}", (1.18, 0.055, 1.42), (x, -4.03, z), glass)
            empty(root, f"WindowTarget_{floor_index}_{column}", (x, -4.20, z))
    for index, x in enumerate((-4.2, -2.1, 0.0, 2.1, 4.2)):
        empty(root, f"RoofTarget_{index}", (x, -2.0, total_height + 1.12))
    save("training_building.blend")


def create_scenery_house():
    reset_scene()
    root = collection("SceneryHouse")
    wall = material("Facade", (0.78, 0.68, 0.55))
    roof = material("Roof", (0.24, 0.12, 0.08))
    glass = material("WindowGlass", (0.10, 0.25, 0.34), roughness=0.25)
    box(root, "Facade", (8.0, 6.0, 8.0), (0, 0, 4.0), wall)
    box(root, "Roof", (8.35, 6.35, 0.35), (0, 0, 8.18), roof)
    box(root, "Door", (1.05, 0.08, 2.05), (0, -3.05, 1.03), roof)
    for floor_index in range(3):
        for side in (-1, 1):
            box(root, f"Window_{floor_index}_{side}", (1.05, 0.06, 1.25), (side * 1.65, -3.05, 1.65 + floor_index * 2.55), glass)
    save("scenery_house.blend")


def create_scenery_car():
    reset_scene()
    root = collection("SceneryCar")
    paint = material("Paint", (0.12, 0.27, 0.66), metallic=0.2, roughness=0.35)
    glass = material("Glass", (0.07, 0.16, 0.22), roughness=0.2)
    rubber = material("Rubber", (0.025, 0.025, 0.025), roughness=0.85)
    box(root, "Body", (1.75, 3.75, 0.55), (0, 0, 0.63), paint)
    box(root, "Cabin", (1.50, 1.75, 0.62), (0, 0.15, 1.12), glass)
    for y in (-1.22, 1.22):
        for x in (-0.91, 0.91):
            cylinder(root, "Wheel", 0.32, 0.18, (x, y, 0.35), rubber, (0, math.pi / 2, 0))
    save("scenery_car.blend")


def create_shrub():
    reset_scene()
    root = collection("Shrub")
    bark = material("Bark", (0.24, 0.14, 0.06), roughness=0.9)
    leaves = material("Leaves", (0.11, 0.42, 0.11), roughness=0.9)
    cylinder(root, "Stem", 0.07, 0.55, (0, 0, 0.28), bark)
    sphere(root, "FoliageA", 0.48, (-0.20, 0, 0.72), leaves)
    sphere(root, "FoliageB", 0.54, (0.24, 0.05, 0.78), leaves)
    save("shrub.blend")


def create_rescue_person():
    reset_scene()
    root = collection("RescuePerson")
    skin = material("Skin", (0.72, 0.48, 0.34), roughness=0.75)
    clothing = material("Clothing", (0.12, 0.32, 0.72), roughness=0.7)
    trousers = material("Trousers", (0.10, 0.11, 0.16), roughness=0.8)
    sphere(root, "Head", 0.18, (0, 0, 1.58), skin)
    box(root, "Torso", (0.38, 0.18, 0.50), (0, 0.02, 1.20), clothing)
    bar_between(root, "ArmLeft", (-0.16, 0, 1.36), (-0.42, 0, 1.64), 0.045, skin)
    bar_between(root, "ArmRight", (0.16, 0, 1.36), (0.42, 0, 1.64), 0.045, skin)
    bar_between(root, "LegLeft", (-0.10, 0.02, 0.95), (-0.12, 0.02, 0.40), 0.055, trousers)
    bar_between(root, "LegRight", (0.10, 0.02, 0.95), (0.12, 0.02, 0.40), 0.055, trousers)
    empty(root, "RescueApproachPoint", (0, -0.15, 1.20))
    save("rescue_person.blend")


create_training_building()
create_scenery_house()
create_scenery_car()
create_shrub()
create_rescue_person()
bpy.ops.wm.quit_blender()
