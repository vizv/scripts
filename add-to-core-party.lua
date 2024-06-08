local dialogs = require 'gui.dialogs'
local utils = require 'utils'
local viewscreen = dfhack.gui.getDFViewscreen(true)
if viewscreen._type ~= df.viewscreen_dungeonmodest then
    qerror("This script can only be used during adventure mode!")
end

local function addToCoreParty(nemesis)
    -- Adds them to the party core members list
    local party = df.global.adventure.interactions
    -- problem: the "brain" icon deciding on manual/automatic control is somewhat broken.
    -- research leads me to believe the data is stored per-unit or unit ID, need to figure out
    -- where that data is stored exactly. Might be one of the unknown variables?
    party.party_core_members:insert('#', nemesis.figure.id)
    local extra_member_idx, _ = utils.linear_index(party.party_extra_members, nemesis.figure.id)
    if extra_member_idx then
        party.party_extra_members:erase(extra_member_idx)
    end
    -- Adds them to unretire list
    nemesis.flags.ADVENTURER = true

    -- Ideally, this is always true but you never know...
    if nemesis.unit then
        -- Allow their control to be changeable from manual to AI and vice versa (companion screen bugs out if this isn't true)
        nemesis.unit.status.unit_command_flag.HAVE_COMMAND_GAIT = true
    end
end

local function showExtraPartyPrompt(advSetUpScreen)
    local choices = {}
    for _, figure_id in ipairs(df.global.adventure.interactions.party_extra_members) do
        -- shamelessly copy-pasted from unretire-anyone.lua
        local histFig = df.historical_figure.find(figure_id)
        local nemesis = df.nemesis_record.find(histFig.nemesis_id)
        local histFlags = histFig.flags
        local creature = df.creature_raw.find(histFig.race).caste[histFig.caste]
        local name = creature.caste_name[0]
        if histFig.died_year >= -1 then
            histFig.died_year = -1
            histFig.died_seconds = -1
        end
        if histFig.info and histFig.info.curse then
            local curse = histFig.info.curse
            if curse.name ~= '' then
                name = name .. ' ' .. curse.name
            end
            if curse.undead_name ~= '' then
                name = curse.undead_name .. " - reanimated " .. name
            end
        end
        if histFlags.ghost then
            name = name .. " ghost"
        end
        local sym = df.pronoun_type.attrs[creature.sex].symbol
        if sym then
            name = name .. ' (' .. sym .. ')'
        end
        if histFig.name.has_name then
            name = dfhack.TranslateName(histFig.name) ..
                " - (" .. dfhack.TranslateName(histFig.name, true) .. ") - " .. name
        end
        table.insert(choices, { text = name, nemesis = nemesis, search_key = name:lower() })
    end
    dialogs.showListPrompt('add-to-core-party', "Select someone to add to your \"Core Party\" (able to assume control, able to unretire):", COLOR_WHITE,
        choices, function(id, choice)
            addToCoreParty(choice.nemesis)
        end, nil, nil, true)
end

showExtraPartyPrompt(viewscreen)
