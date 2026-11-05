-- Freewood-Core: Zusatzinfos in Tooltips (Reiter "Einstellungen" -> "Tooltips")
--   tipVendor  Haendlerpreis des Items (nur, wenn das Spiel selbst keinen Preis zeigt)
--   tipQuest   Quest-Fortschritt am Gegner oder Objekt unter der Maus (nur, wenn das Spiel keinen zeigt)
--   tipCompare Shift-Vergleich mit dem angelegten Item (TooltipCompare.lua)
-- Weitere Module haengen Zeilen an Gegner-Tooltips mit FW.Tooltips.AddUnitLine(function(tt, name, npcID) ... end).
-- Jeder Teil ist einzeln abschaltbar. Die Werte stehen in den Core-Einstellungen (FW.settings.tooltips).
--
-- Anbindung: bevorzugt TooltipDataProcessor (neue Tooltips), sonst HookScript (OnTooltipSetItem/-Unit).
-- Alles laeuft geschuetzt (pcall); geheime Werte (secret values) werden nie gerechnet oder verglichen.

local FW = _G.Freewood
local T = FW and FW.Tooltips
if not FW or not T then
    return
end

local Tip = {}
T.Info = Tip

local function On(key) return T.Get(key) == true end
local function Clean(v)
    if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end
    return v
end
local function Str(v)
    v = Clean(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

function Tip.Money(c)
    c = math.floor((c or 0) + 0.5)
    if _G.GetCoinTextureString then
        local ok, text = pcall(_G.GetCoinTextureString, c)
        if ok and type(text) == "string" then return text end
    end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, k) end
    if s > 0 then return string.format("%ds %dc", s, k) end
    return string.format("%dc", k)
end

local function ItemIDFromLink(link)
    link = Str(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Hat das Spiel schon eine Zeile dieser Art? (Verkaufspreis, Questziel, Questname); data.lines kommt vom TooltipDataProcessor
local function HasLineType(data, ...)
    local E = _G.Enum and _G.Enum.TooltipDataLineType
    if not (E and type(data) == "table" and type(data.lines) == "table") then return false end
    for _, name in ipairs({ ... }) do
        local want = E[name]
        if want ~= nil then
            for _, line in ipairs(data.lines) do
                if type(line) == "table" and Clean(line.type) == want then return true end
            end
        end
    end
    return false
end

-- Hat der Tooltip schon eine Zeile mit diesem Text-Anfang? (Fallback ohne Zeilenarten)
local function HasTextLine(tt, prefix)
    if not (prefix and tt and tt.NumLines) then return false end
    local name = tt.GetName and tt:GetName()
    if not name then return false end
    local ok, found = pcall(function()
        for i = 2, tt:NumLines() do
            local fs = _G[name .. "TextLeft" .. i]
            local t = fs and fs.GetText and fs:GetText()
            t = Str(t)
            if t and t:find(prefix, 1, true) == 1 then return true end
        end
        return false
    end)
    return ok and found or false
end

-- Stapelgroesse des Items unter der Maus (Taschenfeld), sonst 1. Nur wenn das Feld dasselbe Item enthaelt.
local function HoverCount(link)
    local ok, count = pcall(function()
        local f
        if _G.GetMouseFoci then
            local list = _G.GetMouseFoci()
            f = list and list[1]
        elseif _G.GetMouseFocus then
            f = _G.GetMouseFocus()
        end
        if not f then return 1 end
        local parent = f.GetParent and f:GetParent()
        if not (parent and parent.GetID and f.GetID) then return 1 end
        local bag, slot = parent:GetID(), f:GetID()
        local l, n
        local CC = _G.C_Container
        if CC and CC.GetContainerItemInfo then
            local info = CC.GetContainerItemInfo(bag, slot)
            if type(info) == "table" then l, n = info.hyperlink, info.stackCount end
        elseif _G.GetContainerItemLink and _G.GetContainerItemInfo then
            l = _G.GetContainerItemLink(bag, slot)
            local _, c = _G.GetContainerItemInfo(bag, slot)
            n = c
        end
        if l and ItemIDFromLink(l) == ItemIDFromLink(link) and tonumber(n) and n > 1 then return n end
        return 1
    end)
    return ok and count or 1
end

------------------------------------------------------------------------
-- Haendlerpreis
------------------------------------------------------------------------

local function AddVendor(tt, link, data)
    if not On("tipVendor") or not tt or not tt.AddLine then return end
    local id = ItemIDFromLink(link)
    if not id then return end
    if tt.fwVendID == id then return end
    -- beim Haendler und bei Tooltips mit eigenem Verkaufspreis zeigt das Spiel den Preis selbst
    if _G.MerchantFrame and _G.MerchantFrame.IsShown and _G.MerchantFrame:IsShown() then return end
    if HasLineType(data, "SellPrice") then return end
    if (tonumber(tt.shownMoneyFrames) or 0) > 0 then return end
    if _G.SELL_PRICE and HasTextLine(tt, _G.SELL_PRICE) then return end
    local info = FW.Util and FW.Util.GetItem and FW.Util.GetItem(id)
    local price = info and tonumber(info.sellPrice) or 0
    if price <= 0 then return end
    tt.fwVendID = id
    Tip.fired.vendor = Tip.fired.vendor + 1
    local L = FW.L
    local n = tt == _G.GameTooltip and HoverCount(link) or 1
    if n > 1 then
        tt:AddLine(string.format(L.TIP_VENDOR_STACK, Tip.Money(price), n, Tip.Money(price * n)), 1, 0.82, 0)
    else
        tt:AddLine(string.format(L.TIP_VENDOR, Tip.Money(price)), 1, 0.82, 0)
    end
end

------------------------------------------------------------------------
-- Quest-Fortschritt am Gegner oder Objekt
------------------------------------------------------------------------

local logCache, logAt = nil, -10
-- { { qid, title, objs = { { text, finished, kind } } } } fuer alle angenommenen Quests (1 s gemerkt)
local function LogObjectives()
    local now = _G.GetTime and _G.GetTime() or 0
    if logCache and now - logAt < 1 then return logCache end
    local out = {}
    local QL = _G.C_QuestLog
    local P = T.questProvider       -- optional (Quest-Modul): AcceptedSet() und TargetsOf(qid)
    if P and P.AcceptedSet and QL and QL.GetQuestObjectives then
        for qid in pairs(P.AcceptedSet()) do
            local ok, objs = pcall(QL.GetQuestObjectives, qid)
            if ok and type(objs) == "table" and #objs > 0 then
                local title
                if QL.GetTitleForQuestID then
                    local ok2, t = pcall(QL.GetTitleForQuestID, qid)
                    if ok2 and type(t) == "string" then title = t end
                end
                local list = {}
                for _, o in ipairs(objs) do
                    if type(o.text) == "string" and o.text ~= "" then
                        list[#list + 1] = { text = o.text, finished = o.finished and true or false, kind = o.type }
                    end
                end
                if #list > 0 then out[#out + 1] = { qid = qid, title = title or ("#" .. qid), objs = list } end
            end
        end
    elseif QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.GetQuestObjectives then
        -- ohne Quest-Modul: normales Questlog ueber C_QuestLog
        local n = QL.GetNumQuestLogEntries() or 0
        for i = 1, n do
            local info = QL.GetInfo(i)
            if type(info) == "table" and not info.isHeader and info.questID then
                local ok, objs = pcall(QL.GetQuestObjectives, info.questID)
                if ok and type(objs) == "table" then
                    local list = {}
                    for _, o in ipairs(objs) do
                        if type(o.text) == "string" and o.text ~= "" then
                            list[#list + 1] = { text = o.text, finished = o.finished and true or false, kind = o.type }
                        end
                    end
                    if #list > 0 then out[#out + 1] = { qid = info.questID, title = info.title or ("#" .. info.questID), objs = list } end
                end
            end
        end
    end
    table.sort(out, function(a, b) return tostring(a.title) < tostring(b.title) end)
    logCache, logAt = out, now
    return out
end

-- Quests, die zu diesem Gegner oder Objekt gehoeren, mit den passenden Zielen
local function QuestLinesFor(name, npcID)
    local out = {}
    local lname = name and name:lower() or nil
    local TM = T.questProvider
    for _, q in ipairs(LogObjectives()) do
        local hits = {}
        local isTarget = npcID and q.qid and TM and TM.TargetsOf and TM.TargetsOf(q.qid)[npcID] or false
        for _, o in ipairs(q.objs) do
            local byName = lname and o.text:lower():find(lname, 1, true) ~= nil
            local byDrop = isTarget and o.kind == "item"
            if (byName or byDrop) then hits[#hits + 1] = o end
        end
        if #hits > 0 then out[#out + 1] = { title = q.title, objs = hits } end
    end
    return out
end

local function AddQuest(tt, name, npcID, data)
    if not On("tipQuest") or not tt or not tt.AddLine or not name then return end
    if tt.fwQuestName == name then return end
    if HasLineType(data, "QuestObjective", "QuestTitle", "QuestPlayer") then return end   -- das Spiel zeigt es selbst
    local list = QuestLinesFor(name, npcID)
    if #list == 0 then return end
    tt.fwQuestName = name
    Tip.fired.quest = Tip.fired.quest + 1
    for _, e in ipairs(list) do
        tt:AddLine(e.title, 1, 0.82, 0)
        for _, o in ipairs(e.objs) do
            if o.finished then tt:AddLine("  " .. o.text, 0.4, 0.9, 0.4) else tt:AddLine("  " .. o.text, 1, 1, 1) end
        end
    end
end

------------------------------------------------------------------------
-- Anbindung an die Tooltips
------------------------------------------------------------------------

T.unitLines = T.unitLines or {}
function T.AddUnitLine(fn) T.unitLines[#T.unitLines + 1] = fn end
T.Money = Tip.Money

Tip.fired = { item = 0, unit = 0, object = 0, vendor = 0, quest = 0 }

local function IsMain(tt) return tt == _G.GameTooltip or tt == _G.ItemRefTooltip end

-- Item: link oder nil
local function OnItem(tt, link, data)
    Tip.fired.item = Tip.fired.item + 1
    if not link then return end
    if IsMain(tt) then pcall(AddVendor, tt, link, data) end
    if T.CompareHook then pcall(T.CompareHook, tt, link) end
end

-- Gegner: Name und Nummer
local function OnUnit(tt, name, guid, data)
    if tt ~= _G.GameTooltip then return end
    Tip.fired.unit = Tip.fired.unit + 1
    name = Str(name)
    if not name then return end
    guid = Str(guid)
    local npcID
    if guid then
        if guid:sub(1, 7) == "Player-" then return end
        npcID = FW.Util and FW.Util.GetNpcID and FW.Util.GetNpcID(guid) or nil
    end
    pcall(AddQuest, tt, name, npcID, data)
    for _, fn in ipairs(T.unitLines) do pcall(fn, tt, name, npcID) end
end

-- Objekte (Truhen, Kraeuter)
local function OnObject(tt, name, data)
    if tt ~= _G.GameTooltip then return end
    name = Str(name)
    if not name then return end
    Tip.fired.object = Tip.fired.object + 1
    pcall(AddQuest, tt, name, nil, data)
end

local function FirstLine(data)
    if type(data) ~= "table" then return nil end
    if _G.TooltipUtil and _G.TooltipUtil.SurfaceArgs then pcall(_G.TooltipUtil.SurfaceArgs, data) end
    local line = type(data.lines) == "table" and data.lines[1] or nil
    return type(line) == "table" and line.leftText or nil
end

local function ClearFlags(self)
    self.fwVendID, self.fwQuestName, self.fwCmpLink, self.fwShift, self.fwDropID = nil, nil, nil, nil, nil
end

local installed
local function Install()
    if installed then return end
    installed = true
    local TDP, E = _G.TooltipDataProcessor, _G.Enum and _G.Enum.TooltipDataType
    if TDP and TDP.AddTooltipPostCall and E and E.Item then
        Tip.mode = "processor"
        pcall(TDP.AddTooltipPostCall, E.Item, function(tt, data)
            local link
            if type(data) == "table" and not (FW.Util.IsSecret and FW.Util.IsSecret(data)) then
                if _G.TooltipUtil and _G.TooltipUtil.SurfaceArgs then pcall(_G.TooltipUtil.SurfaceArgs, data) end
                link = Str(data.hyperlink) or (Clean(data.id) and ("item:" .. tostring(data.id))) or nil
            end
            OnItem(tt, link, data)
        end)
        if E.Unit then
            pcall(TDP.AddTooltipPostCall, E.Unit, function(tt, data)
                if type(data) ~= "table" or (FW.Util.IsSecret and FW.Util.IsSecret(data)) then return end
                local name = FirstLine(data)
                if not name and tt.GetUnit then
                    local ok, n = pcall(tt.GetUnit, tt)
                    if ok then name = n end
                end
                OnUnit(tt, name, data.guid, data)
            end)
        end
        if E.Object then
            pcall(TDP.AddTooltipPostCall, E.Object, function(tt, data)
                if type(data) ~= "table" or (FW.Util.IsSecret and FW.Util.IsSecret(data)) then return end
                OnObject(tt, FirstLine(data), data)
            end)
        end
        for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
            local tt = _G[name]
            if tt and tt.HookScript then pcall(tt.HookScript, tt, "OnTooltipCleared", ClearFlags) end
        end
        return
    end
    -- altes Verfahren: Skripte der Tooltips
    Tip.mode = "scripts"
    for _, tt in ipairs({ _G.GameTooltip, _G.ItemRefTooltip, _G.ShoppingTooltip1, _G.ShoppingTooltip2 }) do
        if tt and tt.HookScript then
            pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self)
                local ok, _, link = pcall(self.GetItem, self)
                if ok and link then
                    OnItem(self, link, nil)
                    self:Show()
                end
            end)
            pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(self)
                local ok, name, unit = pcall(self.GetUnit, self)
                if not ok or not name then return end
                local guid = unit and _G.UnitGUID and _G.UnitGUID(unit) or nil
                if unit and _G.UnitIsPlayer and _G.UnitIsPlayer(unit) then return end
                OnUnit(self, name, guid, nil)
                self:Show()
            end)
            pcall(tt.HookScript, tt, "OnTooltipCleared", ClearFlags)
        end
    end
    local gt = _G.GameTooltip
    if gt and gt.HookScript then
        pcall(gt.HookScript, gt, "OnShow", function(self)
            if self:GetUnit() or (self.GetItem and self:GetItem()) or self.fwQuestName then return end
            local left = _G.GameTooltipTextLeft1
            local name = left and left:GetText()
            if type(name) == "string" and name ~= "" and (_G.UnitExists and not _G.UnitExists("mouseover")) then
                OnObject(self, name, nil)
                if self.fwQuestName then self:Show() end
            end
        end)
    end
end

Install()
FW:On("QUEST_TIP_CHANGED", function() logCache = nil end, Tip)
FW:On("CODEX_CHANGED", function(_, kind) if kind == "quest" then logCache = nil end end, Tip)
FW:RegisterEvent("QUEST_LOG_UPDATE", function() logCache = nil end, Tip)

-- /fwtip: Pruefung der Tooltip-Anbindung (wie oft die Hooks gefeuert haben)
_G.SLASH_FREEWOODTIP1 = "/fwtip"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList["FREEWOODTIP"] = function()
    local f = Tip.fired
    FW:Print(string.format("Tooltips (%s): Item %dx, Gegner %dx, Objekt %dx; Haendlerzeile %dx, Quest-Zeilen %dx, Vergleich %dx. TooltipDataProcessor: %s",
        tostring(Tip.mode), f.item, f.unit, f.object, f.vendor, f.quest, (Tip.cmpCount or 0), tostring(_G.TooltipDataProcessor ~= nil)))
end

-- Optionen (die Codex-abhaengigen meldet das Codex-Modul selbst an)
T.RegisterOption("tipVendor", "TIP_OPT_VENDOR", { order = 10 })
T.RegisterOption("tipQuest", "TIP_OPT_QUEST", { order = 20 })
T.RegisterOption("tipCompare", "TIP_OPT_COMPARE", { order = 30, available = function() return T.CompareHook ~= nil end })
