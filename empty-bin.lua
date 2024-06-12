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


local stockpile = dfhack.gui.getSelectedStockpile(true)
if stockpile then
    local contents = dfhack.buildings.getStockpileContents(stockpile)
    for _, container in ipairs(contents) do
        emptyContainer(container)
    end
else
    local bin = dfhack.gui.getSelectedItem(true) or qerror("No item selected")
    emptyContainer(bin)
end
