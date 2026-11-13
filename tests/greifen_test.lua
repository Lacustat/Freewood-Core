-- Test der Greifen-Ersetzung mit nachgebauten Rahmen (texlua tests/greifen_test.lua)
local function Proxy()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        return function(self, ...)
            if k == "GetAtlas" then return rawget(t,"__atlas") end
            if k == "GetRegions" then return unpack(rawget(t,"__regions") or {}) end
            if k == "GetChildren" then return unpack(rawget(t,"__children") or {}) end
            if k == "GetCenter" then return 100, 50 end
            if k == "GetEffectiveScale" then return 1 end
            if k == "IsShown" then return true end
            return Proxy()
        end
    end })
end
local fails=0
local function eq(a,b,m) if a~=b then fails=fails+1 print("FEHLER "..m,a,b) end end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
local tex = Proxy(); tex.__atlas = "UI-HUD-ActionBar-Wyvern-Left"
local tex2 = Proxy(); tex2.__atlas = "UI-HUD-ActionBar-Wyvern-Right"
local fl, fr = Proxy(), Proxy(); fl.__regions = { tex }; fr.__regions = { tex2 }
local root = Proxy(); root.__children = { fl, fr }
_G.MainActionBar = root
local alpha = {}
local hooks = {}
tex.SetAlpha = function(self, a) alpha.l = a end
tex2.SetAlpha = function(self, a) alpha.r = a end
_G.hooksecurefunc = function(t, n, fn) hooks[#hooks+1] = fn end
_G.C_Timer = { After = function(s, f) end }
local ev, handlers, tabs = {}, {}, {}
local UI = setmetatable({ RegisterSettingsSection = function(_, id, def) tabs[id] = def end, CreateSection = function() return Proxy(), { Add = function() end } end },
  { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }), RegisterEvent = function(_, e, f) ev[e] = f end, On = function(_, e, f) handlers[e] = f end, Fire = function() end }
assert(loadfile("Media/Greifen/Greifen.lua"))("Freewood-Core", FW)
assert(loadfile("UI/Greifen.lua"))("Freewood-Core", FW)
local Gr = FW.Greifen
eq(Gr.Apply(), true, "Originale gefunden")
eq(alpha.l, 1, "aus: Original sichtbar")
FW.settings.greifen = { enabled = true }
Gr.Apply()
eq(alpha.l, 0, "an: Original links unsichtbar"); eq(alpha.r, 0, "an: rechts unsichtbar")
eq(FW.settings.greifen.right.mirror, true, "rechts gespiegelt (Standard)")
eq(FW.settings.greifen.left.mirror, false, "links normal")
Gr.SetUnlocked(true); Gr.SetUnlocked(false)
FW.settings.greifen.enabled = false
Gr.Apply()
eq(alpha.l, 1, "wieder aus: Original zurueck")
local f = tabs.greifen.build(Proxy())
eq(type(f), "table", "Abschnitt gebaut")
eq(tabs.greifen.category, "interface", "Kategorie")
-- Katalog, Filter, Groesse
local n = 0
for _, e in ipairs(FW.GreifenList) do n = n + 1 end
eq(n, 77, "77 Bilder im Katalog")
eq(#FW.GreifenFiles, 77, "Dateiliste passt")
local seen = {}
for _, e in ipairs(FW.GreifenList) do eq(seen[e.id], nil, "Id einmalig " .. e.id); seen[e.id] = true end
eq(#Gr.Filter("all"), 77, "Alle")
eq(#Gr.Filter("affen"), 10, "Legion der Affen")
eq(#Gr.Filter("skyborn"), 5, "Skyborn")
eq(#Gr.Filter("horde"), 18, "Horde")
eq(#Gr.Filter("allianz"), 16, "Allianz")
eq(#Gr.Filter("class", "WARLOCK"), 20, "Hexenmeister (10 Voelker + Affe + 9 Daemonen)")
eq(#Gr.Filter("daemonen"), 9, "Daemonen")
eq(#Gr.Filter("race", "Gnome"), 4, "Gnome")
eq(Gr.Entry("orc_hunter_m_1").faction, "horde", "Orc ist Horde")
eq(Gr.Entry("human_warlock_m").faction, "allianz", "Mensch ist Allianz")
local sub = Gr.SubOptions("class")
eq(#sub, 9, "9 Klassen kommen vor")
eq(#Gr.SubOptions("race"), 8, "8 Voelker")
eq(#Gr.SubOptions("all"), 0, "ohne Unterpunkt")
-- "Zu meinem Charakter": Orc-Jaeger
_G.UnitClass = function() return "Jaeger", "HUNTER" end
_G.UnitRace = function() return "Orc", "Orc" end
local mine = Gr.Filter("mine")
eq(mine[1].class == "HUNTER" and mine[1].race == "Orc", true, "meine: passend zu beidem zuerst")
local lastBoth = 0
for i, e in ipairs(mine) do if e.class == "HUNTER" and e.race == "Orc" then lastBoth = i end end
eq(lastBoth, 2, "zwei Orc-Jaeger vorn")
eq(Gr.DefaultSub("class"), "HUNTER", "Unterpunkt: eigene Klasse")
eq(Gr.DefaultSub("race"), "Orc", "Unterpunkt: eigenes Volk")
-- Groesse: 2:1 wie das Original, quadratisch hoeher
local w, h = Gr.Size("affen_greif"); eq(w, 220, "2:1 Breite"); eq(h, 110, "2:1 Hoehe")
w, h = Gr.Size("orc_hunter_m_1"); eq(w, h, "quadratisch"); eq(h, 154, "quadratisch Hoehe")
w, h = Gr.Size("eigenes_bild"); eq(w, 220, "unbekannt: wie Original")
eq(Gr.Name("orc_hunter_m_1") ~= "", true, "Name")
-- Festhalten am Rand
eq(FW.settings.greifen.left.clamp, true, "Standard: festhalten")
local fakeS = { x = 0, y = 0 }
local fr = { GetEffectiveScale = function() return 1 end, GetLeft = function() return -400 end, GetRight = function() return -10 end,
    GetTop = function() return 300 end, GetBottom = function() return 100 end }
_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end, GetEffectiveScale = function() return 1 end }
Gr.KeepVisible(fr, fakeS)
eq(fakeS.x, 30, "links zu weit draussen: Rest von 20 sichtbar")
eq(fakeS.y, 0, "senkrecht unveraendert")
local fr2 = { GetEffectiveScale = function() return 1 end, GetLeft = function() return 100 end, GetRight = function() return 300 end,
    GetTop = function() return -50 end, GetBottom = function() return -250 end }
local s2 = { x = 5, y = 7 }
Gr.KeepVisible(fr2, s2)
eq(s2.y, 77, "unten: Rest sichtbar")
eq(s2.x, 5, "waagerecht ok")
local fr3 = { GetEffectiveScale = function() return 1 end, GetLeft = function() return 100 end, GetRight = function() return 300 end,
    GetTop = function() return 1400 end, GetBottom = function() return 1200 end }
local s3 = { x = 0, y = 0 }
Gr.KeepVisible(fr3, s3)
eq(s3.y, -(1200 - 1060), "oben: Rest sichtbar")
print(fails == 0 and "OK" or ("FEHLER: "..fails))

-- jedes Bild der Liste hat eine Datei (Kopf: 32 Bit, unkomprimiert, 256x256 oder 512x256)
do
    local list = {}
    local chunk = assert(loadfile("Media/Greifen/Greifen.lua"))
    local FWt = {}
    chunk("Freewood-Core", FWt)
    local hunter = 0
    for _, e in ipairs(FWt.GreifenList) do
        local f = io.open("Media/Greifen/" .. e.id .. ".tga", "rb")
        if not f then print("FEHLER Datei fehlt: " .. e.id) os.exit(1) end
        local h = f:read(18) f:close()
        local w, hgt = h:byte(13) + h:byte(14) * 256, h:byte(15) + h:byte(16) * 256
        if h:byte(3) ~= 2 or h:byte(17) ~= 32 or (w ~= 256 and w ~= 512) or hgt ~= 256 then
            print("FEHLER TGA-Kopf: " .. e.id, h:byte(3), h:byte(17), w, hgt) os.exit(1)
        end
        if e.class == "HUNTER" and e.id:find("^pet_") then hunter = hunter + 1 end
    end
    if hunter ~= 20 then print("FEHLER erwartet 20 Begleiter, gefunden " .. hunter) os.exit(1) end
    print("greifen files OK")
end
