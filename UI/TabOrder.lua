-- Freewood-Core: Einstellungen fuer die Reiter-Leiste (ein-/ausblenden, Standard-Reihenfolge).
-- Verschieben geht direkt in der Leiste per Ziehen, Ausblenden per Rechtsklick (siehe MainWindow.lua).

local FW = _G.Freewood
local UI = FW.UI

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("tab-order", {
        category = "general",
        order = 70,
        height = 260,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.TABS_TITLE)
            stack:Add(UI.CreateLabel(f, L.TABS_HINT, { size = 11, color = "textDim" }), { fit = true })
            local boxes = {}
            for _, entry in ipairs(UI:GetTabList()) do
                if not entry.locked then
                    local id = entry.id
                    local box = UI.CreateCheckbox(f, entry.label,
                        function()
                            local hidden = FW.settings and FW.settings.tabHidden
                            return not (type(hidden) == "table" and hidden[id] == true)
                        end,
                        function(v)
                            UI:SetTabHidden(id, not v)
                        end)
                    boxes[#boxes + 1] = box
                    stack:Add(box, { fit = true })
                end
            end
            stack:Add(UI.CreateButton(f, L.TABS_RESET, 180, 26, function()
                UI:ResetTabOrder()
                for _, box in ipairs(boxes) do
                    box:Refresh()
                end
            end), { gap = 10 })
            f.boxes = boxes
            return f
        end,
        refresh = function(f)
            for _, box in ipairs(f.boxes or {}) do
                box:Refresh()
            end
        end,
    })
end
