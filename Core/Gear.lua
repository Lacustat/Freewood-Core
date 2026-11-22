-- Freewood-Core: Ausrüstung nach Ereignis (0.64.0)
-- Regeln "Ereignis -> Freewood-Profil, Blizzard-Ausrüstungsset oder einzelner Gegenstand".
-- Endet ein Ereignis, wird die Regel inaktiv; es gilt die nächste aktive Regel, sonst die Standard-Ausrüstung.
-- Mehrere aktive Regeln: Rangliste, die obere gewinnt je Platz. Im Kampf nur Waffen, Schild/Nebenhand und Fernkampf
-- (Blizzard erlaubt dort keinen Rüstungswechsel), der Rest folgt nach dem Kampf.
-- Taint: nur ungeschützte Funktionen (PickupContainerItem, EquipCursorItem, PickupInventoryItem), keine Blizzard-Methoden
-- ersetzt, keine Ereignis-Nutzdaten gelesen (F-38 bis F-41).
-- Copyright (C) 2026 Lacustat. GPL-3.0-or-later.

local ADDON, FW = ...
local G = _G

local GS = {}
FW.Gear = GS

FW:AddLocale("enUS", {
    GEAR_TITLE = "Equipment by event", TAB_GEAR = "Equipment",
    GEAR_EV_swim = "Swimming", GEAR_EV_mount = "Mounted", GEAR_EV_fishing = "Fishing (key or /fwgear fish)",
    GEAR_EV_dungeon = "In a dungeon", GEAR_EV_raid = "In a raid dungeon", GEAR_EV_bg = "On a battleground",
    GEAR_EV_arena = "In an arena", GEAR_EV_combat = "In combat (weapons only)", GEAR_EV_city = "In a city or inn (resting)",
    GEAR_EV_zone = "In a zone", GEAR_EV_form = "Form / stance", GEAR_EV_group = "In a group", GEAR_EV_raidgroup = "In a raid group",
    GEAR_DEFAULT_LAST = "What I last wore without an event", GEAR_SET = "Blizzard set", GEAR_PROFILE = "Profile",
    GEAR_ITEM = "Single item",
    GEAR_MSG_ON = "Freewood: %s equipped.", GEAR_MSG_DEFAULT = "standard equipment",
    GEAR_MSG_MISSING = "Freewood: not found in your bags: %s", GEAR_MSG_COMBAT = "Freewood: the rest follows after combat.",
    GEAR_FISH_ON = "Freewood: fishing on.", GEAR_FISH_OFF = "Freewood: fishing off.",
    GEAR_FISH_NONE = "Freewood: there is no fishing rule yet (Equipment tab).",
    GEAR_NEW_PROFILE = "Profile %d",
})
FW:AddLocale("deDE", {
    GEAR_TITLE = "Ausrüstung nach Ereignis", TAB_GEAR = "Ausrüstung",
    GEAR_EV_swim = "Schwimmen", GEAR_EV_mount = "Reiten", GEAR_EV_fishing = "Angeln (Taste oder /fwgear angeln)",
    GEAR_EV_dungeon = "Im Dungeon", GEAR_EV_raid = "Im Schlachtzug-Dungeon", GEAR_EV_bg = "Auf dem Schlachtfeld",
    GEAR_EV_arena = "In der Arena", GEAR_EV_combat = "Im Kampf (nur Waffen)", GEAR_EV_city = "In Stadt oder Gasthaus (erholt)",
    GEAR_EV_zone = "In einer Zone", GEAR_EV_form = "Gestalt / Haltung", GEAR_EV_group = "In einer Gruppe", GEAR_EV_raidgroup = "In einer Schlachtzugsgruppe",
    GEAR_DEFAULT_LAST = "Was ich zuletzt ohne Ereignis trug", GEAR_SET = "Blizzard-Set", GEAR_PROFILE = "Profil",
    GEAR_ITEM = "Einzelner Gegenstand",
    GEAR_MSG_ON = "Freewood: %s angelegt.", GEAR_MSG_DEFAULT = "Standard-Ausrüstung",
    GEAR_MSG_MISSING = "Freewood: nicht in den Taschen gefunden: %s", GEAR_MSG_COMBAT = "Freewood: der Rest folgt nach dem Kampf.",
    GEAR_FISH_ON = "Freewood: Angeln an.", GEAR_FISH_OFF = "Freewood: Angeln aus.",
    GEAR_FISH_NONE = "Freewood: Es gibt noch keine Angel-Regel (Reiter Ausrüstung).",
    GEAR_NEW_PROFILE = "Profil %d",
})

GS.EVENTS = { "swim", "mount", "fishing", "dungeon", "raid", "bg", "arena", "combat", "city", "zone", "form", "group", "raidgroup" }
GS.COMBAT_SLOTS = { [16] = true, [17] = true, [18] = true }
GS.ORDER = { 16, 17, 18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19 }
GS.DEBOUNCE = { swim = 1.5 }      -- Schwimmen erst nach 1,5 s gleichem Zustand (Springen an der Wasseroberfläche)
GS.POLL = { swim = true, mount = true, zone = true, city = true }
GS.STEP = 0.15                    -- Abstand zwischen zwei Wechseln

-- Ausrüstungsort (GetItemInfoInstant) -> mögliche Plätze, der erste ist der Standard
GS.EQUIPLOC = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}

local function L() return FW.L end
local function Secret(v) return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok or Secret(a) then return nil end
    return a, b, c, d
end
local function Now() return Call(G.GetTime) or 0 end
local function After(s, fn) if G.C_Timer and G.C_Timer.After then G.C_Timer.After(s, fn) else fn() end end

------------------------------------------------------------------------
-- Daten je Charakter
------------------------------------------------------------------------

function GS.DB()
    local c = FW.chardb
    if type(c) ~= "table" then GS.mem = GS.mem or {} c = GS.mem end
    c.gear = c.gear or {}
    local d = c.gear
    d.profiles = d.profiles or {}
    d.rules = d.rules or {}
    d.snapshot = d.snapshot or {}
    d.default = d.default or "last"
    if d.on == nil then d.on = true end
    if d.msg == nil then d.msg = true end
    d.nextId = d.nextId or 1
    return d
end

local function NewId(d) local id = d.nextId d.nextId = id + 1 return id end

function GS.Profile(id)
    for _, p in ipairs(GS.DB().profiles) do if p.id == id then return p end end
end

------------------------------------------------------------------------
-- Getragene Ausrüstung und Taschen
------------------------------------------------------------------------

function GS.Equipped(slot)
    local id = Call(G.GetInventoryItemID, "player", slot)
    if not id then return nil end
    return { id = id, link = Call(G.GetInventoryItemLink, "player", slot) }
end

function GS.CurrentMap()
    local m = {}
    for _, slot in ipairs(GS.ORDER) do m[slot] = GS.Equipped(slot) end
    return m
end

local function ContainerInfo(bag, slot)
    local C = G.C_Container
    if C and C.GetContainerItemInfo then return Call(C.GetContainerItemInfo, bag, slot) end
end

local function NumSlots(bag)
    local C = G.C_Container
    if C and C.GetContainerNumSlots then return Call(C.GetContainerNumSlots, bag) or 0 end
    return Call(G.GetContainerNumSlots, bag) or 0
end

-- Gegenstand in den Taschen 0..4 suchen: genauer Link zuerst, sonst gleiche Item-ID
function GS.FindInBags(it)
    local byId
    for bag = 0, 4 do
        for slot = 1, NumSlots(bag) do
            local info = ContainerInfo(bag, slot)
            if type(info) == "table" and info.itemID == it.id then
                if it.link and info.hyperlink == it.link then return bag, slot, info.isLocked end
                byId = byId or { bag, slot, info.isLocked }
            end
        end
    end
    if byId then return byId[1], byId[2], byId[3] end
end

-- Gegenstand an einem anderen Platz getragen (Ringe, Schmuck, Waffen tauschen)
function GS.FindEquipped(it, notSlot)
    for _, slot in ipairs(GS.ORDER) do
        if slot ~= notSlot then
            local e = GS.Equipped(slot)
            if e and e.id == it.id and (not it.link or e.link == it.link) then return slot end
        end
    end
end

function GS.IsEquipped(slot, it)
    local e = GS.Equipped(slot)
    return e ~= nil and e.id == it.id
end

------------------------------------------------------------------------
-- Ziele: Profil, Blizzard-Set, einzelner Gegenstand -> Platz -> Gegenstand
------------------------------------------------------------------------

function GS.HasSets() local E = G.C_EquipmentSet return E and E.GetEquipmentSetIDs and E.GetEquipmentSetID and true or false end

function GS.SetNames()
    local list, E = {}, G.C_EquipmentSet
    if not GS.HasSets() then return list end
    local ids = Call(E.GetEquipmentSetIDs) or {}
    for _, id in ipairs(ids) do
        local name = Call(E.GetEquipmentSetInfo, id)
        if type(name) == "string" then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

function GS.SetMap(name)
    local m, E = {}, G.C_EquipmentSet
    if not GS.HasSets() then return m end
    local id = Call(E.GetEquipmentSetID, name)
    if not id then return m end
    local ids = Call(E.GetItemIDs, id) or {}
    local ignored = Call(E.GetIgnoredSlots, id) or {}
    for slot = 1, 19 do
        local iid = ids[slot]
        if not ignored[slot] and type(iid) == "number" and iid > 0 then m[slot] = { id = iid } end
    end
    return m
end

-- Ziel als Text: "p:<id>", "s:<Setname>", "i" (Gegenstand in rule.item), "last"
function GS.TargetMap(target, item)
    if type(target) ~= "string" then return {} end
    local kind, rest = target:match("^(%a+):(.*)$")
    if target == "i" then
        if type(item) == "table" and item.slot and item.id then return { [item.slot] = { id = item.id, link = item.link } } end
        return {}
    elseif target == "last" then
        return GS.DB().snapshot
    elseif kind == "p" then
        local p = GS.Profile(tonumber(rest))
        return p and p.slots or {}
    elseif kind == "s" then
        return GS.SetMap(rest)
    end
    return {}
end

function GS.TargetName(target, item)
    local Lx = L()
    if target == "i" then return (type(item) == "table" and item.link) or Lx.GEAR_ITEM end
    if target == "last" then return Lx.GEAR_DEFAULT_LAST end
    local kind, rest = (target or ""):match("^(%a+):(.*)$")
    if kind == "p" then local p = GS.Profile(tonumber(rest)) return p and p.name or "?" end
    if kind == "s" then return rest end
    return "?"
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

function GS.InstType()
    local inside, kind = Call(G.IsInInstance)
    if not inside then return "none" end
    return kind or "none"
end

local function ZoneMatch(arg)
    if type(arg) ~= "string" or arg == "" then return false end
    local want = arg:lower()
    for _, fn in ipairs({ G.GetRealZoneText, G.GetZoneText, G.GetSubZoneText, G.GetMinimapZoneText }) do
        local z = Call(fn)
        if type(z) == "string" and z ~= "" and z:lower() == want then return true end
    end
    return false
end

-- Zauber-ID der aktiven Gestalt (Druide, Krieger-Haltung, Schurke Verstohlenheit ...)
function GS.ActiveFormSpell()
    local n = Call(G.GetShapeshiftForm)
    if not n or n <= 0 then return nil end
    local _, _, _, spell = Call(G.GetShapeshiftFormInfo, n)
    return spell or ("n" .. n)
end

function GS.Forms()
    local list = {}
    local n = Call(G.GetNumShapeshiftForms) or 0
    for i = 1, n do
        local _, _, _, spell = Call(G.GetShapeshiftFormInfo, i)
        local name
        if spell then
            if G.C_Spell and G.C_Spell.GetSpellName then name = Call(G.C_Spell.GetSpellName, spell) end
            if not name and G.GetSpellInfo then name = Call(G.GetSpellInfo, spell) end
        end
        list[#list + 1] = { value = spell or ("n" .. i), text = name or ("#" .. i) }
    end
    return list
end

GS.CHECK = {
    swim = function() return Call(G.IsSwimming) end,
    mount = function() return Call(G.IsMounted) end,
    fishing = function() return GS.fishing end,
    dungeon = function() local t = GS.InstType() return t == "party" or t == "scenario" end,
    raid = function() return GS.InstType() == "raid" end,
    bg = function() return GS.InstType() == "pvp" end,
    arena = function() return GS.InstType() == "arena" end,
    combat = function() return GS.inCombat or Call(G.InCombatLockdown) end,
    city = function() return Call(G.IsResting) end,
    zone = ZoneMatch,
    form = function(arg) return arg ~= nil and GS.ActiveFormSpell() == arg end,
    group = function() return Call(G.IsInGroup) end,
    raidgroup = function() return Call(G.IsInRaid) end,
}

GS.deb = {}
function GS.State(ev, arg)
    local fn = GS.CHECK[ev]
    if not fn then return false end
    local raw = fn(arg) and true or false
    local wait = GS.DEBOUNCE[ev]
    if not wait then return raw end
    local now = Now()
    local d = GS.deb[ev]
    if not d then d = { val = raw, since = now, stable = raw } GS.deb[ev] = d end
    if raw ~= d.val then d.val = raw d.since = now end
    if d.val ~= d.stable and now - d.since >= wait then d.stable = d.val end
    return d.stable
end

-- aktive Regeln, die oberste zuerst
function GS.Active()
    local list = {}
    for _, r in ipairs(GS.DB().rules) do
        if r.on ~= false and GS.State(r.ev, r.arg) then list[#list + 1] = r end
    end
    return list
end

local function Sig(active)
    local t = {}
    for i, r in ipairs(active) do t[i] = tostring(r.id) end
    return table.concat(t, ",")
end

-- gewünschte Ausrüstung je Platz; src[slot] = Regel oder "default"
function GS.Desired(active)
    local d = GS.DB()
    local want, src = {}, {}
    for slot, it in pairs(GS.TargetMap(d.default)) do want[slot] = it src[slot] = "default" end
    for i = #active, 1, -1 do
        local r = active[i]
        for slot, it in pairs(GS.TargetMap(r.target, r.item)) do want[slot] = it src[slot] = r end
    end
    return want, src
end

------------------------------------------------------------------------
-- Anziehen (der Reihe nach, mit kleinem Abstand)
------------------------------------------------------------------------

GS.queue = {}

local function Say(text)
    if GS.DB().msg and FW.Print then print(text) end
end

function GS.Apply(want, label)
    local q = {}
    for _, slot in ipairs(GS.ORDER) do
        local it = want[slot]
        if type(it) == "table" and it.id and not GS.IsEquipped(slot, it) then q[#q + 1] = { slot = slot, it = it, tries = 0 } end
    end
    GS.queue = q
    GS.missing = {}
    GS.label = label
    GS.changed = 0
    GS.pending = false
    if #q == 0 then return false end
    GS.applyingUntil = Now() + 60
    if not GS.running then GS.running = true GS.Step() end
    return true
end

local function Finish()
    GS.running = false
    GS.applyingUntil = Now() + 1
    if GS.changed > 0 then Say(string.format(L().GEAR_MSG_ON, GS.label or L().GEAR_MSG_DEFAULT)) end
    for _, it in ipairs(GS.missing) do Say(string.format(L().GEAR_MSG_MISSING, it.link or ("#" .. it.id))) end
    if GS.pending then Say(L().GEAR_MSG_COMBAT) end
    if FW.Fire then pcall(FW.Fire, FW, "GEAR_CHANGED") end
end

function GS.Step()
    local job = table.remove(GS.queue, 1)
    if not job then return Finish() end
    if Call(G.UnitIsDeadOrGhost, "player") then
        GS.pending = true GS.queue = {} return Finish()
    end
    local fight = GS.inCombat or Call(G.InCombatLockdown)
    if fight and not GS.COMBAT_SLOTS[job.slot] then
        GS.pending = true
        return GS.Step()
    end
    if Call(G.CursorHasItem) then Call(G.ClearCursor) end
    if GS.IsEquipped(job.slot, job.it) then return GS.Step() end
    local bag, bslot, locked = GS.FindInBags(job.it)
    local other = (not bag) and GS.FindEquipped(job.it, job.slot)
    if locked and job.tries < 5 then
        job.tries = job.tries + 1
        table.insert(GS.queue, job)
    elseif bag then
        local C = G.C_Container
        local pick = (C and C.PickupContainerItem) or G.PickupContainerItem
        Call(pick, bag, bslot)
        Call(G.EquipCursorItem, job.slot)
        if Call(G.CursorHasItem) then Call(G.ClearCursor) end
        GS.changed = GS.changed + 1
    elseif other then
        Call(G.PickupInventoryItem, other)
        Call(G.PickupInventoryItem, job.slot)
        if Call(G.CursorHasItem) then Call(G.ClearCursor) end
        GS.changed = GS.changed + 1
    else
        GS.missing[#GS.missing + 1] = job.it
    end
    After(GS.STEP, GS.Step)
end

------------------------------------------------------------------------
-- Auswerten
------------------------------------------------------------------------

GS.lastSig = nil

-- Standard "zuletzt getragen": merken, solange keine Regel aktiv ist und wir nicht selbst wechseln
function GS.Snapshot()
    local d = GS.DB()
    if GS.running or Now() < (GS.applyingUntil or 0) then return end
    if GS.lastSig and GS.lastSig ~= "" then return end
    d.snapshot = GS.CurrentMap()
end

-- force: auch ohne Wechsel der aktiven Regeln anziehen (geänderte Regel, nach dem Kampf)
function GS.Evaluate(force)
    local d = GS.DB()
    if not d.on then GS.lastSig = "" return end
    local active = GS.Active()
    local sig = Sig(active)
    if sig == GS.lastSig and not force then return end
    local first = GS.lastSig == nil
    if (GS.lastSig == "" or first) and sig ~= "" and not GS.running then
        -- gleich wechselt eine Regel: vorher den Stand ohne Ereignis merken
        if not first or not next(d.snapshot) then d.snapshot = GS.CurrentMap() end
    end
    GS.lastSig = sig
    GS.active = active
    if first and sig == "" and not force then GS.Snapshot() return end
    local want = GS.Desired(active)
    local label
    if active[1] then label = GS.TargetName(active[1].target, active[1].item) end
    GS.Apply(want, label)
    if FW.Fire then pcall(FW.Fire, FW, "GEAR_STATE") end
end

local evalPending = false
function GS.Soon(force)
    GS.forceNext = GS.forceNext or force
    if evalPending then return end
    evalPending = true
    After(0.2, function()
        evalPending = false
        local f = GS.forceNext
        GS.forceNext = nil
        GS.Evaluate(f)
    end)
end

function GS.NeedsPoll()
    for _, r in ipairs(GS.DB().rules) do if r.on ~= false and GS.POLL[r.ev] then return true end end
    return false
end

------------------------------------------------------------------------
-- Bearbeiten (für die Oberfläche)
------------------------------------------------------------------------

function GS.SaveCurrent(name)
    local d = GS.DB()
    local id = NewId(d)
    local p = { id = id, name = (name and name ~= "") and name or string.format(L().GEAR_NEW_PROFILE, id), slots = GS.CurrentMap() }
    table.insert(d.profiles, p)
    return p
end

function GS.Overwrite(p) if p then p.slots = GS.CurrentMap() end end

function GS.DeleteProfile(id)
    local d = GS.DB()
    for i, p in ipairs(d.profiles) do if p.id == id then table.remove(d.profiles, i) break end end
    local key = "p:" .. tostring(id)
    if d.default == key then d.default = "last" end
    for _, r in ipairs(d.rules) do if r.target == key then r.on = false end end
end

function GS.AddRule(ev, arg, target, item)
    local d = GS.DB()
    local r = { id = NewId(d), ev = ev, arg = arg, target = target, item = item, on = true }
    table.insert(d.rules, r)
    GS.Soon(true)
    return r
end

function GS.DeleteRule(r)
    local d = GS.DB()
    for i, x in ipairs(d.rules) do if x == r then table.remove(d.rules, i) break end end
    GS.Soon(true)
end

function GS.MoveRule(r, dir)
    local list = GS.DB().rules
    for i, x in ipairs(list) do
        if x == r then
            local j = i + dir
            if j >= 1 and j <= #list then list[i], list[j] = list[j], list[i] GS.Soon(true) end
            return
        end
    end
end

function GS.IsActive(r)
    for _, x in ipairs(GS.active or {}) do if x == r then return true end end
    return false
end

-- sofort anziehen (Knopf "Anziehen" am Profil)
function GS.Wear(target, item)
    local label = GS.TargetName(target, item)
    return GS.Apply(GS.TargetMap(target, item), label)
end

function GS.ToggleFishing()
    local has = false
    for _, r in ipairs(GS.DB().rules) do if r.ev == "fishing" and r.on ~= false then has = true end end
    if not has then print(L().GEAR_FISH_NONE) return end
    GS.fishing = not GS.fishing
    Say(GS.fishing and L().GEAR_FISH_ON or L().GEAR_FISH_OFF)
    GS.Evaluate()
end

function Freewood_GearFishing() GS.ToggleFishing() end

-- Steckplatz für einen Gegenstand (aus dem Ausrüstungsort)
function GS.SlotsFor(itemID)
    if not itemID then return {} end
    local fn = (G.C_Item and G.C_Item.GetItemInfoInstant) or G.GetItemInfoInstant
    local _, _, _, loc = Call(fn, itemID)
    return GS.EQUIPLOC[loc or ""] or {}
end

------------------------------------------------------------------------
-- Ereignisse des Spiels (nur Anstoß, keine Nutzdaten)
------------------------------------------------------------------------

for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "PLAYER_UPDATE_RESTING", "UPDATE_SHAPESHIFT_FORM", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
    FW:RegisterEvent(ev, function() GS.Soon() end)
end
-- Gruppenänderungen feuern auf Schlachtfeldern ständig: dort nicht auswerten (F-41)
FW:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    if GS.InstType() == "pvp" then return end
    GS.Soon()
end)
FW:RegisterEvent("PLAYER_REGEN_DISABLED", function() GS.inCombat = true GS.Evaluate() end)
FW:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    GS.inCombat = false
    GS.Soon(GS.pending)
end)
FW:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
    if GS.lastSig == "" then After(0.5, GS.Snapshot) end
end)
FW:RegisterEvent("PLAYER_LOGIN", function()
    GS.Soon()
    if G.C_Timer and G.C_Timer.NewTicker then
        G.C_Timer.NewTicker(0.5, function()
            if not GS.DB().on or not GS.NeedsPoll() then return end
            GS.Evaluate()
        end)
    end
end)

G.SLASH_FREEWOODGEAR1 = "/fwgear"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList.FREEWOODGEAR = function(msg)
    msg = (msg or ""):lower()
    if msg == "angeln" or msg == "fish" or msg == "fishing" then GS.ToggleFishing() return end
    if FW.UI and FW.UI.Show then pcall(FW.UI.Show, FW.UI, "gear") end
end
