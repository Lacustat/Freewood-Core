-- Test Ring-Probe (texlua tests/ringprobe_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local SECRET = setmetatable({}, { __tostring = function() error("secret") end })
local Fake
Fake = function() return setmetatable({}, { __index = function(_, k) return function() if tostring(k):find("^Create") or k == "GetStatusBarTexture" then return Fake() end if k == "GetWidth" or k == "GetHeight" then return 100 end if k == "IsShown" then return true end return nil end end }) end
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
-- Sicht-Probe /fwspin
local a, b = P.Angles(0.25); near = function(x, y) return math.abs(x - y) < 1e-9 end
eq(near(a, -math.pi / 2), true, "25 %: rechte Haelfte 90 Grad"); eq(near(b, -math.pi), true, "25 %: linke Haelfte noch 180 (leer)")
a, b = P.Angles(0.75); eq(near(a, -math.pi), true, "75 %: rechte Haelfte voll"); eq(near(b, -1.5 * math.pi), true, "75 %: linke Haelfte 270 Grad")
a, b = P.Angles(1); eq(near(b, -2 * math.pi), true, "100 %: linke Haelfte 360 Grad")
_G.C_CurveUtil = { CreateCurve = function() return { AddPoint = function() end } end }
local sw = P.Spin(); eq(sw ~= nil and sw.frame ~= nil, true, "Sicht-Probe gebaut"); eq(#sw.items, 2, "zwei Live-Ringe")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
