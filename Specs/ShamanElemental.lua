local _, ns = ...
if ns.playerClass ~= "SHAMAN" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

ns.RegisterSpec{
    spells = { "Lightning Bolt", "Chain Lightning", "Flame Shock", "Earth Shock", "Frost Shock", "Elemental Mastery", "Lightning Shield", "Healing Wave", "Lesser Healing Wave", "Searing Totem", "Magma Totem", "Fire Nova Totem", "Call of the Elements" },
    class = "SHAMAN", tree = 1, name = "Elemental", alias = "ele", ranged = true,
    filler = { "Lightning Bolt" }, -- shown dimmed when nothing else fits
    interrupt = "Earth Shock",
    cooldowns = { "Elemental Mastery" },
    resource = function() return ns.PctShown(ns.PT.Mana), 0.3, 0.6, 1 end,
    next = function()
        if not ns.InCombat() then
            if not HasBuff("Lightning Shield") and Ready("Lightning Shield") then return "Lightning Shield" end
        end
        if not ns.HasHostileTarget() then return nil end

        local hp, mana, enemies = ns.HealthPct(), ns.PowerPct(ns.PT.Mana), ns.Enemies()

        if hp < 40 then
            local heal = ReadyAny("Lesser Healing Wave", "Healing Wave")
            if heal then return heal end
        end
        if ns.InRange("Lightning Bolt") == false then return nil end
        -- Pull with the big cast
        if not ns.InCombat() and Ready("Lightning Bolt") then return "Lightning Bolt" end

        -- Leveling: finish a dying mob with an instant shock instead of starting a slow cast
        if not ns.Lives(20) and not ns.Endgame() and Ready("Earth Shock") then return "Earth Shock" end
        -- In melee you get pushed back while casting: lean on instants
        if ns.InMelee() and ns.InCombat() and mana > 20 then
            if ns.Lives(40) and ns.Debuff("Flame Shock") == 0 and Ready("Flame Shock") then return "Flame Shock" end
            if Ready("Earth Shock") then return "Earth Shock" end
        end
        -- Packs: Chain Lightning, plus a fire totem at your feet when they're on you
        if enemies >= 2 and mana > 30 and Ready("Chain Lightning") then return "Chain Lightning" end
        if enemies >= 3 and ns.InMelee() and mana > 40 and not ns.HasTotem(1) then
            local t = ReadyAny("Magma Totem", "Fire Nova Totem")
            if t then return t end
        end
        -- Long fights: Searing Totem and the Flame Shock dot pay off
        if ns.InCombat() and ns.Lives(60) and mana > 40 and not ns.HasTotem(1) and Ready("Searing Totem") then
            return "Searing Totem"
        end
        if ns.Lives(40) and mana > 30 and ns.Debuff("Flame Shock") == 0 and Ready("Flame Shock") then
            return "Flame Shock"
        end
        if Ready("Lightning Bolt") then return "Lightning Bolt" end
    end,
}
