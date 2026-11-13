-- Test FW:Log: ohne Dev nichts, mit Dev weitergeleitet, Mengenbegrenzung je Kategorie (texlua tests/fwlog_test.lua)
local t = 0
_G.GetTime = function() return t end
local out = print
local FW = {}
-- nur den FW:Log-Teil aus Core/Init.lua laden
local src = io.open("Core/Init.lua"):read("*a")
local a = src:find("local LOG_LIMIT", 1, true)
local b = src:find("function FW:Debug", 1, true)
assert(a and b, "FW:Log fehlt")
local chunk = assert(loadstring or load)("local FW = ...\n" .. src:sub(a, b - 1))
chunk(FW)
FW:Log("x", "ohne Dev")   -- darf nicht fehlen
local got = {}
FW.Dev = { Diag = { Add = function(cat, text) got[#got + 1] = cat .. ":" .. text end } }
FW:Log("plan", "Wert %d", 5)
assert(got[1] == "plan:Wert 5", got[1])
for i = 1, 50 do FW:Log("laut", "z" .. i) end
assert(#got == 1 + 20, "Begrenzung 20 pro Minute: " .. #got)
t = 61
FW:Log("laut", "wieder")
assert(got[#got - 1]:find("30 Zeilen unterdrueckt", 1, true) and got[#got] == "laut:wieder", got[#got - 1])
out("fwlog_test OK")
