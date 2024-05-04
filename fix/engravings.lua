--function checks tiletype for attributes and returns true or false depending on if its engraving location is correct
local function is_good_engraving(engraving)
    local ttype = dfhack.maps.getTileType(engraving.pos)
    if not ttype then return end
    local tileattrs = df.tiletype.attrs[ttype]  

    if tileattrs.special ~= df.tiletype_special.SMOOTH then
        return false
    end
	
    if tileattrs.shape == df.tiletype_shape.FLOOR then
        return engraving.flags.floor
    end	
	
    if tileattrs.shape == df.tiletype_shape.WALL then
        return not engraving.flags.floor
    end
end

--loop runs through list of all engravings checking each using is_good_engraving and if bad gets deleted
local cleanup = 0
local engravings = df.global.world.engravings
for index = #engravings-1,0,-1 do
    local engraving = engravings[index]
    if not is_good_engraving(engraving) then
        engravings:erase(index)
        engraving:delete()
        cleanup = cleanup + 1
    end
end
if not quiet or cleanup > 0 then
    print(('%d bad engraving(s) fixed.'):format(cleanup))
end
