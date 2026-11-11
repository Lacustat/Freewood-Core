-- Freewood-Core: Animationen. Grundlage fuer Bilder, die an einem Ort eine Bilderfolge abspielen (statisch).
-- Spaeter folgen Wege (2 Punkte, mehrere Punkte). Eine Animation ist eine Beschreibung (A.Register) mit:
--   id, nameKey, kind = "static", atlas (Bildplatte mit Einzelbildern), frames (Anzahl), fps, width, height (Einheiten),
--   defaults (Voreinstellungen), bindings = { { event = "NAME", action = "forward" | "reverse" | "sound" } },
--   active() (true = "Inhalt da", z. B. Post im Briefkasten), defaultPlace(frame), tooltip(tip), tests, snoozeVisitKey.
-- Ereignisse: A.Fire("NAME") loest alle Verknuepfungen aus. Einstellungen: FreewoodDB.settings.animation.
-- Der Reiter "Animation" in den Einstellungen steht in AnimUI.lua, der Briefkasten in AnimMailbox.lua.

local ADDON, FW = ...

local UI = FW.UI
local A = { defs = {}, order = {}, frames = {}, events = {}, eventOrder = {} }
FW.Anim = A

A.MEDIA = "Interface\\AddOns\\Freewood-Core\\Media\\Animation\\"
A.SOUND_DIR = "Interface\\AddOns\\Freewood-Sounds\\"
A.ALARM_ID = 12867   -- "Wecker" (SOUNDKIT.ALARM_CLOCK_WARNING_3), Nummer auf Forever noch nicht geprueft

local fallback = { sound = { mode = "alarm", file = "" }, anims = {} }

local function Root()
    local s = FW.settings
    if type(s) ~= "table" then return fallback end
    if type(s.animation) ~= "table" then s.animation = {} end
    local o = s.animation
    if type(o.sound) ~= "table" then o.sound = {} end
    if o.sound.mode ~= "alarm" and o.sound.mode ~= "file" and o.sound.mode ~= "off" then o.sound.mode = "alarm" end
    if type(o.sound.file) ~= "string" then o.sound.file = "" end
    if type(o.anims) ~= "table" then o.anims = {} end
    return o
end

function A.SoundCfg() return Root().sound end

function A.Cfg(id)
    local def = A.defs[id]
    local all = Root().anims
    if type(all[id]) ~= "table" then all[id] = {} end
    local c = all[id]
    local d = def and def.defaults or {}
    if c.enabled == nil then c.enabled = (d.enabled ~= false) end
    if c.showEmpty == nil then c.showEmpty = d.showEmpty == true end
    if type(c.scale) ~= "number" then c.scale = d.scale or 100 end
    c.scale = math.max(30, math.min(300, c.scale))
    if type(c.snoozeUntil) ~= "number" then c.snoozeUntil = 0 end
    if c.snoozeVisit ~= true then c.snoozeVisit = false end
    return c
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

function A.RegisterEvent(id, labelKey)
    if not A.events[id] then A.eventOrder[#A.eventOrder + 1] = id end
    A.events[id] = labelKey or id
end

function A.Register(def)
    assert(type(def) == "table" and def.id, "Anim.Register: id fehlt")
    if not A.defs[def.id] then A.order[#A.order + 1] = def.id end
    A.defs[def.id] = def
    if A.ready then A.Build(def.id) end
end

------------------------------------------------------------------------
-- Bilder
------------------------------------------------------------------------

-- Zuschnitt (links, rechts, oben, unten) des Einzelbilds i aus der Bildplatte
function A.UV(def, i)
    local a = def.atlas
    local col = (i - 1) % a.cols
    local row = math.floor((i - 1) / a.cols)
    local l = col * a.cellW / a.texW
    local t = row * a.cellH / a.texH
    return l, l + a.w / a.texW, t, t + a.h / a.texH
end

local function ShowFrameNo(f, i)
    f.cur = i
    f.tex:SetTexCoord(A.UV(f.def, i))
end

function A.IsSnoozed(id)
    local c = A.Cfg(id)
    return c.snoozeVisit or c.snoozeUntil > time()
end

local function Wanted(id)
    local def, f = A.defs[id], A.frames[id]
    local c = A.Cfg(id)
    if not c.enabled or A.IsSnoozed(id) then return false end
    if def.active and def.active() then return true end
    return c.showEmpty or f.cur ~= 1 or f.target ~= 1
end

-- Sichtbarkeit anwenden; was nicht sichtbar ist, springt sofort auf den Zielstand
function A.Refresh(id)
    local f = A.frames[id]
    if not f then return end
    if Wanted(id) then
        if not f:IsShown() then f:Show() end
    else
        if f.cur ~= f.target then ShowFrameNo(f, f.target) end
        if f:IsShown() then f:Hide() end
    end
end

-- Zielbild setzen; die Bilder dazwischen laufen mit def.fps ab (hin und zurueck)
function A.GoTo(id, target)
    local f = A.frames[id]
    if not f then return end
    f.target = math.max(1, math.min(f.def.frames, target))
    A.Refresh(id)
    if not f:IsShown() then ShowFrameNo(f, f.target) end
end

-- ohne Abspielen auf den Stand springen, den active() meldet (Anmelden, Erinnerung)
function A.Sync(id)
    local f = A.frames[id]
    if not f then return end
    local def = f.def
    local t = (def.active and def.active()) and def.frames or 1
    f.target = t
    ShowFrameNo(f, t)
    A.Refresh(id)
end

------------------------------------------------------------------------
-- Ton
------------------------------------------------------------------------

function A.PlaySound(force)
    local s = A.SoundCfg()
    if s.mode == "off" and not force then return end
    if s.mode == "file" and s.file ~= "" then
        local ok, willPlay = pcall(PlaySoundFile, A.SOUND_DIR .. s.file, "Master")
        if ok and willPlay ~= false then return end   -- Datei fehlt: auf den Standardton zurueckfallen
    end
    if s.mode == "off" then return end
    local id = (_G.SOUNDKIT and _G.SOUNDKIT.ALARM_CLOCK_WARNING_3) or A.ALARM_ID
    pcall(PlaySound, id, "Master")
end

------------------------------------------------------------------------
-- Verknuepfungen
------------------------------------------------------------------------

local function Act(id, action)
    local c = A.Cfg(id)
    if action == "forward" then
        A.GoTo(id, A.defs[id].frames)
    elseif action == "reverse" then
        A.GoTo(id, 1)
    elseif action == "sound" then
        if c.enabled and not A.IsSnoozed(id) then A.PlaySound() end
    end
end

function A.Fire(event)
    for _, id in ipairs(A.order) do
        for _, b in ipairs(A.defs[id].bindings or {}) do
            if b.event == event then Act(id, b.action) end
        end
    end
end

------------------------------------------------------------------------
-- Ausblenden (Rechtsklick)
------------------------------------------------------------------------

function A.Snooze(id, minutes)
    local c = A.Cfg(id)
    if minutes then
        c.snoozeUntil = time() + minutes * 60
        c.snoozeVisit = false
    else
        c.snoozeUntil = 0
        c.snoozeVisit = true
    end
    A.Refresh(id)
end

function A.Unsnooze(id, remind)
    local c = A.Cfg(id)
    local was = c.snoozeVisit or c.snoozeUntil > 0
    c.snoozeUntil = 0
    c.snoozeVisit = false
    if not was then return end
    A.Sync(id)
    if remind and c.enabled and A.defs[id].active and A.defs[id].active() then A.PlaySound() end
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------

function A.Size(id)
    local f, def = A.frames[id], A.defs[id]
    if not f then return end
    local k = A.Cfg(id).scale / 100
    f:SetSize(def.width * k, def.height * k)
end

function A.Place(id)
    local f, def = A.frames[id], A.defs[id]
    if not f then return end
    local pos = A.Cfg(id).pos
    f:ClearAllPoints()
    if type(pos) == "table" and pos.x and pos.y then
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    elseif def.defaultPlace then
        def.defaultPlace(f)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function A.ResetPosition(id)
    A.Cfg(id).pos = nil
    A.Place(id)
end

local menu
local function BuildMenu()
    if menu then return menu end
    menu = UI.CreatePanel(UIParent, "bg", "bronze")
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(270, 92)
    menu:EnableMouse(true)
    menu:Hide()
    menu.title = UI.CreateLabel(menu, "", { size = 12, color = "goldLight" })
    menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -8)
    menu.b1 = UI.CreateButton(menu, "", 250, 24, function()
        A.Snooze(menu.id, nil)
        menu:Hide()
    end)
    menu.b1:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -30)
    menu.b2 = UI.CreateButton(menu, "", 250, 24, function()
        A.Snooze(menu.id, 60)
        menu:Hide()
    end)
    menu.b2:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -58)
    menu:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver and MouseIsOver(self) then
            self.idle = 0
        else
            self.idle = (self.idle or 0) + elapsed
            if self.idle > 1.5 then self:Hide() end
        end
    end)
    return menu
end

function A.OpenMenu(id)
    local def, L = A.defs[id], FW.L
    local m = BuildMenu()
    m.id = id
    m.idle = 0
    m.title:SetText(L[def.nameKey] or id)
    if def.snoozeVisitKey then
        m.b1:SetLabel(L[def.snoozeVisitKey])
        m.b1:Show()
    else
        m.b1:Hide()
    end
    m.b2:SetLabel(L.ANIM_SNOOZE_60)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    m:ClearAllPoints()
    m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale - 12, y / scale - 12)
    m:Show()
end

function A.Build(id)
    local def = A.defs[id]
    if A.frames[id] or not def then return A.frames[id] end
    local f = CreateFrame("Button", "FreewoodAnim_" .. id, UIParent)
    f.def = def
    f:SetFrameStrata("LOW")   -- hinter den Aktionsleisten (MEDIUM): sie verdecken den unteren Teil
    f:SetFrameLevel(1)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForClicks("RightButtonUp")
    f:RegisterForDrag("LeftButton")
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints(f)
    f.tex:SetTexture(def.atlas.file)
    f.target = 1
    f.acc = 0
    ShowFrameNo(f, 1)
    A.frames[id] = f

    f:SetScript("OnUpdate", function(self, elapsed)
        if self.cur == self.target then return end
        self.acc = self.acc + elapsed
        local step = 1 / (self.def.fps or 8)
        while self.acc >= step and self.cur ~= self.target do
            self.acc = self.acc - step
            ShowFrameNo(self, self.cur + (self.target > self.cur and 1 or -1))
        end
        if self.cur == self.target then
            self.acc = 0
            A.Refresh(id)
        end
    end)
    f:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not InCombatLockdown() then
            self:StartMoving()
            self.moving = true
        end
    end)
    f:SetScript("OnDragStop", function(self)
        if not self.moving then return end
        self:StopMovingOrSizing()
        self.moving = false
        local x, y = self:GetLeft(), self:GetBottom()
        if x and y then
            A.Cfg(id).pos = { x = x, y = y }
            A.Place(id)
        end
    end)
    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then A.OpenMenu(id) end
    end)
    f:SetScript("OnEnter", function(self)
        local L = FW.L
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L[def.nameKey] or id, 1, 0.82, 0)
        if def.tooltip then def.tooltip(GameTooltip) end
        GameTooltip:AddLine(L.ANIM_TT_HINT, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    A.Size(id)
    A.Place(id)
    A.Sync(id)
    return f
end

-- Erinnerung nach Ablauf der Auszeit, alle 5 Sekunden pruefen
local driver

function A.Init()
    if A.ready then return end
    A.ready = true
    for _, id in ipairs(A.order) do A.Build(id) end
    driver = CreateFrame("Frame")
    driver.acc = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        if A.pendingReplace then
            A.pendingReplace = A.pendingReplace - elapsed
            if A.pendingReplace <= 0 then
                A.pendingReplace = nil
                A.Replace()
            end
        end
        self.acc = self.acc + elapsed
        if self.acc < 5 then return end
        self.acc = 0
        for _, id in ipairs(A.order) do
            local c = A.Cfg(id)
            if c.snoozeUntil > 0 and time() >= c.snoozeUntil then A.Unsnooze(id, true) end
        end
    end)
end

-- Nach dem Anmelden Position erneut setzen (Aktionsleisten sind dann aufgebaut)
function A.Replace()
    for _, id in ipairs(A.order) do
        if A.frames[id] and not A.Cfg(id).pos then A.Place(id) end
    end
end

FW:On("FW_DB_READY", function() A.Init() end)

------------------------------------------------------------------------
-- Befehl /fwanim (Test)
------------------------------------------------------------------------

SLASH_FWANIM1 = "/fwanim"
SlashCmdList = SlashCmdList or {}
SlashCmdList["FWANIM"] = function(msg)
    msg = strtrim(msg or ""):lower()
    local L = FW.L
    if msg == "neu" or msg == "new" then
        for _, id in ipairs(A.order) do
            for _, t in ipairs(A.defs[id].tests or {}) do if t.id == "on" then t.run() end end
        end
    elseif msg == "leer" or msg == "empty" then
        for _, id in ipairs(A.order) do
            for _, t in ipairs(A.defs[id].tests or {}) do if t.id == "off" then t.run() end end
        end
    elseif msg == "ton" or msg == "sound" then
        A.PlaySound(true)
    elseif msg == "reset" then
        for _, id in ipairs(A.order) do A.ResetPosition(id) end
    else
        FW:Print(L.ANIM_SLASH_HELP)
    end
end
