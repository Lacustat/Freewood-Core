-- Freewood-Core: Gesamtdesign "Legion der Affen" (waehlbar im Design-Reiter der Einstellungen).
-- Ein fertiges Rahmenbild mit festem Format (skaliert wird nur ueber den Groessenregler), dunkler Grund dahinter,
-- Reiterleiste durch ein Dropdown ersetzt, rundes Gildenlogo im Ring links oben.
-- Alles ist umkehrbar: Apply(false) stellt das normale Hauptfenster aus MainWindow.xml wieder her.
-- Bilder: Media/Design/Legion/frame.tga (2048x1024, Bild links 1536x1024), logo.tga.

local ADDON, FW = ...

local UI = FW.UI
local frame = UI.window
local T = {}
FW.ThemeLegion = T
if not frame then
    return
end

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Design\\Legion\\"
local W, H = 1440, 960             -- Fenstergroesse in Einheiten (Full HD: Fenster nicht zu gross, Schrift dafuer groesser)
local K = W / 1536                 -- Pixel im Rahmenbild -> Einheiten
local function U(px) return px * K end

local built, active
local parts = {}

-- Teile des normalen Fensters, die im Design ausgeblendet werden
local FRAME_TEXTURES = { "Bg", "BorderTop", "BorderBottom", "BorderLeft", "BorderRight" }
local HEADER_PARTS = { "Bg", "Accent", "Logo", "Title", "Subtitle" }

local function SetShown(obj, show)
    if not obj then return end
    if show then obj:Show() else obj:Hide() end
end

local function TabLabel(id)
    for _, t in ipairs(UI:GetTabList()) do
        if t.id == id then return t.label end
    end
    return tostring(id or "")
end

local function Build()
    if built then return end
    built = true
    local header = frame.Header

    local paper = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    -- Grund nur im Fensterausschnitt (ein Stueck unter das Holz und die Blaetter geschoben), nicht ueber den ganzen Rahmen
    paper:SetPoint("TOPLEFT", frame, "TOPLEFT", U(112), -U(200))
    paper:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -U(92), U(80))
    paper:SetColorTexture(UI.Color("bg", 0.97))   -- dunkler Grund (spaeter evtl. ein Hintergrundbild)

    local art = frame:CreateTexture(nil, "BORDER")
    art:SetAllPoints(frame)
    art:SetTexture(PATH .. "frame.tga")
    art:SetTexCoord(0, 0.75, 0, 1)

    local logo = header:CreateTexture(nil, "ARTWORK", nil, 2)
    logo:SetSize(U(104), U(104))
    logo:SetPoint("CENTER", header, "TOPLEFT", U(162), -U(134))
    logo:SetTexture(PATH .. "logo.tga")

    local dd = UI.CreateDropdown(header, U(330), 30, {
        getOptions = function()
            local list = {}
            for _, t in ipairs(UI:GetTabList()) do
                if not t.hidden then list[#list + 1] = { value = t.id, text = t.label } end
            end
            return list
        end,
        textOf = TabLabel,
        onChange = function(id) if id ~= nil then UI:SelectTab(id) end end,
    })
    dd:SetPoint("CENTER", header, "TOPLEFT", U(447), -U(149.5))

    -- Roter Schliessen-Knopf von Blizzard (ersetzt den Knopf "X" des Standarddesigns)
    local close = CreateFrame("Button", nil, header)
    close:SetSize(34, 34)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Zahnrad: oeffnet direkt die Einstellungen
    local gear = CreateFrame("Button", nil, header)
    gear:SetSize(26, 26)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
    gear:SetScript("OnClick", function() UI:Show("settings") end)
    UI.AttachTooltip(gear, function() return FW.L.TAB_SETTINGS end)

    parts.paper, parts.art, parts.logo, parts.dropdown, parts.gear, parts.close = paper, art, logo, dd, gear, close

    FW:On("UI_TAB_SELECTED", function(id)
        if active and parts.dropdown then parts.dropdown:SetValue(id) end
    end)
end

local function Layout(on)
    local header = frame.Header
    header:ClearAllPoints()
    frame.Content:ClearAllPoints()
    UI.closeButton:ClearAllPoints()
    if parts.close then parts.close:ClearAllPoints() end
    UI.scaleText:ClearAllPoints()
    UI.scaleSlider:ClearAllPoints()
    if on then
        header:SetHeight(U(222))
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame.Content:SetPoint("TOPLEFT", frame, "TOPLEFT", U(127) + 8, -(U(236) + 30))
        frame.Content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(U(129) + 8), U(113) + 8)
        UI.closeButton:SetPoint("RIGHT", header, "TOPRIGHT", -U(160), -U(149.5))
        parts.close:SetPoint("CENTER", UI.closeButton, "CENTER", 0, 0)
    else
        header:SetHeight(48)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.Content:SetPoint("TOPLEFT", frame.TabBar, "BOTTOMLEFT", 20, -18)
        frame.Content:SetPoint("BOTTOMRIGHT", frame.Footer, "TOPRIGHT", -20, 12)
        UI.closeButton:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    end
    UI.scaleText:SetPoint("RIGHT", UI.closeButton, "LEFT", -12, 0)
    UI.scaleSlider:SetPoint("RIGHT", UI.scaleText, "LEFT", -8, 0)
    if parts.gear then
        parts.gear:ClearAllPoints()
        parts.gear:SetPoint("RIGHT", UI.scaleSlider, "LEFT", -18, 0)
    end
end

-- Fenster darf nicht groesser als der Bildschirm sein: Skalierung beim Einschalten notfalls verkleinern
local function FitScale()
    local uiW = (UIParent and UIParent:GetWidth()) or 1920
    local uiH = (UIParent and UIParent:GetHeight()) or 1080
    -- Hat der Spieler die Groesse selbst eingestellt, bleibt sie genau so (auch nach /reload).
    -- Sonst gilt die Vorgabe: 75 %, bei kleinem Bildschirm entsprechend weniger.
    if FW.settings and FW.settings.scaleUser then return end
    local fit = math.min((uiH - 10) / H, (uiW - 10) / W)
    UI:SetScale(math.max(0.5, math.min(0.75, math.floor(fit * 20) / 20)))
end

function T.Apply(on)
    on = on and true or false
    if on then
        Build()
    elseif not built then
        return
    end
    active = on

    SetShown(parts.paper, on)
    SetShown(parts.art, on)
    SetShown(parts.logo, on)
    SetShown(parts.dropdown, on)
    SetShown(parts.gear, on)
    SetShown(parts.close, on)
    SetShown(UI.closeButton, not on)
    for _, k in ipairs(FRAME_TEXTURES) do SetShown(frame[k], not on) end
    for _, k in ipairs(HEADER_PARTS) do SetShown(frame.Header[k], not on) end
    SetShown(frame.TabBar, not on)
    SetShown(frame.Footer, not on)
    SetShown(frame.resizeGrip, not on)

    Layout(on)
    if UI.LegionSkin then UI.LegionSkin.Apply(on) end   -- Holzknoepfe und Rollbalken
    if on then
        -- Text neben dem Regler liegt auf der dunklen Platte: helle Farbe, nicht vom Farbwaehler umgefaerbt
        UI.tracked[UI.scaleText] = nil
        UI.scaleText:SetTextColor(0.91, 0.85, 0.69, 1)
        UI.fixedSize = { W, H }
        FitScale()
        parts.dropdown:SetValue(UI:GetActiveTab())
    else
        UI.fixedSize = nil
        UI.scaleText:SetTextColor(UI.Color("textDim"))
        if FW.settings and not FW.settings.scaleUser and UI:GetScale() < 1 then UI:SetScale(1) end
    end
    UI:ApplySize()
end

-- Beim Start nach dem Laden der gespeicherten Einstellungen (nach MainWindow und Design)
FW:On("FW_DB_READY", function()
    if FW.Design and FW.Design.IsTheme("legion") then
        T.Apply(true)
        FW.Design.Recolor()
    end
end)
