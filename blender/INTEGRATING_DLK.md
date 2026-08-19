# Blender-DLK in die Simulation integrieren

Diese Anleitung beschreibt die noch erforderlichen Entwicklungsschritte, damit
`blender/dlk_vehicle.blend` anstelle der prozedural erzeugten Fahrzeuggeometrie
im laufenden Spiel angezeigt wird. Regeln für die eigentliche Modellbearbeitung
stehen in [`EDITING_DLK.md`](EDITING_DLK.md).

## Ausgangslage

Godot importiert `dlk_vehicle.blend` bereits erfolgreich als `PackedScene`.
Die Funktion `_build_vehicle()` in `scripts/main.gd` erzeugt derzeit trotzdem
das aktive Fahrzeug aus `BoxMesh`-, `CylinderMesh`- und weiteren primitiven
Meshes. Diese Knoten dienen zugleich als Darstellung und teilweise als
Referenzen für die Bewegungslogik.

Ein bloßes Ablegen oder Speichern der Blender-Datei ersetzt diese Knoten daher
nicht. Würde die importierte Szene zusätzlich instanziiert, wären beide Modelle
gleichzeitig sichtbar und bewegliche Teile des Blender-Modells blieben zunächst
stehen.

## Empfohlene Zielarchitektur

Die Simulation sollte in drei klar getrennte Ebenen aufgeteilt werden:

1. **Steuerungs-Rig in Godot:** Transform-Knoten für Fahrzeug, Drehkranz,
   Aufrichtlager, Leiterstufen, Korb und Abstützungen.
2. **Sichtbares Blender-Modell:** ausschließlich Meshes und Materialien, die den
   passenden Rig-Knoten zugeordnet werden.
3. **Godot-Logik und Kollision:** Eingabe, Freigaben, Bewegungsgrenzen,
   Zielwertung, `Area3D`- und `CollisionShape3D`-Knoten.

Damit können Meshes in Blender weiterentwickelt werden, ohne die getestete
Steuerungs- und Sicherheitslogik in das Modell zu verlagern.

## Vorgesehene Node-Zuordnung

| Blender-Objekt | Godot-Steuerung |
|---|---|
| `DLK_Vehicle` / `VehicleBody` | `vehicle_root` |
| `Support1` bis `Support4` | jeweiliger Eintrag in `supports` |
| `Beam` | seitlicher Ausschub und Skalierung |
| `Jack` | vertikale Stempelbewegung |
| `Foot` | Stützteller und Bodenkontaktposition |
| `Turntable` | `turntable` und `slew_angle` |
| `ElevationPivot` | `elevation_pivot` und `elevation_angle` |
| `LadderStage1` bis `LadderStage4` | Einträge in `ladder_sections` |
| `RescueBasket` | `basket` und Korbnivellierung |
| `BasketCameraMarker` | Position der Korbkamera |
| `BasketApproachPoint` | Abstandsmessung zum Rettungsziel |

Diese Namen sind Schnittstellen. Dekorative Unterobjekte dürfen verändert oder
ergänzt werden, die aufgeführten Knoten sollten stabil bleiben.

## Empfohlene Umsetzungsschritte

### 1. Importierte Szene kapseln

Eine Godot-Wrapper-Szene, beispielsweise
`scenes/components/dlk_vehicle_visual.tscn`, sollte die importierte
`res://blender/dlk_vehicle.blend` als Kind enthalten. In der Wrapper-Szene
können Importkorrekturen vorgenommen werden, ohne die generierte Importszene zu
bearbeiten.

Die `.blend.import`-Datei und Dateien unter `.godot/imported/` dürfen nicht
manuell editiert werden; Godot überschreibt sie bei jedem Neuimport.

### 2. Modell laden und Hierarchie validieren

Beim Aufbau des Fahrzeugs wird die Wrapper- oder Blender-Szene instanziiert.
Vor der Verwendung müssen alle erforderlichen Knoten gesucht und geprüft
werden. Fehlt ein Pflichtknoten, sollte eine verständliche Warnung erscheinen
und das prozedurale Modell verwendet werden.

Der Fallback ist wichtig, weil ein versehentlich umbenannter Blender-Knoten
sonst zu Laufzeitfehlern oder einem unbeweglichen Fahrzeug führen könnte.

### 3. Steuerungs-Rig von den Meshes trennen

`_build_vehicle()` sollte zunächst weiterhin folgende Godot-Knoten erzeugen:

- `vehicle_root`
- vier Abstützungswurzeln und ihre Bewegungsreferenzen
- `turntable`
- `elevation_pivot`
- `ladder_root` und vier Leiterstufen
- `basket`, Kollisionsbereiche und Anfahrpunkt

Die Aufrufe von `_box()`, `_cylinder()` und `_bar_between()`, die nur sichtbare
Fahrzeuggeometrie erzeugen, werden anschließend in einen separaten
Fallback-Aufbau verschoben. Die importierten Blender-Meshes werden unter die
entsprechenden Rig-Knoten gehängt oder ihre Transformationen werden vom Rig
übernommen.

### 4. Bewegliche Teile anbinden

Die vorhandenen Funktionen bleiben maßgeblich:

- `_update_supports()` bewegt Ausschub, Stempel und Stützteller.
- `_apply_ladder_geometry()` positioniert die Leiterstufen.
- `_update_ladder()` steuert Drehung, Aufrichtung und Teleskopierung.
- `_update_basket_level()` hält den Korb waagerecht.

Nach der Integration müssen diese Funktionen die Transform-Knoten des
Blender-Modells beziehungsweise deren Godot-Eltern bewegen. Bewegungen sollten
nicht zusätzlich als Blender-Animationen angelegt werden, weil sonst zwei
Steuerungssysteme miteinander konkurrieren.

### 5. Kollisionen in Godot belassen

Die sichtbaren Blender-Meshes sollten zunächst keine automatisch erzeugten
komplexen Mesh-Kollisionen erhalten. Die vorhandenen einfachen Kollisionskörper
sind schneller, vorhersehbarer und Teil der Ziel- und Freigabeprüfungen.

Wenn Außenmaße geändert wurden, müssen insbesondere folgende Definitionen in
`scripts/main.gd` überprüft werden:

- `VEHICLE_LENGTH`, `VEHICLE_WIDTH`, `VEHICLE_BODY_HEIGHT`
- `BASE_LADDER_LENGTH`, `MAX_EXTRA_EXTENSION`
- `SUPPORT_MAX_OUT`, `SUPPORT_MAX_DOWN`, `SUPPORT_VISUAL_MAX_DOWN`
- `LADDER_COLLISION_RADIUS`, `BASKET_COLLISION_HALF`

### 6. Kameras und Marker verbinden

Die Korbkamera kann an `BasketCameraMarker` ausgerichtet werden. Für die
Zielwertung sollte `BasketApproachPoint` verwendet werden. Fehlt einer dieser
Marker, darf nicht stillschweigend der Objektursprung des Korbs benutzt werden,
weil sich dadurch der Wertungsabstand verändert.

### 7. Fallback schaltbar halten

Während der Umstellung sollte eine zentrale Option entscheiden, ob das
Blender-Modell oder die prozedurale Darstellung verwendet wird. Nach einer
erfolgreichen Validierung kann Blender zum Standard werden; der prozedurale
Aufbau bleibt als Diagnose- und Rückfalloption erhalten.

## Was automatisch übernommen wird

Nach der beschriebenen Integration übernimmt ein Godot-Neuimport automatisch:

- veränderte Mesh-Geometrie innerhalb bestehender Teile
- Materialien und UV-Koordinaten
- zusätzliche dekorative Unterobjekte
- Detail- und Oberflächenänderungen

Nicht automatisch in die Logik übernommen werden:

- geänderte Bewegungswege
- Fahrzeug- und Leitergrenzmaße
- Kollisionsvolumen
- Abstütz- und Bodenkontaktgrenzen
- Zielwertungsabstände
- umbenannte oder verschobene Schnittstellenknoten

## Abnahmetests

Vor der Ablösung des prozeduralen Standardmodells sollten mindestens folgende
Prüfungen erfolgreich sein:

1. Projekt startet auch bei fehlender oder fehlerhafter Blender-Szene über den
   Fallback.
2. Fahrzeug steht maßstäblich und mit allen Rädern auf dem Boden.
3. Alle vier Abstützungen fahren auf der korrekten Fahrzeugseite aus.
4. Stempel und Teller stoppen am Boden und bleiben dort verriegelt.
5. Drehkranz rotiert um den richtigen Mittelpunkt.
6. Leiter richtet sich um `ElevationPivot` auf.
7. Alle vier Leiterstufen teleskopieren in der korrekten Reihenfolge und
   Richtung.
8. Der Korb bleibt waagerecht und die Korbkamera sitzt am Marker.
9. Gebäude- und Korbkollisionen verhalten sich wie mit dem Fallback-Modell.
10. Fenster- und Dachziele können weiterhin gewertet werden.
11. Linux- und Windows-Exporte enthalten die importierte Szene.

## Empfehlung

Die Integration sollte als eigener Entwicklungsschritt mit Tests erfolgen und
nicht neben einer größeren Blender-Überarbeitung. Zuerst wird das unveränderte
mitgelieferte Modell angebunden. Erst wenn Rig, Marker, Kollisionen und Fallback
funktionieren, sollten Abmessungen oder Hierarchie in Blender verändert werden.
