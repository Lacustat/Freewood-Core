-- Freewood-Core: Ring-Anzeige fuer Leben und Ressourcen neben dem Charakter (Einstellungen > Interface).
-- Ebenen von aussen nach innen: 1 Mana-Ring (nur Druide in Katzen-/Baerengestalt), 2 Ressourcenring (Mana, Wut, Energie ...),
-- 3 Lebensring, 4 Portrait (runde Maske). Jeder Ring ist ein einzelner Kreis mit eigener Dicke, Richtung und eigenem Haken.
-- Alles ist standardmaessig AUS. Blizzards Spielerfenster ausblenden (nur Transparenz), Verschieben per Ziehen, Groesse per Regler.
-- Zeichnen: sind die Werte lesbar, ein Cooldown-Frame mit Ring-Textur (Media\Rings\ring<stufe>.tga), angehalten auf dem Prozentwert.
-- Sind die Werte "secret" (Spieler auf Forever), nimmt ein Ring aus 64 Statusleisten ihren Platz (siehe Segment-Ring).
-- UNGEPRUEFT im Spiel: Druiden-Mana-Ring, Richtung je Ring, die Richtung des Swipes (Haken "Füllung vertauschen").

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local R = {}
FW.UnitRings = R

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Rings\\"
local DURATION = 1000          -- Laenge der Pseudo-Abklingzeit in Sekunden; der Prozentwert steckt im "Start"

FW:AddLocale("enUS", {
    RINGS_TITLE = "Unit rings (life and resources)",
    RINGS_NOTE = "Shows your life and your resources as rings next to the character. Layers from the outside in: 1 druid mana (only in cat or bear form), 2 resource (mana, rage, energy ...), 3 life, 4 portrait. Everything is off by default. Drag the rings with the mouse while \"Move\" is on.",
    RINGS_ON = "Show rings",
    RINGS_DMANA = "Layer 1: druid mana ring (only in cat or bear form)",
    RINGS_POWER = "Layer 2: resource ring (mana, rage, energy ...)",
    RINGS_HEALTH = "Layer 3: life ring",
    RINGS_PORTRAIT = "Layer 4: portrait inside the rings",
    RINGS_DMANA_REV = "Druid mana ring counter-clockwise",
    RINGS_POWER_REV = "Resource ring counter-clockwise",
    RINGS_HEALTH_REV = "Life ring counter-clockwise",
    RINGS_HIDEBLIZZ = "Hide Blizzard's player frame",
    RINGS_HIDEFULL = "Only show when not full",
    RINGS_UNLOCK = "Move (drag the rings)",
    RINGS_FLIP = "Swap fill (if a smooth ring shows the wrong part)",
    RINGS_SIZE = "Size: %d",
    RINGS_DMANA_THICK = "Druid mana ring thickness: %d",
    RINGS_POWER_THICK = "Resource ring thickness: %d",
    RINGS_HEALTH_THICK = "Life ring thickness: %d",
})
FW:AddLocale("deDE", {
    RINGS_TITLE = "Ring-Anzeige (Leben und Ressourcen)",
    RINGS_NOTE = "Zeigt dein Leben und deine Ressourcen als Ringe neben dem Charakter. Ebenen von außen nach innen: 1 Druiden-Mana (nur in Katzen- oder Bärengestalt), 2 Ressource (Mana, Wut, Energie ...), 3 Leben, 4 Porträt. Alles ist standardmäßig aus. Mit \"Verschieben\" kannst du die Ringe mit der Maus ziehen.",
    RINGS_ON = "Ringe anzeigen",
    RINGS_DMANA = "Ebene 1: Druiden-Mana-Ring (nur in Katzen- oder Bärengestalt)",
    RINGS_POWER = "Ebene 2: Ressourcenring (Mana, Wut, Energie ...)",
    RINGS_HEALTH = "Ebene 3: Lebensring",
    RINGS_PORTRAIT = "Ebene 4: Porträt in den Ringen",
    RINGS_DMANA_REV = "Druiden-Mana-Ring gegen den Uhrzeigersinn",
    RINGS_POWER_REV = "Ressourcenring gegen den Uhrzeigersinn",
    RINGS_HEALTH_REV = "Lebensring gegen den Uhrzeigersinn",
    RINGS_HIDEBLIZZ = "Blizzards Spielerfenster ausblenden",
    RINGS_HIDEFULL = "Nur anzeigen, wenn nicht voll",
    RINGS_UNLOCK = "Verschieben (Ringe ziehen)",
    RINGS_FLIP = "Füllung vertauschen (falls ein glatter Ring den falschen Teil zeigt)",
    RINGS_SIZE = "Größe: %d",
    RINGS_DMANA_THICK = "Dicke Druiden-Mana-Ring: %d",
    RINGS_POWER_THICK = "Dicke Ressourcenring: %d",
    RINGS_HEALTH_THICK = "Dicke Lebensring: %d",
})

local DEFAULTS = {
    on = false, dmana = false, power = false, health = false, portrait = false, hideBlizz = false, hideFull = false,
    unlock = false, flip = false, size = 120, x = 160, y = 0,
    dmanaThick = 3, powerThick = 3, healthThick = 3,   -- Dicke je Ring, Stufe 1 (duenn) bis 6 (dick); 3 = bisheriges Aussehen
    dmanaRev = false, powerRev = false, healthRev = false,   -- true = gegen den Uhrzeigersinn
}

-- Ebenen von aussen nach innen
R.ORDER = { "dmana", "power", "health" }

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

local function IsSecret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) and true or false
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

---------------------------------------------------------------------
-- Druide und Ebenen
---------------------------------------------------------------------

function R.IsDruid()
    if R.druid == nil then
        local _, token = nil, nil
        if G.UnitClassBase then token = G.UnitClassBase("player")
        elseif G.UnitClass then _, token = G.UnitClass("player") end
        if token == nil then return false end   -- noch nicht bekannt: spaeter nochmal fragen
        R.druid = (token == "DRUID")
    end
    return R.druid
end

-- Druide in Katzen-/Baerengestalt: die Hauptressource ist nicht Mana, das Mana soll trotzdem zu sehen sein
function R.DruidManaActive()
    if not R.IsDruid() then return false end
    local pt = G.UnitPowerType and Num((G.UnitPowerType("player")))
    return pt ~= nil and pt ~= 0
end

-- Eingeschaltete Ebenen von aussen nach innen (die Druiden-Ebene nur fuer Druiden; ihr Platz bleibt auch ausserhalb der Gestalt frei)
function R.Slots(o)
    local list = {}
    for _, key in ipairs(R.ORDER) do
        if o[key] and (key ~= "dmana" or R.IsDruid()) then list[#list + 1] = key end
    end
    return list
end

-- Groessen der Ringe und des Portraits (Pixel). Der aeusserste Ring hat die volle Groesse, jeder naechste liegt innerhalb der
-- Dicke des Vorgaengers (plus kleiner Abstand), das Portrait innerhalb des innersten Rings.
function R.Layout(o)
    local S = o.size or 120
    local lay = { outer = S, diam = {}, slots = R.Slots(o) }
    local d, lastThick = S, 0.16
    for i, key in ipairs(lay.slots) do
        if i > 1 then
            local prev = lay.slots[i - 1]
            d = math.floor(lay.diam[prev] * (1 - R.Thickness(o[prev .. "Thick"]) - 0.05) + 0.5)
        end
        lay.diam[key] = d
        lastThick = R.Thickness(o[key .. "Thick"])
    end
    lay.portrait = math.floor(d * (1 - lastThick - 0.06) + 0.5)
    return lay
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

-- Versteckte Statusleiste als Messgeraet: SetValue/SetMinMaxValues nehmen auch "secret"-Werte an; die Breite der Fuellung ist
-- dann (vermutlich) eine normale Zahl. Auf Forever liefert das nil; bleibt als Versuch.
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

-- Rohwerte (aktuell, maximal) einer Ebene
local function RawValues(kind)
    if kind == "health" then
        return G.UnitHealth and G.UnitHealth("player"), G.UnitHealthMax and G.UnitHealthMax("player")
    elseif kind == "dmana" then
        return G.UnitPower and G.UnitPower("player", 0), G.UnitPowerMax and G.UnitPowerMax("player", 0)
    end
    return G.UnitPower and G.UnitPower("player"), G.UnitPowerMax and G.UnitPowerMax("player")
end

-- Anteil lesen: erst cur/max; sind die Werte "secret" (Spieler auf Forever), dann die Prozent-Funktion, dann das Messgeraet.
-- Rueckgabe: Anteil, Quelle ("wert", "prozent", "balken", "secret", "test")
function R.Read(kind)
    if R.force then return R.force, "test" end
    local cur, max = RawValues(kind)
    if Num(cur) and Num(max) then return R.Fraction(cur, max), "wert" end
    local fn = kind == "health" and G.UnitHealthPercent or G.UnitPowerPercent
    if fn then
        local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
        local ok, v = pcall(fn, "player", false, scale)
        if kind ~= "health" then ok, v = pcall(fn, "player", kind == "dmana" and 0 or nil, false, scale) end
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

---------------------------------------------------------------------
-- Segment-Ring fuer "secret"-Werte: 64 kleine Statusleisten, jede mit einem Stueck des Rings und eigenem Wertebereich.
-- Statusleisten nehmen secret-Werte an und schneiden die Fuellung selbst zu, ganz ohne Rechnen im Addon.
---------------------------------------------------------------------

-- Anzahl der Stuecke steht in Media\Rings\Segments.lua (muss vor dieser Datei geladen sein)
R.SEG_N = FW.RingSegments and FW.RingSegments[1] and #FW.RingSegments[1] or 32

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
        local orient = R.SegDirection(k)
        sb:SetOrientation(orient)
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

-- Segmente ein/aus; Wertebereich je Segment (im Uhrzeigersinn): [ (k-1)/n, k/n ] * pmax; gegen den Uhrzeigersinn
-- werden die Bereiche gespiegelt und die Fuellrichtung jedes Stuecks umgedreht.
function R.SegMode(ring, on, pmax, ccw)
    if on then
        if not R.BuildSegs(ring) then return false end
        local key = tostring(pmax) .. (ccw and "c" or "n")
        if ring.segKey ~= key then
            ring.segKey = key
            local n = R.SEG_N
            for k, sb in ipairs(ring.segs) do
                local j = ccw and (n - k + 1) or k
                sb:SetMinMaxValues((j - 1) / n * pmax, j / n * pmax)
                if sb.SetReverseFill then
                    local _, rev = R.SegDirection(k)
                    if ccw then rev = not rev end
                    sb:SetReverseFill(rev)
                end
            end
        end
        if ring.layKey ~= (ring.size or 100) .. ":" .. (ring.level or 3) then R.LayoutSegs(ring, ring.size or 100) end
        if not ring.segOn then
            for _, sb in ipairs(ring.segs) do sb:Show() end
            ring.cd:Hide()
            ring.segOn = true
        end
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
    if kind == "health" then ok, v = pcall(fn, "player", false, scale)
    else ok, v = pcall(fn, "player", kind == "dmana" and 0 or nil, false, scale) end
    if not ok or v == nil then return nil end
    return v, scale and 100 or 1
end

function R.FeedSegs(ring, kind, r, g, b, ccw)
    local v, pmax = R.SecretPercent(kind)
    if v == nil then return false end
    if not R.SegMode(ring, true, pmax, ccw) then return false end
    for _, sb in ipairs(ring.segs) do
        pcall(sb.SetValue, sb, v)
        if r then sb:SetStatusBarColor(r, g, b) end
    end
    return true
end

function R.SetRing(ring, frac, r, g, b, o, ccw)
    if not ring or not ring.cd then return end
    local cd = ring.cd
    if cd.SetSwipeColor then cd:SetSwipeColor(r or 1, g or 1, b or 1, 1) end
    if cd.SetReverse then cd:SetReverse(ccw and true or false) end
    local key = math.floor(frac * 500 + 0.5) .. (ccw and "r" or "n") .. (o.flip and "f" or "n")
    if key == ring.last then return end
    ring.last = key
    if frac <= 0.001 then
        if cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
        return
    end
    if frac > 0.998 then frac = 0.998 end
    local el = R.Elapsed(frac, ccw, o.flip)
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
    R.rings = {}
    for _, key in ipairs(R.ORDER) do R.rings[key] = NewRing(f) end
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

    for _, key in ipairs(R.ORDER) do
        local ring = R.rings[key]
        ring.segKey = nil
        ring.last = -1
        ring.frame:Hide()
    end
    R.active = lay.slots
    for _, key in ipairs(lay.slots) do
        local ring = R.rings[key]
        local s = lay.diam[key]
        R.SetLevel(ring, o[key .. "Thick"])
        ring.size = s
        ring.frame:SetSize(s, s)
        ring.frame:ClearAllPoints()
        ring.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
        ring.frame:Show()
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

-- Farbe einer Ebene (bei lesbarem Anteil frac)
local function RingColor(key, frac)
    if key == "health" then return R.HealthColor(frac) end
    if key == "dmana" then return R.PowerColor(0) end
    local pt = G.UnitPowerType and Num((G.UnitPowerType("player")))
    return R.PowerColor(pt)
end

function R.Update()
    local o = R.Opts()
    local f = R.frame
    if not o.on or not f then return end
    -- ein Druide wird erst nach dem Anmelden erkannt: dann Ebenen neu aufbauen
    if R.IsDruid() ~= R.layoutDruid then
        R.layoutDruid = R.IsDruid()
        if o.dmana then R.Apply(); return end
    end
    local allFull, any = true, false
    R.src = R.src or {}
    for _, key in ipairs(R.active or {}) do
        local ring = R.rings[key]
        local show = key ~= "dmana" or R.DruidManaActive()
        if not show then
            ring.frame:Hide()
        else
            ring.frame:Show()
            local ccw = o[key .. "Rev"] and true or false
            local frac, src = R.Read(key)
            R.src[key] = src
            local r, g, b = RingColor(key, frac)
            if src == "secret" and R.FeedSegs(ring, key, key == "health" and 0.2 or r, key == "health" and 0.85 or g, key == "health" and 0.2 or b, ccw) then
                frac = 0.5   -- Wert unbekannt: gilt als "nicht voll"
            else
                R.SegMode(ring, false)
                R.SetRing(ring, frac, r, g, b, o, ccw)
            end
            any = true
            if frac < 0.999 then allFull = false end
        end
    end
    local full = any and allFull
    if o.hideFull and full and not o.unlock then f:SetAlpha(0) else f:SetAlpha(1) end
    R.ApplyBlizz()
end

-- Fehlersuche: /fwring debug   |   /fwring test 60  (alle Ringe auf 60 % zwingen)   |   /fwring test  (zurueck)
function R.Debug()
    local function S(v) return tostring(v) end
    local function P(t) if FW.Print then FW:Print(t) else print(t) end end
    local o = R.Opts()
    P("Ringe: an=" .. S(o.on) .. " Druide=" .. S(R.IsDruid()) .. " Mana-Ring=" .. S(o.dmana) .. " Ressource=" .. S(o.power) .. " Leben=" .. S(o.health) .. " Groesse=" .. S(o.size))
    local f = R.frame
    if not f then P("kein Frame gebaut (Ringe aus?)"); return end
    P(string.format("Frame: sichtbar=%s alpha=%s Groesse=%s", S(f:IsShown()), S(f:GetAlpha()), S(f:GetWidth())))
    for _, key in ipairs(R.active or {}) do
        local ring = R.rings[key]
        local fr, src = R.Read(key)
        local cd = ring.cd
        local a, b2
        if cd.GetCooldownTimes then a, b2 = cd:GetCooldownTimes() end
        local nseg, nshown = 0, 0
        if ring.segs then for _, sb in ipairs(ring.segs) do nseg = nseg + 1; if sb:IsShown() then nshown = nshown + 1 end end end
        P(string.format("%s: Anteil=%.3f Quelle=%s Stufe=%s Groesse=%s | Segmente=%d (sichtbar %d, an=%s) | Swipe=%s Pause=%s | CooldownTimes=%s/%s",
            key, fr, S(src), S(ring.level), S(ring.size), nseg, nshown, S(ring.segOn), S(cd.SetSwipeTexture ~= nil), S(cd.Pause ~= nil), S(a), S(b2)))
    end
    do
        local fn = G.UnitHealthPercent
        local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
        local ok, v = false, nil
        if fn then ok, v = pcall(fn, "player", false, scale) end
        P("Prozent-Funktion: ok=" .. S(ok) .. " Ergebnis=" .. (IsSecret(v) and "secret" or S(type(v) == "number" and v or type(v))) .. " | ScaleTo100=" .. S(scale ~= nil))
    end
    P("UnitHealth=" .. (IsSecret(G.UnitHealth and G.UnitHealth("player")) and "secret" or "normal")
        .. " UnitHealthPercent=" .. S(G.UnitHealthPercent ~= nil) .. " CreateMaskTexture=" .. S(f.CreateMaskTexture ~= nil))
end

if G.SlashCmdList then
    G.SLASH_FWRING1 = "/fwring"
    G.SlashCmdList["FWRING"] = function(msg)
        msg = tostring(msg or "")
        local cmd, arg = msg:match("^(%S*)%s*(%S*)")
        if cmd == "test" then
            local v = tonumber(arg)
            R.force = v and math.max(0, math.min(1, v / 100)) or nil
            for _, ring in pairs(R.rings or {}) do ring.last = -1 end
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
        height = 800,
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
            Check("dmana", L.RINGS_DMANA)
            Check("power", L.RINGS_POWER)
            Check("health", L.RINGS_HEALTH)
            Check("portrait", L.RINGS_PORTRAIT)
            Check("dmanaRev", L.RINGS_DMANA_REV)
            Check("powerRev", L.RINGS_POWER_REV)
            Check("healthRev", L.RINGS_HEALTH_REV)
            Check("hideBlizz", L.RINGS_HIDEBLIZZ)
            Check("hideFull", L.RINGS_HIDEFULL)
            Check("unlock", L.RINGS_UNLOCK)
            Check("flip", L.RINGS_FLIP)
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
            Slider("dmanaThick", L.RINGS_DMANA_THICK, 1, R.LEVELS, 1)
            Slider("powerThick", L.RINGS_POWER_THICK, 1, R.LEVELS, 1)
            Slider("healthThick", L.RINGS_HEALTH_THICK, 1, R.LEVELS, 1)
            return f
        end,
    })
end
