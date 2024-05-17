--Print a tree_info visualization of the tree at the cursor.
--@module = true

local branch_dir =
{
    [0] = ' ',
    [1] = string.char(26), --W
    [2] = string.char(25), --N
    [3] = string.char(217), --WN
    [4] = string.char(27), --E
    [5] = string.char(196), --WE
    [6] = string.char(192), --NE
    [7] = string.char(193), --WNE
    [8] = string.char(24), --S
    [9] = string.char(191), --WS
    [10] = string.char(179), --NS
    [11] = string.char(180), --WNS
    [12] = string.char(218), --ES
    [13] = string.char(194), --WES
    [14] = string.char(195), --NES
    [15] = string.char(197), --WNES
}

function printTreeTile(bits)
    local old_color = dfhack.color()
    local chars = 8
    local exists

    if bits.trunk then
        dfhack.color(COLOR_BROWN)
        chars = chars-1
        exists = true

        if bits.trunk_is_thick then
            dfhack.print('@')
        else
            dfhack.print('O')
        end
    end

    if bits.branches then
        dfhack.color(COLOR_GREEN)
        chars = chars-1
        exists = true
        dfhack.print(string.char(172)) --1/4
    end

    if bits.trunk ~= bits.branches then --align properly
        chars = chars-1
        dfhack.print(' ')
    end

    if bits.twigs then
        dfhack.color(COLOR_GREEN)
        chars = chars-1
        exists = true
        dfhack.print(';')
    end

    if bits.blocked then
        dfhack.color(COLOR_RED)
        chars = chars-1
        dfhack.print('x')
    elseif not exists then
        dfhack.color(COLOR_RESET)
        chars = chars-1
        dfhack.print('.')
    end

    dfhack.color(COLOR_GREY)
    chars = chars-2
    dfhack.print(' '..(branch_dir[bits.branches_dir] or '?'))

    dfhack.color(COLOR_DARKGREY)
    local dir = bits.parent_dir
    if dir > 0 then
        chars = chars-2
        if dir == 1 then
            dfhack.print(' N')
        elseif dir == 2 then
            dfhack.print(' S')
        elseif dir == 3 then
            dfhack.print(' W')
        elseif dir == 4 then
            dfhack.print(' E')
        elseif dir == 5 then
            dfhack.print(' U')
        elseif dir == 6 then
            dfhack.print(' D')
        else
            dfhack.print(' ?')
        end
    end

    dfhack.print((' '):rep(chars))

    dfhack.color(old_color)
end

function printRootTile(bits)
    local old_color = dfhack.color()
    local chars = 8
    local exists

    if bits.regular then
        dfhack.color(COLOR_BROWN)
        chars = chars-1
        exists = true
        dfhack.print(string.char(172)) --1/4
    end

    if bits.blocked then
        dfhack.color(COLOR_RED)
        chars = chars-1
        dfhack.print('x')
    elseif not exists then
        dfhack.color(COLOR_RESET)
        chars = chars-1
        dfhack.print('.')
    end

    dfhack.print((' '):rep(chars))

    dfhack.color(old_color)
end

function printTree(t)
    local div = ('-'):rep(t.dim_x*8+1)
    print(div)

    for z = t.body_height-1, 0, -1 do
        for i = 0, t.dim_x*t.dim_y-1 do
            printTreeTile(t.body[z]:_displace(i))

            if i%t.dim_x == t.dim_x-1 then
                print('|') --next line
            end
        end

        print(div)
    end

    for z = 0, t.roots_depth-1 do
        for i = 0, t.dim_x*t.dim_y-1 do
            printRootTile(t.roots[z]:_displace(i))

            if i%t.dim_x == t.dim_x-1 then
                print('|') --next line
            end
        end

        print(div)
    end
end

if not dfhack_flags.module then
    local p = dfhack.maps.getPlantAtTile(copyall(df.global.cursor))
    if p and p.tree_info then
        printTree(p.tree_info)
    else
        qerror('No tree!')
    end
end
