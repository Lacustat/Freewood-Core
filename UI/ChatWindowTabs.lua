-- Freewood-Core: Reiter-Editor und Einstellungen fuer das Freewood-Chatfenster, Kampflog-Spiegel.
-- Rechtsklick auf einen Reiter oder "+" oeffnet den Editor: Name, Gruppen, Kanaele, verschieben, loeschen.
-- Das Chatfenster selbst steht in UI/ChatWindow.lua. UNGEPRUEFT im Spiel.

local ADDON, FW = ...

local UI = FW.UI
local G = _G
local W = FW.ChatWindow
if not W or not UI then return end

local MAX_CHAN_ROWS = 10
local DEFAULT_CHANNELS = { "Allgemein", "Handel", "LokaleVerteidigung", "SucheNachGruppe" }

------------------------------------------------------------------------
-- Kanaele eines Reiters (rein rechnerisch, mit Tests)
------------------------------------------------------------------------

function W.TabHasChannel(tab, name)
    local n = W.NormChannel(name)
    for _, c in ipairs(tab.channels or {}) do
        if W.NormChannel(c) == n then return true end
    end
    return false
end

function W.TabSetChannel(tab, name, on)
    tab.channels = tab.channels or {}
    local n = W.NormChannel(name)
    for i = #tab.channels, 1, -1 do
        if W.NormChannel(tab.channels[i]) == n then table.remove(tab.channels, i) end
    end
    if on and n ~= "" then tab.channels[#tab.channels + 1] = name end
end

-- Kanalnamen fuer die Auswahl: erst die des Reiters, dann gesehene, dann die ueblichen
function W.EditorChannelNames(tab)
    local out, seen = {}, {}
    local function Add(n)
        local k = W.NormChannel(n)
        if k ~= "" and not seen[k] then seen[k] = true; out[#out + 1] = n end
    end
    for _, n in ipairs(tab and tab.channels or {}) do Add(n) end
    for _, n in ipairs(DEFAULT_CHANNELS) do Add(n) end
    for _, n in ipairs(W.Opts().knownChannels or {}) do Add(n) end
    return out
end

------------------------------------------------------------------------
-- Editor
------------------------------------------------------------------------

local ed, tabId
local boxes, chanRows = {}, {}

local function CurTab() return W.FindTab(tabId) end

local function After(redraw)
    if W.RefreshTabs then W.RefreshTabs() end
    if redraw and W.Dirty then W.Dirty() end
end

local function RefreshAll()
    if not ed then return end
    local t = CurTab()
    if not t then return end
    for _, cb in ipairs(boxes) do cb:Refresh() end
    local names = W.EditorChannelNames(t)
    for i = 1, MAX_CHAN_ROWS do
        local row = chanRows[i]
        if names[i] then
            row.chName = names[i]
            row:SetLabel(names[i])
            row:SetWidth(200)
            row:Show()
            row:Refresh()
        else
            row.chName = nil
            row:Hide()
        end
    end
end

local function CommitName()
    if not (ed and ed.nameBox) then return end
    local t = CurTab()
    local txt = string.gsub(ed.nameBox:GetText() or "", "^%s+", "")
    txt = string.gsub(txt, "%s+$", "")
    if t and txt ~= "" and txt ~= W.TabName(t) then
        t.name = txt
        After()
    end
end

local function MakeEditBox(parent, width)
    local box = UI.CreatePanel(parent, "card", "bronze")
    box:SetSize(width, 24)
    local e = CreateFrame("EditBox", nil, box)
    e:SetAutoFocus(false)      -- sonst haelt das Feld die Tastatur fest (F-28)
    e:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -3)
    e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 3)
    e:SetMaxLetters(40)
    UI.SetFont(e, "body", 12)
    e:SetTextColor(UI.Color("text"))
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box, e
end

local function BuildEditor()
    if ed then return end
    local L = FW.L
    ed = UI.CreatePanel(G.UIParent, "bgDeep", "bronze")
    ed:SetSize(700, 480)
    ed:SetPoint("CENTER", G.UIParent, "CENTER", 0, 40)
    ed:SetFrameStrata("DIALOG")
    ed:SetClampedToScreen(true)
    ed:EnableMouse(true)
    ed:SetMovable(true)
    ed:RegisterForDrag("LeftButton")
    ed:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ed:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ed:Hide()

    local title = UI.CreateLabel(ed, L.CHATWIN_EDIT_TITLE, { font = "heading", size = 14, color = "goldLight" })
    title:SetPoint("TOPLEFT", ed, "TOPLEFT", 16, -14)

    local nl = UI.CreateLabel(ed, L.CHATWIN_EDIT_NAME, { size = 12, color = "textDim" })
    nl:SetPoint("TOPLEFT", ed, "TOPLEFT", 16, -46)
    local nbox, nedit = MakeEditBox(ed, 260)
    nbox:SetPoint("TOPLEFT", ed, "TOPLEFT", 16, -66)
    nedit:SetScript("OnEnterPressed", function(self) CommitName(); self:ClearFocus() end)
    nedit:SetScript("OnEditFocusLost", function() CommitName() end)
    ed.nameBox = nedit

    local function Header(x, text)
        local h = UI.CreateLabel(ed, text, { size = 12, color = "goldLight" })
        h:SetPoint("TOPLEFT", ed, "TOPLEFT", x, -104)
    end
    Header(16, L.CHATWIN_EDIT_CHAT)
    Header(236, L.CHATWIN_EDIT_MSGS)
    Header(456, L.CHATWIN_EDIT_CHANNELS)

    local yChat, yMsgs = 128, 128
    for _, g in ipairs(W.GROUPS) do
        local id = g[1]
        local cb = UI.CreateCheckbox(ed, L[g[2]] or id,
            function()
                local t = CurTab()
                return t ~= nil and t.groups ~= nil and t.groups[id] == true
            end,
            function(v)
                local t = CurTab()
                if not t then return end
                t.groups = t.groups or {}
                t.groups[id] = v and true or nil
                After(true)
            end)
        if g[3] == "chat" then
            cb:SetPoint("TOPLEFT", ed, "TOPLEFT", 16, -yChat); yChat = yChat + 24
        else
            cb:SetPoint("TOPLEFT", ed, "TOPLEFT", 236, -yMsgs); yMsgs = yMsgs + 24
        end
        boxes[#boxes + 1] = cb
    end

    local all = UI.CreateCheckbox(ed, L.CHATWIN_G_CHANNELS_ALL,
        function() local t = CurTab(); return t ~= nil and t.allChannels == true end,
        function(v) local t = CurTab(); if t then t.allChannels = v and true or nil; After(true) end end)
    all:SetPoint("TOPLEFT", ed, "TOPLEFT", 456, -128)
    boxes[#boxes + 1] = all

    for i = 1, MAX_CHAN_ROWS do
        local cb
        cb = UI.CreateCheckbox(ed, "",
            function()
                local t = CurTab()
                return t ~= nil and cb.chName ~= nil and W.TabHasChannel(t, cb.chName)
            end,
            function(v)
                local t = CurTab()
                if t and cb.chName then W.TabSetChannel(t, cb.chName, v); After(true) end
            end)
        cb:SetPoint("TOPLEFT", ed, "TOPLEFT", 456, -(152 + (i - 1) * 24))
        cb:Hide()
        chanRows[i] = cb
    end

    local abox, aedit = MakeEditBox(ed, 150)
    abox:SetPoint("TOPLEFT", ed, "TOPLEFT", 456, -(152 + MAX_CHAN_ROWS * 24 + 6))
    local function AddChannel()
        local t = CurTab()
        local txt = string.gsub(aedit:GetText() or "", "^%s+", "")
        txt = string.gsub(txt, "%s+$", "")
        if t and txt ~= "" then
            W.TabSetChannel(t, txt, true)
            aedit:SetText("")
            RefreshAll()
            After(true)
        end
    end
    aedit:SetScript("OnEnterPressed", function(self) AddChannel(); self:ClearFocus() end)
    local ahint = UI.CreateLabel(abox, L.CHATWIN_EDIT_ADD_CH, { size = 11, color = "textDim" })
    ahint:SetPoint("LEFT", abox, "LEFT", 8, 0)
    aedit:SetScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" then ahint:Show() else ahint:Hide() end
    end)
    local abtn = UI.CreateButton(ed, "+", 28, 24, AddChannel)
    abtn:SetPoint("LEFT", abox, "RIGHT", 4, 0)

    local function Btn(x, text, w, fn)
        local b = UI.CreateButton(ed, text, w, 28, fn)
        b:SetPoint("BOTTOMLEFT", ed, "BOTTOMLEFT", x, 16)
        return b
    end
    Btn(16, L.CHATWIN_EDIT_LEFT, 120, function() if W.MoveTab(tabId, -1) then After() end end)
    Btn(144, L.CHATWIN_EDIT_RIGHT, 120, function() if W.MoveTab(tabId, 1) then After() end end)
    Btn(272, L.CHATWIN_EDIT_DELETE, 140, function()
        if W.RemoveTab(tabId) then
            ed:Hide()
            W.SelectTab(W.CurrentTab().id)
            After(true)
        elseif FW.Print then
            FW:Print(L.CHATWIN_EDIT_LAST)
        end
    end)
    local done = UI.CreateButton(ed, L.CHATWIN_EDIT_DONE, 120, 28, function()
        CommitName()
        ed:Hide()
        After(true)
    end, "primary")
    done:SetPoint("BOTTOMRIGHT", ed, "BOTTOMRIGHT", -16, 16)
end

function W.OpenTabEditor(id)
    BuildEditor()
    tabId = id
    local t = CurTab()
    if not t then return end
    ed.nameBox:SetText(W.TabName(t))
    RefreshAll()
    ed:Show()
end

function W.NewTab()
    local t = W.AddTab(FW.L.CHATWIN_NEW_TAB or "New")
    W.SelectTab(t.id)
    W.OpenTabEditor(t.id)
end

------------------------------------------------------------------------
-- Kampflog des Spiels in den Reiter spiegeln (begrenzt, schaltbar)
------------------------------------------------------------------------

function W.HookCombat()
    if W.combatHooked then return end
    local cf = G.COMBATLOG or G.ChatFrame2
    if not (cf and G.hooksecurefunc and cf.AddMessage) then return end
    W.combatHooked = true
    local count, stamp = 0, 0
    pcall(G.hooksecurefunc, cf, "AddMessage", function(_, text)
        if W.Opts().combatMirror ~= true then return end
        if type(text) ~= "string" then return end
        local now = G.GetTime and G.GetTime() or 0
        if now - stamp >= 1 then stamp, count = now, 0 end
        count = count + 1
        if count > 60 then return end       -- Schutz bei sehr vielen Zeilen pro Sekunde
        W.Add("combat", "", text, false)
    end)
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function() pcall(W.HookCombat) end)
FW:RegisterEvent("UPDATE_CHAT_WINDOWS", function() pcall(W.HookCombat) end)

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("chat-window-tabs", {
        category = "chat",
        order = 6,
        height = 300,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATWIN_TABS_TITLE)
            stack:Add(UI.CreateLabel(f, L.CHATWIN_TABS_HINT, { size = 11, color = "textDim" }), { fit = true, gap = 4 })
            local pick = W.CurrentTab().id
            local dd = UI.CreateDropdown(f, 240, 22, {
                getOptions = function()
                    local list = {}
                    for _, t in ipairs(W.Tabs()) do list[#list + 1] = { value = t.id, text = W.TabName(t) } end
                    return list
                end,
                textOf = function(v) local t = W.FindTab(v); return t and W.TabName(t) or "" end,
                onChange = function(v) if v then pick = v end end,
            })
            dd:SetValue(pick)
            stack:Add(dd, { height = 22, gap = 8 })
            stack:Add(UI.CreateButton(f, L.CHATWIN_TABS_EDIT, 240, 24, function()
                if W.FindTab(pick) then W.OpenTabEditor(pick) end
            end), { height = 24, gap = 6 })
            stack:Add(UI.CreateButton(f, L.CHATWIN_TABS_NEW, 240, 24, function()
                if W.Build then W.Build() end
                W.NewTab()
                pick = W.CurrentTab().id
                dd:SetValue(pick)
            end), { height = 24, gap = 4 })
            stack:Add(UI.CreateButton(f, L.CHATWIN_TABS_RESTORE, 240, 24, function()
                local o = W.Opts()
                o.tabs = nil
                local tabs = W.Tabs()
                o.tab = tabs[1].id
                W.unread = {}
                pick = tabs[1].id
                dd:SetValue(pick)
                if W.RefreshTabs then W.RefreshTabs() end
                if W.Dirty then W.Dirty() end
            end), { height = 24, gap = 4 })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_COMBAT_MIRROR,
                function() return W.Opts().combatMirror == true end,
                function(v) W.Opts().combatMirror = v and true or false end), { fit = true, gap = 10 })
            return f
        end,
    })

    UI:RegisterSettingsSection("chat-window-styles", {
        category = "chat",
        order = 7,
        height = 520,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATWIN_STYLE_TITLE)
            stack:Add(UI.CreateLabel(f, L.CHATWIN_STYLE_HINT, { size = 11, color = "textDim" }), { fit = true, gap = 4 })
            local function Box(label, kind)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return W.Style(kind) == "bubble" end,
                    function(v)
                        local o = W.Opts()
                        if type(o.styles) ~= "table" then o.styles = {} end
                        o.styles[kind] = v and "bubble" or "line"
                        if W.Dirty then W.Dirty() end
                    end), { fit = true })
            end
            for _, g in ipairs(W.GROUPS) do Box(L[g[2]] or g[1], g[1]) end
            Box(L.CHATWIN_G_CHANNELS, "channel")
            return f
        end,
    })
end
