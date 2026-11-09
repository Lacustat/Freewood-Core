-- Test Quest-Glitzern (texlua tests/questglow_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local cv = { graphicsOutlineMode = "2", outlineModeShowLootEffectWhenDisabled = "0" }
_G.GetCVar = function(k) return cv[k] end
_G.SetCVar = function(k, v) if cv[k] == nil then error("unbekannt") end cv[k] = v end
local UI = setmetatable({}, { __index = function() return function() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }), AddLocale = function() end, RegisterEvent = function() end }
assert(loadfile("UI/QuestGlow.lua"))("Freewood-Core", FW)
local QG = FW.QuestGlow
eq(QG.Apply(true), true, "einschalten"); eq(cv.graphicsOutlineMode, "0", "Umriss aus"); eq(cv.outlineModeShowLootEffectWhenDisabled, "1", "Glitzern an")
eq(QG.Opts().on, true, "gemerkt"); eq(QG.Opts().prev.outline, "2", "alter Wert gemerkt")
QG.Apply(true); eq(QG.Opts().prev.outline, "2", "zweites Einschalten ueberschreibt den alten Wert nicht")
eq(QG.Apply(false), true, "ausschalten"); eq(cv.graphicsOutlineMode, "2", "alter Umriss-Wert zurueck"); eq(cv.outlineModeShowLootEffectWhenDisabled, "0", "Glitzern zurueck")
eq(QG.Opts().on, false, "aus gemerkt")
cv.outlineModeShowLootEffectWhenDisabled = nil
eq(QG.Apply(true), false, "fehlende Einstellung: nichts aendern"); eq(cv.graphicsOutlineMode, "2", "unveraendert")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
