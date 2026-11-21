-- Test 0.55.2: Tasten-Rahmen des Chatfensters verschluckt im Kampf keine Tasten (Bewegung)   texlua tests/chatkeys_test.lua
local function Proxy()
    return setmetatable({}, { __index = function() return function() return Proxy() end end })
end
-- Rahmen, die Skripte und die Weitergabe mitschreiben; unbekannte Methoden tun nichts
local made = {}
local FM = {}
FM.__index = function(t, k)
    if FM[k] then return FM[k] end
    if type(k) == "string" and k:match("^%u") then return function() return Proxy() end end
end
function FM.SetScript(f, k, fn) f.scripts[k] = fn end
function FM.EnableKeyboard(f, on) f.keyboard = on end
function FM.SetPropagateKeyboardInput(f, on)
    if _G.InCombatLockdown() then f.blocked = (f.blocked or 0) + 1 return end   -- im Spiel: ADDON_ACTION_BLOCKED
    f.propagate = on
end
_G.CreateFrame = function() local f = setmetatable({ scripts = {} }, FM) made[#made + 1] = f return f end
_G.UIParent = Proxy()
_G.UnitName = function() return "Pinky" end
_G.time = os.time
local combat = false
_G.InCombatLockdown = function() return combat end
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local t = timers timers = {} for _, fn in ipairs(t) do fn() end end
_G.GetBindingKey = function(a) if a == "OPENCHAT" then return "ENTER" end end
_G.IsShiftKeyDown = function() return false end

local ev = {}
local UI = setmetatable({ RegisterSettingsSection = function() end }, { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    RegisterEvent = function(_, e, f) ev[e] = f end, On = function() end, Fire = function() end,
    Util = { IsSecret = function() return false end }, Whisper = { SelfName = function() return "Pinky" end } }
assert(loadfile("UI/ChatWindow.lua"))("Freewood-Core", FW)
local W = FW.ChatWindow
local opened = 0
W.OpenInput = function() opened = opened + 1 return true end
W.MainActive = function() return true end
W.UseBlizz = function() return false end

local before = #made
W.ApplyKeyListener(true)
local kf = made[before + 1]
assert(kf and kf.scripts.OnKeyDown, "Tasten-Rahmen gebaut")
assert(kf.keyboard == true and kf.propagate == true, "hoert mit und gibt weiter")

-- Enter oeffnet den Chat: nur dieser Druck wird geschluckt, im naechsten Bild wieder frei
kf.scripts.OnKeyDown(kf, "ENTER")
assert(opened == 1 and kf.propagate == false, "Enter geschluckt")
RunTimers()
assert(kf.propagate == true, "gleich wieder frei")

-- Der Fehler: Enter, dann sofort Kampf (Bild noch nicht weiter) -> Kampfbeginn gibt frei
kf.scripts.OnKeyDown(kf, "ENTER")
assert(kf.propagate == false)
ev.PLAYER_REGEN_DISABLED()        -- kommt vor der Sperre: darf noch setzen
combat = true
assert(kf.propagate == true, "Kampfbeginn gibt die Tasten frei")
RunTimers()
-- im Kampf: W, A, S, D und auch Enter werden nie geschluckt, keine geschuetzten Aufrufe
for _, key in ipairs({ "W", "A", "S", "D", "ENTER" }) do kf.scripts.OnKeyDown(kf, key) end
assert(kf.propagate == true and (kf.blocked or 0) == 0, "im Kampf nichts geschluckt, nichts blockiert")
assert(opened == 2, "Enter im Kampf geht an das Spiel (nicht an unseren Rahmen)")
combat = false
ev.PLAYER_REGEN_ENABLED()
assert(kf.propagate == true)

-- Taste loslassen gibt ebenfalls frei (falls das naechste Bild ausbleibt)
kf.scripts.OnKeyDown(kf, "ENTER")
timers = {}
kf.scripts.OnKeyUp(kf, "ENTER")
assert(kf.propagate == true, "beim Loslassen frei")

-- andere Tasten ausserhalb des Kampfes: nie geschluckt
kf.scripts.OnKeyDown(kf, "W")
assert(kf.propagate == true, "W wird weitergegeben")
print("chatkeys_test: ok")
