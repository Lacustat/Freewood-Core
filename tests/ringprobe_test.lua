-- Test Ring-Probe (texlua tests/ringprobe_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local SECRET = setmetatable({}, { __tostring = function() error("secret") end })
local Fake
Fake = function() return setmetatable({}, { __index = function(_, k) return function() if tostring(k):find("^Create") or k == "GetStatusBarTexture" then return Fake() end return nil end end }) end
_G.issecretvalue = function(v) return v == SECRET end
_G.InCombatLockdown = function() return false end
_G.IsInInstance = function() return false, "none" end
_G.UnitExists = function(u) return u == "player" end
_G.UnitHealth = function() return SECRET end
_G.UnitHealthMax = function() return SECRET end
_G.UnitHealthPercent = function() return SECRET end
_G.GetTime = function() return 100 end
_G.UIParent = Fake()
_G.CreateFrame = function() return Fake() end
_G.CurveConstants = { ScaleTo100 = 1 }
local FW = { settings = {}, Print = function() end }
assert(loadfile("UI/RingProbe.lua"))("Freewood-Core", FW)
local P = FW.RingProbe
eq(P.Desc(SECRET), "table GEHEIM", "geheimer Wert wird erkannt")
eq(P.Desc(5), "number 5", "Zahl"); eq(P.Desc(nil), "nil", "nil"); eq(P.Desc("x"), "string 'x'", "Text")
local ops = P.Ops(5); eq(ops:find("+0:ok(5)", 1, true) ~= nil, true, "Rechnen mit normaler Zahl geht")
local lines = P.Run()
eq(#lines > 15, true, "Probe liefert viele Zeilen")
local text = table.concat(lines, "\n")
eq(text:find("Ring-Probe", 1, true) ~= nil, true, "Kopfzeile"); eq(text:find("Ende der Probe", 1, true) ~= nil, true, "Schlusszeile")
eq(text:find("player: Health=table GEHEIM", 1, true) ~= nil, true, "geheimer Spielerwert gemeldet")
-- mit lesbaren Werten
_G.UnitHealth = function() return 875 end; _G.UnitHealthMax = function() return 875 end
lines = P.Run(); text = table.concat(lines, "\n")
eq(text:find("Health=number 875", 1, true) ~= nil, true, "lesbarer Wert gemeldet")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
