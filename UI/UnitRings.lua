-- Freewood-Core: Ring-Anzeige fuer Leben und Ressource (Mana, Wut, Energie ...) neben dem Charakter (Einstellungen > Interface).
-- Die Ringe sind Abklingzeit-Frames (Cooldown) mit eigener Ring-Textur (Media\Rings\ring<stufe>.tga), angehalten auf dem Prozentwert.
-- Alles ist standardmaessig AUS. Innen ein Lebensring, aussen ein Ressourcenring; optional Portrait im Inneren (runde Maske),
-- Blizzards Spielerfenster ausblenden (nur Transparenz, jederzeit umkehrbar), Verschieben per Ziehen, Groesse per Regler.
-- Sind die Werte "secret" (Spieler auf Forever), nimmt ein Ring aus 32 Statusleisten ihren Platz (siehe Segment-Ring).
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
    RINGS_HEALTH_THICK = "Life ring thickness: %d",
    RINGS_POWER_THICK = "Resource ring thickness: %d",
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
    RINGS_HEALTH_THICK = "Dicke Lebensring: %d",
    RINGS_POWER_THICK = "Dicke Ressourcenring: %d",
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
    healthThick = 3, powerThick = 3,   -- Dicke je Ring, Stufe 1 (duenn) bis 6 (dick); 3 = bisheriges Aussehen
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

R.LEVELS = 6

function R.Level(v)
    v = math.floor((tonumber(v) or 3) + 0.5)
    if v < 1 then v = 1 elseif v > R.LEVELS then v = R.LEVELS end
    return v
end

-- Dicke eines Rings als Anteil am Radius (aus Media\Rings\Segments.lua)
function R.Thickness(level)
    local t = FW.RingThickness
    return t and t[R.Level(level)] or 0.16
end

-- Groessen der beiden Ringe und des Portraits (Pixel). Zwei Ringe: aussen Ressource, innen Leben; der innere Ring liegt
-- innerhalb der Dicke des aeusseren (plus kleiner Abstand), das Portrait innerhalb des innersten Rings.
function R.Layout(o)
    local S = o.size or 120
    local both = o.health and o.power
    local outer = S
    local inner = S
    local innerThick
    if both then
        inner = math.floor(S * (1 - R.Thickness(o.powerThick) - 0.05) + 0.5)
        innerThick = R.Thickness(o.healthThick)
    elseif o.health then
        innerThick = R.Thickness(o.healthThick)
    elseif o.power then
        innerThick = R.Thickness(o.powerThick)
    else
        innerThick = 0.16
    end
    local portrait = math.floor(inner * (1 - innerThick - 0.06) + 0.5)
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
    ring.track:SetTexture(PATH .. "ring3.tga")
    ring.track:SetVertexColor(0.12, 0.12, 0.12, 0.7)
    local cd = G.CreateFrame("Cooldown", nil, ring.frame)
    cd:SetAllPoints(ring.frame)
    if cd.SetSwipeTexture then cd:SetSwipeTexture(PATH .. "ring3.tga") end
    ring.level = 3
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    ring.cd = cd
    ring.last = -1
    return ring
end

---------------------------------------------------------------------
-- Segment-Ring fuer "secret"-Werte: 32 kleine Statusleisten, jede mit einem Stueck des Rings und eigenem Wertebereich.
-- Statusleisten nehmen secret-Werte an und schneiden die Fuellung selbst zu, ganz ohne Rechnen im Addon.
---------------------------------------------------------------------

R.SEG_N = 32

-- Fuellrichtung eines Segments (im Uhrzeigersinn ab 12 Uhr): orientation, reverse
function R.SegDirection(k, n)
    n = n or R.SEG_N
    local th = ((k - 0.5) / n) * 2 * math.pi
    local dx, dy = math.cos(th), -math.sin(th)   -- Laufrichtung im Uhrzeigersinn (x rechts, y oben)
    if math.abs(dx) >= math.abs(dy) then
        return "HORIZONTAL", dx < 0
    end
    return "VERTICAL", dy < 0
end

function R.BuildSegs(ring)
    if ring.segs then return ring.segs end
    if not FW.RingSegments or not G.CreateFrame then return nil end
    ring.segs = {}
    for k = 1, R.SEG_N do
        local sb = G.CreateFrame("StatusBar", nil, ring.frame)
        sb:SetStatusBarTexture(string.format("%sseg%d_%02d.tga", PATH, ring.level or 3, k))
        local orient, rev = R.SegDirection(k)
        sb:SetOrientation(orient)
        if sb.SetReverseFill then sb:SetReverseFill(rev) end
        sb:Hide()
        ring.segs[k] = sb
    end
    return ring.segs
end

function R.LayoutSegs(ring, size)
    local info = FW.RingSegments and FW.RingSegments[ring.level or 3]
    if not ring.segs or not info then return end
    local f = size / (FW.RingSegmentSize or 256)
    for k, sb in ipairs(ring.segs) do
        local d = info[k]
        if d then
            sb:SetSize(d[3] * f, d[4] * f)
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", d[1] * f, -d[2] * f)
        end
    end
    ring.layKey = size .. ":" .. (ring.level or 3)
end

-- Dicke eines Rings umstellen: Hintergrund-, Swipe- und Segment-Bilder tauschen
function R.SetLevel(ring, level)
    level = R.Level(level)
    if ring.level == level then return end
    ring.level = level
    ring.last = -1
    ring.track:SetTexture(PATH .. "ring" .. level .. ".tga")
    if ring.cd.SetSwipeTexture then ring.cd:SetSwipeTexture(PATH .. "ring" .. level .. ".tga") end
    if ring.segs then
        for k, sb in ipairs(ring.segs) do sb:SetStatusBarTexture(string.format("%sseg%d_%02d.tga", PATH, level, k)) end
        R.LayoutSegs(ring, ring.size or 100)
    end
end

-- Segmente ein/aus; Wertebereich je Segment: [ (k-1)/n, k/n ] * pmax
function R.SegMode(ring, on, pmax)
    if on then
        if not R.BuildSegs(ring) then return false end
        if ring.segMax ~= pmax then
            ring.segMax = pmax
            for k, sb in ipairs(ring.segs) do
                sb:SetMinMaxValues((k - 1) / R.SEG_N * pmax, k / R.SEG_N * pmax)
            end
        end
        if ring.layKey ~= (ring.size or 100) .. ":" .. (ring.level or 3) then R.LayoutSegs(ring, ring.size or 100) end
        for _, sb in ipairs(ring.segs) do sb:Show() end
        ring.cd:Hide()
        ring.segOn = true
    elseif ring.segOn then
        for _, sb in ipairs(ring.segs) do sb:Hide() end
        ring.cd:Show()
        ring.segOn = false
        ring.last = -1
    end
    return true
end

-- secret-Prozentwert holen (nur an Statusleisten weiterreichen, nicht rechnen!). Rueckgabe: Wert, Maximum der Skala
function R.SecretPercent(kind)
    local fn = kind == "health" and G.UnitHealthPercent or G.UnitPowerPercent
    if not fn then return nil end
    local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
    local ok, v
    if kind == "health" then ok, v = pcall(fn, "player", false, scale) else ok, v = pcall(fn, "player", nil, false, scale) end
    if not ok or v == nil then return nil end
    return v, scale and 100 or 1
end

function R.FeedSegs(ring, kind, r, g, b)
    local v, pmax = R.SecretPercent(kind)
    if v == nil then return false end
    if not R.SegMode(ring, true, pmax) then return false end
    for _, sb in ipairs(ring.segs) do
        pcall(sb.SetValue, sb, v)
        if r then sb:SetStatusBarColor(r, g, b) end
    end
    return true
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
    if R.healthRing then R.SetLevel(R.healthRing, o.healthThick) end
    if R.powerRing then R.SetLevel(R.powerRing, o.powerThick) end
    for _, ring in ipairs({ R.outer, R.inner }) do ring.last = -1; ring.segMax = nil; ring.frame:Hide() end
    if R.healthRing then
        local s = lay.both and lay.inner or lay.outer
        R.healthRing.size = s; R.healthRing.frame:SetSize(s, s); R.healthRing.frame:ClearAllPoints(); R.healthRing.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
        R.healthRing.frame:Show()
    end
    if R.powerRing then
        R.powerRing.size = lay.outer; R.powerRing.frame:SetSize(lay.outer, lay.outer); R.powerRing.frame:ClearAllPoints(); R.powerRing.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
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

-- Versteckte Statusleiste als Messgeraet: SetValue/SetMinMaxValues nehmen auch "secret"-Werte an; die Breite der Fuellung ist
-- dann (vermutlich) eine normale Zahl. UNGEPRUEFT: ob das Spiel die Breite freigibt.
local BAR_W = 1000
local function Gauge(key)
    R.gauges = R.gauges or {}
    local g = R.gauges[key]
    if g then return g end
    if not G.CreateFrame then return nil end
    local ok, sb = pcall(G.CreateFrame, "StatusBar", nil, G.UIParent)
    if not ok or not sb then return nil end
    sb:SetSize(BAR_W, 10)
    sb:SetPoint("TOPLEFT", G.UIParent, "TOPLEFT", -5000, 0)
    sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    g = sb
    R.gauges[key] = g
    return g
end

local function GaugeRead(key, cur, max)
    local sb = Gauge(key)
    if not sb then return nil end
    local ok = pcall(function() sb:SetMinMaxValues(0, max); sb:SetValue(cur) end)
    if not ok then return nil end
    local tex = sb.GetStatusBarTexture and sb:GetStatusBarTexture()
    if not tex then return nil end
    local ok2, w = pcall(tex.GetWidth, tex)
    w = ok2 and Num(w) or nil
    if not w then return nil end
    return R.Fraction(w, BAR_W)
end

-- Anteil lesen: erst cur/max; sind die Werte "secret" (im Kampf), dann die Prozent-Funktion des Spiels, dann das Messgeraet.
-- Rueckgabe: Anteil, Quelle ("wert", "prozent", "balken", "secret", "test")
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
        local ok, v = pcall(fn, "player", false, scale)
        if not ok or not Num(v) then ok, v = pcall(fn, "player") end
        v = ok and Num(v) or nil
        if v then
            if v > 1.0001 then v = v / 100 end
            return R.Fraction(v, 1), "prozent"
        end
    end
    if cur ~= nil and max ~= nil then
        local f = GaugeRead(kind, cur, max)
        if f then return f, "balken" end
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
        if R.hsrc == "secret" and R.FeedSegs(R.healthRing, "health", 0.2, 0.85, 0.2) then
            hfrac = 0.5
        else
            R.SegMode(R.healthRing, false)
            R.SetRing(R.healthRing, hfrac, r, g, b, o)
        end
    end
    if R.powerRing then
        local ptype = G.UnitPowerType and G.UnitPowerType("player")
        pfrac, R.psrc = R.Read("power")
        local r, g, b = R.PowerColor(Num(ptype))
        if R.psrc == "secret" and R.FeedSegs(R.powerRing, "power", r, g, b) then
            pfrac = 0.5
        else
            R.SegMode(R.powerRing, false)
            R.SetRing(R.powerRing, pfrac, r, g, b, o)
        end
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
    do
        local fn = G.UnitHealthPercent
        local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
        local ok, v = false, nil
        if fn then ok, v = pcall(fn, "player", false, scale) end
        local hp, hm = G.UnitHealth and G.UnitHealth("player"), G.UnitHealthMax and G.UnitHealthMax("player")
        local gauge = (hp ~= nil and hm ~= nil) and GaugeRead("health", hp, hm) or nil
        P("Prozent-Funktion: ok=" .. S(ok) .. " Ergebnis=" .. (IsSecret(v) and "secret" or S(type(v) == "number" and v or type(v)))
            .. " | Messgeraet (Statusleiste): " .. S(gauge) .. " | ScaleTo100=" .. S(scale ~= nil))
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
        height = 560,
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
            local function Slider(key, label, lo, hi, step)
                local lab = UI.CreateLabel(f, "", { size = 12 })
                stack:Add(lab, { height = 16, gap = 8 })
                local sl = UI.CreateSlider(f, 240, {
                    min = lo, max = hi, step = step,
                    get = function() return R.Opts()[key] end,
                    set = function(v) R.Opts()[key] = v; pcall(R.Apply) end,
                })
                sl.onText = function(v) lab:SetText(string.format(label, v)) end
                sl:Refresh()
                stack:Add(sl, { height = 20, gap = 2 })
            end
            Slider("size", L.RINGS_SIZE, 60, 300, 5)
            Slider("healthThick", L.RINGS_HEALTH_THICK, 1, R.LEVELS, 1)
            Slider("powerThick", L.RINGS_POWER_THICK, 1, R.LEVELS, 1)
            return f
        end,
    })
end
