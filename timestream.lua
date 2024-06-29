--@module = true
--@enable = true

local argparse = require('argparse')
local repeatutil = require("repeat-util")
local utils = require('utils')

------------------------------------
-- state management

local GLOBAL_KEY = 'timestream'

local SETTINGS = {
    {
        name='fps',
        validate=function(arg)
            local val = argparse.positiveInt(arg, 'fps')
            if val < 10 then qerror('target fps must be at least 10') end
            return val
        end,
        default=function() return df.global.init.fps_cap end,
    },
    {
        name='calendar-rate',
        internal_name='calendar_rate',
        validate=function(arg)
            local val = tonumber(arg)
            if not val or val <= 0 then qerror('calendar-rate must be larger than 0') end
            return val
        end,
        default=1.0,
    },
}

local function get_default_state()
    local settings = {}
    for _, v in ipairs(SETTINGS) do
        settings[v.internal_name or v.name] = utils.getval(v.default)
    end
    return {
        enabled=false,
        settings=settings,
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

------------------------------------
-- business logic

-- ensure we never skip over cur_year_tick values that match this list
local TICK_TRIGGERS = {
    {mod=10, rem={0}}, -- season ticks and (mod=100) crop growth
}

-- "owed" ticks we would like to skip at the next opportunity
local timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0

local function get_desired_timeskip(real_fps, desired_fps)
    -- minus 1 to account for the current frame
    return (desired_fps / real_fps) - 1
end

local function get_next_trigger_year_tick(next_tick)
    local next_trigger_tick = math.huge
    for _, trigger in ipairs(TICK_TRIGGERS) do
        local cur_rem = next_tick % trigger.mod
        for _, rem in ipairs(trigger.rem) do
            if cur_rem <= rem then
                next_trigger_tick = math.min(next_trigger_tick, next_tick + (rem - cur_rem))
                goto continue
            end
        end
        next_trigger_tick = math.min(next_trigger_tick, next_tick + trigger.mod - cur_rem + trigger.rem[#trigger.rem])
        ::continue::
    end
    return next_trigger_tick
end

local function clamp_timeskip(timeskip)
    if timeskip <= 0 then return 0 end
    local next_tick = df.global.cur_year_tick + 1
    return math.min(timeskip, get_next_trigger_year_tick(next_tick)-next_tick)
end

local function has_caste_flag(unit, flag)
    if unit.curse.rem_tags1[flag] then return false end
    if unit.curse.add_tags1[flag] then return true end
    return dfhack.units.casteFlagSet(unit.race, unit.caste, df.caste_raw_flags[flag])
end

local function adjust_units(timeskip)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isActive(unit) then goto continue end
        if unit.sex == df.pronoun_type.she then
            if unit.pregnancy_timer > 0 then
                unit.pregnancy_timer = math.max(1, unit.pregnancy_timer - timeskip)
            end
        end
        dfhack.units.subtractGroupActionTimers(unit, timeskip, df.unit_action_type_group.All)
        local job = unit.job.current_job
        local c2 = unit.counters2
        if job and job.job_type == df.job_type.Rest then
            c2.sleepiness_timer = math.max(0, c2.sleepiness_timer - timeskip * 200)
        end
        if not dfhack.units.isCitizen(unit, true) then goto continue end
        if not has_caste_flag(unit, 'NO_EAT') then
            c2.hunger_timer = c2.hunger_timer + timeskip
        end
        if not has_caste_flag(unit, 'NO_DRINK') then
            c2.thirst_timer = c2.thirst_timer + timeskip
        end
        if not has_caste_flag(unit, 'NO_SLEEP') then
            if job and job.job_type == df.job_type.Sleep then
                c2.sleepiness_timer = math.max(0, c2.sleepiness_timer - timeskip * 19)
            else
                c2.sleepiness_timer = c2.sleepiness_timer + timeskip
            end
        end
        -- TODO: c2.stomach_content, c2.stomach_food, and c2.stored_fat
        -- TODO: needs
        ::continue::
    end
end

local function adjust_armies(timeskip)
    -- TODO
end

local function on_tick()
    local real_fps = math.max(1, df.global.enabler.calculated_fps)
    if real_fps >= state.settings.fps then
        timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0
        return
    end

    local desired_timeskip = get_desired_timeskip(real_fps, state.settings.fps) + timeskip_deficit
    local timeskip = math.floor(clamp_timeskip(desired_timeskip))

    -- add some jitter so we don't fall into a constant pattern
    -- this reduces the risk of repeatedly missing an unknown threshold
    -- also keeps the game from looking robotic at lower frame rates
    local jitter_category = math.random(1, 10)
    if jitter_category <= 1 then
        timeskip = math.random(0, timeskip)
    elseif jitter_category <= 3 then
        timeskip = math.random(math.max(0, timeskip-2), timeskip)
    elseif jitter_category <= 5 then
        timeskip = math.random(math.max(0, timeskip-4), timeskip)
    end

    -- no need to let our deficit grow unbounded
    timeskip_deficit = math.min(desired_timeskip - timeskip, 100.0)

    if timeskip <= 0 then return end

    local desired_calendar_timeskip = (timeskip * state.settings.calendar_rate) + calendar_timeskip_deficit
    local calendar_timeskip = math.max(1, math.floor(desired_calendar_timeskip))
    calendar_timeskip_deficit = math.max(0, desired_calendar_timeskip - calendar_timeskip)

    df.global.cur_year_tick = df.global.cur_year_tick + calendar_timeskip

    adjust_units(timeskip)
    adjust_armies(timeskip)
end

------------------------------------
-- hook management

local function do_enable()
    timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0
    state.enabled = true
    repeatutil.scheduleEvery(GLOBAL_KEY, 1, 'ticks', on_tick)
end

local function do_disable()
    state.enabled = false
    repeatutil.cancel(GLOBAL_KEY)
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        do_disable()
        return
    end
    if sc ~= SC_MAP_LOADED or not dfhack.world.isFortressMode() then
        return
    end
    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))
    if state.enabled then
        do_enable()
    end
end

------------------------------------
-- interface

if dfhack_flags.module then
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('needs a loaded fortress map to work')
end

local function print_status()
    print(GLOBAL_KEY .. ' is ' .. (state.enabled and 'enabled' or 'not enabled'))
    print()
    print('settings:')
    for _,v in ipairs(SETTINGS) do
        print(('  %15s: %s'):format(v.name, state.settings[v.internal_name or v.name]))
    end
end

local function do_set(setting_name, arg)
    if not setting_name or not arg then
        qerror('must specify setting and value')
    end
    local _, setting = utils.linear_index(SETTINGS, setting_name, 'name')
    if not setting then
        qerror('setting not found: ' .. setting_name)
    end
    state.settings[setting.internal_name or setting.name] = setting.validate(arg)
    print(('set %s to %s'):format(setting_name, state.settings[setting.internal_name or setting.name]))
end

local function do_reset()
    state = get_default_state()
end

local args = {...}
local command = table.remove(args, 1)

if dfhack_flags and dfhack_flags.enable then
    if dfhack_flags.enable_state then do_enable()
    else do_disable()
    end
elseif command == 'set' then
    do_set(args[1], args[2])
elseif command == 'reset' then
    do_reset()
elseif not command or command == 'status' then
    print_status()
    return
else
    print(dfhack.script_help())
    return
end

persist_state()
