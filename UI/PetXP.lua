-- Freewood-Core: kleiner Erfahrungsbalken für den Jäger-Begleiter (0.68.0)
-- Zeigt Stufe und Erfahrung des aktiven Begleiters (GetPetExperience), ohne das Begleiterfenster zu öffnen.
-- Standardplatz: Bildschirmmitte. Verschieben mit Shift + linker Maustaste (ziehen), Position je Charakter.
-- Ab 0.68.1: nur für Jäger, unsichtbar wenn der Begleiter so hoch ist wie du, Breite/Höhe einstellbar, im Kampf wählbar.
-- Die Einstellungen liegen im Reiter Klassen > Jäger > Pet-Regler (Freewood-Class), ohne Class-Modul unter Einstellungen > Oberfläche.
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
    PETXP_LEVEL = "Level %d",
    PETXP_SHOW = "Text on the bar:", PETXP_T_NAME = "Name", PETXP_T_LEVEL = "Level",
    PETXP_T_XP = "Experience (numbers)", PETXP_T_PCT = "Percent",
    PETXP_TIP = "Shift + drag: move",
    PETXP_COMBAT = "Visible in combat",
    PETXP_WIDTH = "Width: %d", PETXP_HEIGHT = "Height: %d",
})
FW:AddLocale("deDE", {
    PETXP_TITLE = "Begleiter-Erfahrungsbalken",
    PETXP_ON = "Kleinen Erfahrungsbalken für meinen Begleiter zeigen",
    PETXP_RESET = "Zurück in die Mitte",
    PETXP_INFO = "Zeigt Stufe und Erfahrung deines aktiven Jäger-Begleiters. Verschieben mit Shift + linker Maustaste (ziehen). Die Position wird je Charakter gespeichert; /fwpetxp reset setzt ihn zurück in die Bildschirmmitte.",
    PETXP_LEVEL = "Stufe %d",
    PETXP_SHOW = "Text auf dem Balken:", PETXP_T_NAME = "Name", PETXP_T_LEVEL = "Stufe",
    PETXP_T_XP = "Erfahrung (Zahlen)", PETXP_T_PCT = "Prozent",
    PETXP_TIP = "Shift + ziehen: verschieben",
    PETXP_COMBAT = "Im Kampf sichtbar",
    PETXP_WIDTH = "Breite: %d", PETXP_HEIGHT = "Höhe: %d",
})

local W, H = 260, 18
PX.W_MIN, PX.W_MAX, PX.H_MIN, PX.H_MAX = 120, 600, 10, 40

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
    if o.combat == nil then o.combat = true end
    -- 0.68.2: Teile des Textes (alle aus = nur der Balken)
    for _, k in ipairs({ "tName", "tLevel", "tXP", "tPct" }) do if o[k] == nil then o[k] = true end end
    o.w = math.max(PX.W_MIN, math.min(PX.W_MAX, tonumber(o.w) or W))
    o.h = math.max(PX.H_MIN, math.min(PX.H_MAX, tonumber(o.h) or H))
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
function PX.IsHunter()
    local _, token = Call(G.UnitClass, "player")
    return token == "HUNTER"
end

function PX.Data()
    if not PX.IsHunter() then return nil end
    if not Call(G.UnitExists, "pet") then return nil end
    local cur, max = Call(G.GetPetExperience)
    if type(cur) ~= "number" or type(max) ~= "number" then return nil end
    local level = Call(G.UnitLevel, "pet") or 0
    local name = Call(G.UnitName, "pet") or "?"
    return { cur = cur, max = max, level = level, name = name }
end

-- Text aus den gewählten Teilen (Name, Stufe, Zahlen, Prozent); auf Höchststufe ohne Zahlen und Prozent
function PX.Text(d)
    if not d then return "" end
    local o = PX.Opts()
    local parts = {}
    if o.tName then parts[#parts + 1] = d.name end
    if o.tLevel then parts[#parts + 1] = string.format(L().PETXP_LEVEL, d.level) end
    if d.max > 0 then
        if o.tXP then parts[#parts + 1] = PX.Num(d.cur) .. " / " .. PX.Num(d.max) end
        if o.tPct then parts[#parts + 1] = math.floor(d.cur / d.max * 100) .. " %" end
    end
    return table.concat(parts, "  ·  ")
end

-- Schriftgröße passend zum Balken: 70 % der Höhe (6 bis 28), schmaler, wenn der Text nicht in die Breite passt
function PX.FontSize(h, textWidth, barWidth, current)
    local size = math.max(6, math.min(28, math.floor(h * 0.7 + 0.5)))
    if textWidth and current and current > 0 and barWidth and barWidth > 8 then
        local need = textWidth * size / current
        if need > barWidth - 8 then size = math.max(6, math.floor(size * (barWidth - 8) / need)) end
    end
    return size
end

function PX.ApplyFont(f)
    f = f or frame
    if not (f and f.text) then return end
    local font = f.fontPath or "Fonts\\FRIZQT__.TTF"
    local o = PX.Opts()
    local size = PX.FontSize(o.h)
    f.text:SetFont(font, size, "OUTLINE")
    local tw = f.text.GetStringWidth and f.text:GetStringWidth() or nil
    local fit = PX.FontSize(o.h, tw, o.w, size)
    if fit ~= size then f.text:SetFont(font, fit, "OUTLINE") end
    f.fontSize = fit
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
    f:SetSize(PX.Opts().w, PX.Opts().h)
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
    if f.text.GetFont then f.fontPath = f.text:GetFont() end
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

-- Soll der Balken jetzt zu sehen sein? (Daten oder nil, Grund)
function PX.Visible()
    local o = PX.Opts()
    if not o.on then return nil, "off" end
    local d = PX.Data()
    if not d then return nil, "nopet" end
    local me = Call(G.UnitLevel, "player")
    if type(me) == "number" and d.level >= me then return nil, "level" end
    if not o.combat and (PX.inCombat or Call(G.InCombatLockdown)) then return nil, "combat" end
    return d
end

function PX.ApplySize()
    if not frame then return end
    local o = PX.Opts()
    frame:SetSize(o.w, o.h)
end

function PX.Update()
    local d = PX.Visible()
    if not d then
        if frame then frame:Hide() end
        return
    end
    local f = Build()
    PX.ApplySize()
    local max = d.max > 0 and d.max or 1
    f.bar:SetMinMaxValues(0, max)
    f.bar:SetValue(d.max > 0 and d.cur or max)
    local t = PX.Text(d)
    f.text:SetText(t)
    f.text:SetShown(t ~= "")
    PX.ApplyFont(f)
    f:Show()
end

FW:RegisterEvent("PLAYER_REGEN_DISABLED", function() PX.inCombat = true PX.Update() end)
FW:RegisterEvent("PLAYER_REGEN_ENABLED", function() PX.inCombat = false PX.Update() end)
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_PET", "UNIT_PET_EXPERIENCE", "PET_UI_UPDATE", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "PLAYER_LEVEL_UP" }) do
    FW:RegisterEvent(ev, function(unit)
        if (ev == "UNIT_LEVEL" or ev == "UNIT_NAME_UPDATE") and unit ~= "pet" and unit ~= "player" then return end
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

-- Einstellungsfeld, das andere Module einbauen (Klassen > Jäger > Pet-Regler). Rückgabe: Frame mit :Refresh(), .fwHeight
function PX.BuildPanel(parent, width)
    local Lx = L()
    local f = CreateFrame("Frame", nil, parent)
    width = width or 360
    f:SetSize(width, 10)
    local y = 0
    local function Put(w, h, gap)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
        y = y + (h or 24) + (gap or 6)
    end
    f.title = UI.CreateLabel(f, Lx.PETXP_TITLE, { font = "heading", size = 13, color = "goldLight" })
    Put(f.title, 18, 6)
    f.on = UI.CreateCheckbox(f, Lx.PETXP_ON, function() return PX.Opts().on end, function(v)
        PX.Opts().on = v and true or false
        PX.Update()
    end)
    Put(f.on, 22, 4)
    f.combat = UI.CreateCheckbox(f, Lx.PETXP_COMBAT, function() return PX.Opts().combat end, function(v)
        PX.Opts().combat = v and true or false
        PX.Update()
    end)
    Put(f.combat, 22, 10)
    f.showLabel = UI.CreateLabel(f, Lx.PETXP_SHOW, { size = 12, color = "gold" })
    Put(f.showLabel, 14, 4)
    f.parts = {}
    for _, k in ipairs({ { "tName", "PETXP_T_NAME" }, { "tLevel", "PETXP_T_LEVEL" }, { "tXP", "PETXP_T_XP" }, { "tPct", "PETXP_T_PCT" } }) do
        local key = k[1]
        local cb = UI.CreateCheckbox(f, Lx[k[2]], function() return PX.Opts()[key] end, function(v)
            PX.Opts()[key] = v and true or false
            PX.Update()
        end)
        Put(cb, 22, 2)
        f.parts[#f.parts + 1] = cb
    end
    y = y + 8
    local function SizeSlider(key, textKey, lo, hi, step)
        local label = UI.CreateLabel(f, "", { size = 12 })
        Put(label, 14, 4)
        local sl = UI.CreateSlider(f, math.min(width, 320), {
            min = lo, max = hi, step = step,
            get = function() return PX.Opts()[key] end,
            set = function(v) PX.Opts()[key] = v PX.ApplySize() PX.Update() end,
        })
        sl.onText = function(v)
            label:SetText(string.format(Lx[textKey], v))
            if frame and frame:IsShown() then
                local o = PX.Opts()
                local keep = o[key]
                o[key] = v
                if key == "w" then frame:SetWidth(v) else frame:SetHeight(v) end
                PX.ApplyFont(frame)
                o[key] = keep
            end
        end
        Put(sl, 20, 10)
        return sl
    end
    f.width = SizeSlider("w", "PETXP_WIDTH", PX.W_MIN, PX.W_MAX, 10)
    f.height = SizeSlider("h", "PETXP_HEIGHT", PX.H_MIN, PX.H_MAX, 1)
    f.reset = UI.CreateButton(f, Lx.PETXP_RESET, 180, 24, function() PX.ResetPos() end, "default")
    Put(f.reset, 24, 8)
    f.info = UI.CreateLabel(f, Lx.PETXP_INFO, { size = 11, color = "textDim", justifyV = "TOP" })
    f.info:SetWordWrap(true)
    f.info:SetWidth(width)
    Put(f.info, 42, 0)
    f.fwHeight = y
    f:SetHeight(y)
    function f:Refresh()
        for _, w in ipairs({ self.on, self.combat, self.width, self.height }) do if w.Refresh then w:Refresh() end end
        for _, w in ipairs(self.parts) do if w.Refresh then w:Refresh() end end
    end
    f:Refresh()
    return f
end

-- Ohne Class-Modul: Abschnitt unter Einstellungen > Oberfläche
local function ClassLoaded()
    local fn = (G.C_AddOns and G.C_AddOns.IsAddOnLoaded) or G.IsAddOnLoaded
    return fn and Call(fn, "Freewood-Class") and true or false
end

function PX.RegisterFallback()
    if PX.fallback or ClassLoaded() or not (UI and UI.RegisterSettingsSection) then return end
    PX.fallback = true
    UI:RegisterSettingsSection("petxp", {
        category = "interface",
        order = 30,
        height = 420,
        build = function(parent)
            local f, stack = UI.CreateSection(parent, L().PETXP_TITLE)
            local panel = PX.BuildPanel(f, 340)
            panel.title:Hide()
            stack:Add(panel, { height = panel.fwHeight })
            f.panel = panel
            return f
        end,
        refresh = function(frame) if frame and frame.panel then frame.panel:Refresh() end end,
    })
end
FW:RegisterEvent("PLAYER_LOGIN", function() PX.RegisterFallback() end)
