-- Test 0.61.0: Charakteransicht (Aufteilung je Bildschirm, Taschenraster, Werte, Suche, Aufbau, Taste C)
-- texlua tests/charsheet_test.lua
local events = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), settings = {} }
function FW:RegisterEvent(ev, fn) events[ev] = fn return true end
function FW:AddLocale(_, t) for k, v in pairs(t) do rawset(FW.L, k, v) end end
FW.Util = { IsSecret = function(v) return v == "SECRET" end }
_G.Freewood = FW
_G.unpack = _G.unpack or table.unpack

-- Attrappen für Rahmen
local M = {}
M.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.HookScript(f, k, fn) M.SetScript(f, k, fn) end
function M.Show(f) f.shown = true if f.scripts and f.scripts.OnShow then f.scripts.OnShow(f) end end
function M.Hide(f) f.shown = false end
function M.IsShown(f) return f.shown == true end
function M.SetShown(f, v) f.shown = v and true or false end
function M.GetWidth(f) return f.w or 0 end
function M.GetHeight(f) return f.h or 0 end
function M.SetSize(f, w, h) f.w, f.h = w, h end
function M.SetWidth(f, w) f.w = w end
function M.SetHeight(f, h) f.h = h end
function M.SetAllPoints(f, o) if o then f.w, f.h = o.w, o.h end end
function M.SetID(f, id) f.id = id end
function M.GetID(f) return f.id end
function M.GetParent(f) return f.parent end
function M.GetText(f) return f.text or "" end
function M.SetText(f, t) f.text = t end
function M.GetFrameLevel() return 1 end
function M.CreateTexture() return setmetatable({}, M) end
-- wie im Spiel: SetText auf eine Zeile ohne Schrift bricht ab ("Font not set", 0.61.1)
local FS = setmetatable({}, { __index = M })
FS.__index = function(t, k) if FS[k] then return FS[k] end return M.__index(t, k) end
function FS.SetText(f, t) if not f.font then error("FontString:SetText(): Font not set") end f.text = t end
function FS.SetFormattedText(f, ...) FS.SetText(f, string.format(...)) end
function M.CreateFontString(_, _, _, template) return setmetatable({ font = template ~= nil }, FS) end
local created = {}
_G.CreateFrame = function(kind, name, parent, template)
    local f = setmetatable({ kind = kind, parent = parent, template = template }, M)
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
_G.UIParent = setmetatable({ w = 1835, h = 768 }, M)   -- 3440 x 1440 bei Skalierung
_G.UISpecialFrames = {}
FW.UI = {
    SetFont = function(fs) fs.font = true end, Color = function() return 1, 1, 1 end,
    CreateCheckbox = function(_, _, g) g() return setmetatable({}, M) end,
    RegisterSettingsSection = function(_, id, def) FW.section = def end,
    CreateSection = function() local f = setmetatable({}, M) return f, { Add = function() end } end,
}

-- Spielwerte
_G.UnitStat = function(_, i) local t = { { 50, 55, 5, 0 }, { 120, 132, 12, 0 }, { 111, 111, 0, 0 }, { 68, 68, 0, 0 }, { 90, 81, 0, -9 } } return 0, t[i][2], t[i][3], t[i][4] end
_G.UnitHealthMax = function() return 1477 end
_G.UnitPowerMax = function() return 1710 end
_G.GetUnitSpeed = function() return 0, 9.1 end
_G.UnitDamage = function() return 92, 111 end
_G.UnitAttackPower = function() return 200, 79, 0 end
_G.UnitAttackSpeed = function() return 2.6 end
_G.GetCritChance = function() return 13.6 end
_G.UnitRangedDamage = function() return 3.0, 131, 164 end
_G.UnitRangedAttackPower = function() return 181, 0, 0 end
_G.GetRangedCritChance = function() return "SECRET" end     -- im Kampf geschützt
_G.UnitArmor = function() return 900, 942 end
_G.GetDodgeChance = function() return 8.9 end
_G.UnitResistance = function(_, i) return 0, i * 5 end
_G.UnitClass = function() return "Jägerin", "HUNTER" end
_G.UnitLevel = function() return 36 end
_G.UnitName = function() return "Pinky" end
_G.GetMoney = function() return 124783 end
_G.GetInventorySlotInfo = function(n) if n == "AmmoSlot" then return 0, "ammo" end return #n, "empty-" .. n end
local bagSlots = { [0] = 16, 10, 10, 0, 0, 0 }
_G.C_Container = {
    GetContainerNumSlots = function(b) return bagSlots[b] or 0 end,
    GetContainerItemInfo = function(b, s) if s == 1 then return { iconFileID = 1, stackCount = 5, hyperlink = "|cff1eff00|Hitem:1|h[Grüner Hut]|h|r", quality = 2 } end end,
}

assert(loadfile("UI/CharacterSheet.lua"))("Freewood-Core", FW)
local CS = FW.CharSheet
assert(CS and _G.Freewood_ToggleCharSheet, "geladen, Taste bekannt")

-- Aufteilung: 21:9 und 16:9, alles innerhalb, nichts überlappt
for _, size in ipairs({ { 1835, 768 }, { 1365, 768 }, { 1024, 768 } }) do
    local W, H = size[1], size[2]
    local lay = CS.ComputeLayout(W, H)
    local c, s, b = lay.char, lay.stats, lay.bags
    assert(c.x + c.w < s.x and s.x + s.w < b.x, "Spalten nebeneinander " .. W)
    assert(b.x + b.w <= W - 60 * lay.k + 1, "Taschen im Rahmen " .. W)
    assert(lay.model.y + lay.model.h + lay.S * 1.2 < H, "Waffenreihe passt " .. W)
    assert(b.w >= 6 * (lay.S + 4), "mindestens 6 Taschenspalten " .. W)
end
local wide, narrow = CS.ComputeLayout(1835, 768), CS.ComputeLayout(1365, 768)
assert(wide.bags.w > narrow.bags.w + 300, "Ultrawide: Taschen bekommen den Platz")

-- Taschenraster: scrollen (feste Größe) oder wachsen (alle sichtbar)
local cols, size = CS.BagGrid(400, 200, 80, 60, false)
assert(cols == 6 and size == 60, "scrollend: feste Größe")
cols, size = CS.BagGrid(400, 200, 80, 60, true)
assert(math.ceil(80 / cols) * (size + 4) - 4 <= 200 and size < 60, "wachsend: alle passen " .. size)

-- Werte
local st = CS.Stats()
assert(st[1].title == "Allgemein" and st[1].rows[1][2] == "1.477" and st[1].rows[3][2] == "130%", "Allgemein")
assert(st[2].rows[2][2]:find("132", 1, true) and st[2].rows[2][2]:find("40ff40", 1, true), "Beweglichkeit grün (Buff)")
assert(st[2].rows[5][2]:find("ff6060", 1, true), "Willenskraft rot (gesenkt)")
assert(st[3].title == "Fernkampf", "Jäger: Fernkampf zuerst")
assert(st[3].rows[1][2] == "131-164" and st[3].rows[2][2] == "181", "Fernkampfwerte")
assert(st[3].rows[3][2] == "–", "geschützter Wert = –")
local last = st[#st]
assert(last.title == "Widerstände" and last.rows[1][2] == "10", "Widerstände zuletzt")
local order = CS.ClassOrder("MAGE")
assert(order[1] == "spell", "Magier: Zauber zuerst")

-- Gold mit Münzsymbolen
local mt = CS.MoneyText(64333)
assert(mt:find("^6|T", 1) and mt:find("43|T", 1, true) and mt:find("33|T", 1, true), mt)
assert(CS.MoneyText(5):find("^5|T"), "nur Kupfer")

-- Suche
local info = { hyperlink = "|cff1eff00|Hitem:1|h[Grüner Hut]|h|r" }
assert(CS.MatchSearch(info, "hut") and not CS.MatchSearch(info, "schwert") and CS.MatchSearch(nil, ""), "Suche")

-- Aufbau und Öffnen
_G.Freewood_ToggleCharSheet()
local win = _G.FreewoodCharacterSheet
assert(win and win.shown, "Fenster offen")
assert(_G.UISpecialFrames[1] == "FreewoodCharacterSheet", "Esc schließt")
local slots = 0
for _, b in ipairs(win.slots) do if b then slots = slots + 1 end end
assert(slots == 20, "19 Plätze + Munition: " .. slots)
local bagButtons = 0
for _, f in ipairs(created) do if f.template == "ContainerFrameItemButtonTemplate" then bagButtons = bagButtons + 1 end end
assert(bagButtons == 36, "Blizzards Taschenknöpfe für alle Plätze: " .. bagButtons)
local p = win.bagButtons["1:3"].parent
assert(p.id == 1 and win.bagButtons["1:3"].id == 3, "Tasche und Platz über IDs (Blizzards Knopf liest sie selbst)")
local statRows = 0
for _, r in ipairs(win.statRows) do if r.shown and r.l.text and r.l.text ~= "" then statRows = statRows + 1 end end
assert(statRows > 20, "Werte eingetragen: " .. statRows)
assert(win.name.text == "Pinky" and win.level.text == "Stufe 36 · Jägerin", "Namensschild")
_G.Freewood_ToggleCharSheet()
assert(not win.shown, "zweiter Druck schließt")

-- Taste C (nur wenn eingeschaltet, nie im Kampf)
local over = {}
_G.SetOverrideBinding = function(_, _, key, cmd) over[key] = cmd end
_G.ClearOverrideBindings = function() for k in pairs(over) do over[k] = nil end end
_G.GetBindingKey = function(cmd) if cmd == "TOGGLECHARACTER0" then return "C" end end
local fight = false
_G.InCombatLockdown = function() return fight end
CS.ApplyBinding()
assert(over.C == nil, "Standard: C bleibt bei Blizzard")
CS.Opts().takeC = true
fight = true
CS.ApplyBinding()
assert(over.C == nil and CS.bindPending, "im Kampf aufgeschoben")
fight = false
events.PLAYER_REGEN_ENABLED()
assert(over.C == "FREEWOOD_CORE_CHARSHEET", "danach C auf die Charakteransicht")
CS.Opts().takeC = false
CS.ApplyBinding()
assert(over.C == nil, "wieder aus")

-- Einstellungen unter Design
assert(FW.section and FW.section.category == "design", "Einstellungen > Design")
FW.section.build(setmetatable({}, M))
print("charsheet_test: ok")
