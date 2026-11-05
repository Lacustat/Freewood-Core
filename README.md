# Freewood-Core

**Deutsch & English · German & English.** Autor · Author: Lacustat. Version 0.2.2 · Interface 16001 (World of Warcraft: Forever).

## Inhalt · Contents
- [Deutsch](#deutsch)
- [English](#english)

## Deutsch

### Was ist das?
Das Basis-Addon der Freewood-Familie für World of Warcraft: Forever. Es liefert das Hauptfenster mit den Reitern, die Einstellungen, den Datenspeicher, die Bausteine für die Oberfläche und den Austausch von Daten als Text-Code. Alle anderen Module bauen darauf auf.

### Funktionen
- Hauptfenster mit Reitern: jedes Modul bringt seinen eigenen Reiter mit; fehlt ein Modul, fehlt nur sein Reiter.
- Einstellungen: Fenstergröße (50 bis 150 %) und die Optionen der einzelnen Module an einer Stelle.
- Austausch: Datenarten (zum Beispiel Wildtiere) als Text-Code exportieren und bei einem anderen Spieler importieren. Der Code ist komprimiert, nicht verschlüsselt.
- Minimap-Knopf, der das Fenster öffnet.
- Gemeinsame Bausteine (Fenster, Knöpfe, Auswahlfelder, Listen) für alle Module.

### Abhängigkeiten
- Benötigt: –
- Optional: –

### Befehle
- `/fw` oder `/freewood`: Hauptfenster öffnen

### Installation
Den Ordner `Freewood-Core` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren. Neue Dateien lädt das Spiel erst nach einem kompletten Neustart; ein `/reload` genügt nur, wenn sich bestehende Dateien geändert haben. Fehler sichtbar machen: `/console scriptErrors 1`, danach `/reload`.

### Hinweise

- Gespeichert wird in `FreewoodDB` (account) und `FreewoodCharDB` (pro Charakter). Gespeichert wird beim `/reload` oder Abmelden.

### Lizenz
GPL-3.0, siehe `LICENSE`.

---

## English

### What is it?
The base addon of the Freewood family for World of Warcraft: Forever. It provides the main window with its tabs, the settings, data storage, the UI building blocks and the exchange of data as text codes. All other modules build on it.

### Features
- Main window with tabs: every module adds its own tab; a missing module only removes its tab.
- Settings: window size (50 to 150 %) and the options of all modules in one place.
- Exchange: export data kinds (for example wild beasts) as a text code and import them on another player's game. The code is compressed, not encrypted.
- Minimap button that opens the window.
- Shared building blocks (windows, buttons, dropdowns, lists) for all modules.

### Dependencies
- Required: –
- Optional: –

### Commands
- `/fw` oder `/freewood`: Hauptfenster öffnen

### Installation
Copy the folder `Freewood-Core` to `World of Warcraft\_forever_\Interface\AddOns\`. New files only load after a full game restart; a `/reload` is enough only when existing files changed. To see errors: `/console scriptErrors 1`, then `/reload`.

### Notes

- Data is saved in `FreewoodDB` (account) and `FreewoodCharDB` (per character). It is written on `/reload` or logout.

### License
GPL-3.0, see `LICENSE`.
