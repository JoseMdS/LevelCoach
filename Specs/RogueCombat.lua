local _, ns = ...
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

-- Combat ("Outlaw") Rogue: Sinister Strike builder, Slice and Dice always up, Eviscerate at 5 points.
ns.RegisterSpec{
    spells = { "Sinister Strike", "Eviscerate", "Kick", "Adrenaline Rush", "Blade Flurry", "Evasion", "Sprint", "Throw", "Cheap Shot", "Garrote", "Riposte", "Slice and Dice", "Shank" },
    class = "ROGUE", tree = 2, name = "Combat", alias = "outlaw",
    filler = { "Sinister Strike" }, -- shown dimmed when nothing else fits
    melee = { "Sinister Strike", "Eviscerate" },
    interrupt = "Kick",
    cooldowns = { "Adrenaline Rush", "Blade Flurry", "Evasion", "Sprint" },
    resource = function() return ns.ComboPoints() .. " cp  " .. ns.PowerShown(ns.PT.Energy), 1, 0.9, 0.2 end,
    next = function()
        if not ns.HasHostileTarget() then return nil end
        local cp, hp, thp, enemies = ns.ComboPoints(), ns.HealthPct(), ns.HealthPct("target"), ns.Enemies()

        if not ns.InMelee() then
            if Ready("Throw") and ns.InRange("Throw") then return "Throw" end
            return nil
        end
        -- Opener: Cheap Shot works from the front; Garrote if you can get behind
        if ns.Stealthed() then
            local opener = ReadyAny("Cheap Shot", "Garrote", "Sinister Strike")
            if opener then return opener end
        end
        if hp < 35 and Ready("Evasion") then return "Evasion" end
        -- Two or more mobs: Blade Flurry makes every hit cleave
        if enemies >= 2 and not HasBuff("Blade Flurry") and Ready("Blade Flurry") then return "Blade Flurry" end
        -- Riposte only lights up after you parry: free damage
        if Ready("Riposte") then return "Riposte" end

        -- Finish a dying mob early instead of wasting combo points
        if not ns.Endgame() and cp >= 2 and thp < 15 and Ready("Eviscerate") then return "Eviscerate" end
        -- Keep Slice and Dice up (skip on mobs about to die)
        if cp >= 1 and ns.Lives(30) and not HasBuff("Slice and Dice") and Ready("Slice and Dice") then
            return "Slice and Dice"
        end
        if cp >= 5 and Ready("Eviscerate") then return "Eviscerate" end
        -- Forever: Shank (baseline at 24) is cheap, refunds energy and can't miss
        if Ready("Shank") then return "Shank" end
        if Ready("Sinister Strike") then return "Sinister Strike" end
    end,
}
