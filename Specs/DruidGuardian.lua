local _, ns = ...
if ns.playerClass ~= "DRUID" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

ns.RegisterSpec{
    spells = { "Maul", "Swipe", "Claw", "Bash", "Frenzied Regeneration", "Enrage", "Barkskin", "Dire Bear Form", "Bear Form", "Feral Charge", "Faerie Fire (Feral)", "Demoralizing Roar", "Primal Bite", "Lacerate" },
    class = "DRUID", tree = 2, name = "Bear", alias = "guardian", default = true,
    -- Same talent tree as cat in Forever: this one is used while you're in Bear Form.
    when = function() return ns.InBearForm() end,
    filler = { "Primal Bite", "Maul" }, -- shown dimmed when nothing else fits
    melee = { "Maul", "Swipe", "Claw" },
    interrupt = "Bash",
    cooldowns = { "Frenzied Regeneration", "Enrage", "Barkskin" },
    resource = function() return ns.PowerShown(ns.PT.Rage), 1, 0.25, 0.25 end,
    next = function()
        if not ns.HasHostileTarget() then return nil end
        if not ns.InBearForm() then
            return ReadyAny("Dire Bear Form", "Bear Form") or ns.Druid.Caster()
        end
        local rage, hp, thp, enemies = ns.Power(ns.PT.Rage), ns.HealthPct(), ns.HealthPct("target"), ns.Enemies()

        if not ns.InMelee() then
            if Ready("Feral Charge") and ns.InRange("Feral Charge") then return "Feral Charge" end
            if not ns.TargetHasDebuff("Faerie Fire (Feral)") and Ready("Faerie Fire (Feral)") then
                return "Faerie Fire (Feral)"
            end
            return nil
        end
        if ns.InCombat() and rage < 10 and Ready("Enrage") then return "Enrage" end
        if hp < 40 and Ready("Frenzied Regeneration") then return "Frenzied Regeneration" end
        if not ns.TargetHasDebuff("Demoralizing Roar") and (enemies >= 2 or ns.Lives(60)) and Ready("Demoralizing Roar") then
            return "Demoralizing Roar"
        end
        -- Forever: Primal Bite is the bear 31-point talent (replaced Mangle)
        if Ready("Primal Bite") then return "Primal Bite" end
        if enemies >= 2 and Ready("Swipe") then return "Swipe" end
        local _, lacerate = ns.Debuff("Lacerate")
        if lacerate < 5 and ns.Lives(30) and Ready("Lacerate") then return "Lacerate" end
        if not ns.TargetHasDebuff("Faerie Fire (Feral)") and Ready("Faerie Fire (Feral)") then
            return "Faerie Fire (Feral)"
        end
        if rage >= 15 and not ns.Queued("Maul") and Ready("Maul") then return "Maul" end
    end,
}
