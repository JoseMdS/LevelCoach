local _, ns = ...
if ns.playerClass ~= "WARRIOR" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

ns.RegisterSpec{
    spells = { "Heroic Strike", "Hamstring", "Sunder Armor", "Pummel", "Death Wish", "Recklessness", "Berserker Rage", "Bloodrage", "Battle Shout", "Charge", "Intercept", "Victory Rush", "Execute", "Whirlwind", "Bloodthirst", "Overpower", "Slam", "Reckless Swings", "Rend", "Cleave", "Demoralizing Shout" },
    class = "WARRIOR", tree = 2, name = "Fury", default = true,
    filler = { "Bloodthirst", "Whirlwind", "Heroic Strike" }, -- shown dimmed when nothing else fits
    melee = { "Heroic Strike", "Hamstring", "Sunder Armor" },
    interrupt = "Pummel",
    cooldowns = { "Death Wish", "Recklessness", "Berserker Rage", "Bloodrage" },
    resource = function() return ns.PowerShown(ns.PT.Rage), 1, 0.25, 0.25 end,
    next = function()
        if not ns.HasHostileTarget() then
            if Ready("Battle Shout") and not HasBuff("Battle Shout") then return "Battle Shout" end
            return nil
        end
        local rage, hp, thp, enemies = ns.Power(ns.PT.Rage), ns.HealthPct(), ns.HealthPct("target"), ns.Enemies()

        if not ns.InMelee() then
            return ReadyAny("Charge", "Intercept")
        end
        if not HasBuff("Battle Shout") and Ready("Battle Shout") then return "Battle Shout" end
        -- Free heal after a kill (Forever: baseline at 20)
        if hp < 85 and Ready("Victory Rush") then return "Victory Rush" end
        if Ready("Execute") then return "Execute" end
        if enemies >= 2 and Ready("Whirlwind") then return "Whirlwind" end
        if Ready("Bloodthirst") then return "Bloodthirst" end
        if Ready("Whirlwind") then return "Whirlwind" end
        -- Slam right after a main-hand swing so its cast doesn't delay your next auto-attack
        if ns.SwingSince and ns.SwingSince("mh") < 0.4 and ns.SwingRemaining("mh") > 1.5
           and rage >= (Known("Bloodthirst") and 45 or 15) and Ready("Slam") then return "Slam" end
        if Ready("Overpower") then return "Overpower" end
        -- Forever Fury talent: costs health, refunds rage on the next swings
        if hp > 60 and Ready("Reckless Swings") then return "Reckless Swings" end
        -- Low level (no Bloodthirst yet): bleed mobs that will live a while
        if not Known("Bloodthirst") and ns.Lives(50) and ns.Debuff("Rend") == 0 and Ready("Rend") then return "Rend" end
        if Ready("Victory Rush") then return "Victory Rush" end
        -- Rage dump on next swing (off the global cooldown)
        local dumpAt = ns.Endgame() and 50 or (Known("Bloodthirst") and 60 or 20)
        if rage >= dumpAt then
            local swing = (enemies >= 2 and Known("Cleave")) and "Cleave" or "Heroic Strike"
            if not ns.Queued(swing) and Ready(swing) then return swing end
        end
        if ns.InCombat() and enemies >= 2 and not ns.TargetHasDebuff("Demoralizing Shout")
           and Ready("Demoralizing Shout") then return "Demoralizing Shout" end
    end,
}
