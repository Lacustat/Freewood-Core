-- Freewood-Core: Reiter "Profile" unter Einstellungen. Speichern, Laden, Umbenennen, Loeschen, Zuruecksetzen.
-- Die persoenlichen Einstellungen gelten je Charakter (Core/Profile.lua); ein Profil ist ein benannter Abzug im Konto.

local ADDON, NS = ...
local G = _G
local FW = G.Freewood
if not FW or not FW.UI or not FW.Profile then return end

local UI = FW.UI
local P = FW.Profile
local ROWS = 10

local function Say(text) if FW.Print then FW:Print(text) end end

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("profiles", {
        category = "profiles",
        order = 10,
        height = 150 + ROWS * 28 + 190,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.PROFILE_TITLE)
            local refreshers = {}
            local selected

            local cur = UI.CreateLabel(f, "", { size = 12, color = "goldLight" })
            stack:Add(cur, { height = 18, gap = 4 })
            refreshers[#refreshers + 1] = function()
                local n = P.Current()
                cur:SetText(string.format(L.PROFILE_CURRENT, n or L.PROFILE_NONE))
            end
            stack:Add(UI.CreateLabel(f, L.PROFILE_NOTE, { size = 11, color = "textDim" }), { height = 46, gap = 8 })

            -- Name + Speichern
            local row = CreateFrame("Frame", nil, f)
            row:SetSize(340, 24)
            local box = UI.CreatePanel(row, "bgDeep", "bronze")
            box:SetSize(190, 24)
            box:SetPoint("LEFT", row, "LEFT", 0, 0)
            local edit = CreateFrame("EditBox", nil, box)
            edit:SetAutoFocus(false)
            edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
            edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
            edit:SetMaxLetters(32)
            if not edit:SetFont(UI.GetFontPath("body"), 12, "") then edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
            edit:SetTextColor(UI.Color("text"))
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            local function Refresh() for _, r in ipairs(refreshers) do r() end end
            local function DoSave()
                local ok, name = P.Save(edit:GetText())
                if ok then
                    Say(string.format(L.PROFILE_SAVED, name))
                    edit:SetText("")
                    edit:ClearFocus()
                    selected = name
                    Refresh()
                else
                    Say(L.PROFILE_NEED_NAME)
                end
            end
            edit:SetScript("OnEnterPressed", DoSave)
            local save = UI.CreateButton(row, L.PROFILE_SAVE, 140, 24, DoSave, "primary")
            save:SetPoint("LEFT", box, "RIGHT", 6, 0)
            stack:Add(row, { height = 24, gap = 10 })

            -- Liste der gespeicherten Profile (Zeile anklicken = auswaehlen)
            stack:Add(UI.CreateLabel(f, L.PROFILE_LIST, { size = 12 }), { height = 16, gap = 2 })
            local list = CreateFrame("Frame", nil, f)
            list:SetSize(340, ROWS * 28)
            local rows = {}
            for i = 1, ROWS do
                local b = UI.CreateButton(list, "", 340, 24, function()
                    local e = rows[i].entry
                    if e then selected = e.name Refresh() end
                end, "default")
                b:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * 28)
                rows[i] = b
            end
            stack:Add(list, { height = ROWS * 28, gap = 6 })
            refreshers[#refreshers + 1] = function()
                local entries = P.List()
                for i = 1, ROWS do
                    local e = entries[i]
                    local b = rows[i]
                    b.entry = e
                    if e then
                        local text = e.name .. (e.from and ("  |cff9a978c(" .. e.from .. ")|r") or "")
                        b:SetLabel(text)
                        b:SetStyle(e.name == selected and "primary" or "default")
                        b:Show()
                    else
                        b:Hide()
                    end
                end
            end

            -- Aktionen auf das gewaehlte Profil
            local sel = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
            stack:Add(sel, { height = 16, gap = 4 })
            refreshers[#refreshers + 1] = function()
                if selected and not P.Exists(selected) then selected = nil end
                sel:SetText(selected and string.format(L.PROFILE_SELECTED, selected) or L.PROFILE_SELECT_HINT)
            end
            local act = CreateFrame("Frame", nil, f)
            act:SetSize(340, 24)
            local load = UI.CreateButton(act, L.PROFILE_LOAD, 104, 24, function()
                if not selected then Say(L.PROFILE_SELECT_HINT) return end
                local ok, name = P.Load(selected)
                if ok then Say(string.format(L.PROFILE_LOADED, name)) Refresh() end
            end, "primary")
            load:SetPoint("LEFT", act, "LEFT", 0, 0)
            local rename = UI.CreateButton(act, L.PROFILE_RENAME, 114, 24, function()
                if not selected then Say(L.PROFILE_SELECT_HINT) return end
                local ok, name = P.Rename(selected, edit:GetText())
                if ok then
                    Say(string.format(L.PROFILE_RENAMED, name))
                    selected = name
                    edit:SetText("")
                    Refresh()
                else
                    Say(L.PROFILE_RENAME_FAIL)
                end
            end, "default")
            rename:SetPoint("LEFT", load, "RIGHT", 6, 0)
            local del = UI.CreateButton(act, L.PROFILE_DELETE, 104, 24, function()
                if not selected then Say(L.PROFILE_SELECT_HINT) return end
                if P.Delete(selected) then Say(string.format(L.PROFILE_DELETED, selected)) selected = nil Refresh() end
            end, "default")
            del:SetPoint("LEFT", rename, "RIGHT", 6, 0)
            stack:Add(act, { height = 24, gap = 6 })
            stack:Add(UI.CreateLabel(f, L.PROFILE_RENAME_HINT, { size = 11, color = "textDim" }), { height = 30, gap = 10 })

            local reset = UI.CreateButton(f, L.PROFILE_RESET, 220, 24, function()
                P.Reset()
                Say(L.PROFILE_RESET_DONE)
                Refresh()
            end, "default")
            stack:Add(reset, { height = 24, gap = 8 })
            stack:Add(UI.CreateButton(f, L.DESIGN_RELOAD, 220, 24, function() G.ReloadUI() end, "primary"), { height = 24, gap = 8 })

            f.fwRefreshers = refreshers
            Refresh()
            return f
        end,
        refresh = function(frame)
            if frame and frame.fwRefreshers then for _, r in ipairs(frame.fwRefreshers) do r() end end
        end,
    })
end
