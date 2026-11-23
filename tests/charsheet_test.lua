-- Test 0.61.0: Charakteransicht (Aufteilung je Bildschirm, Taschenraster, Werte, Suche, Aufbau, Taste C)
-- texlua tests/charsheet_test.lua
local events = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), settings = {} }
function FW:RegisterEvent(ev, fn) events[ev] = fn return true end
function FW:AddLocale(_, t) for k, v in pairs(t) do rawset(FW.L, k, v) end end
FW.Util = { IsSecret = function(v) return v == "SECRET" end }
_G.Freewood = FW
_G.unpack = _G.unpack or table.unpack

-- Attrappen für Rahmen
local M = {}
M.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.HookScript(f, k, fn) M.SetScript(f, k, fn) end
function M.Show(f) f.shown = true if f.scripts and f.scripts.OnShow then f.scripts.OnShow(f) end end
function M.Hide(f) f.shown = false end
function M.IsShown(f) return f.shown == true end
function M.SetShown(f, v) f.shown = v and true or false end
function M.GetWidth(f) return f.w or 0 end
function M.GetHeight(f) return f.h or 0 end
function M.SetSize(f, w, h) f.w, f.h = w, h end
function M.SetWidth(f, w) f.w = w end
function M.SetHeight(f, h) f.h = h end
function M.SetAllPoints(f, o) if o then f.w, f.h = o.w, o.h end end
function M.SetID(f, id) f.id = id end
function M.GetID(f) return f.id end
function M.GetParent(f) return f.parent end
function M.GetText(f) return f.text or "" end
function M.SetText(f, t) f.text = t end
function M.GetFrameLevel() return 1 end
function M.SetTexture(f, t) f.tex = t end
function M.SetTexCoord(f, ...) f.coord = { ... } end
function M.CreateTexture() return setmetatable({}, M) end
-- wie im Spiel: SetText auf eine Zeile ohne Schrift bricht ab ("Font not set", 0.61.1)
local FS = setmetatable({}, { __index = M })
FS.__index = function(t, k) if FS[k] then return FS[k] end return M.__index(t, k) end
function FS.SetText(f, t) if not f.font then error("FontString:SetText(): Font not set") end f.text = t end
function FS.SetFormattedText(f, ...) FS.SetText(f, string.format(...)) end
function M.CreateFontString(_, _, _, template) return setmetatable({ font = template ~= nil }, FS) end
local created = {}
_G.CreateFrame = function(kind, name, parent, template)
    local f = setmetatable({ kind = kind, parent = parent, template = template }, M)
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
_G.UIParent = setmetatable({ w = 1835, h = 768 }, M)   -- 3440 x 1440 bei Skalierung
_G.UISpecialFrames = {}
FW.UI = {
    SetFont = function(fs) fs.font = true end, Color = function() return 1, 1, 1 end,
    CreateCheckbox = function(_, _, g) g() return setmetatable({}, M) end,
    RegisterSettingsSection = function(_, id, def) FW.section = def end,
    CreateSection = function() local f = setmetatable({}, M) return f, { Add = function() end } end,
    CreateDropdown = function(_, _, _, o)
        local d = setmetatable({ opts = o }, M)
        function d:SetValue(v) self.value = v self.text = o.textOf(v) end
        FW.dropOpts = FW.dropOpts or {}
        FW.dropOpts[#FW.dropOpts + 1] = o
        FW.bgDropOpts = FW.dropOpts[1]
        FW.frameDropOpts = FW.dropOpts[2]
        return d
    end,
}

-- Spielwerte
_G.UnitStat = function(_, i) local t = { { 50, 55, 5, 0 }, { 120, 132, 12, 0 }, { 111, 111, 0, 0 }, { 68, 68, 0, 0 }, { 90, 81, 0, -9 } } return 0, t[i][2], t[i][3], t[i][4] end
_G.UnitHealthMax = function() return 1477 end
_G.UnitPowerMax = function() return 1710 end
_G.GetUnitSpeed = function() return 0, 9.1 end
_G.UnitDamage = function() return 92, 111 end
_G.UnitAttackPower = function() return 200, 79, 0 end
_G.UnitAttackSpeed = function() return 2.6 end
_G.GetCritChance = function() return 13.6 end
_G.UnitRangedDamage = function() return 3.0, 131, 164 end
_G.UnitRangedAttackPower = function() return 181, 0, 0 end
_G.GetRangedCritChance = function() return "SECRET" end     -- im Kampf geschützt
_G.UnitArmor = function() return 900, 942 end
_G.GetDodgeChance = function() return 8.9 end
_G.UnitResistance = function(_, i) return 0, i * 5 end
_G.UnitClass = function() return "Jägerin", "HUNTER" end
_G.UnitLevel = function() return 36 end
_G.UnitName = function() return "Pinky" end
local raceFile = "NightElf"
_G.UnitRace = function() return "Nachtelfe", raceFile end
local classFile = "HUNTER"
_G.UnitClass = function() return "Jägerin", classFile end
_G.GetMoney = function() return 124783 end
_G.GetInventorySlotInfo = function(n) if n == "AmmoSlot" then return 0, "ammo" end return #n, "empty-" .. n end
local bagSlots = { [0] = 16, 10, 10, 0, 0, 4 }
-- Tasche 2 ist ein Köcher (Taschenart 1), Tasche 5 die Reagenzientasche
local items = {
    ["0:1"] = { iconFileID = 1, stackCount = 1, itemID = 10, quality = 2, hyperlink = "|cff1eff00|Hitem:10|h[Grüner Hut]|h|r" },
    ["0:2"] = { iconFileID = 2, stackCount = 5, itemID = 20, quality = 1, hyperlink = "|cffffffff|Hitem:20|h[Brot]|h|r" },
    ["0:3"] = { iconFileID = 3, stackCount = 20, itemID = 30, quality = 1, hyperlink = "|cffffffff|Hitem:30|h[Leinenstoff]|h|r" },
    ["0:4"] = { iconFileID = 4, stackCount = 1, itemID = 40, quality = 0, hyperlink = "|cff9d9d9d|Hitem:40|h[Zerbrochener Zahn]|h|r" },
    ["0:5"] = { iconFileID = 5, stackCount = 3, itemID = 20, quality = 1, hyperlink = "|cffffffff|Hitem:20|h[Apfel]|h|r" },
    ["1:1"] = { iconFileID = 6, stackCount = 1, itemID = 60, quality = 1, hyperlink = "|cffffffff|Hitem:60|h[Seltsamer Brief]|h|r" },
    ["2:1"] = { iconFileID = 7, stackCount = 200, itemID = 70, quality = 1, hyperlink = "|cffffffff|Hitem:70|h[Pfeil]|h|r" },
    ["5:1"] = { iconFileID = 8, stackCount = 10, itemID = 30, quality = 1, hyperlink = "|cffffffff|Hitem:30|h[Leinenstoff]|h|r" },
}
local classOf = { [10] = 4, [20] = 0, [30] = 7, [40] = 15, [60] = 12, [70] = 6 }
_G.C_Item = { GetItemInfoInstant = function(id) return id, "", "", "", 0, classOf[id] end }
_G.C_Container = {
    GetContainerNumSlots = function(b) return bagSlots[b] or 0 end,
    GetContainerItemInfo = function(b, s) return items[b .. ":" .. s] end,
    GetContainerNumFreeSlots = function(b) return 0, (b == 2) and 1 or 0 end,
    GetBagName = function(b) return b == 2 and "Leichter Köcher" or "Tasche" end,
}

assert(loadfile("UI/CharacterSheet.lua"))("Freewood-Core", FW)
local CS = FW.CharSheet
assert(CS and _G.Freewood_ToggleCharSheet, "geladen, Taste bekannt")

-- Aufteilung: 21:9 und 16:9, alles innerhalb, nichts überlappt
for _, size in ipairs({ { 1835, 768 }, { 1365, 768 }, { 1024, 768 } }) do
    local W, H = size[1], size[2]
    local lay = CS.ComputeLayout(W, H)
    local c, s, b = lay.char, lay.stats, lay.bags
    assert(c.x + c.w < s.x and s.x + s.w < b.x, "Spalten nebeneinander " .. W)
    assert(b.x + b.w <= W - 60 * lay.k + 1, "Taschen im Rahmen " .. W)
    assert(lay.model.y + lay.model.h + lay.S * 1.2 < H, "Waffenreihe passt " .. W)
    assert(b.w >= 6 * (lay.S + 4), "mindestens 6 Taschenspalten " .. W)
end
local wide, narrow = CS.ComputeLayout(1835, 768), CS.ComputeLayout(1365, 768)
assert(wide.bags.w > narrow.bags.w + 300, "Ultrawide: Taschen bekommen den Platz")

-- Taschenraster: scrollen (feste Größe) oder wachsen (alle sichtbar)
local cols, size = CS.BagGrid(400, 200, 80, 60, false)
assert(cols == 6 and size == 60, "scrollend: feste Größe")
cols, size = CS.BagGrid(400, 200, 80, 60, true)
assert(math.ceil(80 / cols) * (size + 4) - 4 <= 200 and size < 60, "wachsend: alle passen " .. size)

-- Werte
local st = CS.Stats()
assert(st[1].title == "Allgemein" and st[1].rows[1][2] == "1.477" and st[1].rows[3][2] == "130%", "Allgemein")
assert(st[2].rows[2][2]:find("132", 1, true) and st[2].rows[2][2]:find("40ff40", 1, true), "Beweglichkeit grün (Buff)")
assert(st[2].rows[5][2]:find("ff6060", 1, true), "Willenskraft rot (gesenkt)")
assert(st[3].title == "Fernkampf", "Jäger: Fernkampf zuerst")
assert(st[3].rows[1][2] == "131-164" and st[3].rows[2][2] == "181", "Fernkampfwerte")
assert(st[3].rows[3][2] == "–", "geschützter Wert = –")
local last = st[#st]
assert(last.title == "Widerstände" and last.rows[1][2] == "10", "Widerstände zuletzt")
local order = CS.ClassOrder("MAGE")
assert(order[1] == "spell", "Magier: Zauber zuerst")

-- 0.62.0: Kategorien, Spezialtaschen, Sortierung
local secs = CS.Sections()
local ids = {}
for _, sec in ipairs(secs) do ids[#ids + 1] = sec.id .. "=" .. #sec.entries end
assert(table.concat(ids, ",") == "gear=1,consumable=2,trade=1,quest=1,junk=1,free=20,ammo=10,reagent=4", table.concat(ids, ","))
assert(secs[7].special and secs[7].used == 1 and secs[7].total == 10, "Köcher eigener Bereich mit Füllstand")
CS.Opts().sort.consumable = "name"
secs = CS.Sections()
assert(ItemNameOf == nil and secs[2].entries[1].info.hyperlink:find("Apfel", 1, true), "nach Name: Apfel vor Brot")
CS.Opts().sort.consumable = "count"
secs = CS.Sections()
assert(secs[2].entries[1].info.stackCount == 5, "nach Anzahl")
CS.Opts().sort.consumable = nil
CS.Opts().categories = false
secs = CS.Sections()
assert(secs[1].plain and #secs[1].entries == 26 and secs[2].id == "ammo", "ohne Kategorien: ein Raster, Spezialtaschen bleiben getrennt")
CS.Opts().categories = true
-- Wachsen: alle Abschnitte passen in die Höhe
local fitCols, fitSize = CS.FitGrid(400, 500, CS.Sections(), 60, true)
assert(CS.SectionsHeight(CS.Sections(), fitCols, fitSize) <= 500 and fitSize < 60, "wachsend passt " .. fitSize)

-- Gold mit Münzsymbolen
local mt = CS.MoneyText(64333)
assert(mt:find("^6|T", 1) and mt:find("43|T", 1, true) and mt:find("33|T", 1, true), mt)
assert(CS.MoneyText(5):find("^5|T"), "nur Kupfer")

-- Suche
local info = { hyperlink = "|cff1eff00|Hitem:1|h[Grüner Hut]|h|r" }
assert(CS.MatchSearch(info, "hut") and not CS.MatchSearch(info, "schwert") and CS.MatchSearch(nil, ""), "Suche")

-- Aufbau und Öffnen
_G.Freewood_ToggleCharSheet()
local win = _G.FreewoodCharacterSheet
assert(win and win.shown, "Fenster offen")
assert(_G.UISpecialFrames[1] == "FreewoodCharacterSheet", "Esc schließt")
local slots = 0
for _, b in ipairs(win.slots) do if b then slots = slots + 1 end end
assert(slots == 20, "19 Plätze + Munition: " .. slots)
local bagButtons = 0
for _, f in ipairs(created) do if f.template == "ContainerFrameItemButtonTemplate" then bagButtons = bagButtons + 1 end end
assert(bagButtons == 40, "Blizzards Taschenknöpfe für alle Plätze: " .. bagButtons)
local p = win.bagButtons["1:3"].parent
assert(p.id == 1 and win.bagButtons["1:3"].id == 3, "Tasche und Platz über IDs (Blizzards Knopf liest sie selbst)")
local statRows = 0
for _, r in ipairs(win.statRows) do if r.shown and r.l.text and r.l.text ~= "" then statRows = statRows + 1 end end
assert(statRows > 20, "Werte eingetragen: " .. statRows)
assert(win.name.text == "Pinky" and win.level.text == "Stufe 36 · Jägerin", "Namensschild")
-- Einklappen: Plätze der Kategorie verschwinden, Überschrift bleibt
local freeKey = "0:10"
assert(win.bagButtons[freeKey].shown, "freier Platz sichtbar")
win.bagHeads.free.scripts.OnClick()
assert(not win.bagButtons[freeKey].shown and win.bagHeads.free.shown and CS.Opts().collapsed.free, "eingeklappt und gemerkt")
win.bagHeads.free.scripts.OnClick()
assert(win.bagButtons[freeKey].shown, "wieder ausgeklappt")
-- Sortierknopf schaltet durch
win.bagHeads.trade.sort.scripts.OnClick()
assert(CS.Opts().sort.trade == "quality", "Sortierung weiter geschaltet")
for _ = 1, 3 do win.bagHeads.trade.sort.scripts.OnClick() end
assert(CS.Opts().sort.trade == nil, "nach einer Runde wieder wie in den Taschen")
assert(win.bagHeads.ammo.text.text:find("10", 1, true) and win.bagHeads.ammo.text.text:find("Köcher", 1, true), win.bagHeads.ammo.text.text)
_G.Freewood_ToggleCharSheet()
assert(not win.shown, "zweiter Druck schließt")

-- Taste C (nur wenn eingeschaltet, nie im Kampf)
local over = {}
_G.SetOverrideBinding = function(_, _, key, cmd) over[key] = cmd end
_G.ClearOverrideBindings = function() for k in pairs(over) do over[k] = nil end end
_G.GetBindingKey = function(cmd) if cmd == "TOGGLECHARACTER0" then return "C" end end
local fight = false
_G.InCombatLockdown = function() return fight end
CS.ApplyBinding()
assert(over.C == nil, "Standard: C bleibt bei Blizzard")
CS.Opts().takeC = true
fight = true
CS.ApplyBinding()
assert(over.C == nil and CS.bindPending, "im Kampf aufgeschoben")
fight = false
events.PLAYER_REGEN_ENABLED()
assert(over.C == "FREEWOOD_CORE_CHARSHEET", "danach C auf die Charakteransicht")
CS.Opts().takeC = false
CS.ApplyBinding()
assert(over.C == nil, "wieder aus")

-- 0.63.0: Hintergründe
local a, b, c, d = CS.CoverCoords(400, 400, 0.5, true)
assert(a == 0 and b == 1 and c == 0.5 and d == 1, "breiter als das Bild: oben abschneiden, Boden bleibt")
a, b, c, d = CS.CoverCoords(100, 400, 0.5, true)
assert(c == 0 and d == 1 and math.abs(a - 0.25) < 1e-9 and math.abs(b - 0.75) < 1e-9, "schmaler: seitlich mittig")
a, b, c, d = CS.CoverCoords(2000, 1000, 1, false)
assert(a == 0 and b == 1 and math.abs(c - 0.25) < 1e-9 and math.abs(d - 0.75) < 1e-9, "Oberfläche: mittig, unverzerrt")
assert(CS.RaceFile("Scourge") == "RaceUndead" and CS.RaceFile("BloodElf") == "RaceElf" and CS.RaceFile("Goblin") == nil, "Rassen")
assert(CS.Opts().bg == "leatherDark" and CS.Opts().race == true, "Standard: dunkles Leder, Rassenbild an")
_G.Freewood_ToggleCharSheet()
assert(win.forest.tex:find("RaceElf.tga", 1, true), "Nachtelf: Elfenbild " .. tostring(win.forest.tex))
assert(win.leather.tex:find("BgLeatherDark.tga", 1, true), "dunkles Leder")
assert(win.bgDrop and FW.bgDropOpts and #FW.bgDropOpts.getOptions() == 4, "Auswahl mit 4 Hintergründen")
assert(win.bgDrop.text == "Dunkles Leder" or win.bgDrop.text == "CS_BG_leatherDark", tostring(win.bgDrop.text))
FW.bgDropOpts.onChange("parchment")
assert(CS.Opts().bg == "parchment" and win.leather.tex:find("BgParchment.tga", 1, true), "Pergament gewählt")
FW.bgDropOpts.onChange("classic")
assert(win.leather.tex:find("Leather.tga", 1, true) and win.leather.coord[1] == 0.02, "klassisch mit altem Ausschnitt")
raceFile = "Goblin"
CS.ApplyRace()
assert(win.forest.tex:find("Forest.tga", 1, true) and win.forest.coord[3] == 101 / 1024, "ohne Bild: Wald")
raceFile = "Orc"
CS.Opts().race = false
CS.ApplyRace()
assert(win.forest.tex:find("Forest.tga", 1, true), "Rassenbild aus: Wald")
CS.Opts().race = true
CS.ApplyRace()
assert(win.forest.tex:find("RaceOrc.tga", 1, true), "Orc")
-- 0.66.0: Rahmen aus Kacheln, Auswahl Rasse | Klasse | Pinky
local a1, b1, c1, d1, e1, f1, g1, h1 = CS.EdgeCoords("right", 0.5)
assert(a1 == 0 and b1 == 0 and c1 == 0 and d1 == 0.5 and e1 == 1 and f1 == 0 and g1 == 1 and h1 == 0.5, "rechts: senkrecht, halbes Stück")
a1, b1, c1, d1, e1, f1, g1, h1 = CS.EdgeCoords("top", 1)
assert(a1 == 1 and b1 == 0 and c1 == 0 and d1 == 0 and e1 == 1 and f1 == 1 and g1 == 0 and h1 == 1, "oben: gedreht")
a1, b1, c1, d1, e1, f1, g1, h1 = CS.EdgeCoords("left", 1)
assert(a1 == 1 and b1 == 1 and g1 == 0 and h1 == 0, "links: 180 Grad")
a1, b1, c1, d1, e1, f1, g1, h1 = CS.EdgeCoords("bottom", 1)
assert(a1 == 0 and b1 == 1 and g1 == 1 and h1 == 0, "unten: im Uhrzeigersinn")
local pieces = CS.EdgePieces(250, 100)
assert(#pieces == 3 and pieces[3].a == 200 and math.abs(pieces[3].frac - 0.5) < 1e-9, "Stücke: zwei ganze, ein halbes")
assert(#CS.EdgePieces(0, 100) == 0, "keine Länge, keine Stücke")
assert(CS.RaceFrame("Scourge") == nil and CS.RaceFrame("MagharOrc") == "Orc" and CS.RaceFrame("X", "Skyborne") == "Skyborne", "Rassenrahmen")
assert(CS.ClassFrame("HUNTER") == "Hunter" and CS.ClassFrame("WARRIOR") == nil, "Klassenrahmen")
raceFile = "Orc"
local ch = CS.FrameChoices()
assert(#ch == 3 and ch[1].id == "race" and ch[1].file == "Orc" and ch[2].file == "Hunter" and ch[3].file == "Pinky", "Orc-Jäger: Orc, Jäger, Pinky")
CS.Opts().frame = nil
CS.ApplyFrame()
assert(win.frame.style == "Orc", "Standard: Rasse")
assert(win.frame.corners.TR.tex:find("Frames\\OrcCorner.tga", 1, true), "Ecke gesetzt")
assert(FW.frameDropOpts and #FW.frameDropOpts.getOptions() == 3, "Rahmen-Auswahl mit 3 Einträgen")
FW.frameDropOpts.onChange("class")
assert(win.frame.style == "Hunter" and CS.Opts().frame == "class", "Klasse gewählt")
FW.frameDropOpts.onChange("pinky")
assert(win.frame.style == "Pinky", "Pinky gewählt")
classFile, raceFile = "WARRIOR", "Scourge"
CS.Opts().frame = "class"
CS.ApplyFrame()
assert(#CS.FrameChoices() == 1 and win.frame.style == "Pinky", "Untoter Krieger: nur Pinky")
classFile, raceFile = "HUNTER", "NightElf"
CS.Opts().frame = nil
CS.ApplyFrame()
assert(win.frame.style == "NightElf", "Nachtelf")
-- Ecken: links gespiegelt, unten aufrecht
win.frame.w, win.frame.h = 2000, 1000
win.frame:SetSliceScale(0.5)
local tl = win.frame.corners.TL.coord
assert(tl and tl[1] == 1 and tl[2] == 0 and tl[3] == 0 and tl[4] == 1, "links gespiegelt")
local br = win.frame.corners.BR.coord
assert(br[1] == 0 and br[2] == 1 and br[3] == 0 and br[4] == 1, "unten rechts wie oben rechts")
assert(#win.frame.pools.top > 0 and #win.frame.pools.left > 0, "Seiten aus Stücken")

-- 0.64.0: Umschalter Werte | Ausrüstung
assert(win.statsScroll.shown ~= false and not win.gearHost.shown, "Standard: Werte")
local built = 0
FW.GearUI = { Build = function(p) built = built + 1 return { parent = p, Refresh = function() end } end }
win.viewGear.scripts.OnClick()
assert(CS.Opts().view == "gear" and win.gearHost.shown and win.statsScroll.shown == false and built == 1, "Ausrüstung gezeigt")
win.viewStats.scripts.OnClick()
win.viewGear.scripts.OnClick()
assert(built == 1, "nur einmal gebaut")
win.viewStats.scripts.OnClick()
assert(CS.Opts().view == "stats" and win.statsScroll.shown, "zurück zu den Werten")
CS.Opts().bg = "gibtsnicht"
assert(CS.Opts().bg == "leatherDark", "unbekannter Wert -> Standard")
_G.Freewood_ToggleCharSheet()

-- 0.64.1: zwei Aufträge kurz nacheinander (Taschen, dann Ausrüstung) gehen beide durch
local timers, ranA, ranB = {}, 0, 0
local oldTimer = _G.C_Timer
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function A() ranA = ranA + 1 end
local function B() ranB = ranB + 1 end
CS.Soon(A) CS.Soon(B) CS.Soon(A)
assert(#timers == 1, "ein Zeitgeber")
timers[1]()
assert(ranA == 1 and ranB == 1, "beide ausgeführt, keiner doppelt")
CS.Soon(B)
assert(#timers == 2, "danach neuer Zeitgeber")
_G.C_Timer = oldTimer

-- Einstellungen unter Design
assert(FW.section and FW.section.category == "design", "Einstellungen > Design")
FW.section.build(setmetatable({}, M))
print("charsheet_test: ok")
