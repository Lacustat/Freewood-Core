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
-- Doppelte Uhrzeit: Spiel setzt schon eine
FW.settings.chatStyle = {}
local g1 = S.Format("14:11:23 Leeny sagt: hi", 1, 1, 1)
eq(string.find(g1, "12:34", 1, true), nil, "keine zweite Uhrzeit")
local g2 = S.Format("\124cffaaaaaa[14:11:23]\124r Leeny sagt: hi", 1, 1, 1)
eq(string.find(g2, "12:34", 1, true), nil, "keine zweite Uhrzeit (Klammern/Farbe)")
has(S.Format("Leeny sagt: hi", 1, 1, 1), "12:34", "ohne Spielzeit: eigene Uhrzeit")
-- Chat-Arten ueber die Zeilenfarbe
_G.ChatTypeInfo = { SAY = { r = 1, g = 1, b = 1 }, GUILD = { r = 0.25, g = 1, b = 0.25 }, SYSTEM = { r = 1, g = 1, b = 0 } }
ev.UPDATE_CHAT_COLOR()   -- Farbtabelle des Spiels neu einlesen
FW.settings.chatStyle = { types = { guild = { bar = { 1, 0, 0 }, text = { 0, 0, 0 } } } }
local gt, tr, tg, tb = S.Format("Gilde: hallo", 0.25, 1, 0.25)
has(gt, "\124cffff0000", "eigene Balkenfarbe Gilde")
eq(tr, 0, "eigene Textfarbe Gilde (r)"); eq(tb, 0, "eigene Textfarbe Gilde (b)")
local st, sr = S.Format("Sagen: hallo", 1, 1, 1)
has(st, "\124cffffffff", "Sagen: Spielfarbe als Balken"); eq(sr, 1, "Sagen: Textfarbe unveraendert")
local dr, dg, db = S.DefaultColor("guild")
eq(dg, 1, "Standardfarbe Gilde")
-- Balkenbreite
FW.settings.chatStyle = { barWidth = "wide" }
has(S.Format("x", 1, 1, 1), "\226\150\136\226\150\136", "breiter Balken")
FW.settings.chatStyle = { barWidth = "medium" }
eq(string.find(S.Format("x", 1, 1, 1), "\226\150\136\226\150\136", 1, true), nil, "mittlerer Balken ist ein Block")
-- Standard-Tabellen werden nicht geteilt
FW.settings.chatStyle = {}
local o1 = S.Opts(); o1.types.say = { bar = { 1, 0, 0 } }
eq(S.DEFAULTS.types.say, nil, "Standardwerte unveraendert")
-- Abstand und Hintergrund
local calls = {}
local cf1 = { SetSpacing = function(_, v) calls.spacing = v end }
_G.NUM_CHAT_WINDOWS = 1; _G.ChatFrame1 = cf1
_G.FCF_SetWindowColor = function(_, r, g, b) calls.color = { r, g, b } end
_G.FCF_SetWindowAlpha = function(_, a) calls.alpha = a end
FW.settings.chatStyle = { spacing = 3, bgOn = true, bgAlpha = 40, bgColor = { 0.1, 0.2, 0.3 } }
S.ApplyLook()
eq(calls.spacing, 3, "Zeilenabstand gesetzt"); eq(calls.alpha, 0.4, "Hintergrund-Deckkraft"); eq(calls.color[2], 0.2, "Hintergrundfarbe")
calls = {}
FW.settings.chatStyle = { bgOn = false }
S.ApplyLook()
eq(calls.alpha, nil, "Hintergrund aus: nicht angefasst")

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
