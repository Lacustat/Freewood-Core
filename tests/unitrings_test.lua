-- Test Ring-Anzeige (texlua tests/unitrings_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function near(a, b, m) n = n + 1; if math.abs(a - b) > 1e-6 then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function Fake()
    local o = { shown = false, alpha = 1 }
    return setmetatable(o, { __index = function(t, k)
        if k == "CreateTexture" or k == "CreateMaskTexture" then return function() return Fake() end end
        if k == "GetAlpha" then return function() return t.alpha end end
        if k == "SetAlpha" then return function(_, a) t.alpha = a end end
        if k == "Show" then return function() t.shown = true end end
        if k == "Hide" then return function() t.shown = false end end
        if k == "IsShown" then return function() return t.shown end end
        if k == "SetScript" then return function(_, e, f) t[e] = f end end
        if k == "SetCooldown" then return function(_, s, d) t.start, t.dur = s, d; t.nCD = (rawget(t, "nCD") or 0) + 1 end end
        if k == "SetPoint" then return function(_, ...) t.point = { ... } end end
        if k == "SetSize" then return function(_, w, h) t.w, t.h = w, h end end
        if k == "GetCenter" then return function() return 100, 100 end end
        return function() end
    end })
end
local statusbars = {}
_G.CreateFrame = function(kind)
    local f = Fake()
    if kind == "StatusBar" then
        f.ranges, f.vals, f.rev = {}, {}, nil
        f.SetMinMaxValues = function(self, lo, hi) self.range = { lo, hi } end
        f.SetValue = function(self, v) self.val = v end
        f.SetReverseFill = function(self, r) self.rev = r end
        table.insert(statusbars, f)
    end
    return f
end
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
    RegisterEvent = function() end, Util = { IsSecret = function(v) return v == "secret" or v == "secretwert" end },
    RingThickness = { 0.06, 0.10, 0.16, 0.22, 0.30, 0.40 } }
assert(loadfile("UI/UnitRings.lua"))("Freewood-Core", FW)
local R = FW.UnitRings

-- Standard: alles aus
local o = R.Opts()
for _, k in ipairs({ "on", "dmana", "power", "health", "portrait", "hideBlizz", "hideFull", "unlock", "flip", "dmanaRev", "powerRev", "healthRev" }) do eq(o[k], false, "Standard aus: " .. k) end
eq(o.healthThick, 3, "Standard-Dicke Leben"); eq(o.powerThick, 3, "Standard-Dicke Ressource"); eq(o.dmanaThick, 3, "Standard-Dicke Mana")

near(R.Fraction(50, 100), 0.5, "Anteil"); near(R.Fraction(5, 0), 0, "Max 0"); near(R.Fraction("secret", 10), 0, "secret ignoriert")
near(R.Fraction(200, 100), 1, "oben begrenzt"); near(R.Fraction(-5, 100), 0, "unten begrenzt")
near(R.Elapsed(0.25, false, false), 0.75, "Standard: Rest wird gezeichnet")
near(R.Elapsed(0.25, true, false), 0.25, "reverse: Abgelaufenes")
near(R.Elapsed(0.25, false, true), 0.25, "flip")
near(R.Elapsed(0.25, true, true), 0.75, "reverse+flip")
local r, g = R.HealthColor(1); eq(g > r, true, "voll = gruen")
r, g = R.HealthColor(0.05); eq(r > g, true, "fast leer = rot")
eq(R.Level(0), 1, "Stufe unten begrenzt"); eq(R.Level(99), 6, "Stufe oben begrenzt"); eq(R.Level(nil), 3, "Standard 3")
near(R.Thickness(1), 0.06, "Dicke Stufe 1"); near(R.Thickness(6), 0.40, "Dicke Stufe 6")

-- Ebenen und Groessen
local function Opt(t) local x = { size = 100, dmanaThick = 3, powerThick = 3, healthThick = 3 }; for k, v in pairs(t) do x[k] = v end; return x end
R.druid = false
local lay = R.Layout(Opt({ power = true, health = true }))
eq(#lay.slots, 2, "zwei Ebenen"); eq(lay.slots[1], "power", "Ressource aussen"); eq(lay.slots[2], "health", "Leben innen")
eq(lay.diam.power, 100, "aeusserer Ring volle Groesse"); eq(lay.diam.health, 79, "innerer Ring kleiner")
lay = R.Layout(Opt({ dmana = true, power = true, health = true }))
eq(#lay.slots, 2, "Mana-Ebene nur fuer Druiden")
R.druid = true
lay = R.Layout(Opt({ dmana = true, power = true, health = true }))
eq(#lay.slots, 3, "drei Ebenen fuer Druiden"); eq(lay.slots[1], "dmana", "Mana ganz aussen")
eq(lay.diam.dmana > lay.diam.power and lay.diam.power > lay.diam.health, true, "von aussen nach innen kleiner")
local lyB = R.Layout(Opt({ dmana = true, power = true, health = true, dmanaThick = 6 }))
eq(lyB.diam.power < lay.diam.power, true, "dicker Aussenring -> naechster Ring kleiner")
local lyC = R.Layout(Opt({ power = true, health = true, healthThick = 6 }))
eq(lyC.portrait < R.Layout(Opt({ power = true, health = true })).portrait, true, "dicker Innenring -> Portrait kleiner")
lay = R.Layout(Opt({ health = true })); eq(lay.diam.health, 100, "ein Ring volle Groesse")
R.druid = false

-- ausgeschaltet: nichts gebaut, Blizzard unberuehrt
R.Apply(); eq(R.frame, nil, "aus: kein Frame"); eq(PlayerFrame.alpha, 1, "aus: Blizzard sichtbar")

-- zwei Ringe
o.on, o.health, o.power = true, true, true
R.Apply()
eq(R.frame ~= nil, true, "Frame gebaut"); eq(R.frame.shown, true, "sichtbar")
eq(R.rings.health.frame.shown, true, "Leben sichtbar"); eq(R.rings.power.frame.shown, true, "Ressource sichtbar"); eq(R.rings.dmana.frame.shown, false, "Mana-Ring aus")
local cdH = R.rings.health.cd
near(cdH.start, 5000 - 0.5 * 1000, "Leben 50% -> Rest 0.5")
hp = 25; R.Update(); near(cdH.start, 5000 - 0.75 * 1000, "Leben 25% -> abgelaufen 0.75")
local cnt = cdH.nCD; R.Update(); eq(cdH.nCD, cnt, "unveraenderter Wert setzt nicht neu")
hp = 0; R.Update(); eq(cdH.start ~= nil, true, "Leben 0 geht ohne Fehler")
hp = 100; R.Update(); near(cdH.start, 5000 - 0.002 * 1000, "voll wird begrenzt")
-- Richtung je Ring
o.healthRev = true; hp = 25; R.Update(); near(cdH.start, 5000 - 0.25 * 1000, "gegen den Uhrzeigersinn: Abgelaufenes"); o.healthRev = false

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
eq(R.rings.dmana.frame.shown, false, "Druide in Zauberform: Mana-Ring versteckt (Ressource zeigt Mana)")
pt = 3; R.Update()
eq(R.rings.dmana.frame.shown, true, "Druide in Katzengestalt: Mana-Ring sichtbar")
near(R.rings.dmana.cd.start, 5000 - 0.6 * 1000, "Mana-Ring zeigt Mana (400/1000)")
local fr = R.Read("power"); near(fr, 0.5, "Ressourcenring zeigt Energie (30/60)")
pt = 1; R.Update(); eq(R.rings.dmana.frame.shown, true, "Baer: Mana-Ring sichtbar")
o.dmana = false; R.druid = false; R.Apply()

-- secret-Werte und Testmodus
o.on, o.health, o.power, o.hideFull = true, true, false, false; R.Apply()
_G.UnitHealth = function() return "secret" end
_G.UnitHealthPercent = function() return 0.4 end
local fr2, src = R.Read("health"); near(fr2, 0.4, "secret: Prozent-Funktion"); eq(src, "prozent", "Quelle Prozent")
_G.UnitHealthPercent = nil
fr2, src = R.Read("health"); near(fr2, 0, "secret ohne Ausweg: 0"); eq(src, "secret", "Quelle secret")
R.force = 0.6; fr2, src = R.Read("health"); near(fr2, 0.6, "Testmodus"); eq(src, "test", "Quelle test"); R.force = nil

-- Segment-Ring
local o1, r1 = R.SegDirection(1); eq(o1, "HORIZONTAL", "Segment 1 (12 Uhr) horizontal"); eq(r1, false, "Segment 1 links nach rechts")
local o64, r64 = R.SegDirection(1, 64); eq(o64, "HORIZONTAL", "64: Segment 1 horizontal"); eq(r64, false, "64: links nach rechts")
local o64b, r64b = R.SegDirection(16, 64); eq(o64b, "VERTICAL", "64: Segment 16 (3 Uhr) senkrecht"); eq(r64b, true, "64: oben nach unten")
local o16, r16 = R.SegDirection(16); eq(o16, "HORIZONTAL", "32: Segment 16 (6 Uhr) waagerecht"); eq(r16, true, "6 Uhr: rechts nach links")
FW.RingSegments = {}; for l = 1, 6 do FW.RingSegments[l] = {}; for i = 1, 32 do FW.RingSegments[l][i] = { 10, 10, 20, 20 } end end
local ring = { frame = Fake(), cd = Fake(), track = Fake(), size = 100, level = 3 }
eq(R.SegMode(ring, true, 100, false), true, "Segmente an"); eq(#ring.segs, 32, "32 Segmente (Test-Daten)")
near(ring.segs[1].range[1], 0, "Segment 1 von 0"); near(ring.segs[1].range[2], 3.125, "Segment 1 bis 3.125"); near(ring.segs[32].range[2], 100, "Segment 32 bis 100")
local revCw = ring.segs[1].rev
R.SegMode(ring, true, 100, true)
near(ring.segs[1].range[1], 96.875, "gegen den Uhrzeigersinn: Segment 1 bekommt den letzten Bereich"); near(ring.segs[32].range[1], 0, "Segment 32 beginnt bei 0")
eq(ring.segs[1].rev, not revCw, "Fuellrichtung gedreht")
_G.UnitHealthPercent = function() return "secretwert" end
_G.CurveConstants = { ScaleTo100 = 1 }
eq(R.FeedSegs(ring, "health", 0.2, 0.8, 0.2, false), true, "Segmente gefuettert"); eq(ring.segs[5].val, "secretwert", "Wert unveraendert durchgereicht")
R.SegMode(ring, false); eq(ring.segOn, false, "Segmente aus")
_G.UnitHealthPercent = nil; _G.CurveConstants = nil

-- Dicke umstellen
local tr = { frame = Fake(), cd = Fake(), track = Fake(), size = 100, level = 3 }
local texCalls = {}; tr.track.SetTexture = function(_, p) table.insert(texCalls, p) end
R.SetLevel(tr, 5); eq(tr.level, 5, "Stufe gesetzt"); eq(texCalls[1], "Interface\\AddOns\\Freewood-Core\\Media\\Rings\\ring5.tga", "Hintergrund-Bild der Stufe")
local before = #texCalls; R.SetLevel(tr, 5); eq(#texCalls, before, "gleiche Stufe: nichts neu setzen")

local msgs = {}; FW.Print = function(_, t) table.insert(msgs, t) end
R.Debug(); eq(#msgs >= 3, true, "Debug gibt Zeilen aus")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
