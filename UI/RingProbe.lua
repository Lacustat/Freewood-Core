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
