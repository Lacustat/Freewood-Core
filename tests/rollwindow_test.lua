-- Test Wuerfelfenster: Auswertung der Spiel-Meldungen, Sortierung, Handwuerfe (texlua tests/rollwindow_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function Proxy() return setmetatable({}, { __index = function() return function() return Proxy() end end }) end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.UnitName = function() return "Pinky" end
local now, group = 100, true
_G.GetTime = function() return now end
_G.IsInGroup = function() return group end
local UI = setmetatable({}, { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    AddLocale = function() end, RegisterEvent = function() end, Util = { IsSecret = function() return false end } }
-- deutsche Vorlagen des Spiels
_G.LOOT_ROLL_ROLLED_NEED = "Wurf für eigenen Bedarf: %d für %s von %s"
_G.LOOT_ROLL_ROLLED_GREED = "Wurf für Gier: %d für %s von %s"
_G.LOOT_ROLL_NEED = "%s hat Bedarf ausgewählt für: %s"
_G.LOOT_ROLL_GREED_SELF = "Ihr habt \"Gier\" ausgewählt für: %s"
_G.LOOT_ROLL_WON = "Gewonnen von %s: %s"
_G.LOOT_ROLL_YOU_WON = "Ihr habt gewonnen: %s"
_G.LOOT_ROLL_ALL_PASSED = "Alle haben gepasst bei: %s"
_G.LOOT_ROLL_PASSED = "%s hat gepasst bei: %s"
_G.RANDOM_ROLL_RESULT = "%s würfelt. Ergebnis: %d (%d-%d)"
assert(loadfile("UI/RollWindow.lua"))("Freewood-Core", FW)
local R = FW.RollWindow
R.noUI = true

local link = "|cff0070dd|Hitem:2589:0:0:0:0:0:0:0|h[Schleimüberzogene Polster]|h|r"
local link2 = "|cffffffff|Hitem:2592:0:0:0:0:0:0:0|h[Wollstoff]|h|r"
eq(R.Feed("Wurf für eigenen Bedarf: 62 für " .. link .. " von Ruufy Pesthauch"), "loot", "Bedarfswurf erkannt")
eq(R.Feed("Wurf für Gier: 80 für " .. link .. " von Anna"), "loot", "Gierwurf erkannt")
eq(R.Feed("Wurf für eigenen Bedarf: 10 für " .. link .. " von Bert"), "loot", "zweiter Bedarf")
eq(#R.items, 1, "ein Gegenstand")
local rows = R.LootRows()
eq(#rows, 3, "drei Zeilen")
eq(rows[1].roll.player, "Ruufy Pesthauch", "Bedarf hoechster zuerst")
eq(rows[2].roll.player, "Bert", "Bedarf zweiter")
eq(rows[3].roll.player, "Anna", "Gier zuletzt, obwohl 80 hoeher")
eq(R.Feed("Wurf für eigenen Bedarf: 10 für " .. link .. " von Bert"), nil, "Doppelmeldung nur einmal")
eq(R.Feed("Gewonnen von Ruufy Pesthauch: " .. link), "loot", "Gewinner")
eq(R.items[1].winner, "Ruufy Pesthauch", "Gewinner gesetzt")
eq(R.LootRows()[1].winner, true, "Gewinnerzeile")
-- eigene Wahl
eq(R.Feed("Ihr habt \"Gier\" ausgewählt für: " .. link2), "loot", "eigene Wahl")
eq(R.items[2].rolls["Pinky"].kind, "greed", "eigener Name und Art")
eq(R.LootRows()[4].item.key, R.items[2].key, "Gegenstand ohne Wurf folgt")
R.Feed("Cora hat Bedarf ausgewählt für: " .. link2)
eq(R.items[2].rolls["Cora"].kind, "need", "Wahl anderer")
eq(R.Feed("Alle haben gepasst bei: " .. link2), "loot", "alle gepasst")
eq(R.items[2].doneAt ~= nil, true, "erledigt")
R.Feed("Dino hat gepasst bei: " .. link2); eq(R.items[2].passes, 1, "gepasst gezaehlt")
-- aufraeumen
now = 100 + 30
eq(R.Prune(), true, "erledigte verschwinden"); eq(#R.items, 0, "Liste leer")
-- Handwuerfe
R.Reset()
eq(R.Feed("Anna würfelt. Ergebnis: 45 (1-100)"), "hand", "Handwurf")
R.Feed("Bert würfelt. Ergebnis: 77 (1-100)")
R.Feed("Cid würfelt. Ergebnis: 45 (1-100)")
local list = R.HandSorted()
eq(#list, 3, "drei Handwuerfe"); eq(list[1].player, "Bert", "Bester oben"); eq(list[2].player, "Anna", "Gleichstand: wer zuerst wuerfelte")
now = now + 1
R.Feed("Anna würfelt. Ergebnis: 99 (1-100)")
eq(R.HandSorted()[1].player, "Anna", "neuer Wurf ersetzt den alten"); eq(#R.HandSorted(), 3, "weiter drei")
now = now + 60
R.Feed("Dora würfelt. Ergebnis: 5 (1-20)")
list = R.HandSorted(); eq(#list, 1, "neue Runde nach Pause"); eq(R.hand.hi, 20, "Bereich der Runde")
-- nicht in der Gruppe: kein Handwurf-Fenster
group = false; R.Reset()
R.Feed("Eva würfelt. Ergebnis: 3 (1-100)"); eq(#R.HandSorted(), 0, "ohne Gruppe nichts")
-- englische Vorlage, Farbcodes
group = true
_G.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"; R.ResetPatterns(); R.Reset()
eq(R.Feed("|cffffff00Fay rolls 12 (1-100)|r"), "hand", "englisch mit Farbe")
eq(R.Feed("Hallo Welt"), nil, "normaler Text")
-- Oberflaeche mit Attrappen bauen (Beispielansicht): darf keinen Fehler werfen
R.noUI = false; R.Reset()
_G.GameTooltip = Proxy()
_G.UIParent = Proxy()
R.Demo()
eq(R.lastError, nil, "Beispielansicht ohne Fehler")
eq(#R.LootRows() >= 5, true, "Beispielzeilen")
R.Opts().loot = false; R.Update(); eq(R.lastError, nil, "abgeschaltet ohne Fehler")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
