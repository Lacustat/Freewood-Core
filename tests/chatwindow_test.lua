-- Test eigenes Chatfenster: Einordnung, Reiter-Filter, Eingabe, Speicher (texlua tests/chatwindow_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function Proxy()
    return setmetatable({}, { __index = function() return function() return Proxy() end end })
end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.UnitName = function() return "Pinky" end
_G.time = os.time
local ev, secret = {}, {}
local UI = setmetatable({ RegisterSettingsSection = function() end }, { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    RegisterEvent = function(_, e, f) ev[e] = f end, On = function() end, Fire = function() end,
    Util = { IsSecret = function(v) return secret[v] == true end },
    Whisper = { SelfName = function() return "Pinky Freewood" end } }
assert(loadfile("UI/ChatWindow.lua"))("Freewood-Core", FW)
local W = FW.ChatWindow

local k, x = W.Classify("guild"); eq(k, "guild", "Gilde")
eq(W.Classify("group"), "group", "Gruppe")
k, x = W.Classify("w:Anna"); eq(k, "whisper", "Fluestern"); eq(x, "Anna", "Fluesterpartner")
k, x = W.Classify("c:Handel"); eq(k, "channel", "Kanal"); eq(x, "Handel", "Kanalname")
eq(W.Classify("xyz"), nil, "unbekannt")

W.Push("guild", "Anna", "hi", false)
W.Push("group", "Bob", "los", false)
W.Push("w:Cid", "Cid", "psst", false)
W.Push("c:Handel", "Dora", "WTS", false)
ev.CHAT_MSG_SAY("Hallo", "Eve")
ev.CHAT_MSG_YELL("Hilfe", "Fred")
ev.CHAT_MSG_EMOTE("tanzt", "Gus")
eq(#W.Visible("all"), 6, "Alle (Emote standardmaessig aus)")
eq(#W.Visible("say"), 2, "Sagen")
eq(#W.Visible("guild"), 1, "Gilde-Reiter")
eq(#W.Visible("whisper"), 1, "Fluestern-Reiter")
eq(#W.Visible("channel"), 1, "Kanal-Reiter")
FW.settings.chatWin.emote = true
ev.CHAT_MSG_TEXT_EMOTE("Gus winkt.", "Gus")
eq(#W.Visible("say"), 3, "Emote an")
FW.settings.chatWin.say = false
eq(#W.Visible("say"), 1, "Sagen aus blendet Sagen/Rufen aus")
FW.settings.chatWin.say = true

-- eigene Nachricht
ev.CHAT_MSG_SAY("ich", "Pinky")
eq(W.msgs[#W.msgs].o, true, "eigene Nachricht erkannt")
-- Geheimes wird uebersprungen
secret["geheim"] = true
local c = #W.msgs
ev.CHAT_MSG_SAY("geheim", "Eve")
eq(#W.msgs, c, "geheimer Text uebersprungen")
-- Speicher begrenzt
for i = 1, 500 do W.Push("guild", "A", "m" .. i, false) end
eq(#W.msgs <= 345, true, "Speicher begrenzt")

-- Ungelesen
W.Opts().tab = "guild"; W.unread = {}
W.Push("group", "Bob", "x", false)
eq(W.unread.group, 1, "ungelesen Gruppe")
eq(W.unread.guild, nil, "offener Reiter zaehlt nicht")

-- Eingabe
local kind, target, text = W.ParseInput("/g Hallo Welt", "all", nil); eq(kind, "guild", "/g"); eq(text, "Hallo Welt", "/g Text")
kind = W.ParseInput("/s hi", "guild", nil); eq(kind, "say", "/s")
kind = W.ParseInput("/y hi", "all", nil); eq(kind, "yell", "/y")
kind = W.ParseInput("/p hi", "all", nil); eq(kind, "group", "/p")
kind, target, text = W.ParseInput("/w Anna wie gehts", "all", nil); eq(kind, "whisper", "/w"); eq(target, "Anna", "/w Ziel"); eq(text, "wie gehts", "/w Text")
kind, target, text = W.ParseInput("/2 hallo", "all", nil); eq(kind, "channel", "/2"); eq(target, 2, "/2 Kanalnummer")
kind, target = W.ParseInput("/foo bar", "all", nil); eq(kind, nil, "unbekannter Befehl"); eq(target, "unknown", "Fehlerart")
kind, target = W.ParseInput("/w Anna", "all", nil); eq(target, "usage", "/w ohne Text")
kind = W.ParseInput("hallo", "guild", nil); eq(kind, "guild", "Gilden-Reiter sendet an Gilde")
kind = W.ParseInput("hallo", "group", nil); eq(kind, "group", "Gruppen-Reiter")
kind = W.ParseInput("hallo", "all", nil); eq(kind, "say", "Standard sagen")
kind, target = W.ParseInput("hallo", "guild", "Anna"); eq(kind, "whisper", "Fluesterziel hat Vorrang"); eq(target, "Anna", "Fluesterziel")
eq(W.ParseInput("   ", "all", nil), nil, "leer")

-- Senden
local sent = {}
_G.SendChatMessage = function(t, ch) sent[#sent + 1] = ch .. ":" .. t end
W.Send("say", nil, "a"); W.Send("yell", nil, "b")
eq(sent[1], "SAY:a", "senden sagen"); eq(sent[2], "YELL:b", "senden rufen")
FW.ChatLog = { Send = function(kd, tg, tx) sent[#sent + 1] = kd .. ":" .. tx end }
W.Send("guild", nil, "c"); eq(sent[3], "guild:c", "Gilde ueber ChatLog")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
