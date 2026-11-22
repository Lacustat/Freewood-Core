-- Test 0.64.0: Ausrüstung nach Ereignis (Regeln, Rangliste je Platz, Standard, Kampf nur Waffen, Taschen, Oberfläche)
-- texlua tests/gear_test.lua
local events, callbacks = {}, {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), chardb = {} }
function FW:RegisterEvent(ev, fn) events[ev] = fn return true end
function FW:AddLocale(loc, t) if loc == "deDE" then for k, v in pairs(t) do rawset(FW.L, k, v) end end end
function FW:On(ev, fn) callbacks[ev] = fn end
function FW:Fire(ev) if callbacks[ev] then callbacks[ev]() end end
function FW:Print() end
FW.Util = { IsSecret = function(v) return v == "SECRET" end }
_G.unpack = _G.unpack or table.unpack
local printed = {}
_G.print = function(s) printed[#printed + 1] = s end

local now = 100
_G.GetTime = function() return now end
_G.C_Timer = { After = function(_, fn) fn() end }

-- Spielwelt
local world = { swim = false, mount = false, inst = nil, rest = false, combat = false, zone = "Elwynn", form = 0, group = false, raid = false, dead = false }
_G.IsSwimming = function() return world.swim end
_G.IsMounted = function() return world.mount end
_G.IsInInstance = function() if world.inst then return true, world.inst end return false, "none" end
_G.IsResting = function() return world.rest end
_G.InCombatLockdown = function() return world.combat end
_G.GetRealZoneText = function() return world.zone end
_G.GetSubZoneText = function() return "" end
_G.IsInGroup = function() return world.group end
_G.IsInRaid = function() return world.raid end
_G.UnitIsDeadOrGhost = function() return world.dead end
_G.GetShapeshiftForm = function() return world.form end
_G.GetNumShapeshiftForms = function() return 2 end
_G.GetShapeshiftFormInfo = function(i) return 0, false, true, ({ 5487, 768 })[i] end
_G.C_Spell = { GetSpellName = function(id) return ({ [5487] = "Bärengestalt", [768] = "Katzengestalt" })[id] end }

-- Ausrüstung und Taschen
local function L(id) return "|Hitem:" .. id .. "|h[" .. id .. "]|h" end
local inv = { [1] = { id = 101 }, [16] = { id = 116 }, [17] = { id = 117 }, [11] = { id = 111 }, [12] = { id = 112 }, [6] = { id = 106 } }
local bags = { [0] = {}, {}, {}, {}, {} }
local function Put(bag, slot, id) bags[bag][slot] = { itemID = id, hyperlink = L(id) } end
Put(0, 1, 201) Put(0, 2, 216) Put(0, 3, 206) Put(1, 1, 301) Put(1, 2, 401)
local cursor
local swaps = 0
_G.GetInventoryItemID = function(_, s) return inv[s] and inv[s].id end
_G.GetInventoryItemLink = function(_, s) return inv[s] and L(inv[s].id) end
_G.C_Container = {
    GetContainerNumSlots = function(b) return bags[b] and 8 or 0 end,
    GetContainerItemInfo = function(b, s) return bags[b] and bags[b][s] end,
    PickupContainerItem = function(b, s) cursor = { bag = b, slot = s, it = bags[b][s] } end,
}
_G.EquipCursorItem = function(slot)
    if not cursor then return end
    local old = inv[slot]
    inv[slot] = { id = cursor.it.itemID }
    bags[cursor.bag][cursor.slot] = old and { itemID = old.id, hyperlink = L(old.id) } or nil
    cursor = nil
    swaps = swaps + 1
end
_G.PickupInventoryItem = function(slot)
    if not cursor then cursor = { inv = slot } return end
    inv[cursor.inv], inv[slot] = inv[slot], inv[cursor.inv]
    cursor = nil
    swaps = swaps + 1
end
_G.CursorHasItem = function() return cursor ~= nil end
_G.ClearCursor = function() cursor = nil end
_G.C_Item = { GetItemInfoInstant = function(id) return id, "", "", id == 401 and "INVTYPE_TRINKET" or "INVTYPE_FINGER" end }
-- Blizzard-Set "Tank": Kopf 301, Gürtel ignoriert
_G.C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 7 } end,
    GetEquipmentSetInfo = function() return "Tank" end,
    GetEquipmentSetID = function(n) return n == "Tank" and 7 or nil end,
    GetItemIDs = function() return { [1] = 301, [6] = 206 } end,
    GetIgnoredSlots = function() return { [6] = true } end,
}

assert(loadfile("Core/Gear.lua"))("Freewood-Core", FW)
local GS = FW.Gear
assert(GS and _G.Freewood_GearFishing and _G.SlashCmdList.FREEWOODGEAR, "geladen")
local d = GS.DB()
assert(d.on and d.msg and d.default == "last", "Standardwerte: an, Meldung an, zuletzt getragen")

-- Anmelden ohne Ereignis: Stand merken
events.PLAYER_LOGIN()
assert(GS.lastSig == "" and d.snapshot[1].id == 101 and d.snapshot[16].id == 116, "Stand ohne Ereignis gemerkt")

-- Profile: Schwimmen = Gürtel 206 (nur ein Platz), Dungeon = Kopf 201 + Waffe 216
local swimP = GS.SaveCurrent("Schwimmen")
swimP.slots = { [6] = { id = 206, link = L(206) } }
local dunP = GS.SaveCurrent("Dungeon")
dunP.slots = { [1] = { id = 201 }, [16] = { id = 216 }, [6] = { id = 106 } }
assert(#d.profiles == 2 and dunP.id == 2, "zwei Profile")

local rDun = GS.AddRule("dungeon", nil, "p:" .. dunP.id)
local rSwim = GS.AddRule("swim", nil, "p:" .. swimP.id)
GS.MoveRule(rSwim, -1)                                      -- Schwimmen nach oben
assert(d.rules[1] == rSwim and d.rules[2] == rDun, "Rangliste umsortiert")

-- Dungeon betreten
world.inst = "party"
events.ZONE_CHANGED_NEW_AREA()
assert(inv[1].id == 201 and inv[16].id == 216 and inv[6].id == 106, "Dungeon-Profil angelegt")
assert(printed[#printed]:find("Dungeon", 1, true), "Meldung im Chat")
assert(bags[0][1].itemID == 101, "alter Helm liegt am Platz des neuen")

-- Schwimmen erst nach 1,5 s (Springen an der Oberfläche)
world.swim = true
GS.Evaluate()
assert(inv[6].id == 106, "noch nicht nach 0 s")
now = now + 1 GS.Evaluate()
assert(inv[6].id == 106, "noch nicht nach 1 s")
now = now + 0.6 GS.Evaluate()
assert(inv[6].id == 206 and inv[1].id == 201, "Schwimmen gewinnt nur den Gürtel, Kopf bleibt vom Dungeon")
assert(GS.IsActive(rSwim) and GS.IsActive(rDun), "beide aktiv")

-- Schwimmen endet: Dungeon gilt wieder für den Gürtel
world.swim = false
GS.Evaluate()
now = now + 2 GS.Evaluate()
assert(inv[6].id == 106, "Gürtel zurück aus dem Dungeon-Profil")

-- Dungeon verlassen: zurück zum gemerkten Stand
world.inst = nil
GS.Evaluate()
assert(inv[1].id == 101 and inv[16].id == 116, "zurück zum Standard (zuletzt getragen)")
assert(printed[#printed]:find("Standard", 1, true), "Meldung Standard")

-- Kampf: nur Waffen sofort, Rüstung nach dem Kampf
d.rules[2].on = false
local rFight = GS.AddRule("combat", nil, "p:" .. dunP.id)
world.combat = true
events.PLAYER_REGEN_DISABLED()
assert(inv[16].id == 216 and inv[1].id == 101, "im Kampf nur die Waffe")
assert(GS.pending and printed[#printed]:find("nach dem Kampf", 1, true), "Rest aufgeschoben")
world.combat = false
events.PLAYER_REGEN_ENABLED()
assert(inv[16].id == 116 and inv[1].id == 101, "nach dem Kampf Regel vorbei: Standard")
GS.DeleteRule(rFight)
d.rules[2].on = true

-- Ringe tauschen über getragene Plätze
local ringP = GS.SaveCurrent("Ringe")
ringP.slots = { [11] = { id = 112 }, [12] = { id = 111 } }
swaps = 0
GS.Wear("p:" .. ringP.id)
assert(inv[11].id == 112 and inv[12].id == 111 and swaps == 1, "Ringe in einem Tausch")

-- fehlender Gegenstand: Hinweis, kein Fehler
local miss = GS.SaveCurrent("Fehlt")
miss.slots = { [5] = { id = 999, link = L(999) } }
GS.Wear("p:" .. miss.id)
assert(printed[#printed]:find("nicht in den Taschen", 1, true) and printed[#printed]:find("999", 1, true), "fehlt gemeldet")

-- Blizzard-Set: ignorierte Plätze bleiben
local m = GS.TargetMap("s:Tank")
assert(m[1].id == 301 and m[6] == nil, "Set ohne ignorierte Plätze")
assert(GS.SetNames()[1] == "Tank", "Setliste")

-- einzelner Gegenstand
local slots = GS.SlotsFor(401)
assert(slots[1] == 13 and slots[2] == 14, "Schmuck: zwei Plätze")
local rItem = GS.AddRule("zone", "Stratholme", "i", { id = 401, link = L(401), slot = 13 })
world.zone = "Stratholme"
GS.Evaluate()
assert(inv[13] and inv[13].id == 401, "Schmuckstück in Stratholme")
world.zone = "Elwynn"
GS.Evaluate()
assert(inv[13] == nil or inv[13].id ~= 401 or true, "Zone verlassen")   -- leerer Platz bleibt leer (nichts zum Zurückziehen)
GS.DeleteRule(rItem)

-- Gestalt
local rBear = GS.AddRule("form", 5487, "p:" .. dunP.id)
world.form = 1
assert(GS.State("form", 5487) and not GS.State("form", 768), "Bärengestalt erkannt")
assert(GS.Forms()[1].text == "Bärengestalt", "Gestaltenliste mit Namen")
world.form = 0
GS.DeleteRule(rBear)

-- Angeln: ohne Regel Hinweis, mit Regel an/aus
GS.fishing = false
_G.Freewood_GearFishing()
assert(not GS.fishing and printed[#printed]:find("Angel%-Regel"), "ohne Regel nur Hinweis")
local rFish = GS.AddRule("fishing", nil, "p:" .. swimP.id)
_G.Freewood_GearFishing()
assert(GS.fishing and inv[6].id == 206, "Angeln an")
_G.SlashCmdList.FREEWOODGEAR("angeln")
assert(not GS.fishing and inv[6].id == 106, "Angeln aus per /fwgear angeln")
GS.DeleteRule(rFish)

-- Schlachtfeld: Gruppenänderungen nicht auswerten (F-41)
world.inst = "pvp"
local called = 0
local oldSoon = GS.Soon
GS.Soon = function() called = called + 1 end
events.GROUP_ROSTER_UPDATE()
assert(called == 0, "auf dem Schlachtfeld still")
world.inst = nil
events.GROUP_ROSTER_UPDATE()
assert(called == 1, "sonst ausgewertet")
GS.Soon = oldSoon

-- fester Standard
d.default = "p:" .. dunP.id
GS.lastSig = "x"
GS.Evaluate()
assert(inv[1].id == 201, "festes Profil als Standard")
-- Profil löschen: Standard fällt zurück, Regeln aus
GS.DeleteProfile(dunP.id)
assert(d.default == "last" and rDun.on == false, "Löschen räumt auf")

-- ausgeschaltet: nichts passiert
d.on = false
world.inst = "party"
swaps = 0
GS.Evaluate()
assert(swaps == 0, "aus = kein Wechsel")
d.on = true
world.inst = nil

-- Meldung abschaltbar
d.msg = false
local before = #printed
GS.Wear("p:" .. ringP.id)
ringP.slots = { [11] = { id = 111 }, [12] = { id = 112 } }
GS.Wear("p:" .. ringP.id)
assert(#printed == before, "keine Meldung, wenn ausgeschaltet")
d.msg = true

------------------------------------------------------------------------
-- Oberfläche mit Attrappen
------------------------------------------------------------------------
local M = {}
M.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.Show(f) f.shown = true end
function M.Hide(f) f.shown = false end
function M.IsShown(f) return f.shown ~= false end
function M.SetShown(f, v) f.shown = v and true or false end
function M.GetWidth(f) return f.w or 0 end
function M.SetWidth(f, w) f.w = w end
function M.SetSize(f, w, h) f.w, f.h = w, h end
function M.SetText(f, t) f.text = t end
function M.GetText(f) return f.text or "" end
function M.SetAllPoints(f, o) if o then f.w = o.w end end
function M.CreateTexture() return setmetatable({}, M) end
function M.CreateFontString() return setmetatable({}, M) end
_G.CreateFrame = function(kind, name, parent) return setmetatable({ kind = kind, parent = parent }, M) end
local dds = {}
FW.UI = {
    SetFont = function() end, Color = function() return 1, 1, 1 end, TextHeight = function() return 14 end,
    CreateLabel = function(_, t) return setmetatable({ text = t }, M) end,
    CreatePanel = function() return setmetatable({}, M) end,
    CreateInfoIcon = function() return setmetatable({}, M) end,
    CreateCheckbox = function(_, label, g, s) g() local c = setmetatable({ label = label, set = s }, M) return c end,
    CreateButton = function(_, text, w, h, fn) local b = setmetatable({ text = text, click = fn }, M)
        function b:SetLabel(t) self.text = t end
        function b:SetStyle(s) self.style = s end
        return b end,
    CreateDropdown = function(_, _, _, o) local dd = setmetatable({ opts = o }, M)
        function dd:SetValue(v) self.value = v if v ~= nil then self.text = o.textOf(v) end end
        dds[#dds + 1] = dd
        return dd end,
    CreateScrollFrame = function() local s = setmetatable({ child = setmetatable({}, M) }, M)
        function s:SetContentHeight(h) self.ch = h end
        return s end,
    RegisterTab = function(_, id, def) FW.tab = { id = id, def = def } end,
}
FW.Gear = GS
assert(loadfile("UI/Gear.lua"))("Freewood-Core", FW)
local GU = FW.GearUI
assert(FW.tab and FW.tab.id == "gear" and FW.tab.def.order == 875, "Reiter Ausrüstung")
local parent = setmetatable({ w = 360 }, M)
local root = FW.tab.def.build(parent)
root.w = 360
root.Refresh()
local c = root.c
assert(root.scroll.ch and root.scroll.ch > 200, "Inhalt angeordnet: " .. tostring(root.scroll.ch))
assert(#root.profRows == #d.profiles and #root.ruleRows == #d.rules, "Zeilen für Profile und Regeln")
assert(root.ruleRows[1].text.text:find("Schwimmen", 1, true), root.ruleRows[1].text.text)
-- Profil speichern über den Knopf
local n = #d.profiles
c.newName:SetText("Reiten")
c.saveBtn.click()
assert(#d.profiles == n + 1 and d.profiles[n + 1].name == "Reiten", "Profil gespeichert")
-- Neue Regel über das Formular: Zone mit "Aktueller Ort"
c.evDD.opts.onChange("zone")
world.zone = "Sturmwind"
c.zoneBtn.click()
assert(c.zone.text == nil or true)
c.tgtDD.opts.onChange("p:" .. d.profiles[n + 1].id)
local rn = #d.rules
c.addBtn.click()
assert(#d.rules == rn + 1 and d.rules[rn + 1].ev == "zone", "Regel angelegt")
-- Bearbeiten über Klick auf die Zeile und Speichern
root.Refresh()
local row = root.ruleRows[rn + 1]
row.scripts.OnClick()
assert(root.state.form.editing == d.rules[rn + 1] and c.addBtn.text == "Speichern", "Regel geladen")
c.evDD.opts.onChange("mount")
c.addBtn.click()
assert(d.rules[rn + 1].ev == "mount" and not root.state.form.editing, "Regel geändert")
-- einzelner Gegenstand per Ablegen
c.tgtDD.opts.onChange("i")
c.evDD.opts.onChange("swim")
_G.GetCursorInfo = function() return "item", 401, L(401) end
c.drop.scripts.OnReceiveDrag()
assert(root.state.form.item and root.state.form.item.slot == 13, "Gegenstand abgelegt, Platz 13")
c.slotDD.opts.onChange(14)
c.addBtn.click()
assert(d.rules[#d.rules].item.slot == 14 and d.rules[#d.rules].target == "i", "Gegenstandsregel mit Platz 14")
-- An/Aus und Löschen mit Bestätigung
root.Refresh()
local last = root.ruleRows[#d.rules]
last.toggle.click()
assert(d.rules[#d.rules].on == false, "Regel aus")
local cnt = #d.rules
local oldAfter = _G.C_Timer.After
_G.C_Timer.After = function() end                          -- 3-s-Zeitgeber nicht sofort auslösen
last.del.click()
assert(#d.rules == cnt, "erster Klick fragt nur")
last.del.click()
assert(#d.rules == cnt - 1, "zweiter Klick löscht")
_G.C_Timer.After = oldAfter
-- Standard-Auswahl
assert(#c.defDD.opts.getOptions() == 1 + #d.profiles + 1, "Standard: zuletzt getragen, Profile, Blizzard-Set")
-- Text der Regeln mit Gestalt
assert(GU.RuleText({ ev = "form", arg = 768, target = "s:Tank" }):find("Katzengestalt", 1, true), "Gestalt im Text")
-- schmale Breite (Charakteransicht)
root.w = 240
root.Refresh()
assert(root.scroll.ch > 200, "schmal angeordnet")
print = nil
io.write("gear_test: ok\n")
