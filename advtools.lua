--@ module=true

local convo = reqscript('internal/advtools/convo')
local party = reqscript('internal/advtools/party')
local pets = reqscript('internal/advtools/pets')

OVERLAY_WIDGETS = {
    conversation=convo.AdvRumorsOverlay,
}

if dfhack_flags.module then
    return
end

local commands = {
    party=party.run,
    pets=pets.run,
}

local args = {...}
local command = table.remove(args, 1)

if not command or command == 'help' or not commands[command] then
    print(dfhack.script_help())
    return
end

commands[command](args)
