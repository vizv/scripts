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
-- something important happens when cur_season_tick % <mod> == <rem>
-- please keep remainder list elements in **descending** order
local SEASON_TICK_TRIGGERS = {
    {mod=TICKS_PER_DAY//10, rem={0x6e, 0x50, 0x46, 0x3c, 0x32, 0x28, 0x14, 10, 0}},
    {mod=TICKS_PER_WEEK//10, rem={0x32, 0x1e}},
}

-- additional ticks we would like to skip at the next opportunity
local timeskip_deficit = 0.0

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

local function get_next_trigger_season_tick()
    local tick_offset = (df.global.cur_year_tick+1) % 10
    local is_season_tick = tick_offset == 0
    local next_season_tick = df.global.cur_season_tick + (is_season_tick and 0 or 1)

    local next_trigger_tick = math.huge
    for _, trigger in ipairs(SEASON_TICK_TRIGGERS) do
        local cur_rem = next_season_tick % trigger.mod
        for _, rem in ipairs(trigger.rem) do
            if cur_rem < rem or (cur_rem == rem and is_season_tick) then
                next_trigger_tick = math.min(next_trigger_tick, next_season_tick + (rem - cur_rem))
                break
            end
        end
    end
    return next_trigger_tick
end

local function clamp_timeskip(timeskip)
    if timeskip <= 0 then return 0 end
    local next_important_season_tick = math.min(get_next_timed_event_season_tick(), get_next_trigger_season_tick())
    return math.min(timeskip, (next_important_season_tick-df.global.cur_season_tick)*10)
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
        ::continue::
    end
end

local function adjust_crops(timeskip)
    -- TODO
end

local function adjust_armies(timeskip)
    -- TODO
end

local function adjust_evaporation(timeskip)
    -- TODO
end

local function adjust_caravans(timeskip)
    -- TODO
end

local function adjust_item_wear(timeskip)
    -- TODO
end

local function adjust_buildings(timeskip)
    -- TODO
end

local function on_tick()
    local real_fps = math.max(1, df.global.enabler.calculated_fps)
    if real_fps >= state.settings.fps then
        timeskip_deficit = 0.0
        return
    end

    local desired_timeskip = get_desired_timeskip(real_fps, state.settings.fps) + timeskip_deficit
    local timeskip = math.min(math.floor(clamp_timeskip(desired_timeskip)), state.settings.max_frame_skip)
    timeskip_deficit = math.min(desired_timeskip - timeskip, state.settings.max_frame_skip)
    if timeskip <= 0 then return end

    local calendar_timeskip = timeskip * state.settings.calendar_rate
    local new_cur_year_tick = df.global.cur_year_tick + calendar_timeskip
    df.global.cur_season_tick = df.global.cur_season_tick + new_cur_year_tick//10 - df.global.cur_year_tick//10
    df.global.cur_year_tick = new_cur_year_tick

    adjust_units(timeskip)
    adjust_crops(timeskip)
    adjust_armies(timeskip)
    adjust_evaporation(timeskip)
    adjust_caravans(timeskip)
    adjust_item_wear(timeskip)
    adjust_buildings(timeskip)
end

------------------------------------
-- hook management

local function do_enable()
    timeskip_deficit = 0
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
