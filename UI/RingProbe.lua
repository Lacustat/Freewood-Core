-- Freewood-Core: Probe fuer geheime Werte (secret values). /fwprobe testet im Spiel, welche Abfragen die Lebenswerte des Spielers
-- freigeben (lesbare Zahl) und was man mit einem geheimen Wert anfangen darf. Ausgabe im Chat und unter FW.settings.ringProbe
-- (nach /reload in WTF\Account\<KONTO>\SavedVariables\ zu finden). Aendert nichts am Spiel.

local ADDON, FW = ...

local G = _G
local P = {}
FW.RingProbe = P

local function Secret(v)
    local fn = G.issecretvalue
    if type(fn) ~= "function" then return false end
    local ok, r = pcall(fn, v)
    return ok and r and true or false
end

-- kurze Beschreibung eines Werts: Typ, geheim ja/nein, bei lesbaren Werten der Wert selbst
function P.Desc(v)
    if v == nil then return "nil" end
    local t = type(v)
    if Secret(v) then return t .. " GEHEIM" end
    if t == "number" or t == "boolean" then return t .. " " .. tostring(v) end
    if t == "string" then return "string '" .. v .. "'" end
    return t
end

-- Was darf man mit einem Wert tun? ok / Fehler je Rechenart
function P.Ops(v)
    local function T(f)
        local ok, r = pcall(f)
        if not ok then return "FEHLER" end
        if Secret(r) then return "ok(geheim)" end
        return "ok(" .. tostring(r) .. ")"
    end
    return string.format("+0:%s  >0:%s  tonumber:%s  floor:%s  format%%d:%s  tostring:%s",
        T(function() return v + 0 end), T(function() return v > 0 end), T(function() return tonumber(v) end),
        T(function() return math.floor(v) end), T(function() return string.format("%d", v) end), T(function() return tostring(v) end))
end

function P.Run(out)
    local lines = {}
    local function L(t) lines[#lines + 1] = t; if out then out(t) end end
    local function Try(name, f)
        local ok, a, b, c = pcall(f)
        if not ok then L(name .. ": FEHLER " .. tostring(a)) return end
        L(name .. ": " .. P.Desc(a) .. (b ~= nil and (" | " .. P.Desc(b)) or "") .. (c ~= nil and (" | " .. P.Desc(c)) or ""))
    end

    L("== Ring-Probe (secret values) ==")
    L("Lage: Kampf=" .. tostring(G.InCombatLockdown and G.InCombatLockdown()) .. " Instanz=" .. tostring(G.IsInInstance and select(2, G.IsInInstance()))
        .. " issecretvalue=" .. tostring(type(G.issecretvalue)) .. " C_Secrets=" .. tostring(type(G.C_Secrets)))

    -- A: Einheiten
    L("-- A: UnitHealth je Einheit")
    for _, unit in ipairs({ "player", "pet", "target", "party1" }) do
        if G.UnitExists and G.UnitExists(unit) then
            local ok, h, m = pcall(function() return G.UnitHealth(unit), G.UnitHealthMax(unit) end)
            if ok then L(unit .. ": Health=" .. P.Desc(h) .. " Max=" .. P.Desc(m)) else L(unit .. ": FEHLER") end
        end
    end
    local hp = G.UnitHealth and G.UnitHealth("player")
    local hm = G.UnitHealthMax and G.UnitHealthMax("player")
    L("Rechenarten Health: " .. P.Ops(hp))
    L("Rechenarten Max:    " .. P.Ops(hm))
    Try("UnitHealthMissing", function() return G.UnitHealthMissing("player") end)
    Try("UnitPower(player)", function() return G.UnitPower("player"), G.UnitPowerMax("player") end)
    Try("UnitPower(Mana)", function() return G.UnitPower("player", 0), G.UnitPowerMax("player", 0) end)

    -- B: Prozent-Funktion
    L("-- B: UnitHealthPercent")
    local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
    Try("Percent(player)", function() return G.UnitHealthPercent("player") end)
    Try("Percent(player,false)", function() return G.UnitHealthPercent("player", false) end)
    Try("Percent(player,true)", function() return G.UnitHealthPercent("player", true) end)
    Try("Percent(player,false,ScaleTo100)", function() return G.UnitHealthPercent("player", false, scale) end)
    local pv = nil
    pcall(function() pv = G.UnitHealthPercent("player", false, scale) end)
    if pv ~= nil then L("Rechenarten Percent: " .. P.Ops(pv)) end
    Try("PowerPercent(player)", function() return G.UnitPowerPercent("player") end)

    -- C: Blizzards Spielerfenster
    L("-- C: Blizzard-Spielerfenster")
    local bar = G.PlayerFrameHealthBar or (G.PlayerFrame and G.PlayerFrame.healthbar)
    if not bar and G.PlayerFrame and G.PlayerFrame.PlayerFrameContent then
        local c = G.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        bar = c and c.HealthBarsContainer and c.HealthBarsContainer.HealthBar
    end
    if bar then
        Try("Leiste GetValue", function() return bar:GetValue() end)
        Try("Leiste GetMinMaxValues", function() return bar:GetMinMaxValues() end)
        local fs = bar.TextString or bar.text or bar.LeftText
        if fs and fs.GetText then Try("Leiste Text", function() return fs:GetText() end) end
        Try("Leiste Fuellbreite", function() return bar:GetStatusBarTexture():GetWidth() end)
    else
        L("Spielerfenster-Leiste nicht gefunden")
    end

    -- D: Messgeraet (eigene Statusleiste)
    L("-- D: eigene Statusleiste mit geheimem Wert")
    local sb = G.CreateFrame and G.CreateFrame("StatusBar", nil, G.UIParent)
    if sb and hp ~= nil then
        sb:SetSize(1000, 10); sb:SetPoint("TOPLEFT", G.UIParent, "TOPLEFT", -5000, 0)
        sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        Try("SetValue/Min/Max", function() sb:SetMinMaxValues(0, hm); sb:SetValue(hp); return "ok" end)
        Try("sb:GetValue", function() return sb:GetValue() end)
        Try("sb:GetMinMaxValues", function() return sb:GetMinMaxValues() end)
        Try("Fuelltextur:GetWidth", function() return sb:GetStatusBarTexture():GetWidth() end)
        Try("Fuelltextur:GetTexCoord", function() return sb:GetStatusBarTexture():GetTexCoord() end)
    end

    -- E: was darf man einem geheimen Wert als Argument geben?
    L("-- E: geheimen Wert an Fenster-Funktionen geben")
    local v = pv ~= nil and pv or hp
    if v ~= nil and G.CreateFrame then
        local f = G.CreateFrame("Frame", nil, G.UIParent)
        f:SetSize(10, 10); f:SetPoint("TOPLEFT", G.UIParent, "TOPLEFT", -5000, 0)
        local tex = f:CreateTexture()
        local cd = G.CreateFrame("Cooldown", nil, f)
        local fs = f:CreateFontString()
        if fs.SetFontObject and G.GameFontNormal then fs:SetFontObject(G.GameFontNormal) end
        Try("Frame:SetAlpha", function() f:SetAlpha(v); return "ok" end); f:SetAlpha(1)
        Try("Frame:SetWidth", function() f:SetWidth(v); return f:GetWidth() end)
        Try("Texture:SetRotation", function() tex:SetRotation(v); return "ok" end)
        Try("Texture:SetTexCoord", function() tex:SetTexCoord(0, v, 0, 1); return "ok" end)
        Try("Texture:SetVertexColor", function() tex:SetVertexColor(v, 1, 1, 1); return "ok" end)
        Try("FontString:SetText", function() fs:SetText(v); return fs:GetText() end)
        Try("Cooldown:SetCooldown(start,Wert)", function() cd:SetCooldown(G.GetTime() - 1, v); return "ok" end)
        Try("Cooldown:SetCooldownDuration", function() cd:SetCooldownDuration(v); return "ok" end)
        Try("Cooldown:GetCooldownTimes", function() return cd:GetCooldownTimes() end)
        Try("CreateLine", function() local ln = f:CreateLine(); ln:SetStartPoint("CENTER", f, 0, 0); ln:SetEndPoint("CENTER", f, v, 0); return "ok" end)
    end

    -- F: Kurven und Ausfuehrungsobjekte des Spiels
    L("-- F: Kurven und Zeitobjekte")
    L("C_CurveUtil=" .. tostring(type(G.C_CurveUtil)) .. " C_DurationUtil=" .. tostring(type(G.C_DurationUtil)) .. " CurveConstants=" .. tostring(type(G.CurveConstants)))
    if type(G.CurveConstants) == "table" then
        local names = {}
        for k in pairs(G.CurveConstants) do names[#names + 1] = tostring(k) end
        table.sort(names); L("CurveConstants: " .. table.concat(names, ", "))
    end
    if type(G.C_CurveUtil) == "table" then
        local names = {}
        for k in pairs(G.C_CurveUtil) do names[#names + 1] = tostring(k) end
        table.sort(names); L("C_CurveUtil: " .. table.concat(names, ", "))
        if G.C_CurveUtil.CreateCurve then
            local ok, curve = pcall(G.C_CurveUtil.CreateCurve)
            if ok and curve then
                pcall(function() curve:AddPoint(0, 0); curve:AddPoint(1, 100) end)
                Try("Percent(player,false,Kurve 0..100)", function() return G.UnitHealthPercent("player", false, curve) end)
                local cv
                pcall(function() cv = G.UnitHealthPercent("player", false, curve) end)
                if cv ~= nil and G.CreateFrame then
                    local cd2 = G.CreateFrame("Cooldown", nil, G.UIParent)
                    cd2:SetSize(10, 10); cd2:SetPoint("TOPLEFT", G.UIParent, "TOPLEFT", -5000, 0)
                    Try("Kurvenwert -> Cooldown:SetCooldown", function() cd2:SetCooldown(G.GetTime() - 1, cv); return "ok" end)
                end
            else
                L("CreateCurve: FEHLER")
            end
        end
    end
    if type(G.C_DurationUtil) == "table" then
        local names = {}
        for k in pairs(G.C_DurationUtil) do names[#names + 1] = tostring(k) end
        table.sort(names); L("C_DurationUtil: " .. table.concat(names, ", "))
    end
    if type(G.C_Secrets) == "table" then
        local names = {}
        for k in pairs(G.C_Secrets) do names[#names + 1] = tostring(k) end
        table.sort(names); L("C_Secrets: " .. table.concat(names, ", "))
        for _, k in ipairs(names) do
            if k:find("Should") or k:find("Has") then
                Try("C_Secrets." .. k .. "(player)", function() return G.C_Secrets[k]("player") end)
            end
        end
    end
    L("== Ende der Probe (" .. #lines .. " Zeilen, auch unter ringProbe gespeichert) ==")
    return lines
end

if G.SlashCmdList then
    G.SLASH_FWPROBE1 = "/fwprobe"
    G.SlashCmdList["FWPROBE"] = function()
        local function Out(t) if FW.Print then FW:Print(t) else print(t) end end
        local ok, res = pcall(P.Run, Out)
        if not ok then Out("Probe-Fehler: " .. tostring(res)) return end
        if type(FW.settings) == "table" then FW.settings.ringProbe = res end
    end
end

---------------------------------------------------------------------
-- /fwspin: Sicht-Probe fuer einen glatten Kreis mit geheimen Werten.
-- Zwei Halbringe drehen sich (Texture:SetRotation nimmt geheime Werte an); die Drehwinkel liefert eine Kurve des Spiels aus dem
-- Lebensanteil, das Addon rechnet nichts. Jede Haelfte wird beschnitten: Variante A mit Frame:SetClipsChildren, Variante B mit
-- Masken-Texturen. Obere Reihe A, untere Reihe B; Spalten: feste 25 %, 60 %, 90 % und "live" (dein echtes Leben, geheim).
---------------------------------------------------------------------

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Rings\\"

local function Clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

-- Drehwinkel (im Uhrzeigersinn gefuellt; Rotation in WoW ist gegen den Uhrzeigersinn positiv, daher negativ)
function P.Angles(frac)
    local a = frac * 360
    return -math.rad(Clamp(a, 0, 180)), -math.rad(Clamp(a, 180, 360))
end

local function BuildSweep(parent, size, method)
    local root = G.CreateFrame("Frame", nil, parent)
    root:SetSize(size, size)
    local obj = { root = root }
    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(root)
    bg:SetColorTexture(0, 0, 0, 0.35)
    for _, side in ipairs({ "R", "L" }) do
        local tex
        if method == "A" then
            local clip = G.CreateFrame("Frame", nil, root)
            if clip.SetClipsChildren then clip:SetClipsChildren(true) end
            clip:SetSize(size / 2, size)
            clip:SetPoint(side == "R" and "TOPRIGHT" or "TOPLEFT", root, side == "R" and "TOPRIGHT" or "TOPLEFT", 0, 0)
            tex = clip:CreateTexture(nil, "ARTWORK")
        else
            tex = root:CreateTexture(nil, "ARTWORK")
            if root.CreateMaskTexture and tex.AddMaskTexture then
                local m = root:CreateMaskTexture()
                m:SetTexture(PATH .. (side == "R" and "mask_right.tga" or "mask_left.tga"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                m:SetAllPoints(root)
                tex:AddMaskTexture(m)
            end
        end
        tex:SetTexture(PATH .. "half3.tga")
        tex:SetVertexColor(0.2, 0.85, 0.2, 1)
        tex:SetSize(size, size)
        tex:SetPoint("CENTER", root, "CENTER", 0, 0)
        obj["tex" .. side] = tex
    end
    return obj
end

local function Label(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if fs.SetFontObject and G.GameFontNormalSmall then fs:SetFontObject(G.GameFontNormalSmall) end
    fs:SetPoint("TOP", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

function P.Spin()
    if P.spin then
        if P.spin.frame:IsShown() then P.spin.frame:Hide() else P.spin.frame:Show() end
        return P.spin
    end
    local size, gap = 96, 24
    local f = G.CreateFrame("Frame", "FreewoodRingSpin", G.UIParent)
    f:SetSize(4 * (size + gap) + gap, 2 * (size + 40) + 30)
    f:SetPoint("CENTER", G.UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(f); bg:SetColorTexture(0.05, 0.05, 0.08, 0.9)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Label(f, "/fwspin: oben Variante A (Frame beschneiden), unten Variante B (Masken). Ziehen verschiebt, /fwspin schliesst.", f:GetWidth() / 2, -6)

    local sw = { frame = f, items = {} }
    local fixed = { 0.25, 0.60, 0.90 }
    for row, method in ipairs({ "A", "B" }) do
        for col = 1, 4 do
            local x = gap + (col - 1) * (size + gap)
            local y = -34 - (row - 1) * (size + 40)
            local obj = BuildSweep(f, size, method)
            obj.root:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
            local name = col <= 3 and (method .. " " .. math.floor(fixed[col] * 100 + 0.5) .. " %") or (method .. " live")
            Label(f, name, x + size / 2, y - size - 4)
            if col <= 3 then
                local rr, rl = P.Angles(fixed[col])
                obj.texR:SetRotation(rr); obj.texL:SetRotation(rl)
            else
                sw.items[#sw.items + 1] = obj
            end
        end
    end

    -- Kurven: Lebensanteil (0..1) -> Drehwinkel; die Kurve rechnet im Spiel, das Addon sieht nur geheime Werte
    local status = {}
    if G.C_CurveUtil and G.C_CurveUtil.CreateCurve then
        local okR, cR = pcall(G.C_CurveUtil.CreateCurve)
        local okL, cL = pcall(G.C_CurveUtil.CreateCurve)
        if okR and okL and cR and cL then
            local a1 = pcall(function() cR:AddPoint(0, 0); cR:AddPoint(0.5, -math.pi); cR:AddPoint(1, -math.pi) end)
            local a2 = pcall(function() cL:AddPoint(0, -math.pi); cL:AddPoint(0.5, -math.pi); cL:AddPoint(1, -2 * math.pi) end)
            status[#status + 1] = "Kurven: AddPoint " .. tostring(a1 and a2)
            sw.curveR, sw.curveL = cR, cL
        else
            status[#status + 1] = "Kurven: CreateCurve fehlgeschlagen"
        end
    else
        status[#status + 1] = "Kurven: C_CurveUtil.CreateCurve fehlt"
    end
    status[#status + 1] = "SetClipsChildren: " .. tostring(f.SetClipsChildren ~= nil)
    status[#status + 1] = "MaskTexture: " .. tostring(f.CreateMaskTexture ~= nil)
    sw.status = status
    Label(f, table.concat(status, "   "), f:GetWidth() / 2, -f:GetHeight() + 14)

    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < 0.1 then return end
        acc = 0
        if not sw.curveR or not G.UnitHealthPercent then return end
        local ok, rr = pcall(G.UnitHealthPercent, "player", false, sw.curveR)
        local ok2, rl = pcall(G.UnitHealthPercent, "player", false, sw.curveL)
        if not ok or not ok2 then return end
        for _, obj in ipairs(sw.items) do
            local a = pcall(obj.texR.SetRotation, obj.texR, rr)
            local b = pcall(obj.texL.SetRotation, obj.texL, rl)
            if not (a and b) then sw.err = true end
        end
    end)
    P.spin = sw
    return sw
end

if G.SlashCmdList then
    G.SLASH_FWSPIN1 = "/fwspin"
    G.SlashCmdList["FWSPIN"] = function()
        local ok, err = pcall(P.Spin)
        if not ok and FW.Print then FW:Print("fwspin-Fehler: " .. tostring(err)) end
    end
end
