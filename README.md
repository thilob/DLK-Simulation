# DLK 23/12 Demo Simulator – Godot 4.7.1 – v3

Ein bewusst generisches 3D-Lernprojekt für die Bedienung einer Feuerwehr-Drehleiter vom Maschinistenplatz am Drehkranz. Es ist **kein** Hersteller-, Ausbildungs- oder Sicherheitsmodell und bildet keine reale Freistandsgrenze ab.

## Neu in v3

- Leiter liegt beim Start vollständig eingefahren und auf sichtbaren Ablageböcken über dem Fahrzeugaufbau/Fahrerhaus.
- Vier Teleskopteile mit deutlicherer Fachwerk-/Leiterprofil-Geometrie.
- Bewegungsbegrenzung vor Gebäudekollision: eine kollidierende Leiterbewegung wird verworfen.
- Zielfenster werden nur aus geometrisch erreichbaren und bei der Zielpose kollisionsfreien Fenstern gewählt.
- Die geprüfte Zielpose liegt 0,44 m vor der Fassade: nah genug für die 0,50-m-Wertung, aber außerhalb des Gebäudekörpers.
- Falls eine zufällige Gebäudeentfernung keine gültigen Ziele ergibt, wird das Gebäude automatisch geringfügig nach außen versetzt und erneut geprüft.
- Maschinistenkamera führt den Blickwinkel weich nach oben/unten entsprechend der Korbhöhe nach.
- Zusätzliche Korbkamera; sie blickt automatisch zum jeweils rot markierten Zielfenster.
- HUD zeigt aktive Kamera und Kollisionsschutz an.
- Bedienpult optisch erweitert (Display, zwei Handregler, Kontrollleuchten).
- Hausfassade mit Fensterbänken, Regenrohren und Vordach detaillierter.
- Abstütz-Zustand und Freigabe sind in `scripts/stabilizer_controller.gd` von Darstellung und Eingabe getrennt.

## Steuerung

| Eingabe | Funktion |
|---|---|
| 1–4 | einzelne Abstützung auswählen |
| K / J | ausgewählte Abstützung seitlich aus-/einfahren |
| L / I | Stempel absenken/einholen |
| A / D | Drehkranz links/rechts |
| W / S | Leiter aufrichten/absenken |
| E / Q | Leiter aus-/einfahren |
| C | Kamera wechseln: Maschinist → Korb → Übersicht → außen |
| R | Szene neu starten; Gebäude und Ziel werden neu gewählt |

Bei Bodenkontakt ist der seitliche Ausschub der gewählten Stütze in beiden Richtungen verriegelt. Vor dem Ein- oder Ausfahren muss der Stempel mit `I` so weit angehoben werden, dass kein Bodenkontakt mehr besteht. Das HUD zeigt dann `quer frei` an.

### Joystick

Die Leitersteuerung läuft über eine hardware-neutrale Eingabeschicht (`scripts/input_adapter.gd`). Standardbelegung:

- linker Stick X: Drehen
- linker Stick Y: Aufrichten/Absenken
- rechter Stick Y: Teleskopieren

Die Achsen sind **proportional**. Kleine Ausschläge führen zu langsamen Bewegungen. Zusätzlich wird eine weiche Kennlinie verwendet, um das feinfühlige Anfahren eines Fensters zu erleichtern.

## Freigabe

Die Leiter ist erst bewegbar, wenn alle vier Abstützungen (VL, VR, HL, HR) genügend seitlich ausgefahren sind und alle vier Stempel Bodenkontakt melden. Kippmoment, Bodenpressung, tatsächliche Abstützbreitenabhängigkeit und herstellerspezifische Freistandsgrenzen sind absichtlich noch nicht simuliert.

## Zielwertung

Das aktuelle Zielfenster ist rot eingerahmt. Ein Punkt wird vergeben, wenn sich der definierte vordere Anleiterpunkt des Korbs auf höchstens 0,50 m dem Fensterzentrum nähert und keine Gebäudekollision besteht. Danach wird automatisch ein anderes gültiges Fenster gewählt.

## Blender-Modelle

Das Projekt ist für einen schrittweisen Austausch der prozeduralen Platzhalter vorbereitet:

- Blender-Arbeitsdateien und Pivotregeln: [`blender/README.md`](blender/README.md)
- `.glb`-Zieldateien und verbindliche Node-Namen: [`assets/models/README.md`](assets/models/README.md)
- Godot-Anker- und Komponentenszenen: `scenes/components/`

Die vorhandenen primitiven Modelle bleiben als funktionsfähiger Fallback erhalten. Sichtbare Blender-Geometrie darf später ersetzt werden, während Bewegungs-, Freigabe- und Kollisionslogik in Godot verbleiben.

## Hinweis

Das Projekt ist ein technisches Lern-/Spielmodell. Maße, Geschwindigkeiten, Verriegelungen und Bedienkonzept dürfen nicht als reale Bedien- oder Ausbildungsanweisung für eine Drehleiter verwendet werden.

## Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE). Nutzung, Veränderung und Weitergabe sind auch kommerziell gestattet, sofern der Copyright- und Lizenzhinweis erhalten bleibt.

Copyright © 2026 thilob
