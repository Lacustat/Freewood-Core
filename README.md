# Freewood Core

**English · Deutsch** — Author: Lacustat · Version 0.69.0 · Interface 16001 (World of Warcraft: Forever)

## Contents · Inhalt
- [English](#english)
  - [What is Freewood Core?](#what-is-freewood-core)
  - [Main window and settings](#main-window-and-settings)
  - [Full-screen character view](#full-screen-character-view)
  - [Equipment by event](#equipment-by-event)
  - [Chat, channels and whispers](#chat-channels-and-whispers)
  - [Auto reply](#auto-reply)
  - [Notepad and sticky notes](#notepad-and-sticky-notes)
  - [Statistics and achievements](#statistics-and-achievements)
  - [More helpers](#more-helpers)
  - [Commands and key bindings](#commands-and-key-bindings)
  - [Installation and notes](#installation-and-notes)
- [Deutsch](#deutsch)
  - [Was ist Freewood Core?](#was-ist-freewood-core)
  - [Hauptfenster und Einstellungen](#hauptfenster-und-einstellungen)
  - [Charakteransicht im Vollbild](#charakteransicht-im-vollbild)
  - [Ausrüstung nach Ereignis](#ausrüstung-nach-ereignis)
  - [Chat, Kanäle und Flüstern](#chat-kanäle-und-flüstern)
  - [Auto-Antwort](#auto-antwort)
  - [Notizblock und Zettel](#notizblock-und-zettel)
  - [Statistik und Erfolge](#statistik-und-erfolge)
  - [Weitere Helfer](#weitere-helfer)
  - [Befehle und Tastenbelegung](#befehle-und-tastenbelegung)
  - [Installation und Hinweise](#installation-und-hinweise)
- [Changelog · Änderungen](CHANGELOG.md)

---

## English

### What is Freewood Core?
Freewood Core is the foundation of the Freewood addon family for World of Warcraft: Forever. It brings the main window with its tabs, the settings, data storage, the shared UI building blocks and a lot of everyday features of its own. Every other Freewood module needs Core; each module simply adds its own tab.

### Main window and settings
- One window for all Freewood modules, one tab per module. A missing module only removes its tab.
- Window size from 50 to 150 %, tabs can be arranged, minimap button.
- Settings for all modules in one place; modules can also show their settings directly in their own tab ("Settings" button at the top right).
- Designs and colours, including the "Legion der Affen" skin, custom fonts and the gryphons at the action bar.
- Profiles for settings, German and English interface.
- Explanations sit behind a small golden "i" so the windows stay tidy.
- Exchange: export data (for example beasts or rules) as a text code and import it on another player's game.

### Full-screen character view
- A hand-painted full-screen character window that fits every screen format (16:9, 21:9 …).
- Left: name plate, 3D model in front of a background that matches your race (rotate by dragging, zoom with the wheel), all equipment slots with tooltips, drag and drop, shift-click links and quality glow.
- Middle: all stats of your character, the sections relevant for your class first (ranged, melee, spells, defence, resistances).
- Right: all your bags in one grid, sorted into categories (equipment, consumables, trade goods, recipes, quest, misc, junk, free slots), each foldable and sortable. Quiver, ammo pouch, soul bag and reagent bag get their own sections. Search box and gold display.
- Use, move and sell items straight from the view, just like in Blizzard's bags.
- Frame chosen to fit your race or class (or "Pinky" for everyone), background selectable (dark leather, parchment, red leather, classic leather).
- Opens via the Freewood tab on Blizzard's character window, its own key, or optionally instead of the C key.

### Equipment by event
Put on gear automatically when something happens, and switch back when it ends:
- Events: swimming, mounted, fishing (by key or command), dungeon, raid, battleground, arena, combat, city or inn, a chosen zone, druid form or warrior stance, group, raid group.
- Assign a Freewood profile, a Blizzard equipment set or a single item. Profiles can hold only some slots (for example just belt and boots).
- Several rules at once: the rule higher in the list wins per slot.
- When the event ends, the next active rule applies, otherwise your standard gear: either a fixed profile or "whatever I wore last without an event".
- In combat only weapons, shield/off-hand and ranged change (Blizzard rule); the rest follows after combat.
- Optional chat message on each change. Available as a tab and inside the character view (Blizzard style).

### Chat, channels and whispers
- Channels tab: all channels in categories (Forever standard, guild, group, whispers, custom), chat in the middle, member list with search on the right. History of up to 7 days.
- Optional own chat window with bubbles, class icons, level and time, or a classic line view. Freely arranged tabs.
- Small whisper windows (off by default), Battle.net whispers included.
- Loot roll window: who rolled need, greed or passed, with the number, and who won.

### Auto reply
Rules that answer or react for you:
- 15 triggers: chat message, buff from another player, friend or guild member online, item won, your level-up, level-up in the guild or nearby, group invite, trade or duel request, resurrected, someone joins group or guild, boss defeated.
- Word filter with AND/OR, conditions (AFK, DND, group, raid, combat, instance, guild member, friend …), time window, class filter.
- Answer in the same chat, by whisper, to guild or group, with random variants and placeholders like {name} or {zone}; or play one of 42 voice emotes.
- Pauses per rule and per player, ignore after too many messages (with 20 s to cancel), help to report a player, history of the last 100 answers, 12 ready-made templates, export/import.
- Safety built in: never answers yourself or GMs, at most 6 answers per minute, paused automatically in battlegrounds and arenas.

### Notepad and sticky notes
- Notes and to-do lists, also for your other characters; link items, creatures and quests.
- Pin notes to the screen as sticky notes (movable, resizable, coloured, optionally hidden in combat).
- Available as its own window (own key) and as the "Notes" tab.

### Statistics and achievements
- Statistics per character and for the whole account: values, combat, experience, gold by source, loot, travel (on foot, mounted, swimming, flying), quests, reputation, professions, deaths, kills and more.
- Freewood achievements with medals, titles to choose (shown in the chat) and a notice when you earn a new tier.

### More helpers
- Quest tracker sorting (by level, zone or proximity) and quest glow.
- Watch window for recipes with materials and live bag counts.
- Extended tooltips.
- Pet experience bar for hunters: small, movable (Shift + drag), size adjustable, hidden once your pet has reached your level; settings under Classes > Hunter > Pet controller.
- Small animations (for example when mail arrives).

### Commands and key bindings
- `/fw` or `/freewood` – open the window (`/fw settings`, `/fw exchange`, `/fw minimap`, `/fw reset`, `/fw modules`)
- `/fwnotes` – notepad · `/fwwatch` – watch window · `/fwchat` – chat window · `/fwroll` – roll window
- `/fwgear` – equipment by event, `/fwgear fish` toggles fishing
- `/fwerfolge` – achievements · `/fwpetxp` – pet experience bar on/off (`/fwpetxp reset` = centre)
- `/fwnet` – state of the Freewood network (hidden channel, who is online; switch: settings, "Exchange data with other Freewood players")
- Key bindings (Key Bindings > Freewood): Freewood window, channels, overview, exchange, settings, notepad, character view, fishing on/off.

### Installation and notes
- Copy the folder `Freewood-Core` into `World of Warcraft\_forever_\Interface\AddOns\`.
- New files are only loaded after a full game restart; `/reload` is enough for changed files.
- Data is saved per account and per character (`FreewoodDB`, `FreewoodCharDB`).
- Made for World of Warcraft: Forever. Licence: GPL-3.0. All artwork in the character view is the author's own.

---

## Deutsch

### Was ist Freewood Core?
Freewood Core ist die Grundlage der Freewood-Addons für World of Warcraft: Forever. Es bringt das Hauptfenster mit seinen Reitern, die Einstellungen, den Datenspeicher, die gemeinsamen Bausteine der Oberfläche und viele eigene Alltagsfunktionen mit. Jedes andere Freewood-Modul braucht Core; jedes Modul fügt einfach seinen eigenen Reiter hinzu.

### Hauptfenster und Einstellungen
- Ein Fenster für alle Freewood-Module, ein Reiter je Modul. Fehlt ein Modul, fehlt nur sein Reiter.
- Fenstergröße von 50 bis 150 %, Reiter frei ordnen, Minimap-Knopf.
- Einstellungen aller Module an einer Stelle; Module können ihre Einstellungen auch direkt im eigenen Reiter zeigen (Knopf „Einstellungen“ oben rechts).
- Designs und Farben, darunter das Design „Legion der Affen“, eigene Schriften und die Greifen an der Aktionsleiste.
- Profile für die Einstellungen, Oberfläche auf Deutsch und Englisch.
- Erklärungen stecken hinter einem kleinen goldenen „i“, damit die Fenster aufgeräumt bleiben.
- Austausch: Daten (zum Beispiel Wildtiere oder Regeln) als Text-Code exportieren und bei einem anderen Spieler importieren.

### Charakteransicht im Vollbild
- Ein handgemaltes Charakterfenster im Vollbild, das zu jedem Bildschirmformat passt (16:9, 21:9 …).
- Links: Namensplakette, 3D-Modell vor einem Hintergrund passend zu deiner Rasse (drehen durch Ziehen, Zoom mit dem Mausrad), alle Ausrüstungsplätze mit Tooltip, Ziehen und Ablegen, Shift-Klick-Link und Qualitätsleuchten.
- Mitte: alle Werte deines Charakters, die für deine Klasse wichtigen Abschnitte zuerst (Fernkampf, Nahkampf, Zauber, Verteidigung, Widerstände).
- Rechts: alle Taschen in einem Raster, in Kategorien sortiert (Ausrüstung, Verbrauchbar, Handwerk, Rezepte, Quest, Sonstiges, Müll, freie Plätze), jede einklappbar und sortierbar. Köcher, Munitionsbeutel, Seelentasche und Reagenzientasche haben eigene Abschnitte. Suchfeld und Goldanzeige.
- Gegenstände direkt aus der Ansicht benutzen, verschieben und verkaufen, genau wie in Blizzards Taschen.
- Rahmen passend zu deiner Rasse oder Klasse (oder „Pinky“ für alle), Hintergrund wählbar (dunkles Leder, Pergament, rotes Leder, Leder klassisch).
- Öffnet über den Freewood-Reiter am Blizzard-Charakterfenster, über eine eigene Taste oder auf Wunsch statt der Taste C.

### Ausrüstung nach Ereignis
Ausrüstung automatisch anziehen, wenn etwas passiert, und zurückwechseln, wenn es vorbei ist:
- Ereignisse: Schwimmen, Reiten, Angeln (per Taste oder Befehl), Dungeon, Schlachtzug, Schlachtfeld, Arena, Kampf, Stadt oder Gasthaus, eine gewählte Zone, Druidengestalt oder Kriegerhaltung, Gruppe, Schlachtzugsgruppe.
- Zuordnen lässt sich ein Freewood-Profil, ein Blizzard-Ausrüstungsset oder ein einzelner Gegenstand. Profile können nur einzelne Plätze enthalten (zum Beispiel nur Gürtel und Stiefel).
- Mehrere Regeln gleichzeitig: Die Regel weiter oben in der Liste gewinnt je Platz.
- Endet das Ereignis, gilt die nächste aktive Regel, sonst deine Standard-Ausrüstung: entweder ein festes Profil oder „was ich zuletzt ohne Ereignis trug“.
- Im Kampf wechseln nur Waffen, Schild/Nebenhand und Fernkampf (Blizzard-Regel); der Rest folgt nach dem Kampf.
- Auf Wunsch eine Meldung im Chat bei jedem Wechsel. Als Reiter und in der Charakteransicht (im Blizzard-Stil).

### Chat, Kanäle und Flüstern
- Reiter „Kanäle“: alle Kanäle in Kategorien (Forever-Standard, Gilde, Gruppe, Flüstern, eigene), Chat in der Mitte, Mitgliederliste mit Suche rechts. Verlauf bis 7 Tage.
- Auf Wunsch ein eigenes Chatfenster mit Blasen, Klassensymbol, Stufe und Uhrzeit oder eine klassische Zeilenansicht. Reiter frei einrichten.
- Kleine Flüsterfenster (standardmäßig aus), auch für Battle.net-Flüstern.
- Würfelfenster: wer Bedarf, Gier oder Passen gewürfelt hat, mit der Zahl, und wer gewonnen hat.

### Auto-Antwort
Regeln, die für dich antworten oder reagieren:
- 15 Auslöser: Chatnachricht, Buff von einem anderen Spieler, Freund oder Gildenmitglied online, Gegenstand gewonnen, dein Stufenaufstieg, Stufenaufstieg in der Gilde oder in der Nähe, Gruppeneinladung, Handels- oder Duellanfrage, wiederbelebt, jemand tritt Gruppe oder Gilde bei, Boss besiegt.
- Wortfilter mit UND/ODER, Bedingungen (AFK, DND, Gruppe, Schlachtzug, Kampf, Instanz, Gildenmitglied, Freund …), Zeitfenster, Klassenfilter.
- Antwort im selben Chat, per Flüstern, in Gilde oder Gruppe, mit zufälligen Varianten und Platzhaltern wie {name} oder {zone}; oder eines von 42 Sprach-Emotes.
- Pausen je Regel und je Spieler, Ignorieren nach zu vielen Nachrichten (mit 20 s zum Abbrechen), Hilfe beim Melden eines Spielers, Verlauf der letzten 100 Antworten, 12 fertige Vorlagen, Export/Import.
- Sicherheit eingebaut: antwortet nie dir selbst oder GMs, höchstens 6 Antworten pro Minute, auf Schlachtfeldern und in Arenen automatisch pausiert.

### Notizblock und Zettel
- Notizen und ToDo-Listen, auch für deine anderen Charaktere; Gegenstände, Kreaturen und Quests verknüpfen.
- Notizen als Zettel an den Bildschirm heften (verschiebbar, Größe änderbar, farbig, auf Wunsch im Kampf ausgeblendet).
- Als eigenes Fenster (eigene Taste) und als Reiter „Notizen“.

### Statistik und Erfolge
- Statistik je Charakter und für den ganzen Account: Werte, Kampf, Erfahrung, Gold nach Herkunft, Beute, Reisen (zu Fuß, beritten, schwimmend, fliegend), Quests, Ruf, Berufe, Tode, Kills und mehr.
- Freewood-Erfolge mit Medaillen, wählbaren Titeln (im Chat sichtbar) und einem Hinweis bei jeder neuen Stufe.

### Weitere Helfer
- Sortierung der Questverfolgung (nach Stufe, Zone oder Nähe) und Quest-Leuchten.
- Beobachten-Fenster für Rezepte mit Materialien und aktuellem Taschenbestand.
- Erweiterte Tooltips.
- Begleiter-Erfahrungsbalken für Jäger: klein, verschiebbar (Shift + ziehen), Größe einstellbar, unsichtbar, sobald dein Begleiter deine Stufe erreicht hat; Einstellungen unter Klassen > Jäger > Pet-Regler.
- Kleine Animationen (zum Beispiel bei neuer Post).

### Befehle und Tastenbelegung
- `/fw` oder `/freewood` – Fenster öffnen (`/fw settings`, `/fw exchange`, `/fw minimap`, `/fw reset`, `/fw modules`)
- `/fwnotiz` oder `/fwnotes` – Notizblock · `/fwbeobachten` oder `/fwwatch` – Beobachten-Fenster · `/fwchat` – Chatfenster · `/fwroll` – Würfelfenster
- `/fwgear` – Ausrüstung nach Ereignis, `/fwgear angeln` schaltet Angeln um
- `/fwerfolge` – Erfolge · `/fwpetxp` – Begleiter-Erfahrungsbalken an/aus (`/fwpetxp reset` = Mitte)
- `/fwnet` – Stand des Freewood-Netzes (verborgener Kanal, wer ist online; Schalter: Einstellungen, „Daten mit anderen Freewood-Spielern tauschen“)
- Tastenbelegung (Tastaturbelegung > Freewood): Freewood-Fenster, Kanäle, Übersicht, Austausch, Einstellungen, Notizblock, Charakteransicht, Angeln an/aus.

### Installation und Hinweise
- Den Ordner `Freewood-Core` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren.
- Neue Dateien lädt das Spiel erst nach einem kompletten Neustart; bei geänderten Dateien reicht `/reload`.
- Daten werden je Account und je Charakter gespeichert (`FreewoodDB`, `FreewoodCharDB`).
- Gemacht für World of Warcraft: Forever. Lizenz: GPL-3.0. Alle Grafiken der Charakteransicht sind eigene Werke des Autors.
