local _, ns = ...
if ns.playerClass ~= "DRUID" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

-- Shared druid helpers (also used by the bear file)
ns.Druid = ns.Druid or {}
function ns.Druid.Buffs()
    if ns.InCombat() or ns.InCatForm() or ns.InBearForm() then return nil end
    if not HasBuff("Mark of the Wild") and not HasBuff("Gift of the Wild") and Ready("Mark of the Wild") then
        return "Mark of the Wild"
    end
    if not HasBuff("Thorns") and Ready("Thorns") then return "Thorns" end
end
function ns.Druid.Caster()
    if ns.Debuff("Moonfire") == 0 and Ready("Moonfire") then return "Moonfire" end
    return ReadyAny("Wrath")
end

ns.RegisterSpec{
    spells = { "Mark of the Wild", "Gift of the Wild", "Thorns", "Moonfire", "Wrath", "Claw", "Rake", "Maul", "Bash", "Berserk", "Cat Form", "Bear Form", "Regrowth", "Healing Touch", "Faerie Fire (Feral)", "Pounce", "Ravage", "Rip", "Ferocious Bite", "Shred" },
    class = "DRUID", tree = 2, name = "Feral", alias = "cat", default = true,
    when = function() return not ns.InBearForm() end,
    filler = { "Claw", "Wrath" }, -- shown dimmed when nothing else fits
    melee = { "Claw", "Rake", "Maul" },
    interrupt = "Bash",
    cooldowns = { "Berserk" },
    resource = function()
        if ns.InCatForm() then return ns.ComboPoints() .. " cp  " .. ns.PowerShown(ns.PT.Energy), 1, 0.9, 0.2 end
        return ns.PctShown(ns.PT.Mana), 0.4, 0.6, 1
    end,
    next = function()
        local buff = ns.Druid.Buffs()
        if buff then return buff end
        if not ns.HasHostileTarget() then return nil end

        if not ns.InCatForm() then
            if Known("Cat Form") then return "Cat Form" end
            if Known("Bear Form") then return "Bear Form" end -- levels 10-19: bear until you get Cat Form
            if ns.HealthPct() < 40 then
                local heal = ReadyAny("Regrowth", "Healing Touch")
                if heal then return heal end
            end
            return ns.Druid.Caster()
        end

        local cp, thp = ns.ComboPoints(), ns.HealthPct("target")

        if not ns.InMelee() then
            if not ns.TargetHasDebuff("Faerie Fire (Feral)") and Ready("Faerie Fire (Feral)") then
                return "Faerie Fire (Feral)"
            end
            return nil
        end
        if ns.Stealthed() then
            local opener = ReadyAny("Pounce", "Ravage", "Rake")
            if opener then return opener end
        end
        if not ns.TargetHasDebuff("Faerie Fire (Feral)") and Ready("Faerie Fire (Feral)") then
            return "Faerie Fire (Feral)"
        end
        if cp >= 5 or (not ns.Endgame() and cp >= 2 and thp < 20) then
            -- Rip at 5 points on mobs that will live for it; Ferocious Bite otherwise / while Rip is up
            if cp >= 5 and ns.Lives(50) and ns.Debuff("Rip") == 0 and Ready("Rip") then return "Rip" end
            if Ready("Ferocious Bite") then return "Ferocious Bite" end
        end
        if ns.Lives(40) and ns.Debuff("Rake") == 0 and Ready("Rake") then return "Rake" end
        -- Shred needs you behind the target: suggest it when the mob is attacking someone else
        -- (or always with /lc shred), otherwise Claw.
        local behindLikely = ns.Shred() or (ns.Clean(UnitExists("targettarget")) and ns.Clean(UnitIsUnit("targettarget", "player")) == false)
        if behindLikely and Ready("Shred") then return "Shred" end
        return ReadyAny("Claw")
    end,
}
