# Changelog

## v0.4.3
- Automatischen Universal-2-Export für Intel- und Apple-Silicon-Macs ergänzt.

## v0.4.1
- Eigene Blender-Bearbeitungsanleitung mit Maß-, Hierarchie- und Pivotregeln ergänzt.
- Schrittweise Integrationsanleitung für Blender-Meshes, Godot-Rig, Kollisionen und Fallback ergänzt.
- Start-Intro mit Projektname, GitHub-Adresse, Verfasser und KI-Hinweis ergänzt.
- Blender-DLK vom einfachen Stub auf den vollständigen Detaillierungsumfang des prozeduralen Godot-Modells erweitert.
- Direkten Godot-4.7-Import von `.blend` aktiviert, Blender-Startdatei und reproduzierbaren CI-Import ergänzt.
- Editierbare Blender-Grundmodelle für Übungsgebäude, Nebenhaus, Pkw, Strauch und Rettungsperson ergänzt.
- Stufenloser, je Kamera gespeicherter Zoom über Plus/Minus einschließlich Ziffernblock ergänzt.
- Escape-Bestätigungsdialog ergänzt; die Anwendung endet nur nach positiver Bestätigung.
- Fünf erreichbarkeitsgeprüfte Rettungspositionen mit Personen auf der Dachoberfläche ergänzt.
- Zufälliger Zielwechsel zwischen Fenster- und Dachrettung sowie automatischer Szenentest ergänzt.
- HUD-Schriftgröße für eine weniger verdeckte 3D-Ansicht ungefähr halbiert.

## v3
- Drehrichtung der Tastaturbelegung getauscht: D dreht links, A dreht rechts.
- Reproduzierbare Linux- und Windows-Exports sowie GitHub-Actions-Releaseworkflow ergänzt.
- Sichtbaren Stempelweg an die reale Bodenhöhe der Szene angepasst; Fußplatten versinken bei Bodenkontakt nicht mehr.
- Ziel- und Hintergrundhäuser durch Straßen-/Gehweg-Flächenprüfung von Verkehrswegen ferngehalten.
- Gehwege an der Querstraße getrennt und durch Zebrastreifen auf der Fahrbahn verbunden.
- Standardmäßiger Vollbildmodus mit skalierender `canvas_items`-/`expand`-Darstellung und F11-Umschaltung ergänzt.
- Fadenkreuz und Zielhinweis für unterschiedliche Seitenverhältnisse am Bildschirm verankert.
- Zufällig variierte prozedurale Einsatzumgebung mit Straßen, Parkplätzen, Häusern, Grünflächen, Sträuchern und Fahrzeugen ergänzt.
- Sichtbare Person am aktiven Zielfenster ergänzt; sie wird beim Zielwechsel zusammen mit der alten Markierung entfernt.
- Seitlicher Stützenausschub bei Bodenkontakt in beiden Richtungen verriegelt.
- Automatischer Test für die Abstützungsverriegelung ergänzt.
- Blender/glTF-Arbeitsstruktur, Modellverträge, Pivotvorgaben und Godot-Komponentenszenen vorbereitet.
- Abstützungszustand und Freigabelogik in einen eigenständigen Controller ausgelagert.
- Kollisionsfreie Wertungsposition 0,44 m vor dem Zielfenster eingeführt.
- Zielrahmen emissiv hervorgehoben und Stützen im HUD als VL/VR/HL/HR bezeichnet.
- Start-/Ablagegeometrie der Leiter überarbeitet; sichtbare Leiterauflagen ergänzt.
- Leiterpark optisch als Fachwerk-/Teleskopleiter detailliert.
- Prädiktiver Kollisionsstopp gegen das Trainingsgebäude ergänzt.
- Zielauswahl um kollisionsfreie Zielpose und garantierte Erreichbarkeit erweitert.
- Maschinistenkamera folgt der Korbhöhe vertikal und weich.
- Korbkamera mit automatischem Blick auf das aktive Zielfenster ergänzt.
- HUD um Kamera- und Kollisionsschutzstatus erweitert.
- Bedienstand und Hausfassade optisch erweitert.

## v2
- Joystickfähige proportionale Eingabeschicht.
- Vier Abstützungen, vierteiliger Leiterpark, Korbnivellierung.
- Zufälliges Haus/Zielfenster und Punktemodus.
