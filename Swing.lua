-- LevelCoach swing timer: tracks your main-hand and off-hand auto-attacks from the combat log.
local _, ns = ...

local swing = { mh = { start = 0, speed = 0 }, oh = { start = 0, speed = 0 } }
ns.swing = swing

-- Next-swing abilities replace a main-hand auto-attack, so they reset the main-hand timer too.
local NEXT_SWING = { ["Heroic Strike"] = true, ["Cleave"] = true, ["Maul"] = true, ["Raptor Strike"] = true }

local function Speeds()
    local mh, oh = UnitAttackSpeed("player")
    return mh or 0, oh or 0
end

local function Reset(hand)
    local mh, oh = Speeds()
    local t = swing[hand]
    t.start = GetTime()
    t.speed = (hand == "mh") and mh or oh
end

-- Seconds until the next swing of that hand (0 = ready / unknown)
function ns.SwingRemaining(hand)
    local t = swing[hand or "mh"]
    if t.speed == 0 then return 0 end
    return math.max(0, t.start + t.speed - GetTime())
end

-- Seconds since that hand last swung (999 = never)
function ns.SwingSince(hand)
    local t = swing[hand or "mh"]
    if t.start == 0 then return 999 end
    return GetTime() - t.start
end

function ns.SwingActive()
    if not ns.swingAvailable then return false end
    return ns.InCombat() and swing.mh.start > 0 and ns.SwingSince("mh") < swing.mh.speed + 1.5
end

local playerGUID
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Clients with Blizzard's combat-data restrictions ("secret values", which WoW Forever has) don't let
-- addons use the combat log: registering it is what triggers "blocked from an action only available to
-- the Blizzard UI". Only use it on clients without those restrictions.
local toc = (GetBuildInfo and select(4, GetBuildInfo())) or 0
ns.restricted = (issecretvalue ~= nil) or (C_Secrets ~= nil) or (canaccessvalue ~= nil)
    or (C_DamageMeter ~= nil)                  -- Blizzard's built-in meter only exists on restricted clients
    or (toc >= 16000 and toc < 20000)          -- WoW Forever (1.60.x)
    or toc >= 120000                           -- Retail Midnight and later
ns.swingAvailable = not ns.restricted
if ns.swingAvailable then f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
f:RegisterEvent("UNIT_ATTACK_SPEED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
    elseif event == "PLAYER_REGEN_ENABLED" then
        swing.mh.start, swing.oh.start = 0, 0
    elseif event == "UNIT_ATTACK_SPEED" then
        -- Haste changed mid-swing (e.g. Flurry): rescale the remaining time
        if unit ~= "player" then return end
        local mh, oh = Speeds()
        for hand, speed in pairs({ mh = mh, oh = oh }) do
            local t = swing[hand]
            if t.speed > 0 and speed > 0 and t.start > 0 then
                local done = (GetTime() - t.start) / t.speed
                t.speed = speed
                t.start = GetTime() - done * speed
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not CombatLogGetCurrentEventInfo then return end
        local info = { CombatLogGetCurrentEventInfo() }
        local sub, source = info[2], info[4]
        if source ~= (playerGUID or UnitGUID("player")) then return end
        if sub == "SWING_DAMAGE" then
            Reset(info[21] and "oh" or "mh")
        elseif sub == "SWING_MISSED" then
            Reset(info[13] and "oh" or "mh")
        elseif (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") and NEXT_SWING[info[13]] then
            Reset("mh")
        end
    end
end)
