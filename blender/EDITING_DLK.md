# DLK-Modell in Blender bearbeiten

Diese Anleitung beschreibt die Bearbeitung von `dlk_vehicle.blend` und die
Grenzen der derzeitigen Godot-Integration.

Die konkrete technische Einbindung als sichtbares Spielfahrzeug wird getrennt
in [`INTEGRATING_DLK.md`](INTEGRATING_DLK.md) beschrieben.

## Aktueller Stand

Das Blender-Modell ist eine editierbare, detaillierte Entsprechung des
prozeduralen DLK-Modells. Das sichtbare Fahrzeug der laufenden Simulation wird
gegenwärtig jedoch weiterhin durch `_build_vehicle()` in
`scripts/main.gd` erzeugt. Änderungen an der `.blend`-Datei werden von Godot
importiert, aber noch nicht im Spiel instanziiert.

Damit sind Blender-Änderungen aktuell sicher, haben aber noch keine sichtbare
Auswirkung auf die Simulation.

## Unkritische Bearbeitungen

Folgende Arbeiten können vorgenommen werden, ohne die vorgesehenen
Schnittstellen des Modells zu verändern:

- Oberflächen formen, Kanten abrunden und Details ergänzen
- Materialien, Farben und UV-Koordinaten bearbeiten
- Fahrerhaus, Gerätekästen, Rollläden und Anbauteile detaillieren
- bestehende Meshes innerhalb ihres zugehörigen beweglichen Hauptobjekts
  ersetzen
- zusätzliche rein dekorative Objekte ergänzen

Vor dem Speichern sollte für bearbeitete Meshes `Ctrl+A > Scale` ausgeführt
werden. Blender und Godot verwenden in diesem Projekt Meter als Maßeinheit.

## Namen und Hierarchie beibehalten

Folgende Hauptobjekte dienen als vorgesehene Schnittstelle zu Godot und sollten
nicht umbenannt, vereinigt oder aus ihrer Hierarchie verschoben werden:

- `DLK_Vehicle`
- `VehicleBody`
- `Support1` bis `Support4`
- `Housing`, `Beam`, `Jack` und `Foot` jeder Abstützung
- `Turntable`
- `OperatorStation`
- `ElevationPivot`
- `LadderRoot`
- `LadderStage1` bis `LadderStage4`
- `RescueBasket`
- `BasketCameraMarker`
- `BasketApproachPoint`

Insbesondere `Beam`, `Jack` und `Foot` sowie alle Leiterstufen müssen getrennte
Objekte bleiben, weil sie später unabhängig bewegt werden sollen.

## Drehpunkte und lokale Achsen

Drehpunkte dürfen nicht nur nach optischen Gesichtspunkten verschoben werden:

- `Turntable` dreht um die senkrechte Fahrzeugachse.
- `ElevationPivot` ist das Aufrichtlager des Leitersatzes.
- Leiterstufen bewegen sich entlang ihrer lokalen Längsachse.
- Abstützträger fahren seitlich aus.
- Stempel und Stützteller bewegen sich senkrecht zum Boden.
- Der Korb wird durch Godot waagerecht gehalten.

Nach Änderungen müssen lokale Achsen, Objektursprünge und die Ruhelage geprüft
werden. Transformationen sollten nicht auf Empty- oder Pivot-Objekte angewendet
werden, wenn dadurch deren Bezugssystem verändert würde.

## Änderungen der Abmessungen

Reine Blender-Geometrie steuert derzeit weder Bewegungsgrenzen noch
Kollisionskörper. Maßänderungen werden deshalb nicht dynamisch in die
Simulationslogik zurückgeschrieben. Maßkritisch sind insbesondere:

| Modellmaß | Derzeitige Godot-Definition |
|---|---|
| Fahrzeuglänge | `VEHICLE_LENGTH` |
| Fahrzeugbreite | `VEHICLE_WIDTH` |
| Aufbauhöhe | `VEHICLE_BODY_HEIGHT` |
| Länge einer Leiterstufe | `BASE_LADDER_LENGTH` |
| Gesamter Teleskopweg | `MAX_EXTRA_EXTENSION` |
| seitlicher Abstützweg | `SUPPORT_MAX_OUT` |
| vertikaler Stempelweg | `SUPPORT_MAX_DOWN` und `SUPPORT_VISUAL_MAX_DOWN` |
| Leiter-Kollisionsradius | `LADDER_COLLISION_RADIUS` |
| Korb-Kollisionsgröße | `BASKET_COLLISION_HALF` |

Werden diese Abmessungen in Blender verändert, müssen die zugehörigen Werte,
Bewegungswege und Kollisionskörper in Godot geprüft und gegebenenfalls bewusst
angepasst werden. Eine ungeprüfte automatische Übernahme ist nicht vorgesehen.

## Empfohlener Arbeitsablauf

1. Sicherheitskopie oder Git-Commit vor größeren Modelländerungen erstellen.
2. `blender/dlk_vehicle.blend` direkt in Blender öffnen.
3. Nur Mesh-Geometrie bearbeiten und die Schnittstellenobjekte stabil halten.
4. Maßstab der bearbeiteten Meshes anwenden.
5. Datei am bestehenden Ort speichern.
6. Godot öffnen und den abgeschlossenen `.blend`-Import abwarten.
7. Importierte Hierarchie, Ausrichtung und Materialien kontrollieren.
8. Nach maßkritischen Änderungen Godot-Konstanten und Kollisionskörper prüfen.

Das Skript `create_dlk_template.py` erzeugt die mitgelieferte Grundlage neu.
Ein erneutes Ausführen überschreibt `dlk_vehicle.blend`; es darf daher nicht auf
eine manuell weiterentwickelte Arbeitsdatei angewendet werden, ohne diese zuvor
zu sichern.

## Geplante Einbindung in die Simulation

Für die tatsächliche Verwendung des Blender-Modells als sichtbares Fahrzeug ist
noch eine eigene Integrationsänderung erforderlich. Empfohlen ist ein hybrider
Aufbau: Blender liefert die sichtbaren Meshes, während Godot Eingabe,
Bewegungsgrenzen, Zielwertung und Kollisionslogik kontrolliert. Bis diese
Integration umgesetzt ist, bleibt das prozedurale Fahrzeug der aktive und
getestete Fallback. Die erforderlichen Umsetzungsschritte und Abnahmetests sind
in [`INTEGRATING_DLK.md`](INTEGRATING_DLK.md) aufgeführt.
