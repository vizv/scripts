local argparse = require('argparse')
local utils = require('utils')


local function fix_units()
    if (!Core::getInstance().isMapLoaded())
        return 0;

    if (!World::isFortressMode() && !opts.use_cursor)
    {
        out.printerr("Can only scan entire map in fortress mode\n");
        return 0;
    }

    if (opts.use_cursor && cursor->x < 0)
    {
        out.printerr("No cursor\n");
        return 0;
    }

    uo_buffer.resize();
    unsigned count = 0;

    float time1 = getClock();
    for (size_t i = 0; i < world->map.map_blocks.size(); i++)
    {
        df::map_block *block = world->map.map_blocks[i];
        int map_z = block->map_pos.z;
        if (opts.use_cursor && (map_z != cursor->z || block->map_pos.y != (cursor->y / 16) * 16 || block->map_pos.x != (cursor->x / 16) * 16))
            continue;
        for (int x = 0; x < 16; x++)
        {
            int map_x = x + block->map_pos.x;
            for (int y = 0; y < 16; y++)
            {
                if (block->designation[x][y].bits.hidden)
                    continue;
                int map_y = y + block->map_pos.y;
                if (opts.use_cursor && (map_x != cursor->x || map_y != cursor->y))
                    continue;
                if (block->occupancy[x][y].bits.unit)
                    uo_buffer.set(map_x, map_y, map_z, 1);
            }
        }
    }

    for (auto it = world->units.active.begin(); it != world->units.active.end(); ++it)
    {
        df::unit *u = *it;
        if (!u || u->flags1.bits.caged || u->pos.x < 0)
            continue;
        df::creature_raw *craw = df::creature_raw::find(u->race);
        int unit_extents = (craw && craw->flags.is_set(df::creature_raw_flags::EQUIPMENT_WAGON)) ? 1 : 0;
        for (int16_t x = u->pos.x - unit_extents; x <= u->pos.x + unit_extents; ++x)
        {
            for (int16_t y = u->pos.y - unit_extents; y <= u->pos.y + unit_extents; ++y)
            {
                uo_buffer.set(x, y, u->pos.z, 0);
            }
        }
    }

    for (size_t i = 0; i < uo_buffer.size; i++)
    {
        if (uo_buffer.buf[i])
        {
            uint32_t x, y, z;
            uo_buffer.get_coords(i, x, y, z);
            out.print("(%u, %u, %u) - no unit found\n", x, y, z);
            ++count;
            if (!opts.dry_run)
            {
                df::map_block *b = Maps::getTileBlock(x, y, z);
                b->occupancy[x % 16][y % 16].bits.unit = false;
            }
        }
    }

    float time2 = getClock();
    std::cerr << "fix-unit-occupancy: elapsed time: " << time2 - time1 << " secs" << endl;
    if (count)
        out << (opts.dry_run ? "[dry run] " : "") << "Fixed occupancy of " << count << " tiles [fix-unit-occupancy]" << endl;
    return count;
end

local function fix_buildings()
    function findUnit(x, y, z)
        for _, u in pairs(df.global.world.units.active) do
            if u.pos.x == x and u.pos.y == y and u.pos.z == z then
                return true
            end
        end
        return false
    end

    local cursor = df.global.cursor
    local changed = false
    function report(flag)
        print('Cleared occupancy flag: ' .. flag)
        changed = true
    end

    if cursor.x == -30000 then
        qerror('Cursor not active.')
    end

    local occ = dfhack.maps.getTileBlock(pos2xyz(cursor)).occupancy[cursor.x % 16][cursor.y % 16]

    if occ.building ~= df.tile_building_occ.None and not dfhack.buildings.findAtTile(pos2xyz(cursor)) then
        occ.building = df.tile_building_occ.None
        report('building')
    end

    for _, flag in pairs{'unit', 'unit_grounded'} do
        if occ[flag] and not findUnit(pos2xyz(cursor)) then
            occ[flag] = false
            report(flag)
        end
    end
end

local function check_block_items(fix)
    local cnt = 0
    local icnt = 0
    local found = {}
    local found_somewhere = {}

    local should_fix = false
    local can_fix = true

    for _,block in ipairs(df.global.world.map.map_blocks) do
        local itable = {}
        local bx,by,bz = pos2xyz(block.map_pos)

        -- Scan the block item vector
        local last_id = nil
        local resort = false

        for _,id in ipairs(block.items) do
            local item = df.item.find(id)
            local ix,iy,iz = pos2xyz(item.pos)
            local dx,dy,dz = ix-bx,iy-by,iz-bz

            -- Check sorted order
            if last_id and last_id >= id then
                print(bx,by,bz,last_id,id,'block items not sorted')
                resort = true
            else
                last_id = id
            end

            -- Check valid coordinates and flags
            if not item.flags.on_ground then
                print(bx,by,bz,id,dx,dy,'in block & not on ground')
            elseif dx < 0 or dx >= 16 or dy < 0 or dy >= 16 or dz ~= 0 then
                found_somewhere[id] = true
                print(bx,by,bz,id,dx,dy,dz,'invalid pos')
                can_fix = false
            else
                found[id] = true
                itable[dx + dy*16] = true;

                -- Check missing occupancy
                if not block.occupancy[dx][dy].item then
                    print(bx,by,bz,dx,dy,'item & not occupied')
                    if fix then
                        block.occupancy[dx][dy].item = true
                    else
                        should_fix = true
                    end
                end
            end
        end

        -- Sort the vector if needed
        if resort then
            if fix then
                utils.sort_vector(block.items)
            else
                should_fix = true
            end
        end

        icnt = icnt + #block.items

        -- Scan occupancy for spurious marks
        for x=0,15 do
            local ocx = block.occupancy[x]
            for y=0,15 do
                if ocx[y].item and not itable[x + y*16] then
                    print(bx,by,bz,x,y,'occupied & no item')
                    if fix then
                        ocx[y].item = false
                    else
                        should_fix = true
                    end
                end
            end
        end

        cnt = cnt + 256
    end

    -- Check if any items are missing from blocks
    for _,item in ipairs(df.global.world.items.other.IN_PLAY) do
        if item.flags.on_ground and not found[item.id] then
            can_fix = false
            if not found_somewhere[item.id] then
                print(item.id,item.pos.x,item.pos.y,item.pos.z,'on ground & not in block')
            end
        end
    end

    -- Report
    print(cnt.." tiles and "..icnt.." items checked.")

    if should_fix and can_fix then
        print("Use 'fix/item-occupancy --fix' to fix the listed problems.")
    elseif should_fix then
        print("The problems are too severe to be fixed by this script.")
    end
end

local function fixit(opts)
end

local opts = {}

local positionals = argparse.processArgsGetopt({...}, {
    { 'h', 'help', handler = function() opts.help = true end },
    { 'n', 'dry-run', handler = function() opts.dry_run = true end },
})

if positionals[1] == 'help' or opts.help then
    print(dfhack.script_help())
    return
end

fixit(opts)
