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
    paper:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -U(114), U(98))
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

    parts.paper, parts.art, parts.logo, parts.dropdown = paper, art, logo, dd

    FW:On("UI_TAB_SELECTED", function(id)
        if active and parts.dropdown then parts.dropdown:SetValue(id) end
    end)
end

local function Layout(on)
    local header = frame.Header
    header:ClearAllPoints()
    frame.Content:ClearAllPoints()
    UI.closeButton:ClearAllPoints()
    UI.scaleText:ClearAllPoints()
    UI.scaleSlider:ClearAllPoints()
    if on then
        header:SetHeight(U(222))
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame.Content:SetPoint("TOPLEFT", frame, "TOPLEFT", U(127) + 8, -(U(236) + 6))
        frame.Content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(U(129) + 8), U(113) + 8)
        UI.closeButton:SetPoint("RIGHT", header, "TOPRIGHT", -U(160), -U(149.5))
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
end

-- Fenster darf nicht groesser als der Bildschirm sein: Skalierung beim Einschalten notfalls verkleinern
local function FitScale()
    local uiW = (UIParent and UIParent:GetWidth()) or 1920
    local uiH = (UIParent and UIParent:GetHeight()) or 1080
    local s = UI:GetScale()
    local fit = math.min((uiH - 10) / H, (uiW - 10) / W)
    if s > fit then
        UI:SetScale(math.max(0.5, math.floor(fit * 20) / 20))
    end
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
    for _, k in ipairs(FRAME_TEXTURES) do SetShown(frame[k], not on) end
    for _, k in ipairs(HEADER_PARTS) do SetShown(frame.Header[k], not on) end
    SetShown(frame.TabBar, not on)
    SetShown(frame.Footer, not on)
    SetShown(frame.resizeGrip, not on)

    Layout(on)
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
