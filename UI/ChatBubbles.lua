-- Freewood-Core: Chat-Blasen. Neue Nachrichten aus Gilde, Gruppe/Schlachtzug (und optional Fluestern, Kanaelen)
-- steigen als Sprechblasen von einem verschiebbaren Ankerpunkt auf und verblassen. UNGEPRUEFT im Spiel.
-- Quelle: Core/ChatLog.lua ruft FW.ChatBubbles.Push(key, sender, text, eigeneNachricht) auf.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local B = {}
FW.ChatBubbles = B

local table = setmetatable({ getn = function(t) return #t end }, { __index = _G.table })

B.DEFAULTS = {
    enabled = true,
    guild = true,
    group = true,
    whisper = false,
    channels = false,
    own = true,
    duration = 8,       -- Sekunden, bis die Blase verblasst ist
    direction = "UP",   -- UP, DOWN, LEFT, RIGHT
    max = 6,
    point = "CENTER", x = -380, y = -80,
}

local TRAVEL = 170        -- Strecke in Pixeln
local WIDTH = 270
local GAP = 4
local MAX_POOL = 12
local MAX_CHARS = 160

local COLORS = {
    guild = { 0.25, 1, 0.25 },
    group = { 0.67, 0.67, 1 },
    whisper = { 1, 0.5, 1 },
    channels = { 0.9, 0.85, 0.7 },
}

local function Opts()
    local s = FW.settings
    if type(s) ~= "table" then return B.DEFAULTS end
    if type(s.bubbles) ~= "table" then s.bubbles = {} end
    local o = s.bubbles
    for k, v in pairs(B.DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end
B.Opts = Opts

local DIRS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

local function Source(key)
    if key == "guild" or key == "group" then return key end
    if type(key) ~= "string" then return nil end
    if string.sub(key, 1, 2) == "w:" then return "whisper" end
    if string.sub(key, 1, 2) == "c:" then return "channels" end
    return nil
end

------------------------------------------------------------------------
-- Anker
------------------------------------------------------------------------

local anchor, handle
local function EnsureAnchor()
    if anchor then return end
    anchor = CreateFrame("Frame", "FreewoodChatBubbleAnchor", UIParent)
    anchor:SetSize(WIDTH, 28)
    anchor:SetFrameStrata("MEDIUM")
    handle = CreateFrame("Frame", nil, anchor)
    handle:SetAllPoints(anchor)
    handle:SetFrameLevel(anchor:GetFrameLevel() + 20)
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    local bg = handle:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(handle)
    bg:SetColorTexture(0.78, 0.61, 0.24, 0.55)
    local txt = handle:CreateFontString(nil, "OVERLAY")
    UI.SetFont(txt, "body", 12)
    txt:SetPoint("CENTER", handle, "CENTER", 0, 0)
    txt:SetText(FW.L.BUBBLE_ANCHOR_TEXT)
    handle.text = txt
    handle:SetScript("OnDragStart", function() anchor:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local o = Opts()
        local cx = anchor:GetCenter()
        local ax = UIParent:GetCenter()
        local _, cy = anchor:GetCenter()
        local _, ay = UIParent:GetCenter()
        if cx and ax and cy and ay then
            o.point, o.x, o.y = "CENTER", math.floor(cx - ax + 0.5), math.floor(cy - ay + 0.5)
        end
    end)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    handle:Hide()
end

function B.ApplyAnchor()
    EnsureAnchor()
    local o = Opts()
    anchor:ClearAllPoints()
    anchor:SetPoint(o.point or "CENTER", UIParent, o.point or "CENTER", o.x or 0, o.y or 0)
end

function B.SetUnlocked(on)
    EnsureAnchor()
    B.ApplyAnchor()
    if on then handle:Show() else handle:Hide() end
    B.unlocked = on and true or false
end

------------------------------------------------------------------------
-- Blasen
------------------------------------------------------------------------

local pool, active = {}, {}      -- active: aelteste zuerst

local function NewBubble()
    EnsureAnchor()
    local f = CreateFrame("Frame", nil, anchor)
    f:SetFrameStrata("MEDIUM")
    f:SetWidth(WIDTH)
    f:EnableMouse(false)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    f.bg = bg
    local bar = f:CreateTexture(nil, "BORDER")
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.bar = bar
    local fs = f:CreateFontString(nil, "OVERLAY")
    UI.SetFont(fs, "body", 12)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -4)
    fs:SetWidth(WIDTH - 14)
    f.text = fs
    f:Hide()
    return f
end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Acquire()
    local f = table.remove(pool)
    if f then return f end
    if table.getn(active) + table.getn(pool) >= MAX_POOL then return nil end
    return NewBubble()
end

local function Release(f)
    f:Hide()
    f.age = nil
    pool[table.getn(pool) + 1] = f
end

function B.Push(key, sender, text, out)
    local o = Opts()
    if not o.enabled then return end
    local src = Source(key)
    if not src or not o[src] then return end
    if out and not o.own then return end
    if type(text) ~= "string" or text == "" then return end
    if type(sender) ~= "string" then sender = "?" end
    EnsureAnchor()
    -- zu viele Blasen: die aelteste verschwindet sofort
    while table.getn(active) >= math.max(1, math.min(o.max or 6, MAX_POOL)) do
        Release(table.remove(active, 1))
    end
    local f = Acquire()
    if not f then
        Release(table.remove(active, 1))
        f = Acquire()
        if not f then return end
    end
    local CL = FW.ChatLog
    local tok = CL and CL.Info and CL.Info(sender)
    local nr, ng, nb = 1, 0.82, 0.3
    if tok and CL.ClassColor then nr, ng, nb = CL.ClassColor(tok) end
    local c = COLORS[src] or COLORS.channels
    if #text > MAX_CHARS then text = string.sub(text, 1, MAX_CHARS) .. "..." end
    f.text:SetText(Hex(nr, ng, nb) .. sender .. "|r: " .. text)
    f.text:SetTextColor(c[1], c[2], c[3])
    local h = (f.text:GetStringHeight() or 14) + 10
    f:SetHeight(h)
    f.bg:SetColorTexture(0.03, 0.04, 0.07, 0.82)
    f.bar:SetColorTexture(c[1], c[2], c[3], 1)
    f.age = 0
    f.h = h
    f:SetAlpha(1)
    f:Show()
    active[table.getn(active) + 1] = f
end

-- Lage und Durchsichtigkeit aller Blasen (neueste zuerst setzen, aeltere weichen aus)
local function Layout()
    local o = Opts()
    local dir = DIRS[o.direction] or DIRS.UP
    local dx, dy = dir[1], dir[2]
    local horizontal = dx ~= 0
    local dur = math.max(1, o.duration or 8)
    local n = table.getn(active)
    local prevOffset, prevExtent
    local i = n
    while i >= 1 do
        local f = active[i]
        local frac = (f.age or 0) / dur
        local offset = frac * TRAVEL
        if prevOffset then
            local minOff = prevOffset + prevExtent + GAP
            if offset < minOff then offset = minOff end
        end
        local extent = horizontal and WIDTH or f.h
        f:ClearAllPoints()
        -- Blase hat ihre Ecke am Anker; je nach Richtung nach aussen versetzt
        local px, py = dx * offset, dy * offset
        if dy > 0 then
            f:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", px, py)
        elseif dy < 0 then
            f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", px, py)
        elseif dx > 0 then
            f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", px + GAP, py)
        else
            f:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", px - GAP, py)
        end
        local a = 1
        if frac > 0.7 then a = math.max(0, 1 - (frac - 0.7) / 0.3) end
        f:SetAlpha(a)
        prevOffset, prevExtent = offset, extent
        i = i - 1
    end
end

local ticker = CreateFrame("Frame")
function B.Tick(el)
    local fn = ticker._scripts and ticker._scripts.OnUpdate
    if fn then fn(ticker, el) end
end
ticker:SetScript("OnUpdate", function(_, el)
    local n = table.getn(active)
    if n == 0 then return end
    el = el or 0
    local dur = math.max(1, Opts().duration or 8)
    local k = 1
    while k <= table.getn(active) do
        local f = active[k]
        f.age = (f.age or 0) + el
        if f.age >= dur then
            table.remove(active, k)
            Release(f)
        else
            k = k + 1
        end
    end
    if table.getn(active) > 0 then Layout() end
end)

function B.Count() return table.getn(active) end
function B.Active() return active end

function B.Clear()
    while table.getn(active) > 0 do Release(table.remove(active)) end
end

-- Testblase fuer die Einstellungen
function B.Test()
    local o = Opts()
    local was = { o.enabled, o.guild }
    o.enabled, o.guild = true, true
    B.Push("guild", G.UnitName and G.UnitName("player") or "Test", FW.L.BUBBLE_TEST_TEXT, false)
    o.enabled, o.guild = was[1], was[2]
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function() B.ApplyAnchor() end)

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("chat-bubbles", {
        category = "general",
        order = 50,
        height = 330,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.BUBBLE_TITLE)
            local function Box(label, key)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return Opts()[key] == true end,
                    function(v) Opts()[key] = v and true or false end), { fit = true })
            end
            Box(L.BUBBLE_ENABLED, "enabled")
            Box(L.BUBBLE_GUILD, "guild")
            Box(L.BUBBLE_GROUP, "group")
            Box(L.BUBBLE_WHISPER, "whisper")
            Box(L.BUBBLE_CHANNELS, "channels")
            Box(L.BUBBLE_OWN, "own")
            stack:Add(UI.CreateCheckbox(f, L.BUBBLE_UNLOCK,
                function() return B.unlocked == true end,
                function(v) B.SetUnlocked(v) end), { fit = true })

            local durLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(durLabel, { height = 16, gap = 10 })
            local slider = UI.CreateSlider(f, 200, {
                min = 2, max = 30, step = 1,
                get = function() return Opts().duration end,
                set = function(v) Opts().duration = v end,
            })
            slider.onText = function(v) durLabel:SetText(string.format(L.BUBBLE_DURATION, v)) end
            slider:Refresh()
            stack:Add(slider, { height = 20, gap = 4 })

            local dirLabel = UI.CreateLabel(f, L.BUBBLE_DIRECTION, { size = 12 })
            stack:Add(dirLabel, { height = 16, gap = 10 })
            local names = { UP = L.BUBBLE_DIR_UP, DOWN = L.BUBBLE_DIR_DOWN, LEFT = L.BUBBLE_DIR_LEFT, RIGHT = L.BUBBLE_DIR_RIGHT }
            local dd = UI.CreateDropdown(f, 160, 22, {
                getOptions = function()
                    return { { value = "UP", text = names.UP }, { value = "DOWN", text = names.DOWN },
                        { value = "LEFT", text = names.LEFT }, { value = "RIGHT", text = names.RIGHT } }
                end,
                textOf = function(v) return names[v] or "" end,
                onChange = function(v) if v then Opts().direction = v end end,
            })
            dd:SetValue(Opts().direction)
            stack:Add(dd, { height = 22, gap = 4 })

            local test = UI.CreateButton(f, L.BUBBLE_TEST, 160, 24, function() B.Test() end)
            stack:Add(test, { height = 24, gap = 10 })
            return f
        end,
    })
end
