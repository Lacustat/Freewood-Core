-- Freewood-Core: Statistik, Sammeln
-- Haengt sich an Ereignisse und zaehlt (siehe StatsData.lua). Nur lesen, nie etwas im Spiel veraendern.
-- UNGEPRUEFT im Spiel (Forever): Ereignisnamen, Chatkonstanten und Hooks sind aus Retail/Classic uebernommen.

local ADDON, FW = ...

local Stats = FW.Stats
if not Stats then return end

local G = _G
local function Clean(v) if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end return v end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return Clean(a), Clean(b), Clean(c), Clean(d)
end
local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end
local function Shown(frame) return frame and frame.IsShown and frame:IsShown() and true or false end

local mod = FW:NewModule("Stats", {
    defaults = { chars = {}, open = { overview = true, combat = true }, selected = nil },
})
Stats.module = mod

local owner = {}
local state = { lastMoney = nil, questAt = -10, lootAt = -10, combatAt = nil, taxi = false, taxiAt = 0, lastLoc = nil, snapAt = -100, inst = nil }

------------------------------------------------------------------------
-- Eigene Daten
------------------------------------------------------------------------

function Stats.UpdateInfo()
    local rec = Stats.Rec()
    if not rec then return end
    local info = rec.info
    local name = Call(G.UnitName, "player")
    if type(name) == "string" then info.name = name end
    local classLocal, class = Call(G.UnitClass, "player")
    info.classLocal, info.class = classLocal, class
    info.race = Call(G.UnitRace, "player") or info.race
    info.faction = Call(G.UnitFactionGroup, "player") or info.faction
    info.level = Call(G.UnitLevel, "player") or info.level
    local guild, rank = Call(G.GetGuildInfo, "player")
    info.guild, info.rank = guild, rank
    rec.last = Now()
end

local function Stat(i) local _, eff = Call(G.UnitStat, "player", i) return eff end

function Stats.Snapshot()
    if G.InCombatLockdown and G.InCombatLockdown() then return end
    local rec = Stats.Rec()
    if not rec then return end
    local s = rec.snap
    s.at = Now()
    s.health = Call(G.UnitHealthMax, "player")
    s.power = Call(G.UnitPowerMax, "player")
    s.str, s.agi, s.sta, s.int, s.spi = Stat(1), Stat(2), Stat(3), Stat(4), Stat(5)
    local _, armor = Call(G.UnitArmor, "player")
    s.armor = armor
    local ab, ap, an = Call(G.UnitAttackPower, "player")
    if ab then s.ap = ab + (ap or 0) + (an or 0) end
    local rb, rp, rn = Call(G.UnitRangedAttackPower, "player")
    if rb then s.rap = rb + (rp or 0) + (rn or 0) end
    s.sp = Call(G.GetSpellBonusDamage, 2)
    s.hp = Call(G.GetSpellBonusHealing)
    s.crit = Call(G.GetCritChance)
    s.scrit = Call(G.GetSpellCritChance, 2)
    s.dodge = Call(G.GetDodgeChance)
    s.parry = Call(G.GetParryChance)
    s.block = Call(G.GetBlockChance)
    local cur = Call(G.GetUnitSpeed, "player")
    if type(cur) == "number" then s.speed = cur / 7 * 100 end
    local avg, equipped = Call(G.GetAverageItemLevel)
    s.ilvl = equipped or avg
    -- Haltbarkeit: Durchschnitt ueber die Plaetze 1 bis 19
    local sum, n = 0, 0
    for slot = 1, 19 do
        local cur2, max = Call(G.GetInventoryItemDurability, slot)
        if type(cur2) == "number" and type(max) == "number" and max > 0 then sum, n = sum + cur2 / max, n + 1 end
    end
    s.dura = n > 0 and (sum / n * 100) or nil
    -- Taschen
    local free, total = 0, 0
    for bag = 0, tonumber(G.NUM_BAG_SLOTS) or 4 do
        local f = (G.C_Container and G.C_Container.GetContainerNumFreeSlots) or G.GetContainerNumFreeSlots
        local t = (G.C_Container and G.C_Container.GetContainerNumSlots) or G.GetContainerNumSlots
        local fv, tv = Call(f, bag), Call(t, bag)
        if type(fv) == "number" and type(tv) == "number" then free, total = free + fv, total + tv end
    end
    if total > 0 then s.bagFree, s.bagTotal = free, total end
    s.money = Call(G.GetMoney)
    if Stats.World and Stats.World.Refresh and (Now() - ((rec.w and rec.w.at) or 0)) > 300 then pcall(Stats.World.Refresh, true) end
    if s.money then rec.c.maxMoney = math.max(rec.c.maxMoney or 0, s.money) end
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

local lootPatterns, xpKill, xpOther
local function BuildPatterns()
    lootPatterns = {}
    local function Add(name, kind, multi)
        local p = Stats.PatternFor(G[name])
        if p then lootPatterns[#lootPatterns + 1] = { p = p, kind = kind, multi = multi } end
    end
    -- mehrfache zuerst, damit "xN" nicht im Link landet
    Add("LOOT_ITEM_SELF_MULTIPLE", "loot", true)
    Add("LOOT_ITEM_PUSHED_SELF_MULTIPLE", "loot", true)
    Add("LOOT_ITEM_CREATED_SELF_MULTIPLE", "craft", true)
    Add("LOOT_ITEM_SELF", "loot")
    Add("LOOT_ITEM_PUSHED_SELF", "loot")
    Add("LOOT_ITEM_CREATED_SELF", "craft")
    xpKill = Stats.PatternFor(G.COMBATLOG_XPGAIN_FIRSTPERSON)
    xpOther = Stats.PatternFor(G.COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED)
end

local function OnLoot(_, msg)
    msg = Clean(msg)
    if not lootPatterns then BuildPatterns() end
    local link, n, kind = Stats.ParseLoot(msg, lootPatterns)
    local rec = Stats.Rec()
    if not link or not rec then return end
    local q = Stats.QualityOfLink(link)
    if kind == "craft" then
        Stats.Inc(rec.c, "crafted", n)
        return
    end
    Stats.Inc(rec.c, "lootItems", n)
    if q then Stats.Inc(rec.c, "lootQ" .. q, n) end
    -- bester Fund: hoechste Qualitaet, danach Verkaufspreis
    local price = select(11, Call(G.GetItemInfo, link)) or 0
    local best = rec.best
    if q and (not best or q > (best.q or -1) or (q == best.q and price > (best.price or 0))) then
        rec.best = { link = link, q = q, price = price }
    end
    state.lootAt = Clock()
end

local function OnXP(_, msg)
    msg = Clean(msg)
    if not lootPatterns then BuildPatterns() end
    local xp, kill = Stats.ParseXP(msg, xpKill, xpOther)
    local rec = Stats.Rec()
    if not xp or not rec then return end
    Stats.Inc(rec.c, "xp", xp)
    if kill then
        Stats.Inc(rec.c, "xpKill", xp)
        Stats.Inc(rec.c, "kills", 1)
    end
end

local function OnMoney()
    local rec = Stats.Rec()
    local now = Call(G.GetMoney)
    if not rec or type(now) ~= "number" then return end
    local last = state.lastMoney
    state.lastMoney = now
    if not last or now == last then return end
    local delta = now - last
    local c = Clock()
    local src = Stats.MoneySource(delta, {
        merchant = Shown(G.MerchantFrame), mail = Shown(G.MailFrame),
        auction = Shown(G.AuctionHouseFrame) or Shown(G.AuctionFrame), trade = Shown(G.TradeFrame),
        questAge = c - state.questAt, lootAge = c - state.lootAt,
    })
    Stats.Inc(rec.c, delta > 0 and "moneyEarned" or "moneySpent", math.abs(delta))
    Stats.Inc(rec.c, "m_" .. src, math.abs(delta))
    rec.c.maxMoney = math.max(rec.c.maxMoney or 0, now)
end

local function OnCombatStart() state.combatAt = Clock() end
local function OnCombatEnd()
    local rec = Stats.Rec()
    if not rec or not state.combatAt then return end
    Stats.Inc(rec.c, "combats", 1)
    Stats.Inc(rec.c, "combatSecs", math.max(0, Clock() - state.combatAt))
    state.combatAt = nil
    Stats.UpdateInfo()
    Stats.Snapshot()
end

local function OnDead()
    local rec = Stats.Rec()
    if not rec then return end
    Stats.Inc(rec.c, "deaths", 1)
    local zone = Call(G.GetRealZoneText)
    if type(zone) == "string" and zone ~= "" then Stats.Inc(rec.dz, zone, 1) end
end

local function OnZone()
    local rec = Stats.Rec()
    if not rec then return end
    local z = Call(G.GetRealZoneText)
    if type(z) == "string" and z ~= "" and not rec.z[z] then rec.z[z] = Now() end
    local sz = Call(G.GetSubZoneText)
    if type(sz) == "string" and sz ~= "" and not rec.sz[sz] then rec.sz[sz] = Now() end
end

local function OnEnterWorld()
    local rec = Stats.Rec()
    if not rec then return end
    Stats.Inc(rec.c, "loads", 1)
    OnZone()
    local inInstance, kind = Call(G.IsInInstance)
    if inInstance and kind ~= "none" then
        local name = Call(G.GetInstanceInfo)
        if type(name) == "string" and name ~= state.inst then
            state.inst = name
            Stats.Inc(rec.c, "instances", 1)
            Stats.Inc(rec.inst, name, 1)
        end
    else
        state.inst = nil
    end
    Stats.UpdateInfo()
    state.lastMoney = Call(G.GetMoney)
    state.lastLoc = nil
end

local function OnCast(_, unit, _, spellID)
    if Clean(unit) ~= "player" then return end
    spellID = Clean(spellID)
    local rec = Stats.Rec()
    if not rec or type(spellID) ~= "number" then return end
    Stats.Inc(rec.c, "casts", 1)
    Stats.Inc(rec.sp, spellID, 1)
end

local function OnQuestTurned(_, questID, xp, money)
    local rec = Stats.Rec()
    if not rec then return end
    Stats.Inc(rec.c, "questsDone", 1)
    xp, money = Clean(xp), Clean(money)
    if type(xp) == "number" then Stats.Inc(rec.c, "questXP", xp) end
    if type(money) == "number" then Stats.Inc(rec.c, "questMoney", money) end
    state.questAt = Clock()
end

local function Hook(name, fn)
    local target = G[name]
    if type(target) == "function" and G.hooksecurefunc then pcall(G.hooksecurefunc, name, fn) return true end
    return false
end

local function OnSendChat(msg, chatType)
    local rec = Stats.Rec()
    if not rec then return end
    Stats.Inc(rec.c, "chatMsgs", 1)
    if type(msg) == "string" and not (FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(msg)) then Stats.Inc(rec.c, "chatChars", #msg) end
    if type(chatType) == "string" then Stats.Inc(rec.ch, chatType, 1) end
end

------------------------------------------------------------------------
-- Zeitgeber: Online-Zeit, Gruppe, Wege
------------------------------------------------------------------------

local acc, lastT = 0, nil
local ticker = G.CreateFrame("Frame")
local function Tick(dt)
    local rec = Stats.Rec()
    if not rec then return end
    local c = rec.c
    Stats.Inc(c, "online", dt)
    if Call(G.IsResting) then Stats.Inc(c, "restSecs", dt) end
    if Call(G.UnitIsAFK, "player") then Stats.Inc(c, "afkSecs", dt) end
    if Call(G.IsInRaid) then Stats.Inc(c, "raidSecs", dt) elseif Call(G.IsInGroup) then Stats.Inc(c, "groupSecs", dt) end
    -- Taxi
    local onTaxi = Call(G.UnitOnTaxi, "player") and true or false
    if onTaxi then
        Stats.Inc(c, "taxiSecs", dt)
        if not state.taxi then Stats.Inc(c, "taxiTrips", 1) end
    end
    state.taxi = onTaxi
    -- Weg: Abstand der Weltpositionen, Spruenge (Portale, Ruhestein) werden uebersprungen
    if onTaxi or Call(G.UnitIsDeadOrGhost, "player") or Call(G.UnitInVehicle, "player") then
        state.lastLoc = nil
    else
        local loc = Stats.WorldPoint()
        local last = state.lastLoc
        state.lastLoc = loc
        if loc and last and loc.cont == last.cont then
            local d = math.sqrt((loc.x - last.x) ^ 2 + (loc.y - last.y) ^ 2)
            if d > 0 and d < 130 * dt + 5 then
                local key = "distFoot"
                if Call(G.IsFlying) then key = "distFly"
                elseif Call(G.IsSwimming) then key = "distSwim"
                elseif Call(G.IsMounted) then key = "distMount" end
                Stats.Inc(c, key, d)
            end
        end
    end
end

-- Kontinent und Weltposition (Yards) des Spielers
function Stats.WorldPoint()
    local CM = G.C_Map
    if not (CM and CM.GetBestMapForUnit and CM.GetPlayerMapPosition and CM.GetWorldPosFromMapPos and G.CreateVector2D) then return nil end
    local m = Call(CM.GetBestMapForUnit, "player")
    if type(m) ~= "number" then return nil end
    local pos = Call(CM.GetPlayerMapPosition, m, "player")
    if not pos or not pos.GetXY then return nil end
    local x, y = Call(pos.GetXY, pos)
    if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return nil end
    local ok, cont, wp = pcall(CM.GetWorldPosFromMapPos, m, G.CreateVector2D(x, y))
    if not ok or not cont or not wp or not wp.GetXY then return nil end
    local ok2, wx, wy = pcall(wp.GetXY, wp)
    if not ok2 or type(wx) ~= "number" or type(wy) ~= "number" then return nil end
    return { cont = cont, x = wx, y = wy }
end

ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 1 then return end
    local dt = acc
    acc = 0
    if dt > 5 then dt = 1 end        -- nach Pausen (Ladebildschirm) nicht aufholen
    pcall(Tick, dt)
    local now = Clock()
    if now - state.snapAt > 60 then
        state.snapAt = now
        pcall(Stats.Snapshot)
    end
end)

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

function mod:OnEnable()
    BuildPatterns()
    Stats.Rec()
    pcall(Stats.UpdateInfo)
    state.lastMoney = Call(G.GetMoney)
    local R = function(event, fn) FW:RegisterEvent(event, fn, owner) end
    R("CHAT_MSG_LOOT", OnLoot)
    R("CHAT_MSG_COMBAT_XP_GAIN", OnXP)
    R("CHAT_MSG_COMBAT_HONOR_GAIN", function() Stats.Count("honorKills", 1) end)
    R("PLAYER_MONEY", OnMoney)
    R("PLAYER_REGEN_DISABLED", OnCombatStart)
    R("PLAYER_REGEN_ENABLED", OnCombatEnd)
    R("PLAYER_DEAD", OnDead)
    R("ZONE_CHANGED_NEW_AREA", OnZone)
    R("ZONE_CHANGED", OnZone)
    R("ZONE_CHANGED_INDOORS", OnZone)
    R("PLAYER_ENTERING_WORLD", OnEnterWorld)
    R("UNIT_SPELLCAST_SUCCEEDED", OnCast)
    R("QUEST_ACCEPTED", function() Stats.Count("questsAccepted", 1) end)
    R("QUEST_TURNED_IN", OnQuestTurned)
    R("CHAT_MSG_WHISPER", function() Stats.Count("whispersIn", 1) end)
    R("PLAYER_LEVEL_UP", function() Stats.UpdateInfo() end)
    R("PLAYER_GUILD_UPDATE", function() Stats.UpdateInfo() end)
    R("TIME_PLAYED_MSG", function(_, total)
        total = Clean(total)
        local rec = Stats.Rec()
        if rec and type(total) == "number" then rec.played = total end
    end)
    if not Stats.hooked then
        Stats.hooked = true
        Hook("SendChatMessage", OnSendChat)
        if G.C_ChatInfo then pcall(G.hooksecurefunc, G.C_ChatInfo, "SendChatMessage", OnSendChat) end
        Hook("SendMail", function() Stats.Count("mailsSent", 1) end)
        Hook("JumpOrAscendStart", function() Stats.Count("jumps", 1) end)
        Hook("DoEmote", function() Stats.Count("emotes", 1) end)
    end
    ticker:Show()
    if Stats.World and Stats.World.Start then pcall(Stats.World.Start) end
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(5, function() pcall(Stats.Snapshot) end) end
end

function mod:OnDisable()
    ticker:Hide()
    for _, e in ipairs({ "CHAT_MSG_LOOT", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_MONEY", "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD",
        "UNIT_SPELLCAST_SUCCEEDED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "CHAT_MSG_WHISPER", "PLAYER_LEVEL_UP", "PLAYER_GUILD_UPDATE", "TIME_PLAYED_MSG" }) do
        FW:UnregisterEvent(e, owner)
    end
end
