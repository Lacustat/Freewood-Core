-- Test Design-Reiter: Farben merken, umfaerben, Transparenz, Schrift (texlua tests/design_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function near(a, b, m) n = n + 1; if math.abs(a - b) > 0.01 then fails = fails + 1; print("FEHLER " .. m, a, b) end end

local clock = 1
_G.GetTime = function() return clock end
local TexM, FsM, EbM = {}, {}, {}
TexM.SetColorTexture = function(self, r, g, b, a) self.c = { r, g, b, a } end
FsM.SetTextColor = function(self, r, g, b, a) self.c = { r, g, b, a } end
FsM.SetFont = function(self, path) self.font = path; return true end
EbM.SetTextColor = FsM.SetTextColor
local function New(M) return setmetatable({}, { __index = M }) end
_G.hooksecurefunc = function(tbl, name, fn)
    local orig = tbl[name]
    tbl[name] = function(...) local r = orig(...); fn(...); return r end
end
local frameObj = { CreateTexture = function() return New(TexM) end, CreateFontString = function() return New(FsM) end }
_G.CreateFrame = function(kind) if kind == "EditBox" then local e = New(EbM); e.SetAutoFocus = function() end; e.ClearFocus = function() end; e.Hide = function() end; return e end return frameObj end
_G.UIParent = { CreateFontString = function() return New(FsM) end }
_G.UISpecialFrames = {}

local handlers = {}
local FW = { settings = {}, On = function(_, e, f) handlers[e] = f end, Fire = function() end, L = setmetatable({}, { __index = function(_, k) return k end }) }
assert(loadfile("UI/Kit.lua"))("Freewood-Core", FW)
local UI = FW.UI
eq(UI.liveColors, true, "Methoden gehookt")

-- Merken
local t = New(TexM)
t:SetColorTexture(UI.Color("panel", 0.5))
eq(UI.tracked[t] ~= nil, true, "Textur gemerkt")
local fs = New(FsM)
fs:SetTextColor(UI.Color("gold"))
eq(UI.tracked[fs] ~= nil, true, "Text gemerkt")
-- fremde Farbe (nicht aus UI.Color) wird nicht gemerkt
local other = New(TexM)
other:SetColorTexture(0.3, 0.3, 0.3, 1)
eq(UI.tracked[other], nil, "fremde Textur nicht gemerkt")
clock = clock + 1
local late = New(TexM)
late:SetColorTexture(UI.Color("panel"))   -- gleiches Bild, aber nach UI.Color von frueher: gemerkt
clock = clock + 1
local later = New(TexM)
later:SetColorTexture(0.078, 0.094, 0.141, 1)  -- gleiche Farbe, aber UI.Color war in einem frueheren Bild
eq(UI.tracked[later], nil, "alte UI.Color-Anfrage zaehlt nicht")

-- Design laden
FW.window = nil
assert(loadfile("UI/Design.lua"))("Freewood-Core", FW)
local D = FW.Design
D.ApplyAll()
D.SetColor("panel", 1, 0, 0)
near(t.c[1], 1, "Textur rot"); near(t.c[2], 0, "Textur gruen"); near(t.c[4], 0.5, "Grundtransparenz bleibt")
D.SetColor("gold", 0, 1, 0)
near(fs.c[2], 1, "Text gruen")
D.SetAlpha(50)
near(t.c[4], 0.25, "Flaeche halbtransparent (0.5 * 0.5)")
near(fs.c[4], 1, "Text bleibt deckend")
eq(FW.settings.design.colors.panel, "ff0000", "Farbe gespeichert")
D.ResetColors()
near(t.c[1], 0.078, "Standardfarbe zurueck")
eq(UI.hex.panel, UI.hexDefault.panel, "Palette zurueck")

-- Schrift
D.SetFont("heading", "Fonts\\MORPHEUS.TTF")
eq(UI.GetFontPath("heading"), "Fonts\\MORPHEUS.TTF", "Schriftart gesetzt")
D.SetFont("heading", "")
eq(UI.GetFontPath("heading"), "Fonts\\FRIZQT__.TTF", "Schriftart zurueck")
D.SetTabSize(16)
eq(UI.tabFontSize, 16, "Tab-Schriftgroesse")
D.SetTabSize(40)
eq(UI.tabFontSize, 20, "Schriftgroesse begrenzt")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
