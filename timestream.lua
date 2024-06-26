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
    {
        name='max-frame-skip',
        internal_name='max_frame_skip',
        validate=function(arg) return argparse.positiveInt(arg, 'max-frame-skip') end,
        default=4,
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

local TICKS_PER_DAY = 1200
local TICKS_PER_WEEK = 7 * TICKS_PER_DAY

-- determined from reverse engineering; don't skip these tick thresholds
-- something important happens when tick % <mod> == <rem>
-- please keep remainder list elements in **descending** order
local SEASON_TICK_TRIGGERS = {
    {mod=TICKS_PER_DAY//10, rem={0x6e, 0x50, 0x46, 0x3c, 0x32, 0x28, 0x14, 10, 0}},
    {mod=TICKS_PER_WEEK//10, rem={0x32, 0x1e}},
}
local YEAR_TICK_TRIGGERS = {
    {mod=100, rem={0}}, -- crop growth
}

-- additional ticks we would like to skip at the next opportunity
local timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0

local function get_desired_timeskip(real_fps, desired_fps)
    return (desired_fps / real_fps) - 1
end

local function get_next_timed_event_season_tick()
    local next_event_tick = math.huge
    for _, event in ipairs(df.global.timed_events) do
        if event.season == df.global.cur_season then
            next_event_tick = math.min(next_event_tick, event.season_ticks)
        end
    end
    return next_event_tick
end

local function get_next_trigger_tick(triggers, next_tick, is_tick_boundary)
    local next_trigger_tick = math.huge
    for _, trigger in ipairs(triggers) do
        local cur_rem = next_tick % trigger.mod
        for _, rem in ipairs(trigger.rem) do
            if cur_rem < rem or (cur_rem == rem and is_tick_boundary) then
                    next_trigger_tick = math.min(next_trigger_tick, next_tick + (rem - cur_rem))
                goto continue
            end
        end
        next_trigger_tick = math.min(next_trigger_tick, next_tick + trigger.mod - cur_rem + trigger.rem[#trigger.rem])
        ::continue::
    end
    return next_trigger_tick
end

local function get_next_trigger_year_tick()
    return get_next_trigger_tick(YEAR_TICK_TRIGGERS, df.global.cur_year_tick + 1, true)
end

local function get_next_trigger_season_tick()
    local is_season_tick = (df.global.cur_year_tick+1) % 10 == 0
    local next_season_tick = df.global.cur_season_tick + (is_season_tick and 1 or 0)
    return get_next_trigger_tick(SEASON_TICK_TRIGGERS, next_season_tick, is_season_tick)
end

local function clamp_timeskip(timeskip)
    if timeskip <= 0 then return 0 end
    local next_important_season_tick = math.min(get_next_timed_event_season_tick(), get_next_trigger_season_tick())
    return math.min(timeskip,
        get_next_trigger_year_tick()-df.global.cur_year_tick-1,
        df.global.cur_year_tick - (df.global.cur_year_tick % 10 + 1) + (next_important_season_tick - df.global.cur_season_tick)*10)
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
        local c2 = unit.counters2
        if not has_caste_flag(unit, 'NO_EAT') then
            c2.hunger_timer = c2.hunger_timer + timeskip
        end
        if not has_caste_flag(unit, 'NO_DRINK') then
            c2.thirst_timer = c2.thirst_timer + timeskip
        end
        local job = unit.job.current_job
        if not has_caste_flag(unit, 'NO_SLEEP') then
            if job and job.job_type == df.job_type.Sleep then
                c2.sleepiness_timer = math.max(0, c2.sleepiness_timer - timeskip * 19)
            else
                c2.sleepiness_timer = c2.sleepiness_timer + timeskip
            end
        end
        if job and job.job_type == df.job_type.Rest then
            c2.sleepiness_timer = math.max(0, c2.sleepiness_timer - timeskip * 200)
        end
        ::continue::
    end
end

local function adjust_armies(timeskip)
    -- TODO
end

local function adjust_caravans(season_timeskip)
    for i, caravan in ipairs(df.global.plotinfo.caravans) do
        if caravan.trade_state == df.caravan_state.T_trade_state.Approaching or
            caravan.trade_state == df.caravan_state.T_trade_state.AtDepot
        then
            local was_before_message_threshold = caravan.time_remaining >= 501
            caravan.time_remaining = caravan.time_remaining - season_timeskip
            if was_before_message_threshold and caravan.time_remaining <= 500 then
                caravan.time_remaining = 501
                need_season_tick = true
            end
        end
        if caravan.time_remaining <= 0 then
            caravan.time_remaining = 0
            dfhack.run_script('caravan', 'leave', tostring(i))
        end
    end
end

local noble_cooldowns = {'manager_cooldown', 'bookkeeper_cooldown'}
local function adjust_nobles(season_timeskip)
    for _, field in ipairs(noble_cooldowns) do
        df.global.plotinfo.nobles[field] = df.global.plotinfo.nobles[field] - season_timeskip
        if df.global.plotinfo.nobles[field] < 0 then
            df.global.plotinfo.nobles[field] = 0
        end
    end
end

local function on_tick()
    local real_fps = math.max(1, df.global.enabler.calculated_fps)
    if real_fps >= state.settings.fps then
        timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0
        return
    end

    local desired_timeskip = get_desired_timeskip(real_fps, state.settings.fps) + timeskip_deficit
    local timeskip = math.min(math.floor(clamp_timeskip(desired_timeskip)), state.settings.max_frame_skip)
    timeskip_deficit = math.min(desired_timeskip - timeskip, state.settings.max_frame_skip)
    if timeskip <= 0 then return end

    local desired_calendar_timeskip = (timeskip * state.settings.calendar_rate) + calendar_timeskip_deficit
    local calendar_timeskip = math.max(1, math.floor(desired_calendar_timeskip))
    if need_season_tick then
        local old_ones = df.global.cur_year_tick % 10
        local new_ones = (df.global.cur_year_tick + calendar_timeskip) % 10
        if new_ones == 9 then
            need_season_tick = false
        elseif old_ones + calendar_timeskip >= 10 then
            calendar_timeskip = 9 - old_ones
            need_season_tick = false
        end
    end
    calendar_timeskip_deficit = math.max(0, desired_calendar_timeskip - calendar_timeskip)

    local new_cur_year_tick = df.global.cur_year_tick + calendar_timeskip
    local season_timeskip = new_cur_year_tick//10 - df.global.cur_year_tick//10

    df.global.cur_season_tick = df.global.cur_season_tick + season_timeskip
    df.global.cur_year_tick = new_cur_year_tick

    adjust_units(timeskip)
    adjust_armies(timeskip)
    adjust_caravans(season_timeskip)
    adjust_nobles(season_timeskip)
end

------------------------------------
-- hook management

local function do_enable()
    timeskip_deficit, calendar_timeskip_deficit = 0.0, 0.0
    need_season_tick = false
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
