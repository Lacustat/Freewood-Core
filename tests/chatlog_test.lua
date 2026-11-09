-- Test: Klasse und Stufe von Absendern herausfinden (texlua tests/chatlog_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, tostring(a), tostring(b)) end end
_G.FreewoodDB = {}
local units = {
    player = { name = "Ich", class = "WARRIOR", level = 60 },
    party1 = { name = "Igni Purgatorius", class = "MAGE", level = 23 },
    ["Nahe Spielerin"] = { name = "Nahe Spielerin", class = "PRIEST", level = 31 },
}
_G.UnitExists = function(u) return units[u] ~= nil end
_G.UnitIsPlayer = function() return true end
_G.UnitName = function(u) return units[u] and units[u].name end
_G.UnitClass = function(u) local x = units[u]; return x and x.class:lower(), x and x.class end
_G.UnitLevel = function(u) return units[u] and units[u].level end
_G.time = function() return 1000 end
_G.CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
local timers = {}
_G.C_Timer = { After = function(s, f) timers[#timers + 1] = f end }
local events = {}
local FW = { chardb = {}, RegisterEvent = function(_, e, f) events[e] = f end, Print = function() end }
FW.L = setmetatable({}, { __index = function(_, k) return k end })
assert(loadfile("Core/ChatLog.lua"))("Freewood-Core", FW)
local CL = FW.ChatLog

eq(CL.Info("Igni Purgatorius"), nil, "anfangs unbekannt")
CL.NoteByName("Igni Purgatorius")
local c, l = CL.Info("Igni Purgatorius")
eq(c, "MAGE", "Gruppenmitglied: Klasse"); eq(l, 23, "Gruppenmitglied: Stufe")
CL.NoteByName("Nahe Spielerin")
c, l = CL.Info("Nahe Spielerin"); eq(c, "PRIEST", "Spieler in der Naehe ueber den Namen"); eq(l, 31, "Stufe in der Naehe")
CL.NoteByName("Ich"); eq(select(1, CL.Info("Ich")), "WARRIOR", "eigene Figur")
CL.NoteByName("Unbekannt"); eq(CL.Info("Unbekannt"), nil, "Unbekannter bleibt leer")
CL.NoteByName(42); CL.NoteByName(nil)
-- beim Eintreffen einer Gruppennachricht wird nachgeschlagen
FW.chardb.chat = nil
_G.FreewoodDB.chatPlayers = {}
events.CHAT_MSG_PARTY("hallo", "Igni Purgatorius")
eq(select(1, CL.Info("Igni Purgatorius")), "MAGE", "Nachricht fuellt den Merker")
-- Gruppenwechsel: sofort und zweimal spaeter einlesen
timers = {}
events.GROUP_ROSTER_UPDATE()
eq(#timers, 2, "zwei spaetere Wiederholungen")
for _, f in ipairs(timers) do f() end
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
