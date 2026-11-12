-- Freewood-Core: Verhalten des Hauptfensters
-- Aufbau und Farben stehen in MainWindow.xml. Hier: Ziehen, Position merken,
-- Tabs registrieren und umschalten, Oeffnen/Schliessen.

local ADDON, FW = ...

local UI = FW.UI
local frame = _G.FreewoodMainFrame
if not frame then
    return
end

UI.window = frame
table.insert(UISpecialFrames, "FreewoodMainFrame") -- Escape schliesst das Fenster

local tabs = {}      -- Reihenfolge der Tabs
local tabsById = {}
local activeId
local built = false

------------------------------------------------------------------------
-- Kopf, Ziehen, Position
------------------------------------------------------------------------

local header = frame.Header

UI.SetFont(header.Title, "heading", 20)
header.Title:SetTextColor(UI.Color("goldLight"))
header.Title:SetText("Freewood")

UI.SetFont(header.Subtitle, "body", 11)
header.Subtitle:SetTextColor(UI.Color("textDim"))

UI.SetFont(frame.Footer.Left, "body", 11)
frame.Footer.Left:SetTextColor(UI.Color("textDim"))

local closeButton = UI.CreateButton(header, "X", 30, 30, function()
    frame:Hide()
end, "ghost")
closeButton:SetPoint("RIGHT", header, "RIGHT", -10, 0)

-- Regler fuer die Fenstergroesse (50 bis 150 Prozent) in der Kopfzeile
local scaleText = UI.CreateLabel(header, "100%", { size = 11, color = "textDim", justify = "RIGHT" })
scaleText:SetWidth(40)
scaleText:SetPoint("RIGHT", closeButton, "LEFT", -12, 0)
local scaleSlider = UI.CreateSlider(header, 150, {
    min = 50, max = 150, step = 5,
    get = function() return math.floor(UI:GetScale() * 100 + 0.5) end,
    set = function(v)
        if FW.settings then FW.settings.scaleUser = true end   -- vom Spieler gewaehlt: bleibt nach /reload
        UI:SetScale(v / 100)
    end,
})
scaleSlider:SetPoint("RIGHT", scaleText, "LEFT", -8, 0)
scaleSlider.onText = function(v) scaleText:SetText(string.format("%d%%", v)) end
UI.AttachTooltip(scaleSlider, function() return FW.L.WINDOW_SCALE end, function() return FW.L.WINDOW_SCALE_TIP end)
UI.scaleSlider = scaleSlider
UI.closeButton = closeButton
UI.scaleText = scaleText

local scaleListeners = {}
-- Andere Bedienelemente (Einstellungen: - / +) melden sich an, um bei einer Aenderung nachzuziehen
function UI:OnScaleChanged(fn)
    scaleListeners[#scaleListeners + 1] = fn
end

header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function()
    frame:StartMoving()
end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point and FW.settings then
        FW.settings.windowPos = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end)

function UI:ApplyPosition()
    local pos = FW.settings and FW.settings.windowPos
    frame:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

------------------------------------------------------------------------
-- Groesse: Standard, Grenzen, Ziehgriff unten rechts
------------------------------------------------------------------------

local DEFAULT_W, DEFAULT_H = 1240, 840
local MIN_W, MIN_H = 1240, 840   -- so gross, dass die Einstellungen komplett passen
local MAX_W, MAX_H = 1500, 1100

-- Grenzen passend zum Bildschirm (Fenster soll nicht groesser als der Bildschirm werden)
local function SizeLimits()
    local scale = frame:GetScale() or 1
    local sw = ((UIParent and UIParent:GetWidth()) or 1920) / scale
    local sh = ((UIParent and UIParent:GetHeight()) or 1080) / scale
    local maxW = math.max(MIN_W, math.min(MAX_W, sw - 20))
    local maxH = math.max(MIN_H, math.min(MAX_H, sh - 20))
    return maxW, maxH
end

local function ClampSize(w, h)
    local maxW, maxH = SizeLimits()
    w = math.min(math.max(tonumber(w) or DEFAULT_W, MIN_W), maxW)
    h = math.min(math.max(tonumber(h) or DEFAULT_H, MIN_H), maxH)
    return w, h
end

function UI:ApplySize()
    -- Design mit fester Groesse (z. B. "Legion der Affen"): Rahmenbild hat ein festes Format, skaliert wird nur ueber den Regler
    if UI.fixedSize then
        frame:SetSize(UI.fixedSize[1], UI.fixedSize[2])
        return
    end
    local saved = FW.settings and FW.settings.windowSize
    local w, h = DEFAULT_W, DEFAULT_H
    if type(saved) == "table" then
        w, h = saved.w or w, saved.h or h
    end
    frame:SetSize(ClampSize(w, h))
end

local function SetupResize()
    if frame.SetResizable then
        frame:SetResizable(true)
    end
    local maxW, maxH = SizeLimits()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(MIN_W, MIN_H) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function()
        local mw, mh = SizeLimits()
        if frame.SetResizeBounds then
            frame:SetResizeBounds(MIN_W, MIN_H, mw, mh)
        end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local w, h = ClampSize(frame:GetWidth(), frame:GetHeight())
        frame:SetSize(w, h)
        if FW.settings then
            FW.settings.windowSize = { w = math.floor(w + 0.5), h = math.floor(h + 0.5) }
        end
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        if point and FW.settings then
            FW.settings.windowPos = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)
    UI.AttachTooltip(grip, function() return FW.L.WINDOW_RESIZE end, function() return FW.L.WINDOW_RESIZE_TIP end)
    frame.resizeGrip = grip
end

function UI:ResetPosition()
    if FW.settings then
        FW.settings.windowPos = false
        FW.settings.windowSize = false
    end
    self:ApplySize()
    self:ApplyPosition()
end

function UI:SetScale(scale)
    scale = FW.Util.Clamp(math.floor(scale * 20 + 0.5) / 20, 0.5, 1.5)
    if FW.settings then
        FW.settings.scale = scale
    end
    frame:SetScale(scale)
    self:ApplySize()
    scaleSlider:Refresh()
    for _, fn in ipairs(scaleListeners) do
        pcall(fn, scale)
    end
end

function UI:GetScale()
    return (FW.settings and FW.settings.scale) or 1
end

FW:On("FW_DB_READY", function()
    frame:SetScale(UI:GetScale())
    scaleSlider:Refresh()
    SetupResize()
    UI:ApplySize()
    UI:ApplyPosition()
    header.Subtitle:SetText("v" .. FW.version)
end)

------------------------------------------------------------------------
-- Tabs
-- def.label   Text oder Funktion, die den Text liefert
-- def.order   Reihenfolge (kleiner = weiter links)
-- def.build   function(content) -> Frame   (wird beim ersten Anzeigen aufgerufen)
-- def.onShow  function(tabFrame)           (bei jedem Anzeigen)
------------------------------------------------------------------------

local function ResolveLabel(def)
    local label = def.label
    if type(label) == "function" then
        label = label()
    end
    return label or "?"
end

-- Reihenfolge und ausgeblendete Reiter: FW.settings.tabOrder (Liste von Ids), FW.settings.tabHidden (Id -> true)
local function TabRank()
    local rank = {}
    local order = FW.settings and FW.settings.tabOrder
    if type(order) == "table" then
        for i, id in ipairs(order) do
            rank[id] = i
        end
    end
    return rank
end

local function IsTabHidden(tab)
    local hidden = FW.settings and FW.settings.tabHidden
    return tab.id ~= "settings" and type(hidden) == "table" and hidden[tab.id] == true
end

local TAB_ROW_H = 34

-- Tabs in Zeilen umbrechen, wenn sie nicht in eine Zeile passen; die Leiste waechst mit,
-- der Inhaltsbereich haengt an ihrem unteren Rand und rutscht mit.
local function LayoutTabs()
    local rank = TabRank()
    table.sort(tabs, function(a, b)
        local ra, rb = rank[a.id], rank[b.id]
        if ra and rb then
            return ra < rb
        elseif ra then
            return true
        elseif rb then
            return false
        end
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.seq < b.seq
    end)
    local barW = frame.TabBar:GetWidth()
    if not barW or barW < 100 then
        barW = (frame:GetWidth() or 1000) - 2
    end
    local limit = barW - 12
    local x, row = 12, 0
    local rowOf = {}
    for _, tab in ipairs(tabs) do
        if tab.button and IsTabHidden(tab) then
            tab.button:Hide()
        elseif tab.button then
            tab.button:Show()
            local w = tab.button:GetWidth()
            if x + w > limit and x > 12 then
                row = row + 1
                x = 12
            end
            rowOf[tab] = { row = row, x = x }
            x = x + w + 4
        end
    end
    local rows = row + 1
    frame.TabBar:SetHeight(rows * TAB_ROW_H + 2)
    for _, tab in ipairs(tabs) do
        local at = rowOf[tab]
        if at then
            tab.button:ClearAllPoints()
            tab.button:SetPoint("BOTTOMLEFT", frame.TabBar, "BOTTOMLEFT", at.x, 1 + (rows - 1 - at.row) * TAB_ROW_H)
        end
    end
end

local StartTabDrag

local function CreateTabButton(tab)
    local button = UI.CreateTabButton(frame.TabBar, ResolveLabel(tab.def))
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            UI:SetTabHidden(tab.id, true, true)
        else
            UI:SelectTab(tab.id)
        end
    end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        StartTabDrag(tab)
    end)
    button:SetScript("OnDragStop", function()
        UI:StopTabDrag(true)
    end)
    tab.button = button
end

function UI:RegisterTab(id, def)
    if tabsById[id] then
        return tabsById[id]
    end
    local tab = { id = id, def = def, order = def.order or 100, seq = #tabs + 1 }
    tabsById[id] = tab
    tabs[#tabs + 1] = tab
    if built then
        CreateTabButton(tab)
        LayoutTabs()
    end
    return tab
end

function UI:SelectTab(id)
    local tab = tabsById[id]
    if not tab then
        return
    end

    for _, other in ipairs(tabs) do
        if other.frame then
            other.frame:Hide()
        end
        if other.button then
            other.button:SetActive(other == tab)
        end
    end

    if not tab.frame and tab.def.build then
        tab.frame = tab.def.build(frame.Content)
        if tab.frame then
            tab.frame:SetAllPoints(frame.Content)
        end
    end
    if tab.frame then
        tab.frame:Show()
        if tab.def.onShow then
            FW.SafeCall(tab.def.onShow, tab.frame)
        end
    end
    activeId = id
    FW:Fire("UI_TAB_SELECTED", id)
end

function UI:GetActiveTab()
    return activeId
end

local function BuildOnce()
    if built then
        return
    end
    built = true
    for _, tab in ipairs(tabs) do
        CreateTabButton(tab)
    end
    LayoutTabs()
    frame:HookScript("OnSizeChanged", function()
        LayoutTabs()
    end)
end

-- Schriftgroesse der Haupt-Reiter (Design-Reiter in den Einstellungen)
function UI:ApplyTabFont(size)
    UI.tabFontSize = size
    for _, tab in ipairs(tabs) do
        if tab.button then tab.button:SetFontSize(size) end
    end
    if built then LayoutTabs() end
end

------------------------------------------------------------------------
-- Reiter ordnen und ausblenden
------------------------------------------------------------------------

-- Liste aller Reiter in der aktuellen Reihenfolge: { id, label, hidden, locked }
function UI:GetTabList()
    LayoutTabs()
    local list = {}
    for _, tab in ipairs(tabs) do
        list[#list + 1] = { id = tab.id, label = ResolveLabel(tab.def), hidden = IsTabHidden(tab), locked = (tab.id == "settings") }
    end
    return list
end

local function FirstVisibleId()
    for _, tab in ipairs(tabs) do
        if not IsTabHidden(tab) then
            return tab.id
        end
    end
    return nil
end

function UI:SetTabHidden(id, hide, announce)
    local tab = tabsById[id]
    if not tab or id == "settings" or not FW.settings then
        return
    end
    if type(FW.settings.tabHidden) ~= "table" then
        FW.settings.tabHidden = {}
    end
    FW.settings.tabHidden[id] = hide and true or nil
    if built then
        LayoutTabs()
    end
    if hide and activeId == id then
        activeId = FirstVisibleId()
        if frame:IsShown() and activeId then
            self:SelectTab(activeId)
        end
    end
    if hide and announce then
        FW:Print(string.format(FW.L.TABS_HIDDEN_NOTE, ResolveLabel(tab.def)))
    end
end

function UI:ResetTabOrder()
    if not FW.settings then
        return
    end
    FW.settings.tabOrder = {}
    FW.settings.tabHidden = {}
    if built then
        LayoutTabs()
    end
end

-- Ziehen: Geisterbild am Mauszeiger, goldene Einfuegemarke an der Zielstelle
local drag

local function VisibleTabs()
    local list = {}
    for _, tab in ipairs(tabs) do
        if tab.button and tab.button:IsShown() then
            list[#list + 1] = tab
        end
    end
    return list
end

-- Index (1 .. n+1) in der Liste der sichtbaren Reiter, vor dem eingefuegt wird
local function DropIndex(list, cx, cy)
    local best, bestScore, after
    for i, tab in ipairs(list) do
        local b = tab.button
        local l, r, top, bottom = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
        if l and r and top and bottom then
            local sc = b:GetEffectiveScale()
            local x, y = cx / sc, cy / sc
            local dy = 0
            if y > top then
                dy = y - top
            elseif y < bottom then
                dy = bottom - y
            end
            local mid = (l + r) / 2
            local score = dy * 10000 + math.abs(x - mid)
            if not bestScore or score < bestScore then
                best, bestScore, after = i, score, (x >= mid)
            end
        end
    end
    if not best then
        return nil
    end
    return after and (best + 1) or best
end

local function PlaceIndicator(list, index)
    local ind = drag.indicator
    local ref, side
    if index <= #list then
        ref, side = list[index], "before"
    else
        ref, side = list[#list], "after"
    end
    ind:ClearAllPoints()
    if side == "before" then
        ind:SetPoint("TOPLEFT", ref.button, "TOPLEFT", -3, -2)
        ind:SetPoint("BOTTOMRIGHT", ref.button, "BOTTOMLEFT", -1, 2)
    else
        ind:SetPoint("TOPLEFT", ref.button, "TOPRIGHT", 1, -2)
        ind:SetPoint("BOTTOMRIGHT", ref.button, "BOTTOMRIGHT", 3, 2)
    end
    ind:Show()
end

local function DragUpdate()
    if not drag then
        return
    end
    local cx, cy = GetCursorPosition()
    local ui = UIParent:GetEffectiveScale()
    drag.ghost:ClearAllPoints()
    drag.ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / ui, cy / ui)
    local list = VisibleTabs()
    local index = DropIndex(list, cx, cy)
    drag.index = index
    drag.list = list
    if index then
        PlaceIndicator(list, index)
    else
        drag.indicator:Hide()
    end
end

function StartTabDrag(tab)
    if drag or not tab.button then
        return
    end
    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(tab.button:GetWidth(), 30)
    local bg = ghost:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(UI.Color("gold", 0.35))
    local text = UI.CreateLabel(ghost, ResolveLabel(tab.def), { font = "heading", size = 13, color = "goldLight", justify = "CENTER" })
    text:SetPoint("CENTER", 0, 0)
    local indicator = frame.TabBar:CreateTexture(nil, "OVERLAY")
    indicator:SetColorTexture(UI.Color("goldLight"))
    indicator:Hide()
    drag = { tab = tab, ghost = ghost, indicator = indicator }
    tab.button:SetAlpha(0.4)
    ghost:SetScript("OnUpdate", DragUpdate)
end

function UI:StopTabDrag(apply)
    local d = drag
    if not d then
        return
    end
    drag = nil
    d.ghost:SetScript("OnUpdate", nil)
    d.ghost:Hide()
    d.indicator:Hide()
    d.tab.button:SetAlpha(1)
    if not apply or not d.index or not d.list or not FW.settings then
        return
    end
    local ref = d.list[d.index]      -- vor diesem Reiter einfuegen (nil = ans Ende der sichtbaren)
    if ref == d.tab then
        return
    end
    local ids = {}
    for _, tab in ipairs(tabs) do
        if tab ~= d.tab then
            ids[#ids + 1] = tab.id
        end
    end
    local pos
    if ref then
        for i, id in ipairs(ids) do
            if id == ref.id then
                pos = i
                break
            end
        end
    else
        local last = d.list[#d.list]
        if last == d.tab then
            last = d.list[#d.list - 1]
        end
        if last then
            for i, id in ipairs(ids) do
                if id == last.id then
                    pos = i + 1
                    break
                end
            end
        end
    end
    table.insert(ids, pos or (#ids + 1), d.tab.id)
    FW.settings.tabOrder = ids
    LayoutTabs()
end

frame:HookScript("OnHide", function()
    UI:StopTabDrag(false)
end)

frame:SetScript("OnShow", function()
    BuildOnce()
    local _, _, _, toc = GetBuildInfo()
    local left = FW.L.TITLE .. "  |  " .. string.format(FW.L.SLASH_VERSION, FW.version, FW.API_VERSION, tostring(toc or "?"))
    frame.Footer.Left:SetText(left)
    local current = activeId and tabsById[activeId]
    if not current or IsTabHidden(current) then
        activeId = FirstVisibleId()
    end
    UI:SelectTab(activeId or (tabs[1] and tabs[1].id))
end)

------------------------------------------------------------------------
-- Oeffnen und Schliessen
------------------------------------------------------------------------

function UI:Show(tabId)
    if tabId then
        activeId = tabId
    end
    if frame:IsShown() then
        if tabId then
            self:SelectTab(tabId)
        end
    else
        frame:Show() -- OnShow waehlt den Tab
    end
end

function UI:Hide()
    frame:Hide()
end

function UI:Toggle(tabId)
    if frame:IsShown() then
        frame:Hide()
    else
        self:Show(tabId)
    end
end

-- Fuer Tastenbelegungen: Fenster auf dem Reiter oeffnen; ist er schon aktiv, schliesst es wieder.
function UI:ToggleTab(id)
    if not id then
        return self:Toggle()
    end
    if not tabsById[id] then
        return false
    end
    if frame:IsShown() and activeId == id then
        frame:Hide()
    else
        self:Show(id)
    end
    return true
end

-- Globale Einstiegspunkte fuer Bindings.xml aller Freewood-Module
function _G.Freewood_ToggleTab(id)
    local FW = _G.Freewood
    if FW and FW.UI then
        FW.UI:ToggleTab(id)
    end
end
