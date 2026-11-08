-- Freewood-Core: Chat verschoenern ("Blasen-Look light") im Chatfenster des Spiels.
-- Jede Zeile bekommt vor dem Anzeigen: Uhrzeit, einen farbigen Balken in der Kanalfarbe, den Absendernamen in Klassenfarbe
-- (ohne Klammern, wenn gewuenscht). Technik: AddMessage der Chatfenster wird eingehuellt (wie bei Chatter/Prat), kein
-- Chat-Filter. Geheime Werte werden unveraendert durchgereicht, bei jedem Fehler wird die Zeile unveraendert angezeigt.
-- Alles per Einstellung (Reiter Chat) abschaltbar. UNGEPRUEFT im Spiel.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local S = {}
FW.ChatStyle = S

S.DEFAULTS = {
    enabled = true,
    time = true,
    bar = true,
    classColor = true,
    brackets = false,      -- Klammern um Namen behalten
}

local MARK = "\124cff000001\124r"   -- unsichtbare Marke: Zeile wurde schon bearbeitet

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

function S.Opts()
    local st = FW.settings
    if type(st) ~= "table" then return S.DEFAULTS end
    if type(st.chatStyle) ~= "table" then st.chatStyle = {} end
    local o = st.chatStyle
    for k, v in pairs(S.DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end

local function Hex(r, g, b)
    local function c(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format("\124cff%02x%02x%02x", c(r), c(g), c(b))
end

local function NameKey(link, shown)
    local n = string.match(link or "", "^player:([^:]+)")
    if n and n ~= "" then return n end
    return shown
end

-- Zeile umbauen; gibt den neuen Text zurueck (oder den alten, wenn nichts zu tun ist)
function S.Format(text, r, g, b)
    if type(text) ~= "string" or Secret(text) or text == "" then return text end
    local o = S.Opts()
    if not o.enabled then return text end
    if string.find(text, MARK, 1, true) then return text end
    local nr, ng, nb = tonumber(r), tonumber(g), tonumber(b)
    if Secret(r) or Secret(g) or Secret(b) then nr, ng, nb = nil, nil, nil end
    local back = (nr and ng and nb) and Hex(nr, ng, nb) or nil

    if o.classColor or not o.brackets then
        local CL = FW.ChatLog
        text = string.gsub(text, "(\124H(player:[^\124]*)\124h)%[([^%]]*)%](\124h)", function(open, link, shown, close)
            local inner = o.brackets and ("[" .. shown .. "]") or shown
            if o.classColor and CL and CL.Info and CL.ClassColor then
                local tok = CL.Info(NameKey(link, shown))
                if tok then
                    local cr, cg, cb = CL.ClassColor(tok)
                    inner = Hex(cr, cg, cb) .. inner .. "\124r" .. (back or "")
                end
            end
            return open .. inner .. close
        end)
    end

    local pre = MARK
    if o.time and G.date then
        pre = pre .. "\124cff8a8a8a" .. G.date("%H:%M") .. "\124r "
    end
    if o.bar and back then
        pre = pre .. back .. "\226\150\140\124r "     -- ▌
    end
    return pre .. text
end

------------------------------------------------------------------------
-- Einhuellen von AddMessage
------------------------------------------------------------------------

local wrapped = setmetatable({}, { __mode = "k" })

local function Wrap(cf)
    if not cf or wrapped[cf] or type(cf.AddMessage) ~= "function" then return false end
    local orig = cf.AddMessage
    wrapped[cf] = orig
    cf.AddMessage = function(self, text, r, g, b, ...)
        local ok, res = pcall(S.Format, text, r, g, b)
        if ok and type(res) == "string" then text = res end
        return orig(self, text, r, g, b, ...)
    end
    return true
end

function S.Unwrap(cf)
    local orig = wrapped[cf]
    if orig then cf.AddMessage = orig; wrapped[cf] = nil end
end

function S.Install()
    local n = tonumber(G.NUM_CHAT_WINDOWS) or 10
    local count = 0
    for i = 1, n do
        local cf = G["ChatFrame" .. i]
        if cf and Wrap(cf) then count = count + 1 end
    end
    return count
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function() pcall(S.Install) end)
FW:RegisterEvent("UPDATE_CHAT_WINDOWS", function() pcall(S.Install) end)

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("chat-style", {
        category = "chat",
        order = 20,
        height = 220,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATSTYLE_TITLE)
            local function Box(label, key)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return S.Opts()[key] == true end,
                    function(v) S.Opts()[key] = v and true or false end), { fit = true })
            end
            Box(L.CHATSTYLE_ENABLED, "enabled")
            Box(L.CHATSTYLE_TIME, "time")
            Box(L.CHATSTYLE_BAR, "bar")
            Box(L.CHATSTYLE_CLASS, "classColor")
            Box(L.CHATSTYLE_BRACKETS, "brackets")
            local hint = UI.CreateLabel(f, L.CHATSTYLE_HINT, { size = 11, color = "textDim" })
            stack:Add(hint, { fit = true, gap = 8 })
            return f
        end,
    })
end
