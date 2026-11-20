-- Freewood-Core: die drei eigenen Tabs (Uebersicht, Austausch, Einstellungen)
-- Module registrieren ihre Tabs ueber Freewood.UI:RegisterTab(...), siehe MainWindow.lua.

local ADDON, FW = ...

local UI = FW.UI
local Export = FW.Export

------------------------------------------------------------------------
-- Uebersicht: geladene Module
------------------------------------------------------------------------

local function BuildOverview(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.OVERVIEW_HEADER, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local _, build, _, toc = GetBuildInfo()
    local gameVersion = (GetBuildInfo())
    local info = UI.CreateLabel(f,
        string.format(L.OVERVIEW_INFO, FW.version, tostring(gameVersion), tostring(build)),
        { size = 11, color = "textDim", justify = "RIGHT" })
    info:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)

    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -30)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -30)

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -44)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local empty = UI.CreateLabel(scroll.child, L.OVERVIEW_NONE, { size = 12, color = "textDim", justifyV = "TOP" })
    empty:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
    empty:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, 0)

    local ROW_H, GAP = 58, 8
    local rows = {}

    local function GetRow(i)
        local row = rows[i]
        if row then
            return row
        end
        row = UI.CreatePanel(scroll.child, "card", "bronze")
        row:SetHeight(ROW_H)

        row.name = UI.CreateLabel(row, "", { font = "heading", size = 14, color = "goldLight" })
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -10)

        row.version = UI.CreateLabel(row, "", { size = 11, color = "textDim" })
        row.version:SetPoint("LEFT", row.name, "RIGHT", 10, 0)

        row.desc = UI.CreateLabel(row, "", { size = 12, color = "text" })
        row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)

        row.status = UI.CreateLabel(row, "", { size = 12, justify = "RIGHT" })
        row.status:SetPoint("RIGHT", row, "RIGHT", -14, 0)

        rows[i] = row
        return row
    end

    function f.Refresh()
        local list = FW.moduleList
        if #list == 0 then
            empty:Show()
        else
            empty:Hide()
        end

        for i, mod in ipairs(list) do
            local row = GetRow(i)
            local y = (i - 1) * (ROW_H + GAP)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -y)
            row.name:SetText(mod.title or mod.name)
            row.version:SetText(mod.version and ("v" .. mod.version) or "")
            row.desc:SetText(mod.description or "")
            if mod:IsEnabled() then
                if FW.Design and FW.Design.IsTheme and FW.Design.IsTheme("legion") then
                    -- Blizzard-Punkt "online" statt Text (Pfad auf Forever noch nicht geprueft)
                    row.status:SetText("|TInterface\\FriendsFrame\\StatusIcon-Online:16:16|t")
                else
                    row.status:SetText("|cff" .. UI.Hex("success") .. L.MODULE_ACTIVE .. "|r")
                end
            else
                row.status:SetText("|cff" .. UI.Hex("textDim") .. L.MODULE_INACTIVE .. "|r")
            end
            row:Show()
        end
        for i = #list + 1, #rows do
            rows[i]:Hide()
        end

        scroll:SetContentHeight(math.max(#list * (ROW_H + GAP), 40))
    end

    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Austausch: Export und Import
------------------------------------------------------------------------

local function BuildExchange(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    f.selected = nil

    local intro = UI.CreateLabel(f, L.EXCHANGE_INTRO, { size = 12, color = "textDim", justifyV = "TOP" })
    intro:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    intro:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

    local kinds = CreateFrame("Frame", nil, f)
    kinds:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -46)
    kinds:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -46)
    kinds:SetHeight(28)

    local none = UI.CreateLabel(kinds, L.EXCHANGE_NO_HANDLERS, { size = 12, color = "textDim" })
    none:SetPoint("LEFT", kinds, "LEFT", 0, 0)

    local area = UI.CreateTextArea(f)
    area:SetPoint("TOPLEFT", kinds, "BOTTOMLEFT", 0, -12)
    area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 46)

    local status = UI.CreateLabel(f, "", { size = 12 })
    status:SetWidth(520)

    local function SetStatus(message, colorKey)
        status:SetText("|cff" .. UI.Hex(colorKey or "text") .. message .. "|r")
    end

    local function ErrorText(key, extra)
        local text = L[key]
        if key == "ERR_NO_HANDLER" then
            text = string.format(text, tostring(extra))
        elseif key == "ERR_INVALID" and type(extra) == "string" then
            text = text .. " (" .. extra .. ")"
        end
        return text
    end

    local kindButtons = {}

    local function RefreshKindButtons()
        for _, b in ipairs(kindButtons) do
            b:SetStyle(b.kind == f.selected and "primary" or "default")
        end
    end

    local function RebuildKinds()
        for _, b in ipairs(kindButtons) do
            b:Hide()
        end
        local list = Export.handlerList
        if #list == 0 then
            none:Show()
            f.selected = nil
            return
        end
        none:Hide()

        local found = false
        for _, h in ipairs(list) do
            if h.kind == f.selected then
                found = true
            end
        end
        if not found then
            f.selected = list[1].kind
        end

        local x = 0
        for i, handler in ipairs(list) do
            local b = kindButtons[i]
            if not b then
                b = UI.CreateButton(kinds, "", 150, 28, function(self)
                    f.selected = self.kind
                    RefreshKindButtons()
                end)
                kindButtons[i] = b
            end
            b.kind = handler.kind
            local label = Export.GetLabel(handler)
            b:SetLabel(label)
            b:SetWidth(math.max(110, b.label:GetStringWidth() + 32))
            b:ClearAllPoints()
            b:SetPoint("LEFT", kinds, "LEFT", x, 0)
            b:Show()
            x = x + b:GetWidth() + 8
        end
        RefreshKindButtons()
    end

    local exportButton = UI.CreateButton(f, L.EXCHANGE_EXPORT, 130, 30, function()
        if not f.selected then
            return -- der Hinweis "kein Modul" steht schon ueber dem Textfeld
        end
        local code, err, extra = Export.ExportKind(f.selected)
        if code then
            area:SetText(code)
            area:SelectAll()
            SetStatus(string.format(L.EXCHANGE_EXPORTED, #code), "success")
        else
            SetStatus(ErrorText(err, extra), "danger")
        end
    end, "primary")
    exportButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

    local importButton = UI.CreateButton(f, L.EXCHANGE_IMPORT, 130, 30, function()
        local text = area:GetText() or ""
        if not text:find("%S") then
            SetStatus(L.EXCHANGE_EMPTY, "danger")
            return
        end
        local ok, result, extra = Export.Import(text)
        if ok then
            local message = type(result) == "string" and result ~= "" and result or L.EXCHANGE_IMPORTED
            SetStatus(message, "success")
        else
            SetStatus(ErrorText(result, extra), "danger")
        end
    end)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)

    local clearButton = UI.CreateButton(f, L.EXCHANGE_CLEAR, 100, 30, function()
        area:SetText("")
        status:SetText("")
    end, "ghost")
    clearButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)

    status:SetPoint("LEFT", clearButton, "RIGHT", 16, 0)

    function f.Refresh()
        RebuildKinds()
    end

    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

-- Module koennen eigene Abschnitte in den Einstellungen anmelden:
--   UI:RegisterSettingsSection(id, { order = 100, height = 260, build = function(parent) return frame end, refresh = function(frame) end })
-- def.module (seit 0.54.0, optional) = Reiter-ID eines Moduls: der Abschnitt steht dann NICHT im Reiter Einstellungen, sondern
-- hinter dem Zahnrad oben rechts im Modul-Reiter (UI:ShowModuleSettings). Im Reiter Einstellungen > Module stehen Knoepfe dorthin.
-- def.category (optional) ordnet den Abschnitt einem Unter-Reiter zu: "general" (Standard, mit den allgemeinen Einstellungen
-- links), "database", "tooltips", "quest" oder "modules". Reiter ohne Abschnitte werden nicht gezeigt.
-- Die Abschnitte stehen in Spalten (allgemein: zwei Spalten rechts neben den allgemeinen Einstellungen). Die Hoehe eines Abschnitts
-- ist der Wert frame.flowH, wenn er ihn meldet (UI.CreateSection tut das), sonst def.height. Die ganze Seite
-- scrollt, wenn sie hoeher ist als das Fenster; die Breiten richten sich nach der Fensterbreite.
local settingsSections = {}
local settingsFrame, settingsBody, settingsScroll, settingsLeft
local vlines = {}
local catBar, catButtons = nil, {}
local currentCat
local CATS = { "general", "database", "tooltips", "interface", "design", "animation", "chat", "quest", "profiles", "modules" }
local CAT_LABEL = {
    general = "SETTINGS_CAT_GENERAL", database = "SETTINGS_CAT_DATABASE", tooltips = "SETTINGS_CAT_TOOLTIPS", interface = "SETTINGS_CAT_INTERFACE", design = "SETTINGS_CAT_DESIGN", animation = "SETTINGS_CAT_ANIMATION", chat = "SETTINGS_CAT_CHAT",
    quest = "SETTINGS_CAT_QUEST", profiles = "SETTINGS_CAT_PROFILES", modules = "SETTINGS_CAT_MODULES",
}
local function CatOf(def)
    return CAT_LABEL[def.category] and def.category or "general"
end
local function CountCats()
    local counts = {}
    for _, def in ipairs(settingsSections) do
        if not def.module then
            local c = CatOf(def)
            counts[c] = (counts[c] or 0) + 1
        end
    end
    return counts
end
-- gewaehlter Unter-Reiter (gemerkt); ohne Abschnitte faellt er auf "general" zurueck
local function CurrentCat()
    if not currentCat then
        local c = FW.settings and FW.settings.settingsCat
        currentCat = CAT_LABEL[c] and c or "general"
    end
    if currentCat ~= "general" and not CountCats()[currentCat] then
        currentCat = "general"
    end
    return currentCat
end
local function UpdateCatBar()
    if not catBar then return end
    local cat, counts, x = CurrentCat(), CountCats(), 0
    for _, b in ipairs(catButtons) do
        if b.cat == "general" or counts[b.cat] then
            b:Show()
            -- Breite nach dem Text (vorher fest 140, zu breit fuer den Rahmen)
            b:SetWidth(math.max(64, math.ceil((b.label:GetStringWidth() or 0) + 24)))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", catBar, "TOPLEFT", x, 0)
            x = x + b:GetWidth() + 4
            b:SetStyle(b.cat == cat and "primary" or "default")
        else
            b:Hide()
        end
    end
end

-- Abschnitt mit Ueberschrift, Trennlinie und einem Stapel darunter: local f, stack = UI.CreateSection(parent, "Titel")
function UI.CreateSection(parent, titleText)
    local f = CreateFrame("Frame", nil, parent)
    local title = UI.CreateLabel(f, titleText, { font = "heading", size = 14, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -26)
    local stack = UI.CreateStack(f, { y = 30, gap = 6, pad = 0 })
    stack.onHeight = function(h)
        f.flowH = h + 14
        f:SetHeight(f.flowH)
        if f.onFlow then f.onFlow() end
    end
    f.stack = stack
    f.title = title
    return f, stack
end

local SECTION_GAP = 36    -- Abstand zwischen den beiden Spalten
local LEFT_GAP = 40       -- Abstand zwischen allgemeinen Einstellungen und Abschnitten

local function LeftWidth(W)
    return FW.Util.Clamp(math.floor(W * 0.28), 300, 420)
end

local layingOut, pendingLayout, layoutDepth = false, false, 0
local LayoutSections
local function DoLayout()
    local W = settingsBody:GetWidth() or 0
    if W < 200 then
        W = 1000
    end
    local cat = CurrentCat()
    local general = cat == "general"
    local leftW = LeftWidth(W)
    local x0 = general and (leftW + LEFT_GAP) or 0
    local ncol = general and 2 or FW.Util.Clamp(math.floor((W + SECTION_GAP) / (420 + SECTION_GAP)), 1, 3)
    local colW = math.max(200, math.floor((W - x0 - (ncol - 1) * SECTION_GAP) / ncol))
    local xs, ypos = {}, {}
    for i = 1, ncol do
        xs[i] = x0 + (i - 1) * (colW + SECTION_GAP)
        ypos[i] = 0
    end
    if general then settingsLeft:Show() else settingsLeft:Hide() end
    settingsLeft:SetWidth(leftW)
    for _, def in ipairs(settingsSections) do
        local frame = def.frame
        if def.module then
            -- gehoert in die Modul-Einstellungen: hier nicht anfassen
        elseif CatOf(def) ~= cat then
            if frame then frame:Hide() end
        else
            local best = 1                                   -- jeweils in die kuerzeste Spalte
            for i = 2, ncol do
                if ypos[i] > ypos[best] then best = i end
            end
            local h = (frame and frame.flowH) or def.height or 260
            def.col, def.y = best, ypos[best]
            ypos[best] = ypos[best] - h - 10
            if frame then
                frame:Show()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", settingsBody, "TOPLEFT", xs[best], def.y)
                local wChanged = frame.laidW ~= colW
                frame.laidW = colW
                frame:SetWidth(colW)
                frame:SetHeight(h)
                if wChanged and frame.stack and frame.stack.Layout then pcall(frame.stack.Layout, frame.stack) end
            end
        end
    end
    local contentH = general and (settingsLeft.flowH or 0) or 0
    for i = 1, ncol do
        contentH = math.max(contentH, -ypos[i])
    end
    contentH = contentH + 20
    settingsBody.contentH = contentH
    settingsBody:SetHeight(contentH)
    settingsScroll:SetContentHeight(contentH)
    local pos = {}
    if general then
        pos[1] = x0 - 20
        pos[2] = xs[2] - SECTION_GAP / 2
    else
        for i = 2, ncol do pos[#pos + 1] = xs[i] - SECTION_GAP / 2 end
    end
    for i, line in ipairs(vlines) do
        if pos[i] then
            line:Show()
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", settingsBody, "TOPLEFT", pos[i], 0)
            line:SetPoint("BOTTOMLEFT", settingsBody, "TOPLEFT", pos[i], -contentH)
        else
            line:Hide()
        end
    end
    UpdateCatBar()
end

LayoutSections = function()
    if not settingsBody then
        return
    end
    if layingOut then
        pendingLayout = true     -- eine Hoehe hat sich waehrend des Anordnens geaendert: danach noch einmal
        return
    end
    layingOut = true
    local ok, err = pcall(DoLayout)
    layingOut = false
    if not ok then
        pendingLayout = false
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Freewood: Fehler in den Einstellungen: " .. tostring(err) .. "|r")
        end
        return
    end
    if pendingLayout and layoutDepth < 4 then
        pendingLayout = false
        layoutDepth = layoutDepth + 1
        LayoutSections()
        layoutDepth = layoutDepth - 1
    end
    pendingLayout = false
end

local function SelectCategory(cat)
    currentCat = cat
    if FW.settings then FW.settings.settingsCat = cat end
    LayoutSections()
end

local ModuleLayout
local moduleView      -- { frame, scroll, body, title, tab }
local function BuildSection(def, parent)
    parent = parent or settingsBody
    if def.frame or not parent then
        return
    end
    local ok, frame = pcall(def.build, parent)
    if ok and frame then
        def.frame = frame
        frame.onFlow = def.module and function() if ModuleLayout then ModuleLayout() end end or LayoutSections
        if def.refresh then
            pcall(def.refresh, frame)
        end
    end
end

function UI:RegisterSettingsSection(id, def)
    def.id = id
    def.order = def.order or 100
    settingsSections[#settingsSections + 1] = def
    table.sort(settingsSections, function(a, b)
        return a.order < b.order
    end)
    if def.module then
        if moduleView and moduleView.tab == def.module and moduleView.frame:IsShown() then
            BuildSection(def, moduleView.body)
            ModuleLayout()
        end
        FW:Fire("UI_MODULE_SETTINGS", def.module)
    else
        BuildSection(def)
    end
    LayoutSections()
end

------------------------------------------------------------------------
-- Modul-Einstellungen (seit 0.54.0): Zahnrad oben rechts im Modul-Reiter
------------------------------------------------------------------------

function UI:ModuleSections(tabId)
    local list = {}
    for _, def in ipairs(settingsSections) do
        if def.module == tabId then list[#list + 1] = def end
    end
    return list
end
function UI:HasModuleSettings(tabId)
    return tabId ~= nil and #UI:ModuleSections(tabId) > 0
end
-- Reiter mit eigenen Einstellungen: { { id, label } } in der Reihenfolge der Reiter
function UI:ModuleSettingsTabs()
    local seen, list = {}, {}
    for _, def in ipairs(settingsSections) do
        if def.module then seen[def.module] = true end
    end
    for _, t in ipairs(UI.GetTabList and UI:GetTabList() or {}) do
        if seen[t.id] then list[#list + 1] = { id = t.id, label = t.label } seen[t.id] = nil end
    end
    for id in pairs(seen) do list[#list + 1] = { id = id, label = UI.GetTabLabel and UI:GetTabLabel(id) or id } end
    return list
end

local MOD_COL_W, MOD_GAP = 420, 36
ModuleLayout = function()
    local v = moduleView
    if not v or not v.tab then return end
    local W = v.body:GetWidth() or 0
    if W < 200 then W = 1000 end
    local ncol = FW.Util.Clamp(math.floor((W + MOD_GAP) / (MOD_COL_W + MOD_GAP)), 1, 3)
    local colW = math.max(200, math.floor((W - (ncol - 1) * MOD_GAP) / ncol))
    local ypos = {}
    for i = 1, ncol do ypos[i] = 0 end
    for _, def in ipairs(settingsSections) do
        local frame = def.frame
        if def.module and frame then
            if def.module ~= v.tab then
                frame:Hide()
            else
                local best = 1
                for i = 2, ncol do if ypos[i] > ypos[best] then best = i end end
                local h = frame.flowH or def.height or 260
                frame:Show()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", v.body, "TOPLEFT", (best - 1) * (colW + MOD_GAP), ypos[best])
                local wChanged = frame.laidW ~= colW
                frame.laidW = colW
                frame:SetWidth(colW)
                frame:SetHeight(h)
                if wChanged and frame.stack and frame.stack.Layout then pcall(frame.stack.Layout, frame.stack) end
                ypos[best] = ypos[best] - h - 10
            end
        end
    end
    local h = 20
    for i = 1, ncol do h = math.max(h, -ypos[i] + 20) end
    v.body:SetHeight(h)
    v.scroll:SetContentHeight(h)
end
UI.ModuleLayout = function() ModuleLayout() end

local function BuildModuleView()
    if moduleView then return moduleView end
    local content = UI.window and UI.window.Content
    if not content then return nil end
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    f:SetAllPoints(content)
    f:SetFrameLevel((content:GetFrameLevel() or 1) + 20)
    f:EnableMouse(true)
    f:Hide()
    local back = UI.CreateButton(f, L.MODSET_BACK or "Back", 110, 26, function() UI:HideModuleSettings(true) end)
    back:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local title = UI.CreateLabel(f, "", { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("LEFT", back, "RIGHT", 14, 0)
    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -34)
    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -46)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local body = scroll.child
    body:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if type(w) == "number" and w > 0 then ModuleLayout() end
    end)
    moduleView = { frame = f, scroll = scroll, body = body, title = title, back = back }
    UI.moduleView = moduleView
    return moduleView
end

function UI:IsModuleSettingsShown(tabId)
    return moduleView ~= nil and moduleView.frame:IsShown() and (tabId == nil or moduleView.tab == tabId)
end

function UI:ShowModuleSettings(tabId)
    if not UI:HasModuleSettings(tabId) then return false end
    if UI.GetActiveTab and UI:GetActiveTab() ~= tabId then UI:SelectTab(tabId) end
    local v = BuildModuleView()
    if not v then return false end
    v.tab = tabId
    v.title:SetText(string.format(FW.L.MODSET_TITLE or "%s: settings", tostring(UI.GetTabLabel and UI:GetTabLabel(tabId) or tabId)))
    for _, def in ipairs(UI:ModuleSections(tabId)) do
        BuildSection(def, v.body)
        if def.frame and def.refresh then pcall(def.refresh, def.frame) end
    end
    local tf = UI.GetTabFrame and UI:GetTabFrame(tabId)
    if tf then tf:Hide() end
    v.frame:Show()
    ModuleLayout()
    FW:Fire("UI_MODULE_SETTINGS_SHOWN", tabId)
    return true
end

-- back = true: den Modul-Reiter wieder zeigen (Zurueck-Knopf / Zahnrad)
function UI:HideModuleSettings(back)
    if not moduleView or not moduleView.frame:IsShown() then return end
    local tabId = moduleView.tab
    moduleView.frame:Hide()
    if back and tabId and UI.GetActiveTab and UI:GetActiveTab() == tabId then UI:SelectTab(tabId) end
    FW:Fire("UI_MODULE_SETTINGS_SHOWN", nil)
end

-- Zahnrad: oben rechts ueber dem Inhalt, nur bei Reitern mit eigenen Einstellungen
local gear
local function UpdateGear()
    if not gear then return end
    local id = UI.GetActiveTab and UI:GetActiveTab()
    if UI:HasModuleSettings(id) then
        gear:Show()
        gear:SetStyle(UI:IsModuleSettingsShown(id) and "primary" or "default")
    else
        gear:Hide()
    end
end
UI.UpdateModuleGear = UpdateGear
local function BuildGear()
    local content = UI.window and UI.window.Content
    if gear or not content then return end
    gear = UI.CreateButton(UI.window, "      " .. (FW.L.MODSET_BUTTON or "Settings"), 120, 22, function()
        local id = UI:GetActiveTab()
        if UI:IsModuleSettingsShown(id) then UI:HideModuleSettings(true) else UI:ShowModuleSettings(id) end
    end)
    gear:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT", 0, -2)
    gear:SetFrameLevel((content:GetFrameLevel() or 1) + 30)
    local icon = gear:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", gear, "LEFT", 8, 0)
    gear.icon = icon
    UI.AttachTooltip(gear, function() return FW.L.MODSET_BUTTON or "Settings" end, function() return FW.L.MODSET_TIP or "" end)
    UI.moduleGear = gear
    gear:Hide()
end
BuildGear()
FW:On("UI_TAB_SELECTED", function(id)
    -- jeder Reiterwechsel (auch erneutes Waehlen desselben Reiters) zeigt wieder den Reiter selbst
    if moduleView and moduleView.frame:IsShown() then moduleView.frame:Hide() end
    UpdateGear()
end)
FW:On("UI_MODULE_SETTINGS", function() UpdateGear() end)
FW:On("UI_MODULE_SETTINGS_SHOWN", function() UpdateGear() end)

-- Reiter Einstellungen > Module: Knoepfe zu den Einstellungen in den Modulen
local function BuildModuleLinks(parent)
    local L = FW.L
    local f, stack = UI.CreateSection(parent, L.MODSET_LINKS_HEADER or "Settings in the modules")
    stack:Add(UI.CreateLabel(f, L.MODSET_LINKS_NOTE or "", { size = 11, color = "textDim", justifyV = "TOP" }), { fit = true, gap = 8 })
    local holder = CreateFrame("Frame", nil, f)
    holder:SetHeight(30)
    stack:Add(holder, { height = 30, gap = 4, stretch = true })
    f.buttons = {}
    function f.Fill()
        local list = UI:ModuleSettingsTabs()
        local x, y, w = 0, 0, holder:GetWidth() or 400
        if w < 100 then w = 400 end
        for i, t in ipairs(list) do
            local b = f.buttons[i]
            if not b then
                b = UI.CreateButton(holder, "", 120, 26, function(self) if self.tab then UI:ShowModuleSettings(self.tab) end end)
                f.buttons[i] = b
            end
            b.tab = t.id
            b:SetLabel(t.label)
            local bw = math.max(90, math.ceil((b.label and b.label:GetStringWidth() or 60) + 24))
            b:SetWidth(bw)
            if x > 0 and x + bw > w then x, y = 0, y - 30 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", holder, "TOPLEFT", x, y)
            b:Show()
            x = x + bw + 6
        end
        for i = #list + 1, #f.buttons do f.buttons[i]:Hide() end
        local h = (#list == 0) and 20 or (-y + 30)
        if f.holderH ~= h then
            f.holderH = h
            for _, it in ipairs(stack.items) do if it.w == holder then it.height = h end end
            stack:Layout()
        end
    end
    stack:Layout()
    f.Fill()
    UI.moduleLinks = f
    return f
end

local function BuildSettings(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.SETTINGS_HEADER, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local divider = UI.CreateDivider(f)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -30)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -30)

    -- Unter-Reiter (Kategorien)
    catBar = CreateFrame("Frame", nil, f)
    catBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -42)
    catBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -42)
    catBar:SetHeight(28)
    catButtons = {}
    for _, cat in ipairs(CATS) do
        local cat = cat                  -- Schleifenvariable fuer die Closure sichern
        local b = UI.CreateButton(catBar, L[CAT_LABEL[cat]], 140, 26, function() SelectCategory(cat) end)
        b.cat = cat
        catButtons[#catButtons + 1] = b
    end

    -- Alles darunter scrollt, wenn das Fenster zu niedrig ist
    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -78)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local body = scroll.child
    settingsScroll, settingsBody, settingsFrame = scroll, body, f

    -- allgemeine Einstellungen links (Stapel)
    local lf = CreateFrame("Frame", nil, body)
    lf:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    lf:SetWidth(400)
    settingsLeft = lf
    local stack = UI.CreateStack(lf, { y = 0, gap = 8 })
    stack.onHeight = function(h)
        lf.flowH = h
        lf:SetHeight(h)
    end

    local minimapBox = UI.CreateCheckbox(lf, L.SETTINGS_MINIMAP,
        function()
            return not FW.settings.minimap.hide
        end,
        function(value)
            FW.Minimap:SetHidden(not value)
        end)
    stack:Add(minimapBox, { fit = true })

    local debugBox = UI.CreateCheckbox(lf, L.SETTINGS_DEBUG,
        function()
            return FW.settings.debug and true or false
        end,
        function(value)
            FW.settings.debug = value and true or false
        end)
    stack:Add(debugBox, { fit = true })

    -- Fenstergroesse: Zeile mit - / Prozent / +
    local scaleLabel = UI.CreateLabel(lf, L.SETTINGS_SCALE, { size = 12 })
    stack:Add(scaleLabel, { height = 16, gap = 18 })
    local scaleRow = CreateFrame("Frame", nil, lf)
    scaleRow:SetHeight(26)
    stack:Add(scaleRow, { height = 26, gap = 4, stretch = true })
    local scaleValue = UI.CreateLabel(scaleRow, "", { size = 12, color = "goldLight", justify = "CENTER" })
    scaleValue:SetWidth(60)

    local function RefreshScale()
        scaleValue:SetText(string.format("%d%%", math.floor(UI:GetScale() * 100 + 0.5)))
    end
    UI:OnScaleChanged(function() RefreshScale() end)

    local minus = UI.CreateButton(scaleRow, "-", 28, 26, function()
        UI:SetScale(UI:GetScale() - 0.05)
    end)
    minus:SetPoint("LEFT", scaleRow, "LEFT", 0, 0)
    scaleValue:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local plus = UI.CreateButton(scaleRow, "+", 28, 26, function()
        UI:SetScale(UI:GetScale() + 0.05)
    end)
    plus:SetPoint("LEFT", scaleValue, "RIGHT", 4, 0)

    -- Sprache: Beschriftung oben, drei Knoepfe gleich breit darunter
    local langLabel = UI.CreateLabel(lf, L.SETTINGS_LANGUAGE, { size = 12 })
    stack:Add(langLabel, { height = 16, gap = 18 })
    local langRow = CreateFrame("Frame", nil, lf)
    langRow:SetHeight(26)
    stack:Add(langRow, { height = 26, gap = 4, stretch = true })

    local langButtons = {}
    local function RefreshLang()
        for _, b in ipairs(langButtons) do
            b:SetStyle(FW.settings.locale == b.code and "primary" or "default")
        end
    end

    local options = {
        { code = "auto", text = L.LANG_AUTO },
        { code = "deDE", text = L.LANG_DE },
        { code = "enUS", text = L.LANG_EN },
    }
    for i, option in ipairs(options) do
        local b = UI.CreateButton(langRow, option.text, 110, 26, function(self)
            FW.settings.locale = self.code
            RefreshLang()
        end)
        b.code = option.code
        langButtons[#langButtons + 1] = b
    end
    local function LayoutLang(w)
        w = w or langRow:GetWidth() or 0
        if w < 60 then return end
        local bw = math.floor((w - 12) / 3)
        for i, b in ipairs(langButtons) do
            b:ClearAllPoints()
            b:SetWidth(bw)
            b:SetPoint("LEFT", langRow, "LEFT", (i - 1) * (bw + 6), 0)
        end
    end
    langRow:SetScript("OnSizeChanged", function(self) LayoutLang(self:GetWidth()) end)
    LayoutLang(stack:Width())

    local note = UI.CreateLabel(lf, L.SETTINGS_LANGUAGE_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
    stack:Add(note, { fit = true, gap = 8 })

    local reset = UI.CreateButton(lf, L.SETTINGS_RESET_POS, 220, 28, function()
        UI:ResetPosition()
    end)
    stack:Add(reset, { height = 28, gap = 16, stretch = true })

    function f.Refresh()
        minimapBox:Refresh()
        debugBox:Refresh()
        RefreshScale()
        RefreshLang()
        for _, def in ipairs(settingsSections) do
            if def.frame and def.refresh and not def.module then
                pcall(def.refresh, def.frame)
            end
        end
        stack:Layout()
        LayoutSections()
    end

    -- senkrechte Trennstriche zwischen den Spalten
    local function VLine()
        local line = body:CreateTexture(nil, "ARTWORK")
        line:SetWidth(1)
        line:SetColorTexture(UI.Color("gold", 0.35))
        return line
    end
    vlines = { VLine(), VLine(), VLine() }

    body:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if type(w) == "number" and w > 0 then
            stack:Layout()
            LayoutSections()
        end
    end)
    for _, def in ipairs(settingsSections) do
        if not def.module then BuildSection(def) end
    end
    stack:Layout()
    LayoutSections()

    f.Refresh()
    return f
end

UI:RegisterSettingsSection("module-links", {
    category = "modules",
    order = 1,
    height = 120,
    build = BuildModuleLinks,
    refresh = function(frame) frame.Fill() end,
})

------------------------------------------------------------------------
-- Anmelden
------------------------------------------------------------------------

UI:RegisterTab("overview", {
    label = function() return FW.L.TAB_OVERVIEW end,
    order = 10,
    build = BuildOverview,
    onShow = function(f) f.Refresh() end,
})

UI:RegisterTab("exchange", {
    label = function() return FW.L.TAB_EXCHANGE end,
    order = 20,
    build = BuildExchange,
    onShow = function(f) f.Refresh() end,
})

UI:RegisterTab("settings", {
    label = function() return FW.L.TAB_SETTINGS end,
    order = 900,
    build = BuildSettings,
    onShow = function(f) f.Refresh() end,
})
