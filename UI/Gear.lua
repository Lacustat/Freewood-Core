-- Freewood-Core: Oberfläche "Ausrüstung nach Ereignis" (0.64.0)
-- Ein Aufbau für zwei Orte: Reiter "Ausrüstung" im Freewood-Fenster und Umschalter "Werte | Ausrüstung"
-- in der Charakteransicht. Beide zeigen dieselben Daten (FW.Gear) und frischen sich gegenseitig auf.
-- Copyright (C) 2026 Lacustat. GPL-3.0-or-later.

local ADDON, FW = ...
local G = _G
local UI = FW.UI
local GS = FW.Gear

local GU = { views = {} }
FW.GearUI = GU

FW:AddLocale("enUS", {
    GEAR_ON = "Switch automatically", GEAR_MSG = "Message in chat when switching",
    GEAR_DEFAULT = "Standard equipment", GEAR_PROFILES = "Profiles", GEAR_RULES = "Rules (the upper one wins)",
    GEAR_SAVE = "Save current equipment", GEAR_NAME_HINT = "Name", GEAR_WEAR = "Wear", GEAR_EDIT = "Edit",
    GEAR_OVERWRITE = "Overwrite with current equipment", GEAR_RENAME = "Rename", GEAR_SURE = "Sure?",
    GEAR_NEW_RULE = "New rule", GEAR_EDIT_RULE = "Edit rule", GEAR_EVENT = "Event", GEAR_TARGET = "Put on",
    GEAR_ADD = "Add rule", GEAR_SAVE_RULE = "Save", GEAR_CANCEL = "Cancel", GEAR_HERE = "Current zone",
    GEAR_ZONE_HINT = "Zone or subzone name", GEAR_DROP = "Drop an item here (or click with it)", GEAR_SLOT = "Slot",
    GEAR_NO_FORMS = "This character has no forms or stances.", GEAR_NONE_PROFILES = "No profiles yet: put on what you want and click \"Save current equipment\".",
    GEAR_NONE_RULES = "No rules yet.", GEAR_STATUS_IDLE = "Now: standard equipment", GEAR_STATUS = "Now active: %s",
    GEAR_ON_SHORT = "On", GEAR_OFF_SHORT = "Off", GEAR_EMPTY = "(empty)", GEAR_STATS = "Stats",
    GEAR_INFO = "Assign a profile, a Blizzard equipment set or a single item to an event. When the event ends the rule stops and the next active rule applies, otherwise the standard equipment. If several rules are active, the upper one wins for each slot it contains. In combat only weapons, shield/off-hand and ranged change; the rest follows after combat. A profile can hold only some slots: click Edit and remove the slots you don't need. Fishing has no game event: use the key (Key Bindings > Freewood, needs a full game restart once) or /fwgear fish.",
    GEAR_SLOT_1 = "Head", GEAR_SLOT_2 = "Neck", GEAR_SLOT_3 = "Shoulder", GEAR_SLOT_4 = "Shirt", GEAR_SLOT_5 = "Chest",
    GEAR_SLOT_6 = "Waist", GEAR_SLOT_7 = "Legs", GEAR_SLOT_8 = "Feet", GEAR_SLOT_9 = "Wrist", GEAR_SLOT_10 = "Hands",
    GEAR_SLOT_11 = "Finger 1", GEAR_SLOT_12 = "Finger 2", GEAR_SLOT_13 = "Trinket 1", GEAR_SLOT_14 = "Trinket 2",
    GEAR_SLOT_15 = "Back", GEAR_SLOT_16 = "Main hand", GEAR_SLOT_17 = "Off hand", GEAR_SLOT_18 = "Ranged", GEAR_SLOT_19 = "Tabard",
})
FW:AddLocale("deDE", {
    GEAR_ON = "Automatisch wechseln", GEAR_MSG = "Meldung im Chat beim Wechsel",
    GEAR_DEFAULT = "Standard-Ausrüstung", GEAR_PROFILES = "Profile", GEAR_RULES = "Regeln (die obere gewinnt)",
    GEAR_SAVE = "Aktuelle Ausrüstung speichern", GEAR_NAME_HINT = "Name", GEAR_WEAR = "Anziehen", GEAR_EDIT = "Ändern",
    GEAR_OVERWRITE = "Mit aktueller Ausrüstung überschreiben", GEAR_RENAME = "Umbenennen", GEAR_SURE = "Sicher?",
    GEAR_NEW_RULE = "Neue Regel", GEAR_EDIT_RULE = "Regel bearbeiten", GEAR_EVENT = "Ereignis", GEAR_TARGET = "Anziehen",
    GEAR_ADD = "Regel hinzufügen", GEAR_SAVE_RULE = "Speichern", GEAR_CANCEL = "Abbrechen", GEAR_HERE = "Aktueller Ort",
    GEAR_ZONE_HINT = "Name der Zone oder des Gebiets", GEAR_DROP = "Gegenstand hier ablegen (oder damit klicken)", GEAR_SLOT = "Platz",
    GEAR_NO_FORMS = "Dieser Charakter hat keine Gestalten oder Haltungen.", GEAR_NONE_PROFILES = "Noch keine Profile: Zieh an, was du willst, und klick auf „Aktuelle Ausrüstung speichern“.",
    GEAR_NONE_RULES = "Noch keine Regeln.", GEAR_STATUS_IDLE = "Jetzt: Standard-Ausrüstung", GEAR_STATUS = "Jetzt aktiv: %s",
    GEAR_ON_SHORT = "An", GEAR_OFF_SHORT = "Aus", GEAR_EMPTY = "(leer)", GEAR_STATS = "Werte",
    GEAR_INFO = "Ordne einem Ereignis ein Profil, ein Blizzard-Ausrüstungsset oder einen einzelnen Gegenstand zu. Endet das Ereignis, endet die Regel, und es gilt die nächste aktive Regel, sonst die Standard-Ausrüstung. Sind mehrere Regeln aktiv, gewinnt die obere bei jedem Platz, den sie enthält. Im Kampf wechseln nur Waffen, Schild/Nebenhand und Fernkampf; der Rest folgt nach dem Kampf. Ein Profil kann nur einzelne Plätze enthalten: „Ändern“ klicken und die überflüssigen Plätze entfernen. Angeln hat kein Spielereignis: dafür die Taste (Tastaturbelegung > Freewood, einmal kompletter Spielneustart nötig) oder /fwgear angeln.",
    GEAR_SLOT_1 = "Kopf", GEAR_SLOT_2 = "Hals", GEAR_SLOT_3 = "Schulter", GEAR_SLOT_4 = "Hemd", GEAR_SLOT_5 = "Brust",
    GEAR_SLOT_6 = "Taille", GEAR_SLOT_7 = "Beine", GEAR_SLOT_8 = "Füße", GEAR_SLOT_9 = "Handgelenke", GEAR_SLOT_10 = "Hände",
    GEAR_SLOT_11 = "Finger 1", GEAR_SLOT_12 = "Finger 2", GEAR_SLOT_13 = "Schmuck 1", GEAR_SLOT_14 = "Schmuck 2",
    GEAR_SLOT_15 = "Rücken", GEAR_SLOT_16 = "Waffenhand", GEAR_SLOT_17 = "Nebenhand", GEAR_SLOT_18 = "Fernkampf", GEAR_SLOT_19 = "Wappenrock",
})

local function L() return FW.L end
local ROW = 26

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function ItemIcon(id)
    if not id then return nil end
    if G.C_Item and G.C_Item.GetItemIconByID then return Call(G.C_Item.GetItemIconByID, id) end
    return Call(G.GetItemIcon, id)
end

local function Tip(owner, link, id)
    local T = G.GameTooltip
    if not T then return end
    T:SetOwner(owner, "ANCHOR_RIGHT")
    if link then pcall(T.SetHyperlink, T, link) elseif id and T.SetItemByID then pcall(T.SetItemByID, T, id) end
    T:Show()
end
local function HideTip() if G.GameTooltip then G.GameTooltip:Hide() end end

------------------------------------------------------------------------
-- Bausteine: Freewood-Kit (Reiter) oder Blizzard-Stil (Charakteransicht, 0.65.0)
-- Beide Sätze haben dieselben Funktionen, der Aufbau unten kennt nur W.*
------------------------------------------------------------------------

local KIT = { inset = 16 }
function KIT.Label(parent, text, opts) return UI.CreateLabel(parent, text, opts) end
function KIT.Check(parent, label, get, set) return UI.CreateCheckbox(parent, label, get, set) end
function KIT.Dropdown(parent, w, h, opts) return UI.CreateDropdown(parent, w, h, opts) end
function KIT.Button(parent, text, w, fn) return UI.CreateButton(parent, text, w, 22, fn) end
function KIT.Scroll(parent) return UI.CreateScrollFrame(parent) end
function KIT.Dim(fs) fs:SetTextColor(UI.Color("textDim")) end
function KIT.Edit(parent)
    local box = UI.CreatePanel(parent, "card", "bronze")
    box:SetHeight(22)
    local e = CreateFrame("EditBox", nil, box)
    e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -2)
    e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 2)
    UI.SetFont(e, "body", 12)
    e:SetTextColor(UI.Color("text"))
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box.edit = e
    function box:GetText() return e:GetText() or "" end
    function box:SetText(t) e:SetText(t or "") end
    return box
end

local BLZ = { inset = 30 }
-- Schriftobjekte wie in Blizzards Fenstern: Überschrift gold, Beschriftung gold klein, Text weiß, Hinweis grau
local function FontObject(opts)
    opts = opts or {}
    if opts.font == "heading" then return (opts.size or 13) >= 15 and "GameFontNormalLarge" or "GameFontNormal" end
    if opts.color == "gold" or opts.color == "goldLight" then return "GameFontNormalSmall" end
    if opts.color == "textDim" then return "GameFontDisableSmall" end
    return (opts.size or 12) >= 12 and "GameFontHighlight" or "GameFontHighlightSmall"
end
function BLZ.Label(parent, text, opts)
    local fs = parent:CreateFontString(nil, "OVERLAY", FontObject(opts))
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end
function BLZ.Dim(fs) fs:SetTextColor(0.6, 0.6, 0.6) end
function BLZ.Check(parent, label, get, set)
    local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if not ok or not cb then return KIT.Check(parent, label, get, set) end
    cb:SetSize(24, 24)
    cb.fwLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.fwLabel:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb.fwLabel:SetText(label or "")
    for _, k in ipairs({ "Text", "text" }) do if type(cb[k]) == "table" and cb[k].SetText then cb[k]:SetText("") end end
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function cb:Refresh() self:SetChecked(get() and true or false) end
    cb:Refresh()
    return cb
end
function BLZ.Button(parent, text, w, fn)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then return KIT.Button(parent, text, w, fn) end
    b:SetSize(w or 120, 22)
    b:SetText(text or "")
    b:SetScript("OnClick", function(self, ...) if fn then fn(self, ...) end end)
    function b:SetLabel(t) self:SetText(t or "") end
    function b:SetStyle(name) if name == "primary" then self:LockHighlight() else self:UnlockHighlight() end end
    return b
end
function BLZ.Edit(parent)
    local ok, e = pcall(CreateFrame, "EditBox", nil, parent, "InputBoxTemplate")
    if not ok or not e then return KIT.Edit(parent) end
    e:SetAutoFocus(false)
    e:SetHeight(20)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local set, get = e.SetText, e.GetText
    function e:SetText(t) set(self, t or "") end
    function e:GetText() return get(self) or "" end
    return e
end
-- Blizzard-Dropdown (WowStyle1, Menü-System); fehlt es, das Kit-Dropdown
function BLZ.Dropdown(parent, w, h, opts)
    local ok, dd = false, nil
    if G.MenuUtil then ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate") end
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(w or 200)
        local okSetup = pcall(dd.SetupMenu, dd, function(_, menu)
            for _, o in ipairs(opts.getOptions() or {}) do
                menu:CreateRadio(o.text, function() return dd.fwValue == o.value end, function()
                    dd.fwValue = o.value
                    if opts.onChange then opts.onChange(o.value) end
                end)
            end
        end)
        if okSetup then
            dd.opts = opts
            function dd:SetValue(v)
                self.fwValue = v
                if v == nil and self.SetDefaultText then pcall(self.SetDefaultText, self, "") end
                if self.GenerateMenu then pcall(self.GenerateMenu, self) end
            end
            return dd
        end
        dd:Hide()
    end
    return KIT.Dropdown(parent, w, h, opts)
end
function BLZ.Scroll(parent)
    local holder = CreateFrame("Frame", nil, parent)
    local ok, sf = pcall(CreateFrame, "ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    if not ok or not sf then sf = CreateFrame("ScrollFrame", nil, holder) end
    sf:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    holder.scroll, holder.child = sf, child
    function holder:SetContentHeight(hh) child:SetHeight(math.max(1, hh)) end
    return holder
end

GU.STYLES = { freewood = KIT, blizzard = BLZ }

local function ArrowButton(parent, up, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:SetNormalTexture(up and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", fn)
    return b
end

-- Knopf mit zweitem Klick zur Bestätigung (Löschen)
local function DeleteButton(W, parent, fn)
    local b
    b = W.Button(parent, "X", 26, function()
        if b.armed then b.armed = nil b:SetLabel("X") b:SetWidth(26) fn() return end
        b.armed = true
        b:SetLabel(L().GEAR_SURE)
        b:SetWidth(60)
        if G.C_Timer then G.C_Timer.After(3, function() if b.armed then b.armed = nil b:SetLabel("X") b:SetWidth(26) end end) end
    end)
    return b
end

local function SlotName(slot) return L()["GEAR_SLOT_" .. tostring(slot)] or tostring(slot) end

local function TargetOptions(withLast, withItem)
    local Lx, list = L(), {}
    if withLast then list[#list + 1] = { value = "last", text = Lx.GEAR_DEFAULT_LAST } end
    for _, p in ipairs(GS.DB().profiles) do list[#list + 1] = { value = "p:" .. p.id, text = Lx.GEAR_PROFILE .. ": " .. p.name } end
    for _, n in ipairs(GS.SetNames()) do list[#list + 1] = { value = "s:" .. n, text = Lx.GEAR_SET .. ": " .. n } end
    if withItem then list[#list + 1] = { value = "i", text = Lx.GEAR_ITEM } end
    return list
end

local function TargetText(v)
    for _, o in ipairs(TargetOptions(true, true)) do if o.value == v then return o.text end end
    return GS.TargetName(v)
end

function GU.RuleText(r)
    local Lx = L()
    local ev = Lx["GEAR_EV_" .. tostring(r.ev)] or tostring(r.ev)
    if r.ev == "zone" and r.arg then ev = ev .. " „" .. tostring(r.arg) .. "“" end
    if r.ev == "form" and r.arg then
        for _, f in ipairs(GS.Forms()) do if f.value == r.arg then ev = ev .. " „" .. f.text .. "“" end end
    end
    return ev .. " -> " .. GS.TargetName(r.target, r.item)
end

------------------------------------------------------------------------
-- Aufbau
------------------------------------------------------------------------

-- style: "freewood" (Standard, Reiter) oder "blizzard" (Charakteransicht)
function GU.Build(parent, style)
    local Lx = L()
    local W = GU.STYLES[style or "freewood"] or KIT
    local root = CreateFrame("Frame", nil, parent)
    root.W = W
    root:SetAllPoints(parent)
    local scroll = W.Scroll(root)
    scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    local c = scroll.child
    local state = { open = {}, form = {} }
    root.state = state

    c.title = W.Label(c, Lx.GEAR_TITLE, { font = "heading", size = 15, color = "goldLight" })
    c.info = UI.CreateInfoIcon and UI.CreateInfoIcon(c, Lx.GEAR_TITLE, Lx.GEAR_INFO) or CreateFrame("Frame", nil, c)
    c.on = W.Check(c, Lx.GEAR_ON, function() return GS.DB().on end, function(v)
        GS.DB().on = v and true or false
        GS.lastSig = nil
        if v then GS.Soon(true) end
        GU.RefreshAll()
    end)
    c.msg = W.Check(c, Lx.GEAR_MSG, function() return GS.DB().msg end, function(v) GS.DB().msg = v and true or false end)
    c.status = W.Label(c, "", { size = 12 })
    c.status:SetWordWrap(true)

    c.defLabel = W.Label(c, Lx.GEAR_DEFAULT, { size = 12, color = "gold" })
    c.defDD = W.Dropdown(c, 200, 22, {
        getOptions = function() return TargetOptions(true, false) end,
        textOf = TargetText,
        onChange = function(v) GS.DB().default = v GS.Soon(GS.lastSig == "") GU.RefreshAll() end,
    })

    -- Profile
    c.profHead = W.Label(c, Lx.GEAR_PROFILES, { font = "heading", size = 13, color = "goldLight" })
    c.profNone = W.Label(c, Lx.GEAR_NONE_PROFILES, { size = 11, color = "textDim" })
    c.profNone:SetWordWrap(true)
    c.newName = W.Edit(c)
    c.saveBtn = W.Button(c, Lx.GEAR_SAVE, 200, function()
        GS.SaveCurrent(c.newName:GetText())
        c.newName:SetText("")
        GU.RefreshAll()
    end)
    root.profRows, root.slotRows = {}, {}

    -- Regeln
    c.ruleHead = W.Label(c, Lx.GEAR_RULES, { font = "heading", size = 13, color = "goldLight" })
    c.ruleNone = W.Label(c, Lx.GEAR_NONE_RULES, { size = 11, color = "textDim" })
    root.ruleRows = {}

    -- Formular
    local form = state.form
    c.formHead = W.Label(c, Lx.GEAR_NEW_RULE, { font = "heading", size = 13, color = "goldLight" })
    c.evLabel = W.Label(c, Lx.GEAR_EVENT, { size = 12, color = "gold" })
    c.evDD = W.Dropdown(c, 200, 22, {
        getOptions = function()
            local list = {}
            for _, ev in ipairs(GS.EVENTS) do list[#list + 1] = { value = ev, text = L()["GEAR_EV_" .. ev] or ev } end
            return list
        end,
        textOf = function(v) return L()["GEAR_EV_" .. tostring(v)] or tostring(v) end,
        onChange = function(v) form.ev = v form.arg = nil root.Refresh() end,
    })
    c.zone = W.Edit(c)
    c.zoneHint = W.Label(c, Lx.GEAR_ZONE_HINT, { size = 11, color = "textDim" })
    c.zoneBtn = W.Button(c, Lx.GEAR_HERE, 110, function()
        local z = Call(G.GetRealZoneText) or Call(G.GetZoneText) or ""
        c.zone:SetText(z)
    end)
    c.formDD = W.Dropdown(c, 200, 22, {
        getOptions = GS.Forms,
        textOf = function(v) for _, f in ipairs(GS.Forms()) do if f.value == v then return f.text end end return tostring(v or "") end,
        onChange = function(v) form.arg = v end,
    })
    c.noForms = W.Label(c, Lx.GEAR_NO_FORMS, { size = 11, color = "textDim" })
    c.tgtLabel = W.Label(c, Lx.GEAR_TARGET, { size = 12, color = "gold" })
    c.tgtDD = W.Dropdown(c, 200, 22, {
        getOptions = function() return TargetOptions(false, true) end,
        textOf = TargetText,
        onChange = function(v) form.target = v root.Refresh() end,
    })
    c.drop = CreateFrame("Button", nil, c)
    c.drop:SetSize(36, 36)
    c.drop.bg = c.drop:CreateTexture(nil, "BACKGROUND")
    c.drop.bg:SetAllPoints()
    c.drop.bg:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
    c.drop.icon = c.drop:CreateTexture(nil, "ARTWORK")
    c.drop.icon:SetAllPoints()
    c.drop:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    c.dropText = W.Label(c, Lx.GEAR_DROP, { size = 11 })
    c.dropText:SetWordWrap(true)
    local function TakeCursor()
        local kind, id, link = Call(G.GetCursorInfo)
        if kind ~= "item" or not id then return end
        local slots = GS.SlotsFor(id)
        form.item = { id = id, link = link, slot = slots[1] }
        Call(G.ClearCursor)
        root.Refresh()
    end
    c.drop:RegisterForClicks("LeftButtonUp")
    c.drop:SetScript("OnReceiveDrag", TakeCursor)
    c.drop:SetScript("OnClick", TakeCursor)
    c.drop:SetScript("OnEnter", function(self) if form.item then Tip(self, form.item.link, form.item.id) end end)
    c.drop:SetScript("OnLeave", HideTip)
    c.slotDD = W.Dropdown(c, 140, 22, {
        getOptions = function()
            local list = {}
            local slots = form.item and GS.SlotsFor(form.item.id) or {}
            for _, s in ipairs(slots) do list[#list + 1] = { value = s, text = SlotName(s) } end
            return list
        end,
        textOf = SlotName,
        onChange = function(v) if form.item then form.item.slot = v end end,
    })
    c.addBtn = W.Button(c, Lx.GEAR_ADD, 150, function()
        if not form.ev or not form.target then return end
        local arg = form.arg
        if form.ev == "zone" then arg = c.zone:GetText() if arg == "" then return end end
        if form.ev == "form" and not arg then return end
        local item = nil
        if form.target == "i" then
            if not (form.item and form.item.slot) then return end
            item = { id = form.item.id, link = form.item.link, slot = form.item.slot }
        end
        if form.editing then
            local r = form.editing
            r.ev, r.arg, r.target, r.item = form.ev, arg, form.target, item
            GS.Soon(true)
        else
            GS.AddRule(form.ev, arg, form.target, item)
        end
        GU.ResetForm(root)
        GU.RefreshAll()
    end)
    c.cancelBtn = W.Button(c, Lx.GEAR_CANCEL, 100, function() GU.ResetForm(root) root.Refresh() end)

    root.c, root.scroll = c, scroll
    root.Refresh = function() GU.Refresh(root) end
    root:SetScript("OnShow", root.Refresh)
    root:SetScript("OnSizeChanged", function(_, w)
        if type(w) == "number" and math.abs(w - (root.lastW or 0)) > 0.5 then root.lastW = w root.Refresh() end
    end)
    GU.views[#GU.views + 1] = root
    return root
end

function GU.ResetForm(root)
    local f = root.state.form
    f.ev, f.arg, f.target, f.item, f.editing = nil, nil, nil, nil, nil
    root.c.zone:SetText("")
end

function GU.LoadRule(root, r)
    local f = root.state.form
    f.editing = r
    f.ev, f.arg, f.target = r.ev, r.arg, r.target
    f.item = r.item and { id = r.item.id, link = r.item.link, slot = r.item.slot } or nil
    root.c.zone:SetText(r.ev == "zone" and r.arg or "")
    root.Refresh()
end

function GU.RefreshAll()
    for _, v in ipairs(GU.views) do if v:IsShown() then pcall(v.Refresh) end end
end

------------------------------------------------------------------------
-- Zeilen
------------------------------------------------------------------------

local function ProfileRow(root, i)
    local row = root.profRows[i]
    if row then return row end
    local c = root.c
    row = CreateFrame("Frame", nil, c)
    row:SetHeight(ROW)
    row.name = root.W.Label(row, "", { size = 12 })
    row.name:SetWordWrap(false)
    row.del = DeleteButton(root.W, row, function() GS.DeleteProfile(row.p.id) GU.RefreshAll() end)
    row.edit = root.W.Button(row, L().GEAR_EDIT, 64, function()
        root.state.open[row.p.id] = not root.state.open[row.p.id]
        root.Refresh()
    end)
    row.wear = root.W.Button(row, L().GEAR_WEAR, 76, function() GS.Wear("p:" .. row.p.id) end)
    row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.edit:SetPoint("RIGHT", row.del, "LEFT", -4, 0)
    row.wear:SetPoint("RIGHT", row.edit, "LEFT", -4, 0)
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetPoint("RIGHT", row.wear, "LEFT", -6, 0)
    -- aufgeklappt
    row.rename = root.W.Edit(c)
    row.renameBtn = root.W.Button(c, L().GEAR_RENAME, 100, function()
        local t = row.rename:GetText()
        if t ~= "" then row.p.name = t GU.RefreshAll() end
    end)
    row.over = root.W.Button(c, L().GEAR_OVERWRITE, 200, function() GS.Overwrite(row.p) root.Refresh() end)
    root.profRows[i] = row
    return row
end

local function SlotRow(root, i)
    local row = root.slotRows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, root.c)
    row:SetHeight(22)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.text = root.W.Label(row, "", { size = 11 })
    row.text:SetWordWrap(false)
    row.del = root.W.Button(row, "X", 24, function()
        if row.p and row.slot then row.p.slots[row.slot] = nil GS.Soon(true) root.Refresh() end
    end)
    row.del:SetHeight(18)
    row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.del, "LEFT", -4, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) if self.it then Tip(self, self.it.link, self.it.id) end end)
    row:SetScript("OnLeave", HideTip)
    root.slotRows[i] = row
    return row
end

local function RuleRow(root, i)
    local row = root.ruleRows[i]
    if row then return row end
    row = CreateFrame("Button", nil, root.c)
    row:SetHeight(ROW)
    row.toggle = root.W.Button(row, "", 40, function()
        row.r.on = row.r.on == false
        GS.Soon(true)
        GU.RefreshAll()
    end)
    row.toggle:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.del = DeleteButton(root.W, row, function() GS.DeleteRule(row.r) GU.RefreshAll() end)
    row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.down = ArrowButton(row, false, function() GS.MoveRule(row.r, 1) GU.RefreshAll() end)
    row.down:SetPoint("RIGHT", row.del, "LEFT", -4, 0)
    row.up = ArrowButton(row, true, function() GS.MoveRule(row.r, -1) GU.RefreshAll() end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    row.text = root.W.Label(row, "", { size = 12 })
    row.text:SetWordWrap(false)
    row.text:SetPoint("LEFT", row.toggle, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.up, "LEFT", -4, 0)
    row:SetScript("OnClick", function() GU.LoadRule(root, row.r) end)
    root.ruleRows[i] = row
    return row
end

------------------------------------------------------------------------
-- Anordnen
------------------------------------------------------------------------

function GU.Refresh(root)
    local c, Lx, d = root.c, L(), GS.DB()
    local W = (root:GetWidth() or 0) - (root.W.inset or 16)
    if W <= 40 then return end
    c:SetWidth(W)
    local y = 4
    local function Put(w, x, h, width)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", c, "TOPLEFT", x or 0, -y)
        if width then w:SetWidth(width) end
        if h then w:SetHeight(h) end
        w:Show()
    end
    local function Text(fs, x, width, minH)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", x or 0, -y)
        fs:SetWidth(width)
        fs:Show()
        local h = (UI.TextHeight and UI.TextHeight(fs, minH or 14)) or (minH or 14)
        y = y + h
    end

    Put(c.title, 0) y = y + 2
    c.info:ClearAllPoints()
    c.info:SetPoint("LEFT", c.title, "RIGHT", 6, 0)
    y = y + 20
    Put(c.on, 0) c.on:Refresh() y = y + 24
    Put(c.msg, 0) c.msg:Refresh() y = y + 26
    local act = GS.active and GS.active[1]
    c.status:SetText(act and string.format(Lx.GEAR_STATUS, GU.RuleText(act)) or Lx.GEAR_STATUS_IDLE)
    if act then c.status:SetTextColor(0.4, 1, 0.4) else root.W.Dim(c.status) end
    Text(c.status, 0, W, 14) y = y + 10

    Put(c.defLabel, 0) y = y + 16
    Put(c.defDD, 0, 22, math.min(W, 280)) c.defDD:SetValue(d.default) y = y + 32

    -- Profile
    Put(c.profHead, 0) y = y + 20
    local slotN = 0
    if #d.profiles == 0 then Text(c.profNone, 0, W, 14) y = y + 4 else c.profNone:Hide() end
    for i, p in ipairs(d.profiles) do
        local row = ProfileRow(root, i)
        row.p = p
        local n = 0
        for _ in pairs(p.slots or {}) do n = n + 1 end
        row.name:SetText(p.name .. "  |cff999999(" .. n .. ")|r")
        row.edit:SetStyle(root.state.open[p.id] and "primary" or "default")
        Put(row, 0, ROW, W) y = y + ROW + 2
        if root.state.open[p.id] then
            for _, slot in ipairs(GS.ORDER) do
                local it = p.slots[slot]
                if it then
                    slotN = slotN + 1
                    local sr = SlotRow(root, slotN)
                    sr.p, sr.slot, sr.it = p, slot, it
                    sr.icon:SetTexture(ItemIcon(it.id))
                    sr.text:SetText(SlotName(slot) .. ": " .. (it.link or ("#" .. it.id)))
                    Put(sr, 16, 22, W - 16) y = y + 22
                end
            end
            y = y + 4
            row.rename:SetText(p.name)
            Put(row.rename, 16, 22, math.max(80, math.min(W - 16 - 106, 220)))
            row.renameBtn:ClearAllPoints()
            row.renameBtn:SetPoint("LEFT", row.rename, "RIGHT", 6, 0)
            row.renameBtn:Show()
            y = y + 28
            Put(row.over, 16, 22, math.min(W - 16, 280)) y = y + 30
        else
            row.rename:Hide() row.renameBtn:Hide() row.over:Hide()
        end
    end
    for i = #d.profiles + 1, #root.profRows do
        local row = root.profRows[i]
        row:Hide() row.rename:Hide() row.renameBtn:Hide() row.over:Hide()
    end
    for i = slotN + 1, #root.slotRows do root.slotRows[i]:Hide() end
    Put(c.newName, 0, 22, math.max(80, math.min(W - 206, 200)))
    c.saveBtn:ClearAllPoints()
    if W >= 300 then
        c.saveBtn:SetPoint("LEFT", c.newName, "RIGHT", 6, 0)
        y = y + 34
    else
        c.newName:SetWidth(W)
        y = y + 28
        Put(c.saveBtn, 0) y = y + 30
    end
    c.saveBtn:Show()

    -- Regeln
    y = y + 6
    Put(c.ruleHead, 0) y = y + 20
    if #d.rules == 0 then Text(c.ruleNone, 0, W, 14) y = y + 4 else c.ruleNone:Hide() end
    for i, r in ipairs(d.rules) do
        local row = RuleRow(root, i)
        row.r = r
        row.toggle:SetLabel(r.on == false and Lx.GEAR_OFF_SHORT or Lx.GEAR_ON_SHORT)
        row.toggle:SetStyle(r.on == false and "default" or "primary")
        local t = i .. ". " .. GU.RuleText(r)
        if GS.IsActive(r) then t = "|cff66ff66" .. t .. "|r" elseif r.on == false then t = "|cff888888" .. t .. "|r" end
        row.text:SetText(t)
        Put(row, 0, ROW, W) y = y + ROW + 2
    end
    for i = #d.rules + 1, #root.ruleRows do root.ruleRows[i]:Hide() end

    -- Formular
    local form = root.state.form
    y = y + 10
    c.formHead:SetText(form.editing and Lx.GEAR_EDIT_RULE or Lx.GEAR_NEW_RULE)
    Put(c.formHead, 0) y = y + 20
    local ddW = math.min(W, 280)
    Put(c.evLabel, 0) y = y + 16
    Put(c.evDD, 0, 22, ddW) c.evDD:SetValue(form.ev) y = y + 28
    c.zone:Hide() c.zoneHint:Hide() c.zoneBtn:Hide() c.formDD:Hide() c.noForms:Hide()
    if form.ev == "zone" then
        Put(c.zone, 0, 22, math.max(80, math.min(W - 116, 220)))
        c.zoneBtn:ClearAllPoints()
        c.zoneBtn:SetPoint("LEFT", c.zone, "RIGHT", 6, 0)
        c.zoneBtn:Show()
        y = y + 24
        Text(c.zoneHint, 0, W, 12) y = y + 6
    elseif form.ev == "form" then
        if #GS.Forms() == 0 then Text(c.noForms, 0, W, 14) y = y + 6
        else Put(c.formDD, 0, 22, ddW) c.formDD:SetValue(form.arg) y = y + 28 end
    end
    Put(c.tgtLabel, 0) y = y + 16
    Put(c.tgtDD, 0, 22, ddW) c.tgtDD:SetValue(form.target) y = y + 28
    c.drop:Hide() c.dropText:Hide() c.slotDD:Hide()
    if form.target == "i" then
        Put(c.drop, 0)
        c.drop.icon:SetTexture(form.item and ItemIcon(form.item.id) or nil)
        c.dropText:ClearAllPoints()
        c.dropText:SetPoint("TOPLEFT", c, "TOPLEFT", 44, -y)
        c.dropText:SetWidth(W - 44)
        c.dropText:SetText(form.item and (form.item.link or ("#" .. form.item.id)) or Lx.GEAR_DROP)
        c.dropText:Show()
        y = y + 40
        if form.item then
            Put(c.slotDD, 0, 22, math.min(W, 180)) c.slotDD:SetValue(form.item.slot) y = y + 28
        end
    end
    y = y + 4
    Put(c.addBtn, 0) c.addBtn:SetLabel(form.editing and Lx.GEAR_SAVE_RULE or Lx.GEAR_ADD)
    if form.editing then
        c.cancelBtn:ClearAllPoints()
        c.cancelBtn:SetPoint("LEFT", c.addBtn, "RIGHT", 6, 0)
        c.cancelBtn:Show()
    else
        c.cancelBtn:Hide()
    end
    y = y + 34
    c:SetHeight(y)
    if root.scroll.SetContentHeight then root.scroll:SetContentHeight(y) end
end

FW:On("GEAR_STATE", function() GU.RefreshAll() end)
FW:On("GEAR_CHANGED", function() GU.RefreshAll() end)

if UI.RegisterTab then
    UI:RegisterTab("gear", {
        label = function() return FW.L.TAB_GEAR end,
        order = 875,
        build = function(content) return GU.Build(content) end,
        onShow = function(f) if f and f.Refresh then f.Refresh() end end,
    })
end
