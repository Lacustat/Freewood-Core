# Freewood-Core

**Deutsch & English · German & English.** Autor · Author: Lacustat. Version 0.17.0 · Interface 16001 (World of Warcraft: Forever).

## Inhalt · Contents
- [Deutsch](#deutsch)
- [English](#english)
- [Tastenbelegung · Key bindings](#tastenbelegung--key-bindings)
- [Reiter ordnen · Arranging tabs](#reiter-ordnen--arranging-tabs)

## Deutsch

### Was ist das?
Das Basis-Addon der Freewood-Familie für World of Warcraft: Forever. Es liefert das Hauptfenster mit den Reitern, die Einstellungen, den Datenspeicher, die Bausteine für die Oberfläche und den Austausch von Daten als Text-Code. Alle anderen Module bauen darauf auf.

### Funktionen
- Hauptfenster mit Reitern: jedes Modul bringt seinen eigenen Reiter mit; fehlt ein Modul, fehlt nur sein Reiter.
- Einstellungen: Fenstergröße (50 bis 150 %) und die Optionen der einzelnen Module an einer Stelle.
- Austausch: Datenarten (zum Beispiel Wildtiere) als Text-Code exportieren und bei einem anderen Spieler importieren. Der Code ist komprimiert, nicht verschlüsselt.
- Beobachten-Fenster (`/fwwatch`): eigene Merkliste für Rezepte mit Materialien und Taschenbestand; andere Module (zum Beispiel Guild, später Auction) legen Rezepte hinein.
- Statistik-Reiter (0.10.0): Unterreiter „Charakter“ und „Account“ (Charakterliste links, Summe aller Charaktere). Einklappbare Kategorien: Überblick, Werte, Kampf, Erfahrung, Gold (nach Quelle), Beute, Reisen (zu Fuß, Reittier, Schwimmen, Flug), Soziales, Tode. Knopf „Wegenetz anzeigen“ blendet die Karte der gelaufenen Wege (Codex) ein. Alle Daten werden nur lokal gezählt; Fehlendes füllt sich mit dem Spielen.
- Statistik erweitert (0.11.0): Quests (erledigt, Erfahrung und Gold laut Codex-Daten, je Zone), Ruf, Berufe, Talente, Zauber, Erfolge, Ausrüstung, Taschenwert, Erkundung. Jede Abfrage ist geschützt; antwortet der Client nicht, fehlt nur die Zeile. `/fwstatprobe` zeigt, welche Abfragen im Spiel antworten.
- Statistik (0.12.0): Symbole an den Kategorien, Zeilen leuchten beim Drüberfahren auf, neue Kategorie „Kills (Codex)“ (Kills mit Erfahrung, Kreaturenarten, geplünderte Leichen, Top 8; gilt für den ganzen Account, weil der Codex account-weit lernt).
- Minimap-Knopf, der das Fenster öffnet.
- Gemeinsame Bausteine (Fenster, Knöpfe, Auswahlfelder, Listen) für alle Module.

### Abhängigkeiten
- Benötigt: –
- Optional: –

### Befehle
- `/fw` oder `/freewood`: Hauptfenster öffnen
- `/fwwatch`: Beobachten-Fenster, `/fwwatch clear` leert es

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
- Watch window (`/fwwatch`): its own list for recipes with materials and live bag counts; other modules (for example Guild, later Auction) put recipes into it.
- Statistics tab (0.10.0): sub-tabs "Character" and "Account" (character list on the left, sum of all characters). Collapsible categories: overview, values, combat, experience, gold (by source), loot, travel (foot, mount, swimming, flight), social, deaths. A "Show path network" button toggles the map of walked paths (Codex). Everything is counted locally; gaps fill as you play.
- Statistics extended (0.11.0): quests (completed, experience and gold from Codex data, per zone), reputation, professions, talents, spells, achievements, equipment, bag value, exploration. Every query is guarded; if the client does not answer, only that row is missing. `/fwstatprobe` shows which queries answer in game.
- Statistics (0.12.0): icons on the categories, rows highlight on mouse-over, new category "Kills (Codex)" (kills with experience, creature species, looted corpses, top 8; account-wide because the Codex learns account-wide).
- Minimap button that opens the window.
- Shared building blocks (windows, buttons, dropdowns, lists) for all modules.

### Dependencies
- Required: –
- Optional: –

### Commands
- `/fw` oder `/freewood`: Hauptfenster öffnen
- `/fwwatch`: watch window, `/fwwatch clear` empties it

### Installation
Copy the folder `Freewood-Core` to `World of Warcraft\_forever_\Interface\AddOns\`. New files only load after a full game restart; a `/reload` is enough only when existing files changed. To see errors: `/console scriptErrors 1`, then `/reload`.

### Notes

- Data is saved in `FreewoodDB` (account) and `FreewoodCharDB` (per character). It is written on `/reload` or logout.

### License
GPL-3.0, see `LICENSE`.

## Tastenbelegung · Key bindings
**DE:** Unter Optionen > Tastaturbelegung gibt es einen eigenen Abschnitt für dieses Modul. Dort lässt sich eine Taste zum Öffnen und Schließen des Reiters belegen (zum Beispiel J für die Gilde). Ist der Reiter schon offen, schließt dieselbe Taste das Fenster. Nach der Installation einmal das Spiel neu starten, damit die neue Datei Bindings.xml gelesen wird.
**EN:** Options > Key Bindings has its own section for this module. Bind a key to open and close the tab (for example J for the guild). If the tab is already open, the same key closes the window. Restart the game once after installing so the new Bindings.xml file is read.

## Reiter ordnen · Arranging tabs
**DE:** Die Reiter der Hauptleiste lassen sich mit der Maus ziehen und so in beliebige Reihenfolge bringen (auch in eine andere Zeile). Rechtsklick auf einen Reiter blendet ihn aus. Unter Einstellungen > Reiter blendest du Reiter wieder ein oder stellst die Standard-Reihenfolge her. Der Reiter „Einstellungen“ lässt sich nicht ausblenden. Reihenfolge und Auswahl gelten für den ganzen Account. Neue Reiter, die noch nicht in deiner Reihenfolge stehen, erscheinen hinten.
**EN:** Drag the tabs of the main bar with the mouse to put them in any order (also into another row). Right-click a tab to hide it. Under Settings > Tabs you can show hidden tabs again or restore the default order. The Settings tab cannot be hidden. Order and visibility apply to the whole account. New tabs that are not yet in your order appear at the end.

## Flüstern (0.13.0, vorbereitet, AUS) · Whisper (0.13.0, prepared, OFF)
**DE:** `Core/Whisper.lua` sendet und empfängt Daten per unsichtbarer Flüster-Addon-Nachricht (Präfix `FWWH1`). Im Spiel gemessen: kommt an, steht nicht im Chat, 100 Nachrichten am Stück ohne Drosselung (an sich selbst). Der Schalter `settings.whisperShare` ist aus; nur Testnachrichten („T|“) gehen immer und stehen im Protokoll. Test im Dev-Addon, Reiter „Flüstertest“ (`/fwwhisper`).
**EN:** `Core/Whisper.lua` sends and receives data by invisible whisper addon messages (prefix `FWWH1`). Measured in game: arrives, not shown in chat, 100 messages in a row without throttling (to self). The switch `settings.whisperShare` is off; only test messages ("T|") always work and are logged. Test in the Dev addon, tab "Whisper test" (`/fwwhisper`).
**0.13.1 DE:** Testlauf: Jeder Spieler mit diesem Core schickt einmal je Account eine Testnachricht an „Dr Freewood“ (45–150 s nach dem Anmelden, nicht im Kampf). Echte Daten bleiben aus. / **EN:** Test run: every player with this Core sends one test message per account to "Dr Freewood" (45–150 s after login, not in combat). Real data stays off.
**0.13.2 DE:** Der einmalige Testlauf an „Dr Freewood“ ist beendet (`Whisper.AUTO_TEST = false`); der Test im Dev-Reiter bleibt. / **EN:** The one-time test run to "Dr Freewood" is finished (`Whisper.AUTO_TEST = false`); the test in the Dev tab stays.

## Design: Farben und Schriften (0.16.0) · Design: colors and fonts (0.16.0)
**DE:** Einstellungen → Design (`UI/Design.lua`). Zehn Grundfarben (Hintergründe, Flächen, Akzent, Rahmen, Text) über den Blizzard-Farbwähler, Transparenz der Flächen (Deckkraft 30–100 %), Schriftgröße der Haupt-Reiter (9–20) und Schriftart für Überschriften/Haupt-Reiter und für normalen Text (Spielschriften: Spiel-Standard, Friz Quadrata, Arial Narrow, Morpheus, Skurri; nur was der Client lädt, wird angeboten). Alles wirkt sofort, außer der Schriftart des normalen Textes (nach „Interface neu laden“). Technik: `UI.Color` merkt sich, welche Textur/welcher Text welche Farbe bekam (`UI.tracked`, Haken in die Methoden `SetColorTexture`/`SetTextColor`), die festen Teile des Hauptfensters aus `MainWindow.xml` sind in `Design.lua` aufgelistet. Fehlen die Haken (`UI.liveColors == false`), gelten Farbänderungen erst nach `/reload`. Eigene Grafiken für Designs folgen später. Test: `tests/design_test.lua`. Ungeprüft im Spiel.
**EN:** Settings → Design (`UI/Design.lua`). Ten base colors (backgrounds, surfaces, accent, borders, text) via Blizzard's color picker, transparency of surfaces (opacity 30–100 %), font size of the main tabs (9–20) and font for headings/main tabs and for normal text (game fonts: game default, Friz Quadrata, Arial Narrow, Morpheus, Skurri; only fonts the client loads are offered). Everything applies at once except the font of normal text (after "Reload interface"). Technique: `UI.Color` remembers which texture/text received which color (`UI.tracked`, hooks on `SetColorTexture`/`SetTextColor`); the static parts of the main window from `MainWindow.xml` are listed in `Design.lua`. Without the hooks (`UI.liveColors == false`) color changes apply after `/reload`. Own graphics for designs come later. Test: `tests/design_test.lua`. Unchecked in game.

**0.16.1 DE:** Fehler in 0.16.0 behoben: Ein beim Laden erzeugtes unsichtbares Eingabefeld (nur für den Haken in die Farbmethoden) hat den Tastaturfokus an sich gerissen, die Tastatur reagierte im Spiel nicht mehr. Das Feld gibt den Fokus jetzt ab und ist versteckt. **EN:** Fixed a 0.16.0 bug: an invisible edit box created at load (only used to hook the color methods) took the keyboard focus, so the keyboard stopped responding in game. It now gives up focus and is hidden.

**0.17.0 DE:** Neuer Reiter „Chat“ unter Einstellungen. Die Chat-Blasen-Einstellungen sind von „Allgemein“ dorthin umgezogen (an/aus, Dauer, Richtung, Ankerpunkt verschieben, Testblase). Neu als Blasen: Sagen, Rufen und Emotes (Standard: Sagen und Rufen an, Emotes aus), dazu wie bisher Gilde, Gruppe/Schlachtzug, Flüstern, Kanäle. Das Chatfenster des Spiels bleibt unverändert. Geheime Werte werden übersprungen. Die Unter-Reiter der Einstellungen sind etwas schmaler (140 statt 160 Pixel), damit alle acht ins Fenster passen. Test: `texlua tests/bubbles_test.lua`. **EN:** New "Chat" tab in settings. The chat bubble settings moved there from "General" (on/off, duration, direction, move anchor, test bubble). New as bubbles: say, yell and emotes (default: say and yell on, emotes off), plus guild, party/raid, whispers and channels as before. The game's chat window stays unchanged. Secret values are skipped. The settings sub-tabs are slightly narrower (140 instead of 160 pixels) so all eight fit the window. Test: `texlua tests/bubbles_test.lua`.

**0.15.1 DE:** Kanäle-Reiter: Die Teilnehmerlisten, die wir für den Reiter abfragen, erscheinen nicht mehr im Chat. Während einer Abfrage sind die Chatfenster vom Ereignis `CHAT_MSG_CHANNEL_LIST` abgemeldet und danach wieder angemeldet (kein Filter, kein Taint). Test: `tests/channels_mute_test.lua`. Manuelles `/chatlist` während einer Abfrage (wenige Sekunden) zeigt nichts.
**0.15.1 EN:** Channels tab: the member lists we query for the tab no longer appear in chat. While a query runs the chat frames are unregistered from `CHAT_MSG_CHANNEL_LIST` and registered again afterwards (no filter, no taint). Test: `tests/channels_mute_test.lua`. A manual `/chatlist` during a query (a few seconds) shows nothing.

## Interface: Greifen (0.15.0) · Interface: gryphons (0.15.0)
**DE:** Einstellungen → Interface → „Aktionsleiste: Greifen“ (`UI/Greifen.lua`). Ersetzt die Original-Greifen (Rahmen unter `MainActionBar` mit den Bildern `UI-HUD-ActionBar-Wyvern-Left/-Right`, gefunden über den Bildnamen) durch Bilder aus `Media/Greifen`. Je Seite: Bild (Dropdown mit Vorschau), Spiegeln, Größe 20–300 %, Versatz waagerecht/senkrecht (0/0 = deckungsgleich mit dem Original). Verschieben im Blizzard-HUD-Bearbeitungsmodus (grüne Felder, Mausrad = Größe) oder mit „Position ändern“. Neue Bilder: `.tga` (512×256 oder 256×128, mit Transparenz; PNG lädt der Client nicht) in `Media/Greifen` legen, den Namen in `Media/Greifen/Greifen.lua` eintragen, Spiel neu starten (WoW kann keinen Ordner auflisten). Mitgeliefert: `affen_greif`. Test: `tests/greifen_test.lua`. Im Spiel bestätigt (Ersetzen, Spiegeln, Bearbeitungsmodus).
**EN:** Settings → Interface → "Action bar: gryphons" (`UI/Greifen.lua`). Replaces the original gryphons (frames under `MainActionBar` with the images `UI-HUD-ActionBar-Wyvern-Left/-Right`, found by image name) with images from `Media/Greifen`. Per side: image (dropdown with preview), mirror, size 20–300 %, horizontal/vertical offset (0/0 = on top of the original). Move in Blizzard's HUD edit mode (green fields, mouse wheel = size) or with "Change position". New images: put a `.tga` (512×256 or 256×128, with transparency; the client cannot load PNG) into `Media/Greifen`, add the name to `Media/Greifen/Greifen.lua`, restart the game (WoW cannot list a folder). Included: `affen_greif`. Test: `tests/greifen_test.lua`. Confirmed in game (replace, mirror, edit mode).

**0.14.0 DE:** Datennetz scharf (Auslastungstest): `Core/WhisperSend.lua` schickt den **gesamten eigenen Codex-Stand** (nur die ohnehin teilbaren, bereinigten Datensätze – keine Gildendaten, kein Gold, keine Taschen, keine Post, kein Chat, keine Namen anderer Spieler) unsichtbar per Flüstern an „Pinky Freewood“, ersatzweise „Dr Freewood“, danach alle 24 Stunden erneut. Standard AN, abschaltbar unter Einstellungen → „Daten an den Entwickler senden“ (`settings.whisperSend`). Ablauf: Hallo → „bereit“ → Stücke `P|id|i|n|Teil` (ca. 4 je Sekunde) → Quittung je Paket, Wiederholung bei Zeitüberschreitung. Offline-Empfänger: die gelbe Systemzeile wird ausgeblendet, 10 Minuten Pause, dann der nächste. Ein „Stopp“ des Empfängers pausiert das Senden 24 Stunden. Nicht im Kampf, 60–180 Sekunden nach dem Anmelden. Test: `tests/whisper_net_test.lua`.
**0.14.0 EN:** Data net armed (load test): `Core/WhisperSend.lua` sends the **whole own Codex state** (only the records that are shareable anyway, sanitised – no guild data, gold, bags, mail, chat or other players' names) invisibly by whisper to "Pinky Freewood", fallback "Dr Freewood", then again every 24 hours. Default ON, can be turned off in Settings → "Send data to the developer" (`settings.whisperSend`). Flow: hello → "ready" → pieces `P|id|i|n|piece` (about 4 per second) → ack per packet, retry on timeout. Offline recipient: the yellow system line is hidden, 10 minutes pause, then the next one. A "stop" from the recipient pauses sending for 24 hours. Never in combat, 60–180 seconds after login. Test: `tests/whisper_net_test.lua`.
