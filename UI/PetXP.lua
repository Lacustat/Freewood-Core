-- Freewood-Core: kleiner Erfahrungsbalken für den Jäger-Begleiter (0.68.0)
-- Zeigt Stufe und Erfahrung des aktiven Begleiters (GetPetExperience), ohne das Begleiterfenster zu öffnen.
-- Standardplatz: Bildschirmmitte. Verschieben mit Shift + linker Maustaste (ziehen), Position je Charakter.
-- Nur Lesen, keine geschützten Funktionen; Werte werden auf Secret geprüft.
-- Copyright (C) 2026 Lacustat. GPL-3.0-or-later.

local ADDON, FW = ...
local G = _G
local UI = FW.UI

local PX = {}
FW.PetXP = PX

FW:AddLocale("enUS", {
    PETXP_TITLE = "Pet experience bar",
    PETXP_ON = "Show a small experience bar for my pet",
    PETXP_RESET = "Back to the centre",
    PETXP_INFO = "Shows level and experience of your active hunter pet. Move it with Shift + left mouse button (drag). The position is saved per character; /fwpetxp reset puts it back to the centre of the screen.",
    PETXP_TEXT = "%s  ·  Level %d  ·  %s / %s (%d %%)",
    PETXP_MAX = "%s  ·  Level %d",
    PETXP_TIP = "Shift + drag: move",
})
FW:AddLocale("deDE", {
    PETXP_TITLE = "Begleiter-Erfahrungsbalken",
    PETXP_ON = "Kleinen Erfahrungsbalken für meinen Begleiter zeigen",
    PETXP_RESET = "Zurück in die Mitte",
    PETXP_INFO = "Zeigt Stufe und Erfahrung deines aktiven Jäger-Begleiters. Verschieben mit Shift + linker Maustaste (ziehen). Die Position wird je Charakter gespeichert; /fwpetxp reset setzt ihn zurück in die Bildschirmmitte.",
    PETXP_TEXT = "%s  ·  Stufe %d  ·  %s / %s (%d %%)",
    PETXP_MAX = "%s  ·  Stufe %d",
    PETXP_TIP = "Shift + ziehen: verschieben",
})

local W, H = 260, 18

local function L() return FW.L end
local function Secret(v) return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or Secret(a) or Secret(b) then return nil end
    return a, b, c
end

function PX.Opts()
    local c = FW.chardb
    if type(c) ~= "table" then PX.mem = PX.mem or {} c = PX.mem end
    c.petxp = c.petxp or {}
    local o = c.petxp
    if o.on == nil then o.on = true end
    return o
end

-- Zahl mit Tausenderpunkt (deutsch) bzw. Komma (englisch)
function PX.Num(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local sep = (G.GetLocale and G.GetLocale() == "deDE") and "." or ","
    local out = s
    while true do
        local k
        out, k = out:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2")
        if k == 0 then break end
    end
    return out
end

-- Daten des Begleiters: nil, wenn kein Begleiter mit Erfahrung da ist
function PX.Data()
    if not Call(G.UnitExists, "pet") then return nil end
    local cur, max = Call(G.GetPetExperience)
    if type(cur) ~= "number" or type(max) ~= "number" then return nil end
    local level = Call(G.UnitLevel, "pet") or 0
    local name = Call(G.UnitName, "pet") or "?"
    return { cur = cur, max = max, level = level, name = name }
end

function PX.Text(d)
    if not d then return "" end
    if d.max <= 0 then return string.format(L().PETXP_MAX, d.name, d.level) end
    local pct = math.floor(d.cur / d.max * 100)
    return string.format(L().PETXP_TEXT, d.name, d.level, PX.Num(d.cur), PX.Num(d.max), pct)
end

local frame

function PX.ApplyPos(f)
    f = f or frame
    if not f then return end
    local o = PX.Opts()
    f:ClearAllPoints()
    if o.point then
        f:SetPoint(o.point, G.UIParent, o.rel or o.point, o.x or 0, o.y or 0)
    else
        f:SetPoint("CENTER", G.UIParent, "CENTER", 0, 0)
    end
end

function PX.ResetPos()
    local o = PX.Opts()
    o.point, o.rel, o.x, o.y = nil, nil, nil, nil
    PX.ApplyPos()
end

local function Build()
    if frame then return frame end
    local f = CreateFrame("Frame", "FreewoodPetXPBar", G.UIParent)
    f:SetSize(W, H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.6)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.58, 0.0, 0.55)
    bar:SetMinMaxValues(0, 1)
    f.bar = bar
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    if border.SetBackdrop then
        pcall(border.SetBackdrop, border, { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        if border.SetBackdropBorderColor then border:SetBackdropBorderColor(0.8, 0.65, 0.35, 1) end
    end
    f.border = border
    f.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    f:SetScript("OnDragStart", function(self)
        if G.IsShiftKeyDown and G.IsShiftKeyDown() then self.moving = true self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        if not self.moving then return end
        self.moving = nil
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint(1)
        local o = PX.Opts()
        o.point, o.rel, o.x, o.y = point, rel, x, y
    end)
    f:SetScript("OnEnter", function(self)
        local T = G.GameTooltip
        if not T then return end
        T:SetOwner(self, "ANCHOR_TOP")
        T:SetText(L().PETXP_TITLE)
        T:AddLine(L().PETXP_TIP, 0.7, 0.7, 0.7)
        T:Show()
    end)
    f:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    frame = f
    PX.frame = f
    PX.ApplyPos(f)
    f:Hide()
    return f
end

function PX.Update()
    if not PX.Opts().on then
        if frame then frame:Hide() end
        return
    end
    local d = PX.Data()
    if not d then
        if frame then frame:Hide() end
        return
    end
    local f = Build()
    local max = d.max > 0 and d.max or 1
    f.bar:SetMinMaxValues(0, max)
    f.bar:SetValue(d.max > 0 and d.cur or max)
    f.text:SetText(PX.Text(d))
    f:Show()
end

for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_PET", "UNIT_PET_EXPERIENCE", "PET_UI_UPDATE", "UNIT_LEVEL", "UNIT_NAME_UPDATE" }) do
    FW:RegisterEvent(ev, function(unit)
        if (ev == "UNIT_LEVEL" or ev == "UNIT_NAME_UPDATE") and unit ~= "pet" then return end
        PX.Update()
    end)
end

G.SLASH_FREEWOODPETXP1 = "/fwpetxp"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList.FREEWOODPETXP = function(msg)
    msg = (msg or ""):lower()
    if msg == "reset" then PX.ResetPos() return end
    PX.Opts().on = not PX.Opts().on
    PX.Update()
end

if UI and UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("petxp", {
        category = "interface",
        order = 30,
        height = 120,
        build = function(parent)
            local Lx = L()
            local f, stack = UI.CreateSection(parent, Lx.PETXP_TITLE)
            f.on = UI.CreateCheckbox(f, Lx.PETXP_ON, function() return PX.Opts().on end, function(v)
                PX.Opts().on = v and true or false
                PX.Update()
            end)
            stack:Add(f.on, { fit = true })
            stack:Add(UI.CreateButton(f, Lx.PETXP_RESET, 180, 24, function() PX.ResetPos() end, "default"), { height = 24, gap = 6 })
            if f.AddInfo then f:AddInfo(Lx.PETXP_INFO) end
            return f
        end,
        refresh = function(frame) if frame and frame.on and frame.on.Refresh then frame.on:Refresh() end end,
    })
end
