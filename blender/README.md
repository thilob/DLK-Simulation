# Blender source workflow

Store editable `.blend` source files here. Recommended master file:
`dlk_vehicle.blend`. Export individual collections to `assets/models/*.glb`.

## Collection layout

```text
DLK_Vehicle
├── VehicleBody
├── Stabilizer
├── TurntableVisual
├── OperatorStation
├── LadderStage1
├── LadderStage2
├── LadderStage3
├── LadderStage4
└── RescueBasketVisual
```

Use Metric units with Unit Scale 1.0. Model the vehicle centered on X, on the
ground plane at Y=0, and longitudinally along Z. The current Godot blockout is
approximately 10.2 m long and 2.5 m wide and is the scale reference.

## Pivot contract

- Stabilizer beam origin: inner end of its horizontal guide.
- Stabilizer jack origin: top attachment at the outer beam end.
- Foot origin: center of the foot plate.
- Ladder stage origins: rear end on the extension axis.
- Basket origin: attachment at the ladder tip.
- Turntable origin: center of its vertical slew axis.
- Elevation pivot: center of the ladder heel pin.

Keep moving pieces as separate objects. Never join a stabilizer's Housing,
Beam, Jack and Foot into one mesh.

## Materials and licensing

Use glTF-compatible Principled BSDF materials. Put authored textures below
`assets/textures/`. Self-created source models and textures are covered by the
repository's MIT license. Record the license and attribution of every external
texture or model before adding it to the project.
