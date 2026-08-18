extends Node3D

const InputAdapter = preload("res://scripts/input_adapter.gd")
const StabilizerController = preload("res://scripts/stabilizer_controller.gd")

# Simplified generic DLK 23/12 geometry. This is a training/demo model,
# not a manufacturer-specific load-envelope or safety controller.
const VEHICLE_LENGTH = 10.2
const VEHICLE_WIDTH = 2.5
const VEHICLE_BODY_HEIGHT = 2.65
const GROUND_Y = 0.0

const SUPPORT_MAX_OUT = 2.25
const SUPPORT_MAX_DOWN = 1.05
const SUPPORT_SPEED = 0.75
const SUPPORT_DEPLOY_THRESHOLD = 0.68
# The controller keeps a normalized 1.05 m demo stroke. The visible jack only
# needs this travel from its stowed pose until the 0.10 m foot meets the road.
const SUPPORT_VISUAL_MAX_DOWN = 0.17

const SLEW_SPEED = 20.0 * PI / 180.0
const ELEVATION_SPEED = 11.0 * PI / 180.0
const MIN_ELEVATION = 0.0
const MAX_ELEVATION = 75.0 * PI / 180.0
const STOW_ELEVATION = 0.0

const BASE_LADDER_LENGTH = 7.4
const MAX_EXTRA_EXTENSION = 21.6
const MAX_LADDER_LENGTH = BASE_LADDER_LENGTH + MAX_EXTRA_EXTENSION
const EXTENSION_SPEED = 3.0

const TARGET_DISTANCE = 0.50
const TARGET_POSE_STANDOFF = 0.44
const BUILDING_MIN_CENTER_DISTANCE = 14.0
const BUILDING_MAX_CENTER_DISTANCE = 18.5
const BUILDING_WIDTH = 12.0
const BUILDING_DEPTH = 5.0
const BUILDING_FLOORS = 5
const FLOOR_HEIGHT = 2.85
const LADDER_COLLISION_RADIUS = 0.52
const BASKET_COLLISION_HALF = Vector3(0.66, 0.62, 0.48)
const CAMERA_FOLLOW_SPEED = 4.5

var input_adapter = InputAdapter.new()
var stabilizer_controller = StabilizerController.new(SUPPORT_MAX_OUT, SUPPORT_MAX_DOWN, SUPPORT_SPEED, SUPPORT_DEPLOY_THRESHOLD)
var supports = []
var ladder_sections = []
var ladder_collision_areas = []
var cameras = []
var camera_names = []
var hud_labels = {}
var windows = []
var reachable_windows = []

var vehicle_root
var turntable
var elevation_pivot
var ladder_root
var basket
var basket_collision_area
var basket_approach_point
var building_root
var building_body
var building_total_height = 0.0
var scenery_root
var target_window
var target_marker
var target_person

var active_camera = 0
var operator_camera
var basket_camera
var score = 0
var current_extension = 0.0
var elevation_angle = STOW_ELEVATION
var slew_angle = 0.0
var previous_target_distance = 999.0
var collision_warning = false
var target_required_length = 0.0
var target_required_elevation = 0.0
var target_required_slew = 0.0
var movement_blocked_text = ""
var movement_blocked_timer = 0.0
var ladder_enabled = false

func _ready():
    _setup_input_map()
    randomize()
    _build_world()
    _build_vehicle()
    _build_building()
    _build_surroundings()
    _build_cameras()
    _build_hud()
    _apply_ladder_geometry()
    _rebuild_reachable_window_list()
    _choose_target()

func _physics_process(delta):
    _handle_selection()
    _update_supports(delta)
    _update_ladder(delta)
    _update_basket_level()
    collision_warning = _geometry_hits_building()
    _update_cameras(delta)
    _check_target()
    if movement_blocked_timer > 0.0:
        movement_blocked_timer = max(0.0, movement_blocked_timer - delta)
        if movement_blocked_timer <= 0.0:
            movement_blocked_text = ""
    _update_hud()

    if Input.is_action_just_pressed("camera_cycle"):
        _cycle_camera()
    if Input.is_action_just_pressed("reset_demo"):
        get_tree().reload_current_scene()
    if Input.is_action_just_pressed("fullscreen_toggle"):
        _toggle_fullscreen()

func _ensure_action(action_name, deadzone):
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name, deadzone)
    else:
        InputMap.action_set_deadzone(action_name, deadzone)

func _add_key(action_name, keycode):
    var ev = InputEventKey.new()
    ev.physical_keycode = keycode
    if not InputMap.action_has_event(action_name, ev):
        InputMap.action_add_event(action_name, ev)

func _add_joy_axis(action_name, axis_id, axis_value):
    var ev = InputEventJoypadMotion.new()
    ev.axis = axis_id
    ev.axis_value = axis_value
    if not InputMap.action_has_event(action_name, ev):
        InputMap.action_add_event(action_name, ev)

func _setup_input_map():
    var actions = [
        "turn_left", "turn_right", "raise_ladder", "lower_ladder",
        "extend_ladder", "retract_ladder", "support_out", "support_in",
        "support_down", "support_up", "select_support_1", "select_support_2",
        "select_support_3", "select_support_4", "camera_cycle", "reset_demo",
        "fullscreen_toggle"
    ]
    for action_name in actions:
        _ensure_action(action_name, 0.08)

    _add_key("turn_left", KEY_D)
    _add_key("turn_right", KEY_A)
    _add_key("raise_ladder", KEY_W)
    _add_key("lower_ladder", KEY_S)
    _add_key("extend_ladder", KEY_E)
    _add_key("retract_ladder", KEY_Q)
    _add_key("support_out", KEY_K)
    _add_key("support_in", KEY_J)
    _add_key("support_down", KEY_L)
    _add_key("support_up", KEY_I)
    _add_key("select_support_1", KEY_1)
    _add_key("select_support_2", KEY_2)
    _add_key("select_support_3", KEY_3)
    _add_key("select_support_4", KEY_4)
    _add_key("camera_cycle", KEY_C)
    _add_key("reset_demo", KEY_R)
    _add_key("fullscreen_toggle", KEY_F11)

    # Generic joystick layout:
    # left X = slew, left Y = elevation, right Y = telescope.
    # Input.get_axis preserves the analog magnitude, and input_adapter.gd
    # applies a soft response curve for precise slow movement near center.
    _add_joy_axis("turn_left", JOY_AXIS_LEFT_X, -1.0)
    _add_joy_axis("turn_right", JOY_AXIS_LEFT_X, 1.0)
    _add_joy_axis("raise_ladder", JOY_AXIS_LEFT_Y, -1.0)
    _add_joy_axis("lower_ladder", JOY_AXIS_LEFT_Y, 1.0)
    _add_joy_axis("extend_ladder", JOY_AXIS_RIGHT_Y, -1.0)
    _add_joy_axis("retract_ladder", JOY_AXIS_RIGHT_Y, 1.0)

func _mat(color, metallic = 0.0, roughness = 0.62):
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _box(parent, node_name, size, pos, color, collision = false, layer = 1):
    var mi = MeshInstance3D.new()
    mi.name = node_name
    var mesh = BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = _mat(color)
    parent.add_child(mi)

    if collision:
        var body = StaticBody3D.new()
        body.name = node_name + "Collision"
        body.position = pos
        body.collision_layer = layer
        body.collision_mask = 0
        parent.add_child(body)
        var cs = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        body.add_child(cs)
    return mi

func _cylinder(parent, node_name, radius, height, pos, color, rotation_degrees = Vector3.ZERO):
    var mi = MeshInstance3D.new()
    mi.name = node_name
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.position = pos
    mi.rotation_degrees = rotation_degrees
    mi.material_override = _mat(color, 0.25, 0.45)
    parent.add_child(mi)
    return mi

func _sphere(parent, node_name, radius, pos, color):
    var mi = MeshInstance3D.new()
    mi.name = node_name
    var mesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = _mat(color, 0.0, 0.72)
    parent.add_child(mi)
    return mi

func _bar_between(parent, node_name, a, b, thickness, color):
    var midpoint = (a + b) * 0.5
    var length = a.distance_to(b)
    var mi = MeshInstance3D.new()
    mi.name = node_name
    var mesh = BoxMesh.new()
    mesh.size = Vector3(thickness, thickness, length)
    mi.mesh = mesh
    mi.position = midpoint
    mi.material_override = _mat(color, 0.15, 0.42)
    parent.add_child(mi)
    if length > 0.001:
        mi.look_at(parent.to_global(b), Vector3.UP)
    return mi

func _add_area_box(parent, node_name, size, pos):
    var area = Area3D.new()
    area.name = node_name
    area.position = pos
    area.collision_layer = 0
    area.collision_mask = 2
    area.monitoring = true
    parent.add_child(area)
    var cs = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    cs.shape = shape
    area.add_child(cs)
    return area

func _build_world():
    var env = WorldEnvironment.new()
    var e = Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.55, 0.76, 0.94)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.78, 0.80, 0.84)
    e.ambient_light_energy = 0.82
    env.environment = e
    add_child(env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

    _box(self, "Ground", Vector3(100, 0.2, 100), Vector3(0, -0.1, 0), Color(0.25, 0.43, 0.23))
    _box(self, "Road", Vector3(13.0, 0.045, 100.0), Vector3(0, 0.035, 0), Color(0.18, 0.19, 0.20))
    _box(self, "RoadStripeL", Vector3(0.10, 0.02, 98.0), Vector3(-4.1, 0.07, 0), Color(0.82,0.82,0.78))
    _box(self, "RoadStripeR", Vector3(0.10, 0.02, 98.0), Vector3(4.1, 0.07, 0), Color(0.82,0.82,0.78))

func _build_vehicle():
    vehicle_root = Node3D.new()
    vehicle_root.name = "GenericDLK2312"
    add_child(vehicle_root)

    var fire_red = Color(0.78, 0.015, 0.02)
    var dark_red = Color(0.54, 0.01, 0.015)
    var silver = Color(0.70, 0.72, 0.74)
    var dark = Color(0.055, 0.06, 0.065)
    var glass = Color(0.08, 0.19, 0.27)
    var yellow = Color(0.95, 0.72, 0.04)

    _box(vehicle_root, "Frame", Vector3(2.35, 0.42, 9.5), Vector3(0, 0.78, 0.05), dark)
    _box(vehicle_root, "LowerBody", Vector3(2.48, 0.72, 9.75), Vector3(0, 1.15, 0.05), fire_red)
    _box(vehicle_root, "EquipmentBody", Vector3(2.45, 1.45, 4.75), Vector3(0, 2.02, 2.0), fire_red)
    _box(vehicle_root, "Cab", Vector3(2.45, 1.75, 2.65), Vector3(0, 2.05, -3.42), fire_red)
    _box(vehicle_root, "CabRoof", Vector3(2.46, 0.16, 2.58), Vector3(0, 2.99, -3.42), dark_red)
    _box(vehicle_root, "Windshield", Vector3(2.02, 0.82, 0.06), Vector3(0, 2.42, -4.77), glass)
    _box(vehicle_root, "FrontBumper", Vector3(2.42, 0.28, 0.26), Vector3(0, 0.85, -4.96), dark)
    _box(vehicle_root, "RearBumper", Vector3(2.42, 0.28, 0.26), Vector3(0, 0.85, 4.95), dark)

    # Equipment shutters and reflective stripe.
    for side in [-1.0, 1.0]:
        for z in [0.55, 2.0, 3.45]:
            _box(vehicle_root, "Shutter", Vector3(0.035, 1.05, 1.18), Vector3(side * 1.235, 2.02, z), silver)
        _box(vehicle_root, "ReflectiveStripe", Vector3(0.04, 0.13, 8.6), Vector3(side * 1.255, 1.38, 0.25), yellow)

    # Wheels with hubs.
    for z in [-3.15, 2.75]:
        for x in [-1.28, 1.28]:
            _cylinder(vehicle_root, "Wheel", 0.56, 0.34, Vector3(x, 0.62, z), Color(0.035,0.035,0.035), Vector3(0,0,90))
            _cylinder(vehicle_root, "Hub", 0.24, 0.355, Vector3(x, 0.62, z), silver, Vector3(0,0,90))

    # Blue warning lights.
    for x in [-0.72, 0.72]:
        _cylinder(vehicle_root, "BlueBeacon", 0.12, 0.16, Vector3(x, 3.13, -3.45), Color(0.03,0.18,0.95))

    # Stowage cradles: with zero elevation/extension the ladder lies just above
    # the superstructure and is supported over the cab instead of floating.
    _box(vehicle_root, "FrontLadderCradle", Vector3(1.18,0.18,0.28), Vector3(0,3.16,-2.70), dark)
    _box(vehicle_root, "FrontCradlePad", Vector3(0.92,0.08,0.34), Vector3(0,3.29,-2.70), Color(0.16,0.16,0.17))
    _box(vehicle_root, "RearLadderCradle", Vector3(1.20,0.18,0.30), Vector3(0,3.14,1.55), dark)

    # Stabilizer cross-beam housings.
    var support_positions = [
        Vector3(-1.18, 0.83, -1.55), Vector3(1.18, 0.83, -1.55),
        Vector3(-1.18, 0.83, 2.65), Vector3(1.18, 0.83, 2.65)
    ]
    for i in range(4):
        var s = Node3D.new()
        s.name = "Support%d" % (i + 1)
        s.position = support_positions[i]
        vehicle_root.add_child(s)
        var side = -1.0 if i % 2 == 0 else 1.0
        _box(s, "Housing", Vector3(0.48,0.42,0.58), Vector3(side * 0.12,0,0), dark)
        var beam = _box(s, "Beam", Vector3(0.72, 0.26, 0.34), Vector3(side * 0.32,0,0), silver)
        var jack = _box(s, "Jack", Vector3(0.22, 0.50, 0.22), Vector3(side * 0.48,-0.25,0), yellow)
        var foot = _box(s, "Foot", Vector3(0.62, 0.10, 0.62), Vector3(side * 0.48,-0.55,0), dark)
        supports.append({"root":s, "beam":beam, "jack":jack, "foot":foot, "side":side})

    turntable = Node3D.new()
    turntable.name = "Turntable"
    turntable.position = Vector3(0, 3.02, 2.45)
    vehicle_root.add_child(turntable)
    _cylinder(turntable, "TurntableRing", 1.03, 0.30, Vector3.ZERO, dark)
    _box(turntable, "TurntablePlatform", Vector3(2.20,0.16,1.80), Vector3(0,0.20,0), dark)
    _box(turntable, "OperatorSeatBase", Vector3(0.58,0.14,0.58), Vector3(0.90,0.46,0.15), dark)
    _box(turntable, "OperatorSeatBack", Vector3(0.58,0.66,0.14), Vector3(0.90,0.78,0.38), dark)
    _box(turntable, "ControlConsole", Vector3(0.78,0.50,0.42), Vector3(0.86,0.72,-0.46), Color(0.11,0.115,0.12))
    _box(turntable, "ConsoleDisplay", Vector3(0.48,0.23,0.025), Vector3(0.86,0.84,-0.685), Color(0.05,0.32,0.22))
    _box(turntable, "ConsoleLip", Vector3(0.80,0.08,0.34), Vector3(0.86,0.51,-0.47), dark)
    # Two visible generic proportional hand controllers. They are decorative here;
    # the actual input is hardware-neutral in input_adapter.gd.
    for xoff in [-0.20, 0.20]:
        _cylinder(turntable, "JoystickBase", 0.085, 0.08, Vector3(0.86 + xoff,0.99,-0.48), dark)
        _cylinder(turntable, "JoystickStick", 0.025, 0.25, Vector3(0.86 + xoff,1.13,-0.48), Color(0.22,0.22,0.23))
        _cylinder(turntable, "JoystickGrip", 0.055, 0.10, Vector3(0.86 + xoff,1.27,-0.48), dark)
    for xoff in [-0.22, 0.0, 0.22]:
        _cylinder(turntable, "IndicatorLamp", 0.025, 0.035, Vector3(0.86 + xoff,0.93,-0.69), yellow)

    elevation_pivot = Node3D.new()
    elevation_pivot.name = "ElevationPivot"
    elevation_pivot.position = Vector3(0, 0.38, -0.05)
    turntable.add_child(elevation_pivot)

    ladder_root = Node3D.new()
    ladder_root.name = "LadderRoot"
    elevation_pivot.add_child(ladder_root)

    # Four nested ladder sections. Local -Z is the forward/tip direction,
    # so at startup the ladder lies longitudinally over the cab roof.
    for i in range(4):
        var section = Node3D.new()
        section.name = "LadderSection%d" % (i + 1)
        ladder_root.add_child(section)
        var width = 0.96 - float(i) * 0.105
        var rail_y = 0.22 + float(i) * 0.030
        var truss_height = 0.34 - float(i) * 0.025
        # Box-section side rails with lower chords and diagonal truss braces make
        # the telescopic ladder read much more like a real aerial ladder.
        _box(section, "TopRailL", Vector3(0.080,0.095,BASE_LADDER_LENGTH), Vector3(-width/2.0,rail_y + truss_height/2.0,-BASE_LADDER_LENGTH/2.0), silver)
        _box(section, "TopRailR", Vector3(0.080,0.095,BASE_LADDER_LENGTH), Vector3(width/2.0,rail_y + truss_height/2.0,-BASE_LADDER_LENGTH/2.0), silver)
        _box(section, "BottomRailL", Vector3(0.070,0.075,BASE_LADDER_LENGTH), Vector3(-width/2.0,rail_y - truss_height/2.0,-BASE_LADDER_LENGTH/2.0), silver)
        _box(section, "BottomRailR", Vector3(0.070,0.075,BASE_LADDER_LENGTH), Vector3(width/2.0,rail_y - truss_height/2.0,-BASE_LADDER_LENGTH/2.0), silver)
        for r in range(16):
            var rz = -0.30-float(r)*0.43
            _box(section, "Rung", Vector3(width,0.050,0.060), Vector3(0,rail_y,rz), silver)
        for brace in range(7):
            var z0 = -0.25 - float(brace) * 0.92
            var z1 = z0 - 0.86
            for side_sign in [-1.0, 1.0]:
                var xside = side_sign * width / 2.0
                if brace % 2 == 0:
                    _bar_between(section, "Brace", Vector3(xside,rail_y-truss_height/2.0,z0), Vector3(xside,rail_y+truss_height/2.0,z1), 0.045, silver)
                else:
                    _bar_between(section, "Brace", Vector3(xside,rail_y+truss_height/2.0,z0), Vector3(xside,rail_y-truss_height/2.0,z1), 0.045, silver)
        var area = _add_area_box(section, "SectionCollision", Vector3(width + 0.12,0.46,BASE_LADDER_LENGTH), Vector3(0,rail_y,-BASE_LADDER_LENGTH/2.0))
        ladder_sections.append(section)
        ladder_collision_areas.append(area)

    basket = Node3D.new()
    basket.name = "RescueBasket"
    ladder_root.add_child(basket)
    _box(basket, "Floor", Vector3(1.30,0.12,0.95), Vector3(0,0.00,-0.42), silver)
    for x in [-0.60, 0.60]:
        _box(basket, "Post", Vector3(0.07,1.15,0.07), Vector3(x,0.57,-0.42), silver)
    for z in [-0.02, -0.84]:
        _box(basket, "UpperRail", Vector3(1.30,0.07,0.07), Vector3(0,1.05,z), silver)
        _box(basket, "MidRail", Vector3(1.30,0.055,0.055), Vector3(0,0.62,z), silver)
    for x in [-0.60,0.60]:
        _box(basket, "SideRail", Vector3(0.07,0.07,0.88), Vector3(x,1.05,-0.43), silver)

    basket_collision_area = _add_area_box(basket, "BasketCollision", Vector3(1.28,1.20,0.92), Vector3(0,0.57,-0.42))
    basket_approach_point = Node3D.new()
    basket_approach_point.name = "BasketApproachPoint"
    basket_approach_point.position = Vector3(0,0.72,-0.94)
    basket.add_child(basket_approach_point)

func _build_building():
    building_root = Node3D.new()
    building_root.name = "TrainingBuilding"
    add_child(building_root)

    # Keep the exercise building on either side of the longitudinal road. A
    # small longitudinal offset provides variety without allowing its footprint
    # to overlap the road or sidewalks.
    var side = -1.0 if randf() < 0.5 else 1.0
    var distance = randf_range(BUILDING_MIN_CENTER_DISTANCE, BUILDING_MAX_CENTER_DISTANCE)
    building_root.position = Vector3(side * distance, 0, randf_range(-3.0,3.0))
    building_root.look_at(Vector3(0,0,0), Vector3.UP)

    var wall = Color(0.74,0.69,0.61)
    var wall_dark = Color(0.58,0.52,0.45)
    var roof = Color(0.24,0.14,0.10)
    var glass = Color(0.08,0.22,0.31)
    var frame = Color(0.88,0.88,0.84)

    var total_height = float(BUILDING_FLOORS) * FLOOR_HEIGHT + 0.6
    building_total_height = total_height
    _box(building_root, "BuildingVisual", Vector3(BUILDING_WIDTH,total_height,BUILDING_DEPTH), Vector3(0,total_height/2.0,0), wall)

    building_body = StaticBody3D.new()
    building_body.name = "BuildingCollision"
    building_body.position = Vector3(0,total_height/2.0,0)
    building_body.collision_layer = 2
    building_body.collision_mask = 0
    building_root.add_child(building_body)
    var bcs = CollisionShape3D.new()
    var bshape = BoxShape3D.new()
    bshape.size = Vector3(BUILDING_WIDTH,total_height,BUILDING_DEPTH)
    bcs.shape = bshape
    building_body.add_child(bcs)

    # Roof edge/parapet, entrance and facade details.
    _box(building_root, "RoofSlab", Vector3(BUILDING_WIDTH+0.55,0.28,BUILDING_DEPTH+0.55), Vector3(0,total_height+0.12,0), roof)
    _box(building_root, "Door", Vector3(1.35,2.25,0.08), Vector3(4.55,1.13,-BUILDING_DEPTH/2.0-0.045), Color(0.18,0.12,0.08))
    _box(building_root, "DoorFrame", Vector3(1.55,0.12,0.11), Vector3(4.55,2.29,-BUILDING_DEPTH/2.0-0.07), frame)

    windows.clear()
    for floor in range(BUILDING_FLOORS):
        var y = 1.85 + float(floor) * FLOOR_HEIGHT
        for col in range(5):
            var x = -4.45 + float(col) * 2.22
            var w = Node3D.new()
            w.name = "Window_%d_%d" % [floor,col]
            w.position = Vector3(x,y,-BUILDING_DEPTH/2.0-0.055)
            building_root.add_child(w)
            _box(w, "Pane", Vector3(1.18,1.42,0.055), Vector3.ZERO, glass)
            _box(w, "FrameTop", Vector3(1.36,0.08,0.09), Vector3(0,0.75,-0.02), frame)
            _box(w, "FrameBottom", Vector3(1.36,0.08,0.09), Vector3(0,-0.75,-0.02), frame)
            _box(w, "FrameLeft", Vector3(0.08,1.58,0.09), Vector3(-0.64,0,-0.02), frame)
            _box(w, "FrameRight", Vector3(0.08,1.58,0.09), Vector3(0.64,0,-0.02), frame)
            _box(w, "Mullion", Vector3(0.055,1.42,0.075), Vector3(0,0,-0.04), frame)
            windows.append(w)

    # Sills, rain pipes and a small entrance canopy add depth to the otherwise
    # deliberately generic training facade.
    for floor in range(BUILDING_FLOORS):
        var wy = 1.85 + float(floor) * FLOOR_HEIGHT
        for col in range(5):
            var wx = -4.45 + float(col) * 2.22
            _box(building_root, "WindowSill", Vector3(1.42,0.09,0.22), Vector3(wx,wy-0.80,-BUILDING_DEPTH/2.0-0.12), frame)
    for pipe_x in [-5.65, 5.65]:
        _cylinder(building_root, "RainPipe", 0.055, total_height-0.5, Vector3(pipe_x,(total_height-0.5)/2.0,-BUILDING_DEPTH/2.0-0.13), Color(0.30,0.31,0.31))
    _box(building_root, "EntranceCanopy", Vector3(2.2,0.16,1.05), Vector3(4.35,2.55,-BUILDING_DEPTH/2.0-0.48), wall_dark)

    # Side wall accents make the house read as a building from oblique views.
    for y in [2.2, 5.0, 7.8, 10.6]:
        _box(building_root, "FacadeBand", Vector3(BUILDING_WIDTH+0.05,0.08,0.08), Vector3(0,y,-BUILDING_DEPTH/2.0-0.06), wall_dark)

func _scenery_position_clear(pos: Vector3, target_clearance: float, vehicle_clearance: float) -> bool:
    var flat_pos = Vector2(pos.x, pos.z)
    if flat_pos.length() < vehicle_clearance:
        return false
    if building_root != null:
        var building_flat = Vector2(building_root.position.x, building_root.position.z)
        if flat_pos.distance_to(building_flat) < target_clearance:
            return false
    return true

func _rectangles_overlap(center_a: Vector2, half_a: Vector2, center_b: Vector2, half_b: Vector2) -> bool:
    return abs(center_a.x-center_b.x) < half_a.x+half_b.x and abs(center_a.y-center_b.y) < half_a.y+half_b.y

func _house_footprint_clear(pos: Vector3, size: Vector3) -> bool:
    var center = Vector2(pos.x,pos.z)
    var half_size = Vector2(size.x/2.0+0.8,size.z/2.0+0.8)
    # Transport surfaces are described in X/Z. Sidewalk sections deliberately
    # stop at the cross street, where zebra crossings continue the foot route.
    var forbidden_rects = [
        [Vector2(0,0),Vector2(6.5,50.0)],
        [Vector2(0,28.0),Vector2(43.0,4.5)],
        [Vector2(-7.25,-13.25),Vector2(0.65,36.75)],
        [Vector2(7.25,-13.25),Vector2(0.65,36.75)],
        [Vector2(-7.25,41.25),Vector2(0.65,8.75)],
        [Vector2(7.25,41.25),Vector2(0.65,8.75)]
    ]
    for rect in forbidden_rects:
        if _rectangles_overlap(center,half_size,rect[0],rect[1]):
            return false
    return true

func _create_scenery_house(pos: Vector3, size: Vector3, color: Color, index: int):
    var house = Node3D.new()
    house.name = "BackgroundHouse%d" % index
    house.position = pos
    scenery_root.add_child(house)
    _box(house, "Facade", size, Vector3(0,size.y/2.0,0), color)
    _box(house, "Roof", Vector3(size.x+0.35,0.35,size.z+0.35), Vector3(0,size.y+0.18,0), Color(0.24,0.12,0.08))
    _box(house, "Door", Vector3(1.05,2.05,0.08), Vector3(0,1.03,-size.z/2.0-0.05), Color(0.19,0.12,0.07))
    var floor_count = maxi(2, int(floor(size.y / 2.7)))
    for floor_index in range(floor_count):
        var window_y = 1.65 + float(floor_index) * 2.55
        if window_y > size.y - 0.55:
            continue
        for side_x in [-1.0, 1.0]:
            var window_x = side_x * min(1.65, size.x * 0.24)
            _box(house, "Window", Vector3(1.05,1.25,0.06), Vector3(window_x,window_y,-size.z/2.0-0.05), Color(0.10,0.25,0.34))
            _box(house, "WindowSill", Vector3(1.20,0.08,0.18), Vector3(window_x,window_y-0.68,-size.z/2.0-0.10), Color(0.82,0.82,0.78))

func _create_shrub(pos: Vector3, scale_factor: float, index: int):
    var shrub = Node3D.new()
    shrub.name = "Shrub%d" % index
    shrub.position = pos
    scenery_root.add_child(shrub)
    _cylinder(shrub, "Stem", 0.07*scale_factor, 0.55*scale_factor, Vector3(0,0.28*scale_factor,0), Color(0.24,0.14,0.06))
    _sphere(shrub, "FoliageA", 0.48*scale_factor, Vector3(-0.20*scale_factor,0.72*scale_factor,0), Color(0.10,0.38,0.10))
    _sphere(shrub, "FoliageB", 0.54*scale_factor, Vector3(0.24*scale_factor,0.78*scale_factor,0.05), Color(0.13,0.46,0.12))

func _create_scenery_car(pos: Vector3, rotation_y: float, color: Color, index: int):
    var car = Node3D.new()
    car.name = "SceneryVehicle%d" % index
    car.position = pos
    car.rotation.y = rotation_y
    scenery_root.add_child(car)
    _box(car, "Body", Vector3(1.75,0.55,3.75), Vector3(0,0.63,0), color)
    _box(car, "Cabin", Vector3(1.50,0.62,1.75), Vector3(0,1.12,-0.15), Color(0.12,0.23,0.30))
    _box(car, "FrontGlass", Vector3(1.28,0.48,0.05), Vector3(0,1.18,-1.04), Color(0.07,0.16,0.22))
    for wheel_z in [-1.22,1.22]:
        for wheel_x in [-0.91,0.91]:
            _cylinder(car, "Wheel", 0.32, 0.18, Vector3(wheel_x,0.35,wheel_z), Color(0.025,0.025,0.025), Vector3(0,0,90))

func _build_surroundings():
    scenery_root = Node3D.new()
    scenery_root.name = "ProceduralSurroundings"
    add_child(scenery_root)

    var asphalt = Color(0.17,0.18,0.19)
    var paving = Color(0.56,0.56,0.54)
    var lawn = Color(0.29,0.52,0.22)
    # A cross street and sidewalks frame the training area without narrowing
    # the operational space around the aerial appliance.
    _box(scenery_root, "CrossStreet", Vector3(86.0,0.045,9.0), Vector3(0,0.036,28.0), asphalt)
    _box(scenery_root, "CrossStreetStripe", Vector3(82.0,0.018,0.10), Vector3(0,0.070,28.0), Color(0.88,0.78,0.18))
    # Sidewalks stop at the cross street instead of covering its asphalt.
    for sidewalk_x in [-7.25,7.25]:
        _box(scenery_root, "SidewalkSouth", Vector3(1.30,0.16,73.5), Vector3(sidewalk_x,0.08,-13.25), paving)
        _box(scenery_root, "SidewalkNorth", Vector3(1.30,0.16,17.5), Vector3(sidewalk_x,0.08,41.25), paving)
        # White bars continue each pedestrian route across the cross street.
        for crossing_index in range(9):
            var crossing_z = 24.0+float(crossing_index)*1.0
            _box(scenery_root,"ZebraStripe",Vector3(1.30,0.018,0.58),Vector3(sidewalk_x,0.070,crossing_z),Color(0.94,0.94,0.90))
    _box(scenery_root, "LawnWest", Vector3(10.0,0.08,20.0), Vector3(-13.0,0.05,-14.0), lawn)
    _box(scenery_root, "LawnEast", Vector3(10.0,0.08,20.0), Vector3(13.0,0.05,-14.0), lawn)

    var parking_centers = [Vector3(-13.0,0,14.0), Vector3(13.0,0,14.0)]
    var parking_index = 0
    for parking_pos in parking_centers:
        if not _scenery_position_clear(parking_pos, 8.5, 9.0):
            continue
        _box(scenery_root, "Parking%d" % parking_index, Vector3(8.0,0.055,10.5), parking_pos+Vector3(0,0.04,0), asphalt)
        for line_x in [-3.0,-1.0,1.0,3.0]:
            _box(scenery_root, "ParkingLine", Vector3(0.07,0.018,4.1), parking_pos+Vector3(line_x,0.078,0), Color(0.88,0.88,0.82))
        parking_index += 1

    var house_candidates = [
        Vector3(-23,0,-20), Vector3(23,0,-20), Vector3(-29,0,10),
        Vector3(29,0,10), Vector3(-25,0,38), Vector3(25,0,38)
    ]
    var house_colors = [Color(0.78,0.68,0.55),Color(0.70,0.76,0.68),Color(0.74,0.65,0.70),Color(0.82,0.76,0.63)]
    var house_index = 0
    for house_pos in house_candidates:
        var house_size = Vector3(randf_range(6.5,9.0),randf_range(6.2,10.5),randf_range(5.0,7.0))
        if _scenery_position_clear(house_pos, 11.0, 17.0) and _house_footprint_clear(house_pos,house_size):
            _create_scenery_house(house_pos,house_size,house_colors[house_index % house_colors.size()],house_index)
            house_index += 1

    var shrub_index = 0
    for shrub_pos in [Vector3(-9,0,-18),Vector3(-12,0,-8),Vector3(10,0,-19),Vector3(13,0,-8),Vector3(-18,0,31),Vector3(18,0,31)]:
        if _scenery_position_clear(shrub_pos, 7.0, 7.0):
            _create_shrub(shrub_pos,randf_range(0.8,1.3),shrub_index)
            shrub_index += 1

    var car_index = 0
    var car_specs = [
        [Vector3(-3.1,0,11.5),0.0,Color(0.12,0.27,0.66)],
        [Vector3(3.0,0,-13.0),PI,Color(0.76,0.76,0.72)],
        [Vector3(-15.0,0,27.8),PI/2.0,Color(0.68,0.12,0.10)],
        [Vector3(17.0,0,28.2),-PI/2.0,Color(0.12,0.48,0.32)],
        [Vector3(-13.0,0,14.0),0.0,Color(0.75,0.58,0.08)],
        [Vector3(13.0,0,14.0),PI,Color(0.32,0.32,0.35)]
    ]
    for spec in car_specs:
        var car_pos: Vector3 = spec[0]
        if _scenery_position_clear(car_pos, 7.5, 7.0):
            _create_scenery_car(car_pos,float(spec[1]),spec[2],car_index)
            car_index += 1

func _window_solution(window_node):
    var pivot = elevation_pivot.global_position
    var window_pos = window_node.global_position
    # Solve for a legal scoring pose just outside the facade. At 0.44 m from
    # the window it is within the 0.50 m scoring tolerance, while the basket's
    # collision volume remains outside the solid building body.
    var desired_approach = window_pos + building_root.global_basis * Vector3(0,0,-TARGET_POSE_STANDOFF)
    var delta = desired_approach - pivot
    var target_horizontal = Vector2(delta.x, delta.z).length()
    # Approximate inverse kinematics for the scoring point at the front rail:
    # the point sits about 0.94 m ahead of the ladder tip and 0.72 m above it.
    var ladder_horizontal = max(0.1, target_horizontal - 0.94)
    var ladder_vertical = delta.y - 0.72
    var length = sqrt(ladder_horizontal * ladder_horizontal + ladder_vertical * ladder_vertical)
    var angle = atan2(ladder_vertical, ladder_horizontal)
    var slew = atan2(-delta.x, -delta.z)
    return {"length":length, "angle":angle, "slew":slew, "horizontal":target_horizontal, "desired":desired_approach}

func _target_pose_is_clear(solution):
    var old_slew = slew_angle
    var old_elevation = elevation_angle
    var old_extension = current_extension

    slew_angle = float(solution["slew"])
    elevation_angle = float(solution["angle"])
    current_extension = clamp(float(solution["length"]) - BASE_LADDER_LENGTH, 0.0, MAX_EXTRA_EXTENSION)
    _apply_ladder_geometry()
    _update_basket_level()
    var clear = not _geometry_hits_building()

    slew_angle = old_slew
    elevation_angle = old_elevation
    current_extension = old_extension
    _apply_ladder_geometry()
    _update_basket_level()
    return clear

func _rebuild_reachable_window_list():
    reachable_windows.clear()
    for w in windows:
        var solution = _window_solution(w)
        var length = float(solution["length"])
        var angle = float(solution["angle"])
        # Leave enough motion margin for deliberate, slow final approach.
        if length >= BASE_LADDER_LENGTH + 0.8 and length <= MAX_LADDER_LENGTH - 0.8 and angle >= MIN_ELEVATION + deg_to_rad(2.0) and angle <= MAX_ELEVATION - deg_to_rad(2.0):
            if _target_pose_is_clear(solution):
                reachable_windows.append(w)

    # If a geometry change makes the randomly placed house unsuitable, move it
    # slightly farther away in the same direction and try again. This guarantees
    # that a new session does not start with an impossible exercise.
    var attempts = 0
    while reachable_windows.is_empty() and attempts < 5:
        attempts += 1
        var radial = building_root.position.normalized()
        building_root.position += radial * 1.25
        for w in windows:
            var retry_solution = _window_solution(w)
            var retry_length = float(retry_solution["length"])
            var retry_angle = float(retry_solution["angle"])
            if retry_length >= BASE_LADDER_LENGTH + 0.8 and retry_length <= MAX_LADDER_LENGTH - 0.8 and retry_angle >= MIN_ELEVATION + deg_to_rad(2.0) and retry_angle <= MAX_ELEVATION - deg_to_rad(2.0):
                if _target_pose_is_clear(retry_solution):
                    reachable_windows.append(w)

func _clear_target_marker():
    if target_marker != null and is_instance_valid(target_marker):
        target_marker.queue_free()
    target_marker = null
    if target_person != null and is_instance_valid(target_person):
        target_person.queue_free()
    target_person = null

func _create_target_person():
    if target_window == null:
        return
    target_person = Node3D.new()
    target_person.name = "PersonAtTargetWindow"
    target_person.position = Vector3(0,-0.12,-0.15)
    target_window.add_child(target_person)
    var skin = Color(0.82,0.57,0.42)
    var clothing = Color(0.10,0.34,0.78)
    _sphere(target_person,"Head",0.18,Vector3(0,0.28,0),skin)
    _box(target_person,"Torso",Vector3(0.38,0.50,0.18),Vector3(0,-0.10,0.02),clothing)
    _bar_between(target_person,"ArmLeft",Vector3(-0.16,0.06,0),Vector3(-0.42,0.34,0),0.09,skin)
    _bar_between(target_person,"ArmRight",Vector3(0.16,0.06,0),Vector3(0.42,0.34,0),0.09,skin)

func _choose_target():
    _clear_target_marker()
    if reachable_windows.is_empty():
        target_window = null
        return

    var candidates = reachable_windows.duplicate()
    if target_window != null and candidates.size() > 1:
        candidates.erase(target_window)
    target_window = candidates[randi() % candidates.size()]

    var solution = _window_solution(target_window)
    target_required_length = float(solution["length"])
    target_required_elevation = float(solution["angle"])
    target_required_slew = float(solution["slew"])

    target_marker = Node3D.new()
    target_marker.name = "TargetMarker"
    target_window.add_child(target_marker)
    var red = Color(1.0,0.015,0.015)
    _box(target_marker,"Top",Vector3(1.50,0.09,0.11),Vector3(0,0.82,-0.10),red)
    _box(target_marker,"Bottom",Vector3(1.50,0.09,0.11),Vector3(0,-0.82,-0.10),red)
    _box(target_marker,"Left",Vector3(0.09,1.73,0.11),Vector3(-0.75,0,-0.10),red)
    _box(target_marker,"Right",Vector3(0.09,1.73,0.11),Vector3(0.75,0,-0.10),red)
    for marker_child in target_marker.get_children():
        if marker_child is MeshInstance3D:
            var marker_material = marker_child.material_override
            marker_material.emission_enabled = true
            marker_material.emission = red
            marker_material.emission_energy_multiplier = 2.5
    _create_target_person()
    previous_target_distance = 999.0

func _build_cameras():
    operator_camera = Camera3D.new()
    operator_camera.name = "OperatorCamera"
    operator_camera.position = Vector3(0.92,1.43,0.12)
    operator_camera.rotation = Vector3.ZERO
    operator_camera.fov = 68
    turntable.add_child(operator_camera)
    cameras.append(operator_camera)
    camera_names.append("Maschinistenplatz")

    basket_camera = Camera3D.new()
    basket_camera.name = "BasketCamera"
    basket_camera.position = Vector3(0,1.42,0.08)
    basket_camera.fov = 72
    basket.add_child(basket_camera)
    cameras.append(basket_camera)
    camera_names.append("Rettungskorb")

    var overview = Camera3D.new()
    overview.name = "OverviewCamera"
    overview.position = Vector3(16,11,16)
    overview.look_at_from_position(overview.position, Vector3(0,4,0))
    add_child(overview)
    cameras.append(overview)
    camera_names.append("Übersicht")

    var side = Camera3D.new()
    side.name = "SideCamera"
    side.position = Vector3(-16,7,2)
    side.look_at_from_position(side.position, Vector3(0,4,0))
    add_child(side)
    cameras.append(side)
    camera_names.append("Außenansicht")

    _set_camera(0)

func _update_cameras(delta):
    if operator_camera != null and basket != null:
        # The operator remains seated on the turntable, but the line of sight
        # smoothly follows the basket vertically as the ladder rises or lowers.
        var local_basket = turntable.to_local(basket.global_position)
        var horizontal = max(0.1, Vector2(local_basket.x, local_basket.z).length())
        var desired_pitch = atan2(local_basket.y - operator_camera.position.y, horizontal)
        desired_pitch = clamp(desired_pitch, deg_to_rad(-8.0), deg_to_rad(78.0))
        operator_camera.rotation.x = lerp_angle(operator_camera.rotation.x, desired_pitch, clamp(delta * CAMERA_FOLLOW_SPEED,0.0,1.0))
        operator_camera.rotation.y = 0.0
        operator_camera.rotation.z = 0.0

    if basket_camera != null and target_window != null:
        # From the basket, always look toward the active marked window.
        var target = target_window.global_position + Vector3(0,0.05,0)
        if basket_camera.global_position.distance_to(target) > 0.2:
            basket_camera.look_at(target, Vector3.UP)

func _build_hud():
    var canvas = CanvasLayer.new()
    add_child(canvas)

    var panel = ColorRect.new()
    panel.position = Vector2(10,10)
    panel.size = Vector2(410,330)
    panel.color = Color(0.015,0.022,0.028,0.80)
    canvas.add_child(panel)

    var vbox = VBoxContainer.new()
    vbox.position = Vector2(14,10)
    vbox.size = Vector2(382,310)
    panel.add_child(vbox)

    for key in ["title","state","motion","geometry","supports","selected","target","collision","camera","score","help"]:
        var label = Label.new()
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vbox.add_child(label)
        hud_labels[key] = label

    hud_labels["title"].text = "DLK 23/12 – Drehkranz-Bedienstand"
    hud_labels["help"].text = "W/S Aufrichten | D/A links/rechts drehen | E/Q Teleskop\n1–4 Stütze | K/J seitlich | L/I Stempel | C Kamera | R Neustart | F11 Vollbild"

    var center = Label.new()
    center.text = "+"
    center.anchor_left = 0.5
    center.anchor_top = 0.5
    center.anchor_right = 0.5
    center.anchor_bottom = 0.5
    center.offset_left = -10.0
    center.offset_top = -18.0
    center.offset_right = 10.0
    center.offset_bottom = 18.0
    center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    center.add_theme_font_size_override("font_size",24)
    canvas.add_child(center)

    var hint = Label.new()
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.offset_left = -210.0
    hint.offset_top = 12.0
    hint.offset_right = 210.0
    hint.offset_bottom = 40.0
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.text = "Rot markiertes Fenster anleitern"
    hint.add_theme_font_size_override("font_size",16)
    canvas.add_child(hint)

func _handle_selection():
    for i in range(4):
        if Input.is_action_just_pressed("select_support_%d" % (i + 1)):
            stabilizer_controller.select(i)

func _update_supports(delta):
    var axis = input_adapter.support_axis()
    stabilizer_controller.update_selected(axis, delta)

    for i in range(4):
        var s = supports[i]
        var d = stabilizer_controller.states[i]
        var side = float(s["side"])
        var out_value = float(d["out"])
        var down_value = float(d["down"])
        var visual_down = down_value / SUPPORT_MAX_DOWN * SUPPORT_VISUAL_MAX_DOWN
        s["beam"].position.x = side * (0.32 + out_value / 2.0)
        s["beam"].scale.x = 1.0 + out_value / 0.72
        var x = side * (0.48 + out_value)
        s["jack"].position = Vector3(x,-0.25-visual_down/2.0,0)
        s["jack"].scale.y = 1.0 + visual_down / 0.50
        s["foot"].position = Vector3(x,-0.55-visual_down,0)

func _all_supports_grounded():
    return stabilizer_controller.all_grounded()

func _update_ladder(delta):
    ladder_enabled = _all_supports_grounded()
    if not ladder_enabled:
        return

    var cmd = input_adapter.ladder_commands()
    var old_slew = slew_angle
    var old_elevation = elevation_angle
    var old_extension = current_extension

    slew_angle += float(cmd["slew"]) * SLEW_SPEED * delta
    elevation_angle = clamp(elevation_angle + float(cmd["elevate"]) * ELEVATION_SPEED * delta, MIN_ELEVATION, MAX_ELEVATION)
    current_extension = clamp(current_extension + float(cmd["extend"]) * EXTENSION_SPEED * delta, 0.0, MAX_EXTRA_EXTENSION)
    _apply_ladder_geometry()
    _update_basket_level()

    # Predictive collision stop: if this requested movement would penetrate the
    # building, restore the last valid pose instead of allowing overlap.
    if _geometry_hits_building():
        slew_angle = old_slew
        elevation_angle = old_elevation
        current_extension = old_extension
        _apply_ladder_geometry()
        _update_basket_level()
        movement_blocked_text = "BEWEGUNG GESPERRT – Gebäudeabstand"
        movement_blocked_timer = 0.85

func _apply_ladder_geometry():
    if turntable == null:
        return
    turntable.rotation.y = slew_angle
    elevation_pivot.rotation.x = elevation_angle
    var per_stage = current_extension / 3.0
    for i in range(4):
        ladder_sections[i].position.z = -per_stage * float(i)
    basket.position = Vector3(0,0.23,-(BASE_LADDER_LENGTH + current_extension))

func _update_basket_level():
    if basket != null:
        # Counter-rotate the basket so its floor remains horizontal while the
        # ladder elevates. Yaw remains inherited from the turntable.
        basket.rotation.x = -elevation_angle

func _point_inside_building(world_point, margin_xz = 0.0, margin_y = 0.0):
    if building_root == null:
        return false
    var p = building_root.to_local(world_point)
    return abs(p.x) <= BUILDING_WIDTH / 2.0 + margin_xz and p.y >= -margin_y and p.y <= building_total_height + margin_y and abs(p.z) <= BUILDING_DEPTH / 2.0 + margin_xz

func _geometry_hits_building():
    if building_root == null or ladder_root == null or basket == null:
        return false

    # Sample the occupied ladder axis densely enough for this demo. Expanding
    # the house by the ladder radius approximates the truss cross-section.
    var total_length = BASE_LADDER_LENGTH + current_extension
    var d = 0.55
    while d <= total_length:
        var ladder_point = ladder_root.to_global(Vector3(0,0.28,-d))
        if _point_inside_building(ladder_point, LADDER_COLLISION_RADIUS, 0.28):
            return true
        d += 0.28

    # Sample an oriented basket volume. Because basket is actively levelled, a
    # compact 3x3x3 point grid gives reliable contact prevention for the facade.
    for xi in [-1.0, 0.0, 1.0]:
        for yi in [-1.0, 0.0, 1.0]:
            for zi in [-1.0, 0.0, 1.0]:
                var local_point = Vector3(xi * BASKET_COLLISION_HALF.x, 0.57 + yi * BASKET_COLLISION_HALF.y, -0.42 + zi * BASKET_COLLISION_HALF.z)
                if _point_inside_building(basket.to_global(local_point), 0.0, 0.0):
                    return true
    return false

func _check_target():
    if target_window == null or basket_approach_point == null:
        return
    var p = basket_approach_point.global_position
    var t = target_window.global_position
    previous_target_distance = p.distance_to(t)
    if previous_target_distance <= TARGET_DISTANCE and not collision_warning:
        score += 1
        _choose_target()

func _update_hud():
    var allowed = _all_supports_grounded()
    ladder_enabled = allowed
    var cmd = input_adapter.ladder_commands()
    var total_length = BASE_LADDER_LENGTH + current_extension
    var outreach = cos(elevation_angle) * total_length
    var tip_height = elevation_pivot.global_position.y + sin(elevation_angle) * total_length

    hud_labels["state"].text = "LEITERFREIGABE: %s" % ("JA" if allowed else "NEIN – 4× Bodenkontakt erforderlich")
    hud_labels["motion"].text = "Drehung %6.1f° | Aufrichtung %5.1f° | Teleskop %4.1f m" % [rad_to_deg(slew_angle),rad_to_deg(elevation_angle),current_extension]
    hud_labels["geometry"].text = "Leiterlänge %4.1f m | Ausladung ~%4.1f m | Spitzenhöhe ~%4.1f m" % [total_length,outreach,tip_height]

    var support_names = ["VL", "VR", "HL", "HR"]
    var support_text = "Stützen: "
    for i in range(4):
        support_text += "%s:%s  " % [support_names[i], "BODEN" if bool(stabilizer_controller.states[i]["contact"]) else "frei"]
    hud_labels["supports"].text = support_text

    var selected_support = stabilizer_controller.selected
    var selected_state = stabilizer_controller.states[selected_support]
    var lateral_status = "QUER VERRIEGELT" if stabilizer_controller.lateral_locked() else "quer frei"
    hud_labels["selected"].text = "Gewählt %s | quer %.2f/%.2f m | Stempel %.2f/%.2f m | %s | %s" % [support_names[selected_support],float(selected_state["out"]),SUPPORT_MAX_OUT,float(selected_state["down"]),SUPPORT_MAX_DOWN,"Bodenkontakt" if bool(selected_state["contact"]) else "kein Kontakt",lateral_status]
    hud_labels["target"].text = "Ziel %.2f m | Soll ~%.1f m / %.1f° / %.1f° Drehung | Achsen %.2f / %.2f / %.2f" % [previous_target_distance,target_required_length,rad_to_deg(target_required_elevation),rad_to_deg(target_required_slew),float(cmd["slew"]),float(cmd["elevate"]),float(cmd["extend"])]
    var collision_text = "frei"
    if collision_warning:
        collision_text = "KONTAKT"
    elif movement_blocked_text != "":
        collision_text = movement_blocked_text
    hud_labels["collision"].text = "KOLLISIONSSCHUTZ: %s" % collision_text
    hud_labels["camera"].text = "KAMERA: %s" % camera_names[active_camera]
    hud_labels["score"].text = "PUNKTE: %d" % score

func _cycle_camera():
    active_camera = (active_camera + 1) % cameras.size()
    _set_camera(active_camera)

func _toggle_fullscreen():
    var window = get_window()
    if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
        window.mode = Window.MODE_WINDOWED
        window.size = Vector2i(1280,720)
    else:
        window.mode = Window.MODE_FULLSCREEN

func _set_camera(index):
    for i in range(cameras.size()):
        cameras[i].current = (i == index)
