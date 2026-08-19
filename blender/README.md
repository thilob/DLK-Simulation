# Blender source workflow

Die ausführliche Anleitung für Änderungen am Fahrzeugmodell befindet sich in
[`EDITING_DLK.md`](EDITING_DLK.md).
Die spätere Verwendung des Modells in der laufenden Simulation beschreibt
[`INTEGRATING_DLK.md`](INTEGRATING_DLK.md).

Godot 4.7 imports `.blend` files directly by invoking Blender's glTF exporter
in the background. The editable master file is `dlk_vehicle.blend`; saving it
while the Godot editor is open triggers a reimport without a manual `.glb`
export. Blender 3.0 or newer must be installed and discoverable by Godot.

The supplied file reproduces the detailed generic Godot vehicle as an editable
Blender blockout. It includes the body equipment, wheels, four separate
stabilizers, operator station, four trussed ladder stages and rescue basket.
It remains a modeling foundation rather than a manufacturer-accurate vehicle.
It can be regenerated with:

```bash
blender --background --factory-startup --python blender/create_dlk_template.py
```

Reusable blockouts corresponding to the procedural scenery can be regenerated
with:

```bash
blender --background --factory-startup --python blender/create_generic_templates.py
```

This creates separate editable sources for the training building, background
house, passenger car, shrub and rescue person. They deliberately remain simple
and use the dimensions and important marker names from `scripts/main.gd`.
Roads, sidewalks, parking areas, lawns and zebra crossings remain procedural in
Godot because their dimensions and placement are coupled to clearance checks.

If Godot does not find Blender automatically, set its executable under
`Editor Settings > Filesystem > Import > Blender > Blender Path`. The project
explicitly enables `filesystem/import/blender/enabled`.

On Arch Linux, the distribution build of Blender uses the system Python. If
startup reports `ModuleNotFoundError: No module named 'cattrs'`, install the
official repository package with `sudo pacman -Syu python-cattrs`. Do not use
`sudo pip` to modify the system Python.

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

## Generic scenery templates

- `training_building.blend`: facade blockout plus window and roof target empties
- `scenery_house.blend`: scalable secondary-building starting point
- `scenery_car.blend`: generic parked/road vehicle
- `shrub.blend`: trunk and separate foliage volumes
- `rescue_person.blend`: person blockout with a rescue approach marker

These files are modeling foundations and are not yet instantiated by the game.
Keep their root collections and marker names stable when replacing geometry.

## Optional `.glb` export

Direct `.blend` import is the normal editing workflow. Individual collections
may still be exported to `assets/models/*.glb` when an engine-ready interchange
file is needed or a collaborator cannot install Blender. Do not commit both
formats for the same production model unless that fallback is intentional.

## Materials and licensing

Use glTF-compatible Principled BSDF materials. Put authored textures below
`assets/textures/`. Self-created source models and textures are covered by the
repository's MIT license. Record the license and attribution of every external
texture or model before adding it to the project.
