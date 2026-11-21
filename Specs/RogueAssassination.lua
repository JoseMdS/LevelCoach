local _, ns = ...
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

ns.RegisterSpec{
    spells = { "Sinister Strike", "Eviscerate", "Kick", "Cold Blood", "Evasion", "Sprint", "Throw", "Garrote", "Cheap Shot", "Slice and Dice", "Venom", "Envenom", "Shank", "Mutilate" },
    class = "ROGUE", tree = 1, name = "Assassination", default = true,
    filler = { "Mutilate", "Sinister Strike" }, -- shown dimmed when nothing else fits
    melee = { "Sinister Strike", "Eviscerate" },
    interrupt = "Kick",
    cooldowns = { "Cold Blood", "Evasion", "Sprint" },
    resource = function() return ns.ComboPoints() .. " cp  " .. ns.PowerShown(ns.PT.Energy), 1, 0.9, 0.2 end,
    next = function()
        if not ns.HasHostileTarget() then return nil end
        local cp, hp, thp = ns.ComboPoints(), ns.HealthPct(), ns.HealthPct("target")

        if not ns.InMelee() then
            if Ready("Throw") and ns.InRange("Throw") then return "Throw" end
            return nil
        end
        -- Stealth opener: Garrote (needs you behind the target); Cheap Shot as the front-facing backup
        if ns.Stealthed() then
            local opener = ReadyAny("Garrote", "Cheap Shot", "Sinister Strike")
            if opener then return opener end
        end
        if hp < 35 and Ready("Evasion") then return "Evasion" end

        -- Finish a dying mob early instead of wasting combo points
        if not ns.Endgame() and cp >= 2 and thp < 15 and Ready("Eviscerate") then return "Eviscerate" end
        -- Slice and Dice early on mobs with plenty of health
        -- Keep Slice and Dice up (guides: never let it drop); skip it only on mobs about to die
        if cp >= 1 and ns.Lives(30) and not HasBuff("Slice and Dice") and Ready("Slice and Dice") then
            return "Slice and Dice"
        end
        -- Venom (Forever): keep it up when it's an active finisher on your client
        if cp >= 3 and Known("Venom") and not HasBuff("Venom") and Ready("Venom") then return "Venom" end
        if cp >= 5 then
            local fin = ReadyAny("Envenom", "Eviscerate")
            if fin then return fin end
        end
        -- Forever: Shank (baseline at 24) is cheap, refunds energy and can't miss
        if Ready("Shank") then return "Shank" end
        local builder = ReadyAny("Mutilate", "Sinister Strike")
        if builder then return builder end
    end,
}
