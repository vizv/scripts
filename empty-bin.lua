-- Empty a bin onto the floor
-- Based on "emptybin" by StoneToad
-- https://gist.github.com/stonetoad/11129025
-- http://dwarffortresswiki.org/index.php/DF2014_Talk:Bin

--[====[

empty-bin
=========

Empties the contents of the selected bin onto the floor.

]====]

local function emptyContainer(container)
    local items = dfhack.items.getContainedItems(container)

    if #items > 0 then
        print('Emptying ' .. dfhack.items.getDescription(container, 0))
        for _, item in pairs(items) do
            print('  ' .. dfhack.items.getDescription(item, 0))
            dfhack.items.moveToGround(item, xyz2pos(dfhack.items.getPosition(container)))
        end
    end
end

local function emptyPos(pos)
    if not pos then return end
    local block = dfhack.maps.getTileBlock(pos)
    for _,item_id in ipairs(block.items) do
        local item = df.item.find(item_id)
        emptyContainer(item)
    end
end


local stockpile = dfhack.gui.getSelectedStockpile(true)
local mouse_pos = dfhack.gui.getMousePos()
local selected = dfhack.gui.getSelectedItem(true)
if stockpile then
    local contents = dfhack.buildings.getStockpileContents(stockpile)
    for _, container in ipairs(contents) do
        emptyContainer(container)
    end
elseif selected then
    emptyContainer(selected)
elseif mouse_pos then
    emptyPos(mouse_pos)
else
    qerror("No item selected")
end
