"""Create the editable Blender source scaffold used by the Godot project."""

import bpy
from pathlib import Path


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def add_collection(name, parent):
    collection = bpy.data.collections.new(name)
    parent.children.link(collection)
    return collection


def add_empty(name, collection, parent=None, location=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.35
    obj.location = location
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def add_box(name, collection, size, location, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for source_collection in list(obj.users_collection):
        source_collection.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def build_template():
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    master = add_collection("DLK_Vehicle", scene.collection)
    root = add_empty("DLK_Vehicle", master)

    body_collection = add_collection("VehicleBody", master)
    body = add_empty("VehicleBody", body_collection, root)
    add_box("VehicleBody_Blockout", body_collection, (2.5, 10.2, 2.65), (0.0, 0.0, 1.325), body)

    support_collection = add_collection("Stabilizer", master)
    support = add_empty("Stabilizer", support_collection, root)
    housing = add_empty("Housing", support_collection, support)
    beam = add_empty("Beam", support_collection, support)
    jack = add_empty("Jack", support_collection, support)
    foot = add_empty("Foot", support_collection, support)
    add_box("HousingMesh", support_collection, (0.48, 0.58, 0.42), (0.0, 0.0, 0.0), housing)
    add_box("BeamMesh", support_collection, (0.72, 0.34, 0.26), (0.36, 0.0, 0.0), beam)
    add_box("JackMesh", support_collection, (0.22, 0.22, 0.50), (0.0, 0.0, -0.25), jack)
    add_box("FootMesh", support_collection, (0.62, 0.62, 0.10), (0.0, 0.0, -0.05), foot)

    for name in ("TurntableVisual", "OperatorStation"):
        collection = add_collection(name, master)
        add_empty(name, collection, root)

    for index in range(1, 5):
        name = f"LadderStage{index}"
        collection = add_collection(name, master)
        stage = add_empty(name, collection, root)
        add_box(f"{name}_Blockout", collection, (0.96-(index-1)*0.105, 7.4, 0.40), (0.0, -3.7, 0.2), stage)

    basket_collection = add_collection("RescueBasketVisual", master)
    basket = add_empty("RescueBasketVisual", basket_collection, root)
    add_empty("BasketCameraMarker", basket_collection, basket, (0.0, -0.08, 1.42))
    add_empty("ApproachPointMarker", basket_collection, basket, (0.0, -0.94, 0.72))

    output_path = Path(__file__).resolve().parent / "dlk_vehicle.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(output_path))
    print(f"Saved Blender template: {output_path}")
    bpy.ops.wm.quit_blender()


if __name__ == "__main__":
    build_template()
