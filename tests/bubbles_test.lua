-- Test Chat-Blasen: Sagen/Rufen/Emote, Schalter, eigene Nachrichten (texlua tests/bubbles_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function Proxy()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        return function(self, ...)
            if k == "SetText" then rawset(t, "txt", ... ) end
            if k == "GetStringHeight" then return 14 end
            if k == "GetFrameLevel" then return 1 end
            return Proxy()
        end
    end })
end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.UnitName = function() return "Pinky" end
local ev, secretText = {}, {}
local UI = setmetatable({ RegisterSettingsSection = function() end, SetFont = function() end },
    { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    RegisterEvent = function(_, e, f) ev[e] = f end, On = function() end, Fire = function() end,
    Util = { IsSecret = function(v) return secretText[v] == true end },
    Whisper = { SelfName = function() return "Pinky Freewood" end } }
assert(loadfile("UI/ChatBubbles.lua"))("Freewood-Core", FW)
local B = FW.ChatBubbles
for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" }) do eq(type(ev[e]), "function", e .. " registriert") end

ev.CHAT_MSG_SAY("Hallo", "Anna"); eq(B.Count(), 1, "Sagen als Blase")
ev.CHAT_MSG_YELL("Achtung", "Bob"); eq(B.Count(), 2, "Rufen als Blase")
ev.CHAT_MSG_EMOTE("tanzt", "Cid"); eq(B.Count(), 2, "Emote standardmaessig aus")
FW.settings.bubbles.emote = true
ev.CHAT_MSG_EMOTE("tanzt", "Cid"); eq(B.Count(), 3, "Emote an")
ev.CHAT_MSG_TEXT_EMOTE("Cid winkt dir zu.", "Cid"); eq(B.Count(), 4, "Text-Emote")
FW.settings.bubbles.say = false
ev.CHAT_MSG_SAY("noch eins", "Anna"); eq(B.Count(), 4, "Sagen aus")
FW.settings.bubbles.say = true
FW.settings.bubbles.own = false
ev.CHAT_MSG_SAY("ich", "Pinky Freewood"); eq(B.Count(), 4, "eigene Nachricht (voller Name) ausgeblendet")
ev.CHAT_MSG_SAY("ich", "Pinky"); eq(B.Count(), 4, "eigene Nachricht (Vorname) ausgeblendet")
FW.settings.bubbles.own = true
ev.CHAT_MSG_SAY("ich", "Pinky"); eq(B.Count(), 5, "eigene Nachricht an")
-- geheime Werte werden uebersprungen
secretText["geheim"] = true
ev.CHAT_MSG_SAY("geheim", "Anna"); eq(B.Count(), 5, "geheimer Text uebersprungen")
FW.settings.bubbles.enabled = false
ev.CHAT_MSG_YELL("aus", "Bob"); eq(B.Count(), 5, "alles aus")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
