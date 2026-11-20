-- Test der Quest-Sortierung (texlua tests/questsort_test.lua)
local fails, checks = 0, 0
local function eq(a, b, m) checks = checks + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end

local function Proxy()
    return setmetatable({}, { __index = function() return function() return Proxy() end end })
end
local logged, handlers, tabs = {}, {}, {}
_G.hooksecurefunc = function(n, fn) logged[n] = fn end
_G.QuestLogQuests_Update = function() end
local timers, tickers = {}, {}
_G.C_Timer = { After = function(sec, fn) timers[#timers + 1] = { sec, fn } end, NewTicker = function(sec, fn) tickers[#tickers + 1] = fn; return {} end }
_G.CreateFrame = function() return Proxy() end
local menus = {}
_G.Menu = { ModifyMenu = function(tag, fn) menus[tag] = fn end }
-- Questdaten
local data = {
    [1] = { level = 12, title = "Charlie", progress = 0.5, dist = 300 },
    [2] = { level = 8,  title = "alpha",   progress = 1,   dist = 100 },
    [3] = { level = 20, title = "Bravo",   progress = 0,   dist = 50 },
    [4] = { level = 8,  title = "Delta",   progress = 0.25, dist = 900 },
}
_G.C_QuestLog = {
    GetLogIndexForQuestID = function(id) return id end,
    GetInfo = function(i) return data[i] and { level = data[i].level, title = data[i].title } end,
    IsComplete = function(id) return data[id].progress == 1 end,
    GetQuestObjectives = function(id) return { { numRequired = 4, numFulfilled = data[id].progress * 4 } } end,
    GetDistanceSqToQuest = function(id) return data[id].dist end,
}
local ev = {}
local UI = setmetatable({ RegisterSettingsSection = function(_, id, def) tabs[id] = def end, CreateSection = function() return Proxy(), { Add = function() end } end },
    { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    RegisterEvent = function(_, e, f) ev[e] = f end, On = function(_, e, f) handlers[e] = f end, Fire = function() end }
assert(loadfile("UI/QuestSort.lua"))("Freewood-Core", FW)
local QS = FW.QuestSort

local function Items()
    local t = {}
    for i = 1, 4 do t[i] = { id = i, title = data[i].title, level = data[i].level, pos = i } end
    return t
end
local function Ids(t) local s = {} for _, it in ipairs(t) do s[#s + 1] = it.id end return table.concat(s, ",") end
eq(Ids(QS.SortItems(Items(), "default")), "1,2,3,4", "Standard unveraendert")
eq(Ids(QS.SortItems(Items(), "levelAsc")), "2,4,1,3", "Stufe aufsteigend (Gleichstand nach Name)")
eq(Ids(QS.SortItems(Items(), "levelDesc")), "3,1,2,4", "Stufe absteigend")
eq(Ids(QS.SortItems(Items(), "nameAsc")), "2,3,1,4", "Name A-Z (ohne Gross/Klein)")
eq(Ids(QS.SortItems(Items(), "nameDesc")), "4,1,3,2", "Name Z-A")
eq(Ids(QS.SortItems(Items(), "progress")), "2,1,4,3", "Fortschritt: fast fertig zuerst")
eq(Ids(QS.SortItems(Items(), "distance")), "3,2,1,4", "Entfernung: naechste zuerst")

-- Questlog: nur Quests direkt hinter normaler Ueberschrift, Plaetze bleiben
local function F(li, pad, id) return { layoutIndex = li, topPadding = pad, questID = id, info = { questID = id, title = data[id] and data[id].title, level = data[id] and data[id].level } } end
local h1, q1, q2, q3 = { layoutIndex = 3 }, F(4, 2, 1), F(5, -3, 2), F(6, -3, 3)
local camp, cq1, cq2 = { layoutIndex = 1 }, F(2, -6, 4), F(7, 0, 4)
local entries = {
    { kind = "quest", frame = q3 }, { kind = "header", frame = h1 }, { kind = "quest", frame = q1 },
    { kind = "boundary", frame = camp }, { kind = "quest", frame = cq1 }, { kind = "quest", frame = q2 },
}
eq(QS.ArrangeLog(entries, "default"), false, "Standard: nichts")
eq(QS.ArrangeLog(entries, "levelAsc"), true, "Stufe auf: geaendert")
eq(q2.layoutIndex, 4, "niedrigste Stufe auf den ersten Platz"); eq(q2.topPadding, 2, "erster Platz behaelt Abstand zur Ueberschrift")
eq(q1.layoutIndex, 5, "mittlere Stufe"); eq(q1.topPadding, -3, "Abstand Quest-Quest")
eq(q3.layoutIndex, 6, "hoechste Stufe zuletzt")
eq(cq1.layoutIndex, 2, "Kampagnen-Quest unveraendert")
-- einzelne Quest unter Ueberschrift: nichts zu tun
local solo = { { kind = "header", frame = { layoutIndex = 1 } }, { kind = "quest", frame = F(2, 2, 1) } }
eq(QS.ArrangeLog(solo, "levelAsc"), false, "eine Quest: keine Aenderung")

-- Beobachtungsliste: Aufrufer vorn, Rest sortiert
local function Q(id, special)
    return { quest = { GetID = function() return id end, title = data[id].title, IsCalling = function() return special == true end } }
end
local infos = { Q(1), Q(3, true), Q(2), Q(4) }
local out = QS.SortWatchInfos(infos, "levelAsc")
local ids = {}
for _, i in ipairs(out) do ids[#ids + 1] = i.quest:GetID() end
eq(table.concat(ids, ","), "3,2,4,1", "Verfolgung: Calling zuerst, Rest nach Stufe")
eq(QS.SortWatchInfos(infos, "default"), infos, "Standard: gleiche Liste")

-- Einrichtung
eq(QS.Opts().enabled, true, "Standard an"); eq(QS.Opts().log, "default", "Standard Log"); eq(QS.Opts().tracker, "default", "Standard Verfolgung")
local tr = { Header = Proxy(), MarkDirty = function() end }
local orig = function() return { Q(1), Q(2), Q(4) } end
tr.BuildQuestWatchInfos = orig
_G.QuestObjectiveTracker = tr
QS.Setup()
eq(type(logged.QuestLogQuests_Update), "function", "Log-Hook gesetzt")
eq(type(menus.MENU_QUEST_MAP_FRAME_SETTINGS), "function", "Menue-Erweiterung gesetzt")
eq(tr.BuildQuestWatchInfos ~= orig, true, "Verfolgung ueberschrieben")
local function Wid(l) local s = {} for _, i in ipairs(l) do s[#s + 1] = i.quest:GetID() end return table.concat(s, ",") end
eq(Wid(tr.BuildQuestWatchInfos(tr)), "1,2,4", "Standard: Blizzard-Reihenfolge")
QS.Opts().tracker = "levelDesc"
eq(Wid(tr.BuildQuestWatchInfos(tr)), "1,2,4", "Stufe ab: 12, 8(alpha), 8(Delta)")
QS.Opts().tracker = "nameDesc"
eq(Wid(tr.BuildQuestWatchInfos(tr)), "4,1,2", "Name Z-A")
QS.Opts().enabled = false
eq(Wid(tr.BuildQuestWatchInfos(tr)), "1,2,4", "aus: Blizzard-Reihenfolge")
-- Menue: Eintraege entstehen
local rows = {}
local root = setmetatable({}, { __index = function(_, k) return function(self, text, a, b) if k == "CreateRadio" then rows[#rows + 1] = text end return Proxy() end end })
QS.Opts().enabled = true
menus.MENU_QUEST_MAP_FRAME_SETTINGS(nil, root)
eq(#rows, 7, "7 Sortierungen im Menue")
eq(type(tabs.questsort.build(Proxy())), "table", "Einstellungsabschnitt gebaut")

-- Abgabe: waehrend der Abgabe-Animation (QS.settling) bleibt die letzte Reihenfolge
QS.Opts().enabled = true; QS.Opts().tracker = "nameAsc"
eq(Wid(tr.BuildQuestWatchInfos(tr)), "2,1,4", "Name A-Z (alpha, Charlie, Delta)")
QS.settling = true
QS.Opts().tracker = "nameDesc"   -- wuerde sonst anders sortieren
eq(Wid(tr.BuildQuestWatchInfos(tr)), "2,1,4", "waehrend der Abgabe: letzte Reihenfolge bleibt")
QS.settling = false
tr.numCachedBlocks = 1           -- stehen gebliebener Zwischenspeicher darf die Sortierung nicht mehr sperren
eq(Wid(tr.BuildQuestWatchInfos(tr)), "4,1,2", "danach neu sortiert (auch mit numCachedBlocks)")
tr.numCachedBlocks = 0
eq(Wid(QS.OrderByIds({ Q(4), Q(3), Q(2) }, { 2, 4 })), "2,4,3", "OrderByIds: unbekannte hinten")

-- Nach Abgabe/Entfernen: ein Neuaufbau nach 2,5 s (nur einer)
local before = #timers
ev.QUEST_TURNED_IN(); ev.QUEST_REMOVED()
eq(#timers - before, 1, "ein Neuaufbau geplant")
eq(timers[#timers][1], 2.5, "nach 2,5 s")
local dirty = 0
tr.MarkDirty = function() dirty = dirty + 1 end
timers[#timers][2]()
eq(dirty >= 1, true, "Neuaufbau macht den Tracker neu")
ev.QUEST_TURNED_IN()
eq(#timers - before, 2, "danach wieder planbar")
eq(QS.settling, true, "waehrend der Abgabe gesperrt")
timers[#timers][2]()
eq(QS.settling, false, "nach 2,5 s frei")

-- Entfernung: Ticker baut nur bei geaenderter Reihenfolge neu auf
eq(#tickers, 1, "Ticker gestartet")
QS.Opts().tracker = "distance"
tr.BuildQuestWatchInfos = nil
_G.QuestObjectiveTracker = tr
local infos2 = { Q(1), Q(2), Q(3), Q(4) }
local base = function() return { Q(1), Q(2), Q(3), Q(4) } end
tr.fwSortHooked = nil; tr.BuildQuestWatchInfos = base; tr.numCachedBlocks = 0
QS.Setup()
Wid(tr.BuildQuestWatchInfos(tr))
dirty = 0
eq(QS.DistanceTick(), false, "gleiche Reihenfolge: kein Neuaufbau")
data[1].dist = 10
eq(QS.DistanceTick(), true, "geaenderte Reihenfolge: Neuaufbau")
eq(dirty, 1, "Tracker neu angestossen")
QS.settling = true; data[4].dist = 1
eq(QS.DistanceTick(), false, "waehrend der Abgabe: nichts")
QS.settling = false
-- Entfernung: Freewood-Quest-Schaetzung (Sekunden) geht vor, Spiel-Wert wird in Sekunden umgerechnet
FW.QuestDistance = function(id) if id == 3 then return 5 end end
eq(QS.Distance(3), 5, "Sammelquest: Wert aus Freewood-Quest")
data[2].dist = 49 * 49
eq(QS.Distance(2), 7, "Spiel: 49 Yards = 7 Sekunden")
data[2].dist = nil
eq(QS.Distance(2), math.huge, "nichts bekannt: ganz hinten")
FW.QuestDistance = nil
QS.Opts().tracker = "default"
eq(QS.DistanceTick(), false, "andere Sortierung: nichts")
-- Questlog offen und nach Entfernung sortiert: Ticker ordnet neu
QS.Opts().log = "distance"
local visible = true
_G.QuestScrollFrame = {}
_G.QuestScrollFrame.IsVisible = function() return visible end
eq(QS.LogDistanceTick(), true, "Questlog offen: neu geordnet")
visible = false
eq(QS.LogDistanceTick(), false, "Questlog zu: nichts")
QS.Opts().log = "default"
-- 0.53.1: auf jede Quest-Aenderung reagieren
for _, e in ipairs(QS.CHANGE_EVENTS) do eq(type(ev[e]), "function", e .. " registriert") end
-- Fortschritt aus dem Text, wenn das Spiel keine Zahlen liefert
local oldObj = _G.C_QuestLog.GetQuestObjectives
_G.C_QuestLog.GetQuestObjectives = function(id)
    if id == 3 then return { { text = "Wolfsfleisch: 3/6" }, { text = "Rede mit Ogg'marr", finished = false } } end
    return oldObj(id)
end
eq(QS.Progress(3), 0.5, "Fortschritt aus Text 3/6")
_G.C_QuestLog.GetQuestObjectives = function(id)
    if id == 3 then return { { numRequired = 5, numFulfilled = 0, finished = true } } end
    return oldObj(id)
end
eq(QS.Progress(3), 1, "Ziel als erfuellt gemeldet zaehlt voll")
_G.C_QuestLog.GetQuestObjectives = oldObj
-- Fortschritt aendert die Reihenfolge der Questverfolgung: nach dem Ereignis wird neu aufgebaut
QS.settling = false
QS.Opts().enabled = true
QS.Opts().tracker = "progress"
local dirty = 0
tr.MarkDirty = function() dirty = dirty + 1 end
QS.CheckTracker()
dirty = 0
data[4].progress = 0.75
timers = {}
ev.QUEST_LOG_UPDATE()
eq(#timers, 1, "gebuendelt geplant")
ev.QUEST_LOG_UPDATE()
eq(#timers, 1, "nur einmal geplant")
timers[1][2]()
eq(dirty, 1, "neue Reihenfolge: Questverfolgung neu aufgebaut")
timers = {}
ev.QUEST_LOG_UPDATE(); timers[1][2]()
eq(dirty, 1, "nichts geaendert: kein Neuaufbau")
-- nur Spieler-Einheit
timers = {}
ev.UNIT_QUEST_LOG_CHANGED("party1")
eq(#timers, 0, "andere Einheit: nichts")
ev.UNIT_QUEST_LOG_CHANGED("player")
eq(#timers, 1, "eigene Einheit: pruefen")
-- Questlog offen, Sortierung Stufe: wird bei Aenderung geordnet
QS.Opts().log = "levelAsc"
_G.QuestScrollFrame = { IsVisible = function() return true end }
eq(QS.CheckLog(), true, "Questlog offen: geordnet")
QS.Opts().log = "default"
eq(QS.CheckLog(), false, "Standard: nichts")
QS.Opts().tracker = "default"
timers = {}
ev.QUEST_ACCEPTED()
eq(#timers, 0, "alles Standard: keine Arbeit")
print(checks .. " Pruefungen, " .. fails .. " Fehler")
