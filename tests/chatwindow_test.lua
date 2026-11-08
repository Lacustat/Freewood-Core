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

-- /r (Antworten) und andere unbekannte Befehle werden weitergereicht, /ra ist Schlachtzug
kind, target = W.ParseInput("/r hallo", "all", nil); eq(kind, nil, "/r wird weitergereicht"); eq(target, "unknown", "/r unbekannt")
kind = W.ParseInput("/ra hallo", "all", nil); eq(kind, "group", "/ra")

-- System-Meldungen (vorerst nur mit sysOn)
ev.CHAT_MSG_SYSTEM("zu frueh"); eq(#W.Visible("system"), 0, "System standardmaessig aus")
FW.settings.chatWin.sysOn = true
ev.CHAT_MSG_SYSTEM("Bogadin ist jetzt offline.")
ev.CHAT_MSG_SYSTEM("Bogadin ist jetzt offline.")
FW.settings.chatWin.main = false
eq(#W.Visible("system"), 1, "System-Reiter, doppelte Meldung zusammengefasst")
local nAll = #W.Visible("all")
FW.settings.chatWin.main = true
eq(#W.Visible("all"), nAll + 1, "System in Alle nur im Haupt-Chat-Modus")
ev.CHAT_MSG_LOOT("Du erhaeltst Beute: [Stein].")
eq(#W.Visible("system"), 2, "Beute als System")
secret["geheim2"] = true
ev.CHAT_MSG_SYSTEM("geheim2")
eq(#W.Visible("system"), 2, "geheime Systemmeldung uebersprungen")

-- Spiel-Eingabefeld umleiten
local opened
W.OpenInput = function(t) opened = t; return true end
W.MainActive = function() return true end
local closed = 0
local eb = { GetText = function() return "" end, ClearFocus = function() closed = closed + 1 end, Hide = function() closed = closed + 1 end,
    GetAttribute = function(_, k) if k == "chatType" then return "WHISPER" elseif k == "tellTarget" then return "Anna" end end }
eq(W.OnBlizzActivate(eb, false), true, "Aktivierung umgeleitet")
eq(opened, "", "Eingabe geoeffnet"); eq(closed >= 1, true, "Spiel-Feld geschlossen"); eq(W.target, "Anna", "Fluesterziel vom Antworten")
W.target = nil
opened = nil
eq(W.OnBlizzActivate(eb, true), false, "Umschalt: Spiel-Feld bleibt (Notausgang)"); eq(opened, nil, "nicht geoeffnet")
W.bypass = true; eq(W.OnBlizzActivate(eb, false), false, "Bypass"); W.bypass = false
W.MainActive = function() return false end
eq(W.OnBlizzActivate(eb, false), false, "Haupt-Chat aus: nichts umleiten")
W.MainActive = function() return true end
W.redirected = true
W.OnBlizzOpenChat("/")
eq(W.redirected, false, "Nachtragen setzt Marke zurueck")

-- Weiterreichen
local sentT
_G.ChatEdit_SendText = function(e) sentT = e.text end
local feb = { SetText = function(self, t) self.text = t end }
_G.DEFAULT_CHAT_FRAME = { editBox = feb }
eq(W.Forward("/roll 100"), true, "Weiterreichen"); eq(sentT, "/roll 100", "Text beim Spiel angekommen")
_G.ChatEdit_SendText = nil
eq(W.Forward("/roll"), false, "ohne Spiel-Funktion false")

-- eigene Nachrichten erkennen (auch ohne Kennzeichen vom Chat-Protokoll)
W.Push("guild", "Pinky", "ich in der Gilde", false); eq(W.msgs[#W.msgs].o, true, "eigene Gildennachricht rechts")
W.Push("guild", "Pinky-Realm", "mit Realm", false); eq(W.msgs[#W.msgs].o, true, "eigener Name mit Realm")
W.Push("guild", "Anna", "fremd", false); eq(W.msgs[#W.msgs].o, nil, "fremde Nachricht links")
W.Push("group", "Pinky Freewood", "voller Name", false); eq(W.msgs[#W.msgs].o, true, "voller eigener Name")

-- Tasten: Bindungen und Abfrage
_G.GetBindingKey = function(a) if a == "OPENCHAT" then return "ENTER", "F5" end end
local keys = W.BindingKeys("OPENCHAT", { "ENTER", "NUMPADENTER" })
eq(#keys, 3, "Tasten ohne Doppelte"); eq(keys[2], "F5", "zweite Taste aus dem Spiel")
local opened2
W.OpenInput = function(t) opened2 = t; return true end
_G.IsShiftKeyDown = function() return false end
W.MainActive = function() return true end
eq(W.HandleKey("ENTER"), true, "Enter oeffnet"); eq(opened2, "", "leer geoeffnet")
eq(W.HandleKey("F5"), true, "zweite Taste oeffnet")
eq(W.HandleKey("A"), false, "andere Taste wird weitergegeben")
_G.IsShiftKeyDown = function() return true end
_G.GetBindingKey = function(a) if a == "OPENCHATSLASH" then return "SHIFT-7" end end
eq(W.HandleKey("7"), true, "Schraegstrich auf deutscher Tastatur (Umschalt+7)"); eq(opened2, "/", "mit Schraegstrich geoeffnet")
_G.IsShiftKeyDown = function() return false end
FW.settings.chatWin.useBlizz = true
eq(W.UseBlizz(), true, "Feld des Spiels aktiv (Haupt-Chat an)")
eq(W.HandleKey("ENTER"), false, "Spiel-Feld-Modus: keine eigene Tastenabfrage")
eq(W.OnBlizzActivate({}, false), false, "Spiel-Feld-Modus: nichts umleiten")
FW.settings.chatWin.main = false
eq(W.UseBlizz(), false, "Spiel-Feld-Modus nur bei Haupt-Chat")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
