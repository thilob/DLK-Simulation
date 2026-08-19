# External 3D models

Godot imports the editable `blender/dlk_vehicle.blend` directly. Place optional
glTF Binary (`.glb`) exports here only when an engine-ready interchange copy is
needed. Direct `.blend` import and `.glb` use the same Godot glTF pipeline.

Planned model files and required root/node names:

| File | Root | Required movable children |
|---|---|---|
| `vehicle_body.glb` | `VehicleBody` | static visual only |
| `stabilizer.glb` | `Stabilizer` | `Housing`, `Beam`, `Jack`, `Foot` |
| `turntable.glb` | `TurntableVisual` | static visual only |
| `operator_station.glb` | `OperatorStation` | static visual only |
| `ladder_stage_1.glb` | `LadderStage1` | static visual only |
| `ladder_stage_2.glb` | `LadderStage2` | static visual only |
| `ladder_stage_3.glb` | `LadderStage3` | static visual only |
| `ladder_stage_4.glb` | `LadderStage4` | static visual only |
| `rescue_basket.glb` | `RescueBasketVisual` | `BasketCameraMarker`, `ApproachPointMarker` |
| `building.glb` | `BuildingVisual` | facade visual only |

Conventions:

- One Blender unit is one metre.
- Local `Y` is up in Godot; ladder forward/tip direction is local `-Z`.
- Apply rotation and scale before export, but preserve deliberately positioned
  object origins for hinges and sliding components.
- Export selected objects as glTF Binary with modifiers, UVs, normals, tangents
  and materials enabled.
- Do not add detailed mesh collision to the exports. Godot owns the simple,
  robust collision and safety volumes.
- Imported visual scenes must not contain scripts or operational logic.

Until a model is present and wired into its component scene, the existing
procedural primitive model remains the functional fallback.
