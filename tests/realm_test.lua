-- Test 0.57.0: Realmname ohne leeren Text, Merken, Erkennen, Zusammenfuehren (Notizen, Statistik)   texlua tests/realm_test.lua
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), modules = {} }
local printed = {}
function FW:Print(t) printed[#printed + 1] = t end
function FW:RegisterEvent() end function FW:On() end function FW:Fire() end
_G.Freewood = FW
local realm, norm = "Realm 8 PvP", "Realm8PvP"
_G.UnitName = function() return "Pinky" end
_G.GetRealmName = function() return realm end
_G.GetNormalizedRealmName = function() return norm end
assert(loadfile("Core/Util.lua"))("Freewood-Core", FW)
assert(loadfile("Core/Notes.lua"))("Freewood-Core", FW)
assert(loadfile("Stats/StatsData.lua"))("Freewood-Core", FW)
local U = FW.Util
FW.db = { modules = { Stats = { chars = {
    ["Pinky-Realm 8 PvP"] = { c = { kills = 10, maxMoney = 500 }, z = { a = 1 }, ach = { x = { l = 2, at = 1 } }, played = 100, first = 5, last = 50, info = { level = 30 } },
    ["Pinky-"] = { c = { kills = 4, maxMoney = 300 }, z = { b = 1 }, ach = { x = { l = 1, at = 9 }, y = { l = 1, at = 9 } }, played = 120, first = 60, last = 90, info = { level = 31 } },
} } }, notes = {
    ["Pinky - Realm 8 PvP"] = { notes = { { id = 1, title = "Alt" } }, todo = { { id = 2, text = "A" } }, seq = 2, pins = { n1 = { r = 1 } } },
    ["Pinky - "] = { notes = { { id = 1, title = "Neu" } }, todo = { { id = 2, text = "B" } }, seq = 2, pins = { n1 = { r = 0.5 }, todo = { r = 0 } } },
} }
-- 1. echter Name wird gemerkt
assert(U.RealmName() == "Realm 8 PvP" and FW.db.realmOf.Pinky == "Realm 8 PvP")
assert(U.NormalizedRealm() == "Realm8PvP")
-- 2. Spiel liefert "": gemerkter Name
realm, norm = "", ""
assert(U.RealmName() == "Realm 8 PvP", "gemerkt")
assert(FW.Notes.CharKey() == "Pinky - Realm 8 PvP" and FW.Stats.Key() == "Pinky-Realm 8 PvP", "Schluessel bleiben gleich")
-- 3. nichts gemerkt: aus den Daten erkannt
FW.db.realmOf = nil
assert(U.RealmName() == "Realm 8 PvP", "aus der Statistik erkannt")
-- 4. zusammenfuehren
local done = U.FixEmptyRealms()
assert(#done == 2, "Notizblock und Statistik: " .. #done)
local d = FW.db.notes["Pinky - Realm 8 PvP"]
assert(FW.db.notes["Pinky - "] == nil and #d.notes == 2 and d.notes[2].title == "Neu" and d.notes[2].id == 3, "Notiz mit neuer Nummer")
assert(#d.todo == 2 and d.todo[2].id == 4, "ToDo mit neuer Nummer")
assert(d.pins.n1.r == 1 and d.pins.n3.r == 0.5 and d.pins.todo, "Zettel ziehen mit")
local s = FW.db.modules.Stats.chars["Pinky-Realm 8 PvP"]
assert(FW.db.modules.Stats.chars["Pinky-"] == nil, "leerer Datensatz weg")
assert(s.c.kills == 14 and s.c.maxMoney == 500 and s.played == 120 and s.first == 5 and s.last == 90, "Zaehler")
assert(s.z.a and s.z.b and s.ach.x.l == 2 and s.ach.y, "Zonen und Erfolge")
assert(s.info.level == 31, "neuerer Zustand")
assert(printed[1] == "REALM_FIXED")
-- 5. ohne Realm gar nichts tun
FW.db.realmOf, FW.db.modules.Stats.chars, FW.db.notes = nil, {}, { ["Pinky - "] = { notes = {}, todo = {}, seq = 0 } }
assert(#U.FixEmptyRealms() == 0 and FW.db.notes["Pinky - "], "ohne bekannten Realm unveraendert")
-- 6. MergeNewer / FixEmptyRealmEntry
realm = "Realm 8 PvP"
local t = { ["Pinky-Realm 8 PvP"] = { a = 1, sub = { x = 1 } }, ["Pinky-"] = { a = 2, sub = { y = 2 }, b = 3 } }
assert(U.FixEmptyRealmEntry(t, "-", U.RealmName()) and t["Pinky-"] == nil)
assert(t["Pinky-Realm 8 PvP"].a == 2 and t["Pinky-Realm 8 PvP"].sub.x == 1 and t["Pinky-Realm 8 PvP"].sub.y == 2 and t["Pinky-Realm 8 PvP"].b == 3)
print("realm_test: ok")
