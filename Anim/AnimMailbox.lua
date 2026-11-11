-- Freewood-Core: Animation "Briefkasten". Bild 1 = keine neue Post, Bild 2 bis 4 laufen ab, wenn Post eintrifft,
-- Bild 4 = Post im Briefkasten. Wird die Post gelesen, laeuft die Folge rueckwaerts von 4 nach 1.
-- "Post" heisst: ungelesene Post, so wie das Spiel sie am Minimap-Briefsymbol zeigt (HasNewMail).

local ADDON, FW = ...

local A = FW.Anim
if not A then return end

local M = { has = false }
A.mailbox = M

A.RegisterEvent("MAIL_NEW", "ANIM_EV_MAIL_NEW")
A.RegisterEvent("MAIL_EMPTY", "ANIM_EV_MAIL_EMPTY")

local function Has()
    if type(_G.HasNewMail) ~= "function" then return false end
    local ok, v = pcall(_G.HasNewMail)
    return ok and v and true or false
end

-- Stand pruefen; silent = ohne Abspielen (Anmelden), sonst Ereignis ausloesen
local function Evaluate(silent)
    local now = Has()
    if now == M.has then return end
    M.has = now
    if silent then
        A.Sync("mailbox")
    else
        A.Fire(now and "MAIL_NEW" or "MAIL_EMPTY")
    end
end
M.Evaluate = Evaluate

-- Vorgabe: ueber der Aktionsleiste 3 (MultiBarBottomRight) ganz rechts, dahinter
local BARS = { "MultiBarBottomRight", "MultiBarBottomLeft", "MainMenuBar", "MainActionBar" }
local function DefaultPlace(f)
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        if bar and bar.IsVisible and bar:IsVisible() and bar.GetTop and bar:GetTop() then
            f:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, -28)
            return
        end
    end
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 110)
end

-- Aussehen: 18 Briefkaesten, je 4 Bilder; 3 Aussehen je Bildplatte Mailbox1..6.tga (1024x1024, Felder 256x341, Bild 252x336)
local SKIN_IDS = { "horde", "allianz", "mensch", "orc", "nachtelf", "zwerg", "gnom", "untot", "tauren", "troll",
    "greif", "hexenmeister", "paladin", "magier", "krieger", "druide", "schamane", "jaeger" }
local SKINS = {}
for k, id in ipairs(SKIN_IDS) do
    SKINS[k] = {
        id = id,
        nameKey = "ANIM_SKIN_" .. id,
        atlas = { file = A.MEDIA .. "Mailbox" .. (math.floor((k - 1) / 3) + 1) .. ".tga", texW = 1024, texH = 1024,
            cellW = 256, cellH = 341, cols = 4, w = 252, h = 336, ox = 2, oy = 2, row0 = (k - 1) % 3 },
    }
end

local function DefaultSkin()
    local ok, faction = pcall(function() return _G.UnitFactionGroup and _G.UnitFactionGroup("player") end)
    return (ok and faction == "Alliance") and "allianz" or "horde"
end

A.Register({
    id = "mailbox",
    nameKey = "ANIM_MAILBOX",
    kind = "static",
    skins = SKINS,
    defaultSkin = DefaultSkin,
    frames = 4,
    fps = 8,
    width = 96,
    height = 128,
    defaults = { enabled = true, showEmpty = false, scale = 100 },
    bindings = {
        { event = "MAIL_NEW", action = "forward" },
        { event = "MAIL_NEW", action = "sound" },
        { event = "MAIL_EMPTY", action = "reverse" },
    },
    active = function() return M.has end,
    defaultPlace = DefaultPlace,
    snoozeVisitKey = "ANIM_SNOOZE_VISIT_MAIL",
    showEmptyKey = "ANIM_SHOWEMPTY_MAIL",
    eventsKey = "ANIM_EVENTS_MAIL",
    tooltip = function(tip)
        local L = FW.L
        if M.has then
            tip:AddLine(L.ANIM_TT_NEW, 0.4, 0.9, 0.4)
        else
            tip:AddLine(L.ANIM_TT_NONE, 0.8, 0.8, 0.8)
        end
        if type(_G.GetInboxNumItems) == "function" then
            local ok, n = pcall(_G.GetInboxNumItems)
            if ok and type(n) == "number" and n > 0 then
                tip:AddLine(string.format(L.ANIM_TT_COUNT, n), 0.8, 0.8, 0.8)
            end
        end
    end,
    tests = {
        { id = "on", labelKey = "ANIM_TEST_ON", run = function() M.has = true; A.Fire("MAIL_NEW") end },
        { id = "off", labelKey = "ANIM_TEST_OFF", run = function() M.has = false; A.Fire("MAIL_EMPTY") end },
    },
})

local function Throttled()
    -- MAIL_INBOX_UPDATE kann sehr oft kommen: nur pruefen, nicht aufbauen
    Evaluate(false)
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Evaluate(true)
    A.Sync("mailbox")
    A.pendingReplace = 2   -- Position nach dem Aufbau der Leisten noch einmal setzen
end, M)
FW:RegisterEvent("UPDATE_PENDING_MAIL", function() Evaluate(false) end, M)
FW:RegisterEvent("MAIL_INBOX_UPDATE", Throttled, M)
FW:RegisterEvent("MAIL_CLOSED", function() Evaluate(false) end, M)
FW:RegisterEvent("MAIL_SHOW", function()
    -- am Briefkasten: "bis zum Besuch ausgeblendet" endet
    A.Unsnooze("mailbox", false)
end, M)
