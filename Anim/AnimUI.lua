-- Freewood-Core: Einstellungen, Reiter "Animation". Ton (Wecker, eigene Datei, aus) und je Animation:
-- anzeigen, auch ohne Inhalt zeigen, Groesse, Position zuruecksetzen, Test.

local ADDON, FW = ...

local UI = FW.UI
local A = FW.Anim
if not UI or not A or not UI.RegisterSettingsSection then return end

local function MakeEdit(parent, width, getText, onEnter)
    local box = UI.CreatePanel(parent, "bg", "bronze")
    box:SetSize(width, 26)
    local e = CreateFrame("EditBox", nil, box)
    e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -3)
    e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 3)
    e:SetMaxLetters(80)
    UI.SetFont(e, "body", 12)
    e:SetTextColor(UI.Color("text"))
    e:SetScript("OnEnterPressed", function(self) onEnter(strtrim(self:GetText() or "")); self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function(self) onEnter(strtrim(self:GetText() or "")) end)
    e:SetScript("OnEscapePressed", function(self) self:SetText(getText()); self:ClearFocus() end)
    box.edit = e
    function box:Refresh() e:SetText(getText()) end
    box:Refresh()
    return box
end

local function SoundSection(parent)
    local L = FW.L
    local f, stack = UI.CreateSection(parent, L.ANIM_SOUND_TITLE)
    local refreshers = {}

    stack:Add(UI.CreateLabel(f, L.ANIM_SOUND_MODE, { size = 12 }), { height = 16, gap = 2 })
    local function Options()
        return {
            { value = "alarm", text = L.ANIM_SOUND_ALARM },
            { value = "file", text = L.ANIM_SOUND_FILE },
            { value = "off", text = L.ANIM_SOUND_OFF },
        }
    end
    local dd = UI.CreateDropdown(f, 260, 22, {
        getOptions = Options,
        textOf = function(v)
            return v == "file" and L.ANIM_SOUND_FILE or v == "off" and L.ANIM_SOUND_OFF or L.ANIM_SOUND_ALARM
        end,
        onChange = function(v) if v then A.SoundCfg().mode = v end end,
    })
    dd:SetValue(A.SoundCfg().mode)
    stack:Add(dd, { height = 22, gap = 6 })
    refreshers[#refreshers + 1] = function() dd:SetValue(A.SoundCfg().mode) end

    stack:Add(UI.CreateLabel(f, L.ANIM_SOUND_FILENAME, { size = 12 }), { height = 16, gap = 2 })
    local edit = MakeEdit(f, 260,
        function() return A.SoundCfg().file or "" end,
        function(text) A.SoundCfg().file = text end)
    stack:Add(edit, { height = 26, gap = 6 })
    refreshers[#refreshers + 1] = function() edit:Refresh() end

    stack:Add(UI.CreateButton(f, L.ANIM_SOUND_PLAY, 200, 24, function()
        local s = A.SoundCfg()
        local keep = s.mode
        if keep == "off" then s.mode = "alarm" end
        A.PlaySound(true)
        s.mode = keep
    end, "default"), { height = 24, gap = 8 })
    stack:Add(UI.CreateLabel(f, L.ANIM_SOUND_NOTE, { size = 11, color = "textDim" }), { height = 40, gap = 4 })
    stack:Layout()
    f.fwRefreshers = refreshers
    return f
end

local function AnimSection(parent, id)
    local L = FW.L
    local def = A.defs[id]
    local f, stack = UI.CreateSection(parent, L[def.nameKey] or id)
    local refreshers = {}
    local function Cfg() return A.Cfg(id) end

    stack:Add(UI.CreateCheckbox(f, L.ANIM_SHOW,
        function() return Cfg().enabled end,
        function(v) Cfg().enabled = v and true or false; A.Refresh(id) end), { fit = true })
    if def.showEmptyKey then
        stack:Add(UI.CreateCheckbox(f, L[def.showEmptyKey],
            function() return Cfg().showEmpty end,
            function(v) Cfg().showEmpty = v and true or false; A.Refresh(id) end), { fit = true })
    end

    local label = UI.CreateLabel(f, "", { size = 12 })
    stack:Add(label, { height = 16, gap = 4 })
    local slider = UI.CreateSlider(f, 240, {
        min = 30, max = 300, step = 10,
        get = function() return Cfg().scale end,
        set = function(v) Cfg().scale = v; A.Size(id) end,
    })
    slider.onText = function(v) label:SetText(string.format(L.ANIM_SCALE, v)) end
    slider:Refresh()
    stack:Add(slider, { height = 20, gap = 8 })
    refreshers[#refreshers + 1] = function() slider:Refresh() end

    stack:Add(UI.CreateButton(f, L.ANIM_RESET_POS, 200, 24, function() A.ResetPosition(id) end, "default"), { height = 24, gap = 6 })
    for _, t in ipairs(def.tests or {}) do
        stack:Add(UI.CreateButton(f, L[t.labelKey], 200, 24, function() t.run() end, "default"), { height = 24, gap = 4 })
    end
    if def.eventsKey then
        stack:Add(UI.CreateLabel(f, L[def.eventsKey], { size = 11, color = "textDim" }), { height = 40, gap = 4 })
    end
    stack:Add(UI.CreateLabel(f, L.ANIM_MOVE_NOTE, { size = 11, color = "textDim" }), { height = 40, gap = 4 })
    stack:Layout()
    f.fwRefreshers = refreshers
    return f
end

local function Refresh(frame)
    if frame and frame.fwRefreshers then
        for _, r in ipairs(frame.fwRefreshers) do r() end
    end
end

UI:RegisterSettingsSection("animation-sound", {
    category = "animation",
    order = 10,
    height = 260,
    build = SoundSection,
    refresh = Refresh,
})

for i, id in ipairs(A.order) do
    UI:RegisterSettingsSection("animation-" .. id, {
        category = "animation",
        order = 20 + i,
        height = 380,
        build = function(parent) return AnimSection(parent, id) end,
        refresh = Refresh,
    })
end
