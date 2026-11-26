-- Test 0.68.0: Begleiter-Erfahrungsbalken (Daten, Text, Mitte als Standard, Shift-Ziehen, Ein/Aus)
-- texlua tests/petxp_test.lua
local events = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), chardb = {} }
function FW:RegisterEvent(ev, fn) events[ev] = fn end
function FW:AddLocale(loc, t) if loc == "deDE" then for k, v in pairs(t) do rawset(FW.L, k, v) end end end
FW.Util = { IsSecret = function(v) return v == "SECRET" end }
local M = {}
M.__index = function(t, k) if M[k] then return M[k] end if type(k) == "string" and k:match("^%u") then return function() end end end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.Show(f) f.shown = true end
function M.Hide(f) f.shown = false end
function M.SetText(f, t) f.text = t end
function M.SetPoint(f, ...) f.point = { ... } end
function M.ClearAllPoints(f) f.point = nil end
function M.GetPoint(f) return "TOPLEFT", nil, "BOTTOMLEFT", 100, 200 end
function M.StartMoving(f) f.moving2 = true end
function M.SetMinMaxValues(f, a, b) f.min, f.max = a, b end
function M.SetValue(f, v) f.value = v end
function M.CreateTexture() return setmetatable({}, M) end
function M.CreateFontString() return setmetatable({}, M) end
_G.CreateFrame = function() return setmetatable({}, M) end
_G.UIParent = setmetatable({}, M)
_G.GetLocale = function() return "deDE" end
local pet = { exists = true, cur = 1234, max = 5000, level = 23, name = "Krallenfuss" }
_G.UnitExists = function(u) return u == "pet" and pet.exists end
_G.GetPetExperience = function() return pet.cur, pet.max end
local me = { level = 30, class = "HUNTER", combat = false }
_G.UnitLevel = function(u) if u == "player" then return me.level end return pet.level end
_G.UnitClass = function() return "Jäger", me.class end
_G.InCombatLockdown = function() return me.combat end
_G.UnitName = function() return pet.name end
local shift = false
_G.IsShiftKeyDown = function() return shift end
function M.SetSize(f, w, h) f.w, f.h = w, h end
function M.SetWidth(f, w) f.w = w end
function M.SetHeight(f, h) f.h = h end
function M.IsShown(f) return f.shown end
local sliders = {}
FW.UI = { RegisterSettingsSection = function(_, id, def) FW.section = { id = id, def = def } end,
    CreateLabel = function(_, t) return setmetatable({ text = t }, M) end,
    CreateCheckbox = function(_, label, get, set) local c = setmetatable({ label = label, get = get, set = set }, M) return c end,
    CreateButton = function(_, t, w, h, fn) return setmetatable({ text = t, click = fn }, M) end,
    CreateSlider = function(_, w, o) local sl = setmetatable({ opts = o }, M)
        function sl:Refresh() if self.onText then self.onText(o.get()) end end
        sliders[#sliders + 1] = sl return sl end,
    CreateSection = function() return setmetatable({}, M), { Add = function() end } end,
}
assert(loadfile("UI/PetXP.lua"))("Freewood-Core", FW)
local PX = FW.PetXP
assert(PX.Num(1234567) == "1.234.567" and PX.Num(12) == "12", "Tausenderpunkt")
assert(PX.Text(PX.Data()) == "Krallenfuss  ·  Stufe 23  ·  1.234 / 5.000 (24 %)", PX.Text(PX.Data()))
events.UNIT_PET("player")
local f = PX.frame
assert(f and f.shown and f.bar.value == 1234 and f.bar.max == 5000, "Balken gezeigt")
assert(f.point[1] == "CENTER" and f.point[3] == "CENTER" and f.point[4] == 0, "Standard: Mitte")
-- ohne Shift nicht verschieben
f.scripts.OnDragStart(f)
assert(not f.moving2, "ohne Shift bleibt er")
shift = true
f.scripts.OnDragStart(f)
f.scripts.OnDragStop(f)
assert(f.moving2 and PX.Opts().point == "TOPLEFT" and PX.Opts().x == 100, "mit Shift verschoben und gemerkt")
PX.ApplyPos()
assert(f.point[1] == "TOPLEFT" and f.point[4] == 100, "Position angewandt")
_G.SlashCmdList.FREEWOODPETXP("reset")
assert(PX.Opts().point == nil and f.point[1] == "CENTER", "/fwpetxp reset: Mitte")
-- Erfahrung steigt
pet.cur = 2500
events.UNIT_PET_EXPERIENCE()
assert(f.bar.value == 2500 and f.text.text:find("50 %%"), "aktualisiert")
-- anderer Unit-Level ignoriert
pet.level = 24
events.UNIT_LEVEL("target")
assert(f.text.text:find("Stufe 23"), "fremde Einheit ignoriert")
events.UNIT_LEVEL("pet")
assert(f.text.text:find("Stufe 24"), "Begleiter-Stufe")
-- Höchststufe (max 0)
pet.max = 0
PX.Update()
assert(f.text.text == "Krallenfuss  ·  Stufe 24" and f.shown, "Höchststufe ohne Zahlen")
pet.max = 5000
-- kein Begleiter / Secret
pet.exists = false
PX.Update()
assert(not f.shown, "ohne Begleiter versteckt")
pet.exists = true
pet.cur = "SECRET"
PX.Update()
assert(not f.shown, "Secret: versteckt")
pet.cur = 10
-- aus
_G.SlashCmdList.FREEWOODPETXP("")
assert(PX.Opts().on == false and not f.shown, "abgeschaltet")
_G.SlashCmdList.FREEWOODPETXP("")
assert(f.shown, "wieder an")
-- 0.68.1: nur Jäger, nicht bei gleicher Stufe, im Kampf wählbar, Größe
assert(f.w == 260 and f.h == 18, "Standardgröße")
pet.level = 30
PX.Update()
assert(not f.shown, "Begleiter so hoch wie ich: unsichtbar")
pet.level = 29
PX.Update()
assert(f.shown, "eine Stufe darunter: sichtbar")
me.class = "WARRIOR"
PX.Update()
assert(not f.shown, "kein Jäger: unsichtbar")
me.class = "HUNTER"
PX.Update()
me.combat = true
events.PLAYER_REGEN_DISABLED()
assert(f.shown, "im Kampf sichtbar (Standard)")
PX.Opts().combat = false
PX.Update()
assert(not f.shown, "im Kampf aus")
me.combat = false
events.PLAYER_REGEN_ENABLED()
assert(f.shown, "nach dem Kampf wieder da")
-- Einstellungsfeld
local panel = PX.BuildPanel(setmetatable({}, M), 360)
assert(panel.fwHeight > 150 and #sliders == 2, "Feld mit zwei Reglern")
assert(sliders[1].opts.min == 120 and sliders[2].opts.max == 40, "Grenzen")
sliders[1].opts.set(400)
sliders[2].opts.set(24)
assert(PX.Opts().w == 400 and f.w == 400 and f.h == 24, "Größe übernommen")
panel.combat.set(true)
assert(PX.Opts().combat == true, "Haken Kampf")
PX.Opts().w = 9999
assert(PX.Opts().w == 600, "Breite begrenzt")
-- ohne Class-Modul: Abschnitt unter Oberfläche
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Freewood-Class" end }
events.PLAYER_LOGIN()
assert(FW.section == nil, "mit Class-Modul kein Abschnitt im Core")
_G.C_AddOns = { IsAddOnLoaded = function() return false end }
PX.RegisterFallback()
assert(FW.section and FW.section.def.category == "interface", "ohne Class-Modul unter Oberfläche")
io.write("petxp_test: ok\n")
