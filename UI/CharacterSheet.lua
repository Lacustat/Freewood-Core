-- Freewood-Core: Charakteransicht im Vollbild (seit 0.61.0)
--
-- Vollbild-Fenster im Freewood-Wald-Design (Grafiken von Lacustat in Media/Character, keine Blizzard-Grafiken):
--   links   Namensschild, 3D-Modell des Charakters vor dem Waldbild (ziehen = drehen, Mausrad = zoomen),
--           8 Plätze links, 8 rechts, darunter Haupthand, Nebenhand, Fernkampf, Munition
--   Mitte   Charakterwerte des gespielten Charakters (Allgemein, Primär, dann je nach Klasse Fernkampf / Nahkampf /
--           Zauber, Verteidigung, Widerstände), scrollbar mit Blizzards Scrollleiste; im Kampf geschützte Werte = "–"
--   rechts  Taschen (Rucksack, 4 Taschen, Reagenzientasche) mit Blizzards eigenen Taschenknöpfen
--           (ContainerFrameItemButtonTemplate: benutzen, verschieben, verkaufen ohne Taint), Suche, Gold;
--           Haken "Raster wächst mit" (sonst scrollt es)
-- Der Außenrahmen (0.62.2: Holzleisten mit Eisenbeschlägen, 4 Ecken + 4 Leisten von Lacustat) passt sich jeder Bildschirmgröße an
-- (16:9, 21:9 ...). Öffnen: Reiter mit Freewood-Logo am Blizzard-Charakterfenster, Taste (Tastaturbelegung >
-- Freewood > Charakteransicht) oder auf Wunsch die Taste des Charakterfensters (C). Esc schließt.
-- Einstellungen: Einstellungen > Design > Charakteransicht.

local ADDON, FW = ...
local G = _G
local UI = FW.UI
if not UI then return end

local CS = {}
FW.CharSheet = CS

local MEDIA = "Interface\\AddOns\\Freewood-Core\\Media\\Character\\"
CS.MEDIA = MEDIA
local LOGO = "Interface\\AddOns\\Freewood-Core\\Media\\FreeWood_Logo.tga"

FW:AddLocale("enUS", {
    CS_TITLE = "Character view", CS_TAB_TIP = "Freewood character view (full screen)",
    CS_LEVEL = "Level %d · %s", CS_BAGS = "Bags", CS_STATS = "Character stats", CS_SEARCH = "Search",
    CS_GROW = "Grid grows with the bags (otherwise it scrolls)", CS_CATS = "Categories",
    CS_C_gear = "Equipment", CS_C_consumable = "Consumables", CS_C_trade = "Trade goods", CS_C_recipe = "Recipes",
    CS_C_quest = "Quest", CS_C_other = "Keys & misc", CS_C_junk = "Junk", CS_C_free = "Free", CS_C_all = "Items",
    CS_C_ammo = "Ammo", CS_C_soul = "Soul shards", CS_C_reagent = "Reagent bag",
    CS_SORT_bag = "As in bags", CS_SORT_quality = "Quality", CS_SORT_name = "Name", CS_SORT_count = "Count",
    CS_SORT_TIP = "Click: change the order of this category (as in bags, quality, name, count)",
    CS_HEAD_TIP = "Click: fold or unfold this category",
    CS_GENERAL = "General", CS_PRIMARY = "Primary attributes", CS_MELEE = "Melee", CS_RANGED = "Ranged",
    CS_SPELL = "Spells", CS_DEFENSE = "Defense", CS_RESIST = "Resistances",
    CS_HEALTH = "Health", CS_MANA = "Mana", CS_SPEED = "Movement speed",
    CS_STR = "Strength", CS_AGI = "Agility", CS_STA = "Stamina", CS_INT = "Intellect", CS_SPI = "Spirit",
    CS_DAMAGE = "Damage", CS_AP = "Attack power", CS_ATKSPEED = "Speed", CS_CRIT = "Critical strike",
    CS_HIT = "Hit chance", CS_SPELLDMG = "Bonus damage", CS_HEAL = "Bonus healing", CS_SPELLCRIT = "Spell crit",
    CS_REGEN = "Mana regeneration", CS_ARMOR = "Armor", CS_DODGE = "Dodge", CS_PARRY = "Parry", CS_BLOCK = "Block",
    CS_FIRE = "Fire", CS_NATURE = "Nature", CS_FROST = "Frost", CS_SHADOW = "Shadow", CS_ARCANE = "Arcane",
    CS_STATS_SHORT = "Stats", CS_GEAR_SHORT = "Equipment",
    CS_SET_TITLE = "Character view",
    CS_SET_TAB = "Show the Freewood tab on the character window",
    CS_SET_C = "The character window key (C) opens the Freewood character view",
    CS_FRAME = "Frame", CS_FRAME_Pinky = "Pinky",
    CS_BG = "Background", CS_BG_TIP = "Background of the character view",
    CS_BG_leatherDark = "Dark leather", CS_BG_parchment = "Parchment", CS_BG_leatherRed = "Red leather", CS_BG_classic = "Classic leather",
    CS_SET_RACE = "Race background behind the character (otherwise the Freewood forest)",
    CS_SET_INFO = "Full-screen character view in the Freewood forest design. Opens via the tab with the Freewood logo on Blizzard's character window, via its own key (Key Bindings > Freewood, needs a full game restart once) or optionally via C. Esc closes it.",
})
FW:AddLocale("deDE", {
    CS_TITLE = "Charakteransicht", CS_TAB_TIP = "Freewood-Charakteransicht (Vollbild)",
    CS_LEVEL = "Stufe %d · %s", CS_BAGS = "Taschen", CS_STATS = "Charakterwerte", CS_SEARCH = "Suchen",
    CS_GROW = "Raster wächst mit den Taschen (sonst scrollt es)", CS_CATS = "Kategorien",
    CS_C_gear = "Ausrüstung", CS_C_consumable = "Verbrauchbar", CS_C_trade = "Handwerk", CS_C_recipe = "Rezepte",
    CS_C_quest = "Quest", CS_C_other = "Schlüssel & Sonstiges", CS_C_junk = "Plunder", CS_C_free = "Frei", CS_C_all = "Gegenstände",
    CS_C_ammo = "Munition", CS_C_soul = "Seelensplitter", CS_C_reagent = "Reagenzientasche",
    CS_SORT_bag = "Wie in den Taschen", CS_SORT_quality = "Qualität", CS_SORT_name = "Name", CS_SORT_count = "Anzahl",
    CS_SORT_TIP = "Klick: Reihenfolge dieser Kategorie ändern (wie in den Taschen, Qualität, Name, Anzahl)",
    CS_HEAD_TIP = "Klick: Kategorie ein- oder ausklappen",
    CS_GENERAL = "Allgemein", CS_PRIMARY = "Primäre Eigenschaften", CS_MELEE = "Nahkampf", CS_RANGED = "Fernkampf",
    CS_SPELL = "Zauber", CS_DEFENSE = "Verteidigung", CS_RESIST = "Widerstände",
    CS_HEALTH = "Gesundheit", CS_MANA = "Mana", CS_SPEED = "Bewegungstempo",
    CS_STR = "Stärke", CS_AGI = "Beweglichkeit", CS_STA = "Ausdauer", CS_INT = "Intelligenz", CS_SPI = "Willenskraft",
    CS_DAMAGE = "Schaden", CS_AP = "Angriffskraft", CS_ATKSPEED = "Tempo", CS_CRIT = "Kritische Trefferchance",
    CS_HIT = "Trefferchance", CS_SPELLDMG = "Bonusschaden", CS_HEAL = "Bonusheilung", CS_SPELLCRIT = "Zauberkrit",
    CS_REGEN = "Manaregeneration", CS_ARMOR = "Rüstung", CS_DODGE = "Ausweichen", CS_PARRY = "Parieren", CS_BLOCK = "Blocken",
    CS_FIRE = "Feuer", CS_NATURE = "Natur", CS_FROST = "Frost", CS_SHADOW = "Schatten", CS_ARCANE = "Arkan",
    CS_STATS_SHORT = "Werte", CS_GEAR_SHORT = "Ausrüstung",
    CS_SET_TITLE = "Charakteransicht",
    CS_SET_TAB = "Freewood-Reiter am Charakterfenster zeigen",
    CS_SET_C = "Die Taste des Charakterfensters (C) öffnet die Freewood-Charakteransicht",
    CS_FRAME = "Rahmen", CS_FRAME_Pinky = "Pinky",
    CS_BG = "Hintergrund", CS_BG_TIP = "Hintergrund der Charakteransicht",
    CS_BG_leatherDark = "Dunkles Leder", CS_BG_parchment = "Pergament", CS_BG_leatherRed = "Rotes Leder", CS_BG_classic = "Leder klassisch",
    CS_SET_RACE = "Rassen-Hintergrund hinter dem Charakter (sonst der Freewood-Wald)",
    CS_SET_INFO = "Charakteransicht im Vollbild im Freewood-Wald-Design. Öffnen über den Reiter mit dem Freewood-Logo am Blizzard-Charakterfenster, über eine eigene Taste (Tastaturbelegung > Freewood, einmal kompletter Spielneustart nötig) oder auf Wunsch über C. Esc schließt.",
})

local function L() return FW.L end

------------------------------------------------------------------------
-- Hintergründe (0.63.0): Oberfläche wählbar, hinter dem Modell je Rasse
------------------------------------------------------------------------

-- Oberflächen-Hintergründe; classic = altes Leder mit festem Ausschnitt
CS.BACKGROUNDS = {
    { id = "leatherDark", file = "BgLeatherDark.tga" },
    { id = "parchment", file = "BgParchment.tga" },
    { id = "leatherRed", file = "BgLeatherRed.tga" },
    { id = "classic", file = "Leather.tga", crop = { 0.02, 0.70, 0.14, 0.72 } },
}
CS.BG_BY_ID = {}
for _, b in ipairs(CS.BACKGROUNDS) do CS.BG_BY_ID[b.id] = b end

-- Rasse (Dateiname aus UnitRace) -> Bild; alle Elfen teilen sich ein Bild, ohne Bild: Wald
CS.RACE_BG = {
    Gnome = "RaceGnome", Mechagnome = "RaceGnome",
    Dwarf = "RaceDwarf", DarkIronDwarf = "RaceDwarf",
    Human = "RaceHuman", KulTiran = "RaceHuman",
    NightElf = "RaceElf", BloodElf = "RaceElf", HighElf = "RaceElf", VoidElf = "RaceElf", Nightborne = "RaceElf",
    Troll = "RaceTroll", ZandalariTroll = "RaceTroll",
    Tauren = "RaceTauren", HighmountainTauren = "RaceTauren",
    Scourge = "RaceUndead", Undead = "RaceUndead",
    Orc = "RaceOrc", MagharOrc = "RaceOrc",
}
CS.RACE_ASPECT = 0.5      -- Rassenbilder 512 x 1024
CS.FOREST_CROP = { 0, 1, 101 / 1024, 923 / 1024 }

-- Datei des Bildes hinter dem Modell (nil = Wald)
function CS.RaceFile(raceFile)
    if type(raceFile) ~= "string" then return nil end
    return CS.RACE_BG[raceFile]
end

-- Ausschnitt, der ein Rechteck w x h füllt, ohne das Bild zu verzerren.
-- aspect = Breite/Höhe des Bildes, keepBottom = unten bündig (Boden bleibt sichtbar)
function CS.CoverCoords(w, h, aspect, keepBottom)
    if not w or not h or w <= 0 or h <= 0 then return 0, 1, 0, 1 end
    local ra = w / h
    if ra >= aspect then
        local v = aspect / ra                 -- sichtbarer Anteil der Höhe
        if keepBottom then return 0, 1, 1 - v, 1 end
        return 0, 1, (1 - v) / 2, (1 + v) / 2
    end
    local u = ra / aspect                     -- sichtbarer Anteil der Breite
    return (1 - u) / 2, (1 + u) / 2, 0, 1
end

function CS.Opts()
    local s = FW.settings
    if type(s) ~= "table" then CS.mem = CS.mem or {} s = CS.mem end
    s.charSheet = s.charSheet or {}
    local o = s.charSheet
    if o.tab == nil then o.tab = true end
    if o.takeC == nil then o.takeC = false end
    if o.grow == nil then o.grow = false end
    if o.categories == nil then o.categories = true end
    if not CS.BG_BY_ID or not CS.BG_BY_ID[o.bg or ""] then o.bg = "leatherDark" end
    if o.race == nil then o.race = true end
    o.sort = o.sort or {}
    o.collapsed = o.collapsed or {}
    return o
end

local function Secret(v) return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) end
-- Wert sicher holen: pcall, Secret-Werte -> nil
local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    for i = 2, #r do if Secret(r[i]) then return nil end end
    return select(2, unpack(r))
end

------------------------------------------------------------------------
-- Rahmen in 9 Teilen aus einer Grafik (Ecken fest, Kanten gestreckt)
------------------------------------------------------------------------

-- Grafik in Pixeln: Bildgröße W x H, sichtbarer Bereich x0..x3 / y0..y3, Ecken bis x1/x2, y1/y2
CS.SLICES = {
    StatsFrame = { W = 512, H = 1024, x = { 2, 48, 465, 511 }, y = { 9, 55, 970, 1016 } },
    BagFrame = { W = 512, H = 1024, x = { 2, 48, 466, 512 }, y = { 135, 181, 850, 896 } },
}

-- Schmaler Rahmen um Werte und Taschen (0.67.0, Grafiken von Lacustat: Thin<Stil>Corner/Side.tga, 32 x 32):
-- Ecke oben rechts, alle Ecken gespiegelt, Seiten gedreht und gekachelt. Der Rahmen der Grafik bleibt nur als Füllung.
CS.THIN = { size = 32, style = "Brown" }
CS.MONEY_ASPECT = 2108 / 261         -- Seitenverhältnis des Goldfelds (Money.tga)
CS.TITLE_ASPECT = 2130 / 315         -- Seitenverhältnis der Titelleiste (BagTitle.tga)
CS.PLATE_ASPECT = 2144 / 415         -- Seitenverhältnis der Namensplakette (NamePlate.tga)
function CS.ThinFrame(holder)
    local thin = CS.TileFrame(holder, {
        size = CS.THIN.size, aspect = 1, flipBottom = true, layer = "ARTWORK",
        path = function(style, part) return MEDIA .. "Thin" .. style .. part .. ".tga" end,
    })
    thin:SetAllPoints(holder)
    thin:SetStyle(CS.THIN.style)
    holder.thin = thin
    return thin
end

-- Ein Rahmen aus 9 Texturen; frame:SetSliceScale(s) setzt die Bildschirmgröße der Ecken (Pixel * s)
function CS.NineSlice(parent, name, layer)
    local sl = CS.SLICES[name]
    local holder = CreateFrame("Frame", nil, parent)
    holder.parts = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local t = holder:CreateTexture(nil, layer or "BORDER")
            t:SetTexture(MEDIA .. name .. ".tga")
            t:SetTexCoord(sl.x[col] / sl.W, sl.x[col + 1] / sl.W, sl.y[row] / sl.H, sl.y[row + 1] / sl.H)
            holder.parts[(row - 1) * 3 + col] = t
        end
    end
    function holder:SetSliceScale(s)
        local p = self.parts
        if self.thin then
            -- nur die Füllung der Grafik (Mitte), dicht unter dem schmalen Rahmen; Ecken und Kanten aus
            local inset = CS.THIN.size * s * 0.5
            for i = 1, 9 do if i ~= 5 then p[i]:Hide() end end
            p[5]:ClearAllPoints()
            p[5]:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
            p[5]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
            self.thin:SetSliceScale(s / 0.9)
            return
        end
        local cw = (sl.x[2] - sl.x[1]) * s
        local cwr = (sl.x[4] - sl.x[3]) * s
        local ch = (sl.y[2] - sl.y[1]) * s
        local chb = (sl.y[4] - sl.y[3]) * s
        for i = 1, 9 do p[i]:ClearAllPoints() end
        p[1]:SetPoint("TOPLEFT", self, "TOPLEFT") p[1]:SetSize(cw, ch)
        p[3]:SetPoint("TOPRIGHT", self, "TOPRIGHT") p[3]:SetSize(cwr, ch)
        p[7]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT") p[7]:SetSize(cw, chb)
        p[9]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT") p[9]:SetSize(cwr, chb)
        p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT") p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
        p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT") p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
        p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT") p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
        p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT") p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
        p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT") p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT")
    end
    holder:SetSliceScale(1)
    return holder
end

------------------------------------------------------------------------
-- Außenrahmen aus Kacheln (0.66.0): je Rahmen eine Ecke (oben rechts) und ein senkrechtes Seitenteil,
-- das nahtlos an sich selbst passt. Ecken links gespiegelt, unten wie oben (Motive bleiben aufrecht);
-- die Seiten werden über Texturkoordinaten gedreht und aus Stücken zusammengesetzt, das letzte abgeschnitten.
-- Grafiken von Lacustat: Media/Character/Frames/<Name>Corner.tga (256 x 256) und <Name>Side.tga (256 x 512,
-- aus 376 x 512 waagerecht gestaucht, beim Zeichnen wieder im Verhältnis 376 : 512).
------------------------------------------------------------------------

CS.FRAME = { size = 166, aspect = 512 / 376 }     -- Dicke bei fs = 1; Länge eines Seitenstücks je Dicke

-- Rahmen: Rasse (Dateiname aus UnitRace), Klasse (Dateiname aus UnitClass), Pinky für alle
CS.FRAME_RACE = {
    Orc = "Orc", MagharOrc = "Orc", Tauren = "Tauren", HighmountainTauren = "Tauren",
    Troll = "Troll", ZandalariTroll = "Troll", Dwarf = "Dwarf", DarkIronDwarf = "Dwarf",
    Gnome = "Gnome", Mechagnome = "Gnome", Human = "Human", KulTiran = "Human",
    NightElf = "NightElf", Skyborne = "Skyborne", Scourge = "Undead", Undead = "Undead",
}
CS.FRAME_CLASS = {
    HUNTER = "Hunter", MAGE = "Mage", WARLOCK = "Warlock", ROGUE = "Rogue", WARRIOR = "Warrior",
    DRUID = "Druid", SHAMAN = "Shaman", PRIEST = "Priest", PALADIN = "Paladin",
}
CS.FRAME_PINKY = "Pinky"

function CS.RaceFrame(raceFile, raceName)
    if type(raceFile) == "string" and CS.FRAME_RACE[raceFile] then return CS.FRAME_RACE[raceFile] end
    for _, v in ipairs({ raceFile, raceName }) do
        if type(v) == "string" and v:lower():find("skyborne", 1, true) then return "Skyborne" end
    end
end

function CS.ClassFrame(classFile)
    return type(classFile) == "string" and CS.FRAME_CLASS[classFile] or nil
end

-- Texturkoordinaten eines Seitenstücks: Rand (top, bottom, left, right), sichtbarer Anteil frac (0..1].
-- Rückgabe in der Reihenfolge von SetTexCoord mit 8 Werten (UL, LL, UR, LR); u quer, r längs zum Seitenteil.
function CS.EdgeCoords(edge, frac)
    local function F(x, y)
        if edge == "right" then return x, y * frac
        elseif edge == "left" then return 1 - x, (1 - y) * frac
        elseif edge == "top" then return 1 - y, x * frac
        else return y, (1 - x) * frac end           -- bottom
    end
    local a, b = F(0, 0)
    local c, d = F(0, 1)
    local e, g = F(1, 0)
    local h, i = F(1, 1)
    return a, b, c, d, e, g, h, i
end

-- Stücke eines Randes der Länge len: { a = Anfang, b = Ende, frac } ab der Startecke
function CS.EdgePieces(len, seg)
    local list = {}
    if not len or len <= 0 or not seg or seg <= 0 then return list end
    local a = 0
    while a < len - 0.01 do
        local b = math.min(len, a + seg)
        list[#list + 1] = { a = a, b = b, frac = (b - a) / seg }
        a = b
    end
    return list
end

-- opts (0.67.0): size, aspect (Länge eines Seitenstücks je Dicke), path(style, "Corner"|"Side"), flipBottom
-- (untere Ecken senkrecht gespiegelt statt aufrecht), layer. Ohne opts: der große Außenrahmen.
local function FramePath(style, part) return MEDIA .. "Frames\\" .. style .. part .. ".tga" end
function CS.TileFrame(parent, opts)
    opts = opts or {}
    local SIZE, ASPECT = opts.size or CS.FRAME.size, opts.aspect or CS.FRAME.aspect
    local Path = opts.path or FramePath
    local LAYER = opts.layer or "BORDER"
    local holder = CreateFrame("Frame", nil, parent)
    local corners = {}
    for _, n in ipairs({ "TL", "TR", "BL", "BR" }) do corners[n] = holder:CreateTexture(nil, LAYER, nil, 2) end
    local pools = { top = {}, bottom = {}, left = {}, right = {} }
    holder.corners, holder.pools = corners, pools
    holder.fs = 0.4

    function holder:SetStyle(name)
        self.style = name
        for _, tex in pairs(corners) do tex:SetTexture(Path(name, "Corner")) end
        for _, pool in pairs(pools) do for _, tex in ipairs(pool) do tex:SetTexture(Path(name, "Side")) end end
        self:Build()
    end

    function holder:SetSliceScale(fs)
        self.fs = fs
        self:Build()
    end

    local function Piece(edge, k)
        local pool = pools[edge]
        local tex = pool[k]
        if not tex then
            tex = holder:CreateTexture(nil, LAYER, nil, 1)
            if holder.style then tex:SetTexture(Path(holder.style, "Side")) end
            pool[k] = tex
        end
        return tex
    end

    function holder:Build()
        local W, H = self:GetWidth() or 0, self:GetHeight() or 0
        if W <= 0 or H <= 0 then return end
        local t = SIZE * (self.fs or 0.4)
        local seg = t * ASPECT
        self.thick = t
        for n, tex in pairs(corners) do
            tex:ClearAllPoints()
            tex:SetSize(t, t)
            local l, r, tp, b = 0, 1, 0, 1
            if n == "TL" or n == "BL" then l, r = 1, 0 end
            if opts.flipBottom and (n == "BL" or n == "BR") then tp, b = 1, 0 end
            tex:SetTexCoord(l, r, tp, b)
        end
        corners.TL:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        corners.TR:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
        corners.BL:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
        corners.BR:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        local lenX, lenY = W - 2 * t, H - 2 * t
        for edge, pool in pairs(pools) do
            local len = (edge == "top" or edge == "bottom") and lenX or lenY
            local pieces = CS.EdgePieces(len, seg)
            for k, p in ipairs(pieces) do
                local tex = Piece(edge, k)
                tex:ClearAllPoints()
                local size = p.b - p.a
                if edge == "right" then
                    tex:SetPoint("TOPLEFT", self, "TOPLEFT", W - t, -(t + p.a)) tex:SetSize(t, size)
                elseif edge == "left" then
                    tex:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(t + len - p.b)) tex:SetSize(t, size)
                elseif edge == "top" then
                    tex:SetPoint("TOPLEFT", self, "TOPLEFT", t + p.a, 0) tex:SetSize(size, t)
                else
                    tex:SetPoint("TOPLEFT", self, "TOPLEFT", t + len - p.b, -(H - t)) tex:SetSize(size, t)
                end
                tex:SetTexCoord(CS.EdgeCoords(edge, p.frac))
                tex:Show()
            end
            for k = #pieces + 1, #pool do pool[k]:Hide() end
        end
    end
    holder:SetScript("OnSizeChanged", function(self) self:Build() end)
    return holder
end

------------------------------------------------------------------------
-- Aufteilung (reine Rechnung, getestet): Bildschirmgröße -> Bereiche
------------------------------------------------------------------------

-- W, H: Fenstergröße in UI-Einheiten. Rückgabe: Maßstab k der Rahmen-Grafik und die Bereiche (x, y von oben links)
function CS.ComputeLayout(W, H)
    local k = H / 1020                        -- Maßstab für Abstände (wie bisher)
    local fs = math.max(0.28, math.min(0.6, H / 2000))   -- Maßstab des Holzrahmens (Ecke 256 px -> ~13 % der Höhe)
    local inner = CS.FRAME.size * fs + 6                 -- Innenkante des Rahmens plus etwas Luft (0.66.0)
    local padX, padTop, padBot = inner, inner, inner
    local cx, cy = padX, padTop
    local cw, ch = W - 2 * padX, H - padTop - padBot
    local gap = math.max(10, 24 * k)
    -- Platzgröße aus der Höhe (Namensschild + 8 Plätze + Waffenreihe); bei schmalen Bildschirmen (4:3) kleiner,
    -- bis mindestens 6 Taschenspalten neben Charakter und Werte passen
    local S = math.floor(math.min(72, ch / 12.2))
    local sg, plateH, modelW, charW, statsW, bagsW
    while true do
        sg = math.max(4, math.floor(S * 0.14))
        plateH = math.floor(S * 1.35)
        modelW = math.floor(S * 4.6)
        charW = S * 2 + sg * 2 + modelW
        statsW = math.max(280, math.floor(cw * 0.22))
        bagsW = cw - charW - statsW - 2 * gap
        local need = 6 * (S + 4) + 40
        if bagsW < need then
            statsW = math.max(220, cw - charW - 2 * gap - need)
            bagsW = cw - charW - statsW - 2 * gap
        end
        if bagsW >= need or S <= 30 then break end
        S = S - 2
    end
    return {
        k = k, fs = fs, S = S, sg = sg,
        content = { x = cx, y = cy, w = cw, h = ch },
        char = { x = cx, y = cy, w = charW, h = ch },
        plate = { x = cx, y = cy, w = charW, h = plateH },
        model = { x = cx + S + sg, y = cy + plateH + sg, w = modelW, h = 8 * S + 7 * sg },
        stats = { x = cx + charW + gap, y = cy, w = statsW, h = ch },
        bags = { x = cx + charW + gap + statsW + gap, y = cy, w = bagsW, h = ch },
    }
end

-- Wie viele Spalten passen ins Taschenraster? (grow: Platzgröße so, dass alle Plätze ohne Scrollen passen)
function CS.BagGrid(w, h, count, S, grow)
    local pad = 4
    if not grow then
        local cols = math.max(1, math.floor((w + pad) / (S + pad)))
        return cols, S
    end
    local size = S
    while size > 18 do
        local cols = math.max(1, math.floor((w + pad) / (size + pad)))
        local rows = math.ceil(count / cols)
        if rows * (size + pad) - pad <= h then return cols, size end
        size = size - 2
    end
    return math.max(1, math.floor((w + pad) / (size + pad))), size
end

------------------------------------------------------------------------
-- Werte (reine Abfrage, getestet)
------------------------------------------------------------------------

local function Num(v, dec)
    if v == nil then return "–" end
    if dec then return (string.format("%." .. dec .. "f", v):gsub("%.", ",", 1)) end
    v = math.floor(v + 0.5)
    local s = tostring(v)
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end
local function Pct(v) if v == nil then return "–" end return string.format("%.2f %%", v):gsub("%.", ",", 1) end
CS.Num, CS.Pct = Num, Pct

-- Stat mit Buff-Farbe: grün wenn erhöht, rot wenn gesenkt
local function StatColored(idx)
    local base, stat, pos, neg = Safe(G.UnitStat, "player", idx)
    if stat == nil then return "–" end
    local txt = Num(stat)
    if (neg or 0) < 0 then return "|cffff6060" .. txt .. "|r" end
    if (pos or 0) > 0 then return "|cff40ff40" .. txt .. "|r" end
    return txt
end

function CS.ClassOrder(class)
    if class == "HUNTER" then return { "ranged", "melee", "defense" } end
    if class == "MAGE" or class == "WARLOCK" or class == "PRIEST" then return { "spell", "defense", "melee" } end
    if class == "SHAMAN" or class == "DRUID" or class == "PALADIN" then return { "melee", "spell", "defense" } end
    return { "melee", "defense", "ranged" }
end

-- Liste der Abschnitte: { { title, rows = { { label, value } } } }
function CS.Stats()
    local Lx = L()
    local out = {}
    local function Sec(title, rows) out[#out + 1] = { title = title, rows = rows } end
    local hp = Safe(G.UnitHealthMax, "player")
    local mana = Safe(G.UnitPowerMax, "player", 0)
    local _, run = Safe(G.GetUnitSpeed, "player")
    local gen = { { Lx.CS_HEALTH, Num(hp) } }
    if mana and mana > 0 then gen[#gen + 1] = { Lx.CS_MANA, Num(mana) } end
    gen[#gen + 1] = { Lx.CS_SPEED, run and (math.floor(run / 7 * 100 + 0.5) .. "%") or "–" }
    Sec(Lx.CS_GENERAL, gen)
    Sec(Lx.CS_PRIMARY, { { Lx.CS_STR, StatColored(1) }, { Lx.CS_AGI, StatColored(2) }, { Lx.CS_STA, StatColored(3) },
        { Lx.CS_INT, StatColored(4) }, { Lx.CS_SPI, StatColored(5) } })
    local parts = {}
    do
        local lo, hi = Safe(G.UnitDamage, "player")
        local base, pos, neg = Safe(G.UnitAttackPower, "player")
        local sp = Safe(G.UnitAttackSpeed, "player")
        parts.melee = { Lx.CS_MELEE, {
            { Lx.CS_DAMAGE, lo and (Num(lo) .. "-" .. Num(hi)) or "–" },
            { Lx.CS_AP, base and Num(base + (pos or 0) + (neg or 0)) or "–" },
            { Lx.CS_ATKSPEED, sp and Num(sp, 2) or "–" },
            { Lx.CS_CRIT, Pct(Safe(G.GetCritChance)) },
            { Lx.CS_HIT, Pct(Safe(G.GetHitModifier) or Safe(G.GetCombatRatingBonus, 6)) },
        } }
    end
    do
        local _, lo, hi = Safe(G.UnitRangedDamage, "player")
        local base, pos, neg = Safe(G.UnitRangedAttackPower, "player")
        parts.ranged = { Lx.CS_RANGED, {
            { Lx.CS_DAMAGE, lo and (Num(lo) .. "-" .. Num(hi)) or "–" },
            { Lx.CS_AP, base and Num(base + (pos or 0) + (neg or 0)) or "–" },
            { Lx.CS_CRIT, Pct(Safe(G.GetRangedCritChance)) },
            { Lx.CS_HIT, Pct(Safe(G.GetHitModifier) or Safe(G.GetCombatRatingBonus, 7)) },
        } }
    end
    do
        local best
        for school = 2, 7 do
            local v = Safe(G.GetSpellBonusDamage, school)
            if v and (not best or v > best) then best = v end
        end
        local base, casting = Safe(G.GetManaRegen)
        parts.spell = { Lx.CS_SPELL, {
            { Lx.CS_SPELLDMG, Num(best) },
            { Lx.CS_HEAL, Num(Safe(G.GetSpellBonusHealing)) },
            { Lx.CS_SPELLCRIT, Pct(Safe(G.GetSpellCritChance, 2)) },
            { Lx.CS_REGEN, base and Num(base * 5) or "–" },
        } }
    end
    do
        local _, eff = Safe(G.UnitArmor, "player")
        parts.defense = { Lx.CS_DEFENSE, {
            { Lx.CS_ARMOR, Num(eff) },
            { Lx.CS_DODGE, Pct(Safe(G.GetDodgeChance)) },
            { Lx.CS_PARRY, Pct(Safe(G.GetParryChance)) },
            { Lx.CS_BLOCK, Pct(Safe(G.GetBlockChance)) },
        } }
    end
    local class = select(2, Safe(G.UnitClass, "player"))
    local used = {}
    for _, key in ipairs(CS.ClassOrder(class)) do
        if parts[key] then Sec(parts[key][1], parts[key][2]) used[key] = true end
    end
    for _, key in ipairs({ "melee", "ranged", "spell", "defense" }) do
        if parts[key] and not used[key] then Sec(parts[key][1], parts[key][2]) end
    end
    local res = {}
    for i, k in ipairs({ { 2, Lx.CS_FIRE }, { 3, Lx.CS_NATURE }, { 4, Lx.CS_FROST }, { 5, Lx.CS_SHADOW }, { 6, Lx.CS_ARCANE } }) do
        local _, total = Safe(G.UnitResistance, "player", k[1])
        res[i] = { k[2], Num(total) }
    end
    Sec(Lx.CS_RESIST, res)
    return out
end

------------------------------------------------------------------------
-- Ausrüstung
------------------------------------------------------------------------

CS.LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
CS.RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
CS.BOTTOM = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" }
CS.BAGS = { 0, 1, 2, 3, 4, 5 }   -- Rucksack, 4 Taschen, Reagenzientasche (F-31)

local function SlotInfo(name)
    local id, empty = Safe(G.GetInventorySlotInfo, name)
    return id, empty
end

------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------

local win

local function Glow(btn)
    local g = btn:CreateTexture(nil, "OVERLAY")
    g:SetTexture(MEDIA .. "Glow.tga")
    g:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
    g:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
    g:SetBlendMode("ADD")
    g:Hide()
    return g
end

local function QualityColor(q)
    local c = q and G.ITEM_QUALITY_COLORS and G.ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return nil
end

local function MakeSlot(parent, slotName, bg)
    local id, emptyTex = SlotInfo(slotName)
    if not id then return nil end
    local b = CreateFrame("Button", nil, parent)
    b.slot = id
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture(MEDIA .. bg .. ".tga")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -6)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 6)
    b.empty = emptyTex
    b.quality = b:CreateTexture(nil, "OVERLAY")
    b.quality:SetTexture(MEDIA .. "Glow.tga")
    b.quality:SetAllPoints(b)
    b.quality:Hide()
    b.hover = Glow(b)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 5)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", function(self)
        self.hover:SetVertexColor(1, 0.85, 0.4)
        self.hover:Show()
        if G.GameTooltip then
            G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local has = G.GameTooltip:SetInventoryItem("player", self.slot)
            if not has then G.GameTooltip:SetText(G[slotName:upper()] or slotName) end
            G.GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() if G.GameTooltip then G.GameTooltip:Hide() end end)
    b:SetScript("OnClick", function(self, button)
        local link = G.GetInventoryItemLink and G.GetInventoryItemLink("player", self.slot)
        if link and G.IsModifiedClick and G.IsModifiedClick() and G.HandleModifiedItemClick then
            G.HandleModifiedItemClick(link)
            return
        end
        if button == "LeftButton" and G.PickupInventoryItem then G.PickupInventoryItem(self.slot) end
    end)
    b:SetScript("OnDragStart", function(self) if G.PickupInventoryItem then G.PickupInventoryItem(self.slot) end end)
    b:SetScript("OnReceiveDrag", function(self) if G.PickupInventoryItem then G.PickupInventoryItem(self.slot) end end)
    function b:Update()
        local tex = G.GetInventoryItemTexture and G.GetInventoryItemTexture("player", self.slot)
        self.icon:SetTexture(tex or self.empty)
        self.icon:SetAlpha(tex and 1 or 0.35)
        local q = tex and G.GetInventoryItemQuality and G.GetInventoryItemQuality("player", self.slot)
        local r, g2, bb = QualityColor(q)
        if r and q and q >= 2 then self.quality:SetVertexColor(r, g2, bb) self.quality:Show() else self.quality:Hide() end
        local n = tex and slotName == "AmmoSlot" and G.GetInventoryItemCount and G.GetInventoryItemCount("player", self.slot)
        self.count:SetText(n and n > 1 and n or "")
    end
    return b
end

-- Taschenknopf: Blizzards eigene Vorlage (benutzen, verschieben, verkaufen, Tooltip) ohne Taint
local bagParents = {}
local function BagParent(bag)
    if bagParents[bag] then return bagParents[bag] end
    local p = CreateFrame("Frame", nil, win.bagsChild)
    p:SetID(bag)
    p:SetAllPoints(win.bagsChild)
    bagParents[bag] = p
    return p
end

local function MakeBagButton(bag, slot)
    local p = BagParent(bag)
    local ok, b = pcall(CreateFrame, "ItemButton", nil, p, "ContainerFrameItemButtonTemplate")
    if not ok or not b then ok, b = pcall(CreateFrame, "Button", nil, p, "ContainerFrameItemButtonTemplate") end
    if not ok or not b then return nil end
    b:SetID(slot)
    b.fwBag = bag
    if b.GetBagID == nil then function b:GetBagID() return self:GetParent():GetID() end end
    -- Rahmen genau so groß wie der Knopf; Blizzards eigener Platzrahmen (NormalTexture) und Zusatzbilder aus,
    -- Symbol leicht eingerückt, damit es im Freewood-Rahmen sitzt (0.61.1)
    b.fwBg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.fwBg:SetTexture(MEDIA .. "BagSlot.tga")
    b.fwBg:SetAllPoints(b)
    b.fwFrame = b:CreateTexture(nil, "OVERLAY", nil, -1)
    b.fwFrame:SetTexture(MEDIA .. "BagSlot.tga")
    b.fwFrame:SetAllPoints(b)
    b.fwFrame:SetAlpha(0)
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    for _, key in ipairs({ "NewItemTexture", "BattlepayItemTexture", "flash", "ExtendedSlot", "ItemContextOverlay" }) do
        local t = b[key]
        if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
    end
    function b:FwFit(size)
        local inset = math.max(3, math.floor(size * 0.09))
        local icon = self.icon or self.Icon or (self.GetName and self:GetName() and G[self:GetName() .. "IconTexture"])
        if type(icon) == "table" and icon.ClearAllPoints then
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
            icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
        end
        if type(self.IconBorder) == "table" and self.IconBorder.ClearAllPoints then
            self.IconBorder:ClearAllPoints()
            self.IconBorder:SetPoint("TOPLEFT", self, "TOPLEFT", inset - 1, -(inset - 1))
            self.IconBorder:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -(inset - 1), inset - 1)
        end
        local hl = self.GetHighlightTexture and self:GetHighlightTexture()
        if hl then hl:ClearAllPoints() hl:SetAllPoints(self) end
        local pt = self.GetPushedTexture and self:GetPushedTexture()
        if pt then pt:ClearAllPoints() pt:SetAllPoints(self) end
    end
    b.fwGlow = Glow(b)
    b:HookScript("OnEnter", function(self) self.fwGlow:SetVertexColor(1, 0.85, 0.4) self.fwGlow:Show() end)
    b:HookScript("OnLeave", function(self) self.fwGlow:Hide() end)
    return b
end

local function ContainerSlots(bag)
    local C = G.C_Container
    if C and C.GetContainerNumSlots then return Safe(C.GetContainerNumSlots, bag) or 0 end
    return Safe(G.GetContainerNumSlots, bag) or 0
end
local function ContainerInfo(bag, slot)
    local C = G.C_Container
    if C and C.GetContainerItemInfo then return Safe(C.GetContainerItemInfo, bag, slot) end
    return nil
end

-- 64333 -> "6 [Gold]  43 [Silber]  33 [Kupfer]" mit Münzsymbolen (0.61.1; GetCoinTextureString fehlte in Forever)
function CS.MoneyText(m)
    m = math.floor(tonumber(m) or 0)
    local g, sv, c = math.floor(m / 10000), math.floor(m / 100) % 100, m % 100
    local function Icon(name) return "|TInterface\\MoneyFrame\\UI-" .. name .. "Icon:0:0:2:0|t" end
    local parts = {}
    if g > 0 then parts[#parts + 1] = Num(g) .. Icon("Gold") end
    if g > 0 or sv > 0 then parts[#parts + 1] = sv .. Icon("Silver") end
    parts[#parts + 1] = c .. Icon("Copper")
    return table.concat(parts, "   ")
end

function CS.MatchSearch(info, text)
    if not text or text == "" then return true end
    if not info or not info.hyperlink then return false end
    local name = info.hyperlink:match("%[(.-)%]") or ""
    local lower = (FW.AutoReply and FW.AutoReply.Lower) or string.lower
    return lower(name):find(lower(text), 1, true) ~= nil
end

local function Build()
    if win then return win end
    local f = CreateFrame("Frame", "FreewoodCharacterSheet", G.UIParent)
    f:SetAllPoints(G.UIParent)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:Hide()
    if G.UISpecialFrames then table.insert(G.UISpecialFrames, "FreewoodCharacterSheet") end
    win = f

    -- Hintergrund: dunkles Leder, Rahmen in 9 Teilen
    -- dichter Grund: zwischen Rahmenecken und am oberen Rand darf nichts vom Spiel durchscheinen (0.61.1)
    f.base = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.base:SetAllPoints(f)
    f.base:SetColorTexture(0.07, 0.05, 0.035, 1)
    f.leather = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    -- Grafik und Ausschnitt setzt CS.ApplyBackground (0.63.0)
    f.frame = CS.TileFrame(f)
    f.frame:SetAllPoints(f)
    f.frame:SetFrameLevel(f:GetFrameLevel() + 20)

    f.close = CreateFrame("Button", nil, f.frame)
    f.close:SetNormalTexture(MEDIA .. "Close.tga")
    f.close:SetHighlightTexture(MEDIA .. "Glow.tga", "ADD")
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.bgDrop = CS.CreateBgDropdown(f.frame)
    f.frameDrop = CS.CreateFrameDropdown(f.frame)
    CS.ApplyFrame()

    -- Charakter
    f.plate = f:CreateTexture(nil, "ARTWORK")
    f.plate:SetTexture(MEDIA .. "NamePlate.tga")
    f.plate:SetTexCoord(0, 1, 0, 1)        -- 0.67.3: neue Plakette von Lacustat, ohne Rand zugeschnitten (2144 x 415)
    f.name = f:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.name, "heading", 26)
    f.name:SetTextColor(1, 0.85, 0.45)
    f.level = f:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.level, "body", 16)
    f.level:SetTextColor(0.95, 0.92, 0.85)
    f.forest = f:CreateTexture(nil, "BORDER")
    f.forest:SetTexture(MEDIA .. "Forest.tga")
    f.forest:SetTexCoord(unpack(CS.FOREST_CROP))
    local okModel, model = pcall(CreateFrame, "DressUpModel", nil, f)
    if not okModel or not model then model = CreateFrame("PlayerModel", nil, f) end
    f.model = model
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model.rot = 0
    model.zoom = 1
    model:SetScript("OnMouseDown", function(self, btn) if btn == "LeftButton" then self.dragX = G.GetCursorPosition() end end)
    model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        local x = G.GetCursorPosition()
        self.rot = self.rot + (x - self.dragX) * 0.01
        self.dragX = x
        if self.SetFacing then self:SetFacing(self.rot) end
    end)
    model:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.max(0.4, math.min(1.6, self.zoom - delta * 0.1))
        if self.SetCamDistanceScale then pcall(self.SetCamDistanceScale, self, self.zoom) end
    end)

    f.slots = {}
    for _, n in ipairs(CS.LEFT) do f.slots[#f.slots + 1] = MakeSlot(f, n, "Slot") or false end
    for _, n in ipairs(CS.RIGHT) do f.slots[#f.slots + 1] = MakeSlot(f, n, "Slot") or false end
    for _, n in ipairs(CS.BOTTOM) do f.slots[#f.slots + 1] = MakeSlot(f, n, "WeaponSlot") or false end

    -- Werte
    f.stats = CS.NineSlice(f, "StatsFrame", "BORDER")
    CS.ThinFrame(f.stats)
    f.statsTitle = f.stats:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.statsTitle, "heading", 20)
    f.statsTitle:SetTextColor(1, 0.85, 0.45)
    f.statsTitle:SetText(L().CS_STATS)
    -- Umschalter "Werte | Ausrüstung" (0.64.0): die Ausrüstung nach Ereignis teilt sich den Platz mit den Werten
    local function ViewButton(text, view)
        local b = CreateFrame("Button", nil, f.stats)
        b.text = b:CreateFontString(nil, "OVERLAY")
        UI.SetFont(b.text, "heading", 20)
        b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.text:SetText(text)
        b:SetSize(math.max(60, (b.text:GetStringWidth() or 80) + 12), 28)
        b:SetScript("OnClick", function() CS.SetView(view) end)
        return b
    end
    f.viewStats = ViewButton(L().CS_STATS_SHORT, "stats")
    f.viewGear = ViewButton(L().CS_GEAR_SHORT, "gear")
    f.viewSep = f.stats:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.viewSep, "heading", 20)
    f.viewSep:SetTextColor(0.6, 0.5, 0.35)
    f.viewSep:SetText("|")
    f.gearHost = CreateFrame("Frame", nil, f.stats)
    f.gearHost:Hide()
    local okS, ss = pcall(CreateFrame, "ScrollFrame", "FreewoodCharacterSheetStats", f.stats, "UIPanelScrollFrameTemplate")
    if not okS then ss = CreateFrame("ScrollFrame", nil, f.stats) end
    f.statsScroll = ss
    f.statsChild = CreateFrame("Frame", nil, ss)
    f.statsChild:SetSize(1, 1)
    ss:SetScrollChild(f.statsChild)
    f.statRows = {}

    -- Taschen
    f.bags = CS.NineSlice(f, "BagFrame", "BORDER")
    CS.ThinFrame(f.bags)
    -- Schilder (Titel, Gold) über dem schmalen Rahmen: eigene Ebene, höher als der Rahmen (0.67.4)
    f.bagsTop = CreateFrame("Frame", nil, f.bags)
    f.bagsTop:SetAllPoints(f.bags)
    f.bagsTop:SetFrameLevel((f.bags.thin:GetFrameLevel() or 1) + 2)
    f.bagTitle = f.bagsTop:CreateTexture(nil, "ARTWORK")
    f.bagTitle:SetTexture(MEDIA .. "BagTitle.tga")
    f.bagTitle:SetTexCoord(0, 1, 0, 1)     -- 0.67.2: neue Titelleiste von Lacustat, ohne Rand zugeschnitten (2130 x 315)
    f.bagTitleText = f.bagsTop:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.bagTitleText, "heading", 20)
    f.bagTitleText:SetTextColor(1, 0.85, 0.45)
    f.bagTitleText:SetText(L().CS_BAGS)
    -- Suchleiste in drei Teilen: Enden fest, nur die Mitte wird gestreckt (0.61.1)
    f.searchBg = CreateFrame("Frame", nil, f.bags)
    f.searchParts = {}
    for i, tc in ipairs({ { 0, 40 }, { 40, 472 }, { 472, 512 } }) do
        local t = f.searchBg:CreateTexture(nil, "ARTWORK")
        t:SetTexture(MEDIA .. "Search.tga")
        t:SetTexCoord(tc[1] / 512, tc[2] / 512, 9 / 64, 56 / 64)
        f.searchParts[i] = t
    end
    local sb = CreateFrame("EditBox", nil, f.bags)
    sb:SetAutoFocus(false)
    UI.SetFont(sb, "body", 14)
    sb:SetTextColor(0.95, 0.92, 0.85)
    sb:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnTextChanged", function(self) f.searchHint:SetShown(self:GetText() == "") CS.UpdateBags() end)
    f.search = sb
    f.searchHint = sb:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.searchHint, "body", 14)
    f.searchHint:SetTextColor(0.6, 0.55, 0.48)
    f.searchHint:SetPoint("LEFT", sb, "LEFT", 22, 0)
    f.searchHint:SetText(L().CS_SEARCH)
    f.grow = UI.CreateCheckbox(f.bags, L().CS_GROW, function() return CS.Opts().grow end,
        function(v) CS.Opts().grow = v and true or false CS.Layout() end)
    f.cats = UI.CreateCheckbox(f.bags, L().CS_CATS, function() return CS.Opts().categories end,
        function(v) CS.Opts().categories = v and true or false CS.UpdateBags() end)
    f.bagHeads = {}
    local okB, bs = pcall(CreateFrame, "ScrollFrame", "FreewoodCharacterSheetBags", f.bags, "UIPanelScrollFrameTemplate")
    if not okB then bs = CreateFrame("ScrollFrame", nil, f.bags) end
    f.bagsScroll = bs
    f.bagsChild = CreateFrame("Frame", nil, bs)
    f.bagsChild:SetSize(1, 1)
    bs:SetScrollChild(f.bagsChild)
    f.bagButtons = {}
    f.moneyBg = f.bagsTop:CreateTexture(nil, "ARTWORK")
    f.moneyBg:SetTexture(MEDIA .. "Money.tga")
    f.moneyBg:SetTexCoord(0, 1, 0, 1)      -- 0.67.1: neues Goldfeld von Lacustat, ohne Rand zugeschnitten (2108 x 261)
    f.money = f.bagsTop:CreateFontString(nil, "OVERLAY")
    UI.SetFont(f.money, "body", 16)
    f.money:SetTextColor(0.95, 0.92, 0.85)

    f:SetScript("OnShow", function() CS.Layout() CS.UpdateAll() end)
    f:SetScript("OnSizeChanged", function() if f:IsShown() then CS.Layout() end end)
    f:SetScript("OnHide", function() if f.search then f.search:ClearFocus() end end)
    return f
end

-- Oberflächen-Hintergrund nach der Einstellung setzen (Ausschnitt ohne Verzerrung)
function CS.ApplyBackground()
    local f = win
    if not f or not f.leather then return end
    local b = CS.BG_BY_ID[CS.Opts().bg] or CS.BACKGROUNDS[1]
    f.leather:SetTexture(MEDIA .. b.file)
    if b.crop then
        f.leather:SetTexCoord(unpack(b.crop))
    else
        local W, H = f:GetWidth() or 0, f:GetHeight() or 0
        f.leather:SetTexCoord(CS.CoverCoords(W, H, 1, false))
    end
    if f.bgDrop and f.bgDrop.FwRefresh then f.bgDrop:FwRefresh() end
end

-- Bild hinter dem Modell: Rasse des Spielers, sonst Wald
function CS.ApplyRace()
    local f = win
    if not f or not f.forest then return end
    local file
    if CS.Opts().race then
        local raceFile = select(2, Safe(G.UnitRace, "player"))
        file = CS.RaceFile(raceFile)
    end
    f.raceFile = file
    if file then
        f.forest:SetTexture(MEDIA .. file .. ".tga")
        local r = f.lay and f.lay.model
        f.forest:SetTexCoord(CS.CoverCoords(r and r.w or 1, r and r.h or 2, CS.RACE_ASPECT, true))
    else
        f.forest:SetTexture(MEDIA .. "Forest.tga")
        f.forest:SetTexCoord(unpack(CS.FOREST_CROP))
    end
end

function CS.SetBackground(id)
    if not CS.BG_BY_ID[id] then return end
    CS.Opts().bg = id
    CS.ApplyBackground()
end

-- Auswahl oben rechts neben dem X: Blizzard-Dropdown (WowStyle1), sonst das Kit-Dropdown.
-- def = { title, width, list() -> { { id, text } }, get() -> id, set(id) }
function CS.CreateChoice(parent, def)
    local ok, dd = false, nil
    if G.MenuUtil and G.CreateFrame then
        ok, dd = pcall(G.CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    end
    if ok and dd and dd.SetupMenu then
        dd.fwBlizzard = true
        dd:SetWidth(def.width or 170)
        local okSetup = pcall(dd.SetupMenu, dd, function(_, root)
            if root.CreateTitle then root:CreateTitle(def.title) end
            for _, o in ipairs(def.list()) do
                root:CreateRadio(o.text, function() return def.get() == o.id end, function() def.set(o.id) end)
            end
        end)
        if okSetup then
            function dd:FwRefresh() if self.GenerateMenu then pcall(self.GenerateMenu, self) end end
            return dd
        end
        dd:Hide()
    end
    local function Text(id)
        for _, o in ipairs(def.list()) do if o.id == id then return o.text end end
        return tostring(id or "")
    end
    dd = UI.CreateDropdown(parent, def.width or 170, 24, {
        getOptions = function()
            local list = {}
            for _, o in ipairs(def.list()) do list[#list + 1] = { value = o.id, text = o.text } end
            return list
        end,
        textOf = Text,
        onChange = function(v) def.set(v) end,
    })
    dd:SetValue(def.get())
    function dd:FwRefresh() self:SetValue(def.get()) end
    return dd
end

function CS.CreateBgDropdown(parent)
    local Lx = L()
    return CS.CreateChoice(parent, {
        title = Lx.CS_BG, width = 170,
        list = function()
            local list = {}
            for _, b in ipairs(CS.BACKGROUNDS) do list[#list + 1] = { id = b.id, text = Lx["CS_BG_" .. b.id] or b.id } end
            return list
        end,
        get = function() return CS.Opts().bg end,
        set = function(id) CS.SetBackground(id) end,
    })
end

-- Rahmen zur Auswahl für diesen Charakter: seine Rasse, seine Klasse, Pinky
function CS.FrameChoices()
    local Lx = L()
    local list = {}
    local raceName, raceFile = Safe(G.UnitRace, "player")
    local race = CS.RaceFrame(raceFile, raceName)
    if race then list[#list + 1] = { id = "race", file = race, text = raceName or Lx["CS_FRAME_" .. race] or race } end
    local className, classFile = Safe(G.UnitClass, "player")
    local cls = CS.ClassFrame(classFile)
    if cls then list[#list + 1] = { id = "class", file = cls, text = className or Lx["CS_FRAME_" .. cls] or cls } end
    list[#list + 1] = { id = "pinky", file = CS.FRAME_PINKY, text = Lx.CS_FRAME_Pinky }
    return list
end

-- gewählter Rahmen; ohne Wahl oder wenn es ihn für diesen Charakter nicht gibt: Rasse, sonst Pinky
function CS.FrameChoice()
    local list = CS.FrameChoices()
    local want = CS.Opts().frame
    for _, o in ipairs(list) do if o.id == want then return o end end
    return list[1]
end

function CS.ApplyFrame()
    local f = win
    if not f or not f.frame then return end
    local o = CS.FrameChoice()
    if f.frame.style ~= o.file then f.frame:SetStyle(o.file) end
    if f.frameDrop and f.frameDrop.FwRefresh then f.frameDrop:FwRefresh() end
end

function CS.SetFrame(id)
    CS.Opts().frame = id
    CS.ApplyFrame()
end

function CS.CreateFrameDropdown(parent)
    return CS.CreateChoice(parent, {
        title = L().CS_FRAME, width = 150,
        list = CS.FrameChoices,
        get = function() return CS.FrameChoice().id end,
        set = function(id) CS.SetFrame(id) end,
    })
end

local function Place(obj, r, parent)
    obj:ClearAllPoints()
    obj:SetPoint("TOPLEFT", parent or win, "TOPLEFT", r.x, -r.y)
    obj:SetSize(r.w, r.h)
end

function CS.Layout()
    local f = win
    if not f then return end
    local W, H = f:GetWidth(), f:GetHeight()
    if not W or W <= 0 then return end
    local lay = CS.ComputeLayout(W, H)
    f.lay = lay
    local k, S, sg = lay.k, lay.S, lay.sg
    f.frame:SetSliceScale(lay.fs)
    f.leather:ClearAllPoints()
    f.leather:SetPoint("TOPLEFT", f, "TOPLEFT", 8 * k, -8 * k)
    f.leather:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8 * k, 8 * k)
    CS.ApplyBackground()
    -- X auf der oberen Leiste links neben der Ecke (0.66.0: das Motiv der Ecke bleibt frei), daneben die Auswahlen
    local t = CS.FRAME.size * lay.fs
    local xs = math.max(24, 0.42 * t)
    f.close:SetSize(xs, xs)
    f.close:ClearAllPoints()
    f.close:SetPoint("CENTER", f, "TOPRIGHT", -(t + xs / 2 + 8), -t / 2)
    if f.frameDrop then
        f.frameDrop:ClearAllPoints()
        f.frameDrop:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
    end
    if f.bgDrop then
        f.bgDrop:ClearAllPoints()
        f.bgDrop:SetPoint("RIGHT", f.frameDrop or f.close, "LEFT", -10, 0)
    end

    -- Charakter
    -- Plakette im eigenen Seitenverhältnis, mittig im Platz der Plakette (0.67.3)
    do
        local r = lay.plate
        local w = math.min(r.w, r.h * CS.PLATE_ASPECT)
        local h = w / CS.PLATE_ASPECT
        Place(f.plate, { x = r.x + (r.w - w) / 2, y = r.y + (r.h - h) / 2, w = w, h = h })
    end
    f.name:ClearAllPoints()
    f.name:SetPoint("CENTER", f.plate, "CENTER", 0, lay.plate.h * 0.14)
    f.level:ClearAllPoints()
    f.level:SetPoint("TOP", f.name, "BOTTOM", 0, -2)
    Place(f.forest, lay.model)
    CS.ApplyRace()
    Place(f.model, lay.model)
    local x0, y0 = lay.char.x, lay.model.y
    local xr = lay.model.x + lay.model.w + sg
    for i, b in ipairs(f.slots) do
        if b then
            b:SetSize(S, S)
            b:ClearAllPoints()
            if i <= 8 then
                b:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -(y0 + (i - 1) * (S + sg)))
            elseif i <= 16 then
                b:SetPoint("TOPLEFT", f, "TOPLEFT", xr, -(y0 + (i - 9) * (S + sg)))
            else
                local n = i - 16
                local rowW = 4 * S + 3 * sg
                local bx = lay.model.x + (lay.model.w - rowW) / 2 + (n - 1) * (S + sg)
                b:SetPoint("TOPLEFT", f, "TOPLEFT", bx, -(lay.model.y + lay.model.h + sg * 2))
            end
        end
    end

    -- Werte
    Place(f.stats, lay.stats)
    f.stats:SetSliceScale(math.max(0.5, k * 0.9))
    f.statsTitle:ClearAllPoints()
    f.statsTitle:SetPoint("TOP", f.stats, "TOP", 0, -24)
    f.statsTitle:Hide()
    f.viewSep:ClearAllPoints()
    f.viewSep:SetPoint("TOP", f.stats, "TOP", 0, -24)
    f.viewStats:ClearAllPoints()
    f.viewStats:SetPoint("RIGHT", f.viewSep, "LEFT", -6, 0)
    f.viewGear:ClearAllPoints()
    f.viewGear:SetPoint("LEFT", f.viewSep, "RIGHT", 6, 0)
    f.gearHost:ClearAllPoints()
    f.gearHost:SetPoint("TOPLEFT", f.stats, "TOPLEFT", 22, -60)
    f.gearHost:SetPoint("BOTTOMRIGHT", f.stats, "BOTTOMRIGHT", -26, 24)
    CS.SetView(CS.Opts().view)
    f.statsScroll:ClearAllPoints()
    f.statsScroll:SetPoint("TOPLEFT", f.stats, "TOPLEFT", 22, -60)
    f.statsScroll:SetPoint("BOTTOMRIGHT", f.stats, "BOTTOMRIGHT", -34, 24)
    f.statsChild:SetWidth(lay.stats.w - 60)

    -- Taschen
    Place(f.bags, lay.bags)
    f.bags:SetSliceScale(math.max(0.5, k * 0.9))
    local bw = lay.bags.w
    f.bagTitle:ClearAllPoints()
    f.bagTitle:SetPoint("TOP", f.bags, "TOP", 0, 8)
    local tw = math.min(bw * 0.6, 420)
    f.bagTitle:SetSize(tw, tw / CS.TITLE_ASPECT)
    f.bagTitleText:ClearAllPoints()
    f.bagTitleText:SetPoint("CENTER", f.bagTitle, "CENTER", 0, 0)
    f.searchBg:ClearAllPoints()
    f.searchBg:SetPoint("TOPLEFT", f.bags, "TOPLEFT", 20, -62)
    f.searchBg:SetPoint("TOPRIGHT", f.bags, "TOPRIGHT", -20, -62)
    f.searchBg:SetHeight(32)
    local capW = 40 * 32 / 47
    local sp = f.searchParts
    for i = 1, 3 do sp[i]:ClearAllPoints() end
    sp[1]:SetPoint("TOPLEFT", f.searchBg, "TOPLEFT") sp[1]:SetPoint("BOTTOMLEFT", f.searchBg, "BOTTOMLEFT") sp[1]:SetWidth(capW)
    sp[3]:SetPoint("TOPRIGHT", f.searchBg, "TOPRIGHT") sp[3]:SetPoint("BOTTOMRIGHT", f.searchBg, "BOTTOMRIGHT") sp[3]:SetWidth(capW)
    sp[2]:SetPoint("TOPLEFT", sp[1], "TOPRIGHT") sp[2]:SetPoint("BOTTOMRIGHT", sp[3], "BOTTOMLEFT")
    f.search:ClearAllPoints()
    f.search:SetPoint("TOPLEFT", f.searchBg, "TOPLEFT", 14, -2)
    f.search:SetPoint("BOTTOMRIGHT", f.searchBg, "BOTTOMRIGHT", -14, 2)
    f.grow:ClearAllPoints()
    f.grow:SetPoint("TOPLEFT", f.bags, "TOPLEFT", 22, -102)
    f.cats:ClearAllPoints()
    f.cats:SetPoint("TOPLEFT", f.bags, "TOPLEFT", math.max(420, bw * 0.5), -102)
    f.moneyBg:ClearAllPoints()
    f.moneyBg:SetPoint("BOTTOM", f.bags, "BOTTOM", 0, 14)
    local mw = math.min(bw * 0.7, 380)
    f.moneyBg:SetSize(mw, mw / CS.MONEY_ASPECT)
    f.money:ClearAllPoints()
    f.money:SetPoint("CENTER", f.moneyBg, "CENTER", 0, 0)
    f.bagsScroll:ClearAllPoints()
    f.bagsScroll:SetPoint("TOPLEFT", f.bags, "TOPLEFT", 22, -134)
    f.bagsScroll:SetPoint("BOTTOMRIGHT", f.bags, "BOTTOMRIGHT", -34, 66)
    CS.UpdateBags()
end

-- Werte oder Ausrüstung nach Ereignis im mittleren Feld
function CS.SetView(view)
    local f = win
    if not f or not f.viewStats then return end
    if view ~= "gear" or not (FW.GearUI and FW.GearUI.Build) then view = "stats" end
    CS.Opts().view = view
    local gear = view == "gear"
    if gear and not f.gearView then f.gearView = FW.GearUI.Build(f.gearHost, "blizzard") end
    f.statsScroll:SetShown(not gear)
    f.gearHost:SetShown(gear)
    if gear and f.gearView and f.gearView.Refresh then f.gearView.Refresh() end
    f.viewStats.text:SetTextColor(gear and 0.6 or 1, gear and 0.55 or 0.85, gear and 0.45 or 0.45)
    f.viewGear.text:SetTextColor(gear and 1 or 0.6, gear and 0.85 or 0.55, 0.45)
end

function CS.UpdateHeader()
    local f = win
    local name = (FW.Whisper and FW.Whisper.SelfName and FW.Whisper.SelfName()) or (G.UnitName and G.UnitName("player")) or ""
    f.name:SetText(name)
    local lvl = Safe(G.UnitLevel, "player") or 0
    local cls = Safe(G.UnitClass, "player") or ""
    f.level:SetText(string.format(L().CS_LEVEL, lvl, cls))
    if f.model.SetUnit then pcall(f.model.SetUnit, f.model, "player") end
    if f.model.SetFacing then pcall(f.model.SetFacing, f.model, f.model.rot or 0) end
    f.money:SetText(CS.MoneyText(Safe(G.GetMoney) or 0))
end

function CS.UpdateSlots()
    for _, b in ipairs(win.slots) do if b then b:Update() end end
end

function CS.UpdateStats()
    local f = win
    local y = 0
    local n = 0
    local w = f.statsChild:GetWidth()
    local function Row(kind)
        n = n + 1
        local r = f.statRows[n]
        if not r then
            r = CreateFrame("Frame", nil, f.statsChild)
            r.bar = r:CreateTexture(nil, "BACKGROUND")
            r.bar:SetTexture(MEDIA .. "StatsHeader.tga")
            r.bar:SetTexCoord(0, 1, 4 / 64, 59 / 64)
            r.bar:SetAllPoints(r)
            r.div = r:CreateTexture(nil, "BACKGROUND")
            r.div:SetTexture(MEDIA .. "StatsDivider.tga")
            r.div:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT")
            r.div:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT")
            r.div:SetHeight(4)
            r.l = r:CreateFontString(nil, "OVERLAY")
            r.v = r:CreateFontString(nil, "OVERLAY")
            -- Schrift sofort setzen: SetText auf eine Zeile ohne Schrift bricht mit "Font not set" ab, dann blieben
            -- alle Werte leer (0.61.1)
            UI.SetFont(r.l, "body", 14)
            UI.SetFont(r.v, "body", 14)
            r.l:SetPoint("LEFT", r, "LEFT", 10, 0)
            r.v:SetPoint("RIGHT", r, "RIGHT", -10, 0)
            f.statRows[n] = r
        end
        r.kind = kind
        r:Show()
        return r
    end
    for _, sec in ipairs(CS.Stats()) do
        local h = Row("head")
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", f.statsChild, "TOPLEFT", 0, -y)
        h:SetSize(w, 30)
        h.bar:Show() h.div:Hide()
        UI.SetFont(h.l, "heading", 16)
        h.l:SetTextColor(1, 0.85, 0.45)
        h.l:SetText(sec.title)
        h.v:SetText("")
        y = y + 36
        for _, row in ipairs(sec.rows) do
            local r = Row("row")
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f.statsChild, "TOPLEFT", 0, -y)
            r:SetSize(w, 24)
            r.bar:Hide() r.div:Show()
            UI.SetFont(r.l, "body", 14)
            UI.SetFont(r.v, "body", 14)
            r.l:SetTextColor(0.95, 0.92, 0.85)
            r.v:SetTextColor(0.95, 0.92, 0.85)
            r.l:SetText(row[1] .. ":")
            r.v:SetText(row[2])
            y = y + 26
        end
        y = y + 8
    end
    for i = n + 1, #f.statRows do f.statRows[i]:Hide() end
    f.statsChild:SetHeight(math.max(1, y))
end

------------------------------------------------------------------------
-- Kategorien (0.62.0)
------------------------------------------------------------------------

CS.CATS = { "gear", "consumable", "trade", "recipe", "quest", "other", "junk", "free" }
CS.SPECIAL = { "ammo", "soul", "reagent" }       -- eigene Bereiche unten (Köcher/Munitionsbeutel, Seelentasche, Reagenzientasche)
CS.SORTS = { "bag", "quality", "name", "count" }

-- Spezialtasche? Taschenart aus GetContainerNumFreeSlots (Bits: 1 Köcher, 2 Munitionsbeutel, 4 Seelentasche)
function CS.BagKind(bag)
    if bag == 5 then return "reagent" end
    if bag == 0 then return nil end
    local C = G.C_Container
    local _, family
    if C and C.GetContainerNumFreeSlots then _, family = Safe(C.GetContainerNumFreeSlots, bag)
    elseif G.GetContainerNumFreeSlots then _, family = Safe(G.GetContainerNumFreeSlots, bag) end
    family = tonumber(family) or 0
    if family % 4 >= 1 then return "ammo" end           -- Bit 1 oder 2
    if math.floor(family / 4) % 2 == 1 then return "soul" end
    return nil
end

-- Kategorie eines Platzes aus der Itemart des Spiels
function CS.Category(info, bag, slot)
    if not info or not info.iconFileID then return "free" end
    if info.quality == 0 then return "junk" end
    local id = info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)")))
    local C = G.C_Container
    if C and C.GetContainerItemQuestInfo and bag then
        local q = Safe(C.GetContainerItemQuestInfo, bag, slot)
        if type(q) == "table" and (q.isQuestItem or q.questID) then return "quest" end
    end
    local classID
    local CI = G.C_Item
    if id and CI and CI.GetItemInfoInstant then classID = select(6, Safe(CI.GetItemInfoInstant, id))
    elseif id and G.GetItemInfoInstant then classID = select(6, Safe(G.GetItemInfoInstant, id)) end
    if classID == 12 then return "quest" end
    if classID == 2 or classID == 4 then return "gear" end
    if classID == 0 then return "consumable" end
    if classID == 5 or classID == 7 then return "trade" end
    if classID == 9 then return "recipe" end
    return "other"
end

local function ItemName(e) return (e.info and e.info.hyperlink and e.info.hyperlink:match("%[(.-)%]")) or "" end

function CS.SortEntries(list, mode)
    if mode == nil or mode == "bag" then return list end
    table.sort(list, function(a, b)
        local ia, ib = a.info or {}, b.info or {}
        if mode == "quality" and (ia.quality or 0) ~= (ib.quality or 0) then return (ia.quality or 0) > (ib.quality or 0) end
        if mode == "count" and (ia.stackCount or 0) ~= (ib.stackCount or 0) then return (ia.stackCount or 0) > (ib.stackCount or 0) end
        local na, nb = ItemName(a), ItemName(b)
        if na ~= nb then return na < nb end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list
end

-- Abschnitte bauen: { { id, title, entries = { {bag, slot, info} }, special, used, total } }
function CS.Sections()
    local o = CS.Opts()
    local normal, special = {}, {}
    for _, bag in ipairs(CS.BAGS) do
        local n = ContainerSlots(bag)
        if n > 0 then
            local kind = CS.BagKind(bag)
            for slot = 1, n do
                local e = { bag = bag, slot = slot, info = ContainerInfo(bag, slot) }
                if kind then
                    special[kind] = special[kind] or { id = kind, special = true, entries = {}, used = 0, total = 0, bags = {} }
                    local sp = special[kind]
                    sp.entries[#sp.entries + 1] = e
                    sp.total = sp.total + 1
                    if e.info and e.info.iconFileID then sp.used = sp.used + 1 end
                    sp.bags[bag] = true
                else
                    normal[#normal + 1] = e
                end
            end
        end
    end
    local out = {}
    if o.categories then
        local byCat = {}
        for _, e in ipairs(normal) do
            local c = CS.Category(e.info, e.bag, e.slot)
            byCat[c] = byCat[c] or {}
            table.insert(byCat[c], e)
        end
        for _, c in ipairs(CS.CATS) do
            if byCat[c] then
                out[#out + 1] = { id = c, entries = (c == "free") and byCat[c] or CS.SortEntries(byCat[c], o.sort[c]) }
            end
        end
    else
        out[#out + 1] = { id = "all", entries = CS.SortEntries(normal, o.sort.all), plain = true }
    end
    for _, k in ipairs(CS.SPECIAL) do if special[k] then out[#out + 1] = special[k] end end
    return out
end

local HEAD_H = 24

-- Höhe aller Abschnitte bei cols Spalten und Platzgröße size
function CS.SectionsHeight(sections, cols, size)
    local h = 4
    for _, sec in ipairs(sections) do
        if not sec.plain then h = h + HEAD_H + 4 end
        if not CS.Opts().collapsed[sec.id] or sec.plain then
            h = h + math.ceil(#sec.entries / cols) * (size + 4) + 6
        end
    end
    return h
end

function CS.FitGrid(w, h, sections, S, grow)
    local pad = 4
    local size = S
    while true do
        local cols = math.max(1, math.floor((w + pad) / (size + pad)))
        if not grow or size <= 18 or CS.SectionsHeight(sections, cols, size) <= h then return cols, size end
        size = size - 2
    end
end

local function HeadButton(id)
    local f = win
    local hb = f.bagHeads[id]
    if hb then return hb end
    hb = CreateFrame("Button", nil, f.bagsChild)
    hb:SetHeight(HEAD_H)
    hb.bar = hb:CreateTexture(nil, "BACKGROUND")
    hb.bar:SetTexture(MEDIA .. "StatsHeader.tga")
    hb.bar:SetTexCoord(0, 1, 4 / 64, 59 / 64)
    hb.bar:SetAllPoints(hb)
    hb.text = hb:CreateFontString(nil, "OVERLAY")
    UI.SetFont(hb.text, "heading", 14)
    hb.text:SetTextColor(1, 0.85, 0.45)
    hb.text:SetPoint("LEFT", hb, "LEFT", 8, 0)
    hb:SetScript("OnClick", function()
        local c = CS.Opts().collapsed
        c[id] = not c[id] or nil
        CS.UpdateBags()
    end)
    hb:SetScript("OnEnter", function(self)
        if G.GameTooltip then G.GameTooltip:SetOwner(self, "ANCHOR_TOP") G.GameTooltip:SetText(L().CS_HEAD_TIP) G.GameTooltip:Show() end
    end)
    hb:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    -- Sortierung je Kategorie zum Durchschalten
    hb.sort = CreateFrame("Button", nil, hb)
    hb.sort:SetSize(150, HEAD_H)
    hb.sort:SetPoint("RIGHT", hb, "RIGHT", -6, 0)
    hb.sort.text = hb.sort:CreateFontString(nil, "OVERLAY")
    UI.SetFont(hb.sort.text, "body", 12)
    hb.sort.text:SetTextColor(0.85, 0.82, 0.7)
    hb.sort.text:SetPoint("RIGHT", hb.sort, "RIGHT", 0, 0)
    hb.sort:SetScript("OnClick", function()
        local o = CS.Opts()
        local cur = o.sort[id] or "bag"
        local nextMode = CS.SORTS[1]
        for i, m in ipairs(CS.SORTS) do if m == cur then nextMode = CS.SORTS[i % #CS.SORTS + 1] end end
        o.sort[id] = nextMode ~= "bag" and nextMode or nil
        CS.UpdateBags()
    end)
    hb.sort:SetScript("OnEnter", function(self)
        if G.GameTooltip then G.GameTooltip:SetOwner(self, "ANCHOR_TOP") G.GameTooltip:SetText(L().CS_SORT_TIP) G.GameTooltip:Show() end
    end)
    hb.sort:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    f.bagHeads[id] = hb
    return hb
end

local function BagNames(sec)
    local names = {}
    local C = G.C_Container
    for bag in pairs(sec.bags or {}) do
        local n = C and C.GetBagName and Safe(C.GetBagName, bag)
        if n then names[#names + 1] = n end
    end
    table.sort(names)
    return table.concat(names, ", ")
end

local function FillButton(b, info, text, size)
    b:SetSize(size, size)
    if b.FwFit and b.fwFitted ~= size then b:FwFit(size) b.fwFitted = size end
    local tex = info and info.iconFileID
    if G.SetItemButtonTexture then G.SetItemButtonTexture(b, tex) elseif b.icon then b.icon:SetTexture(tex) end
    if G.SetItemButtonCount then G.SetItemButtonCount(b, info and info.stackCount or 0) end
    if G.SetItemButtonDesaturated then G.SetItemButtonDesaturated(b, info and info.isLocked) end
    if type(b.IconBorder) == "table" then
        local r, g2, bb = QualityColor(info and info.quality)
        if r and info.quality >= 2 then b.IconBorder:SetVertexColor(r, g2, bb) b.IconBorder:Show() else b.IconBorder:Hide() end
    end
    b:SetAlpha(CS.MatchSearch(info, text) and 1 or 0.25)
    b:Show()
end

function CS.UpdateBags()
    local f = win
    if not f or not f.lay then return end
    local o = CS.Opts()
    local sections = CS.Sections()
    local areaW = f.bagsScroll:GetWidth()
    local areaH = f.bagsScroll:GetHeight()
    if not areaW or areaW <= 0 then areaW = f.lay.bags.w - 56 areaH = f.lay.bags.h - 200 end
    local cols, size = CS.FitGrid(areaW, areaH, sections, f.lay.S, o.grow)
    local text = f.search:GetText()
    f.bagButtons = f.bagButtons or {}
    local used, heads = {}, {}
    local y = 4
    for _, sec in ipairs(sections) do
        if not sec.plain then
            local hb = HeadButton(sec.id)
            heads[sec.id] = true
            hb:ClearAllPoints()
            hb:SetPoint("TOPLEFT", f.bagsChild, "TOPLEFT", 4, -y)
            hb:SetWidth(math.max(40, cols * (size + 4) - 4))
            local fold = o.collapsed[sec.id] and "+ " or "– "
            local title = L()["CS_C_" .. sec.id] or sec.id
            if sec.special then
                local names = BagNames(sec)
                hb.text:SetText(fold .. title .. string.format("  %d/%d", sec.used, sec.total) .. (names ~= "" and ("  ·  " .. names) or ""))
            else
                hb.text:SetText(fold .. title .. string.format(" (%d)", #sec.entries))
            end
            local canSort = not sec.special and sec.id ~= "free"
            hb.sort:SetShown(canSort)
            hb.sort.text:SetText(canSort and L()["CS_SORT_" .. (o.sort[sec.id] or "bag")] or "")
            hb:Show()
            y = y + HEAD_H + 4
        end
        if not o.collapsed[sec.id] or sec.plain then
            for i, e in ipairs(sec.entries) do
                local key = e.bag .. ":" .. e.slot
                local b = f.bagButtons[key]
                if b == nil then
                    b = MakeBagButton(e.bag, e.slot) or false
                    f.bagButtons[key] = b
                end
                if b then
                    local col = (i - 1) % cols
                    local row = math.floor((i - 1) / cols)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", f.bagsChild, "TOPLEFT", 4 + col * (size + 4), -(y + row * (size + 4)))
                    FillButton(b, e.info, text, size)
                    used[key] = true
                end
            end
            y = y + math.ceil(#sec.entries / cols) * (size + 4) + 6
        end
    end
    -- nicht gezeigte Plätze (eingeklappt, Tasche getauscht) und Überschriften verstecken
    for key, b in pairs(f.bagButtons) do if b and not used[key] then b:Hide() end end
    for id, hb in pairs(f.bagHeads) do if not heads[id] then hb:Hide() end end
    f.bagsChild:SetSize(math.max(1, areaW), math.max(1, y + 4))
end

function CS.UpdateAll()
    if not win or not win:IsShown() then return end
    CS.UpdateHeader()
    CS.UpdateSlots()
    CS.UpdateStats()
    CS.UpdateBags()
end

------------------------------------------------------------------------
-- Öffnen, Taste, Reiter am Charakterfenster
------------------------------------------------------------------------

function CS.Toggle()
    local f = Build()
    if f:IsShown() then f:Hide() return end
    -- Blizzards Fenster schließen (nicht im Kampf: dort nur darüberlegen, kein Eingriff in die Fenster-Verwaltung)
    local cf = G.CharacterFrame
    if cf and cf:IsShown() and not (G.InCombatLockdown and G.InCombatLockdown()) and G.HideUIPanel then pcall(G.HideUIPanel, cf) end
    f:Show()
end
function Freewood_ToggleCharSheet() CS.Toggle() end

-- Taste "C" (Charakterfenster) wahlweise auf unser Fenster legen (Override-Belegung, nie im Kampf)
local bindOwner
function CS.ApplyBinding()
    if not G.SetOverrideBinding or not G.ClearOverrideBindings then return end
    if G.InCombatLockdown and G.InCombatLockdown() then CS.bindPending = true return end
    bindOwner = bindOwner or CreateFrame("Frame")
    G.ClearOverrideBindings(bindOwner)
    if not CS.Opts().takeC then return end
    local keys = { G.GetBindingKey and G.GetBindingKey("TOGGLECHARACTER0") }
    for _, key in ipairs(keys) do
        if key then G.SetOverrideBinding(bindOwner, false, key, "FREEWOOD_CORE_CHARSHEET") end
    end
end

-- Reiter mit Freewood-Logo unter Blizzards Seitenreitern (Forever) am Charakterfenster
local sideTab
local function FindLowestSideTab(cf)
    local right = cf:GetRight()
    if not right then return nil end
    local best, bestBottom
    for _, child in ipairs({ cf:GetChildren() }) do
        if child ~= sideTab and child.IsShown and child:IsShown() and child.GetLeft and child:GetLeft() then
            local l, b, w, h = child:GetLeft(), child:GetBottom(), child:GetWidth(), child:GetHeight()
            if l and l >= right - 12 and w and w >= 28 and w <= 80 and h and h >= 28 and h <= 80 then
                if not bestBottom or b < bestBottom then best, bestBottom = child, b end
            end
        end
    end
    return best
end

function CS.SetupTab()
    local cf = G.CharacterFrame
    if not cf or sideTab then return end
    sideTab = CreateFrame("Button", nil, cf)
    sideTab:SetSize(48, 48)
    sideTab.bg = sideTab:CreateTexture(nil, "BACKGROUND")
    sideTab.bg:SetTexture(MEDIA .. "Slot.tga")
    sideTab.bg:SetAllPoints(sideTab)
    sideTab.icon = sideTab:CreateTexture(nil, "ARTWORK")
    sideTab.icon:SetTexture(LOGO)
    sideTab.icon:SetPoint("TOPLEFT", sideTab, "TOPLEFT", 6, -6)
    sideTab.icon:SetPoint("BOTTOMRIGHT", sideTab, "BOTTOMRIGHT", -6, 6)
    sideTab.glow = Glow(sideTab)
    sideTab:SetScript("OnEnter", function(self)
        self.glow:SetVertexColor(1, 0.85, 0.4) self.glow:Show()
        if G.GameTooltip then G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT") G.GameTooltip:SetText(L().CS_TAB_TIP) G.GameTooltip:Show() end
    end)
    sideTab:SetScript("OnLeave", function(self) self.glow:Hide() if G.GameTooltip then G.GameTooltip:Hide() end end)
    sideTab:SetScript("OnClick", function() CS.Toggle() end)
    local function Anchor()
        sideTab:ClearAllPoints()
        local low = FindLowestSideTab(cf)
        if low then
            sideTab:SetSize(low:GetWidth(), low:GetHeight())
            sideTab:SetPoint("TOP", low, "BOTTOM", 0, -4)
        else
            sideTab:SetPoint("TOPLEFT", cf, "TOPRIGHT", 0, -40 - 6 * 54)
        end
        sideTab:SetShown(CS.Opts().tab and true or false)
    end
    cf:HookScript("OnShow", function() if G.C_Timer then G.C_Timer.After(0, Anchor) else Anchor() end end)
    if cf:IsShown() then Anchor() end
    CS.tab = sideTab
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

-- Aufträge sammeln und gemeinsam ausführen. Bis 0.64.0 ging ein zweiter Auftrag verloren, solange der erste wartete:
-- Beim Anziehen aus der Tasche kommt BAG_UPDATE vor PLAYER_EQUIPMENT_CHANGED, das neue Symbol am Platz fehlte (0.64.1).
local jobs = {}
local function Soon(fn)
    local first = #jobs == 0
    for _, f in ipairs(jobs) do if f == fn then return end end
    jobs[#jobs + 1] = fn
    if not first then return end
    local function Run()
        local list = jobs
        jobs = {}
        for _, f in ipairs(list) do pcall(f) end
    end
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(0.1, Run) else Run() end
end
CS.Soon = Soon

FW:RegisterEvent("PLAYER_LOGIN", function()
    pcall(CS.SetupTab)
    pcall(CS.ApplyBinding)
end)
FW:RegisterEvent("ADDON_LOADED", function(name) if name == "Blizzard_CharacterFrame" or name == "Blizzard_UIPanels_Game" then pcall(CS.SetupTab) end end)
FW:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if CS.bindPending then CS.bindPending = false pcall(CS.ApplyBinding) end
    if win and win:IsShown() then Soon(CS.UpdateStats) end
end)
FW:RegisterEvent("UPDATE_BINDINGS", function() if not CS.applying then CS.applying = true pcall(CS.ApplyBinding) CS.applying = false end end)
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY" }) do
    FW:RegisterEvent(ev, function() if win and win:IsShown() then Soon(function() CS.UpdateBags() CS.UpdateHeader() end) end end)
end
for _, ev in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UNIT_STATS", "UNIT_AURA", "PLAYER_LEVEL_UP",
    "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_MAXHEALTH" }) do
    FW:RegisterEvent(ev, function(unit)
        if unit and unit ~= "player" and ev ~= "PLAYER_EQUIPMENT_CHANGED" and ev ~= "PLAYER_LEVEL_UP" then return end
        if win and win:IsShown() then Soon(function() CS.UpdateSlots() CS.UpdateStats() CS.UpdateHeader() end) end
    end)
end

------------------------------------------------------------------------
-- Einstellungen > Design > Charakteransicht
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("charsheet", {
        category = "design",
        order = 40,
        build = function(parent)
            local Lx = L()
            local f, stack = UI.CreateSection(parent, Lx.CS_SET_TITLE)
            if f.AddInfo then f:AddInfo(Lx.CS_SET_INFO) end
            stack:Add(UI.CreateCheckbox(f, Lx.CS_SET_TAB, function() return CS.Opts().tab end, function(v)
                CS.Opts().tab = v and true or false
                if CS.tab then CS.tab:SetShown(CS.Opts().tab) end
            end), { fit = true, gap = 4 })
            stack:Add(UI.CreateCheckbox(f, Lx.CS_SET_C, function() return CS.Opts().takeC end, function(v)
                CS.Opts().takeC = v and true or false
                CS.ApplyBinding()
            end), { fit = true, gap = 4 })
            stack:Add(UI.CreateCheckbox(f, Lx.CS_SET_RACE, function() return CS.Opts().race end, function(v)
                CS.Opts().race = v and true or false
                CS.ApplyRace()
            end), { fit = true, gap = 4 })
            return f
        end,
    })
end

CS.Build = Build
