-- Test der Standortabfrage zwischen Fluesterpartnern (texlua tests/whisper_loc_test.lua)
local fails, n = 0, 0
local function eq(a, b, msg) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. msg .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end

local clock, sent = 0, {}
_G.GetTime = function() return clock end
_G.time = function() return 1000000 + math.floor(clock) end
_G.date = os.date
_G.GetUnitName = function() return "Bob Test" end
_G.Enum = { SendAddonMessageResult = { Success = 0 } }
_G.C_Timer = { After = function() end }
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, text, ch, to) sent[#sent + 1] = { text = text, to = to } return 0 end,
}
local pos = { GetXY = function() return 0.4321, 0.8765 end }
_G.C_Map = {
    GetBestMapForUnit = function() return 1411 end,
    GetPlayerMapPosition = function() return pos end,
    GetMapInfo = function() return { name = "Durotar" } end,
}
_G.UnitExists = function() return false end

local events, handlers = {}, {}
local FW = { version = "test", db = {}, settings = {}, Print = function() end, ChatLog = { guild = { { name = "Gildi", zone = "Orgrimmar" } } } }
function FW:On(ev, fn) handlers[ev] = handlers[ev] or {}; table.insert(handlers[ev], fn) end
function FW:Fire(ev, ...) for _, fn in ipairs(handlers[ev] or {}) do fn(...) end end
function FW:RegisterEvent(ev, fn) events[ev] = events[ev] or {}; table.insert(events[ev], fn) end
assert(loadfile("Core/Whisper.lua"))("Freewood-Core", FW)
local W = FW.Whisper
local function Recv(text, from) for _, fn in ipairs(events.CHAT_MSG_ADDON) do fn("FWWH1", text, "WHISPER", from) end end

-- eigene Position
local m, x, y, zone = W.MyLocation()
eq(m, 1411, "mapID"); eq(zone, "Durotar", "Gebiet"); eq(math.floor(x * 1000), 432, "x")

-- Fremder, dem ich nie gefluestert habe: keine Antwort
Recv("L|1", "Fremder")
eq(#sent, 0, "keine Antwort an Fremde")
-- Ich habe ihm gefluestert: Antwort
W.NoteTalked("Freund-Quelthalas")
Recv("L|1", "Freund-Quelthalas")
eq(#sent, 1, "Antwort an Gefluesterten")
eq(sent[1].text, "M|1411|432|877|Durotar", "Antwort: Karte, x, y, Gebiet")
-- Gildenmitglied
Recv("L|1", "Gildi")
eq(#sent, 2, "Antwort an Gilde")
-- ausgeschaltet
FW.settings.shareLocation = false
Recv("L|1", "Freund")
eq(#sent, 2, "aus: keine Antwort")
FW.settings.shareLocation = nil

-- Anfrage: hoechstens alle 20 s
sent = {}
eq(W.RequestLocation("Freund"), true, "Anfrage gesendet")
eq(sent[1].text, "L|1", "Anfragetext")
eq(W.RequestLocation("Freund"), false, "innerhalb 20 s nicht nochmal")
clock = 21
eq(W.RequestLocation("Freund"), true, "nach 20 s wieder")

-- Antwort empfangen
local got
FW:On("WHISPER_LOCATION", function(sender, rec) got = rec end)
Recv("M|1411|432|877|Durotar", "Freund-Quelthalas")
eq(got and got.m, 1411, "Antwort: Karte"); eq(got and got.zone, "Durotar", "Antwort: Gebiet")
local r = W.GetLocation("Freund-Quelthalas")
eq(r and math.floor(r.x * 1000 + 0.5), 432, "gespeichert x")
eq(W.GetLocation("Freund") ~= nil, true, "auch unter dem kurzen Namen")
clock = 300
eq(W.GetLocation("Freund"), nil, "nach 120 s veraltet")
-- Muell
Recv("M|abc|1|2|x", "Freund"); Recv("M|1|5000|2|x", "Freund")
clock = 301
eq(W.GetLocation("Freund"), nil, "ungueltige Antworten werden verworfen")

print(n .. " Pruefungen, " .. fails .. " Fehler")
