-- Test: Fluesterfenster verlaesst die Eingabe nach dem Absenden (texlua tests/whisperpopup_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
local edits = {}
local function Mock(kind)
    local o = { kind = kind, scripts = {}, text = "", focus = false }
    return setmetatable(o, { __index = function(t, k)
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "SetText" then return function(self, v) self.text = v or "" end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "SetFocus" then return function(self) self.focus = true end end
        if k == "ClearFocus" then return function(self) self.focus = false end end
        if k == "HasFocus" then return function(self) return self.focus end end
        if k == "SetFont" then return function() return true end end
        if k == "GetNumRegions" then return function() return 0 end end
        if string.find(k, "^Get") and not string.find(k, "^GetFont") then return function() return 100 end end
        return function() return Mock("sub") end
    end })
end
_G.CreateFrame = function(kind) local m = Mock(kind); if kind == "EditBox" then edits[#edits + 1] = m end; return m end
_G.UIParent = Mock("UIParent")
_G.GetTime = function() return 1 end
_G.time = function() return 1000 end
_G.UnitAffectingCombat = function() return false end
_G.SlashCmdList = {}
local sent = {}
local FW = { UI = setmetatable({ GetFontPath = function() return "x" end }, { __index = function() return function() return Mock("ui") end end }),
    L = setmetatable({}, { __index = function(_, k) return k end }), settings = { whisperPopup = true },
    RegisterEvent = function() end, On = function() end, Print = function() end, Util = {} }
FW.ChatLog = { Send = function(kind, name, txt) sent[#sent + 1] = kind .. ":" .. name .. ":" .. txt end, guild = {}, History = function() return {} end, Get = function() return {} end, Detail = function() return nil end, Lines = function() return {} end }
assert(loadfile("UI/WhisperPopups.lua"))("Freewood-Core", FW)
local ok, win = pcall(FW.WhisperPopups.Open, "Anna")
eq(ok, true, "Fenster oeffnet: " .. tostring(win))
local edit = edits[#edits]
assert(edit and edit.scripts.OnEnterPressed, "Eingabefeld mit Enter-Skript")
edit.text, edit.focus = "hallo", true
edit.scripts.OnEnterPressed(edit)
eq(sent[1], "whisper:Anna:hallo", "Nachricht gesendet")
eq(edit.text, "", "Feld geleert")
eq(edit.focus, false, "Eingabe nach dem Absenden verlassen")
edit.text, edit.focus = "", true
edit.scripts.OnEnterPressed(edit)
eq(#sent, 1, "leeres Feld sendet nichts"); eq(edit.focus, false, "leeres Enter verlaesst ebenfalls")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
