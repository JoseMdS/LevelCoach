local _, ns = ...
if ns.playerClass ~= "SHAMAN" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

local function MissingImbue()
    if not GetWeaponEnchantInfo then return nil end
    local hasMain = GetWeaponEnchantInfo()
    if hasMain then return nil end
    return ReadyAny("Windfury Weapon", "Flametongue Weapon", "Rockbiter Weapon")
end

ns.RegisterSpec{
    spells = { "Grace of Air Totem", "Windfury Weapon", "Flametongue Weapon", "Rockbiter Weapon", "Stormstrike", "Earth Shock", "Rage of the Farseer", "Lightning Shield", "Healing Wave", "Lesser Healing Wave", "Lightning Bolt", "Flame Shock", "Chain Lightning", "Call of the Elements", "Strength of Earth Totem", "Stoneskin Totem", "Searing Totem", "Windfury Totem" },
    class = "SHAMAN", tree = 2, name = "Enhancement", default = true,
    filler = { "Stormstrike", "Lightning Bolt" }, -- shown dimmed when nothing else fits
    melee = { "Stormstrike" },
    interrupt = "Earth Shock",
    cooldowns = { "Rage of the Farseer" },
    resource = function()
        local mw = ns.Buff("Maelstrom Weapon")
        if mw then return mw .. " mw", 0.3, 0.6, 1 end
        return ns.PctShown(ns.PT.Mana), 0.3, 0.6, 1
    end,
    next = function()
        if not ns.InCombat() then
            if not HasBuff("Lightning Shield") and Ready("Lightning Shield") then return "Lightning Shield" end
            local imbue = MissingImbue()
            if imbue then return imbue end
        end
        if not ns.HasHostileTarget() then return nil end

        local hp, thp, mana, enemies = ns.HealthPct(), ns.HealthPct("target"), ns.PowerPct(ns.PT.Mana), ns.Enemies()
        local mw = ns.Buff("Maelstrom Weapon") or 0

        if hp < 40 then
            local heal = (mw >= 5 or not ns.InCombat()) and ReadyAny("Healing Wave", "Lesser Healing Wave")
                      or ReadyAny("Lesser Healing Wave", "Healing Wave")
            if heal then return heal end
        end

        if not ns.InMelee() then
            -- Pull from range
            -- Each Maelstrom stack cuts cast time and mana cost by 20%, so 3+ stacks already make a quick bolt
            if mw >= 3 or not ns.InCombat() then
                if Ready("Lightning Bolt") then return "Lightning Bolt" end
            end
            if ns.Debuff("Flame Shock") == 0 and Ready("Flame Shock") then return "Flame Shock" end
            return nil
        end

        -- Instant cast with a full Maelstrom Weapon
        if mw >= 5 then
            local spell = (enemies >= 2 and Ready("Chain Lightning")) and "Chain Lightning" or ReadyAny("Lightning Bolt")
            if spell then return spell end
        end
        if Ready("Stormstrike") then return "Stormstrike" end
        -- Totem twisting (opt-in, /lc twist): Windfury Totem's buff lingers ~10 sec after the totem is
        -- replaced, so drop Grace of Air right after Windfury, then Windfury again before the buff ends.
        if ns.Twist() and ns.InCombat() and mana > 40 and Known("Windfury Totem") and Known("Grace of Air Totem") then
            local air = ns.TotemName(4)
            local wfUp = air and air:find("Windfury")
            local sinceWF = ns.SinceCast and ns.SinceCast("Windfury Totem") or 999
            if not wfUp and sinceWF > 8.5 and Ready("Windfury Totem") then return "Windfury Totem" end
            if wfUp and sinceWF > 1 and sinceWF < 8.5 and Ready("Grace of Air Totem") then return "Grace of Air Totem" end
        end
        -- Drop totems on mobs that will live long enough (Forever: Call of the Elements drops a set at once)
        if ns.InCombat() and ns.Lives(60) and not ns.HasTotem(2) and not ns.HasTotem(1)
           and Ready("Call of the Elements") then return "Call of the Elements" end
        if ns.InCombat() and ns.Lives(60) then
            if not ns.HasTotem(2) then
                local t = ReadyAny("Strength of Earth Totem", "Stoneskin Totem")
                if t then return t end
            end
            if not ns.HasTotem(1) and Ready("Searing Totem") then return "Searing Totem" end
            if not ns.HasTotem(4) then
                local air = ReadyAny("Windfury Totem", "Grace of Air Totem")
                if air then return air end
            end
        end
        -- 3-4 Maelstrom stacks: 60-80% faster and cheaper, worth spending rather than waiting for 5
        if mw >= 3 and mana > 15 then
            local spell = (enemies >= 2 and Ready("Chain Lightning")) and "Chain Lightning" or ReadyAny("Lightning Bolt")
            if spell then return spell end
        end
        if mana > 30 then
            -- With Stormstrike: Earth Shock right after it (shared shock cooldown). Before that: Flame Shock dot.
            if Known("Stormstrike") then
                if Ready("Earth Shock") then return "Earth Shock" end
            else
                if ns.Lives(40) and ns.Debuff("Flame Shock") == 0 and Ready("Flame Shock") then return "Flame Shock" end
                if Ready("Earth Shock") then return "Earth Shock" end
            end
        end
        -- Very low level: Lightning Bolt between swings is fine
        if not Known("Stormstrike") and mana > 50 and Ready("Lightning Bolt") then return "Lightning Bolt" end
    end,
}
