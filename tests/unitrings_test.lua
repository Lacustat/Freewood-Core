-- Test Ring-Anzeige (texlua tests/unitrings_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function near(a, b, m) n = n + 1; if math.abs(a - b) > 1e-6 then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function Fake()
    local o = { shown = false, alpha = 1, calls = {} }
    return setmetatable(o, { __index = function(t, k)
        if k == "CreateTexture" or k == "CreateMaskTexture" then return function() return Fake() end end
        if k == "GetAlpha" then return function() return t.alpha end end
        if k == "SetAlpha" then return function(_, a) t.alpha = a end end
        if k == "Show" then return function() t.shown = true end end
        if k == "Hide" then return function() t.shown = false end end
        if k == "SetScript" then return function(_, e, f) t[e] = f end end
        if k == "SetCooldown" then return function(_, s, d) t.start, t.dur = s, d; t.nCD = (rawget(t, "nCD") or 0) + 1 end end
        if k == "SetPoint" then return function(_, ...) t.point = { ... } end end
        if k == "GetCenter" then return function() return 100, 100 end end
        return function() end
    end })
end
local lastCD
_G.CreateFrame = function(kind) local f = Fake(); if kind == "Cooldown" then lastCD = lastCD or {}; table.insert(lastCD, f) end; return f end
_G.UIParent = Fake()
_G.GetTime = function() return 5000 end
local hp, hpmax, pw, pwmax, pt = 50, 100, 30, 60, 0
_G.UnitHealth = function() return hp end; _G.UnitHealthMax = function() return hpmax end
_G.UnitPower = function() return pw end; _G.UnitPowerMax = function() return pwmax end; _G.UnitPowerType = function() return pt end
_G.PlayerFrame = Fake()
local UI = setmetatable({}, { __index = function() return function() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }), AddLocale = function() end,
    RegisterEvent = function() end, Util = { IsSecret = function(v) return v == "secret" end } }
assert(loadfile("UI/UnitRings.lua"))("Freewood-Core", FW)
local R = FW.UnitRings

-- Standard: alles aus
local o = R.Opts()
for _, k in ipairs({ "on", "health", "power", "portrait", "hideBlizz", "hideFull", "unlock", "flip", "reverse" }) do eq(o[k], false, "Standard aus: " .. k) end

near(R.Fraction(50, 100), 0.5, "Anteil"); near(R.Fraction(5, 0), 0, "Max 0"); near(R.Fraction("secret", 10), 0, "secret ignoriert")
near(R.Fraction(200, 100), 1, "oben begrenzt"); near(R.Fraction(-5, 100), 0, "unten begrenzt")
near(R.Elapsed(0.25, false, false), 0.75, "Standard: Rest wird gezeichnet")
near(R.Elapsed(0.25, true, false), 0.25, "reverse: Abgelaufenes")
near(R.Elapsed(0.25, false, true), 0.25, "flip")
near(R.Elapsed(0.25, true, true), 0.75, "reverse+flip")
local r, g = R.HealthColor(1); eq(g > r, true, "voll = gruen")
r, g = R.HealthColor(0.05); eq(r > g, true, "fast leer = rot")
local lay = R.Layout({ size = 100, health = true, power = true }); eq(lay.both, true, "zwei Ringe"); eq(lay.inner, 78, "innerer Ring kleiner"); eq(lay.outer, 100, "aeusserer Ring")
lay = R.Layout({ size = 100, health = true, power = false }); eq(lay.inner, 100, "ein Ring volle Groesse")

-- ausgeschaltet: nichts gebaut, Blizzard unberuehrt
R.Apply(); eq(R.frame, nil, "aus: kein Frame"); eq(PlayerFrame.alpha, 1, "aus: Blizzard sichtbar")

-- beide Ringe an
o.on, o.health, o.power = true, true, true
R.Apply()
eq(R.frame ~= nil, true, "Frame gebaut"); eq(R.frame.shown, true, "sichtbar")
eq(R.healthRing, R.inner, "Leben innen"); eq(R.powerRing, R.outer, "Ressource aussen")
local cdHealth = R.inner.cd
near(cdHealth.start, 5000 - 0.5 * 1000, "Leben 50% -> Rest 0.5")
hp = 25; R.Update(); near(cdHealth.start, 5000 - 0.75 * 1000, "Leben 25% -> abgelaufen 0.75")
local cnt = cdHealth.nCD; R.Update(); eq(cdHealth.nCD, cnt, "unveraenderter Wert setzt nicht neu")
hp = 0; R.Update(); eq(cdHealth.start ~= nil, true, "Leben 0 geht ohne Fehler")
hp = 100; R.Update(); near(cdHealth.start, 5000 - 0.002 * 1000, "voll wird begrenzt")

-- nur ein Ring: volle Groesse, Leben aussen
o.power = false; R.Apply(); eq(R.healthRing, R.outer, "ein Ring aussen"); eq(R.powerRing, nil, "kein Ressourcenring")

-- Nur-wenn-nicht-voll
o.hideFull = true; hp = 100; R.Update(); eq(R.frame.alpha, 0, "voll -> unsichtbar")
hp = 80; R.Update(); eq(R.frame.alpha, 1, "nicht voll -> sichtbar")
o.unlock = true; hp = 100; R.Update(); eq(R.frame.alpha, 1, "Verschieben zeigt immer")
o.unlock = false

-- Blizzard-Spielerfenster
o.hideBlizz = true; R.Apply(); eq(PlayerFrame.alpha, 0, "Blizzard ausgeblendet")
PlayerFrame.alpha = 1; R.Update(); eq(PlayerFrame.alpha, 0, "wird wieder durchgesetzt")
o.hideBlizz = false; R.Apply(); eq(PlayerFrame.alpha, 1, "Blizzard zurueck")
o.hideBlizz = true; R.Apply(); o.on = false; R.Apply(); eq(PlayerFrame.alpha, 1, "Ringe aus: Blizzard zurueck"); eq(R.frame.shown, false, "Ringe aus: versteckt")

-- Position
o.on = true; o.x, o.y = 40, -10; R.Apply(); eq(R.frame.point[4], 40, "Lage x"); eq(R.frame.point[5], -10, "Lage y")

-- secret-Werte und Testmodus
o.on, o.health, o.power, o.hideFull = true, true, false, false; R.Apply()
_G.UnitHealth = function() return "secret" end
_G.UnitHealthPercent = function() return 0.4 end
local fr, src = R.Read("health"); near(fr, 0.4, "secret: Prozent-Funktion"); eq(src, "prozent", "Quelle Prozent")
_G.UnitHealthPercent = nil
fr, src = R.Read("health"); near(fr, 0, "secret ohne Ausweg: 0"); eq(src, "secret", "Quelle secret")
R.force = 0.6; fr, src = R.Read("health"); near(fr, 0.6, "Testmodus"); eq(src, "test", "Quelle test"); R.force = nil
local msgs = {}; FW.Print = function(_, t) table.insert(msgs, t) end
R.Debug(); eq(#msgs >= 3, true, "Debug gibt Zeilen aus")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
