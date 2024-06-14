--Fixes all local bugged sleepers in adventure mode.
--[====[

adv-fix-sleepers
================
Fixes :bug:`6798`. This bug is characterized by sleeping units who refuse to
awaken in adventure mode regardless of talking to them, hitting them, or waiting
so long you die of thirst. If you come accross one or more bugged sleepers in
adventure mode, simply run the script and all nearby sleepers will be cured.

Usage::

    adv-fix-sleepers


]====]

--========================
-- Author: ArrowThunder on bay12 & reddit
-- Fixed for v51 by Crystalwarrior
-- Version: 1.2
--=======================

-- get the list of all the active units currently loaded
local active_units = df.global.world.units.active -- get all active units

-- check every active unit for the bug
local num_fixed = 0 -- this is the number of army controllers fixed, not units
    -- I've found that often, multiple sleepers share a bugged army controller
for k, unit in pairs(active_units) do
    if unit then
        local army_controller = unit.enemy.army_controller
        if army_controller and army_controller.goal == df.army_controller_goal_type.CAMP then -- sleeping code is possible
            if not army_controller.data.goal_camp.camp_flag.ALARM_INTRUDER then
                army_controller.data.goal_camp.camp_flag.ALARM_INTRUDER = true -- fix bug
                num_fixed = num_fixed + 1
            end
        end
    end
end

if num_fixed == 0 then
    print ("No sleepers with the fixable bug were found, sorry.")
else
    print ("Fixed " .. num_fixed .. " bugged army_controller(s).")
end
