local args = {...}

local wave_size = tonumber(args[1])
local max_pop = tonumber(args[2])
local current_pop = #dfhack.units.getCitizens()

if not wave_size then
  print(dfhack.script_help())
  qerror('max-wave: wave_size required')
end

local new_limit = current_pop + wave_size

if max_pop and new_limit > max_pop then new_limit = max_pop end

if new_limit == df.global.d_init.population_cap then
    print('max-wave: Population cap (' .. new_limit .. ') not changed, maximum population reached')
else
    df.global.d_init.population_cap = new_limit
    print('max-wave: Population cap set to ' .. new_limit)
end
