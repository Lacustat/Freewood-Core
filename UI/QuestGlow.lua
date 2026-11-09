-- Freewood-Core: Glitzern fuer Quest-Items und Beute (Einstellungen > Quests und Hinweise).
-- Haken an  = outlineModeShowLootEffectWhenDisabled 1 und graphicsOutlineMode 0 (wie "/console ..."); der alte Wert wird gemerkt
-- und beim Ausschalten zurueckgesetzt. Beim Anmelden wird der Wert nochmal gesetzt, falls das Spiel ihn zurueckgestellt hat.
-- UNGEPRUEFT im Spiel (ob diese Einstellungen auf Forever wirken).

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local QG = {}
FW.QuestGlow = QG

FW:AddLocale("enUS", {
    QUESTGLOW_TITLE = "Quest item sparkle",
    QUESTGLOW_NOTE = "Shows the sparkle on quest items and loot, even with the outline mode off. Sets the game settings outlineModeShowLootEffectWhenDisabled = 1 and graphicsOutlineMode = 0.",
    QUESTGLOW_SWITCH = "Let quest items sparkle",
    QUESTGLOW_STATE = "Current: graphicsOutlineMode = %s, outlineModeShowLootEffectWhenDisabled = %s",
    QUESTGLOW_MISSING = "This game version does not know one of the settings; nothing was changed.",
})
FW:AddLocale("deDE", {
    QUESTGLOW_TITLE = "Quest-Items glitzern",
    QUESTGLOW_NOTE = "Zeigt das Glitzern an Quest-Items und Beute, auch bei ausgeschaltetem Umriss-Modus. Setzt die Spieleinstellungen outlineModeShowLootEffectWhenDisabled = 1 und graphicsOutlineMode = 0.",
    QUESTGLOW_SWITCH = "Quest-Items glitzern lassen",
    QUESTGLOW_STATE = "Aktuell: graphicsOutlineMode = %s, outlineModeShowLootEffectWhenDisabled = %s",
    QUESTGLOW_MISSING = "Diese Spielversion kennt eine der Einstellungen nicht; es wurde nichts geändert.",
})

QG.CVARS = { outline = "graphicsOutlineMode", loot = "outlineModeShowLootEffectWhenDisabled" }

function QG.Get(name)
    local f = G.GetCVar or (G.C_CVar and G.C_CVar.GetCVar)
    if not f then return nil end
    local ok, v = pcall(f, name)
    if ok and v ~= nil then return tostring(v) end
    return nil
end

function QG.Set(name, value)
    local f = G.SetCVar or (G.C_CVar and G.C_CVar.SetCVar)
    if not f then return false end
    return (pcall(f, name, tostring(value)))
end

function QG.Opts()
    local s = FW.settings
    if type(s) ~= "table" then return { on = false } end
    if type(s.questGlow) ~= "table" then s.questGlow = { on = false } end
    return s.questGlow
end

-- Rueckgabe: ok (beide Einstellungen gibt es)
function QG.Apply(on)
    local o = QG.Opts()
    local c = QG.CVARS
    if QG.Get(c.outline) == nil or QG.Get(c.loot) == nil then return false end
    if on then
        if not o.prev then o.prev = { outline = QG.Get(c.outline), loot = QG.Get(c.loot) } end
        QG.Set(c.outline, "0")
        QG.Set(c.loot, "1")
        o.on = true
    else
        local p = o.prev
        if p then
            if p.outline then QG.Set(c.outline, p.outline) end
            if p.loot then QG.Set(c.loot, p.loot) end
        else
            QG.Set(c.loot, "0")
        end
        o.prev = nil
        o.on = false
    end
    return true
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if QG.Opts().on then pcall(QG.Apply, true) end
end)

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("quest-glow", {
        category = "quest",
        order = 110,
        height = 190,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.QUESTGLOW_TITLE)
            stack:Add(UI.CreateLabel(f, L.QUESTGLOW_NOTE, { size = 11, color = "textDim", justifyV = "TOP" }), { fit = true, gap = 8 })
            local state = UI.CreateLabel(f, "", { size = 11, color = "textDim", justifyV = "TOP" })
            local function Show()
                local c = QG.CVARS
                state:SetText(string.format(L.QUESTGLOW_STATE, QG.Get(c.outline) or "?", QG.Get(c.loot) or "?"))
            end
            stack:Add(UI.CreateCheckbox(f, L.QUESTGLOW_SWITCH,
                function() return QG.Opts().on == true end,
                function(on)
                    if not QG.Apply(on and true or false) and FW.Print then FW:Print(L.QUESTGLOW_MISSING) end
                    Show()
                end), { fit = true, gap = 10 })
            stack:Add(state, { fit = true, gap = 6 })
            Show()
            return f
        end,
    })
end
