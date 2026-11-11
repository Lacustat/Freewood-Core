-- Test Animationen: Bildzuschnitt, Abspielen vor und zurueck, Briefkasten-Ereignisse, Auszeit, Ton (texlua tests/anim_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function near(a, b, m) eq(math.abs(a - b) < 1e-6, true, m .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")") end

local function Obj()
    local o = { shown = false, scripts = {}, points = {} }
    return setmetatable(o, { __index = function(t, k)
        if k == "Show" then return function(self) self.shown = true end
        elseif k == "Hide" then return function(self) self.shown = false end
        elseif k == "IsShown" then return function(self) return self.shown end
        elseif k == "SetScript" then return function(self, e, f) self.scripts[e] = f end
        elseif k == "SetTexCoord" then return function(self, ...) self.tc = { ... } end
        elseif k == "SetTexture" then return function(self, p) self.texture = p end
        elseif k == "SetSize" then return function(self, w, h) self.w, self.h = w, h end
        elseif k == "ClearAllPoints" then return function(self) self.points = {} end
        elseif k == "SetPoint" then return function(self, ...) self.points[#self.points + 1] = { ... } end
        elseif k == "CreateTexture" then return function() return Obj() end
        elseif k == "GetLeft" or k == "GetBottom" then return function() return 100 end
        elseif type(k) == "string" and (k:find("^Set") or k:find("^Register") or k:find("^Enable")) then return function() end
        end
        return nil
    end })
end

_G.UIParent = Obj()
_G.CreateFrame = function() return Obj() end
_G.InCombatLockdown = function() return false end
_G.IsShiftKeyDown = function() return true end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.GameTooltip = Obj()
local sounds = {}
_G.PlaySound = function(id) sounds[#sounds + 1] = { "id", id } end
_G.PlaySoundFile = function(path) sounds[#sounds + 1] = { "file", path }; return true end
local newMail = false
_G.HasNewMail = function() return newMail end
local now = 1000
_G.time = function() return now end

local handlers, events = {}, {}
local FW = { settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    On = function(_, e, f) handlers[e] = handlers[e] or {}; table.insert(handlers[e], f) end,
    RegisterEvent = function(_, e, f) events[e] = f end,
    Print = function() end }
FW.UI = { Color = function() return 1, 1, 1 end, RegisterSettingsSection = nil }

assert(loadfile("Anim/Anim.lua"))("Freewood-Core", FW)
assert(loadfile("Anim/AnimMailbox.lua"))("Freewood-Core", FW)
local A = FW.Anim
for _, f in ipairs(handlers.FW_DB_READY or {}) do f() end
local f = A.frames.mailbox
eq(f ~= nil, true, "Briefkasten-Frame gebaut")
eq(f.shown, false, "ohne Post unsichtbar (Standard)")
eq(f.strata, nil, "Mock")

-- Zuschnitt
local def = A.defs.mailbox
local ox, oy = 2 / 1024, 2 / 1024
local l, r, t, b = A.UV(def, 1); near(l, ox, "UV1 l"); near(r, ox + 252 / 1024, "UV1 r"); near(t, oy, "UV1 t"); near(b, oy + 336 / 1024, "UV1 b")
l, r, t, b = A.UV(def, 4); near(l, 3 * 256 / 1024 + ox, "UV4 l"); near(t, oy, "UV4 t"); near(b, oy + 336 / 1024, "UV4 b")

-- Aussehen: Vorgabe nach Fraktion, 18 Stueck, 3 je Bildplatte
eq(#def.skins, 19, "19 Aussehen")
eq(A.SkinId(def), "horde", "Vorgabe ohne Fraktion: Horde")
eq(f.tex.texture, "Interface\\AddOns\\Freewood-Core\\Media\\Animation\\Mailbox1.tga", "Horde liegt auf Platte 1")
_G.UnitFactionGroup = function() return "Alliance" end
eq(A.SkinId(def), "allianz", "Vorgabe Allianz")
_G.UnitFactionGroup = nil
local seen = {}
for k, sk in ipairs(def.skins) do
    eq(seen[sk.id], nil, "Aussehen " .. sk.id .. " nur einmal"); seen[sk.id] = true
    eq(sk.atlas.file:find("Mailbox" .. (math.floor((k - 1) / 3) + 1) .. "%.tga$") ~= nil, true, "Platte von " .. sk.id)
    eq(sk.atlas.row0, (k - 1) % 3, "Zeile von " .. sk.id)
    eq((sk.atlas.row0 + 1) * sk.atlas.cellH <= sk.atlas.texH, true, "Zeile passt in die Platte " .. sk.id)
end
A.SetSkin("mailbox", "nachtelf")
eq(A.SkinId(def), "nachtelf", "gewaehlt: Nachtelf")
eq(A.Cfg("mailbox").skin, "nachtelf", "gespeichert")
eq(f.tex.texture:find("Mailbox2%.tga$") ~= nil, true, "Nachtelf auf Platte 2")
l, r, t, b = A.UV(def, 1); near(t, (1 * 341 + 2) / 1024, "Nachtelf: zweite Zeile")
A.SetSkin("mailbox", "gibtesnicht")
eq(A.SkinId(def), "horde", "unbekanntes Aussehen faellt auf die Vorgabe zurueck")
A.SetSkin("mailbox", nil)
eq(A.Cfg("mailbox").skin, nil, "Automatik")

-- Post kommt an: sichtbar, Bilder 1 bis 4 laufen, Ton
newMail = true
events.UPDATE_PENDING_MAIL()
eq(f.shown, true, "mit Post sichtbar")
eq(f.target, 4, "Ziel Bild 4")
eq(f.cur, 1, "startet bei Bild 1")
eq(#sounds, 1, "ein Ton")
eq(sounds[1][1], "id", "Standardton ist der Wecker")
f.scripts.OnUpdate(f, 0.13)
eq(f.cur, 2, "nach 1/8 s Bild 2")
f.scripts.OnUpdate(f, 0.4)
eq(f.cur, 4, "Bild 4 erreicht")
f.scripts.OnUpdate(f, 1)
eq(f.cur, 4, "bleibt auf Bild 4")

-- gleiche Meldung ein zweites Mal: kein neuer Ton
events.UPDATE_PENDING_MAIL()
eq(#sounds, 1, "kein doppelter Ton")

-- Post gelesen: rueckwaerts 4 nach 1, dann unsichtbar
newMail = false
events.UPDATE_PENDING_MAIL()
eq(f.target, 1, "Ziel Bild 1")
eq(f.shown, true, "bis zum Ende sichtbar")
f.scripts.OnUpdate(f, 1)
eq(f.cur, 1, "Bild 1 erreicht")
eq(f.shown, false, "danach unsichtbar")

-- "auch ohne Post zeigen"
A.Cfg("mailbox").showEmpty = true
A.Refresh("mailbox")
eq(f.shown, true, "ohne Post sichtbar, wenn gewuenscht")
A.Cfg("mailbox").showEmpty = false
A.Refresh("mailbox")

-- Anmelden mit vorhandener Post: sofort Bild 4, kein Ton
newMail = true
A.mailbox.has = false
events.PLAYER_ENTERING_WORLD()
eq(f.cur, 4, "Anmelden: sofort Bild 4")
eq(f.shown, true, "Anmelden: sichtbar")
eq(#sounds, 1, "Anmelden: kein Ton")

-- Auszeit bis zum Besuch
A.Snooze("mailbox", nil)
eq(f.shown, false, "ausgeblendet bis Besuch")
newMail = false; events.UPDATE_PENDING_MAIL(); newMail = true; events.UPDATE_PENDING_MAIL()
eq(#sounds, 1, "ausgeblendet: kein Ton")
events.MAIL_SHOW()
eq(f.shown, true, "Briefkastenbesuch hebt das Ausblenden auf")

-- Auszeit 60 Minuten mit Erinnerung
A.Snooze("mailbox", 60)
eq(f.shown, false, "60 Minuten ausgeblendet")
now = now + 61 * 60
-- Treiber laeuft ueber OnUpdate des zweiten Frames: Ablauf direkt pruefen
A.Unsnooze("mailbox", true)
eq(f.shown, true, "nach Ablauf wieder sichtbar")
eq(#sounds, 2, "Erinnerung mit Ton")

-- Ton aus / eigene Datei / Rueckfall
A.SoundCfg().mode = "off"; A.PlaySound(); eq(#sounds, 2, "Ton aus")
A.SoundCfg().mode = "file"; A.SoundCfg().file = "post.ogg"; A.PlaySound()
eq(sounds[3][1], "file", "eigene Datei"); eq(sounds[3][2], "Interface\\AddOns\\Freewood-Sounds\\post.ogg", "Pfad der eigenen Datei")

-- Groesse und Position
A.Cfg("mailbox").scale = 200; A.Size("mailbox")
eq(f.w, 192, "Breite bei 200 %"); eq(f.h, 256, "Hoehe bei 200 %")
A.Cfg("mailbox").pos = { x = 50, y = 60 }; A.Place("mailbox")
eq(f.points[1][1], "BOTTOMLEFT", "gespeicherte Position"); eq(f.points[1][4], 50, "x")
A.ResetPosition("mailbox")
eq(A.Cfg("mailbox").pos, nil, "Position zurueckgesetzt")
eq(f.points[1][1], "BOTTOMRIGHT", "Standardplatz ohne Leisten: unten rechts")

-- Verschieben nur mit Umschalt
_G.IsShiftKeyDown = function() return false end
f.scripts.OnDragStart(f)
eq(f.moving, nil, "ohne Umschalt kein Verschieben")

print(string.format("anim_test: %d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
