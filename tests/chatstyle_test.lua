-- Test Chat verschoenern (texlua tests/chatstyle_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function has(s, p, m) n = n + 1; if not string.find(s, p, 1, true) then fails = fails + 1; print("FEHLER " .. m, s) end end
_G.date = function() return "12:34" end
local ev, secret = {}, {}
local FW = { UI = { RegisterSettingsSection = function() end }, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    RegisterEvent = function(_, e, f) ev[e] = f end,
    Util = { IsSecret = function(v) return secret[v] == true end },
    ChatLog = { Info = function(name) if name == "Anna" then return "MAGE", 60 end end,
        ClassColor = function() return 0.41, 0.8, 0.94 end } }
assert(loadfile("UI/ChatStyle.lua"))("Freewood-Core", FW)
local S = FW.ChatStyle

local line = "\124Hplayer:Anna:12:CHAT_MSG_SAY\124h[Anna]\124h sagt: Hallo"
local out = S.Format(line, 1, 1, 1)
has(out, "12:34", "Uhrzeit")
has(out, "\226\150\140", "Balken")
has(out, "\124cff69ccf0Anna\124r", "Klassenfarbe")
eq(string.find(out, "[Anna]", 1, true), nil, "Klammern entfernt")
has(out, "sagt: Hallo", "Text bleibt")
-- unbekannter Spieler: Name ohne Farbe, aber ohne Klammern
local out2 = S.Format("\124Hplayer:Bob:1\124h[Bob]\124h: hi", 1, 0, 0)
has(out2, "\124h" .. "Bob" .. "\124h", "Bob ohne Klammern")
-- nicht doppelt bearbeiten
eq(S.Format(out, 1, 1, 1), out, "keine Doppelbearbeitung")
-- Klammern behalten
FW.settings.chatStyle = { brackets = true }
has(S.Format(line, 1, 1, 1), "[Anna]", "Klammern behalten")
-- Schalter
FW.settings.chatStyle = { time = false, bar = false }
local o3 = S.Format("Systemtext", 1, 1, 0)
eq(string.find(o3, "12:34", 1, true), nil, "Uhrzeit aus")
eq(string.find(o3, "\226\150\140", 1, true), nil, "Balken aus")
FW.settings.chatStyle = { enabled = false }
eq(S.Format("x", 1, 1, 1), "x", "aus: unveraendert")
FW.settings.chatStyle = {}
-- geheime Werte
secret["geheim"] = true
eq(S.Format("geheim", 1, 1, 1), "geheim", "geheimer Text unveraendert")
-- Einhuellen
local shown = {}
local cf = { AddMessage = function(self, text, r, g, b, id) shown[#shown + 1] = { text, r, id } end }
_G.NUM_CHAT_WINDOWS = 2
_G.ChatFrame1 = cf
eq(S.Install(), 1, "ein Fenster eingehuellt")
eq(S.Install(), 0, "nicht doppelt eingehuellt")
cf:AddMessage("Hallo", 1, 1, 1, 7)
eq(#shown, 1, "Zeile angezeigt"); has(shown[1][1], "Hallo", "Text vorhanden"); eq(shown[1][3], 7, "weitere Argumente durchgereicht")
-- Fehler in der Umformung: Zeile unveraendert
FW.ChatLog.Info = function() error("kaputt") end
cf:AddMessage("\124Hplayer:Anna:1\124h[Anna]\124h: x", 1, 1, 1)
eq(#shown, 2, "bei Fehler trotzdem angezeigt")
has(shown[2][1], "[Anna]", "bei Fehler unveraendert")
S.Unwrap(cf)
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
