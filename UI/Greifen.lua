-- Freewood-Core: eigene Greifen (Endkappen) an der Aktionsleiste. Ersetzt die Originalfiguren durch Bilder aus Media\Greifen,
-- je Seite eigenes Bild, Spiegelung, Groesse und Versatz. Verschiebbar im Blizzard-Bearbeitungsmodus oder ueber "Position aendern".
-- Gemessen auf Forever (Probe 7.11.2026): Die Originale liegen unter MainActionBar in zwei Rahmen mit den Bildern
-- UI-HUD-ActionBar-Wyvern-Left / -Right. Wir suchen sie ueber den Bildnamen, setzen deren Bild auf Durchsichtigkeit 0 und
-- haengen unsere Bilder an dieselben Rahmen (Versatz 0/0 = deckungsgleich mit dem Original).

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local Gr = {}
FW.Greifen = Gr

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Greifen\\"
local BASE_W, BASE_H = 220, 110      -- Groesse bei 100 Prozent

Gr.DEFAULTS = {
    enabled = false,
    left = { file = "affen_greif", mirror = false, scale = 100, x = 0, y = 0, cat = "all" },
    right = { file = "affen_greif", mirror = true, scale = 100, x = 0, y = 0, cat = "all" },
}

------------------------------------------------------------------------
-- Katalog: Bilder mit Etiketten (Set, Fraktion, Klasse, Volk), Filter fuer die Auswahl
------------------------------------------------------------------------
local de = G.GetLocale and G.GetLocale() == "deDE"
local byId = {}
local function Index()
    byId = {}
    for _, e in ipairs(FW.GreifenList or {}) do byId[e.id] = e end
end
Index()

function Gr.Entry(id) return byId[id] end
function Gr.Name(id)
    local e = byId[id]
    if not e then return id or "" end
    return (de and e.de or e.en) or e.de or e.id
end

-- Klassen und Voelker (feste Reihenfolge, Token wie in UnitClass/UnitRace)
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_NAME = {
    WARRIOR = { "Krieger", "Warrior" }, PALADIN = { "Paladin", "Paladin" }, HUNTER = { "Jäger", "Hunter" },
    ROGUE = { "Schurke", "Rogue" }, PRIEST = { "Priester", "Priest" }, SHAMAN = { "Schamane", "Shaman" },
    MAGE = { "Magier", "Mage" }, WARLOCK = { "Hexenmeister", "Warlock" }, DRUID = { "Druide", "Druid" },
}
local RACE_ORDER = { "Orc", "Troll", "Scourge", "Tauren", "Human", "Dwarf", "Gnome", "NightElf" }
local RACE_NAME = {
    Orc = { "Orc", "Orc" }, Troll = { "Troll", "Troll" }, Scourge = { "Untote", "Undead" }, Tauren = { "Tauren", "Tauren" },
    Human = { "Mensch", "Human" }, Dwarf = { "Zwerg", "Dwarf" }, Gnome = { "Gnom", "Gnome" }, NightElf = { "Nachtelf", "Night Elf" },
}
local function Named(t, key) local n = t[key]; if not n then return tostring(key) end return de and n[1] or n[2] end
function Gr.ClassName(k) return Named(CLASS_NAME, k) end
function Gr.RaceName(k) return Named(RACE_NAME, k) end

Gr.CATEGORIES = { "mine", "all", "affen", "skyborn", "daemonen", "horde", "allianz", "class", "race" }

local function Mine()
    local class, race
    if G.UnitClass then local _, c = G.UnitClass("player"); class = c end
    if G.UnitRace then local _, r = G.UnitRace("player"); race = r end
    return class, race
end

local function HasSet(e, set)
    for _, x in ipairs(e.sets or {}) do if x == set then return true end end
    return false
end

local function ByName(a, b) return Gr.Name(a.id):lower() < Gr.Name(b.id):lower() end

-- Auswahl der Unterpunkte (nur fuer Klassen/Voelker): nur was im Katalog vorkommt
function Gr.SubOptions(cat)
    local order, field, name
    if cat == "class" then order, field, name = CLASS_ORDER, "class", Gr.ClassName
    elseif cat == "race" then order, field, name = RACE_ORDER, "race", Gr.RaceName
    else return {} end
    local have = {}
    for _, e in ipairs(FW.GreifenList or {}) do if e[field] then have[e[field]] = true end end
    local list = {}
    for _, k in ipairs(order) do if have[k] then list[#list + 1] = { value = k, text = name(k) } end end
    return list
end

-- Vorgabe fuer den Unterpunkt: die eigene Klasse/das eigene Volk, sonst der erste
function Gr.DefaultSub(cat)
    local opts = Gr.SubOptions(cat)
    if #opts == 0 then return nil end
    local class, race = Mine()
    local mine = cat == "class" and class or race
    for _, o in ipairs(opts) do if o.value == mine then return mine end end
    return opts[1].value
end

-- Bilder einer Kategorie (sortiert). "mine": passend zu Klasse und/oder Volk des Spielers, beste zuerst.
function Gr.Filter(cat, sub)
    local list = {}
    local class, race = Mine()
    local rank = {}
    for _, e in ipairs(FW.GreifenList or {}) do
        local ok = false
        if cat == "affen" or cat == "skyborn" or cat == "daemonen" then ok = HasSet(e, cat)
        elseif cat == "horde" or cat == "allianz" then ok = e.faction == cat
        elseif cat == "class" then ok = e.class == sub
        elseif cat == "race" then ok = e.race == sub
        elseif cat == "mine" then
            local c, r = class and e.class == class, race and e.race == race
            ok = (c or r) and true or false
            rank[e.id] = (c and r) and 1 or (c and 2 or 3)
        else ok = true end
        if ok then list[#list + 1] = e end
    end
    table.sort(list, function(a, b)
        if cat == "mine" and rank[a.id] ~= rank[b.id] then return rank[a.id] < rank[b.id] end
        return ByName(a, b)
    end)
    return list
end

-- Groesse des Bildes bei 100 Prozent: 2:1-Bilder wie das Original, quadratische etwas hoeher
function Gr.Size(file)
    local e = byId[file]
    local aspect = e and e.aspect or 2
    if aspect >= 1.8 then return BASE_W, BASE_H end
    local h = math.floor(BASE_H * 1.4 + 0.5)
    return math.floor(h * aspect + 0.5), h
end

local function Opts()
    local s = FW.settings
    if type(s) ~= "table" then return Gr.DEFAULTS end
    if type(s.greifen) ~= "table" then s.greifen = {} end
    local o = s.greifen
    if o.enabled == nil then o.enabled = Gr.DEFAULTS.enabled end
    for _, side in ipairs({ "left", "right" }) do
        if type(o[side]) ~= "table" then o[side] = {} end
        for k, v in pairs(Gr.DEFAULTS[side]) do
            if o[side][k] == nil then o[side][k] = v end
        end
    end
    return o
end
Gr.Opts = Opts

local function Secret(v) return G.issecretvalue and G.issecretvalue(v) or false end

------------------------------------------------------------------------
-- Originale finden
------------------------------------------------------------------------
local caps = {}          -- caps.left / caps.right = { frame = Rahmen, tex = Textur }
local hooked = {}

local function Scan(f, depth)
    if not f or depth > 5 then return end
    if f.GetRegions then
        for _, r in ipairs({ f:GetRegions() }) do
            if r.GetAtlas then
                local ok, a = pcall(r.GetAtlas, r)
                if ok and type(a) == "string" and not Secret(a) then
                    local la = a:lower()
                    if la:find("actionbar") and (la:find("wyvern") or la:find("gryphon")) then
                        local side = la:find("left") and "left" or (la:find("right") and "right") or nil
                        if side then caps[side] = { frame = f, tex = r } end
                    end
                end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Scan(c, depth + 1) end
    end
end

local function FindCaps()
    local root = G.MainActionBar
    if root then pcall(Scan, root, 0) end
    return caps.left ~= nil and caps.right ~= nil
end

local function HideOriginal(cap, hide)
    if not cap or not cap.tex then return end
    cap.hide = hide
    if hide and not hooked[cap.tex] and G.hooksecurefunc then
        hooked[cap.tex] = true
        pcall(G.hooksecurefunc, cap.tex, "SetAlpha", function(self, a)
            if cap.hide and not cap.guard and a ~= 0 then
                cap.guard = true
                self:SetAlpha(0)
                cap.guard = false
            end
        end)
    end
    cap.guard = true
    cap.tex:SetAlpha(hide and 0 or 1)
    cap.guard = false
end

------------------------------------------------------------------------
-- Eigene Bilder
------------------------------------------------------------------------
local art = {}

local function Round(v) return math.floor(v + 0.5) end

local function Art(side)
    if art[side] then return art[side] end
    local f = CreateFrame("Frame", nil, G.UIParent)
    f:SetSize(BASE_W, BASE_H)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(120)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.side = side

    local ov = CreateFrame("Frame", nil, f)
    ov:SetAllPoints()
    ov:SetFrameStrata("DIALOG")
    ov:EnableMouse(true)
    ov:RegisterForDrag("LeftButton")
    ov.bg = ov:CreateTexture(nil, "OVERLAY")
    ov.bg:SetAllPoints()
    ov.bg:SetColorTexture(0.2, 1, 0.3, 0.22)
    ov.txt = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ov.txt:SetPoint("BOTTOM", ov, "TOP", 0, 2)
    ov.txt:SetText(side == "left" and FW.L.GREIFEN_DRAG_L or FW.L.GREIFEN_DRAG_R)
    ov:Hide()
    ov:SetScript("OnDragStart", function() f:StartMoving() end)
    ov:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local cap = caps[side]
        local ax, ay = f:GetCenter()
        if cap and cap.frame and ax then
            local cx, cy = cap.frame:GetCenter()
            local es, ces = f:GetEffectiveScale(), cap.frame:GetEffectiveScale()
            if cx and es and es > 0 then
                local s = Opts()[side]
                s.x = Round((ax * es - cx * ces) / es)
                s.y = Round((ay * es - cy * ces) / es)
            end
        end
        Gr.Apply()
        FW:Fire("GREIFEN_CHANGED")
    end)
    ov:EnableMouseWheel(true)
    ov:SetScript("OnMouseWheel", function(_, delta)
        local s = Opts()[side]
        s.scale = math.max(20, math.min(300, (s.scale or 100) + (delta > 0 and 5 or -5)))
        Gr.Apply()
        FW:Fire("GREIFEN_CHANGED")
    end)
    f.ov = ov
    art[side] = f
    return f
end

Gr.unlocked = false

function Gr.SetUnlocked(on)
    Gr.unlocked = on and true or false
    for _, side in ipairs({ "left", "right" }) do
        local f = art[side]
        if f then
            if Gr.unlocked and f:IsShown() then f.ov:Show() else f.ov:Hide() end
        end
    end
    FW:Fire("GREIFEN_CHANGED")
end

function Gr.Apply()
    local o = Opts()
    local found = FindCaps()
    for _, side in ipairs({ "left", "right" }) do
        local cap = caps[side]
        local s = o[side]
        if o.enabled and cap and cap.frame then
            local f = Art(side)
            local k = (s.scale or 100) / 100
            local bw, bh = Gr.Size(s.file)
            f:SetSize(bw * k, bh * k)
            f:ClearAllPoints()
            f:SetPoint("CENTER", cap.frame, "CENTER", s.x or 0, s.y or 0)
            if s.file and s.file ~= "" then f.tex:SetTexture(PATH .. s.file) else f.tex:SetTexture(nil) end
            if s.mirror then f.tex:SetTexCoord(1, 0, 0, 1) else f.tex:SetTexCoord(0, 1, 0, 1) end
            f:Show()
            if Gr.unlocked then f.ov:Show() end
            HideOriginal(cap, true)
        else
            if art[side] then art[side]:Hide(); art[side].ov:Hide() end
            if cap then HideOriginal(cap, false) end
        end
    end
    return found
end

-- die Originale koennen spaeter entstehen oder neu aufgebaut werden: mehrere Versuche
local function Retry(n)
    if not Opts().enabled then return end
    if not Gr.Apply() and n > 0 and G.C_Timer then G.C_Timer.After(2, function() Retry(n - 1) end) end
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if G.C_Timer then
        G.C_Timer.After(1, function() Retry(8) end)
        G.C_Timer.After(6, function() Retry(2) end)
    end
end)

-- Blizzard-Bearbeitungsmodus: beim Oeffnen Rahmen zum Ziehen zeigen, beim Schliessen wieder verstecken
local function HookEditMode()
    local m = G.EditModeManagerFrame
    if not m or Gr.editHooked or not m.HookScript then return end
    Gr.editHooked = true
    m:HookScript("OnShow", function() if Opts().enabled then Gr.SetUnlocked(true) end end)
    m:HookScript("OnHide", function()
        Gr.SetUnlocked(false)
        if G.C_Timer then G.C_Timer.After(0.5, function() Retry(2) end) end
    end)
end
FW:RegisterEvent("PLAYER_LOGIN", HookEditMode)
FW:RegisterEvent("ADDON_LOADED", HookEditMode)

------------------------------------------------------------------------
-- Einstellungen: Reiter "Interface"
------------------------------------------------------------------------
local function CatText(c)
    local L = FW.L
    return L["GREIFEN_CAT_" .. string.upper(c)] or c
end

local function BuildSide(f, stack, side, title, refreshers)
    local L = FW.L
    stack:Add(UI.CreateLabel(f, title, { size = 13, color = "goldLight" }), { height = 18, gap = 12 })

    -- Zeile 1: Kategorie und (bei Klassen/Voelkern) Unterpunkt
    local top = CreateFrame("Frame", nil, f)
    top:SetSize(320, 26)
    local ddCat, ddSub
    ddCat = UI.CreateDropdown(top, 160, 22, {
        prefix = L.GREIFEN_CAT,
        getOptions = function()
            local list = {}
            for _, c in ipairs(Gr.CATEGORIES) do list[#list + 1] = { value = c, text = CatText(c) } end
            return list
        end,
        textOf = CatText,
        maxRows = 10,
        onChange = function(v)
            if not v then return end
            local s = Opts()[side]
            s.cat = v
            s.sub = Gr.DefaultSub(v)
            FW:Fire("GREIFEN_CHANGED")
        end,
    })
    ddCat:SetPoint("TOPLEFT", top, "TOPLEFT", 0, -2)
    ddSub = UI.CreateDropdown(top, 150, 22, {
        getOptions = function() return Gr.SubOptions(Opts()[side].cat) end,
        textOf = function(v)
            local c = Opts()[side].cat
            return c == "class" and Gr.ClassName(v) or Gr.RaceName(v)
        end,
        maxRows = 10,
        onChange = function(v)
            if v then Opts()[side].sub = v; FW:Fire("GREIFEN_CHANGED") end
        end,
    })
    ddSub:SetPoint("LEFT", ddCat, "RIGHT", 8, 0)
    stack:Add(top, { height = 28, gap = 4 })

    -- Zeile 2: Bild und Vorschau
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(320, 44)
    local dd = UI.CreateDropdown(row, 220, 22, {
        getOptions = function()
            local s = Opts()[side]
            local list = {}
            for _, e in ipairs(Gr.Filter(s.cat or "all", s.sub)) do list[#list + 1] = { value = e.id, text = Gr.Name(e.id) } end
            return list
        end,
        textOf = Gr.Name,
        maxRows = 12,
        onChange = function(v) if v then Opts()[side].file = v; Gr.Apply(); FW:Fire("GREIFEN_CHANGED") end end,
    })
    dd:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
    local pv = CreateFrame("Frame", nil, row)
    pv:SetSize(80, 40)
    pv:SetPoint("LEFT", dd, "RIGHT", 12, 0)
    pv.t = pv:CreateTexture(nil, "ARTWORK")
    pv.t:SetAllPoints()
    stack:Add(row, { height = 44, gap = 4 })
    local function RefreshPreview()
        local s = Opts()[side]
        if not s.cat then s.cat = "all" end
        if (s.cat == "class" or s.cat == "race") and not s.sub then s.sub = Gr.DefaultSub(s.cat) end
        ddCat:SetValue(s.cat)
        if s.cat == "class" or s.cat == "race" then
            ddSub:Show()
            ddSub:SetValue(s.sub)
        else
            ddSub:Hide()
        end
        dd:SetValue(s.file)
        local pw, ph = Gr.Size(s.file)
        pv:SetSize(40 * pw / ph, 40)
        if s.file and s.file ~= "" then pv.t:SetTexture(PATH .. s.file) else pv.t:SetTexture(nil) end
        if s.mirror then pv.t:SetTexCoord(1, 0, 0, 1) else pv.t:SetTexCoord(0, 1, 0, 1) end
    end
    refreshers[#refreshers + 1] = RefreshPreview
    RefreshPreview()

    stack:Add(UI.CreateCheckbox(f, L.GREIFEN_MIRROR,
        function() return Opts()[side].mirror == true end,
        function(v) Opts()[side].mirror = v and true or false; RefreshPreview(); Gr.Apply() end), { fit = true })

    local function Slider(key, label, lo, hi, step)
        local lab = UI.CreateLabel(f, "", { size = 12 })
        stack:Add(lab, { height = 16, gap = 8 })
        local sl = UI.CreateSlider(f, 220, {
            min = lo, max = hi, step = step,
            get = function() return Opts()[side][key] end,
            set = function(v) Opts()[side][key] = v; Gr.Apply() end,
        })
        sl.onText = function(v) lab:SetText(string.format(label, v)) end
        sl:Refresh()
        stack:Add(sl, { height = 20, gap = 2 })
        refreshers[#refreshers + 1] = function() sl:Refresh() end
    end
    Slider("scale", L.GREIFEN_SCALE, 20, 300, 5)
    Slider("x", L.GREIFEN_X, -300, 300, 1)
    Slider("y", L.GREIFEN_Y, -300, 300, 1)
end

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("greifen", {
        category = "interface",
        order = 10,
        height = 860,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.GREIFEN_TITLE)
            local refreshers = {}
            stack:Add(UI.CreateCheckbox(f, L.GREIFEN_ENABLE,
                function() return Opts().enabled == true end,
                function(v) Opts().enabled = v and true or false; Gr.Apply() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.GREIFEN_UNLOCK,
                function() return Gr.unlocked == true end,
                function(v) Gr.SetUnlocked(v) end), { fit = true })
            stack:Add(UI.CreateLabel(f, L.GREIFEN_HINT, { size = 11, color = "textDim" }), { height = 30, gap = 6 })
            BuildSide(f, stack, "left", L.GREIFEN_LEFT, refreshers)
            BuildSide(f, stack, "right", L.GREIFEN_RIGHT, refreshers)
            f.fwRefreshers = refreshers
            FW:On("GREIFEN_CHANGED", function() for _, r in ipairs(refreshers) do r() end end, f)
            return f
        end,
        refresh = function(frame)
            if frame and frame.fwRefreshers then for _, r in ipairs(frame.fwRefreshers) do r() end end
        end,
    })
end
