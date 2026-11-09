-- Test Ring-Anzeige (texlua tests/unitrings_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function near(a, b, m) n = n + 1; if math.abs(a - b) > 1e-6 then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local SECRET = {}
local Fake
Fake = function()
    local o = { shown = false, alpha = 1, rot = nil }
    return setmetatable(o, { __index = function(t, k)
        if k == "CreateTexture" or k == "CreateMaskTexture" then return function() return Fake() end end
        if k == "GetAlpha" then return function() return t.alpha end end
        if k == "SetAlpha" then return function(_, a) t.alpha = a end end
        if k == "Show" then return function() t.shown = true end end
        if k == "Hide" then return function() t.shown = false end end
        if k == "IsShown" then return function() return t.shown end end
        if k == "SetScript" then return function(_, e, f) t[e] = f end end
        if k == "SetPoint" then return function(_, ...) t.point = { ... } end end
        if k == "SetSize" then return function(_, w, h) t.w, t.h = w, h end end
        if k == "SetRotation" then return function(_, r) t.rot = r end end
        if k == "SetVertexColor" then return function(_, r, g, b) t.col = { r, g, b } end end
        if k == "SetTexCoord" then return function(_, a, b) t.tc = { a, b } end end
        if k == "SetTexture" then return function(_, p) t.tex = p end end
        if k == "GetCenter" then return function() return 100, 100 end end
        return function() end
    end })
end
_G.CreateFrame = function() return Fake() end
_G.UIParent = Fake()
_G.GetTime = function() return 5000 end
local hp, hpmax, pw, pwmax, pt = 50, 100, 30, 60, 0
local manaCur, manaMax = 400, 1000
_G.UnitHealth = function() return hp end; _G.UnitHealthMax = function() return hpmax end
_G.UnitPower = function(_, t) if t == 0 then return manaCur end return pw end
_G.UnitPowerMax = function(_, t) if t == 0 then return manaMax end return pwmax end
_G.UnitPowerType = function() return pt end
_G.PlayerFrame = Fake()
local UI = setmetatable({}, { __index = function() return function() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }), AddLocale = function() end,
    RegisterEvent = function() end, Util = { IsSecret = function(v) return v == SECRET or v == "secret" end },
    RingThickness = { 0.06, 0.10, 0.16, 0.22, 0.30, 0.40 } }
assert(loadfile("UI/UnitRings.lua"))("Freewood-Core", FW)
local R = FW.UnitRings
local P = "Interface\\AddOns\\Freewood-Core\\Media\\Rings\\"

-- Standard: alles aus
local o = R.Opts()
for _, k in ipairs({ "on", "dmana", "power", "health", "portrait", "hideBlizz", "hideFull", "unlock", "dmanaRev", "powerRev", "healthRev" }) do eq(o[k], false, "Standard aus: " .. k) end
eq(o.healthThick, 3, "Standard-Dicke Leben"); eq(o.powerThick, 3, "Standard-Dicke Ressource"); eq(o.dmanaThick, 3, "Standard-Dicke Mana")

near(R.Fraction(50, 100), 0.5, "Anteil"); near(R.Fraction(5, 0), 0, "Max 0"); near(R.Fraction(SECRET, 10), 0, "secret ignoriert")
near(R.Fraction(200, 100), 1, "oben begrenzt"); near(R.Fraction(-5, 100), 0, "unten begrenzt")
local r, g = R.HealthColor(1); eq(g > r, true, "voll = gruen")
r, g = R.HealthColor(0.05); eq(r > g, true, "fast leer = rot")
eq(R.Level(0), 1, "Stufe unten begrenzt"); eq(R.Level(99), 6, "Stufe oben begrenzt"); eq(R.Level(nil), 3, "Standard 3")
near(R.Thickness(1), 0.06, "Dicke Stufe 1"); near(R.Thickness(6), 0.40, "Dicke Stufe 6")

-- Drehwinkel
local a, b = R.Angles(0); near(a, 0, "0 %: rechts 0"); near(b, -math.pi, "0 %: links 180 (leer)")
a, b = R.Angles(0.25); near(a, -math.pi / 2, "25 %: rechts 90 Grad"); near(b, -math.pi, "25 %: links leer")
a, b = R.Angles(0.5); near(a, -math.pi, "50 %: rechts voll"); near(b, -math.pi, "50 %: links leer")
a, b = R.Angles(0.75); near(a, -math.pi, "75 %: rechts voll"); near(b, -1.5 * math.pi, "75 %: links 270 Grad")
a, b = R.Angles(1); near(b, -2 * math.pi, "100 %: links 360 Grad")
a, b = R.Angles(0.25, true); near(a, math.pi / 2, "gegen den Uhrzeigersinn: Vorzeichen gedreht")

-- Kontur-Bilder
eq(R.LineFor("health"), P .. "frame_green.tga", "Leben gruen")
eq(R.LineFor("dmana"), P .. "frame_blue.tga", "Druiden-Mana blau")
eq(R.LineFor("power", 0), P .. "frame_blue.tga", "Mana blau"); eq(R.LineFor("power", 1), P .. "frame_red.tga", "Wut rot"); eq(R.LineFor("power", 3), P .. "frame_yellow.tga", "Energie gelb")
local wp, tint = R.LineFor("power", 6); eq(wp, P .. "frame_white.tga", "andere Ressource: weisse Kontur"); eq(tint, true, "wird eingefaerbt")

-- Ebenen und Groessen
local function Opt(t) local x = { size = 100, dmanaThick = 3, powerThick = 3, healthThick = 3 }; for k, v in pairs(t) do x[k] = v end; return x end
R.druid = false
local lay = R.Layout(Opt({ power = true, health = true }))
eq(#lay.slots, 2, "zwei Ebenen"); eq(lay.slots[1], "power", "Ressource aussen"); eq(lay.slots[2], "health", "Leben innen")
eq(lay.diam.power, 100, "aeusserer Ring volle Groesse"); eq(lay.diam.health, 76, "innerer Ring: Fuellung (x0.936) minus Dicke minus Abstand")
lay = R.Layout(Opt({ dmana = true, power = true, health = true })); eq(#lay.slots, 2, "Mana-Ebene nur fuer Druiden")
R.druid = true
lay = R.Layout(Opt({ dmana = true, power = true, health = true }))
eq(#lay.slots, 3, "drei Ebenen fuer Druiden"); eq(lay.slots[1], "dmana", "Mana ganz aussen")
eq(lay.diam.dmana > lay.diam.power and lay.diam.power > lay.diam.health, true, "von aussen nach innen kleiner")
eq(R.Layout(Opt({ dmana = true, power = true, health = true, dmanaThick = 6 })).diam.power < lay.diam.power, true, "dicker Aussenring -> naechster Ring kleiner")
eq(R.Layout(Opt({ power = true, health = true, healthThick = 6 })).portrait < R.Layout(Opt({ power = true, health = true })).portrait, true, "dicker Innenring -> Portrait kleiner")
eq(R.Layout(Opt({ health = true })).diam.health, 100, "ein Ring volle Groesse")
R.druid = false

-- ausgeschaltet
R.Apply(); eq(R.frame, nil, "aus: kein Frame"); eq(PlayerFrame.alpha, 1, "aus: Blizzard sichtbar")

-- zwei Ringe, lesbare Werte
o.on, o.health, o.power = true, true, true
R.Apply()
eq(R.frame.shown, true, "sichtbar")
local H, Pw = R.rings.health, R.rings.power
eq(H.frame.shown, true, "Leben sichtbar"); eq(Pw.frame.shown, true, "Ressource sichtbar"); eq(R.rings.dmana.frame.shown, false, "Mana-Ring aus")
eq(H.lineKey, P .. "frame_green.tga", "Lebensring: gruene Kontur")
eq(H.fsize, math.floor(H.size * 0.936 + 0.5), "Fuellung etwas kleiner als der Ring")
near(H.texR.rot, -math.pi, "Leben 50 %: rechte Haelfte voll (180 Grad)")
near(H.texL.rot, -math.pi, "Leben 50 %: linke Haelfte leer")
hp = 75; R.Update(); near(H.texR.rot, -math.pi, "Leben 75 %: rechts voll"); near(H.texL.rot, -1.5 * math.pi, "Leben 75 %: links 270")
hp = 25; R.Update(); near(H.texR.rot, -math.pi / 2, "Leben 25 %: rechts 90")
-- Farbe folgt dem Leben
hp = 100; R.Update(); local c100 = H.texR.col[2]; hp = 10; R.Update(); eq(H.texR.col[1] > H.texR.col[2], true, "Leben 10 %: rot"); eq(c100 > 0.5, true, "Leben 100 %: gruen")
-- Richtung je Ring
o.healthRev = true; hp = 25; R.Update(); near(H.texR.rot, math.pi / 2, "gegen den Uhrzeigersinn: positive Drehung"); eq(H.ccw, true, "Richtung gemerkt")
eq(H.texR.tc[1], 1, "Bild gespiegelt (links)"); eq(H.texR.tc[2], 0, "Bild gespiegelt (rechts)")
o.healthRev = false; R.Update(); eq(H.ccw, false, "zurueck im Uhrzeigersinn"); eq(H.texR.tc[1], 0, "Bild nicht gespiegelt")

-- Dicke umstellen
local tr = { frame = Fake(), fill = Fake(), track = Fake(), texR = Fake(), texL = Fake(), level = 3 }
R.SetLevel(tr, 5); eq(tr.level, 5, "Stufe gesetzt"); eq(tr.track.tex, P .. "ring5.tga", "Hintergrund-Bild der Stufe"); eq(tr.texR.tex, P .. "half5.tga", "Halbring-Bild der Stufe"); eq(tr.texL.tex, P .. "half5.tga", "Halbring links")
R.SetLevel(tr, 99); eq(tr.level, 6, "Stufe begrenzt")

-- Nur-wenn-nicht-voll
o.hideFull = true; hp, pw, pwmax = 100, 60, 60; R.Update(); eq(R.frame.alpha, 0, "alles voll -> unsichtbar")
hp = 80; R.Update(); eq(R.frame.alpha, 1, "nicht voll -> sichtbar")
o.unlock = true; hp = 100; R.Update(); eq(R.frame.alpha, 1, "Verschieben zeigt immer")
o.unlock, o.hideFull = false, false; pw = 30

-- Blizzard-Spielerfenster
o.hideBlizz = true; R.Apply(); eq(PlayerFrame.alpha, 0, "Blizzard ausgeblendet")
PlayerFrame.alpha = 1; R.Update(); eq(PlayerFrame.alpha, 0, "wird wieder durchgesetzt")
o.hideBlizz = false; R.Apply(); eq(PlayerFrame.alpha, 1, "Blizzard zurueck")
o.hideBlizz = true; R.Apply(); o.on = false; R.Apply(); eq(PlayerFrame.alpha, 1, "Ringe aus: Blizzard zurueck"); eq(R.frame.shown, false, "Ringe aus: versteckt")
o.hideBlizz = false

-- Position
o.on = true; o.x, o.y = 40, -10; R.Apply(); eq(R.frame.point[4], 40, "Lage x"); eq(R.frame.point[5], -10, "Lage y")

-- Druide: Mana-Ring nur in Katzen-/Baerengestalt
R.druid = true; R.layoutDruid = true
o.dmana = true; pt = 0; R.Apply()
eq(R.rings.dmana.frame.shown, false, "Zauberform: Mana-Ring versteckt")
pt = 3; hp = 50; R.Update()
eq(R.rings.dmana.frame.shown, true, "Katze: Mana-Ring sichtbar")
near(R.rings.dmana.texR.rot, -math.rad(144), "Mana 40 %: rechte Haelfte 144 Grad"); near(R.rings.dmana.texL.rot, -math.pi, "Mana 40 %: linke Haelfte leer")
eq(R.rings.power.lineKey, P .. "frame_yellow.tga", "Katze: gelbe Kontur fuer Energie"); eq(R.rings.dmana.lineKey, P .. "frame_blue.tga", "blaue Kontur fuer Druiden-Mana")
pt = 1; R.Update(); eq(R.rings.power.lineKey, P .. "frame_red.tga", "Baer: rote Kontur fuer Wut"); eq(R.rings.dmana.frame.shown, true, "Baer: Mana-Ring sichtbar")
o.dmana = false; R.druid = false; R.Apply()

-- geheime Werte: Winkel kommen aus Kurven des Spiels
o.on, o.health, o.power, o.hideFull = true, true, false, false
local pctCalls = {}
local function MkCurve(tag) return { tag = tag, AddPoint = function(self, x, y) self.pts = (self.pts or 0) + 1 end } end
_G.C_CurveUtil = { CreateCurve = function() return MkCurve("w") end,
    CreateColorCurve = function() return MkCurve("c") end }
_G.CreateColor = function(r, g, b) return { GetRGB = function() return r, g, b end } end
_G.UnitHealth = function() return "secret" end
_G.UnitHealthPercent = function(unit, pred, curve) pctCalls[#pctCalls + 1] = curve; if curve.tag == "c" then return { GetRGB = function() return 0.9, 0.5, 0.1 end } end return "secretwinkel" end
R.curves, R.ccurve = nil, nil
R.Apply()
local fr, src = R.Read("health"); eq(src, "secret", "Quelle secret"); near(fr, 0, "secret ohne Wert: 0")
eq(R.rings.health.texR.rot, "secretwinkel", "geheimer Winkel rechts wird durchgereicht"); eq(R.rings.health.texL.rot, "secretwinkel", "geheimer Winkel links")
eq(R.rings.health.texR.col[1], 0.9, "geheime Lebensfarbe aus der Farbkurve")
eq(R.Curves().cw.R.pts, 3, "Kurve mit 3 Punkten"); eq(R.Curves().ccw ~= nil, true, "Kurven gegen den Uhrzeigersinn")
-- ohne Kurven: Ring leer, kein Fehler
_G.C_CurveUtil = nil; R.curves, R.ccurve = nil, nil; R.Apply()
near(R.rings.health.texR.rot, 0, "ohne Kurven: leer (rechts 0)")
R.force = 0.6; fr, src = R.Read("health"); near(fr, 0.6, "Testmodus"); eq(src, "test", "Quelle test"); R.force = nil

local msgs = {}; FW.Print = function(_, t) table.insert(msgs, t) end
R.Debug(); eq(#msgs >= 3, true, "Debug gibt Zeilen aus")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
