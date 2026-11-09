-- Freewood-Core: Ring-Anzeige fuer Leben und Ressource (Mana, Wut, Energie ...) neben dem Charakter (Einstellungen > Interface).
-- Die Ringe sind Abklingzeit-Frames (Cooldown) mit eigener Ring-Textur (Media\Rings\ring.tga), angehalten auf dem Prozentwert.
-- Alles ist standardmaessig AUS. Innen ein Lebensring, aussen ein Ressourcenring; optional Portrait im Inneren (runde Maske),
-- Blizzards Spielerfenster ausblenden (nur Transparenz, jederzeit umkehrbar), Verschieben per Ziehen, Groesse per Regler.
-- UNGEPRUEFT im Spiel: ob Cooldown:SetSwipeTexture / Pause / Masken auf Forever laufen und in welche Richtung der Swipe fuellt
-- (dafuer die Haken "Füllung vertauschen" und "Gegen den Uhrzeigersinn").

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local R = {}
FW.UnitRings = R

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Rings\\"
local DURATION = 1000          -- Laenge der Pseudo-Abklingzeit in Sekunden; der Prozentwert steckt im "Start"

FW:AddLocale("enUS", {
    RINGS_TITLE = "Unit rings (life and resource)",
    RINGS_NOTE = "Shows your life and your resource (mana, rage, energy ...) as rings next to the character. Everything is off by default. Drag the rings with the mouse while \"Move\" is on.",
    RINGS_ON = "Show rings",
    RINGS_HEALTH = "Life ring",
    RINGS_POWER = "Resource ring (outside the life ring)",
    RINGS_PORTRAIT = "Portrait inside the ring",
    RINGS_HIDEBLIZZ = "Hide Blizzard's player frame",
    RINGS_HIDEFULL = "Only show when not full",
    RINGS_UNLOCK = "Move (drag the rings)",
    RINGS_FLIP = "Swap fill (if the ring shows the wrong part)",
    RINGS_REVERSE = "Counter-clockwise",
    RINGS_SIZE = "Size: %d",
})
FW:AddLocale("deDE", {
    RINGS_TITLE = "Ring-Anzeige (Leben und Ressource)",
    RINGS_NOTE = "Zeigt dein Leben und deine Ressource (Mana, Wut, Energie ...) als Ringe neben dem Charakter. Alles ist standardmäßig aus. Mit \"Verschieben\" kannst du die Ringe mit der Maus ziehen.",
    RINGS_ON = "Ringe anzeigen",
    RINGS_HEALTH = "Lebensring",
    RINGS_POWER = "Ressourcenring (außen um den Lebensring)",
    RINGS_PORTRAIT = "Porträt im Ring",
    RINGS_HIDEBLIZZ = "Blizzards Spielerfenster ausblenden",
    RINGS_HIDEFULL = "Nur anzeigen, wenn nicht voll",
    RINGS_UNLOCK = "Verschieben (Ringe ziehen)",
    RINGS_FLIP = "Füllung vertauschen (falls der Ring den falschen Teil zeigt)",
    RINGS_REVERSE = "Gegen den Uhrzeigersinn",
    RINGS_SIZE = "Größe: %d",
})

local DEFAULTS = {
    on = false, health = false, power = false, portrait = false, hideBlizz = false, hideFull = false,
    unlock = false, flip = false, reverse = false, size = 120, x = 160, y = 0,
}

function R.Opts()
    local s = FW.settings
    if type(s) ~= "table" then return DEFAULTS end
    if type(s.unitRings) ~= "table" then s.unitRings = {} end
    local o = s.unitRings
    for k, v in pairs(DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end

local function Num(v)
    if v == nil then return nil end
    if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

-- Anteil 0..1 aus aktuellem und maximalem Wert
function R.Fraction(cur, max)
    cur, max = Num(cur), Num(max)
    if not cur or not max or max <= 0 then return 0 end
    local f = cur / max
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
end

-- Welcher Anteil der Pseudo-Abklingzeit schon "abgelaufen" sein muss, damit der Ring 'frac' voll aussieht.
-- Standard-Cooldown: gezeichnet wird der Rest (1 - abgelaufen). Mit Rueckwaerts-Modus (reverse) wird das Abgelaufene gezeichnet;
-- "flip" dreht die Annahme um, falls der Client es anders macht.
function R.Elapsed(frac, reverse, flip)
    local drawsElapsed = (reverse and true or false) ~= (flip and true or false)
    if drawsElapsed then return frac end
    return 1 - frac
end

local function Lerp(a, b, t) return a + (b - a) * t end

-- gruen -> orange -> rot
function R.HealthColor(frac)
    if frac >= 0.5 then
        local t = (1 - frac) / 0.5
        return Lerp(0.2, 1.0, t), Lerp(0.85, 0.55, t), Lerp(0.2, 0.1, t)
    end
    local t = (0.5 - frac) / 0.5
    return Lerp(1.0, 0.9, t), Lerp(0.55, 0.1, t), Lerp(0.1, 0.1, t)
end

local POWER_COLORS = {
    [0] = { 0.2, 0.45, 1.0 },   -- Mana
    [1] = { 1.0, 0.15, 0.15 },  -- Wut
    [2] = { 1.0, 0.5, 0.25 },   -- Fokus
    [3] = { 1.0, 0.95, 0.2 },   -- Energie
    [6] = { 0.0, 0.8, 1.0 },    -- Runenmacht
}

function R.PowerColor(ptype)
    local c = G.PowerBarColor and ptype ~= nil and G.PowerBarColor[ptype]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    c = POWER_COLORS[ptype or 0] or POWER_COLORS[0]
    return c[1], c[2], c[3]
end

-- Groessen der beiden Ringe und des Portraits (Pixel). Zwei Ringe: aussen Ressource, innen Leben.
function R.Layout(o)
    local S = o.size or 120
    local both = o.health and o.power
    local outer = S
    local inner = both and math.floor(S * 0.78 + 0.5) or S
    local portrait = math.floor(inner * 0.70 + 0.5)
    return { outer = outer, inner = inner, portrait = portrait, both = both and true or false }
end

---------------------------------------------------------------------
-- Zeichnen
---------------------------------------------------------------------

local function NewRing(parent)
    local ring = {}
    ring.frame = G.CreateFrame("Frame", nil, parent)
    ring.track = ring.frame:CreateTexture(nil, "BACKGROUND")
    ring.track:SetAllPoints(ring.frame)
    ring.track:SetTexture(PATH .. "ring.tga")
    ring.track:SetVertexColor(0.12, 0.12, 0.12, 0.7)
    local cd = G.CreateFrame("Cooldown", nil, ring.frame)
    cd:SetAllPoints(ring.frame)
    if cd.SetSwipeTexture then cd:SetSwipeTexture(PATH .. "ring.tga") end
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    ring.cd = cd
    ring.last = -1
    return ring
end

function R.SetRing(ring, frac, r, g, b, o)
    if not ring or not ring.cd then return end
    local cd = ring.cd
    if cd.SetSwipeColor then cd:SetSwipeColor(r or 1, g or 1, b or 1, 1) end
    if cd.SetReverse then cd:SetReverse(o.reverse and true or false) end
    local key = math.floor(frac * 500 + 0.5) .. (o.reverse and "r" or "n") .. (o.flip and "f" or "n")
    if key == ring.last then return end
    ring.last = key
    if frac <= 0.001 then
        if cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
        return
    end
    if frac > 0.998 then frac = 0.998 end
    local el = R.Elapsed(frac, o.reverse, o.flip)
    local now = G.GetTime and G.GetTime() or 0
    cd:SetCooldown(now - el * DURATION, DURATION)
    if cd.Pause then cd:Pause() end
end

function R.Build()
    if R.frame then return R.frame end
    local f = G.CreateFrame("Frame", "FreewoodUnitRings", G.UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f.hl = f:CreateTexture(nil, "BACKGROUND")
    f.hl:SetAllPoints(f)
    f.hl:SetColorTexture(1, 1, 1, 0.08)
    f.hl:Hide()
    f.portrait = f:CreateTexture(nil, "ARTWORK")
    f.portrait:Hide()
    if f.CreateMaskTexture and f.portrait.AddMaskTexture then
        local m = f:CreateMaskTexture()
        m:SetTexture(PATH .. "mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.portrait)
        f.portrait:AddMaskTexture(m)
        f.mask = m
    end
    R.outer = NewRing(f)
    R.inner = NewRing(f)
    f:SetScript("OnDragStart", function(self) if R.Opts().unlock then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local px, py = G.UIParent:GetCenter()
        if cx and px then
            local o = R.Opts()
            o.x, o.y = math.floor(cx - px + 0.5), math.floor(cy - py + 0.5)
        end
    end)
    f:RegisterForDrag("LeftButton")
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < 0.05 then return end
        acc = 0
        R.Update()
    end)
    R.frame = f
    return f
end

function R.UpdatePortrait()
    local f = R.frame
    local o = R.Opts()
    if not f or not o.portrait then return end
    if G.SetPortraitTexture then pcall(G.SetPortraitTexture, f.portrait, "player") end
end

function R.ApplyBlizz()
    local pf = G.PlayerFrame
    if not pf or not pf.SetAlpha then return end
    local o = R.Opts()
    if o.on and o.hideBlizz then
        if pf:GetAlpha() ~= 0 then pf:SetAlpha(0) end
        R.blizzHidden = true
    elseif R.blizzHidden then
        pf:SetAlpha(1)
        R.blizzHidden = false
    end
end

-- Groessen, Lage, Sichtbarkeit; bei jeder Einstellungsaenderung
function R.Apply()
    local o = R.Opts()
    if not o.on then
        if R.frame then R.frame:Hide() end
        R.ApplyBlizz()
        return
    end
    local f = R.Build()
    local lay = R.Layout(o)
    f:SetSize(lay.outer, lay.outer)
    f:ClearAllPoints()
    f:SetPoint("CENTER", G.UIParent, "CENTER", o.x or 0, o.y or 0)
    f:EnableMouse(o.unlock and true or false)
    if o.unlock then f.hl:Show() else f.hl:Hide() end

    -- Zuordnung: zwei Ringe -> aussen Ressource, innen Leben; ein Ring -> volle Groesse
    R.healthRing = o.health and (lay.both and R.inner or R.outer) or nil
    R.powerRing = o.power and R.outer or nil
    for _, ring in ipairs({ R.outer, R.inner }) do ring.last = -1; ring.frame:Hide() end
    if R.healthRing then
        local s = lay.both and lay.inner or lay.outer
        R.healthRing.frame:SetSize(s, s); R.healthRing.frame:ClearAllPoints(); R.healthRing.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
        R.healthRing.frame:Show()
    end
    if R.powerRing then
        R.powerRing.frame:SetSize(lay.outer, lay.outer); R.powerRing.frame:ClearAllPoints(); R.powerRing.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
        R.powerRing.frame:Show()
    end
    if o.portrait then
        f.portrait:SetSize(lay.portrait, lay.portrait)
        f.portrait:ClearAllPoints()
        f.portrait:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.portrait:Show()
        R.UpdatePortrait()
    else
        f.portrait:Hide()
    end
    f:Show()
    R.ApplyBlizz()
    R.Update()
end

local function IsSecret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) and true or false
end

-- Anteil lesen: erst cur/max; sind die Werte "secret" (im Kampf), dann die Prozent-Funktion des Spiels versuchen.
-- Rueckgabe: Anteil, Quelle ("wert", "prozent", "secret", "test")
function R.Read(kind)
    if R.force then return R.force, "test" end
    local cur, max
    if kind == "health" then
        cur = G.UnitHealth and G.UnitHealth("player"); max = G.UnitHealthMax and G.UnitHealthMax("player")
    else
        cur = G.UnitPower and G.UnitPower("player"); max = G.UnitPowerMax and G.UnitPowerMax("player")
    end
    if Num(cur) and Num(max) then return R.Fraction(cur, max), "wert" end
    local fn = kind == "health" and G.UnitHealthPercent or G.UnitPowerPercent
    if fn then
        local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
        local ok, v = pcall(fn, "player", kind ~= "health" and nil or true, scale)
        if not ok or not Num(v) then ok, v = pcall(fn, "player") end
        v = ok and Num(v) or nil
        if v then
            if v > 1.0001 then v = v / 100 end
            return R.Fraction(v, 1), "prozent"
        end
    end
    return 0, "secret"
end

function R.Update()
    local o = R.Opts()
    local f = R.frame
    if not o.on or not f then return end
    local hfrac, pfrac = 1, 1
    if R.healthRing then
        hfrac, R.hsrc = R.Read("health")
        local r, g, b = R.HealthColor(hfrac)
        R.SetRing(R.healthRing, hfrac, r, g, b, o)
    end
    if R.powerRing then
        local ptype = G.UnitPowerType and G.UnitPowerType("player")
        pfrac, R.psrc = R.Read("power")
        local r, g, b = R.PowerColor(Num(ptype))
        R.SetRing(R.powerRing, pfrac, r, g, b, o)
    end
    local full = (not R.healthRing or hfrac >= 0.999) and (not R.powerRing or pfrac >= 0.999)
    if o.hideFull and full and not o.unlock then f:SetAlpha(0) else f:SetAlpha(1) end
    R.ApplyBlizz()
end

-- Fehlersuche: /fwring debug   |   /fwring test 60  (beide Ringe auf 60 % zwingen)   |   /fwring test  (zurueck)
function R.Debug()
    local function S(v) return tostring(v) end
    local function P(t) if FW.Print then FW:Print(t) else print(t) end end
    local o = R.Opts()
    P("Ringe: an=" .. tostring(o.on) .. " Leben=" .. tostring(o.health) .. " Ressource=" .. tostring(o.power) .. " Groesse=" .. tostring(o.size))
    local f = R.frame
    if not f then P("kein Frame gebaut (Ringe aus?)"); return end
    P(string.format("Frame: sichtbar=%s alpha=%s Groesse=%s", S(f:IsShown()), S(f:GetAlpha()), S(f:GetWidth())))
    for _, kind in ipairs({ "health", "power" }) do
        local ring = kind == "health" and R.healthRing or R.powerRing
        if ring then
            local fr, src = R.Read(kind)
            local cd = ring.cd
            local a, b2
            if cd.GetCooldownTimes then a, b2 = cd:GetCooldownTimes() end
            P(string.format("%s: Anteil=%.3f Quelle=%s | SetSwipeTexture=%s Pause=%s SetSwipeColor=%s | CooldownTimes=%s/%s | Cooldown sichtbar=%s",
                kind, fr, tostring(src), tostring(cd.SetSwipeTexture ~= nil), tostring(cd.Pause ~= nil), tostring(cd.SetSwipeColor ~= nil),
                tostring(a), tostring(b2), S(cd:IsShown())))
        end
    end
    P("UnitHealth=" .. tostring(IsSecret(G.UnitHealth and G.UnitHealth("player")) and "secret" or "normal")
        .. " UnitHealthPercent=" .. tostring(G.UnitHealthPercent ~= nil) .. " CreateMaskTexture=" .. tostring(f.CreateMaskTexture ~= nil))
end

if G.SlashCmdList then
    G.SLASH_FWRING1 = "/fwring"
    G.SlashCmdList["FWRING"] = function(msg)
        msg = tostring(msg or "")
        local cmd, arg = msg:match("^(%S*)%s*(%S*)")
        if cmd == "test" then
            local v = tonumber(arg)
            R.force = v and math.max(0, math.min(1, v / 100)) or nil
            for _, ring in ipairs({ R.outer, R.inner }) do if ring then ring.last = -1 end end
            R.Update()
            if FW.Print then FW:Print(R.force and ("Ring-Test: " .. arg .. " %") or "Ring-Test aus") end
        else
            R.Debug()
        end
    end
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    local ok = pcall(R.Apply)
    if not ok and FW.Print and R.Opts().on then FW:Print("Freewood: Ring-Anzeige konnte nicht aufgebaut werden.") end
end)
FW:RegisterEvent("UNIT_PORTRAIT_UPDATE", function(unit)
    if unit == nil or unit == "player" then pcall(R.UpdatePortrait) end
end)
FW:RegisterEvent("UNIT_MODEL_CHANGED", function(unit)
    if unit == nil or unit == "player" then pcall(R.UpdatePortrait) end
end)

---------------------------------------------------------------------
-- Einstellungen
---------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("unit-rings", {
        category = "interface",
        order = 20,
        height = 470,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.RINGS_TITLE)
            stack:Add(UI.CreateLabel(f, L.RINGS_NOTE, { size = 11, color = "textDim", justifyV = "TOP" }), { fit = true, gap = 8 })
            local function Check(key, label)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return R.Opts()[key] == true end,
                    function(v) R.Opts()[key] = v and true or false; pcall(R.Apply) end), { fit = true, gap = 4 })
            end
            Check("on", L.RINGS_ON)
            Check("health", L.RINGS_HEALTH)
            Check("power", L.RINGS_POWER)
            Check("portrait", L.RINGS_PORTRAIT)
            Check("hideBlizz", L.RINGS_HIDEBLIZZ)
            Check("hideFull", L.RINGS_HIDEFULL)
            Check("unlock", L.RINGS_UNLOCK)
            Check("flip", L.RINGS_FLIP)
            Check("reverse", L.RINGS_REVERSE)
            local lab = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(lab, { height = 16, gap = 8 })
            local sl = UI.CreateSlider(f, 240, {
                min = 60, max = 300, step = 5,
                get = function() return R.Opts().size end,
                set = function(v) R.Opts().size = v; pcall(R.Apply) end,
            })
            sl.onText = function(v) lab:SetText(string.format(L.RINGS_SIZE, v)) end
            sl:Refresh()
            stack:Add(sl, { height = 20, gap = 2 })
            return f
        end,
    })
end
