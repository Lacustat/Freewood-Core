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

-- Versuch: Flaeche hinter den Zeilen
local function FS(text, top, bottom, r, g, b, shown)
    return { GetObjectType = function() return "FontString" end, IsShown = function() return shown ~= false end,
        GetText = function() return text end, GetTop = function() return top end, GetBottom = function() return bottom end,
        GetTextColor = function() return r, g, b, 1 end }
end
local texs = {}
local function NewTex() local t = { shown = false }
    t.ClearAllPoints = function() end; t.SetPoint = function() end; t.SetHeight = function(_, h) t.h = h end
    t.SetColorTexture = function(_, r, g, b, a) t.c = { r, g, b, a } end
    t.Show = function() t.shown = true end; t.Hide = function() t.shown = false end
    texs[#texs + 1] = t; return t end
local regs = { FS("Gilde: hallo", 900, 886, 0.25, 1, 0.25), FS("Sagen: hi", 886, 872, 1, 1, 1), FS("", 872, 858, 1, 1, 1), FS("versteckt", 858, 844, 1, 1, 1, false),
    { GetObjectType = function() return "Texture" end } }
local cf2 = { FontStringContainer = { GetRegions = function() return unpack(regs) end }, GetRegions = function() return end, GetTop = function() return 1000 end, GetLeft = function() return 100 end, GetRight = function() return 500 end,
    CreateTexture = function() return NewTex() end }
FW.settings.chatStyle = { lineBg = false }
eq(S.UpdateUnder(cf2), nil, "Versuch aus: nichts gezeichnet")
FW.settings.chatStyle = { lineBg = true, lineBgAlpha = 50, types = { guild = { bg = { 0, 0.5, 0 } } } }
eq(S.UpdateUnder(cf2), 2, "zwei Zeilen mit Text gezeichnet")
eq(texs[1].shown, true, "Flaeche 1 sichtbar")
eq(texs[1].c[2], 0.5, "eigene Flaechenfarbe Gilde"); eq(texs[1].c[4], 0.5, "Deckkraft")
eq(texs[2].c[1], 1, "Sagen: Spielfarbe")
-- Zeile verschwindet: Flaeche wird versteckt
regs[2] = FS("", 886, 872, 1, 1, 1)
eq(S.UpdateUnder(cf2), 1, "nur noch eine Zeile")
eq(texs[2].shown, false, "uebrige Flaeche versteckt")
-- eigene Textfarbe wird der Art zugeordnet
regs[1] = FS("Gilde: hallo", 900, 886, 0, 0, 0)
FW.settings.chatStyle = { lineBg = true, types = { guild = { text = { 0, 0, 0 }, bg = { 0.2, 0.9, 0.2 } } } }
S.UpdateUnder(cf2)
eq(texs[1].c[2], 0.9, "Flaeche ueber eigene Textfarbe gefunden")
-- Messung
local pr = S.Probe()
eq(#pr >= 3, true, "Messzeilen")

-- Protokoll
_G.NUM_CHAT_WINDOWS = 1
local fsx = FS("Hallo \124cffff0000rot\124r", 900, 886, 1, 1, 1)
fsx.GetName = function() return "ChatFrame1Line1" end
local cfd = { GetRegions = function() return fsx, regs[5] end, GetChildren = function() return end, GetObjectType = function() return "ScrollingMessageFrame" end,
    GetName = function() return "ChatFrame1" end, GetTop = function() return 1000 end, GetLeft = function() return 100 end, IsShown = function() return true end,
    GetNumMessages = function() return 2 end, GetMessageInfo = function(_, i) return "Nachricht " .. i, 1, 1, 0, i end }
_G.ChatFrame1 = cfd
_G.ChatTypeInfo = { SAY = { r = 1, g = 1, b = 1 } }
_G.GetBuildInfo = function() return "1.0", "123", "Jan 1 2026", 16001 end
local dump = S.Dump()
eq(#dump > 10, true, "Protokoll hat Zeilen")
local joined = table.concat(dump, "\n")
has(joined, "ScrollingMessageFrame", "Typ im Protokoll"); has(joined, "Nachricht 2", "Nachrichten im Protokoll")
has(joined, "SAY = 1", "Chatfarben im Protokoll"); has(joined, "Regionen: 2", "Regionen gezaehlt")
has(joined, "\124\124cffff0000", "Pipe-Zeichen verdoppelt (kein Farbcode im Protokoll)")
_G.FreewoodDB = {}
eq(S.SaveDump() > 10, true, "Protokoll gespeichert"); eq(type(FreewoodDB.chatDump.lines), "table", "in der Datenbank")

-- Forever: ChatTypeInfo ist leer -> Standardfarben von Blizzard
_G.ChatTypeInfo = {}
ev.UPDATE_CHAT_COLOR()
eq(S.TypeIndex()["25,100,25"], "guild", "Gilde ohne ChatTypeInfo erkannt")
eq(S.TypeIndex()["100,75,75"], "channel", "Kanal ohne ChatTypeInfo erkannt")
local dr2, dg2 = S.DefaultColor("guild"); eq(dg2, 1, "Standardfarbe Gilde (Rueckfall)")
-- Zeilen aus visibleLines, wenn kein Container da ist
local vl = { FS("Gilde: x", 900, 886, 0.25, 1, 0.25) }
local cf3 = { visibleLines = vl, GetTop = function() return 1000 end, GetLeft = function() return 100 end, GetRight = function() return 500 end }
eq(#S.ReadLines(cf3), 1, "visibleLines als Rueckfall")

-- Bloecke: mehrzeilige Nachricht als eine Flaeche
local MK = "\124cff000001\124r"
local regs4 = { FS(MK .. "Gilde: erste Zeile", 900, 884, 0.25, 1, 0.25), FS("zweite Zeile derselben Nachricht", 882, 866, 0.25, 1, 0.25),
    FS(MK .. "Sagen: hi", 864, 848, 1, 1, 1) }
local texs4 = {}
local cf4 = { FontStringContainer = { GetRegions = function() return unpack(regs4) end }, GetTop = function() return 1000 end, GetLeft = function() return 100 end, GetRight = function() return 500 end,
    CreateTexture = function() local t = { }
        t.ClearAllPoints = function() end; t.SetPoint = function(_, _, _, _, _, y) t.y = y end; t.SetHeight = function(_, h) t.h = h end
        t.SetColorTexture = function() end; t.Show = function() end; t.Hide = function() end
        texs4[#texs4 + 1] = t; return t end }
FW.settings.chatStyle = { lineBg = true, lineBlocks = true }
eq(S.UpdateUnder(cf4), 2, "Bloecke: zwei Nachrichten, drei Zeilen")
eq(texs4[1].h, 34, "Block 1 umfasst beide Zeilen (900 bis 866)")
eq(texs4[2].h, 16, "Block 2 ist eine Zeile")
texs4 = {}
FW.settings.chatStyle = { lineBg = true, lineBlocks = false }
cf4.FontStringContainer.GetRegions = function() return unpack(regs4) end
eq(S.UpdateUnder(cf4), 3, "ohne Bloecke: drei Zeilen")

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
