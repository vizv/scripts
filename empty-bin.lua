-- Empty a bin onto the floor
-- Based on "emptybin" by StoneToad
-- https://gist.github.com/stonetoad/11129025
-- http://dwarffortresswiki.org/index.php/DF2014_Talk:Bin

--[====[

empty-bin
=========

Empties the contents of the selected bin onto the floor.

]====]

local function moveItem(item, to_pos)
    print('  ' .. dfhack.items.getDescription(item, 0))
    dfhack.items.moveToGround(item, to_pos)
end

local function emptyContainer(container)
    local items = dfhack.items.getContainedItems(container)

    if #items > 0 then
        print('Emptying ' .. dfhack.items.getDescription(container, 0))
        for _, item in ipairs(items) do
            moveItem(item, xyz2pos(dfhack.items.getPosition(container)))
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

local viewsheets = df.global.game.main_interface.view_sheets

local stockpile = dfhack.gui.getSelectedStockpile(true)
local selectedItem = dfhack.gui.getSelectedItem(true)
local selectedBuilding = dfhack.gui.getSelectedBuilding(true)
if stockpile then
    local contents = dfhack.buildings.getStockpileContents(stockpile)
    for _, container in ipairs(contents) do
        emptyContainer(container)
    end
elseif selectedItem then
    emptyContainer(selectedItem)
elseif selectedBuilding then
    if not df.building_actual:is_instance(selectedBuilding) then
        qerror("This type of building does not contain any items!")
    end
    local containedItems = selectedBuilding.contained_items
    for i=#containedItems-1,0,-1 do
        contained = containedItems[i]
        if contained.use_mode == df.building_item_role_type.TEMP then
            moveItem(contained.item, xyz2pos(selectedBuilding.centerx, selectedBuilding.centery, selectedBuilding.z))
        end
    end
elseif viewsheets.open then
    for _, item_id in ipairs(viewsheets.viewing_itid) do
        local item = df.item.find(item_id)
        emptyContainer(item)
    end
else
    qerror("No valid target found")
end
