# DLK 23/12 Demo Simulator – Godot 4.7.1 – v3

Ein bewusst generisches 3D-Lernprojekt für die Bedienung einer Feuerwehr-Drehleiter vom Maschinistenplatz am Drehkranz. Es ist **kein** Hersteller-, Ausbildungs- oder Sicherheitsmodell und bildet keine reale Freistandsgrenze ab.

Beim Programmstart erscheint ein Intro mit Projektname, GitHub-Adresse und
Verfasser. Die Simulation beginnt über die Schaltfläche oder mit Enter beziehungsweise
Leertaste.

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
- Prozedurale Einsatzumgebung mit Straßen, Gehwegen, Parkflächen, Häusern, Rasen, Sträuchern und Fahrzeugen.
- Am aktiven Zielfenster steht eine sichtbare Person, die nach erfolgreichem Anleitern mit dem alten Ziel verschwindet.

## Steuerung

| Eingabe | Funktion |
|---|---|
| 1–4 | einzelne Abstützung auswählen |
| K / J | ausgewählte Abstützung seitlich aus-/einfahren |
| L / I | Stempel absenken/einholen |
| D / A | Drehkranz links/rechts |
| W / S | Leiter aufrichten/absenken |
| E / Q | Leiter aus-/einfahren |
| C | Kamera wechseln: Maschinist → Korb → Übersicht → außen |
| R | Szene neu starten; Gebäude und Ziel werden neu gewählt |
| F11 | zwischen Vollbild und 1280×720-Fenster wechseln |
| Escape | Sicherheitsabfrage zum Beenden öffnen |
| + / − | aktive Kamera hinein-/herauszoomen |

Bei Bodenkontakt ist der seitliche Ausschub der gewählten Stütze in beiden Richtungen verriegelt. Vor dem Ein- oder Ausfahren muss der Stempel mit `I` so weit angehoben werden, dass kein Bodenkontakt mehr besteht. Das HUD zeigt dann `quer frei` an.

Die Simulation startet standardmäßig im Vollbildmodus. Die 3D-Ansicht nutzt das aktuelle Bildschirmformat; HUD, Fadenkreuz und Zielhinweis werden anhand einer Referenzauflösung von 1280×720 skaliert und am Bildschirm verankert.

Jede Kamera speichert ihren eigenen Zoomwert. `+` verkleinert das Sichtfeld und zoomt hinein, `−` vergrößert das Sichtfeld und zoomt heraus. Haupttastatur und Ziffernblock werden unterstützt; das HUD zeigt das aktuelle Sichtfeld in Grad.

### Joystick

Die Leitersteuerung läuft über eine hardware-neutrale Eingabeschicht (`scripts/input_adapter.gd`). Standardbelegung:

- linker Stick X: Drehen
- linker Stick Y: Aufrichten/Absenken
- rechter Stick Y: Teleskopieren

Die Achsen sind **proportional**. Kleine Ausschläge führen zu langsamen Bewegungen. Zusätzlich wird eine weiche Kennlinie verwendet, um das feinfühlige Anfahren eines Fensters zu erleichtern.

## Freigabe

Die Leiter ist erst bewegbar, wenn alle vier Abstützungen (VL, VR, HL, HR) genügend seitlich ausgefahren sind und alle vier Stempel Bodenkontakt melden. Kippmoment, Bodenpressung, tatsächliche Abstützbreitenabhängigkeit und herstellerspezifische Freistandsgrenzen sind absichtlich noch nicht simuliert.

## Zielwertung

Das aktuelle Rettungsziel ist rot eingerahmt und durch eine vereinfachte Person zusätzlich erkennbar. Neben Fenstern stehen fünf mögliche Rettungspositionen auf der Dachoberfläche zur Verfügung. Bei jedem Zielwechsel wird zufällig zwischen einem Fenster- und mit etwa 35 % Wahrscheinlichkeit einem erreichbaren Dachziel gewählt.

Ein Punkt wird vergeben, wenn sich der definierte vordere Anleiterpunkt des Korbs auf höchstens 0,50 m dem Ziel nähert und keine Gebäudekollision besteht. Danach verschwinden die Person und Markierung am bisherigen Ort; an einem anderen erreichbaren Ziel erscheinen ein neuer Rahmen und eine neue Person. Fenster- und Dachziele werden vor der Auswahl auf erforderliche Leiterlänge, Aufrichtewinkel und kollisionsfreie Zielpose geprüft.

`Escape` beendet das Programm nicht unmittelbar, sondern öffnet einen modalen Dialog. Erst die Schaltfläche `Beenden` terminiert die Anwendung; `Abbrechen` setzt die Simulation fort.

## Prozedurale Umgebung

Bei jedem Neustart erzeugt das Projekt eine einfache Einsatzszenerie aus Haupt- und Querstraße, Gehwegen, Parkplätzen, zusätzlichen Gebäuden, Rasenflächen, Sträuchern sowie Fahrzeugen auf Straßen und Stellflächen. Das Zielgebäude wird ausschließlich seitlich der Hauptstraße aufgestellt. Flächenprüfungen verhindern, dass weitere Häuser auf Straßen oder Gehwegen stehen. Gehwege enden an der Querstraße und werden dort durch Zebrastreifen auf dem Asphalt fortgesetzt. Platzierungsprüfungen halten außerdem den unmittelbaren Aufstell- und Arbeitsbereich frei. Diese Umgebung ist derzeit dekorativ und gehört nicht zur Leiter-Kollisionsüberwachung.

## Blender-Modelle

Das Projekt ist für einen schrittweisen Austausch der prozeduralen Platzhalter vorbereitet:

- Blender-Arbeitsdateien und Pivotregeln: [`blender/README.md`](blender/README.md)
- Bearbeitungsregeln für das DLK-Modell: [`blender/EDITING_DLK.md`](blender/EDITING_DLK.md)
- Integrationsanleitung für das sichtbare Blender-DLK: [`blender/INTEGRATING_DLK.md`](blender/INTEGRATING_DLK.md)
- direkt importierte `.blend`-Quelle: `blender/dlk_vehicle.blend`
- Blender-Grundmodelle für Gebäude, Pkw, Strauch und Rettungsperson: `blender/*.blend`
- optionale `.glb`-Zieldateien und verbindliche Node-Namen: [`assets/models/README.md`](assets/models/README.md)
- Godot-Anker- und Komponentenszenen: `scenes/components/`

Die vorhandenen primitiven Modelle bleiben als funktionsfähiger Fallback erhalten. Sichtbare Blender-Geometrie darf später ersetzt werden, während Bewegungs-, Freigabe- und Kollisionslogik in Godot verbleiben.

Godot 4.7 verarbeitet `.blend` nicht mit einem eigenen Blender-Dateileser, sondern startet eine installierte Blender-Version und übernimmt deren glTF-Export automatisch. Deshalb installiert auch der GitHub-Actions-Workflow Blender, bevor Godot das Projekt importiert und exportiert.

## Hinweis

Das Projekt ist ein technisches Lern-/Spielmodell. Maße, Geschwindigkeiten, Verriegelungen und Bedienkonzept dürfen nicht als reale Bedien- oder Ausbildungsanweisung für eine Drehleiter verwendet werden.

## Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE). Nutzung, Veränderung und Weitergabe sind auch kommerziell gestattet, sofern der Copyright- und Lizenzhinweis erhalten bleibt.

Copyright © 2026 thilob

## Entstehung und KI-Unterstützung

Dieses Projekt wurde von thilob unter Zuhilfenahme generativer KI entwickelt.
KI-Werkzeuge unterstützten insbesondere bei Programmierung, Dokumentation und
der Erzeugung editierbarer Blender-Grundmodelle. Verantwortung für Auswahl,
Prüfung und Veröffentlichung der Projektinhalte trägt der Verfasser.

## Downloads und Builds

Lauffähige Pakete für Linux x86_64 und Windows x86_64 werden von GitHub Actions mit den offiziellen Godot-4.7.1-Export-Templates erzeugt. Jeder Push auf `main` stellt beide Pakete als Workflow-Artefakte bereit. Ein Tag nach dem Muster `v*` veröffentlicht sie zusätzlich unter [GitHub Releases](https://github.com/thilob/DLK-Simulation/releases).

Linux: ZIP entpacken, `DLK-Simulation.x86_64` ausführbar machen und starten. Windows: ZIP entpacken und `DLK-Simulation.exe` starten. Die Builds sind nicht digital signiert; Betriebssysteme können deshalb eine Sicherheitsabfrage anzeigen.
