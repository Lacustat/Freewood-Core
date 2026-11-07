-- Test: Kanalliste wird waehrend der Abfrage im Chat unsichtbar (Chatfenster abgemeldet) und danach wieder angemeldet (texlua tests/channels_mute_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end

local clock = 100
_G.GetTime = function() return clock end
_G.issecretvalue = nil
local onUpdate
_G.CreateFrame = function()
    local f = {}
    return setmetatable(f, { __index = function(t, k)
        if k == "SetScript" then return function(self, ev, fn) if ev == "OnUpdate" and not onUpdate then onUpdate = fn end end end
        return function() return f end
    end })
end
_G.NUM_CHAT_WINDOWS = 3
local registered = {}
for i = 1, 3 do
    local fr = { id = i }
    registered[fr] = (i ~= 3)       -- Fenster 3 hatte das Ereignis nie
    fr.IsEventRegistered = function(self, e) return registered[self] end
    fr.UnregisterEvent = function(self, e) registered[self] = false end
    fr.RegisterEvent = function(self, e) registered[self] = true end
    _G["ChatFrame" .. i] = fr
end
_G.GetChannelList = function() return 1, "Allgemein", 2, "Handel" end
local atCall = {}
_G.ListChannelByName = function(num) atCall[#atCall + 1] = { _G.ChatFrame1:IsEventRegistered(), _G.ChatFrame2:IsEventRegistered(), _G.ChatFrame3:IsEventRegistered() } end

local handlers = {}
local FW = { RegisterEvent = function(_, e, fn) handlers[e] = fn end, Fire = function() end, On = function() end }
assert(loadfile("Core/Channels.lua"))("Freewood-Core", FW)
local Ch = FW.Channels
Ch.RefreshAll()
local c1, c2 = _G.ChatFrame1, _G.ChatFrame2
clock = clock + 1; onUpdate()
eq(#atCall, 1, "erste Abfrage gesendet")
eq(atCall[1][1], false, "Chatfenster 1 beim Senden abgemeldet")
eq(atCall[1][2], false, "Chatfenster 2 beim Senden abgemeldet")
eq(atCall[1][3], false, "Chatfenster 3 bleibt ohne Ereignis")
-- Antwort kommt: noch abgemeldet, erst kurz danach wieder angemeldet
handlers["CHAT_MSG_CHANNEL_LIST"]("Anna, Bert", nil, nil, nil, nil, nil, nil, 1)
eq(registered[c1], false, "direkt nach der Antwort noch abgemeldet")
-- alles abarbeiten
for _ = 1, 40 do clock = clock + 0.5; onUpdate() end
eq(#atCall, 2, "zweite Abfrage gesendet")
eq(atCall[2][1] or atCall[2][2], false, "auch die zweite Abfrage laeuft im Chat unsichtbar")
eq(registered[c1], true, "am Ende wieder angemeldet (1)")
eq(registered[c2], true, "am Ende wieder angemeldet (2)")
eq(registered[_G.ChatFrame3], false, "Fenster 3 wurde nie angemeldet")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
