-- Visualize and inspect biome regions on the map.

local RELOAD = false -- set to true to help with debugging

local gui = require('gui')
local widgets = require('gui.widgets')
local guidm = require('gui.dwarfmode')

local TILE_HIGHLIGHTED = dfhack.textures.getOnOffTexposStart() -- yellow-ish indicator
if TILE_HIGHLIGHTED < 0 then -- use a fallback
    TILE_HIGHLIGHTED = 88 -- `X`
end
local TILE_STARTING_SYMBOL = 97 -- `a`

local biomeTypeNames = {
    MOUNTAIN = "Mountain",
    GLACIER = "Glacier",
    TUNDRA = "Tundra",
    SWAMP_TEMPERATE_FRESHWATER = "Temperate Freshwater Swamp",
    SWAMP_TEMPERATE_SALTWATER = "Temperate Saltwater Swamp",
    MARSH_TEMPERATE_FRESHWATER = "Temperate Freshwater Marsh",
    MARSH_TEMPERATE_SALTWATER = "Temperate Saltwater Marsh",
    SWAMP_TROPICAL_FRESHWATER = "Tropical Freshwater Swamp",
    SWAMP_TROPICAL_SALTWATER = "Tropical Saltwater Swamp",
    SWAMP_MANGROVE = "Mangrove Swamp",
    MARSH_TROPICAL_FRESHWATER = "Tropical Freshwater Marsh",
    MARSH_TROPICAL_SALTWATER = "Tropical Saltwater Marsh",
    FOREST_TAIGA = "Taiga Forest",
    FOREST_TEMPERATE_CONIFER = "Temperate Conifer Forest",
    FOREST_TEMPERATE_BROADLEAF = "Temperate Broadleaf Forest",
    FOREST_TROPICAL_CONIFER = "Tropical Conifer Forest",
    FOREST_TROPICAL_DRY_BROADLEAF = "Tropical Dry Broadleaf Forest",
    FOREST_TROPICAL_MOIST_BROADLEAF = "Tropical Moist Broadleaf Forest",
    GRASSLAND_TEMPERATE = "Temperate Grassland",
    SAVANNA_TEMPERATE = "Temperate Savanna",
    SHRUBLAND_TEMPERATE = "Temperate Shrubland",
    GRASSLAND_TROPICAL = "Tropical Grassland",
    SAVANNA_TROPICAL = "Tropical Savanna",
    SHRUBLAND_TROPICAL = "Tropical Shrubland",
    DESERT_BADLAND = "Badland Desert",
    DESERT_ROCK = "Rock Desert",
    DESERT_SAND = "Sand Desert",
    OCEAN_TROPICAL = "Tropical Ocean",
    OCEAN_TEMPERATE = "Temperate Ocean",
    OCEAN_ARCTIC = "Arctic Ocean",
    POOL_TEMPERATE_FRESHWATER = "Temperate Freshwater Pool",
    POOL_TEMPERATE_BRACKISHWATER = "Temperate Brackishwater Pool",
    POOL_TEMPERATE_SALTWATER = "Temperate Saltwater Pool",
    POOL_TROPICAL_FRESHWATER = "Tropical Freshwater Pool",
    POOL_TROPICAL_BRACKISHWATER = "Tropical Brackishwater Pool",
    POOL_TROPICAL_SALTWATER = "Tropical Saltwater Pool",
    LAKE_TEMPERATE_FRESHWATER = "Temperate Freshwater Lake",
    LAKE_TEMPERATE_BRACKISHWATER = "Temperate Brackishwater Lake",
    LAKE_TEMPERATE_SALTWATER = "Temperate Saltwater Lake",
    LAKE_TROPICAL_FRESHWATER = "Tropical Freshwater Lake",
    LAKE_TROPICAL_BRACKISHWATER = "Tropical Brackishwater Lake",
    LAKE_TROPICAL_SALTWATER = "Tropical Saltwater Lake",
    RIVER_TEMPERATE_FRESHWATER = "Temperate Freshwater River",
    RIVER_TEMPERATE_BRACKISHWATER = "Temperate Brackishwater River",
    RIVER_TEMPERATE_SALTWATER = "Temperate Saltwater River",
    RIVER_TROPICAL_FRESHWATER = "Tropical Freshwater River",
    RIVER_TROPICAL_BRACKISHWATER = "Tropical Brackishwater River",
    RIVER_TROPICAL_SALTWATER = "Tropical Saltwater River",
    SUBTERRANEAN_WATER = "Subterranean Water",
    SUBTERRANEAN_CHASM = "Subterranean Chasm",
    SUBTERRANEAN_LAVA = "Subterranean Lava",
}

local function find(t, predicate)
    for k, item in pairs(t) do
        if predicate(k, item) then
            return k, item
        end
    end
    return nil
end

local regionBiomeMap = {}
local biomesMap = {}
local biomeList = {}
local function gatherBiomeInfo(z)
    local maxX, maxY, maxZ = dfhack.maps.getTileSize()
    maxX = maxX - 1; maxY = maxY - 1; maxZ = maxZ - 1

    local z = z or df.global.window_z

    --for z = 0, maxZ do
    for y = 0, maxY do
        for x = 0, maxX do
            local rgnX, rgnY = dfhack.maps.getTileBiomeRgn(x,y,z)
            if rgnX == nil then goto continue end

            local regionBiomesX = regionBiomeMap[rgnX]
            if not regionBiomesX then
                regionBiomesX = {}
                regionBiomeMap[rgnX] = regionBiomesX
            end
            local regionBiomesXY = regionBiomesX[rgnY]
            if not regionBiomesXY then
                regionBiomesXY = {
                    biomeTypeId = dfhack.maps.getBiomeType(rgnX, rgnY),
                    biome = dfhack.maps.getRegionBiome(rgnX, rgnY),
                }
                regionBiomesX[rgnY] = regionBiomesXY
            end

            local biomeTypeId = regionBiomesXY.biomeTypeId
            local biome = regionBiomesXY.biome

            local biomesZ = biomesMap[z]
            if not biomesZ then
                biomesZ = {}
                biomesMap[z] = biomesZ
            end
            local biomesZY = biomesZ[y]
            if not biomesZY then
                biomesZY = {}
                biomesZ[y] = biomesZY
            end

            local function currentBiome(_, item)
                return item.biome == biome
            end
            local ix = find(biomeList, currentBiome)
            if not ix then
                local ch = string.char(string.byte('a') + #biomeList)
                table.insert(biomeList, {biome = biome, char = ch, typeId = biomeTypeId})
                ix = #biomeList
            end

            biomesZY[x] = ix

            ::continue::
        end
    end
    --end
end

-- always gather info at the very bottom first: this ensures the important biomes are
-- always in the same order (high up in the air strange things happen)
gatherBiomeInfo(0)

--------------------------------------------------------------------------------

local TITLE = "Biomes"

if RELOAD then BiomeVisualizerLegend = nil end
local DEFAULT_LIST_HEIGHT = 5
BiomeVisualizerLegend = defclass(BiomeVisualizerLegend, widgets.Window)
BiomeVisualizerLegend.ATTRS {
    frame_title=TITLE,
    frame_inset=0,
    resizable=false,
    resize_min={h=5, w = 14},
    frame = {
        w = 47,
        h = DEFAULT_LIST_HEIGHT + 2 + 15,
        r = 2,
        t = 18,
    },
}

local function GetBiomeName(biome, biomeTypeId)
    -- based on probe.cpp
    local sav = biome.savagery
    local evi = biome.evilness;
    local sindex = sav > 65 and 2 or sav < 33 and 0 or 1
    local eindex = evi > 65 and 2 or evi < 33 and 0 or 1
    local surr = sindex + eindex * 3 +1; --in Lua arrays are 1-based

    local surroundings = {
        "Serene", "Mirthful", "Joyous Wilds",
        "Calm", "Wilderness", "Untamed Wilds",
        "Sinister", "Haunted", "Terrifying"
    }
    local surrounding = surroundings[surr]

    local name = biomeTypeNames[df.biome_type[biomeTypeId]] or "DFHACK_Unknown"

    return ([[%s %s]]):format(surrounding, name)
end

function BiomeVisualizerLegend:init()
    local list = widgets.List{
        view_id = 'list',
        frame = { t = 0, h = DEFAULT_LIST_HEIGHT, w = self.frame.w },
        frame_inset = 0,
        icon_width = 1,
        text_pen = { fg = COLOR_GREY, bg = COLOR_BLACK }, -- this makes selection stand out more
        on_select = self:callback('onSelectEntry'),
    }
    local tooltip_panel = widgets.Panel{
        view_id='tooltip_panel',
        autoarrange_subviews=true,
        frame = { t = list.frame.h + 1, h = 15 },
        frame_style=gui.INTERIOR_FRAME,
        frame_background=gui.CLEAR_PEN,
        subviews={
            widgets.Label{
                view_id='label',
                text_to_wrap='',
                scroll_keys={},
            },
        },
    }
    self:addviews{
        list,
        tooltip_panel,
    }

    self.list = list
    self.tooltip_panel = tooltip_panel

    self:UpdateChoices()
end

local PEN_ACTIVE_ICON = dfhack.pen.parse{tile=TILE_HIGHLIGHTED}
local PEN_NO_ICON = nil

function BiomeVisualizerLegend:get_icon_pen_callback(ix)
    return function ()
        if self.SelectedIndex == ix then
            return PEN_ACTIVE_ICON
        else
            return PEN_NO_ICON
        end
    end
end

function BiomeVisualizerLegend:onSelectEntry(idx, option)
    self.SelectedIndex = idx
    self.SelectedOption = option

    self:ShowTooltip(option)
end

function BiomeVisualizerLegend:UpdateChoices()
    local choices = self.list:getChoices() or {}
    for i = #choices + 1, #biomeList do
        local biomeExt = biomeList[i]
        table.insert(choices, {
            text = ([[%s: %s]]):format(biomeExt.char, GetBiomeName(biomeExt.biome, biomeExt.typeId)),
            icon = self:get_icon_pen_callback(#choices+1),
            biomeTypeId = biomeExt.typeId,
            biome = biomeExt.biome,
        })
    end
    self.list:setChoices(choices)
end

do -- implementation of onMouseHoverEntry(idx, option)
    function BiomeVisualizerLegend:onRenderFrame(dc, rect)
        BiomeVisualizerLegend.super.onRenderFrame(self, dc, rect)

        local list = self.list
        local currentHoverIx = list:getIdxUnderMouse()
        local oldIx = self.HoverIndex
        if currentHoverIx ~= oldIx then
            self.HoverIndex = currentHoverIx
            if self.onMouseHoverEntry then
                local choices = list:getChoices()
                self:onMouseHoverEntry(currentHoverIx, choices[currentHoverIx])
            end
        end
    end
end

local function add_field_text(lines, biome, field_name)
    lines[#lines+1] = ("%s: %s"):format(field_name, biome[field_name])
    lines[#lines+1] = NEWLINE
end

local function get_tooltip_text(option)
    local text = {}
    text[#text+1] = ("type: %s"):format(df.biome_type[option.biomeTypeId])
    text[#text+1] = NEWLINE

    local biome = option.biome

    add_field_text(text, biome, "savagery")
    add_field_text(text, biome, "evilness")
    table.insert(text, NEWLINE)

    add_field_text(text, biome, "elevation")
    add_field_text(text, biome, "rainfall")
    add_field_text(text, biome, "drainage")
    add_field_text(text, biome, "vegetation")
    add_field_text(text, biome, "temperature")
    add_field_text(text, biome, "volcanism")
    table.insert(text, NEWLINE)

    local flags = biome.flags
    if flags.is_lake then
        text[#text+1] = "lake"
        text[#text+1] = NEWLINE
    end
    if flags.is_brook then
        text[#text+1] = "brook"
        text[#text+1] = NEWLINE
    end

    return text
end

function BiomeVisualizerLegend:onMouseHoverEntry(idx, option)
    self:ShowTooltip(option or self.SelectedOption)
end

function BiomeVisualizerLegend:ShowTooltip(option)
    local text = get_tooltip_text(option)

    local tooltip_panel = self.tooltip_panel
    local lbl = tooltip_panel.subviews.label

    lbl:setText(text)

    -- tooltip_panel:updateLayout()
end

--------------------------------------------------------------------------------

if RELOAD then BiomeVisualizer = nil end
BiomeVisualizer = defclass(BiomeVisualizer, gui.ZScreen)
BiomeVisualizer.ATTRS{
    focus_path='BiomeVisualizer',
    pass_movement_keys=true,
}

function BiomeVisualizer:init()
    local legend = BiomeVisualizerLegend{view_id = 'legend'}
    local legend_tooltip = TooltipWindow{view_id = 'legend_tooltip', parent_window = legend}
    self:addviews{legend, legend_tooltip}
end

function BiomeVisualizer:onRenderFrame(dc, rect)
    BiomeVisualizer.super.onRenderFrame(self, dc, rect)

    local z = df.global.window_z
    if not biomesMap[z] then
        gatherBiomeInfo(z)
        self.subviews.legend:UpdateChoices()
    end

    local function get_overlay_pen(pos)
        local self = self
        local safe_index = safe_index
        local biomes = biomesMap

        local N = safe_index(biomes, pos.z, pos.y, pos.x)
        if not N then return end

        local idxSelected = self.subviews.legend.SelectedIndex
        local idxTile = (N == idxSelected)
                    and TILE_HIGHLIGHTED
                    or TILE_STARTING_SYMBOL + (N-1)
        local color = (N == idxSelected)
                    and COLOR_CYAN
                    or COLOR_GREY
        local ch = string.char(string.byte('a') + (N-1))
        return color, ch, idxTile
    end

    guidm.renderMapOverlay(get_overlay_pen, nil) -- nil for bounds means entire viewport
end

function BiomeVisualizer:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('gui/biomes requires a map to be loaded')
end

if RELOAD and view then
    view:dismiss()
end

view = view and view:raise() or BiomeVisualizer{}:show()
