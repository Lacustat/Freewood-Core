-- Freewood-Core: Itemvergleich im Tooltip (Shift gedrueckt halten)
-- Ueber einem Item (Tasche, Chat-Link, Haendler, Auktion ...) mit gedruecktem Shift steht unten im Tooltip, was besser (+)
-- oder schlechter (-) waere als das angelegte Item, was wegfaellt und was neu dazukommt (auch Equip-/Benutzen-Effekte).
-- Das Spiel zeigt das angelegte Item selbst daneben; hier kommen nur die Unterschiede dazu.
-- Schalter: Tooltip-Einstellung "tipCompare".

local FW = _G.Freewood
local T = FW and FW.Tooltips
if not FW or not T then
    return
end

local GREEN = { 0.35, 0.9, 0.35 }
local RED = { 0.95, 0.35, 0.35 }
local GREY = { 0.65, 0.65, 0.65 }

-- Platz-Nummern (Inventar) je Item-Typ; zwei Eintraege = beide Plaetze vergleichen
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
    INVTYPE_TABARD = { 19 },
}

local function IDOf(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

------------------------------------------------------------------------
-- Tooltip-Text lesen
------------------------------------------------------------------------

local scan
local function Scan()
    if not scan then
        scan = _G.CreateFrame("GameTooltip", "FreewoodScanTip", _G.UIParent, "GameTooltipTemplate")
        scan:SetOwner(_G.UIParent, "ANCHOR_NONE")
    end
    return scan
end

-- Zeilen eines Items (Link) oder des angelegten Platzes (slot) als Liste von Texten
local function Lines(link, slot)
    local tip = Scan()
    tip:ClearLines()
    tip:SetOwner(_G.UIParent, "ANCHOR_NONE")
    local ok
    if slot then ok = pcall(tip.SetInventoryItem, tip, "player", slot) else ok = pcall(tip.SetHyperlink, tip, link) end
    local out = {}
    if not ok then return out end
    for i = 1, tip:NumLines() do
        local fs = _G["FreewoodScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if type(t) == "string" and t ~= "" then out[#out + 1] = t end
    end
    return out
end

local function Num(s) return tonumber((tostring(s):gsub(",", "."))) end

-- Werte aus den Zeilen: stats[Name] = Zahl, extra[Name] = Zahl (Ruestung, Block, DPS), effects[Schluessel] = { text, zahl }
local function Parse(lines)
    local stats, extra, effects = {}, {}, {}
    for i, t in ipairs(lines) do
        local clean = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if i > 1 then
            local sign, n, name = clean:match("^([%+%-])(%d+) (.+)$")
            local dps = clean:match("%((%d+[%.,]?%d*) damage per second%)") or clean:match("%((%d+[%.,]?%d*) Schaden pro Sekunde%)")
            local armor, aname = clean:match("^(%d+) ([^%d%(%)]+)$")
            local prefix = clean:match("^(Equip:)") or clean:match("^(Use:)") or clean:match("^(Chance on hit:)")
                or clean:match("^(Anlegen:)") or clean:match("^(Benutzen:)") or clean:match("^(Trefferchance:)")
            if prefix then
                local key = clean:gsub("%d+[%.,]?%d*", "#")
                local first = clean:match("(%d+[%.,]?%d*)")
                effects[key] = { text = clean, n = first and Num(first) or nil }
            elseif sign and n and name and not name:find("^%(") then
                stats[name] = (stats[name] or 0) + (sign == "-" and -1 or 1) * tonumber(n)
            elseif dps then
                extra["DPS"] = Num(dps)
            elseif armor and aname and not clean:find("^%d+ %- %d+") then
                extra[aname] = tonumber(armor)
            end
        end
    end
    return stats, extra, effects
end

------------------------------------------------------------------------
-- Unterschiede
------------------------------------------------------------------------

local function Fmt(d)
    if math.abs(d - math.floor(d)) < 0.005 then return string.format("%+d", d) end
    return string.format("%+.1f", d)
end

-- Liste { text, farbe } der Unterschiede neu gegenueber alt
local function Diff(newLines, oldLines)
    local ns, ne, nf = Parse(newLines)
    local os, oe, of = Parse(oldLines)
    local out = {}
    local function Add(text, d) out[#out + 1] = { text, d >= 0 and GREEN or RED } end
    -- Ruestung, Block, DPS
    local keys = {}
    for k in pairs(ne) do keys[k] = true end
    for k in pairs(oe) do keys[k] = true end
    local ek = {}
    for k in pairs(keys) do ek[#ek + 1] = k end
    table.sort(ek)
    for _, k in ipairs(ek) do
        local d = (ne[k] or 0) - (oe[k] or 0)
        if math.abs(d) > 0.004 then Add(string.format("%s %s", Fmt(d), k), d) end
    end
    -- Werte
    local sk = {}
    for k in pairs(ns) do sk[k] = true end
    for k in pairs(os) do sk[k] = true end
    local names = {}
    for k in pairs(sk) do names[#names + 1] = k end
    table.sort(names)
    for _, k in ipairs(names) do
        local d = (ns[k] or 0) - (os[k] or 0)
        if d ~= 0 then Add(string.format("%s %s", Fmt(d), k), d) end
    end
    -- Effekte
    local ekeys = {}
    for k in pairs(nf) do ekeys[#ekeys + 1] = k end
    table.sort(ekeys)
    for _, k in ipairs(ekeys) do
        local n, o = nf[k], of[k]
        if not o then
            out[#out + 1] = { "+ " .. n.text, GREEN }
        elseif n.n and o.n and n.n ~= o.n then
            out[#out + 1] = { string.format("(%s) %s", Fmt(n.n - o.n), n.text), n.n > o.n and GREEN or RED }
        end
    end
    local okeys = {}
    for k in pairs(of) do okeys[#okeys + 1] = k end
    table.sort(okeys)
    for _, k in ipairs(okeys) do
        if not nf[k] then out[#out + 1] = { "- " .. of[k].text, RED } end
    end
    return out
end

------------------------------------------------------------------------
-- Anzeige
------------------------------------------------------------------------

local function Compare(tt, link)
    local id = IDOf(link)
    local info = id and FW.Util and FW.Util.GetItem and FW.Util.GetItem(id)
    local slots = info and info.equipLoc and SLOTS[info.equipLoc]
    if not slots then return end
    local L = FW.L
    local mine = Lines(link)
    local shown, worn = 0, 0
    for _, slot in ipairs(slots) do
        local eq = _G.GetInventoryItemLink and _G.GetInventoryItemLink("player", slot)
        local same = false
        if eq and IDOf(eq) == id then
            local ok, d0 = pcall(Diff, mine, Lines(eq, slot))
            same = (eq == link) or (ok and #d0 == 0)
        end
        if same then
            worn = worn + 1
            if worn == 1 then
                tt:AddLine(" ")
                tt:AddLine(L.TIP_CMP_WORN, 0.4, 1, 0.4)
            end
        elseif eq then
            shown = shown + 1
            local eqName = eq:match("%[(.-)%]") or "?"
            local d = Diff(mine, Lines(eq, slot))
            tt:AddLine(" ")
            tt:AddLine(string.format(L.TIP_CMP_VS, eqName), 1, 0.82, 0)
            if #d == 0 then
                tt:AddLine(L.TIP_CMP_SAME, GREY[1], GREY[2], GREY[3])
            else
                for _, e in ipairs(d) do tt:AddLine(e[1], e[2][1], e[2][2], e[2][3]) end
            end
        end
    end
    if shown == 0 and worn == 0 then
        tt:AddLine(L.TIP_CMP_EMPTY, GREY[1], GREY[2], GREY[3])
    end
    T.Info.cmpCount = (T.Info.cmpCount or 0) + 1
end

-- vom Tooltip-Hook (TooltipInfo.lua) bei jedem Item aufgerufen
function T.CompareHook(tt, link)
    if tt ~= _G.GameTooltip and tt ~= _G.ItemRefTooltip then return end
    local id = IDOf(link)
    local info = id and FW.Util and FW.Util.GetItem and FW.Util.GetItem(id)
    local equippable = info and info.equipLoc and SLOTS[info.equipLoc]
    tt.fwCmpLink = equippable and link or nil
    tt.fwShift = _G.IsShiftKeyDown and _G.IsShiftKeyDown() and true or false
    if not equippable or T.Get("tipCompare") ~= true or not tt.fwShift then return end
    pcall(Compare, tt, link)
end

-- Shift waehrend des Ueberfahrens: Tooltip neu aufbauen, wenn sich der Zustand aendert
local function OnModifier()
    if T.Get("tipCompare") ~= true then return end
    local shift = _G.IsShiftKeyDown and _G.IsShiftKeyDown() and true or false
    for _, tt in ipairs({ _G.GameTooltip, _G.ItemRefTooltip }) do
        if tt and tt.fwCmpLink and tt:IsShown() and tt.fwShift ~= shift then
            local link = tt.fwCmpLink
            tt.fwShift = shift   -- gegen Schleifen: der Hook setzt es beim Neuaufbau ohnehin neu
            if tt.RefreshData then
                pcall(tt.RefreshData, tt)                      -- neuer Aufbau mit denselben Daten
            elseif tt == _G.ItemRefTooltip then
                pcall(tt.SetHyperlink, tt, link)
            end
        end
    end
end
FW:RegisterEvent("MODIFIER_STATE_CHANGED", OnModifier, T)
