-- Freewood-Core: Notizblock (Fenster). Reiter "Notizen" (mehrere Notizen mit Titel) und "ToDo" (offen / Erledigt).
-- Oeffnen: Tastenbelegung "Notizblock" oder /fwnotiz. Verknuepfungen: Shift-Klick auf Items/Rezepte (wie im Chat) oder
-- Knopf "Verknuepfen" (Suche im Codex: Kreaturen, Quests, Items, Objekte). Klick auf eine Verknuepfung in der Leseansicht
-- oeffnet den Codex. Notizen anderer Charaktere: Auswahl oben, nur lesen; Knopf "Bearbeiten" schaltet Aendern frei.
-- Im Spiel ungeprueft.

local ADDON, NS = ...
local G = _G
local FW = G.Freewood
if not FW or not FW.UI or not FW.Notes then return end

local UI = FW.UI
local N = FW.Notes
local W = {}
N.Window = W

local MIN_W, MIN_H = 560, 380
local LIST_W = 190
local ROW_H = 24
local view = { key = nil, tab = "notes", edit = false, unlock = false, doneOpen = false, picker = false }
local win
W.view = view   -- fuer Tests

local function L() return FW.L end
local function Key() return view.key or N.CharKey() end
local function Own() return view.key == nil or view.key == N.CharKey() end
local function CanEdit() return Own() or view.unlock end

local function Opts()
    local s = FW.settings
    if not s then return {} end
    if type(s.notesWin) ~= "table" then s.notesWin = {} end
    return s.notesWin
end

local function SavePos(f)
    local o = Opts()
    local cx, cy = f:GetCenter()
    local ux, uy = G.UIParent:GetCenter()
    if cx and ux then
        o.x, o.y = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5)
    end
    o.w, o.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
end

-- einfache Eingabezeile in einem Rahmen
local function Input(parent, width, maxLetters)
    local box = UI.CreatePanel(parent, "bgDeep", "bronze")
    box:SetSize(width, 24)
    local e = CreateFrame("EditBox", nil, box)
    e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -2)
    e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 2)
    e:SetMaxLetters(maxLetters or 200)
    if not e:SetFont(UI.GetFontPath("body"), 12, "") then e:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
    e:SetTextColor(UI.Color("text"))
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) W.target = self end)
    box.edit = e
    return box
end

-- Tooltip fuer Links (Items: Spiel-Tooltip; Codex-Links: Name und Hinweis)
local function LinkEnter(owner, link, text)
    if not G.GameTooltip then return end
    G.GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    if type(link) == "string" and link:find("^fwcodex:") then
        G.GameTooltip:SetText(text or "?", 1, 1, 1)
        G.GameTooltip:AddLine(L().NOTES_LINK_HINT, 0.8, 0.8, 0.8, true)
    elseif not pcall(G.GameTooltip.SetHyperlink, G.GameTooltip, link) then
        G.GameTooltip:SetText(text or "?", 1, 1, 1)
    end
    G.GameTooltip:Show()
end
local function LinkLeave() if G.GameTooltip then G.GameTooltip:Hide() end end
local function EnableLinks(frame)
    if frame.SetHyperlinksEnabled then pcall(frame.SetHyperlinksEnabled, frame, true) end
    frame:SetScript("OnHyperlinkClick", function(_, link, text, button) N.OpenLink(link, text, button) end)
    frame:SetScript("OnHyperlinkEnter", function(self, link, text) LinkEnter(self, link, text) end)
    frame:SetScript("OnHyperlinkLeave", LinkLeave)
end

------------------------------------------------------------------------
-- Aufbau
------------------------------------------------------------------------

local Refresh

local function Build()
    local f = UI.CreatePanel(G.UIParent, "panel", "bronze")
    G.FreewoodNotesWindow = f
    if G.UISpecialFrames then table.insert(G.UISpecialFrames, "FreewoodNotesWindow") end   -- ESC schliesst
    local o = Opts()
    f:SetSize(math.max(MIN_W, o.w or 680), math.max(MIN_H, o.h or 480))
    f:SetPoint("CENTER", G.UIParent, "CENTER", o.x or 0, o.y or 40)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    if f.SetResizable then f:SetResizable(true) end
    if f.SetResizeBounds then pcall(f.SetResizeBounds, f, MIN_W, MIN_H) elseif f.SetMinResize then pcall(f.SetMinResize, f, MIN_W, MIN_H) end
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePos(self) end)
    f:SetScript("OnHide", function() if W.SaveBody then W.SaveBody() end if W.picker then W.picker:Hide() end end)
    f:Hide()

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() SavePos(f) Refresh() end)

    local title = UI.CreateLabel(f, L().NOTES_TITLE, { font = "heading", size = 15, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)

    local close = UI.CreateButton(f, "X", 22, 22, function() f:Hide() end, "default")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    -- Charakter-Auswahl und Bearbeiten-Knopf (nur bei fremden Charakteren)
    local unlock = UI.CreateButton(f, L().NOTES_UNLOCK, 110, 22, function()
        view.unlock = not view.unlock
        view.edit = false
        Refresh()
    end, "default")
    unlock:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local charDd = UI.CreateDropdown(f, 220, 22, {
        getOptions = function()
            local list = {}
            for _, c in ipairs(N.Chars()) do
                list[#list + 1] = { value = c.key, text = c.key .. (c.own and (" " .. L().NOTES_YOU) or "") }
            end
            return list
        end,
        textOf = function(v) return tostring(v or "") .. ((v == N.CharKey()) and (" " .. L().NOTES_YOU) or "") end,
        onChange = function(v)
            if v == nil then return end
            W.SaveBody()
            view.key = (v == N.CharKey()) and nil or v
            view.unlock, view.edit = false, false
            Refresh()
        end,
    })
    charDd:SetPoint("RIGHT", unlock, "LEFT", -6, 0)

    -- Reiter
    local tabNotes = UI.CreateButton(f, L().NOTES_TAB_NOTES, 120, 24, function() W.SaveBody() view.tab = "notes" Refresh() end, "default")
    tabNotes:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
    local tabTodo = UI.CreateButton(f, L().NOTES_TAB_TODO, 120, 24, function() W.SaveBody() view.tab = "todo" Refresh() end, "default")
    tabTodo:SetPoint("LEFT", tabNotes, "RIGHT", 6, 0)
    local ro = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
    ro:SetPoint("LEFT", tabTodo, "RIGHT", 12, 0)

    ------------------------------------------------------------------ Notizen
    local nf = CreateFrame("Frame", nil, f)
    nf:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70)
    nf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

    local list = UI.CreateScrollFrame(nf, LIST_W, 100)
    list:SetPoint("TOPLEFT", nf, "TOPLEFT", 0, 0)
    list:SetPoint("BOTTOMLEFT", nf, "BOTTOMLEFT", 0, 32)
    list:SetWidth(LIST_W)
    local rows = {}
    local btnNew = UI.CreateButton(nf, L().NOTES_NEW, 92, 24, function()
        W.SaveBody()
        local n = N.Add(Key())
        if n then view.edit = false Refresh() end
    end, "primary")
    btnNew:SetPoint("BOTTOMLEFT", nf, "BOTTOMLEFT", 0, 0)
    local btnDel = UI.CreateButton(nf, L().NOTES_DELETE, 92, 24, function()
        local d = N.Data(Key())
        if d and d.cur then N.Delete(Key(), d.cur) view.edit = false Refresh() end
    end, "default")
    btnDel:SetPoint("LEFT", btnNew, "RIGHT", 6, 0)

    local right = CreateFrame("Frame", nil, nf)
    right:SetPoint("TOPLEFT", nf, "TOPLEFT", LIST_W + 12, 0)
    right:SetPoint("BOTTOMRIGHT", nf, "BOTTOMRIGHT", 0, 0)
    local titleBox = Input(right, 200, 60)
    titleBox:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
    titleBox:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, 0)
    local function SaveTitle(self)
        local d = N.Data(Key())
        if d and d.cur and CanEdit() then N.SetTitle(Key(), d.cur, self:GetText()) end
        W.RefreshList()
    end
    titleBox.edit:SetScript("OnEnterPressed", function(self) SaveTitle(self) self:ClearFocus() end)
    titleBox.edit:SetScript("OnEditFocusLost", SaveTitle)

    -- Leseansicht (klickbare Links)
    local readHolder = UI.CreateScrollFrame(right, 100, 100)
    readHolder:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -6)
    readHolder:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 32)
    local readBg = readHolder:CreateTexture(nil, "BACKGROUND", nil, -1)
    readBg:SetPoint("TOPLEFT", readHolder, "TOPLEFT", 0, 0)
    readBg:SetPoint("BOTTOMRIGHT", readHolder, "BOTTOMRIGHT", -12, 0)
    readBg:SetColorTexture(UI.Color("bgDeep", 0.9))
    local readFs = readHolder.child:CreateFontString(nil, "OVERLAY")
    UI.SetFont(readFs, "body", 12)
    readFs:SetPoint("TOPLEFT", readHolder.child, "TOPLEFT", 8, -6)
    readFs:SetJustifyH("LEFT")
    readFs:SetJustifyV("TOP")
    readFs:SetWordWrap(true)
    EnableLinks(readHolder.child)

    -- Schreibansicht
    local area = UI.CreateTextArea(right, 100, 100)
    area:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -6)
    area:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 32)
    area.edit:SetMaxLetters(20000)
    area.edit:HookScript("OnEditFocusGained", function(self) W.target = self end)

    local editBtn = UI.CreateButton(right, L().NOTES_WRITE, 110, 24, function()
        if view.edit then W.SaveBody() view.edit = false else view.edit = true end
        Refresh()
        if view.edit then area.edit:SetFocus() end
    end, "primary")
    editBtn:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
    local linkBtn = UI.CreateButton(right, L().NOTES_LINK, 110, 24, function()
        if not view.edit then view.edit = true Refresh() end
        W.OpenPicker(area.edit)
    end, "default")
    linkBtn:SetPoint("LEFT", editBtn, "RIGHT", 6, 0)
    local hint = UI.CreateLabel(right, L().NOTES_SHIFT_HINT, { size = 10, color = "textDim" })
    hint:SetPoint("LEFT", linkBtn, "RIGHT", 10, 0)
    hint:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    hint:SetWordWrap(true)

    function W.SaveBody()
        if not (view.edit and CanEdit()) then return end
        local d = N.Data(Key())
        if d and d.cur then N.SetText(Key(), d.cur, area:GetText()) end
    end

    function W.RefreshList()
        local d = N.Data(Key())
        local notes = d and d.notes or {}
        if d and not d.cur and notes[1] then d.cur = notes[1].id end
        for i, n in ipairs(notes) do
            local r = rows[i]
            if not r then
                r = UI.CreateButton(list.child, "", LIST_W - 16, ROW_H - 2, nil, "default")
                r:SetPoint("TOPLEFT", list.child, "TOPLEFT", 0, -(i - 1) * ROW_H)
                r.label:ClearAllPoints()
                r.label:SetPoint("LEFT", r, "LEFT", 6, 0)
                r.label:SetPoint("RIGHT", r, "RIGHT", -6, 0)
                r.label:SetJustifyH("LEFT")
                r.label:SetWordWrap(false)
                r:SetScript("OnClick", function(self)
                    W.SaveBody()
                    local dd = N.Data(Key())
                    if dd then dd.cur = self.noteId end
                    view.edit = false
                    Refresh()
                end)
                rows[i] = r
            end
            r.noteId = n.id
            r:SetLabel(N.Plain(n.title))
            r:SetStyle(d.cur == n.id and "primary" or "default")
            r:Show()
        end
        for i = #notes + 1, #rows do rows[i]:Hide() end
        list:SetContentHeight(#notes * ROW_H)
    end

    function W.RefreshNote()
        local d = N.Data(Key())
        local n = d and d.cur and N.Find(Key(), d.cur)
        local can = CanEdit()
        btnNew:SetButtonEnabled(can)
        btnDel:SetButtonEnabled(can and n ~= nil)
        editBtn:SetButtonEnabled(can and n ~= nil)
        linkBtn:SetButtonEnabled(can and n ~= nil)
        titleBox.edit:EnableMouse(can and n ~= nil)
        if not titleBox.edit:HasFocus() then titleBox.edit:SetText(n and n.title or "") end
        if not can then view.edit = false end
        editBtn:SetLabel(view.edit and L().NOTES_DONE_EDIT or L().NOTES_WRITE)
        if view.edit and n then
            readHolder:Hide()
            area:Show()
            if not area.edit:HasFocus() then area:SetText(n.text or "") end
        else
            area:Hide()
            readHolder:Show()
            local w = math.max(50, readHolder.scroll:GetWidth() - 16)
            readFs:SetWidth(w)
            local text = n and n.text or ""
            if n == nil then
                readFs:SetText("|cff9a978c" .. ((d and #d.notes == 0) and L().NOTES_NONE or "") .. "|r")
            elseif text == "" then
                readFs:SetText("|cff9a978c" .. L().NOTES_EMPTY .. "|r")
            else
                readFs:SetText(text)
            end
            readHolder:SetContentHeight((readFs:GetStringHeight() or 0) + 16)
        end
    end

    ------------------------------------------------------------------ ToDo
    local tf = CreateFrame("Frame", nil, f)
    tf:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70)
    tf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    local todoIn = Input(tf, 300, 500)
    todoIn:SetPoint("TOPLEFT", tf, "TOPLEFT", 0, 0)
    todoIn:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -232, 0)
    local function AddTodo()
        if not CanEdit() then return end
        if N.TodoAdd(Key(), todoIn.edit:GetText()) then todoIn.edit:SetText("") Refresh() end
    end
    todoIn.edit:SetScript("OnEnterPressed", function() AddTodo() end)
    local addBtn = UI.CreateButton(tf, L().TODO_ADD, 110, 24, AddTodo, "primary")
    addBtn:SetPoint("LEFT", todoIn, "RIGHT", 6, 0)
    local tLinkBtn = UI.CreateButton(tf, L().NOTES_LINK, 110, 24, function() W.OpenPicker(todoIn.edit) end, "default")
    tLinkBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)

    local tlist = UI.CreateScrollFrame(tf, 100, 100)
    tlist:SetPoint("TOPLEFT", todoIn, "BOTTOMLEFT", 0, -8)
    tlist:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", 0, 0)
    local trows = {}

    local function SmallBtn(parent, text, fn)
        local b = UI.CreateButton(parent, text, 22, 20, fn, "default")
        return b
    end
    local function TodoRow(i)
        local r = trows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, tlist.child)
        r:SetHeight(ROW_H + 2)
        EnableLinks(r)
        r.check = CreateFrame("Button", nil, r)
        r.check:SetSize(18, 18)
        r.check:SetPoint("LEFT", r, "LEFT", 2, 0)
        local box = UI.CreatePanel(r.check, "card", "bronze")
        box:SetAllPoints(r.check)
        r.tick = box:CreateTexture(nil, "ARTWORK")
        r.tick:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
        r.tick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
        r.tick:SetColorTexture(UI.Color("goldLight"))
        r.check:SetScript("OnClick", function()
            if r.entryId and CanEdit() then N.TodoToggle(Key(), r.entryId) Refresh() end
        end)
        r.text = r:CreateFontString(nil, "OVERLAY")
        UI.SetFont(r.text, "body", 12)
        r.text:SetPoint("LEFT", r.check, "RIGHT", 8, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r.del = SmallBtn(r, "x", function() if r.entryId and CanEdit() then N.TodoDelete(Key(), r.entryId) Refresh() end end)
        r.del:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.down = SmallBtn(r, "v", function() if r.entryId and CanEdit() then N.TodoMove(Key(), r.entryId, 1) Refresh() end end)
        r.down:SetPoint("RIGHT", r.del, "LEFT", -3, 0)
        r.up = SmallBtn(r, "^", function() if r.entryId and CanEdit() then N.TodoMove(Key(), r.entryId, -1) Refresh() end end)
        r.up:SetPoint("RIGHT", r.down, "LEFT", -3, 0)
        r.text:SetPoint("RIGHT", r.up, "LEFT", -6, 0)
        r.head = UI.CreateButton(r, "", 200, 22, function() view.doneOpen = not view.doneOpen Refresh() end, "default")
        r.head:SetPoint("LEFT", r, "LEFT", 0, 0)
        trows[i] = r
        return r
    end

    function W.RefreshTodo()
        local can = CanEdit()
        addBtn:SetButtonEnabled(can)
        tLinkBtn:SetButtonEnabled(can)
        todoIn.edit:EnableMouse(can)
        local open, done = N.TodoOpen(Key()), N.TodoDone(Key())
        local i, y = 0, 0
        local width = math.max(100, tlist.scroll:GetWidth())
        local function Place(r)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", tlist.child, "TOPLEFT", 0, -y)
            r:SetWidth(width)
            r:Show()
            y = y + ROW_H + 2
        end
        local function Entry(e, isDone)
            i = i + 1
            local r = TodoRow(i)
            r.head:Hide()
            r.check:Show()
            r.text:Show()
            r.entryId = e.id
            r.tick:SetShown(isDone)
            r.text:SetText(isDone and ("|cff9a978c" .. N.Plain(e.text) .. "|r") or e.text)
            r.del:SetShown(can)
            r.up:SetShown(can and not isDone)
            r.down:SetShown(can and not isDone)
            Place(r)
        end
        for _, e in ipairs(open) do Entry(e, false) end
        if #open == 0 then
            i = i + 1
            local r = TodoRow(i)
            r.head:Hide() r.check:Hide() r.up:Hide() r.down:Hide() r.del:Hide()
            r.entryId = nil
            r.text:Show()
            r.text:SetText("|cff9a978c" .. L().TODO_NONE .. "|r")
            Place(r)
        end
        if #done > 0 then
            i = i + 1
            local r = TodoRow(i)
            r.check:Hide() r.text:Hide() r.up:Hide() r.down:Hide() r.del:Hide()
            r.entryId = nil
            r.head:Show()
            r.head:SetLabel(string.format(L().TODO_DONE, #done) .. (view.doneOpen and "  -" or "  +"))
            y = y + 6
            Place(r)
            if view.doneOpen then
                for _, e in ipairs(done) do Entry(e, true) end
            end
        end
        for k = i + 1, #trows do trows[k]:Hide() end
        tlist:SetContentHeight(y + 4)
    end

    ------------------------------------------------------------------ Verknuepfen (Suche im Codex)
    local pk = UI.CreatePanel(f, "panel", "gold")
    pk:SetSize(300, 330)
    pk:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
    pk:SetFrameStrata("DIALOG")
    pk:EnableMouse(true)
    pk:Hide()
    W.picker = pk
    local pkTitle = UI.CreateLabel(pk, L().NOTES_LINK_TITLE, { size = 13, color = "goldLight" })
    pkTitle:SetPoint("TOPLEFT", pk, "TOPLEFT", 10, -10)
    local pkClose = UI.CreateButton(pk, "X", 20, 20, function() pk:Hide() end, "default")
    pkClose:SetPoint("TOPRIGHT", pk, "TOPRIGHT", -6, -6)
    local search = Input(pk, 280, 60)
    search:SetPoint("TOPLEFT", pk, "TOPLEFT", 10, -36)
    local pkHint = UI.CreateLabel(pk, L().NOTES_SEARCH_HINT, { size = 10, color = "textDim" })
    pkHint:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -4)
    pkHint:SetWidth(280)
    pkHint:SetWordWrap(true)
    local results = {}
    local function Insert(entry)
        local tgt = W.pickTarget
        if not tgt then return end
        local link
        if entry.kind == "items" then
            local gi = G.C_Item and G.C_Item.GetItemInfo or G.GetItemInfo
            if gi then
                local ok, _, l = pcall(gi, entry.id)
                if ok and type(l) == "string" then link = l end
            end
        end
        link = link or N.MakeLink(entry.kind, entry.id, entry.name)
        if link then
            tgt:SetFocus()
            tgt:Insert(link .. " ")
        end
        pk:Hide()
    end
    local function RunSearch()
        local C = FW.Codex
        local list = (C and C.SearchEntries) and C.SearchEntries(search.edit:GetText(), 5) or {}
        for k = 1, 12 do
            local e = list[k]
            local b = results[k]
            if not b then
                b = UI.CreateButton(pk, "", 280, 20, function(self) if self.entry then Insert(self.entry) end end, "default")
                b:SetPoint("TOPLEFT", pk, "TOPLEFT", 10, -86 - (k - 1) * 22)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.label:SetJustifyH("LEFT")
                b.label:SetWordWrap(false)
                results[k] = b
            end
            b.entry = e
            if e then
                b:SetLabel("|cff9a978c" .. (L()["NOTES_KIND_" .. e.kind] or e.kind) .. ":|r " .. e.name)
                b:Show()
            else
                b:Hide()
            end
        end
        if not (C and C.SearchEntries) then pkHint:SetText(L().NOTES_NO_CODEX) end
    end
    search.edit:SetScript("OnTextChanged", function() RunSearch() end)
    search.edit:SetScript("OnEnterPressed", function() if results[1] and results[1].entry then Insert(results[1].entry) end end)
    function W.OpenPicker(target)
        if not CanEdit() then return end
        W.pickTarget = target
        search.edit:SetText("")
        RunSearch()
        pk:Show()
        search.edit:SetFocus()
    end

    ------------------------------------------------------------------ Gesamtanzeige
    Refresh = function()
        if not f:IsShown() then return end
        charDd:SetValue(Key())
        local own = Own()
        unlock:SetShown(not own)
        unlock:SetLabel(view.unlock and L().NOTES_LOCK or L().NOTES_UNLOCK)
        unlock:SetStyle(view.unlock and "primary" or "default")
        ro:SetText(own and "" or (view.unlock and L().NOTES_EDITING_OTHER or L().NOTES_READONLY))
        tabNotes:SetStyle(view.tab == "notes" and "primary" or "default")
        tabTodo:SetStyle(view.tab == "todo" and "primary" or "default")
        if view.tab == "notes" then
            tf:Hide()
            nf:Show()
            W.RefreshList()
            W.RefreshNote()
        else
            nf:Hide()
            tf:Show()
            W.RefreshTodo()
        end
        if not CanEdit() and pk:IsShown() then pk:Hide() end
    end
    f:SetScript("OnShow", function() Refresh() end)
    f:SetScript("OnSizeChanged", function() if f:IsShown() then Refresh() end end)
    return f
end

------------------------------------------------------------------------
-- Oeffnen / Schliessen, Shift-Klick-Links
------------------------------------------------------------------------

function N.Toggle()
    if not FW.db then return end
    win = win or Build()
    if win:IsShown() then win:Hide() else win:Show() end
end

function N.Refresh() if Refresh then Refresh() end end

-- Shift-Klick auf Items/Rezepte: Link ins gerade aktive Notiz- oder ToDo-Feld (wie im Chat)
if G.hooksecurefunc and G.ChatEdit_InsertLink then
    G.hooksecurefunc("ChatEdit_InsertLink", function(text)
        local t = W.target
        if win and win:IsShown() and t and t.HasFocus and t:HasFocus() and type(text) == "string" and CanEdit() then
            t:Insert(text)
        end
    end)
end
