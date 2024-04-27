local workorder = reqscript('workorder')

-- civilization ID of the player civilization
local civ_id = df.global.plotinfo.civ_id
local raws = df.global.world.raws

---@type instrument itemdef_instrumentst
---@return reaction|nil
function getAssemblyReaction(instrument_id)
    for _, reaction in ipairs(raws.reactions.reactions) do
        if reaction.source_enid == civ_id and
            reaction.category == 'INSTRUMENT' and
            reaction.code:find(instrument_id, 1, true)
        then
            return reaction
        end
    end
    return nil
end

-- patch in thread type
---@type reagent reaction_reagent_itemst
---@return string
function reagentString(reagent)
    if reagent.code == 'thread' then
        local silk = reagent.flags2.silk and "silk " or ""
        local yarn = reagent.flags2.yarn and "yarn " or ""
        local plant = reagent.flags2.plant and "plant " or ""
        return silk .. yarn .. plant .. "thread"
    else
        return reagent.code
    end
end

---@type reaction reaction
---@return string
function describeReaction(reaction)
    local skill = df.job_skill[reaction.skill]
    local reagents = {}
    for _, reagent in ipairs(reaction.reagents) do
        table.insert(reagents, reagentString(reagent))
    end
    return skill .. ": " .. table.concat(reagents, ", ")
end

local function print_list()
    -- gather instrument piece reactions and index them by the instrument they are part of
    local instruments = {}
    for _, reaction in ipairs(raws.reactions.reactions) do
        if reaction.source_enid == civ_id and reaction.category == 'INSTRUMENT_PIECE' then
            local iname = reaction.name:match("[^ ]+ ([^ ]+)")
            table.insert(ensure_key(instruments, iname),
                reaction.name .. " (" .. describeReaction(reaction) .. ")")
        end
    end

    -- go over instruments
    for _, instrument in ipairs(raws.itemdefs.instruments) do
        if not (instrument.source_enid == civ_id) then goto continue end

        local building_tag = instrument.flags.PLACED_AS_BUILDING and " (building, " or " (handheld, "
        local reaction = getAssemblyReaction(instrument.id)
        dfhack.print(instrument.name .. building_tag)
        if #instrument.pieces == 0 then
            print(describeReaction(reaction) .. ")")
        else
            print(df.job_skill[reaction.skill] .. "/assemble)")
            for _, str in pairs(instruments[instrument.name]) do
                print("  " .. str)
            end
        end
        print()
        ::continue::
    end
end

local function order_instrument(name, amount)
    local instrument = nil

    for _, instr in ipairs(raws.itemdefs.instruments) do
        if dfhack.toSearchNormalized(instr.name) == name and instr.source_enid == civ_id then
            instrument = instr
        end
    end

    if instrument == nil then
        qerror("Could not find instrument " .. name)
    end

    local orders = {}

    for i, reaction in ipairs(raws.reactions.reactions) do
        if reaction.source_enid == civ_id and reaction.category == 'INSTRUMENT_PIECE' and reaction.code:find(instrument.id, 1, true) then
            local part_order = {
                id=i,
                amount_total=amount,
                reaction=reaction.code,
                job="CustomReaction",
            }
            table.insert(orders, part_order)
        end
    end

    if #orders < #instrument.pieces then
        print("Warning: Could not find reactions for all instrument pieces")
    end

    local assembly_reaction = getAssemblyReaction(instrument.id)

    local assembly_order = {
        id=-1,
        amount_total=amount,
        reaction=assembly_reaction.code,
        job="CustomReaction",
        order_conditions={}
    }

    for _, order in ipairs(orders) do
        table.insert(
            assembly_order.order_conditions,
            {
                condition="Completed",
                order=order.id
            }
        )
    end

    table.insert(orders, assembly_order)

    orders = workorder.preprocess_orders(orders)
    workorder.fillin_defaults(orders)
    workorder.create_orders(orders)

    print("\nCreated " .. #orders .. " work orders")
end

local args = { ... }

if #args == 0 or args[1] == "list" then
    print_list()
elseif args[1] == "order" then
    local instrument_name = args[2]
    if instrument_name == nil then
        qerror("Usage: instruments order <instrument_name> [<amount>]")
    end

    local amount = args[3] or 1
    order_instrument(instrument_name, amount)
end
