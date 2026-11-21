local _, ns = ...
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

ns.RegisterSpec{
    spells = { "Sunder Armor", "Heroic Strike", "Shield Slam", "Shield Bash", "Last Stand", "Shield Wall", "Concussion Blow", "Bloodrage", "Battle Shout", "Charge", "Intercept", "Shield Block", "Victory Rush", "Revenge", "Execute", "Thunder Clap", "Demoralizing Shout", "Cleave" },
    class = "WARRIOR", tree = 3, name = "Protection", alias = "protwarrior",
    filler = { "Shield Slam", "Revenge", "Sunder Armor" }, -- shown dimmed when nothing else fits
    melee = { "Sunder Armor", "Heroic Strike", "Shield Slam" },
    interrupt = "Shield Bash",
    cooldowns = { "Last Stand", "Shield Wall", "Concussion Blow", "Bloodrage" },
    resource = function() return ns.PowerShown(ns.PT.Rage), 1, 0.25, 0.25 end,
    next = function()
        if not ns.HasHostileTarget() then
            if Ready("Battle Shout") and not HasBuff("Battle Shout") then return "Battle Shout" end
            return nil
        end
        local rage, hp, enemies = ns.Power(ns.PT.Rage), ns.HealthPct(), ns.Enemies()

        if not ns.InMelee() then
            return ReadyAny("Charge", "Intercept")
        end
        if ns.InCombat() and not HasBuff("Shield Block") and Ready("Shield Block") then return "Shield Block" end
        if hp < 85 and Ready("Victory Rush") then return "Victory Rush" end
        if Ready("Revenge") then return "Revenge" end
        if Ready("Shield Slam") then return "Shield Slam" end
        if Ready("Execute") then return "Execute" end
        if enemies >= 2 then
            if not ns.TargetHasDebuff("Thunder Clap") and Ready("Thunder Clap") then return "Thunder Clap" end
            if not ns.TargetHasDebuff("Demoralizing Shout") and Ready("Demoralizing Shout") then
                return "Demoralizing Shout"
            end
        end
        local _, sunders = ns.Debuff("Sunder Armor")
        if sunders < 5 and Ready("Sunder Armor") then return "Sunder Armor" end
        if not HasBuff("Battle Shout") and Ready("Battle Shout") then return "Battle Shout" end
        if rage >= 40 then
            local swing = (enemies >= 2 and Known("Cleave")) and "Cleave" or "Heroic Strike"
            if not ns.Queued(swing) and Ready(swing) then return swing end
        end
        return ReadyAny("Sunder Armor", "Victory Rush")
    end,
}
