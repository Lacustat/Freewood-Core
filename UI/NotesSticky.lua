-- Freewood-Core: angeheftete Zettel (Sticky Notes). Eine Notiz oder die ToDo-Liste als kleiner Zettel auf dem Bildschirm.
-- Mehrere Zettel gleichzeitig. Jeder Zettel: verschiebbar, Groesse aenderbar, Schloss (Lage sperren), Zahnrad (gestalten:
-- Vorlagen, freie Hintergrund- und Schriftfarbe, Deckkraft, Schriftgroesse), Notiz-Symbol (im Notizblock oeffnen),
-- x (loesen, die Notiz bleibt). Verknuepfungen sind anklickbar (Codex). Der ToDo-Zettel zeigt die offenen Eintraege
-- zum Abhaken. Lage und Aussehen je Charakter gespeichert. Einstellung "Im Kampf ausblenden" (Standard: immer sichtbar).
-- Im Spiel ungeprueft.

local ADDON, NS = ...
local G = _G
local FW = G.Freewood
if not FW or not FW.UI or not FW.Notes then return end

local UI = FW.UI
local N = FW.Notes
local S = { frames = {} }
N.Sticky = S

local MIN_W, MIN_H = 140, 80
local MAX_W, MAX_H = 700, 700
local HEAD_H = 20
local inCombat = false

-- Vorlagen: Hintergrund r, g, b und Schrift r, g, b
S.PRESETS = {
    { 1.00, 0.92, 0.55, 0.16, 0.12, 0.04 },   -- Gelb
    { 0.74, 0.93, 0.62, 0.07, 0.18, 0.05 },   -- Gruen
    { 0.64, 0.82, 1.00, 0.04, 0.11, 0.24 },   -- Blau
    { 1.00, 0.72, 0.84, 0.26, 0.05, 0.12 },   -- Rosa
    { 1.00, 0.78, 0.52, 0.26, 0.12, 0.02 },   -- Orange
    { 0.95, 0.95, 0.93, 0.10, 0.10, 0.10 },   -- Weiss
    { 0.13, 0.12, 0.11, 0.93, 0.88, 0.76 },   -- Dunkel
}

local function L() return FW.L end

local function Hidden()
    return inCombat and N.HideInCombat()
end

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
local function TipHide() if G.GameTooltip then G.GameTooltip:Hide() end end
local function EnableLinks(frame)
    if frame.SetHyperlinksEnabled then pcall(frame.SetHyperlinksEnabled, frame, true) end
    frame:SetScript("OnHyperlinkClick", function(_, link, text, button) N.OpenLink(link, text, button) end)
    frame:SetScript("OnHyperlinkEnter", function(self, link, text) LinkEnter(self, link, text) end)
    frame:SetScript("OnHyperlinkLeave", TipHide)
end

local function Tip(owner, text)
    if not G.GameTooltip then return end
    G.GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    G.GameTooltip:SetText(text, 1, 1, 1)
    G.GameTooltip:Show()
end

-- kleiner Knopf in der Kopfzeile: Symbol (icon) oder Text
local function HeadBtn(parent, icon, text, tipFn, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b.isText = not icon
    if icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints(b)
        b.icon:SetTexture(icon)
        if icon:find("Icons") then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    else
        b.label = b:CreateFontString(nil, "OVERLAY")
        UI.SetFont(b.label, "body", 13)
        b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
        b.label:SetText(text)
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetColorTexture(1, 1, 1, 0.25)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) Tip(self, tipFn()) end)
    b:SetScript("OnLeave", TipHide)
    return b
end

------------------------------------------------------------------------
-- Gestalten (ein gemeinsames Fenster, haengt am gerade gewaehlten Zettel)
------------------------------------------------------------------------

local style
local ApplyLook

local function OpenColor(pin, which, f)
    local picker = G.ColorPickerFrame
    if not picker then return end
    local kr, kg, kb = "r", "g", "b"
    if which == "text" then kr, kg, kb = "tr", "tg", "tb" end
    local r, g, b = pin[kr], pin[kg], pin[kb]
    local function Changed()
        local nr, ng, nb = picker:GetColorRGB()
        pin[kr], pin[kg], pin[kb] = nr, ng, nb
        ApplyLook(f)
    end
    local function Cancel()
        pin[kr], pin[kg], pin[kb] = r, g, b
        ApplyLook(f)
    end
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = Changed, cancelFunc = Cancel })
    else
        picker.hasOpacity = false
        picker.func = Changed
        picker.cancelFunc = Cancel
        picker:SetColorRGB(r, g, b)
        picker:Show()
    end
end

local function BuildStyle()
    local p = UI.CreatePanel(G.UIParent, "panel", "gold")
    p:SetSize(250, 250)
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:Hide()
    local title = UI.CreateLabel(p, L().STICKY_STYLE, { size = 13, color = "goldLight" })
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    local close = UI.CreateButton(p, "X", 20, 20, function() p:Hide() end, "default")
    close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)

    p.swatches = {}
    local pre = UI.CreateLabel(p, L().STICKY_PRESETS, { size = 11, color = "textDim" })
    pre:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -38)
    for i, c in ipairs(S.PRESETS) do
        local sw = CreateFrame("Button", nil, p)
        sw:SetSize(26, 20)
        sw:SetPoint("TOPLEFT", p, "TOPLEFT", 10 + (i - 1) * 32, -54)
        local border = UI.CreatePanel(sw, "bgDeep", "bronze")
        border:SetAllPoints(sw)
        local t = sw:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", sw, "TOPLEFT", 2, -2)
        t:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -2, 2)
        t:SetColorTexture(c[1], c[2], c[3], 1)
        local a = sw:CreateFontString(nil, "OVERLAY")
        UI.SetFont(a, "body", 11)
        a:SetPoint("CENTER", sw, "CENTER", 0, 0)
        a:SetText("Aa")
        a:SetTextColor(c[4], c[5], c[6])
        p.swatches[i] = sw
        sw:SetScript("OnClick", function()
            local pin = p.pin
            if not pin then return end
            pin.r, pin.g, pin.b, pin.tr, pin.tg, pin.tb = c[1], c[2], c[3], c[4], c[5], c[6]
            ApplyLook(p.target)
        end)
    end

    local bgBtn = UI.CreateButton(p, L().STICKY_BG, 112, 22, function()
        if p.pin then OpenColor(p.pin, "bg", p.target) end
    end, "default")
    bgBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -84)
    local fgBtn = UI.CreateButton(p, L().STICKY_FG, 112, 22, function()
        if p.pin then OpenColor(p.pin, "text", p.target) end
    end, "default")
    fgBtn:SetPoint("LEFT", bgBtn, "RIGHT", 6, 0)
    p.bgBtn, p.fgBtn = bgBtn, fgBtn

    local alphaLbl = UI.CreateLabel(p, "", { size = 11 })
    alphaLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -116)
    local alpha = UI.CreateSlider(p, 228, { min = 10, max = 100, step = 5,
        get = function() return p.pin and math.floor(p.pin.a * 100 + 0.5) or 95 end,
        set = function(v) if p.pin then p.pin.a = v / 100 ApplyLook(p.target) end end })
    alpha.onText = function(v) alphaLbl:SetText(string.format(L().STICKY_ALPHA, v)) end
    alpha:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -132)

    local sizeLbl = UI.CreateLabel(p, "", { size = 11 })
    sizeLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -160)
    local size = UI.CreateSlider(p, 228, { min = 9, max = 20, step = 1,
        get = function() return p.pin and p.pin.size or 12 end,
        set = function(v) if p.pin then p.pin.size = v S.Update(p.target) end end })
    size.onText = function(v) sizeLbl:SetText(string.format(L().STICKY_SIZE, v)) end
    size:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -176)

    local combat = UI.CreateCheckbox(p, L().STICKY_COMBAT, function() return N.HideInCombat() end,
        function(v) N.SetHideInCombat(v) end)
    combat:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -204)
    p.alpha, p.size, p.combat = alpha, size, combat
    if combat.Fit then combat:Fit(230) end

    function p:Open(f)
        self.target, self.pin = f, f.pin
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
        alpha:Refresh()
        size:Refresh()
        combat:Refresh()
        self:Show()
    end
    return p
end

local function OpenStyle(f)
    style = style or BuildStyle()
    S.styleFrame = style
    if style:IsShown() and style.target == f then style:Hide() return end
    style:Open(f)
end
S.OpenStyle = OpenStyle

------------------------------------------------------------------------
-- Zettel
------------------------------------------------------------------------

local function SavePos(f)
    local pin = f.pin
    if not pin then return end
    local cx, cy = f:GetCenter()
    local ux, uy = G.UIParent:GetCenter()
    if cx and ux then
        pin.x, pin.y = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5)
    end
    pin.w, pin.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
end

ApplyLook = function(f)
    if not (f and f.pin) then return end
    local p = f.pin
    f.bg:SetColorTexture(p.r, p.g, p.b, p.a)
    f.head:SetColorTexture(p.r * 0.82, p.g * 0.82, p.b * 0.82, math.min(1, p.a + 0.05))
    f.edge:SetColorTexture(p.r * 0.6, p.g * 0.6, p.b * 0.6, math.min(1, p.a + 0.1))
    f.title:SetTextColor(p.tr, p.tg, p.tb)
    for _, b in ipairs(f.headBtns) do
        if b.isText then b.label:SetTextColor(p.tr, p.tg, p.tb) end
    end
    f.body:SetTextColor(p.tr, p.tg, p.tb)
    for _, r in ipairs(f.rows) do
        r.text:SetTextColor(p.tr, p.tg, p.tb)
        r.box:SetColorTexture(p.tr, p.tg, p.tb, 0.9)
        r.inner:SetColorTexture(p.r, p.g, p.b, 1)
    end
end
S.ApplyLook = ApplyLook

local function ApplyLock(f)
    local locked = f.pin and f.pin.locked
    f.grip:SetShown(not locked)
    f.lock.icon:SetDesaturated(not locked)
    f.lock.icon:SetAlpha(locked and 1 or 0.55)
end

local function OpenInNotepad(f)
    if N.Open then N.Open(f.id == "todo" and "todo" or "notes", f.id ~= "todo" and f.id or nil) end
end

local function Build(pinKey)
    local f = CreateFrame("Frame", nil, G.UIParent)
    f.pinKey = pinKey
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    if f.SetResizable then f:SetResizable(true) end
    if f.SetResizeBounds then pcall(f.SetResizeBounds, f, MIN_W, MIN_H, MAX_W, MAX_H)
    elseif f.SetMinResize then pcall(f.SetMinResize, f, MIN_W, MIN_H) end
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not (self.pin and self.pin.locked) then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePos(self) end)

    f.edge = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.edge:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    f.edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.bg:SetAllPoints(f)
    f.head = f:CreateTexture(nil, "BORDER")
    f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.head:SetHeight(HEAD_H)

    f.close = HeadBtn(f, nil, "x", function() return L().STICKY_CLOSE end, function()
        if N.Unpin(f.id) and N.Refresh then N.Refresh() end
    end)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -2)
    f.edit = HeadBtn(f, "Interface\\Icons\\INV_Misc_Note_01", nil, function() return L().STICKY_EDIT end,
        function() OpenInNotepad(f) end)
    f.edit:SetPoint("RIGHT", f.close, "LEFT", -3, 0)
    f.gear = HeadBtn(f, "Interface\\Buttons\\UI-OptionsButton", nil, function() return L().STICKY_STYLE end,
        function() OpenStyle(f) end)
    f.gear:SetPoint("RIGHT", f.edit, "LEFT", -3, 0)
    f.lock = HeadBtn(f, "Interface\\Icons\\INV_Misc_Key_03", nil, function()
        return (f.pin and f.pin.locked) and L().STICKY_UNLOCK or L().STICKY_LOCK
    end, function()
        if not f.pin then return end
        f.pin.locked = not f.pin.locked or nil
        ApplyLock(f)
    end)
    f.lock:SetPoint("RIGHT", f.gear, "LEFT", -3, 0)
    f.headBtns = { f.close, f.edit, f.gear, f.lock }

    f.title = f:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.title, "heading", 12)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4)
    f.title:SetPoint("RIGHT", f.lock, "LEFT", -4, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)

    f.scroll = UI.CreateScrollFrame(f, 100, 100)
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -(HEAD_H + 4))
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 10)
    EnableLinks(f.scroll.child)
    f.rows = {}
    f.body = f.scroll.child:CreateFontString(nil, "OVERLAY")
    f.body:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 3, -2)
    f.body:SetJustifyH("LEFT")
    f.body:SetJustifyV("TOP")
    f.body:SetWordWrap(true)

    f.grip = CreateFrame("Button", nil, f)
    f.grip:SetSize(14, 14)
    f.grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    f.grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() SavePos(f) S.Update(f) end)
    f:SetScript("OnSizeChanged", function(self) if self.ready then S.Content(self) end end)
    f:SetScript("OnHide", function(self) if style and style.target == self then style:Hide() end end)
    return f
end

-- Inhalt: Notiztext oder offene ToDo-Eintraege
local function TodoRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, f.scroll.child)
    EnableLinks(r)
    r.check = CreateFrame("Button", nil, r)
    r.check:SetSize(13, 13)
    r.check:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -2)
    r.box = r.check:CreateTexture(nil, "ARTWORK", nil, 1)
    r.box:SetAllPoints(r.check)
    r.inner = r.check:CreateTexture(nil, "ARTWORK", nil, 2)
    r.inner:SetPoint("TOPLEFT", r.check, "TOPLEFT", 2, -2)
    r.inner:SetPoint("BOTTOMRIGHT", r.check, "BOTTOMRIGHT", -2, 2)
    local hl = r.check:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(r.check)
    hl:SetColorTexture(1, 1, 1, 0.3)
    r.check:SetScript("OnClick", function()
        if r.entryId then
            N.TodoToggle(nil, r.entryId)
            if N.Refresh then N.Refresh() end
        end
    end)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetPoint("TOPLEFT", r.check, "TOPRIGHT", 6, 1)
    r.text:SetJustifyH("LEFT")
    r.text:SetJustifyV("TOP")
    r.text:SetWordWrap(true)
    f.rows[i] = r
    return r
end

function S.Content(f)
    local p = f.pin
    if not p then return end
    local width = math.max(60, (f.scroll.scroll and f.scroll.scroll:GetWidth() or f:GetWidth()) - 14)
    local key = N.CharKey()
    if f.id == "todo" then
        f.title:SetText(L().STICKY_TODO)
        f.body:Hide()
        local open = N.TodoOpen(key)
        local y = 0
        for i, e in ipairs(open) do
            local r = TodoRow(f, i)
            UI.SetFont(r.text, "body", p.size)
            r.entryId = e.id
            r.text:SetWidth(width - 22)
            r.text:SetText(e.text)
            local h = math.max(17, (r.text:GetStringHeight() or 12) + 4)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 2, -y)
            r:SetSize(width, h)
            r.check:Show()
            r:Show()
            y = y + h + 2
        end
        local n = #open
        if n == 0 then
            n = 1
            local r = TodoRow(f, 1)
            UI.SetFont(r.text, "body", p.size)
            r.entryId = nil
            r.check:Hide()
            r.text:SetWidth(width)
            r.text:SetText(L().STICKY_TODO_NONE)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f.scroll.child, "TOPLEFT", 2, 0)
            r:SetSize(width, 18)
            r:Show()
            y = 20
        end
        for i = n + 1, #f.rows do f.rows[i]:Hide() end
        f.scroll:SetContentHeight(y + 4)
    else
        local note = N.Find(key, f.id)
        f.title:SetText(note and N.Plain(note.title) or "?")
        for _, r in ipairs(f.rows) do r:Hide() end
        UI.SetFont(f.body, "body", p.size)
        f.body:SetWidth(width)
        local text = note and note.text or ""
        f.body:SetText(text ~= "" and text or ("|cff8a8070" .. L().NOTES_EMPTY .. "|r"))
        f.body:Show()
        f.scroll:SetContentHeight((f.body:GetStringHeight() or 0) + 8)
    end
    ApplyLook(f)
end

-- Lage, Groesse, Aussehen und Inhalt eines Zettels anwenden
function S.Update(f)
    local p = f and f.pin
    if not p then return end
    f.ready = false
    f:ClearAllPoints()
    f:SetPoint("CENTER", G.UIParent, "CENTER", p.x or 0, p.y or 0)
    f:SetSize(math.max(MIN_W, math.min(MAX_W, p.w or 220)), math.max(MIN_H, math.min(MAX_H, p.h or 170)))
    ApplyLock(f)
    S.Content(f)
    f.ready = true
end

-- Alle Zettel mit den gespeicherten Daten abgleichen (anlegen, aktualisieren, verbergen)
function S.Sync()
    if not FW.db or not N.CharKey() then return end
    local seen = {}
    for _, e in ipairs(N.PinList()) do
        seen[e.pinKey] = true
        local f = S.frames[e.pinKey]
        local fresh = not f
        if fresh then
            f = Build(e.pinKey)
            S.frames[e.pinKey] = f
        end
        f.id, f.pin = e.id, e.pin
        if fresh or not f:IsShown() then
            S.Update(f)
        else
            S.Content(f)
        end
        if Hidden() then f:Hide() else f:Show() end
    end
    for k, f in pairs(S.frames) do
        if not seen[k] then
            f.pin = nil
            f:Hide()
        end
    end
end

N.Listen(function(key)
    if key == N.CharKey() then S.Sync() end
end)

FW:RegisterEvent("PLAYER_LOGIN", function()
    inCombat = G.InCombatLockdown and G.InCombatLockdown() and true or false
    S.Sync()
end)
FW:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    inCombat = true
    if N.HideInCombat() then S.Sync() end
end)
FW:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    inCombat = false
    S.Sync()
end)

-- fuer Tests
function S.SetCombat(v) inCombat = v and true or false S.Sync() end
