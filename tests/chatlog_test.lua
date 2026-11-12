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
local printed = {}
local hooks = {}
_G.SendChatMessage = function() end
_G.hooksecurefunc = function(name, fn) hooks[name] = fn end
local inGroup, instGroup = false, false
_G.IsInGroup = function(cat) if cat then return instGroup end return inGroup end
_G.IsInRaid = function() return false end
local FW = { chardb = {}, RegisterEvent = function(_, e, f) events[e] = f end, Print = function(_, t) printed[#printed + 1] = t end }
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

-- Gruppe: Anfuehrer-Nachrichten, eigene Nachrichten beim Senden, Instanzchat
for _, ev in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
    eq(type(events[ev]), "function", ev .. " registriert")
end
eq(type(hooks.SendChatMessage), "function", "SendChatMessage abgegriffen")
eq(CL.IsMe("Ich"), true, "IsMe: Name"); eq(CL.IsMe("Ich-Steel"), true, "IsMe: mit Realm"); eq(CL.IsMe("Anna"), false, "IsMe: anderer")
local function GroupLines() return CL.Lines("group") or {} end
FW.chardb.chat = nil
_G.FreewoodDB.chatPlayers = {}
local before = #GroupLines()
-- nicht in einer Gruppe: nichts einfuegen
inGroup = false
local savedP1 = units.party1; units.party1 = nil
hooks.SendChatMessage("hallo", "PARTY")
eq(#GroupLines(), before, "ohne Gruppe: nichts eingefuegt")
units.party1 = savedP1
-- in einer Gruppe: sofort eingefuegt, Ereignis danach nicht doppelt
inGroup = true
hooks.SendChatMessage("hallo Gruppe", "PARTY")
eq(#GroupLines(), before + 1, "eigene Nachricht beim Senden eingefuegt")
eq(GroupLines()[before + 1].o, 1, "als eigene Nachricht")
events.CHAT_MSG_PARTY_LEADER("hallo Gruppe", "Ich-Steel")
eq(#GroupLines(), before + 1, "Ereignis mit gleichem Text nicht doppelt")
-- danach ein neues Ereignis mit gleichem Text wird normal gezeigt
events.CHAT_MSG_PARTY_LEADER("hallo Gruppe", "Ich-Steel")
eq(#GroupLines(), before + 2, "zweites Ereignis (kein Echo mehr offen) wird gezeigt")
eq(GroupLines()[before + 2].o, 1, "Ich mit Realm als eigene erkannt")
-- Nachricht eines anderen mit gleichem Text wird nie verschluckt
hooks.SendChatMessage("ja", "PARTY")
events.CHAT_MSG_PARTY("ja", "Igni Purgatorius")
eq(#GroupLines(), before + 4, "fremde Nachricht mit gleichem Text bleibt")
-- Raid, Instanzchat, Anfuehrer-Ereignis ohne Echo
events.CHAT_MSG_INSTANCE_CHAT("hi", "Igni Purgatorius")
eq(#GroupLines(), before + 5, "Instanzchat angekommen")
-- Kanal beim Senden
local sentType
_G.SendChatMessage = function(_, ct) sentType = ct end
CL.Send("group", nil, "x")
eq(sentType, "PARTY", "Gruppe: PARTY")
instGroup = true
CL.Send("group", nil, "x")
eq(sentType, "INSTANCE_CHAT", "Instanzgruppe: INSTANCE_CHAT")
instGroup = false
-- Fehlersuche
CL.debug = true; printed = {}
events.CHAT_MSG_PARTY_LEADER("test", "Ich")
eq(#printed >= 1 and printed[1]:find("PARTY_LEADER", 1, true) ~= nil, true, "Fehlersuche meldet das Ereignis")
CL.debug = false
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
